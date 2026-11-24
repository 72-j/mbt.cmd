// ===== GENERATED FILE — DO NOT EDIT（生成物禁手写，const.md §7）=====
// 源表：/home/thy/bitbang2/mooncmd/examples/bank_cmd_gen/account_pm.toml（schema 0.2.0）
// 再生：moonx thy1016/cmd@latest /home/thy/bitbang2/mooncmd/examples/bank_cmd_gen/account_pm.toml
// 绑定器：thy1016/cmd/gen(pm 方言 parse/validate/emit 三件套)
// Process Manager 方言：事件→命令字段直通映射（interested 封闭集 / handle 字段直通 / apply 机械演化，封闭集 = agg 方言同源 set|add|append|remove）；计算级映射 = stub zone 留手写（红线7），runner 装配（emit 闭包 / SnapshotStore）= 组合根手写。

///|
/// TransferPmState——transfer PM 状态（saga 实例态）。
pub(all) struct TransferPmState {
  transferred : Int32
  closed : Bool
}

///|
/// 零值态（init 契约：字段缺省值直通）。
pub fn TransferPmState::init() -> TransferPmState {
  { transferred: 0, closed: false, }
}

///|
/// interested——watch 行封闭集（子集匹配，未列事件 = 不相关）。
pub fn transfer_pm_interested(e : AccountEvent) -> Bool {
  match e {
    MoneyWithdrawn(_) => true
    AccountClosed => true
    _ => false
  }
}

///|
/// saga_id_of——saga 分片键（信封 aggregate_id 直读）。
pub fn transfer_pm_saga_id_of(
  msg : @event.EventMessage[String, AccountEvent],
) -> String {
  msg.aggregate_id
}

///|
/// handle——事件→命令直通映射（未列事件 = 空发射）。
pub fn transfer_pm_handle(
  _state : TransferPmState,
  e : AccountEvent,
) -> Array[@mooncmd.DirectedCommand[AccountCommand]] {
  match e {
    MoneyWithdrawn(amount) =>
      [{ target_aggregate_id: "account-2", command: DepositMoney(amount), }]
    AccountClosed =>
      [{ target_aggregate_id: "account-2", command: CloseAccount, }]
    _ => []
  }
}

///|
/// apply——状态机械演化（封闭集同 agg 方言；未列事件 = 透传）。
pub fn transfer_pm_apply(
  state : TransferPmState,
  e : AccountEvent,
) -> TransferPmState {
  match e {
    MoneyWithdrawn(amount) => {
      let s0 = { ..state, transferred: state.transferred + amount, }
      s0
    }
    AccountClosed => {
      let s0 = { ..state, closed: true, }
      s0
    }
    _ => state
  }
}

///|
/// transfer_pm——Process Manager 记录面（事件→命令跨聚合编排；
/// 词表驱动直通映射；命令发射闭包由组合根注入）。
pub fn transfer_pm() -> @mooncmd.ProcessManager[
  TransferPmState,
  AccountCommand,
  AccountEvent,
] {
  {
    name: "transfer",
    init_state: TransferPmState::init,
    interested: transfer_pm_interested,
    saga_id_of: transfer_pm_saga_id_of,
    handle: transfer_pm_handle,
    apply: transfer_pm_apply,
  }
}
