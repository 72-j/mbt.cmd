// 时间源注入罐（役：clock/id_gen 槽位代码化）——
// ①定钟全链:注钟后 exec 多命令,事件时间戳全取注入值(全链零直读钟);
// ②同输入对拍:同脚本+同定钟+计数器 id_gen,两次独立运行事件流逐字段
// 相等(确定性证据)+ id 消费序/ca 因果链钉死。

///|
/// ①定钟全链罐
test "时间注入:定钟全链 - 事件时间戳全取注入值" {
  let fixed = 1700000000000L
  let mut aggregate = @aggregate.AggregateRoot::new(
    "account-clock-001",
    account_handler,
    @event.EventApplier::Single(account_applier_single),
    empty_account_state(),
    clock=fn() { fixed },
  )
  aggregate = aggregate.exec(AccountCommand::CreateAccount("Dana", 100)) catch {
    _ => panic()
  }
  aggregate = aggregate.exec(AccountCommand::DepositMoney(50)) catch {
    _ => panic()
  }
  let events = aggregate.uncommitted_events()
  assert_eq(events.length(), 2)
  assert_eq(events[0].timestamp, fixed)
  assert_eq(events[1].timestamp, fixed)
  assert_true(
    account_event_equal(
      events[0].event,
      AccountEvent::AccountCreated("Dana", 100),
    ),
  )
  assert_true(
    account_event_equal(events[1].event, AccountEvent::MoneyDeposited(50)),
  )
}

///|
/// 事件判等(黑盒伪包看不见 derive 的 Eq impl——变体直比)
fn account_event_equal(a : AccountEvent, b : AccountEvent) -> Bool {
  match (a, b) {
    (AccountCreated(n1, v1), AccountCreated(n2, v2)) => n1 == n2 && v1 == v2
    (MoneyDeposited(v1), MoneyDeposited(v2)) => v1 == v2
    (MoneyWithdrawn(v1), MoneyWithdrawn(v2)) => v1 == v2
    (AccountClosed, AccountClosed) => true
    _ => false
  }
}

///|
/// 计数器 id_gen(Array 单元闭包 = 引用型,推进可见)
fn make_counter_id_gen() -> () -> String {
  let cell = [0]
  fn() {
    cell[0] += 1
    "evt-\{cell[0]}"
  }
}

///|
/// ②定脚本执行器:同钟同 id_gen 同三命令,返回未提交事件流
fn run_scripted_flow(
  aggregate_id : String,
) -> Array[@event.EventMessage[String, AccountEvent]] {
  let mut aggregate = @aggregate.AggregateRoot::new(
    aggregate_id,
    account_handler,
    @event.EventApplier::Single(account_applier_single),
    empty_account_state(),
    clock=fn() { 1700000123456L },
    id_gen=make_counter_id_gen(),
  )
  aggregate = aggregate.exec(AccountCommand::CreateAccount("Eve", 200)) catch {
    _ => panic()
  }
  aggregate = aggregate.exec(AccountCommand::DepositMoney(30)) catch {
    _ => panic()
  }
  aggregate = aggregate.exec(AccountCommand::WithdrawMoney(10)) catch {
    _ => panic()
  }
  aggregate.uncommitted_events()
}

///|
/// ②同输入同事件流对拍罐
test "时间注入:同输入同钟同 id_gen - 两次运行事件流逐字段相等" {
  let run_a = run_scripted_flow("account-replay-001")
  let run_b = run_scripted_flow("account-replay-001")
  assert_eq(run_a.length(), 3)
  assert_eq(run_b.length(), 3)
  for i in 0..<run_a.length() {
    let ea = run_a[i]
    let eb = run_b[i]
    assert_true(account_event_equal(ea.event, eb.event))
    assert_eq(ea.event_id, eb.event_id)
    assert_eq(ea.aggregate_id, eb.aggregate_id)
    assert_eq(ea.aggregate_version, eb.aggregate_version)
    assert_eq(ea.correlation_id, eb.correlation_id)
    assert_eq(ea.causation_id, eb.causation_id)
    assert_eq(ea.user_id, eb.user_id)
    assert_eq(ea.timestamp, eb.timestamp)
    assert_eq(ea.schema_version, eb.schema_version)
  }
  // id 消费序:每命令 envelope 先吃一格(command_id),事件再吃一格
  // (event_id);correlation/causation 从 cmd 继承
  assert_eq(run_a[0].event_id, "evt-2")
  assert_eq(run_a[0].causation_id, "evt-1")
  assert_eq(run_a[1].event_id, "evt-4")
  assert_eq(run_a[2].event_id, "evt-6")
  assert_eq(run_a[0].timestamp, 1700000123456L)
}
