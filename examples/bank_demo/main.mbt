///|
/// mooncmd 全链自证示例（可执行）：银行账户聚合从定义到落库的一跑。
/// 叙事序 = 消费方接入序：① 定义聚合 → ② 内存命令链 → ③ SQLite 落库
/// 与重放重建 → ④ 乐观并发拒写 → ⑤ 销户闭环 → ⑥ 快照加速等价 →
/// ⑦ PM 泵跨聚合编排（gen 径 + trait 手写径，同泵双形）。
/// 终行 EXAMPLE:PASS。

///|
fn check(label : String, ok : Bool, detail : String) -> Bool {
  let verdict = if ok { "PASS" } else { "FAIL" }
  println("[\{verdict}] \{label} — \{detail}")
  ok
}

///|
/// PM 演示用内存 SnapshotStore（Map 单元引用捕获；save/load 记录面直构）。
fn pm_memory_store() -> @store.SnapshotStore[String, @bank.TransferPmState] {
  let ledger : Array[Map[String, (@bank.TransferPmState, Int32)]] = [Map([])]
  {
    save: (key, state, version, _ts) => ledger[0][key] = (state, version),
    load: key => ledger[0].get(key),
  }
}

///|
/// ⑦ 演示事件流（transfer 全程：两笔取出 + 子集外存入 + 销户；版本位连续）。
fn pm_flow(
  saga_id : String,
) -> Array[@event.EventMessage[String, @bank.AccountEvent]] {
  [
    @event.EventMessage::new(@bank.MoneyWithdrawn(30), saga_id, 1),
    @event.EventMessage::new(@bank.MoneyWithdrawn(12), saga_id, 2),
    @event.EventMessage::new(@bank.MoneyDeposited(5), saga_id, 3),
    @event.EventMessage::new(@bank.AccountClosed, saga_id, 4),
  ]
}

///|
/// ⑦ PM 行为面 trait（消费侧手写径形）：MoonBit 无泛型 trait（泛型只在
/// 结构体/函数）——行为面按聚合具体型立（方法收 Self 位置形），适配器
/// 同包具体化进框架泛型记录面；ProcessManagerRunner 泵消费形唯一，泵零改。
trait TransferRelayBehavior {
  fn name(Self) -> String
  fn init_state(Self) -> @bank.TransferPmState
  fn interested(Self, @bank.AccountEvent) -> Bool
  fn saga_id_of(Self, @event.EventMessage[String, @bank.AccountEvent]) -> String
  fn handle(Self, @bank.TransferPmState, @bank.AccountEvent) -> Array[
    @mooncmd.DirectedCommand[@bank.AccountCommand],
  ]
  fn apply(Self, @bank.TransferPmState, @bank.AccountEvent) -> @bank.TransferPmState
}

///|
/// 行为面 → 记录面适配（trait 对象直调，[0079] 零晋升）。
fn transfer_pm_of_behavior(
  behavior : &TransferRelayBehavior,
) -> @mooncmd.ProcessManager[
  @bank.TransferPmState,
  @bank.AccountCommand,
  @bank.AccountEvent,
] {
  {
    name: behavior.name(),
    init_state: () => behavior.init_state(),
    interested: e => behavior.interested(e),
    saga_id_of: msg => behavior.saga_id_of(msg),
    handle: (state, e) => behavior.handle(state, e),
    apply: (state, e) => behavior.apply(state, e),
  }
}

///|
/// 用户手写径示例：RelayTo——转账中继行为（target 实例字段参数化；
/// 语义与 account_pm_gen.mbt 的 transfer_pm 记录面孪生：watch
/// MoneyWithdrawn/AccountClosed → 命令直通发往 target）。
priv struct RelayTo {
  target : String
}

///|
impl TransferRelayBehavior for RelayTo with fn name(_self) -> String {
  "transfer"
}

///|
impl TransferRelayBehavior for RelayTo with fn init_state(_self) -> @bank.TransferPmState {
  @bank.TransferPmState::init()
}

