// ===== Account 裁决策略（手写钩子,红线7 裁决不入表）=====
// 语义 = 夹具同族:开户须未激活 / 存取须激活 / 取须余额足 / 销户须激活。

///|
pub fn account_hooks() -> AccountDecideHooks {
  {
    create_account: (state, name, initial) =>
      if state.is_active {
        Err("account already created")
      } else {
        Ok([AccountCreated(name, initial)])
      },
    deposit_money: (state, amount) =>
      if !state.is_active {
        Err("account closed")
      } else {
        Ok([MoneyDeposited(amount)])
      },
    withdraw_money: (state, amount) =>
      if !state.is_active {
        Err("account closed")
      } else if state.balance < amount {
        Err("insufficient balance")
      } else {
        Ok([MoneyWithdrawn(amount)])
      },
    close_account: state =>
      if !state.is_active {
        Err("account already closed")
      } else {
        Ok([AccountClosed])
      },
  }
}
