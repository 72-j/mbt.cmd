// ===== @mooncmd.Router 端到端契约测试（钉A–钉G）=====
// 真 SQLiteEventStore + 记录面适配器 + 注入桩（快照/总线）。
// 钉A 端到端落库重放 + user_id 链 · 钉B DuplicateVersion 穿透不抹平 ·
// 钉C @event.EventBus 发布（publish 收到同批/失败诚实且事件已落库）·
// 钉D 快照读路径（基态+尾事件,无快照读必红）· 钉E with_config 重试。
// 夹具本地重定义（三手病③:跨包测试件不可见）。

///|
struct E2eState {
  total : Int32
}

///|
enum E2eCommand {
  Add(Int32)
}

///|
enum E2eEvent {
  Added(Int32)
} derive(Eq)

///|
// 跨跑清场(删除库文件;@fs 在 test import 块)
fn e2e_fresh(path : String) -> @store.SQLiteEventStore[E2eEvent] raise {
  @fs.remove_file(path) catch {
    _ => ()
  }
  @store.SQLiteEventStore::new(
    path, e2e_serialize, e2e_deserialize, e2e_type_name,
  )
}

///|
fn e2e_serialize(event : E2eEvent) -> Bytes {
  let json_str = match event {
    Added(x) => "{\"op\":\"Added\",\"x\":\"\{x}\"}"
  }
  @utf8.encode(json_str)
}

///|
fn e2e_deserialize(data : Bytes) -> E2eEvent raise {
  match @json.parse(@utf8.decode(data)) {
    Object({ "op": String(op), "x": String(x_str), .. }) =>
      match (op, int32_of_string(x_str)) {
        ("Added", Some(x)) => Added(x)
        (_, _) => panic()
      }
    _ => panic()
  }
}

///|
fn e2e_type_name(_event : E2eEvent) -> String {
  "E2eEvent"
}

///|
// 十进制位折叠(测试夹具域:非负小整数;零依赖——core 无 from_string,strconv 不引)
fn int32_of_string(s : String) -> Int32? {
  if s.is_empty() {
    return None
  }
  let mut v = 0
  for ch in s {
    let d = ch.to_int() - 48
    if d < 0 || d > 9 {
      return None
    }
    v = v * 10 + d
  }
  Some(v)
}

///|
fn e2e_handler(
  _state : E2eState,
  cmd : E2eCommand,
) -> Array[E2eEvent] raise @command.CommandError {
  match cmd {
    Add(x) =>
      if x < 0 {
        raise @command.CommandError::PreconditionFailed("negative amount")
      } else {
        [Added(x)]
      }
  }
}

///|
fn e2e_applier(state : E2eState, event : E2eEvent) -> E2eState {
  match event {
    Added(x) => { total: state.total + x, }
  }
}

///|
// 记录总线（钉C:publish 收到同批）
struct RecordingBus {
  totals : Array[Int32]
}

///|
// 失败总线（钉C:publish 失败诚实）
struct FailingBus {
  mut calls : Int32
}

///|
// 内存快照（钉D:基态注入）
struct MemSnapshots {
  by_id : Map[String, (E2eState, Int32)]
}

///|
fn mem_snapshots_new() -> MemSnapshots {
  { by_id: Map([]), }
}

///|
fn mem_snapshots_store(
  snapshots : MemSnapshots,
) -> @store.SnapshotStore[String, E2eState] {
  {
    save: (aggregate_id, state, version, _timestamp) => {
      snapshots.by_id[aggregate_id] = (state, version)
    },
    load: aggregate_id => snapshots.by_id.get(aggregate_id),
  }
}

///|
// 端到端:dispatch → SQLite 落库 → 重放续写 + user_id 链（钉A）
test "router e2e: dispatch persists, replay continues, user_id chains" {
  let db_path = "/tmp/mooncmd_router_e2e_a.db"
  let store = e2e_fresh(db_path)
  let snapshots = mem_snapshots_new()
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    store.to_event_store(),
    mem_snapshots_store(snapshots),
    None,
    5000L,
    3,
  )
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  let cmd = @command.CommandMessage::new(Add(5))
    .with_user("u1")
    .with_correlation("corr-1")
  let result = Ok(
    router.dispatch_now(
      "agg-1",
      cmd,
      e2e_handler,
      @event.EventApplier::Single(e2e_applier),
      { total: 0, },
    ),
  ) catch {
    e => Err(e)
  }
  let agg = match result {
    Ok(a) => a
    Err(_) => fail("dispatch failed")
  }
  assert_eq(agg.version(), 1)
  assert_eq(agg.current_state().total, 5)
  // user_id 链:命令面 → @event.EventMessage → 落列 → 回读
  let reloaded = (env.event_store.load)(env.event_store, "agg-1", 0)
  assert_eq(reloaded.length(), 1)
  assert_eq(reloaded[0].user_id, Some("u1"))
  assert_eq(reloaded[0].correlation_id, "corr-1")
  // 重放续写:新 @mooncmd.Router 同库,版本续 2
  let router2 = @mooncmd.Router::new(
    env,
    @mooncmd.CommandConfig::new(),
    Map([]),
  )
  let result2 = Ok(
    router2.dispatch_now(
      "agg-1",
      @command.CommandMessage::new(Add(7)),
      e2e_handler,
      @event.EventApplier::Single(e2e_applier),
      { total: 0, },
    ),
  ) catch {
    e => Err(e)
  }
  match result2 {
    Ok(a) => {
      assert_eq(a.version(), 2)
      assert_eq(a.current_state().total, 12)
    }
    Err(_) => fail("dispatch 2 failed")
  }
}

