// ===== 手写行为层（配方行 4–5 + 框架装配）=====
// apply 演化链 = 词表 evolve 指令的手写投影（封闭集四指令 set/add/append/
// remove 直写记录更新链）；裁决分派骨架只做载荷拆包，裁决体在 policy.mbt
// （红线 7：业务裁决不进 apply 链）。

///|
// evolve 指令逐条 → 一段更新链（"set name=name" 等机械演化；
// 同字段后写覆前写）。封闭集外的演化属裁决，不在此处。
pub fn AccountEvent::apply(
  self : AccountEvent,
  state : AccountState,
) -> AccountState {
  match self {
    AccountCreated(name, initial) => {
      let s0 = { ..state, name, }
      let s1 = { ..s0, balance: initial, }
      let s2 = { ..s1, is_active: true, }
      s2
    }
    MoneyDeposited(amount) => {
      let s0 = { ..state, balance: state.balance + amount, }
      s0
    }
    MoneyWithdrawn(amount) => {
      let s0 = { ..state, balance: state.balance - amount, }
      s0
    }
    AccountClosed => {
      let s0 = { ..state, is_active: false, }
      s0
    }
  }
}

///|
// 事件应用器：框架 EventApplier::Single 槽位要的 (S, E) -> S 形。
pub fn account_applier(
  state : AccountState,
  event : AccountEvent,
) -> AccountState {
  event.apply(state)
}

///|
// 裁决钩子（记录型函数面）：每命令一槽，槽型 Result[Array[E], String]。
// 纪录字段作函数调用要带括号：(hooks.deposit_money)(state, amount)。
pub(all) struct AccountDecideHooks {
  create_account : (AccountState, String, Int32) -> Result[
    Array[AccountEvent],
    String,
  ]
  deposit_money : (AccountState, Int32) -> Result[Array[AccountEvent], String]
  withdraw_money : (AccountState, Int32) -> Result[Array[AccountEvent], String]
  close_account : (AccountState) -> Result[Array[AccountEvent], String]
}

///|
// 裁决分派骨架（只做载荷拆包与转发；裁决体 = policy.mbt 的钩子实现）。
pub fn account_decide(
  state : AccountState,
  cmd : AccountCommand,
  hooks : AccountDecideHooks,
) -> Result[Array[AccountEvent], String] {
  match cmd {
    CreateAccount(name, initial) => (hooks.create_account)(state, name, initial)
    DepositMoney(amount) => (hooks.deposit_money)(state, amount)
    WithdrawMoney(amount) => (hooks.withdraw_money)(state, amount)
    CloseAccount => (hooks.close_account)(state)
  }
}

///|
// 命令处理器：框架槽位要的纯函数 (S, C) -> Array[E] raise CommandError。
// 钩子的 String 错域在此翻译为 CommandError（业务拒 = InvalidCommand 同界，
// 错误串逐字保留）。
pub fn account_handler(
  state : AccountState,
  cmd : AccountCommand,
) -> Array[AccountEvent] raise @command.CommandError {
  match account_decide(state, cmd, account_hooks()) {
    Ok(events) => events
    Err(msg) => raise @command.CommandError::InvalidCommand(msg)
  }
}

///|
// 装配：聚合根 = 标识 + 处理器 + 应用器 + 初态。确定性测试可在
// AggregateRoot::new / from_events 的 clock? / id_gen? 槽注固定源
// （见本包测试件「全链自证」罐）。
pub fn account_root(
  aggregate_id : String,
) -> @aggregate.AggregateRoot[
  String,
  AccountState,
  AccountCommand,
  AccountEvent,
] {
  @aggregate.AggregateRoot::new(
    aggregate_id,
    account_handler,
    account_event_applier(),
    AccountState::init(),
  )
}

///|
// event/command 中间层包装件（bank_demo account.mbt 分区③同款对位）:
// EventApplier::Single 槽位的构造唯一入口——组装点零内联。
pub fn account_event_applier() -> @event.EventApplier[
  AccountState,
  AccountEvent,
] {
  @event.EventApplier::Single(account_applier)
}

///|
// 注入变体组装（确定性罐用）:clock/id_gen 显式槽转发——同输入+同注钟+
// 同 id 源 ⇒ 同事件流。缺省形见 account_root（框架缺省钟/标识源）。
pub fn account_root_with_sources(
  aggregate_id : String,
  clock~ : () -> Int64,
  id_gen~ : () -> String,
) -> @aggregate.AggregateRoot[
  String,
  AccountState,
  AccountCommand,
  AccountEvent,
] {
  @aggregate.AggregateRoot::new(
    aggregate_id,
    account_handler,
    account_event_applier(),
    AccountState::init(),
    clock~,
    id_gen~,
  )
}

///|
// 重放重建注入变体(与 account_root_with_sources 配对的 rebuild 径)。
pub fn account_root_from_events_with_sources(
  aggregate_id : String,
  events : Array[@event.EventMessage[String, AccountEvent]],
  clock~ : () -> Int64,
  id_gen~ : () -> String,
) -> @aggregate.AggregateRoot[
  String,
  AccountState,
  AccountCommand,
  AccountEvent,
] {
  @aggregate.AggregateRoot::from_events(
    aggregate_id,
    events,
    account_handler,
    account_event_applier(),
    AccountState::init(),
    clock~,
    id_gen~,
  )
}
