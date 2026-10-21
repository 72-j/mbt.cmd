///|
/// 命令处理器
fn account_handler(
  state : @mooncmd.AccountState,
  cmd : @mooncmd.AccountCommand,
) -> Result[Array[@mooncmd.AccountEvent], @mooncmd.CommandError] {
  match cmd {
    @mooncmd.CreateAccount(name, initial_balance) =>
      if state.is_active {
        Err(@mooncmd.CommandError::InvalidCommand("Account already exists"))
      } else if name == "" {
        Err(@mooncmd.CommandError::InvalidCommand("Name cannot be empty"))
      } else if initial_balance < 0 {
        Err(
          @mooncmd.CommandError::InvalidCommand(
            "Initial balance cannot be negative",
          ),
        )
      } else {
        Ok([@mooncmd.AccountEvent::AccountCreated(name, initial_balance)])
      }
    @mooncmd.DepositMoney(amount) =>
      if !state.is_active {
        Err(@mooncmd.CommandError::InvalidCommand("Account is not active"))
      } else if amount <= 0 {
        Err(
          @mooncmd.CommandError::InvalidCommand(
            "Deposit amount must be positive",
          ),
        )
      } else {
        Ok([@mooncmd.AccountEvent::MoneyDeposited(amount)])
      }
    @mooncmd.WithdrawMoney(amount) =>
      if !state.is_active {
        Err(@mooncmd.CommandError::InvalidCommand("Account is not active"))
      } else if amount <= 0 {
        Err(
          @mooncmd.CommandError::InvalidCommand(
            "Withdrawal amount must be positive",
          ),
        )
      } else if amount > state.balance {
        Err(@mooncmd.CommandError::InvalidCommand("Insufficient funds"))
      } else {
        Ok([@mooncmd.AccountEvent::MoneyWithdrawn(amount)])
      }
    @mooncmd.CloseAccount =>
      if !state.is_active {
        Err(@mooncmd.CommandError::InvalidCommand("Account is already closed"))
      } else if state.balance != 0 {
        Err(
          @mooncmd.CommandError::InvalidCommand(
            "Cannot close account with non-zero balance",
          ),
        )
      } else {
        Ok([@mooncmd.AccountEvent::AccountClosed])
      }
  }
}

///|
test "@mooncmd.AggregateRoot 执行创建账户命令" {
  let aggregate_id = "account-002"
  let handler = account_handler
  let applier = @mooncmd.EventApplier::Single(account_applier_single)

  let mut aggregate = @mooncmd.AggregateRoot::new(
    aggregate_id,
    handler,
    applier,
    empty_account_state(),
  )

  // 创建命令
  let cmd = @mooncmd.CommandMessage::new(
    @mooncmd.AccountCommand::CreateAccount("John Doe", 1000),
  )

  // 执行命令
  let result = aggregate.execute(cmd)

  // 验证执行成功
  match result {
    Ok(agg) => {
      aggregate = agg

      // 验证版本更新
      assert_eq(aggregate.version(), 1)

      // 验证有一个未提交事件
      let uncommitted = aggregate.uncommitted_events()
      assert_eq(uncommitted.length(), 1)

      // 验证事件内容
      match uncommitted[0].event {
        @mooncmd.AccountCreated(name, balance) => {
          assert_eq(name, "John Doe")
          assert_eq(balance, 1000)
        }
        _ => fail("期望 AccountCreated 事件，实得其它变体")
      }

      // 验证状态已更新
      let state = aggregate.current_state()
      assert_eq(state.name, "John Doe")
      assert_eq(state.balance, 1000)
      assert_eq(state.is_active, true)
    }
    Err(_) => fail("期望命令执行成功，实得 Err")
  }
}

///|
test "@mooncmd.AggregateRoot 执行取款命令" {
  let aggregate_id = "account-004"
  let handler = account_handler
  let applier = @mooncmd.EventApplier::Single(account_applier_single)

  let mut aggregate = @mooncmd.AggregateRoot::new(
    aggregate_id,
    handler,
    applier,
    empty_account_state(),
  )

  // 创建账户并存入资金
  let create_cmd = @mooncmd.CommandMessage::new(
    @mooncmd.AccountCommand::CreateAccount("Bob Wilson", 1000),
  )
  aggregate = match aggregate.execute(create_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  let deposit_cmd = @mooncmd.CommandMessage::new(
    @mooncmd.AccountCommand::DepositMoney(500),
  )
  aggregate = match aggregate.execute(deposit_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  // 执行取款命令
  let withdraw_cmd = @mooncmd.CommandMessage::new(
    @mooncmd.AccountCommand::WithdrawMoney(300),
  )
  aggregate = match aggregate.execute(withdraw_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  // 验证状态
  let state = aggregate.current_state()
  assert_eq(state.balance, 1200)
  assert_eq(aggregate.version(), 3)
}

///|
test "@mooncmd.AggregateRoot 命令失败处理" {
  let aggregate_id = "account-005"
  let handler = account_handler
  let applier = @mooncmd.EventApplier::Single(account_applier_single)

  let aggregate = @mooncmd.AggregateRoot::new(
    aggregate_id,
    handler,
    applier,
    empty_account_state(),
  )

  // 尝试从空账户取款（应该失败）
  let withdraw_cmd = @mooncmd.CommandMessage::new(
    @mooncmd.AccountCommand::WithdrawMoney(100),
  )
  let result = aggregate.execute(withdraw_cmd)

  // 验证命令失败
  match result {
    Err(@mooncmd.CommandError::InvalidCommand(msg)) =>
      inspect(msg, content="Account is not active")
    _ => fail("期望 InvalidCommand，实得其它结果")
  }

  // 验证状态未改变
  assert_eq(aggregate.version(), 0)
  assert_eq(aggregate.uncommitted_events().length(), 0)
}

///|
test "@mooncmd.AggregateRoot 余额不足错误" {
  let aggregate_id = "account-006"
  let handler = account_handler
  let applier = @mooncmd.EventApplier::Single(account_applier_single)

  let mut aggregate = @mooncmd.AggregateRoot::new(
    aggregate_id,
    handler,
    applier,
    empty_account_state(),
  )

  // 创建账户
  let create_cmd = @mooncmd.CommandMessage::new(
    @mooncmd.AccountCommand::CreateAccount("Alice", 100),
  )
  aggregate = match aggregate.execute(create_cmd) {
    Ok(agg) => agg
    Err(_) => panic()
  }

  // 尝试取出超过余额的金额
  let withdraw_cmd = @mooncmd.CommandMessage::new(
    @mooncmd.AccountCommand::WithdrawMoney(200),
  )
  let result = aggregate.execute(withdraw_cmd)

  // 验证失败
  match result {
    Err(@mooncmd.CommandError::InvalidCommand(msg)) =>
      inspect(msg, content="Insufficient funds")
    _ => fail("期望 InvalidCommand，实得其它结果")
  }

  // 验证状态未改变
  let state = aggregate.current_state()
  assert_eq(state.balance, 100)
}
