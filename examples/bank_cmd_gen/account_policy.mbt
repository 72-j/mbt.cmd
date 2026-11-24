// ===== Account 裁决策略 stub（仅缺位时落,regen 永不覆写——宪法 stub-zone）=====
// 源表：mooncmd/examples/bank_cmd/account_agg.toml
// 钩子槽位与 account_gen.mbt 的 declare 声明配对（分派/工厂/胶水 = gen 机械面——
// 本件只补槽体）。裁决 = 手写闭包（mooncmd const.md 红线7 裁决不入表）：
// 每槽 = let 闭包,Err("TODO(<Cmd>)") 即未填;演化槽 abort 即未填（静默恒等是数据黑洞）。

///|
pub let account_create_account : (AccountState, String, Int32) -> Result[
  Array[AccountEvent],
  String,
] = (state, name, initial) => {
  // TODO(CreateAccount): 裁决体待填——红线7（Ok([<Event>(载荷)]) 或 Err(拒绝原因)）
  let _ = (state, name, initial)
  Err("TODO(CreateAccount): 裁决体待填——红线7")
}

///|
pub let account_deposit_money : (AccountState, Int32) -> Result[
  Array[AccountEvent],
  String,
] = (state, amount) => {
  // TODO(DepositMoney): 裁决体待填——红线7（Ok([<Event>(载荷)]) 或 Err(拒绝原因)）
  let _ = (state, amount)
  Err("TODO(DepositMoney): 裁决体待填——红线7")
}

///|
pub let account_withdraw_money : (AccountState, Int32) -> Result[
  Array[AccountEvent],
  String,
] = (state, amount) => {
  // TODO(WithdrawMoney): 裁决体待填——红线7（Ok([<Event>(载荷)]) 或 Err(拒绝原因)）
  let _ = (state, amount)
  Err("TODO(WithdrawMoney): 裁决体待填——红线7")
}

///|
pub let account_close_account : (AccountState) -> Result[
  Array[AccountEvent],
  String,
] = state => {
  // TODO(CloseAccount): 裁决体待填——红线7（Ok([<Event>(载荷)]) 或 Err(拒绝原因)）
  let _ = state
  Err("TODO(CloseAccount): 裁决体待填——红线7")
}
