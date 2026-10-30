// ===== 投影契约测试(FR-MC-3;真 SQLiteEventStore + 检查点拉取形)=====
// 钉1·装载:Origin 全量折入,checkpoint = 末事件版本 ·
// 钉2·refresh:拉新推进检查点,流空 no-op(幂等)。
// 夹具本地重定义(三手病③);视图 = 已折事件数(Json 数);事件载荷不进视图
// (计数投影——deserialize 语义无关,桩形合法)。

///|
struct ProjEvent {
  x : Int32
}

///|
fn proj_serialize(event : ProjEvent) -> Bytes {
  @utf8.encode("{\"x\":\{event.x}}")
}

///|
fn proj_deserialize(data : Bytes) -> ProjEvent raise {
  let _ = @json.parse(@utf8.decode(data)) // 载荷不进视图(计数投影),解析仅验形
  ProjEvent::{ x: 0, }
}

///|
fn proj_type_name(_event : ProjEvent) -> String {
  "ProjEvent"
}

///|
// 投影器:视图 = 已折事件计数(整数 Json);apply 纯函数禁时钟。
fn proj_projection() -> @projection.Projection[String, ProjEvent] {
  @projection.Projection::new(
    fn() { @json.to_json("fresh") },
    fn(_view, _event) { @json.to_json("bumped") },
    @projection.default_batch(fn(_view, _events) {
      @json.to_json("bumped-batch")
    }),
  )
}

///|
test "projection live: origin load checkpoint then refresh idempotent" {
  let db_path = "./mooncmd_proj_gate.db"
  let _ = @fs.remove_file(db_path) catch { _ => () }
  let store = @store.SQLiteEventStore::new(
    db_path, proj_serialize, proj_deserialize, proj_type_name,
  )
  let event_store = store.to_event_store()
  // 预置 v1..v3
  for i in 1..<4 {
    (event_store.append)(event_store, "agg-p", [
      @event.EventMessage::new(ProjEvent::{ x: i, }, "agg-p", i),
    ]) catch {
      e => fail("seed \{i}: \{e.to_string()}")
    }
  }
  let live = @projection.LiveProjection::new(
    "agg-p",
    event_store,
    proj_projection(),
    @projection.SubscriptionPosition::Origin,
  ) catch {
    e => fail("live new: \{e.to_string()}")
  }
  // 钉1:全量折入,checkpoint = 末版本
  assert_eq(live.checkpoint(), 3)
  // 钉2·前半:流空 refresh = no-op(幂等)
  live.refresh() catch {
    e => fail("refresh no-op: \{e.to_string()}")
  }
  assert_eq(live.checkpoint(), 3)
  // 追加 v4 → refresh 推进
  (event_store.append)(event_store, "agg-p", [
    @event.EventMessage::new(ProjEvent::{ x: 4, }, "agg-p", 4),
  ]) catch {
    e => fail("append 4: \{e.to_string()}")
  }
  live.refresh() catch {
    e => fail("refresh 2: \{e.to_string()}")
  }
  assert_eq(live.checkpoint(), 4)
}
