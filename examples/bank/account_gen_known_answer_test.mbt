// ===== gen 产物结构钉(役7 known-answer 形;自足零依赖)=====
// 开源克隆者可跑——不依赖 skelschema,纯字符串断言。
// 职责:防 gen 产物被手改/意外截断(结构级守卫)。
// 完整逐字节黄金门在 bitbang workspace(内部门面,此处分层)。

///|
test "gen product structural known-answer: key lines present" {
  let content = @fs.read_file_to_string("examples/bank/account_gen.mbt")
  // 结构钉:关键声明行存在性
  assert_true(content.contains("GENERATED FILE — DO NOT EDIT"))
  assert_true(content.contains("pub(all) struct AccountState"))
  assert_true(content.contains("pub(all) enum AccountEvent"))
  assert_true(content.contains("pub(all) enum AccountCommand"))
  assert_true(content.contains("pub fn AccountEvent::apply"))
  assert_true(content.contains("pub fn account_decide"))
  assert_true(content.contains("pub(all) struct AccountDecideHooks"))
  // 事件变体词形
  assert_true(content.contains("AccountCreated"))
  assert_true(content.contains("MoneyDeposited"))
  assert_true(content.contains("MoneyWithdrawn"))
  assert_true(content.contains("AccountClosed"))
  // 策略钩子方法名(四钩子)
  assert_true(content.contains("create_account"))
  assert_true(content.contains("deposit_money"))
  assert_true(content.contains("withdraw_money"))
  assert_true(content.contains("close_account"))
}
