// ===== account 聚合契约门（D-MG-5 脚手架;源表 mooncmd/examples/bank/account_agg.toml;生成物禁手写,regen 刷新;白盒件——同包命名空间,夹具/黑盒本地型零遮蔽）=====

///|
/// init 契约:字段初值 = 词表值区声明（形状即契约）
test "account init contract: fields equal declared inits" {
  let state = AccountState::init()
  assert_eq(state.name, "")
  assert_eq(state.balance, 0)
  assert_eq(state.is_active, false)
}

///|
/// wire roundtrip 契约:每事件样本 to_wire→from_wire 恒等（Eq）
test "account wire contract: roundtrip identity per event" {
  let samples : Array[AccountEvent] = [
    AccountCreated("contract", 1),
    MoneyDeposited(1),
    MoneyWithdrawn(1),
    AccountClosed,
  ]
  for sample in samples {
    match AccountEvent::from_wire(sample.to_wire()) {
      Some(back) => assert_true(back.to_wire() == sample.to_wire())
      None => fail("wire roundtrip lost payload")
    }
  }
}

///|
// 场景契约脚手架（红线7:业务语义人填）——重放等价/并发拒写样板见 examples/bank/main.mbt
// §③④ 与 store_test 乐观并发钉;填充点 = 命令脚本 → 期望事件流/终态表。
