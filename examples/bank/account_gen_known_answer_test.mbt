// ===== gen 产物结构钉(known-answer 形;自足零依赖)=====
// 开源克隆者可跑——纯字符串断言,无外部依赖。
// 职责:防 gen 产物被手改/意外截断(结构级守卫)。
// 逐字节再生成门在维护侧工具链(骨架生成器所在仓),不随本模块发布;
// 词表改动须经再生成刷新产物,禁手写(生成纪律)。

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

///|
test "contract scaffold structural pin: key tests present" {
  let content = @fs.read_file_to_string(
    "examples/bank/account_contract_wbtest.mbt",
  )
  assert_true(content.contains("// ===== account 聚合契约门"))
  assert_true(content.contains("生成物禁手写"))
  assert_true(
    content.contains(
      "test \"account init contract: fields equal declared inits\"",
    ),
  )
  assert_true(
    content.contains(
      "test \"account wire contract: roundtrip identity per event\"",
    ),
  )
}

///|
test "retry machine structural pin: key lines present" {
  let content = @fs.read_file_to_string("examples/bank/account_retry_gen.mbt")
  assert_true(content.contains("生成物禁手写"))
  assert_true(
    content.contains(
      "pub fn account_retry_machine() -> @aggregate.RetryMachine",
    ),
  )
  // 词表值回声(源 account_retry.toml:max=3 backoff=fixed interval=100)
  assert_true(content.contains("max=3"))
  assert_true(content.contains("backoff = fixed"))
  assert_true(content.contains("interval = 100"))
}
