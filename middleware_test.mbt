// middleware_test.mbt —— dispatch 中间件管道四钉(ADR-MC-009)
// fixtures 复用 router_e2e_test.mbt(同一黑盒伪包命名空间)。

// 钉1:洋葱律——before 按数组序,after 逆序

///|
test "middleware: onion order (before sequential, after reverse)" {
  let store = e2e_fresh("./mooncmd_mw_1.db")
  let records = store.to_event_store()
  let root = @aggregate.AggregateRoot::new(
    "mw-1",
    e2e_handler,
    @event.EventApplier::Single(e2e_applier),
    { total: 0, },
  )
  let trace : Array[String] = []
  let m1 : @mooncmd.DispatchMiddleware[String, E2eCommand, E2eEvent] = {
    name: "m1",
    before: fn(_) { trace.push("m1:before") },
    after: fn(_) { trace.push("m1:after") },
    failure: fn(_, _) { trace.push("m1:failure") },
  }
  let m2 : @mooncmd.DispatchMiddleware[String, E2eCommand, E2eEvent] = {
    name: "m2",
    before: fn(_) { trace.push("m2:before") },
    after: fn(_) { trace.push("m2:after") },
    failure: fn(_, _) { trace.push("m2:failure") },
  }
  let done = @mooncmd.dispatch(records, None, root, Add(4), middleware=[m1, m2])
  assert_eq(done.version(), 1)
  assert_eq(trace, ["m1:before", "m2:before", "m2:after", "m1:after"])
}

// 钉2:主链错 -> failure 挂点(数组序)后原样上浮;after 不触发

///|
test "middleware: failure hooks on main-chain error" {
  let store = e2e_fresh("./mooncmd_mw_2.db")
  let records = store.to_event_store()
  let root = @aggregate.AggregateRoot::new(
    "mw-2",
    e2e_handler,
    @event.EventApplier::Single(e2e_applier),
    { total: 0, },
  )
  let trace : Array[String] = []
  let mw : @mooncmd.DispatchMiddleware[String, E2eCommand, E2eEvent] = {
    name: "f",
    before: fn(_) { trace.push("f:before") },
    after: fn(_) { trace.push("f:after") },
    failure: fn(_, _) { trace.push("f:failure") },
  }
  let outcome = Ok(
    @mooncmd.dispatch(records, None, root, Add(-1), middleware=[mw]),
  ) catch {
    e => Err(e)
  }
  let mut rejected = false
  match outcome {
    Err(@mooncmd.EventSourcingErr::CommandErr(cmd_err)) =>
      match cmd_err {
        @command.CommandError::PreconditionFailed(_) => rejected = true
        _ => fail("expected precondition failure")
      }
    _ => fail("expected CommandErr")
  }
  assert_true(rejected)
  assert_eq(trace, ["f:before", "f:failure"])
}

// 钉3:before/after 挂点自身抛错直接穿透不进 failure(防自触发递归)

///|
test "middleware: hook error passes through, failure not invoked" {
  let store = e2e_fresh("./mooncmd_mw_3.db")
  let records = store.to_event_store()
  let root = @aggregate.AggregateRoot::new(
    "mw-3",
    e2e_handler,
    @event.EventApplier::Single(e2e_applier),
    { total: 0, },
  )
  let trace : Array[String] = []
  let mw : @mooncmd.DispatchMiddleware[String, E2eCommand, E2eEvent] = {
    name: "boom",
    before: fn(_) raise @mooncmd.EventSourcingErr {
      raise @mooncmd.EventSourcingErr::ConsistencyErr("hook boom")
    },
    after: fn(_) { trace.push("after-ran") },
    failure: fn(_, _) { trace.push("failure-ran") },
  }
  let outcome = Ok(
    @mooncmd.dispatch(records, None, root, Add(4), middleware=[mw]),
  ) catch {
    e => Err(e)
  }
  match outcome {
    Err(@mooncmd.EventSourcingErr::ConsistencyErr(msg)) =>
      assert_eq(msg, "hook boom")
    _ => fail("expected hook error passthrough")
  }
  assert_eq(trace, [])
}

// 钉4:logging_middleware 参考件(时钟/日志汇显式注入,ADR-MC-009 D4)

///|
test "middleware: logging_middleware dogfood" {
  let store = e2e_fresh("./mooncmd_mw_4.db")
  let records = store.to_event_store()
  let root = @aggregate.AggregateRoot::new(
    "mw-4",
    e2e_handler,
    @event.EventApplier::Single(e2e_applier),
    { total: 0, },
  )
  let ticks : Array[Int64] = [100L, 180L]
  let idx : Array[Int32] = [0]
  let clock = fn() {
    let t = ticks[idx[0]]
    idx[0] = idx[0] + 1
    t
  }
  let lines : Array[String] = []
  let log = fn(s : String) { lines.push(s) }
  let mw = @mooncmd.logging_middleware(clock~, log~)
  let done = @mooncmd.dispatch(records, None, root, Add(4), middleware=[mw])
  assert_eq(done.version(), 1)
  assert_eq(lines, [
    "dispatch before: version=0", "dispatch after: version=1 events=1 elapsed_ms=80",
  ])
}
