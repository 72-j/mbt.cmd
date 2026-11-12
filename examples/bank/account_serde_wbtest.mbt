///|
/// 役10 serde wire 投影罐三件（消费面罐;gen 产物 account_serde_gen.mbt 的
/// 消费径验证）——roundtrip 四变体 + 金罐字节锚 + 负例分变体（禁 catch _）。
/// AccountEvent 只 derive(Eq)（gen 面）——断言走 == 面非 assert_eq（Debug 缺）。
/// 工具链账（Phase 0 探针役）：#deprecated 参数表须单行;负例罐 try 体
/// Some 包装形两臂同型;fmt 削 try 前缀成 postfix catch 正形。

///|
/// 金罐字节锚 + roundtrip 四变体（外部标签制三形全谱）
test "serde roundtrip 四变体 + 金罐字节锚" {
  inspect(
    @json.to_string(AccountCreated("ada", 100)),
    content="{\"AccountCreated\":[\"ada\",100]}",
  )
  inspect(
    @json.to_string(MoneyDeposited(42)),
    content="{\"MoneyDeposited\":42}",
  )
  inspect(@json.to_string(MoneyWithdrawn(7)), content="{\"MoneyWithdrawn\":7}")
  inspect(@json.to_string(AccountClosed), content="\"AccountClosed\"")
  let a = (
    @json.from_string(@json.to_string(AccountCreated("ada", 100))) :
    AccountEvent)
  assert_true(a == AccountCreated("ada", 100))
  let b = (@json.from_string(@json.to_string(MoneyDeposited(42))) : AccountEvent)
  assert_true(b == MoneyDeposited(42))
  let c = (@json.from_string(@json.to_string(MoneyWithdrawn(7))) : AccountEvent)
  assert_true(c == MoneyWithdrawn(7))
  let d = (@json.from_string("\"AccountClosed\"") : AccountEvent)
  assert_true(d == AccountClosed)
}

///|
/// 负例分变体（未知变体名拒收;禁 catch _ 吞现场——UnknownVariant 精确捕获）
test "serde 负例分变体" {
  let got : AccountEvent? = Some(
    (@json.from_string("{\"Ghost\":7}") : AccountEvent),
  ) catch {
    e => {
      assert_true(e is @serde.UnknownVariant(..))
      None
    }
  }
  assert_true(got is None)
}
