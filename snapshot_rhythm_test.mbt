// snapshot_rhythm_test.mbt —— 快照自动节律四钉(ADR-MC-010)
// fixtures 复用 router_e2e_test.mbt(同一黑盒伪包命名空间)。
// 判定式 = Commanded 同款差值制:version - base_version >= snapshot_every
// (base_version = Step 0 快照基版本;0 = 关闭)。

// 共用驱动:每次 dispatch 走 Router 全链(Step 0 快照基态 → Step 5 节律落帧)

///|
fn sr_dispatch_now(
  router : @mooncmd.Router[String, E2eState, E2eCommand, E2eEvent],
  id : String,
) -> @aggregate.AggregateRoot[String, E2eState, E2eCommand, E2eEvent] {
  let outcome = Ok(
    router.dispatch_now(
      id,
      @command.CommandMessage::new(Add(4)),
      e2e_handler,
      @event.EventApplier::Single(e2e_applier),
      { total: 0, },
    ),
  ) catch {
    e => Err(e)
  }
  match outcome {
    Ok(a) => a
    Err(e) => abort("dispatch failed: " + sr_err_tag(e))
  }
}

// 错误变体标签(suberror 无 Show,abort 文案带变体防吞现场)

///|
fn sr_err_tag(e : @mooncmd.EventSourcingErr) -> String {
  match e {
    @mooncmd.EventSourcingErr::CommandErr(_) => "CommandErr"
    @mooncmd.EventSourcingErr::EventStoreErr(_) => "EventStoreErr"
    @mooncmd.EventSourcingErr::EventBusErr(_) => "EventBusErr"
    @mooncmd.EventSourcingErr::SnapshotErr(_) => "SnapshotErr"
    @mooncmd.EventSourcingErr::AggregateErr(_) => "AggregateErr"
    @mooncmd.EventSourcingErr::ConsistencyErr(_) => "ConsistencyErr"
  }
}

// 钉1:差值开火——every=3,v1/v2 不落,v3 精确落(总 12)

///|
test "snapshot rhythm: fires exactly at threshold (every=3)" {
  let store = e2e_fresh("./mooncmd_sr_1.db")
  let snapshots = mem_snapshots_new()
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    store.to_event_store(),
    mem_snapshots_store(snapshots),
    None,
    5000L,
    3,
    snapshot_every=3,
  )
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  let agg1 = sr_dispatch_now(router, "sr-1")
  assert_eq(agg1.version(), 1)
  match snapshots.by_id.get("sr-1") {
    Some(_) => fail("snapshot should not exist at v1")
    None => ()
  }
  let agg2 = sr_dispatch_now(router, "sr-1")
  assert_eq(agg2.version(), 2)
  match snapshots.by_id.get("sr-1") {
    Some(_) => fail("snapshot should not exist at v2")
    None => ()
  }
  let agg3 = sr_dispatch_now(router, "sr-1")
  assert_eq(agg3.version(), 3)
  match snapshots.by_id.get("sr-1") {
    Some((state, version)) => {
      assert_eq(state.total, 12)
      assert_eq(version, 3)
    }
    None => fail("expected snapshot at v3")
  }
}

// 钉2:缺省关闭——不带 snapshot_every 参数,两次 dispatch 零落帧

///|
test "snapshot rhythm: default is off (no auto snapshot)" {
  let store = e2e_fresh("./mooncmd_sr_2.db")
  let snapshots = mem_snapshots_new()
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    store.to_event_store(),
    mem_snapshots_store(snapshots),
    None,
    5000L,
    3,
  )
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  let agg1 = sr_dispatch_now(router, "sr-2")
  assert_eq(agg1.version(), 1)
  let agg2 = sr_dispatch_now(router, "sr-2")
  assert_eq(agg2.version(), 2)
  match snapshots.by_id.get("sr-2") {
    Some(_) => fail("default env must not auto-snapshot")
    None => ()
  }
}

// 钉3:错位基版本——种子快照 v2,every=3:模制会在 v3 开火,差值制在 v5

///|
test "snapshot rhythm: difference-based from seeded base (v2 -> v5)" {
  let store = e2e_fresh("./mooncmd_sr_3.db")
  let snapshots = mem_snapshots_new()
  snapshots.by_id["sr-3"] = ({ total: 20, }, 2)
  // 种子事件 v1..v2(内容无关——快照覆盖其态;store 版本连续性要求)
  let event_store = store.to_event_store()
  for i in 1..<3 {
    (event_store.append)(event_store, "sr-3", [
      @event.EventMessage::new(Added(0), "sr-3", i),
    ]) catch {
      e => fail("seed append \{i} failed: \{e.to_string()}")
    }
  }
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    store.to_event_store(),
    mem_snapshots_store(snapshots),
    None,
    5000L,
    3,
    snapshot_every=3,
  )
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  let agg3 = sr_dispatch_now(router, "sr-3")
  assert_eq(agg3.version(), 3)
  // 差值 3-2=1 < 3:种子快照原样(总 20 版 2),未被覆写
  match snapshots.by_id.get("sr-3") {
    Some((state, version)) => {
      assert_eq(state.total, 20)
      assert_eq(version, 2)
    }
    None => fail("seeded snapshot missing")
  }
  let agg4 = sr_dispatch_now(router, "sr-3")
  assert_eq(agg4.version(), 4)
  match snapshots.by_id.get("sr-3") {
    Some((_, version)) => assert_eq(version, 2)
    None => fail("seeded snapshot missing")
  }
  let agg5 = sr_dispatch_now(router, "sr-3")
  assert_eq(agg5.version(), 5)
  // 差值 5-2=3 >= 3:落帧(总 20+12=32,版 5)
  match snapshots.by_id.get("sr-3") {
    Some((state, version)) => {
      assert_eq(state.total, 32)
      assert_eq(version, 5)
    }
    None => fail("expected snapshot at v5")
  }
}

// 钉4:快照后重计——every=3 六发:v3 落帧后基版本重置,v6 再落(总 24)

///|
test "snapshot rhythm: re-counts after snapshot (v3 then v6)" {
  let store = e2e_fresh("./mooncmd_sr_4.db")
  let snapshots = mem_snapshots_new()
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    store.to_event_store(),
    mem_snapshots_store(snapshots),
    None,
    5000L,
    3,
    snapshot_every=3,
  )
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  for _idx in 1..<=6 {
    let _agg = sr_dispatch_now(router, "sr-4")
  }
  // 第一落:v3(总 12);此后差值重计
  match snapshots.by_id.get("sr-4") {
    Some((state, version)) => {
      assert_eq(state.total, 24)
      assert_eq(version, 6)
    }
    None => fail("expected snapshot at v6")
  }
}