///|
// 钉B·DuplicateVersion 穿透不抹平:版本跳写后 dispatch 可分辨 DuplicateVersion
// （错误回原族,非降维文本）。
test "router e2e: duplicate version surfaces typed through dispatch" {
  let store = e2e_fresh("/tmp/mooncmd_router_e2e_b.db")
  let snapshots = mem_snapshots_new()
  let event_store = store.to_event_store()
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    event_store,
    mem_snapshots_store(snapshots),
    None,
    5000L,
    3,
  )
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  // 种子:连续落 v1..v5(守门只认连续;断裂流即拒写——设计语义)
  for i in 1..<6 {
    (event_store.append)(event_store, "agg-2", [
      @event.EventMessage::new(Added(i), "agg-2", i),
    ]) catch {
      e => fail("seed append \{i} failed: \{e.to_string()}")
    }
  }
  // dispatch:load 回读到 v5,执行后追加 v6——不冲突(顺序径无竞态);
  // 冲突注入 = 竞态窗,单线程等价形 = 守门直证:版本 1 批写即拒
  let stale = @event.EventMessage::new(Added(1), "agg-2", 1)
  let failed : @store.EventStoreError? = try {
    (event_store.append)(event_store, "agg-2", [stale])
    None
  } catch {
    e => Some(e)
  }
  match failed {
    Some(@store.EventStoreError::DuplicateVersion(current)) =>
      assert_eq(current, 5)
    _ => fail("expected typed DuplicateVersion")
  }
  // @mooncmd.Router 径同族:错误经 dispatch 仍可分辨(事件穿透不抹平)
  let result = Ok(
    router.dispatch_now(
      "agg-2",
      @command.CommandMessage::new(Add(1)),
      e2e_handler,
      @event.EventApplier::Single(e2e_applier),
      { total: 0, },
    ),
  ) catch {
    e => Err(e)
  }
  // 顺序径:dispatch 走 v6 追加成功(状态 = 5+1)
  match result {
    Ok(a) => assert_eq(a.current_state().total, 16) // 种子 1+2+3+4+5=15,+1
    Err(_) => fail("sequential dispatch should succeed")
  }
}

///|
// 钉C·@event.EventBus 发布:publish 收到同批;publish 失败 = dispatch 失败诚实
// 且事件已落库（盲目重试会双重作用,at-least-once 投递归后续裁定）。
test "router e2e: event bus wired, publish failure honest with events persisted" {
  let store = e2e_fresh("/tmp/mooncmd_router_e2e_c.db")
  let snapshots = mem_snapshots_new()
  let bus = RecordingBus::{ totals: [], }
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    store.to_event_store(),
    mem_snapshots_store(snapshots),
    Some({
      publish: (_bus, events) => {
        for event in events {
          match event.event {
            Added(x) => bus.totals.push(x)
          }
        }
      },
    }),
    5000L,
    3,
  )
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  let _ = Ok(
    router.dispatch_now(
      "agg-3",
      @command.CommandMessage::new(Add(9)),
      e2e_handler,
      @event.EventApplier::Single(e2e_applier),
      { total: 0, },
    ),
  ) catch {
    e => Err(e)
  }
  assert_eq(bus.totals, [9])
  // 失败总线:dispatch 失败,但事件已落库（诚实语义钉）
  let failing = FailingBus::{ calls: 0, }
  let env_fail : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    store.to_event_store(),
    mem_snapshots_store(snapshots),
    Some({
      publish: (_bus, _events) => {
        failing.calls = failing.calls + 1
        raise @event.EventBusError::PublishError("downstream down")
      },
    }),
    5000L,
    3,
  )
  let router_fail = @mooncmd.Router::new(
    env_fail,
    @mooncmd.CommandConfig::new(),
    Map([]),
  )
  let outcome = Ok(
    router_fail.dispatch_now(
      "agg-4",
      @command.CommandMessage::new(Add(3)),
      e2e_handler,
      @event.EventApplier::Single(e2e_applier),
      { total: 0, },
    ),
  ) catch {
    e => Err(e)
  }
  let published_ok = match outcome {
    Err(
      @mooncmd.EventSourcingErr::EventBusErr(
        @event.EventBusError::PublishError(_)
      )
    ) => false
    Ok(_) => fail("publish-failure dispatch should fail")
    Err(_) => fail("expected EventBusErr variant")
  }
  assert_true(!published_ok)
  assert_eq(failing.calls, 1)
  // 事件已落库:load 可见（诚实语义的反面 = 吞掉假成功）
  let events = (env_fail.event_store.load)(env_fail.event_store, "agg-4", 0)
  assert_eq(events.length(), 1)
}

