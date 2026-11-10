// ===== 手写验收清单（README「生成物包含」段逐项自配）=====
// ① init 值契约 ② apply 已知答案 ③ wire 往返恒等 + 负例
// ④ 裁决守卫两面 ⑤ 全链自证（exec → append → 重建，注固定钟/标识源）
// ⑥ 乐观并发守门（DuplicateVersion）

///|
test "init values match vocabulary defaults" {
  let state = AccountState::init()
  assert_eq(state.name, "")
  assert_eq(state.balance, 0)
  assert_eq(state.is_active, false)
}

///|
test "apply reproduces known answers" {
  let state = AccountState::init()
  let state = AccountCreated("Alice", 1000).apply(state)
  assert_eq(state.name, "Alice")
  assert_eq(state.balance, 1000)
  assert_eq(state.is_active, true)
  let state = MoneyDeposited(500).apply(state)
  let state = MoneyWithdrawn(300).apply(state)
  assert_eq(state.balance, 1200)
  let state = AccountClosed.apply(state)
  assert_eq(state.is_active, false)
}

///|
test "wire roundtrip is identity" {
  let events = [
    AccountCreated("Alice", 1000),
    MoneyDeposited(500),
    MoneyWithdrawn(300),
    AccountClosed,
  ]
  for event in events {
    assert_true(AccountEvent::from_wire(event.to_wire()) == Some(event))
  }
}

///|
test "wire rejects malformed lines" {
  assert_true(AccountEvent::from_wire("2\tMoneyDeposited\t5") is None)
  assert_true(AccountEvent::from_wire("1\tMoneyDeposited\t5\textra") is None)
  assert_true(AccountEvent::from_wire("1\tNoSuchEvent\t5") is None)
  assert_true(AccountEvent::from_wire("garbage") is None)
}

///|
test "decision guards accept and reject" {
  let hooks = account_hooks()
  let fresh = AccountState::init()
  assert_true((hooks.create_account)(fresh, "Alice", 1000) is Ok(_))
  assert_true((hooks.deposit_money)(fresh, 500) is Err(_))
  let open = AccountCreated("Alice", 1000).apply(fresh)
  assert_true((hooks.deposit_money)(open, 500) is Ok(_))
  assert_true((hooks.deposit_money)(open, 0) is Err(_))
  assert_true((hooks.withdraw_money)(open, 999999) is Err(_))
  assert_true((hooks.withdraw_money)(open, 300) is Ok(_))
  assert_true((hooks.close_account)(open) is Err(_))
  let drained = MoneyWithdrawn(1000).apply(open)
  assert_true((hooks.close_account)(drained) is Ok(_))
}

///|
test "full chain: exec, persist, rebuild" {
  // 注固定钟 + 顺序标识源：同输入 + 同注钟 + 同 id 源 ⇒ 同事件流（可复现罐）。
  let seq = [0]
  let id_gen = fn() {
    seq[0] = seq[0] + 1
    "evt-\{seq[0]}"
  }
  let fixed_clock = fn() { 1000L }
  let root0 = @aggregate.AggregateRoot::new(
    "acc-001",
    account_handler,
    @event.EventApplier::Single(account_applier),
    AccountState::init(),
    clock=fixed_clock,
    id_gen~,
  )
  let root = root0
    .exec(CreateAccount("Alice", 1000))
    .exec(DepositMoney(400))
    .exec(WithdrawMoney(100))
  assert_eq(root.version(), 3)
  assert_eq(root.current_state().balance, 1300)
  // 落库：未提交事件流一次性 append（内存端口；生产径换 SQLiteEventStore）。
  let store = MemoryEventStore::new().to_event_store()
  (store.append)(store, "acc-001", root.uncommitted_events())
  // 业务拒零痕迹：拒因不推版、不入流。
  let untouched = root
  let after_reject = root.exec(WithdrawMoney(999999)) catch { _ => untouched }
  assert_eq(after_reject.version(), 3)
  assert_eq(after_reject.uncommitted_events().length(), 3)
  // 重建：从存储事件流 rebuild，状态与原根一致（事件溯源本质）。
  let rebuilt = @aggregate.AggregateRoot::from_events(
    "acc-001",
    (store.load)(store, "acc-001", 0),
    account_handler,
    @event.EventApplier::Single(account_applier),
    AccountState::init(),
    clock=fixed_clock,
    id_gen~,
  )
  assert_eq(rebuilt.version(), 3)
  assert_eq(rebuilt.current_state().name, root.current_state().name)
  assert_eq(rebuilt.current_state().balance, root.current_state().balance)
  assert_eq(rebuilt.current_state().is_active, root.current_state().is_active)
  // 确定性注源：信封可复现——每命令消费两格 id（命令信封 1 + 事件信封 1），
  // 事件 correlation_id 承自命令信封（裸命令直 exec 时为空串；经显式
  // CommandMessage::with_correlation / Router 链才携追溯值）、timestamp
  // 承自注钟。
  let first = (store.load)(store, "acc-001", 0)[0]
  assert_eq(first.event_id, "evt-2")
  assert_eq(first.correlation_id, "")
  assert_eq(first.timestamp, 1000L)
}

///|
test "append guards optimistic concurrency" {
  let root = account_root("acc-002").exec(CreateAccount("Bob", 100))
  let store = MemoryEventStore::new().to_event_store()
  (store.append)(store, "acc-002", root.uncommitted_events())
  // 同批次重放 = 首事件版本撞当前版本 → DuplicateVersion 拒写（端口合同），
  // 且无半截写入。
  let mut duplicated = false
  (store.append)(store, "acc-002", root.uncommitted_events()) catch {
    err =>
      match err {
        @store.EventStoreError::DuplicateVersion(_) => duplicated = true
        _ => duplicated = false
      }
  }
  assert_true(duplicated)
  assert_eq((store.load)(store, "acc-002", 0).length(), 1)
}