///|
impl TransferRelayBehavior for RelayTo with fn interested(_self, e) -> Bool {
  match e {
    @bank.MoneyWithdrawn(_) => true
    @bank.AccountClosed => true
    _ => false
  }
}

///|
impl TransferRelayBehavior for RelayTo with fn saga_id_of(_self, msg) -> String {
  msg.aggregate_id
}

///|
impl TransferRelayBehavior for RelayTo with fn handle(self, _state, e) -> Array[
  @mooncmd.DirectedCommand[@bank.AccountCommand],
] {
  match e {
    @bank.MoneyWithdrawn(amount) =>
      [
        {
          target_aggregate_id: self.target,
          command: @bank.DepositMoney(amount),
        },
      ]
    @bank.AccountClosed =>
      [{ target_aggregate_id: self.target, command: @bank.CloseAccount, }]
    _ => []
  }
}

///|
impl TransferRelayBehavior for RelayTo with fn apply(_self, state, e) -> @bank.TransferPmState {
  match e {
    @bank.MoneyWithdrawn(amount) =>
      { ..state, transferred: state.transferred + amount, }
    @bank.AccountClosed => { ..state, closed: true, }
    _ => state
  }
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
  // ========== ⑦ PM 泵：跨聚合编排（gen 径 + trait 手写径，同泵双形）==========
  // EventStore 无全局流（ADR 语义差）——泵序责任在调用方，事件流直喂。
  let pm_sent : Array[(String, @bank.AccountCommand)] = []
  let pm_store = pm_memory_store()
  let gen_runner = @mooncmd.ProcessManagerRunner::new(
    @bank.transfer_pm(),
    pm_store,
    (target, cmd) => pm_sent.push((target, cmd)),
  )
  let gen_handled = gen_runner.pump_events(pm_flow("pm-account-1"))
  let pm_first_ok = match pm_sent[0] {
    ("account-2", @bank.DepositMoney(30)) => true
    _ => false
  }
  let pm_loaded = (pm_store.load)("transfer:pm-account-1") catch { _ => None }
  let pm_state_ok = match pm_loaded {
    Some((state, version)) =>
      state.transferred == 42 && state.closed && version == 4
    None => false
  }
  let gen_ok = gen_handled == 3 &&
    pm_sent.length() == 3 &&
    pm_first_ok &&
    pm_state_ok
  all_green = all_green &&
    check(
      "PM 泵 gen 径（transfer_pm 记录面）", gen_ok, "4 事件 3 处理（MoneyDeposited 子集外跳过）；DepositMoney(30)→account-2；transferred = 42、closed @v4",
    )
  // trait 手写径：RelayTo 行为面 impl → 适配器 → 同一台泵（语义孪生对拍）。
  let pm_sent2 : Array[(String, @bank.AccountCommand)] = []
  let pm_store2 = pm_memory_store()
  let trait_runner = @mooncmd.ProcessManagerRunner::new(
    transfer_pm_of_behavior(RelayTo::{ target: "account-2", }),
    pm_store2,
    (target, cmd) => pm_sent2.push((target, cmd)),
  )
  let trait_handled = trait_runner.pump_events(pm_flow("pm-account-1"))
  let pm_loaded2 = (pm_store2.load)("transfer:pm-account-1") catch { _ => None }
  let pm_state2_ok = match pm_loaded2 {
    Some((state, version)) =>
      state.transferred == 42 && state.closed && version == 4
    None => false
  }
  let trait_ok = trait_handled == 3 && pm_sent2.length() == 3 && pm_state2_ok
  all_green = all_green &&
    check(
      "PM 泵 trait 手写径（行为面 impl 同泵）",
      trait_ok,
      "RelayTo impl → 适配器进同一台泵：sent = \{pm_sent2.length()}，transferred = 42、closed @v4（与 gen 径孪生）",
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
