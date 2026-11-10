// ===== 手写词汇层（配方行 1–3）=====
// 对应词表分区：[aggregate.state] / [[aggregate.events]] /
// [[aggregate.commands]]。设计工作表 = examples/bank/account_agg.toml
// （本文件即该表的手写投影）；形状对照件 = examples/bank/account_gen.mbt。

///|
// [aggregate.state] fields 三行 → 结构三字段；初值对齐表 init 列。
// pub(all)：框架要跨包构造/演化本状态，pub(all) 是跨包可写面。
#derive(Eq)
pub(all) struct AccountState {
  name : String
  balance : Int32
  is_active : Bool
}

///|
// derive(Eq) 的隐式方法晋升已弃用——显式晋升判等面（编译器 [0079] 正解）。
pub extend AccountState with Eq::{not_equal, equal}

///|
pub fn AccountState::init() -> AccountState {
  { name: "", balance: 0, is_active: false, }
}

///|
// [[aggregate.events]] 四行 → 四变体，载荷字段照表（位置形元组载荷）。
#derive(Eq)
pub(all) enum AccountEvent {
  AccountCreated(String, Int32)
  MoneyDeposited(Int32)
  MoneyWithdrawn(Int32)
  AccountClosed
}

///|
pub extend AccountEvent with Eq::{not_equal, equal}

///|
// [[aggregate.commands]] 四行 → 四变体，与事件一一对应。
#derive(Eq)
pub(all) enum AccountCommand {
  CreateAccount(String, Int32)
  DepositMoney(Int32)
  WithdrawMoney(Int32)
  CloseAccount
}

///|
pub extend AccountCommand with Eq::{not_equal, equal}
