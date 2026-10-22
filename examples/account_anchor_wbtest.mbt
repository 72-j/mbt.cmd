// ===== Account 行为金锚（役7 D-MG;命令脚本 → 事件流/终态已知答案）=====

///|
test "account aggregate behavior anchor: script known answers" {
  let hooks = account_hooks()
  let mut state = AccountState::init()
  let events : Array[AccountEvent] = []
  let _ = events
  let chain : Array[AccountEvent] = []
  let script : Array[AccountCommand] = [
    CreateAccount("main", 100),
    DepositMoney(50),
    WithdrawMoney(30),
    CloseAccount,
  ]
  for cmd in script {
    let produced = match account_decide(state, cmd, hooks) {
      Ok(produced) => produced
      Err(msg) => fail("decide failed: \{msg}")
    }
    for event in produced {
      chain.push(event)
      state = event.apply(state)
    }
  }
  assert_true(
    chain == [
      AccountCreated("main", 100),
      MoneyDeposited(50),
      MoneyWithdrawn(30),
      AccountClosed,
    ],
  )
  assert_eq(state.name, "main")
  assert_eq(state.balance, 120)
  assert_eq(state.is_active, false)
}
