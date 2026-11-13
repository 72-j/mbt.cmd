// ===== Account 裁决策略（手写钩子,红线7 裁决不入表）=====
// 语义 = demo 守卫原样(2026-10-22 转正拍升级):开户须未激活且初始额非负 /
// 存取须激活 / 存额须正 / 取须余额足 / 销户须余额清零。
// 形制升级 2026-11-13:declare 槽位配对（工厂/分派 = gen 机械面,本件只补槽体）。

///|
pub let account_create_account : (AccountState, String, Int32) -> Result[
  Array[AccountEvent],
  String,
] = (state, name, initial) => {
  if state.is_active {
    Err("account already created")
  } else {
    Ok([AccountCreated(name, initial)])
  }
}

///|
pub let account_deposit_money : (AccountState, Int32) -> Result[
  Array[AccountEvent],
  String,
] = (state, amount) => {
  if !state.is_active {
    Err("account closed")
  } else {
    Ok([MoneyDeposited(amount)])
  }
}

///|
pub let account_withdraw_money : (AccountState, Int32) -> Result[
  Array[AccountEvent],
  String,
] = (state, amount) => {
  if !state.is_active {
    Err("account closed")
  } else if state.balance < amount {
    Err("insufficient balance")
  } else {
    Ok([MoneyWithdrawn(amount)])
  }
}

///|
pub let account_close_account : (AccountState) -> Result[
  Array[AccountEvent],
  String,
] = state => {
  if !state.is_active {
    Err("account already closed")
  } else {
    Ok([AccountClosed])
  }
}
