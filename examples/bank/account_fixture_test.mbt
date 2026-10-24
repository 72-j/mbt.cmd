///|
/// 银行账户夹具（测试包私有）：AccountState / AccountCommand / AccountEvent。
/// 2026-10-21：自生产面 account_fixture.mbt 迁入测试包——业务夹具
/// 不入公开契约面（spec §7.6 非目标；ADR-MC-007 后独立仓发布面同口径）。
/// 使用示例（消费方视角）见 examples/ 可执行示例包。
struct AccountState {
  name : String
  balance : Int32
  is_active : Bool
}

///|
enum AccountCommand {
  CreateAccount(String, Int32)
  DepositMoney(Int32)
  WithdrawMoney(Int32)
  CloseAccount
}

///|
enum AccountEvent {
  AccountCreated(String, Int32)
  MoneyDeposited(Int32)
  MoneyWithdrawn(Int32)
  AccountClosed
}
