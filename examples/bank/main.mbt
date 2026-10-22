///|
/// mooncmd 全链自证示例（可执行）：银行账户聚合从定义到落库的一跑。
/// 叙事序 = 消费方接入序：① 定义聚合 → ② 内存命令链 → ③ SQLite 落库
/// 与重放重建 → ④ 乐观并发拒写 → ⑤ 销户闭环 → ⑥ 快照加速等价。
/// 终行 EXAMPLE:PASS。

///|
/// ① 聚合三件套（消费方自定义）：状态 / 命令 / 事件

///|
/// ① 聚合三件套（役7 转正:词表 gen 形）——类型/apply/分派 = account_gen.mbt
/// （源表 account_agg.toml,黄金门逐字节）;裁决 = account_policy.mbt 手写钩子
/// （红线7）。金样对照 = 行为金锚 + EXAMPLE:PASS 续绿（account_gate_wbtest）。

///|
/// 桥接:gen 分派（String 错域）→ 框架命令错误（InvalidCommand 同界,
/// demo 守卫语义原样——策略件四钩子升级为 demo 守卫,错误串逐字保留）
fn account_handler(
  state : AccountState,
  cmd : AccountCommand,
) -> Result[Array[AccountEvent], @command.CommandError] {
  match account_decide(state, cmd, account_hooks()) {
    Ok(events) => Ok(events)
    Err(msg) => Err(@command.CommandError::InvalidCommand(msg))
  }
}

///|
fn account_applier(state : AccountState, event : AccountEvent) -> AccountState {
  event.apply(state)
}

///|
fn account_empty_state() -> AccountState {
  AccountState::init()
}

///|
/// 事件序列化 = gen 产物流 wire（役7+ D-MG-6;格式契约见 account_contract_wbtest roundtrip 钉）
fn account_serialize(event : AccountEvent) -> Bytes {
  @utf8.encode(event.to_wire())
}

///|
fn account_deserialize(data : Bytes) -> AccountEvent raise {
  let text = @utf8.decode(data)
  match AccountEvent::from_wire(text) {
    Some(event) => event
    None => abort("bad event wire payload: \{text}")
  }
}

///|
fn account_type_name(event : AccountEvent) -> String {
  match event {
    AccountCreated(_, _) => "AccountCreated"
    MoneyDeposited(_) => "MoneyDeposited"
    MoneyWithdrawn(_) => "MoneyWithdrawn"
    AccountClosed => "AccountClosed"
  }
}

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
      account_handler,
      @event.EventApplier::Single(account_applier),
      account_empty_state(),
    )
    .exec(CreateAccount("Demo Holder", 1000))
    .exec(DepositMoney(500))
    .exec(WithdrawMoney(300))
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
    ":memory:", account_serialize, account_deserialize, account_type_name,
  )
  store.append(aggregate_id, uncommitted)
  let loaded = store.load(aggregate_id, 0)
  let load_ok = loaded.length() == 3
  all_green = all_green &&
    check("落库读回", load_ok, "load 回 \{loaded.length()} 事件")
  let rebuilt = @aggregate.AggregateRoot::from_events(
    aggregate_id,
    loaded,
    account_handler,
    @event.EventApplier::Single(account_applier),
    account_empty_state(),
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
  // ========== ④b Effect 重试状态机（役8 续）：两败后成走机；Validation 直上抛 ==========
  // 演示 1：FailTwiceThenOk——前两次 Conflict（Duplicate 族→词表 retry），第三次成。
  // wait = 打印型假钟（真钟 = async sleep，宿主接）;词表 fixed interval=100。
  let mut effect_calls = 0
  let effect_handler = fn(
    state : AccountState,
    _cmd : AccountCommand,
  ) -> Result[Array[AccountEvent], @command.CommandError] {
    effect_calls = effect_calls + 1
    if effect_calls <= 2 {
      // 模拟瞬时乐观并发冲突（同类：另一写者抢先）——Duplicate 族，词表 retry
      ignore(state)
      Err(@command.CommandError::Conflict(1, 2))
    } else {
      // 冲突消除，业务裁决放行（等价 deposit_money 守卫通过形）
      ignore(state)
      Ok([MoneyDeposited(700)])
    }
  }
  let retry_root = @aggregate.AggregateRoot::new(
    "demo-effect-1",
    effect_handler,
    @event.EventApplier::Single(account_applier),
    AccountState::init(),
  )
  let effect_done = retry_root.exec_with_effect(
    DepositMoney(700),
    account_retry_machine(),
    account_retry_hooks_pure(),
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
    state : AccountState,
    cmd : AccountCommand,
  ) -> Result[Array[AccountEvent], @command.CommandError] {
    invalid_calls = invalid_calls + 1
    account_handler(state, cmd)
  }
  let invalid_root = @aggregate.AggregateRoot::new(
    "demo-effect-2",
    invalid_watcher,
    @event.EventApplier::Single(account_applier),
    AccountState::init(),
  )
  let mut effect2_rejected = false
  try {
    // 未激活户取款 = 业务拒（Validation 族）→ 状态机不重试，原错上抛
    let _ = invalid_root.exec_with_effect(
      WithdrawMoney(100),
      account_retry_machine(),
      account_retry_hooks_pure(),
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
  // ========== ⑤ 销户闭环（dispatch 门面:执行+落库+提交一步——役9 编排层）==========
  let closable = @aggregate.AggregateRoot::from_events(
    aggregate_id,
    store.load(aggregate_id, 0),
    account_handler,
    @event.EventApplier::Single(account_applier),
    account_empty_state(),
  )
  let records = store.to_event_store()
  let after_withdraw = @mooncmd.dispatch(records, None, closable, WithdrawMoney(1200))
  let closed = @mooncmd.dispatch(records, None, after_withdraw, CloseAccount)
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
    account_handler,
    @event.EventApplier::Single(account_applier),
    account_empty_state(),
  )
  let snapshot = snapshottable.to_snapshot()
  let from_snapshot = @aggregate.AggregateRoot::from_events(
    aggregate_id,
    store.load(aggregate_id, snapshot.version),
    account_handler,
    @event.EventApplier::Single(account_applier),
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
    account_handler,
    @event.EventApplier::Single(account_applier),
    account_empty_state(),
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
  // ========== 终判 ==========
  if all_green {
    println(
      "EXAMPLE:PASS — mooncmd 全链自证（聚合/命令/事件/落库/并发/销户/快照）",
    )
  } else {
    println("EXAMPLE:FAIL — 见上方 [FAIL] 行")
  }
}