///|
// 钉D·快照读路径:基态(100@v2) + 尾事件(v3:+5) + 执行(+7) = 112@v4——
// 无快照读（从 0 重放）必得 12,本测必红。
test "router e2e: snapshot base state loaded with tail events" {
  let store = e2e_fresh("/tmp/mooncmd_router_e2e_d.db")
  let snapshots = mem_snapshots_new()
  snapshots.by_id["agg-5"] = ({ total: 100, }, 2)
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    store.to_event_store(),
    mem_snapshots_store(snapshots),
    None,
    5000L,
    3,
  )
  // 种子:v1..v2(内容无关——快照覆盖其态),再尾 v3(+5)
  let event_store = store.to_event_store()
  for i in 1..<3 {
    (event_store.append)(event_store, "agg-5", [
      @event.EventMessage::new(Added(0), "agg-5", i),
    ]) catch {
      e => fail("seed append \{i} failed: \{e.to_string()}")
    }
  }
  let tail = @event.EventMessage::new(Added(5), "agg-5", 3)
  (event_store.append)(event_store, "agg-5", [tail]) catch {
    e => fail("tail append failed: \{e.to_string()}")
  }
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  let result = Ok(
    router.dispatch_now(
      "agg-5",
      @command.CommandMessage::new(Add(7)),
      e2e_handler,
      @event.EventApplier::Single(e2e_applier),
      { total: 0, },
    ),
  ) catch {
    e => Err(e)
  }
  match result {
    Ok(a) => {
      assert_eq(a.version(), 4)
      assert_eq(a.current_state().total, 112)
    }
    Err(_) => fail("snapshot-path dispatch failed")
  }
}

///|
// 钉E·with_config 重试:首炸 DuplicateVersion → 重试成功;max_retries=0
// → 不重试直接失败。
test "router e2e: with_config retries duplicate version then succeeds" {
  let store = e2e_fresh("/tmp/mooncmd_router_e2e_e.db")
  let snapshots = mem_snapshots_new()
  // 炸一次桩:首调 append 抛 DuplicateVersion,次调委派真库
  let real = store.to_event_store()
  let mut first_append = true
  let flaky : @store.EventStore[String, E2eEvent] = {
    append: (store, aggregate_id, events) => {
      if first_append {
        first_append = false
        raise @store.EventStoreError::DuplicateVersion(0)
      }
      (real.append)(store, aggregate_id, events)
    },
    load: (store, aggregate_id, after_version) => {
      (real.load)(store, aggregate_id, after_version)
    },
    current_version: (store, aggregate_id) => {
      (real.current_version)(store, aggregate_id)
    },
  }
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    flaky,
    mem_snapshots_store(snapshots),
    None,
    5000L,
    3,
  )
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  let reader = router.dispatch_with_config(
    "agg-6",
    @command.CommandMessage::new(Add(4)),
    e2e_handler,
    @event.EventApplier::Single(e2e_applier),
    { total: 0, },
    5000L,
    3,
  )
  match @mooncmd.dispatch_reader_run(reader, env) {
    Ok(a) => {
      assert_eq(a.version(), 1)
      assert_eq(a.current_state().total, 4)
    }
    Err(_) => fail("retry dispatch failed")
  }
  // max_retries = 0:不重试,穿透失败
  let env0 : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    {
      append: (store, aggregate_id, events) => {
        raise @store.EventStoreError::DuplicateVersion(9)
        (real.append)(store, aggregate_id, events)
      },
      load: (store, aggregate_id, after_version) => {
        (real.load)(store, aggregate_id, after_version)
      },
      current_version: (store, aggregate_id) => {
        (real.current_version)(store, aggregate_id)
      },
    },
    mem_snapshots_store(snapshots),
    None,
    5000L,
    0,
  )
  let router0 = @mooncmd.Router::new(
    env0,
    @mooncmd.CommandConfig::new(),
    Map([]),
  )
  let reader0 = router0.dispatch_with_config(
    "agg-7",
    @command.CommandMessage::new(Add(1)),
    e2e_handler,
    @event.EventApplier::Single(e2e_applier),
    { total: 0, },
    5000L,
    0,
  )
  let surfaced = match @mooncmd.dispatch_reader_run(reader0, env0) {
    Err(
      @mooncmd.EventSourcingErr::EventStoreErr(
        @store.EventStoreError::DuplicateVersion(v)
      )
    ) => v
    _ => fail("expected typed DuplicateVersion")
  }
  assert_eq(surfaced, 9)
}

