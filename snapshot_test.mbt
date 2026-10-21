///|
/// 役5（FR-MC-5）：快照等价——快照态起跑 + 尾部重放 ≡ 全量重放
test "快照等价：快照态起跑 + 尾部重放 ≡ 全量重放" {
  let handler = account_handler
  let applier = @mooncmd.EventApplier::Single(account_applier_single)
  let e1 = @mooncmd.EventMessage::new(
    @mooncmd.AccountEvent::AccountCreated("Snap", 1000),
    "snap-1",
    1,
  )
  let e2 = @mooncmd.EventMessage::new(
    @mooncmd.AccountEvent::MoneyDeposited(500),
    "snap-1",
    2,
  )
  let e3 = @mooncmd.EventMessage::new(
    @mooncmd.AccountEvent::MoneyWithdrawn(300),
    "snap-1",
    3,
  )
  let full = @mooncmd.AggregateRoot::from_events(
    "snap-1",
    [e1, e2, e3],
    handler,
    applier,
    empty_account_state(),
  )
  let at_v2 = @mooncmd.AggregateRoot::from_events(
    "snap-1",
    [e1, e2],
    handler,
    applier,
    empty_account_state(),
  )
  let snap = at_v2.to_snapshot()
  assert_eq(snap.version, 2)
  let rebuilt = @mooncmd.AggregateRoot::from_events(
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
/// 役5（FR-MC-5）：快照存储记录面 roundtrip（测试内内存实现，不新增生产后端——ADR-MC-004）
test "快照存储记录面 roundtrip（内存实现）" {
  let saved : Array[@mooncmd.Snapshot[String, @mooncmd.AccountState]] = []
  let store : @mooncmd.SnapshotStore[String, @mooncmd.AccountState] = {
    save: fn(id, s, v, _t) { saved.push(@mooncmd.Snapshot::new(id, s, v)) },
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
  let handler = account_handler
  let applier = @mooncmd.EventApplier::Single(account_applier_single)
  let agg = @mooncmd.AggregateRoot::from_events(
    "snap-2",
    [
      @mooncmd.EventMessage::new(
        @mooncmd.AccountEvent::AccountCreated("Snap2", 1000),
        "snap-2",
        1,
      ),
      @mooncmd.EventMessage::new(
        @mooncmd.AccountEvent::MoneyDeposited(500),
        "snap-2",
        2,
      ),
    ],
    handler,
    applier,
    empty_account_state(),
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
