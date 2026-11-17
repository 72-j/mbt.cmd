///|
/// mooncmd 全链自证示例（可执行）：银行账户聚合从定义到落库的一跑。
/// 叙事序 = 消费方接入序：① 定义聚合 → ② 内存命令链 → ③ SQLite 落库
/// 与重放重建 → ④ 乐观并发拒写 → ⑤ 销户闭环 → ⑥ 快照加速等价 →
/// ⑦ PM 泵跨聚合编排（役13b 词表 gen 产物）。
/// 终行 EXAMPLE:PASS。

///|
fn check(label : String, ok : Bool, detail : String) -> Bool {
  let verdict = if ok { "PASS" } else { "FAIL" }
  println("[\{verdict}] \{label} — \{detail}")
  ok
}

///|
fn main raise {
  let mut all_green = true
  let aggregate_id = "demo-account-001"
  // ========== ② 内存命令链：命令 → 纯事件 → EventMessage 自动包装 ==========
  let aggregate = @aggregate.AggregateRoot::new(
      aggregate_id,
      @bank.account_handler,
      @event.EventApplier::Single(@bank.account_applier),
      @bank.account_empty_state(),
    )
    .exec(@bank.CreateAccount("Demo Holder", 1000))
    .exec(@bank.DepositMoney(500))
    .exec(@bank.WithdrawMoney(300))
  let chain_ok = aggregate.version() == 3
  all_green = all_green &&
    check("内存命令链", chain_ok, "版本 = \{aggregate.version()}")
  let state = aggregate.current_state()
  let state_ok = state.balance == 1200 && state.is_active
  all_green = all_green &&
    check(
      "状态演进",
      state_ok,
      "balance = \{state.balance}, active = \{state.is_active}",
    )
  // 元数据自动包装佐证：版本 1..3 连续、schema_version 预留位在
  let uncommitted = aggregate.uncommitted_events()
  let meta_ok = uncommitted.length() == 3 &&
    uncommitted[0].aggregate_version == 1 &&
    uncommitted[2].aggregate_version == 3
  all_green = all_green &&
    check(
      "元数据自动包装",
      meta_ok,
      "3 事件，版本 1..3，schema_version = \{uncommitted[0].schema_version}",
    )
  // ========== ③ SQLite 落库 + 重放重建 ==========
  let store = @store.SQLiteEventStore::new(
    ":memory:", @bank.account_serialize, @bank.account_deserialize, @bank.account_type_name,
  )
  store.append(aggregate_id, uncommitted)
  let loaded = store.load(aggregate_id, 0)
  let load_ok = loaded.length() == 3
  all_green = all_green &&
    check("落库读回", load_ok, "load 回 \{loaded.length()} 事件")
  let rebuilt = @aggregate.AggregateRoot::from_events(
    aggregate_id,
    loaded,
    @bank.account_handler,
    @event.EventApplier::Single(@bank.account_applier),
    @bank.account_empty_state(),
  )
  let rebuilt_state = rebuilt.current_state()
  let rebuild_ok = rebuilt.version() == aggregate.version() &&
    rebuilt_state.balance == state.balance &&
    rebuilt_state.name == state.name
  all_green = all_green &&
    check(
      "重放重建等价",
      rebuild_ok,
      "重建版本 \{rebuilt.version()} / balance \{rebuilt_state.balance} / 户名 \{rebuilt_state.name}",
    )
  // ========== ④ 乐观并发：旧批次重放即拒（DuplicateVersion，不落脏）==========
  let mut conflict_rejected = false
  store.append(aggregate_id, uncommitted) catch {
    err =>
      match err {
        @store.EventStoreError::DuplicateVersion(current) => {
          println(
            "[PASS] 乐观并发拒写 — DuplicateVersion: 当前版本 \{current}",
          )
          conflict_rejected = true
        }
        _ => println("[FAIL] 乐观并发 — 非预期错误形")
      }
  }
  all_green = all_green && conflict_rejected
  let version_after_reject = store.current_version(aggregate_id)
  let clean_ok = version_after_reject == 3
  all_green = all_green &&
    check(
      "拒写不落脏",
      clean_ok,
      "当前版本仍 = \{version_after_reject}",
    )
  // ========== ④b Effect 重试状态机：两败后成走机；Validation 直上抛 ==========
  // 演示 1：FailTwiceThenOk——前两次 Conflict（Duplicate 族→词表 retry），第三次成。
  // wait = 打印型假钟（真钟 = async sleep，宿主接）;词表 fixed interval=100。
  let mut effect_calls = 0
  let effect_handler = fn(
    state : @bank.AccountState,
    _cmd : @bank.AccountCommand,
  ) -> Array[@bank.AccountEvent] raise @command.CommandError {
    effect_calls = effect_calls + 1
    if effect_calls <= 2 {
      // 模拟瞬时乐观并发冲突（同类：另一写者抢先）——Duplicate 族，词表 retry
      ignore(state)
      raise @command.CommandError::Conflict(1, 2)
    } else {
      // 冲突消除，业务裁决放行（等价 deposit_money 守卫通过形）
      ignore(state)
      [@bank.MoneyDeposited(700)]
    }
  }
  let retry_root = @aggregate.AggregateRoot::new(
    "demo-effect-1",
    effect_handler,
    @event.EventApplier::Single(@bank.account_applier),
    @bank.AccountState::init(),
  )
  let effect_done = retry_root.exec_with_effect(
    @bank.DepositMoney(700),
    @bank.account_retry_machine(),
    @bank.account_retry_hooks_pure(),
    fn(ms) { println("    [effect] 冲突，固定退避 \{ms}ms 后重试") },
  )
  let effect1_ok = effect_calls == 3 &&
    effect_done.version() == 1 &&
    effect_done.current_state().balance == 700
  all_green = all_green &&
    check(
      "Effect 重试两败后成",
      effect1_ok,
      "3 次执行（2 冲突 1 成），版本 \{effect_done.version()}，balance \{effect_done.current_state().balance}",
    )
  // 演示 2：Validation（业务拒）——词表 exhausted，零重试直上抛（重放同结果）。
  let mut invalid_calls = 0
  let invalid_watcher = fn(
    state : @bank.AccountState,
    cmd : @bank.AccountCommand,
  ) -> Array[@bank.AccountEvent] raise @command.CommandError {
    invalid_calls = invalid_calls + 1
    @bank.account_handler(state, cmd)
  }
  let invalid_root = @aggregate.AggregateRoot::new(
    "demo-effect-2",
    invalid_watcher,
    @event.EventApplier::Single(@bank.account_applier),
    @bank.AccountState::init(),
  )
  let mut effect2_rejected = false
  try {
    // 未激活户取款 = 业务拒（Validation 族）→ 状态机不重试，原错上抛
    let _ = invalid_root.exec_with_effect(
      @bank.WithdrawMoney(100),
      @bank.account_retry_machine(),
      @bank.account_retry_hooks_pure(),
      fn(_ms) { () },
    )
  } catch {
    e =>
      effect2_rejected = match e {
        @command.CommandError::InvalidCommand(_) => true
        _ => false
      }
  }
  let effect2_ok = effect2_rejected && invalid_calls == 1
  all_green = all_green &&
    check(
      "Effect Validation 直上抛",
      effect2_ok,
      "业务拒零重试（执行 \{invalid_calls} 次，重放同结果）",
    )
  // ========== ⑤ 销户闭环（dispatch 门面:执行+落库+提交一步）==========
  let closable = @aggregate.AggregateRoot::from_events(
    aggregate_id,
    store.load(aggregate_id, 0),
    @bank.account_handler,
    @event.EventApplier::Single(@bank.account_applier),
    @bank.account_empty_state(),
  )
  let records = store.to_event_store()
  let after_withdraw = @mooncmd.dispatch(
    records,
    None,
    closable,
    @bank.WithdrawMoney(1200),
  )
  let closed = @mooncmd.dispatch(
    records,
    None,
    after_withdraw,
    @bank.CloseAccount,
  )
  let closed_state = closed.current_state()
  let close_ok = closed_state.balance == 0 && !closed_state.is_active
  all_green = all_green &&
    check(
      "销户闭环",
      close_ok,
      "户名 \{closed_state.name}，balance = \{closed_state.balance}，active = \{closed_state.is_active}",
    )
  // ========== ⑥ 快照加速：销户事件已随 dispatch 落库；快照@v3 全量态 + 尾部 v4/v5 重放 ≡ 全量 ==========
  let snapshottable = @aggregate.AggregateRoot::from_events(
    aggregate_id,
    loaded,
    @bank.account_handler,
    @event.EventApplier::Single(@bank.account_applier),
    @bank.account_empty_state(),
  )
  let snapshot = snapshottable.to_snapshot()
  let from_snapshot = @aggregate.AggregateRoot::from_events(
    aggregate_id,
    store.load(aggregate_id, snapshot.version),
    @bank.account_handler,
    @event.EventApplier::Single(@bank.account_applier),
    snapshot.state,
  )
  let snap_state = from_snapshot.current_state()
  let snap_ok = from_snapshot.version() == 5 &&
    snap_state.balance == 0 &&
    !snap_state.is_active
  all_green = all_green &&
    check(
      "快照等价",
      snap_ok,
      "快照@v\{snapshot.version}（balance \{snapshot.state.balance}）+ 尾部重放 → v\{from_snapshot.version()}，balance \{snap_state.balance}",
    )
  // 与全量重放对照：两径同果
  let full_replay = @aggregate.AggregateRoot::from_events(
    aggregate_id,
    store.load(aggregate_id, 0),
    @bank.account_handler,
    @event.EventApplier::Single(@bank.account_applier),
    @bank.account_empty_state(),
  )
  let full_state = full_replay.current_state()
  let equiv_ok = full_replay.version() == from_snapshot.version() &&
    full_state.balance == snap_state.balance &&
    full_state.is_active == snap_state.is_active &&
    full_state.name == snap_state.name
  all_green = all_green &&
    check(
      "两径同果",
      equiv_ok,
      "快照径 ≡ 全量径：v\{full_replay.version()} / balance \{full_state.balance} / 户名 \{full_state.name}",
    )
  // ========== ⑦ PM 泵：跨聚合编排（役13b 词表 gen 产物 transfer_pm 直消费）==========
  // watch MoneyWithdrawn/AccountClosed → 命令直通发往 account-2；saga 态按
  // 信封 aggregate_id 分片（SnapshotStore 键 transfer:<saga_id>）。EventStore
  // 无全局流（ADR 语义差）——泵序责任在调用方，单事件直喂。
  let pm_ledger : Array[Map[String, (@bank.TransferPmState, Int32)]] = [Map([])]
  let pm_store : @store.SnapshotStore[String, @bank.TransferPmState] = {
    save: (key, state, version, _ts) => pm_ledger[0][key] = (state, version),
    load: key => pm_ledger[0].get(key),
  }
  let pm_sent : Array[(String, @bank.AccountCommand)] = []
  let runner = @mooncmd.ProcessManagerRunner::new(
    @bank.transfer_pm(),
    pm_store,
    (target, cmd) => pm_sent.push((target, cmd)),
  )
  let pm_p1 = runner.pump_event(
    @event.EventMessage::new(@bank.MoneyWithdrawn(30), "pm-account-1", 1),
  )
  let pm_p2 = runner.pump_event(
    @event.EventMessage::new(@bank.MoneyWithdrawn(12), "pm-account-1", 2),
  )
  let pm_p3 = runner.pump_event(
    @event.EventMessage::new(@bank.MoneyDeposited(5), "pm-account-1", 3),
  )
  let pm_p4 = runner.pump_event(
    @event.EventMessage::new(@bank.AccountClosed, "pm-account-1", 4),
  )
  let pm_pump_ok = pm_p1 && pm_p2 && !pm_p3 && pm_p4
  // 命令直通映射逐条对拍（match 不作 && 链操作元——家法，块臂上提）
  let pm_cmds_ok = if pm_sent.length() == 3 {
    let c0 = match pm_sent[0] {
      ("account-2", @bank.DepositMoney(30)) => true
      _ => false
    }
    let c1 = match pm_sent[1] {
      ("account-2", @bank.DepositMoney(12)) => true
      _ => false
    }
    let c2 = match pm_sent[2] {
      ("account-2", @bank.CloseAccount) => true
      _ => false
    }
    c0 && c1 && c2
  } else {
    false
  }
  let pm_loaded = (pm_store.load)("transfer:pm-account-1") catch { _ => None }
  let pm_state_ok = match pm_loaded {
    Some((state, version)) =>
      state.transferred == 42 && state.closed && version == 4
    None => false
  }
  all_green = all_green &&
    check(
      "PM 泵 watch 直通",
      pm_pump_ok,
      "withdraw×2 + AccountClosed 全处理，MoneyDeposited 子集外跳过（sent = \{pm_sent.length()} 令）",
    )
  all_green = all_green &&
    check(
      "PM 命令直通映射", pm_cmds_ok, "account-2 ← DepositMoney(30)/DepositMoney(12)/CloseAccount（金额保真）",
    )
  all_green = all_green &&
    check(
      "PM saga 态持久", pm_state_ok, "transfer:pm-account-1 @v4：transferred = 42（30+12 累加），closed = true",
    )
  // ========== 终判 ==========
  if all_green {
    println(
      "EXAMPLE:PASS — mooncmd 全链自证（聚合/命令/事件/落库/并发/销户/快照/PM 泵）",
    )
  } else {
    println("EXAMPLE:FAIL — 见上方 [FAIL] 行")
  }
}
