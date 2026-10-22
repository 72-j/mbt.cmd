///|
/// 事件应用器（单个事件）
fn account_applier_single(
  state : AccountState,
  event : AccountEvent,
) -> AccountState {
  match event {
    AccountCreated(name, initial_balance) =>
      { name, balance: initial_balance, is_active: true, }
    MoneyDeposited(amount) =>
      {
        balance: state.balance + amount,
        is_active: state.is_active,
        name: state.name,
      }
    MoneyWithdrawn(amount) =>
      {
        balance: state.balance - amount,
        is_active: state.is_active,
        name: state.name,
      }
    AccountClosed =>
      { is_active: false, balance: state.balance, name: state.name, }
  }
}

///|
/// 事件应用器（批量事件）
fn account_applier_batch(
  state : AccountState,
  events : Array[AccountEvent],
) -> AccountState {
  events.fold(init=state, fn(s, e) { account_applier_single(s, e) })
}

///|
/// 空的账户状态
fn empty_account_state() -> AccountState {
  { name: "", balance: 0, is_active: false, }
}

///|
test "@aggregate.AggregateRoot 提交事件" {
  let aggregate_id = "account-007"
  let handler = account_handler
  let applier = @event.EventApplier::Single(account_applier_single)

  let mut aggregate = @aggregate.AggregateRoot::new(
    aggregate_id,
    handler,
    applier,
    empty_account_state(),
  )

  // 执行多个命令
  let create_cmd = @command.CommandMessage::new(
    AccountCommand::CreateAccount("Charlie", 500),
  )
  aggregate = match aggregate.execute(create_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  let deposit_cmd = @command.CommandMessage::new(
    AccountCommand::DepositMoney(300),
  )
  aggregate = match aggregate.execute(deposit_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  // 验证有未提交事件
  assert_eq(aggregate.uncommitted_events().length(), 2)

  // 提交事件
  aggregate = aggregate.commit()

  // 验证未提交事件已清空
  assert_eq(aggregate.uncommitted_events().length(), 0)

  // 验证版本保持不变
  assert_eq(aggregate.version(), 2)

  // 验证状态保持
  let state = aggregate.current_state()
  assert_eq(state.balance, 800)
}

///|
test "@aggregate.AggregateRoot 从事件恢复" {
  let aggregate_id = "account-008"
  let handler = account_handler
  let applier = @event.EventApplier::Single(account_applier_single)

  // 创建一些历史事件
  let events = [
    @event.EventMessage::new(
      AccountEvent::AccountCreated("David Brown", 1000),
      aggregate_id,
      1,
    ),
    @event.EventMessage::new(AccountEvent::MoneyDeposited(500), aggregate_id, 2),
    @event.EventMessage::new(AccountEvent::MoneyWithdrawn(200), aggregate_id, 3),
  ]

  // 从事件恢复聚合根
  let aggregate = @aggregate.AggregateRoot::from_events(
    aggregate_id,
    events,
    handler,
    applier,
    empty_account_state(),
  )

  // 验证版本
  assert_eq(aggregate.version(), 3)

  // 验证状态
  let state = aggregate.current_state()
  assert_eq(state.name, "David Brown")
  assert_eq(state.balance, 1300)
  assert_true(state.is_active)

  // 验证没有未提交事件
  assert_eq(aggregate.uncommitted_events().length(), 0)
}

///|
test "@aggregate.AggregateRoot 使用批量事件应用器" {
  let aggregate_id = "account-009"
  let handler = account_handler
  let applier = @event.EventApplier::Batch(account_applier_batch)

  let mut aggregate = @aggregate.AggregateRoot::new(
    aggregate_id,
    handler,
    applier,
    empty_account_state(),
  )

  // 执行命令
  let create_cmd = @command.CommandMessage::new(
    AccountCommand::CreateAccount("Eve", 800),
  )
  aggregate = match aggregate.execute(create_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  // 验证状态
  let state = aggregate.current_state()
  assert_eq(state.name, "Eve")
  assert_eq(state.balance, 800)
  assert_true(state.is_active)
}

///|
test "@aggregate.AggregateRoot 关闭账户" {
  let aggregate_id = "account-010"
  let handler = account_handler
  let applier = @event.EventApplier::Single(account_applier_single)

  let mut aggregate = @aggregate.AggregateRoot::new(
    aggregate_id,
    handler,
    applier,
    empty_account_state(),
  )

  // 创建账户
  let create_cmd = @command.CommandMessage::new(
    AccountCommand::CreateAccount("Frank", 0),
  )
  aggregate = match aggregate.execute(create_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  // 关闭账户
  let close_cmd = @command.CommandMessage::new(AccountCommand::CloseAccount)
  aggregate = match aggregate.execute(close_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  // 验证状态
  let state = aggregate.current_state()
  assert_true(!state.is_active)
  assert_eq(state.balance, 0)
  assert_eq(aggregate.version(), 2)
}

///|
test "@aggregate.AggregateRoot 关闭有余额的账户失败" {
  let aggregate_id = "account-011"
  let handler = account_handler
  let applier = @event.EventApplier::Single(account_applier_single)

  let mut aggregate = @aggregate.AggregateRoot::new(
    aggregate_id,
    handler,
    applier,
    empty_account_state(),
  )

  // 创建账户并存入资金
  let create_cmd = @command.CommandMessage::new(
    AccountCommand::CreateAccount("Grace", 100),
  )
  aggregate = match aggregate.execute(create_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  // 尝试关闭有余额的账户
  let close_cmd = @command.CommandMessage::new(AccountCommand::CloseAccount)
  let result = aggregate.execute(close_cmd)

  // 验证失败
  match result {
    Err(@command.CommandError::InvalidCommand(msg)) =>
      assert_eq(msg, "Cannot close account with non-zero balance")
    _ => assert_false(false)
  }
}

///|
test "@aggregate.AggregateRoot 多次执行命令累积事件" {
  let aggregate_id = "account-013"
  let handler = account_handler
  let applier = @event.EventApplier::Single(account_applier_single)

  let mut aggregate = @aggregate.AggregateRoot::new(
    aggregate_id,
    handler,
    applier,
    empty_account_state(),
  )

  // 创建账户
  let create_cmd = @command.CommandMessage::new(
    AccountCommand::CreateAccount("Ivy", 100),
  )
  aggregate = match aggregate.execute(create_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  // 多次存款
  for _i in 1..<4 {
    let deposit_cmd = @command.CommandMessage::new(
      AccountCommand::DepositMoney(100),
    )
    aggregate = match aggregate.execute(deposit_cmd) {
      Ok(agg) => agg
      Err(_) => panic()
    }
  }

  // 验证版本和事件数量
  assert_eq(aggregate.version(), 4)
  assert_eq(aggregate.uncommitted_events().length(), 4)

  // 验证最终状态
  let state = aggregate.current_state()
  assert_eq(state.balance, 400)
}

///|
test "@aggregate.AggregateRoot 空事件数组恢复" {
  let aggregate_id = "account-014"
  let handler = account_handler
  let applier = @event.EventApplier::Single(account_applier_single)

  // 从空事件数组恢复
  let aggregate = @aggregate.AggregateRoot::from_events(
    aggregate_id,
    [],
    handler,
    applier,
    empty_account_state(),
  )

  // 验证初始状态
  assert_eq(aggregate.version(), 0)
  assert_eq(aggregate.uncommitted_events().length(), 0)

  let state = aggregate.current_state()
  assert_eq(state.balance, 0)
}

///|
test "@aggregate.AggregateRoot 命令元数据传递" {
  let aggregate_id = "account-015"
  let handler = account_handler
  let applier = @event.EventApplier::Single(account_applier_single)

  let mut aggregate = @aggregate.AggregateRoot::new(
    aggregate_id,
    handler,
    applier,
    empty_account_state(),
  )

  // 创建带元数据的命令
  let cmd = @command.CommandMessage::new(
      AccountCommand::CreateAccount("Jack", 500),
    )
    .with_correlation("corr-123")
    .with_user("user-456")

  aggregate = match aggregate.execute(cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  // 验证事件中包含元数据
  let events = aggregate.uncommitted_events()
  assert_eq(events.length(), 1)
  assert_eq(events[0].correlation_id, "corr-123")
}
