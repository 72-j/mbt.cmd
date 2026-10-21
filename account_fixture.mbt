// account_fixture.mbt
//! 示例聚合（银行账户）：test_command / test_event 的夹具类型。
//! 只含数据定义；命令处理 account_handler 在 test_command.mbt，
//! 事件应用 account_applier_single/batch 与 empty_account_state 在 test_event.mbt。

///|
/// 账户状态
pub(all) struct AccountState {
  name : String
  balance : Int32
  is_active : Bool
}

///|
/// 账户命令：开户 / 存款 / 取款 / 销户
pub(all) enum AccountCommand {
  CreateAccount(String, Int32)
  DepositMoney(Int32)
  WithdrawMoney(Int32)
  CloseAccount
}

///|
/// 账户事件：已发生的事实
pub(all) enum AccountEvent {
  AccountCreated(String, Int32)
  MoneyDeposited(Int32)
  MoneyWithdrawn(Int32)
  AccountClosed
}
