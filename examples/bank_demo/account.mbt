// ===== account.mbt —— PM 消费面（组合根样板 + trait 手写径）=====
// 从 main.mbt 分区拆出（main = 叙事驱动，本件 = PM 面定义）。分区：
//   ① 组合根样板（内存 SnapshotStore + 演示事件流）
//   ② trait 手写径（行为面 trait + 适配器 + RelayTo 实例）
// 参照：.playground/bank_demo 房间分区样式（玩耍区同构形）。

// ========== ① 组合根样板 ==========

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

// ========== ② trait 手写径 ==========

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

// ========== ③ 聚合根组装辅助（组装聚合根 + event/command 中间层包装）==========

///|
/// event/command 中间层包装（EventApplier 单产；裁决 = account_policy 红线7）
fn account_applier() -> @event.EventApplier[
  @bank.AccountState,
  @bank.AccountEvent,
] {
  @event.EventApplier::Single(@bank.account_applier)
}

///|
/// 内存事件仓组装（:memory: 演示形；生产换持久路径）
fn account_store() -> @store.SQLiteEventStore[@bank.AccountEvent] raise {
  @store.SQLiteEventStore::new(
    ":memory:", @bank.account_serialize, @bank.account_deserialize, @bank.account_type_name,
  )
}

///|
/// 聚合根组装（标准三件套：account_handler + applier + empty_state）
fn account_root_new(
  id : String,
) -> @aggregate.AggregateRoot[
  String,
  @bank.AccountState,
  @bank.AccountCommand,
  @bank.AccountEvent,
] {
  @aggregate.AggregateRoot::new(
    id,
    @bank.account_handler,
    account_applier(),
    @bank.account_empty_state(),
  )
}

///|
/// 聚合根组装（自定义裁决钩子变体——Effect 演示用；空态 = 词表 init）
fn account_root_with(
  id : String,
  handler : (@bank.AccountState, @bank.AccountCommand) -> Array[
    @bank.AccountEvent,
  ] raise @command.CommandError,
) -> @aggregate.AggregateRoot[
  String,
  @bank.AccountState,
  @bank.AccountCommand,
  @bank.AccountEvent,
] {
  @aggregate.AggregateRoot::new(
    id,
    handler,
    account_applier(),
    @bank.AccountState::init(),
  )
}

///|
/// 聚合根重放重建（标准三件套）
fn account_root_from_events(
  id : String,
  events : Array[@event.EventMessage[String, @bank.AccountEvent]],
) -> @aggregate.AggregateRoot[
  String,
  @bank.AccountState,
  @bank.AccountCommand,
  @bank.AccountEvent,
] {
  @aggregate.AggregateRoot::from_events(
    id,
    events,
    @bank.account_handler,
    account_applier(),
    @bank.account_empty_state(),
  )
}

///|
/// 聚合根重放重建（快照态基座变体——尾部重放径）
fn account_root_from_state(
  id : String,
  events : Array[@event.EventMessage[String, @bank.AccountEvent]],
  state : @bank.AccountState,
) -> @aggregate.AggregateRoot[
  String,
  @bank.AccountState,
  @bank.AccountCommand,
  @bank.AccountEvent,
] {
  @aggregate.AggregateRoot::from_events(
    id,
    events,
    @bank.account_handler,
    account_applier(),
    state,
  )
}