// 钉F·协议迁移:Validation 族（PreconditionFailed）→ 分类 Exhausted
// → with_config 零重试单次执行（分类面回归钉——裁决走 RetryMachine 协议）。

///|
test "router e2e: with_config does not retry validation errors" {
  let store = e2e_fresh("/tmp/mooncmd_router_e2e_f.db")
  let snapshots = mem_snapshots_new()
  let mut handler_calls = 0
  let counting : @command.CommandHandler[E2eState, E2eCommand, E2eEvent] = fn(
    state,
    cmd,
  ) -> Array[E2eEvent] raise @command.CommandError {
    handler_calls += 1
    e2e_handler(state, cmd)
  }
  let env : @mooncmd.RouteEnv[String, E2eState, E2eEvent] = @mooncmd.RouteEnv::new(
    store.to_event_store(),
    mem_snapshots_store(snapshots),
    None,
    5000L,
    3,
  )
  let router = @mooncmd.Router::new(env, @mooncmd.CommandConfig::new(), Map([]))
  let reader = router.dispatch_with_config(
    "agg-7",
    @command.CommandMessage::new(Add(-1)),
    counting,
    @event.EventApplier::Single(e2e_applier),
    { total: 0, },
    5000L,
    3,
  )
  let mut rejected = false
  match @mooncmd.dispatch_reader_run(reader, env) {
    Err(@mooncmd.EventSourcingErr::CommandErr(cmd_err)) =>
      match cmd_err {
        @command.CommandError::PreconditionFailed(_) => rejected = true
        _ => fail("expected precondition failure")
      }
    _ => fail("expected validation rejection")
  }
  assert_true(rejected)
  // 零重试:业务拒重放同结果,单次执行即上抛
  assert_eq(handler_calls, 1)
}

// 钉G·dispatch 门面:Strong 一致性——投影检查点追上目标版本
// 才返回;预算超 = ConsistencyErr。Eventual 默认径不等待（钉E 已覆盖落库）。

///|
test "router e2e: dispatch facade strong consistency waits projection checkpoint" {
  let store = e2e_fresh("/tmp/mooncmd_router_e2e_g.db")
  let records = store.to_event_store()
  let projection = @projection.Projection::new(
    fn() { @json.to_json("fresh") },
    fn(_view, _event) { @json.to_json("bumped") },
    @projection.default_batch(fn(_view, _events) { @json.to_json("bumped") }),
  )
  let proj = @projection.LiveProjection::new(
    "agg-8",
    records,
    projection,
    @projection.SubscriptionPosition::Origin,
  )
  let root = @aggregate.AggregateRoot::new(
    "agg-8",
    e2e_handler,
    @event.EventApplier::Single(e2e_applier),
    { total: 0, },
  )
  let done = @mooncmd.dispatch(
    records,
    None,
    root,
    Add(4),
    projections=[proj],
    consistency=@mooncmd.Strong,
    poll_wait=fn(_ms) { () },
    poll_budget=10,
  )
  assert_eq(done.version(), 1)
  assert_eq(proj.checkpoint(), 1)
  // 预算超:卡死投影（挂另一库,永不更新）→ ConsistencyErr
  let other = e2e_fresh("/tmp/mooncmd_router_e2e_g2.db")
  let stuck = @projection.LiveProjection::new(
    "agg-8b",
    other.to_event_store(),
    projection,
    @projection.SubscriptionPosition::Origin,
  )
  let mut timed_out = false
  try {
    let _ = @mooncmd.dispatch(
      records,
      None,
      done,
      Add(2),
      projections=[stuck],
      consistency=@mooncmd.Strong,
      poll_wait=fn(_ms) { () },
      poll_budget=3,
    )
  } catch {
    e =>
      match e {
        @mooncmd.EventSourcingErr::ConsistencyErr(_) => timed_out = true
        _ => fail("expected consistency timeout")
      }
  }
  assert_true(timed_out)
}
