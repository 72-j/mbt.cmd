///|
/// 快照等价夹具本地化——bank 业务夹具住 examples/bank 测试包
/// （跨包不可见，AGENTS 测试件三手病③），此处按等价语义取最小账户夹具；
/// 业务全形版（含命令校验）仍归 bank。

///|
/// 最小账户事件（快照等价夹具）
enum SnapAccountEvent {
  AccountCreated(String, Int32)
  MoneyDeposited(Int32)
  MoneyWithdrawn(Int32)
}

///|
/// 最小账户状态
struct SnapAccountState {
  name : String
  balance : Int32
  is_active : Bool
}

///|
/// 事件应用器（单个事件）
fn snap_account_applier(
  state : SnapAccountState,
  event : SnapAccountEvent,
) -> SnapAccountState {
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
  }
}

///|
/// 空的账户状态
fn empty_snap_account_state() -> SnapAccountState {
  { name: "", balance: 0, is_active: false, }
}

///|
/// 命令处理器占位（from_events 随行存证不触碰，命令面取 Unit）
fn snap_account_handler(
  _state : SnapAccountState,
  _cmd : Unit,
) -> Array[SnapAccountEvent] raise @command.CommandError {
  // 恒空命令面;raise 注记 = CommandHandler 槽型精确匹配(非 raise 不协变入槽)
  if false {
    raise @command.CommandError::InvalidCommand("unreachable")
  }
  []
}

///|
/// FR-MC-5：快照等价——快照态起跑 + 尾部重放 ≡ 全量重放
test "快照等价：快照态起跑 + 尾部重放 ≡ 全量重放" {
  let handler = snap_account_handler
  let applier = @event.EventApplier::Single(snap_account_applier)
  let e1 = @event.EventMessage::new(
    SnapAccountEvent::AccountCreated("Snap", 1000),
    "snap-1",
    1,
  )
  let e2 = @event.EventMessage::new(
    SnapAccountEvent::MoneyDeposited(500),
    "snap-1",
    2,
  )
  let e3 = @event.EventMessage::new(
    SnapAccountEvent::MoneyWithdrawn(300),
    "snap-1",
    3,
  )
  let full = @aggregate.AggregateRoot::from_events(
    "snap-1",
    [e1, e2, e3],
    handler,
    applier,
    empty_snap_account_state(),
  )
  let at_v2 = @aggregate.AggregateRoot::from_events(
    "snap-1",
    [e1, e2],
    handler,
    applier,
    empty_snap_account_state(),
  )
  let snap = at_v2.to_snapshot()
  assert_eq(snap.version, 2)
  let rebuilt = @aggregate.AggregateRoot::from_events(
    "snap-1",
    [e3],
    handler,
    applier,
    snap.state,
  )
  assert_eq(rebuilt.version(), full.version())
  let fs_ = full.current_state()
  let rs_ = rebuilt.current_state()
  assert_eq(fs_.name, rs_.name)
  assert_eq(fs_.balance, rs_.balance)
  assert_eq(fs_.is_active, rs_.is_active)
}

///|
/// FR-MC-5：快照存储记录面 roundtrip（测试内内存实现，不新增生产后端——ADR-MC-004）
test "快照存储记录面 roundtrip（内存实现）" {
  let saved : Array[@store.Snapshot[String, SnapAccountState]] = []
  let store : @store.SnapshotStore[String, SnapAccountState] = {
    save: fn(id, s, v, _t) { saved.push(@store.Snapshot::new(id, s, v)) },
    load: fn(id) {
      let mut found = None
      for s in saved {
        if s.aggregate_id == id {
          found = Some((s.state, s.version))
        }
      }
      found
    },
  }
  let handler = snap_account_handler
  let applier = @event.EventApplier::Single(snap_account_applier)
  let agg = @aggregate.AggregateRoot::from_events(
    "snap-2",
    [
      @event.EventMessage::new(
        SnapAccountEvent::AccountCreated("Snap2", 1000),
        "snap-2",
        1,
      ),
      @event.EventMessage::new(
        SnapAccountEvent::MoneyDeposited(500),
        "snap-2",
        2,
      ),
    ],
    handler,
    applier,
    empty_snap_account_state(),
  )
  let snap = agg.to_snapshot()
  (store.save)(snap.aggregate_id, snap.state, snap.version, snap.timestamp)
  match (store.load)("snap-2") {
    Some((s, v)) => {
      assert_eq(v, 2)
      assert_eq(s.balance, 1500)
    }
    None => assert_false(true)
  }
}
