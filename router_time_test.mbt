// ===== 钉H·Router 时间透传(时间源注入役)=====
// RouteEnv 注钟 → dispatch → 落库事件时间戳 = 注入值(业务/框架零直读钟,
// 全链受控);夹具复用 router_e2e_test.mbt 同包命名空间。

///|
test "router e2e: env-injected clock flows into persisted event timestamps" {
  let fixed = 1770000000000L
  let store = e2e_fresh("./mooncmd_router_e2e_clock.db")
  let snapshots = mem_snapshots_new()
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    store.to_event_store(),
    mem_snapshots_store(snapshots),
    None,
    5000L,
    3,
    clock=fn() { fixed },
  )
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  let result = Ok(
    router.dispatch_now(
      "agg-clock",
      @command.CommandMessage::new(Add(5)),
      e2e_handler,
      @event.EventApplier::Single(e2e_applier),
      { total: 0, },
    ),
  ) catch {
    e => Err(e)
  }
  match result {
    Ok(_) => ()
    Err(_) => fail("dispatch failed")
  }
  let reloaded = (env.event_store.load)(env.event_store, "agg-clock", 0)
  assert_eq(reloaded.length(), 1)
  assert_eq(reloaded[0].timestamp, fixed)
}
