///|
/// 测试用的简单事件类型（夹具本地化：拆分后跨包测试件不可见，AGENTS 三手病③）
enum TestEvent {
  Created(String)
  Updated(String)
  Deleted
} derive(Debug, Eq)

///|
fn get_test_event_type_name(event : TestEvent) -> String {
  match event {
    Created(_) => "Created"
    Updated(_) => "Updated"
    Deleted => "Deleted"
  }
}

///|
/// FR-MC-3：投影契约钉——apply_batch ≡ fold(apply)（结构性合同）；同输入同输出（确定性）
fn proj_apply(v : Json, e : @event.EventMessage[String, TestEvent]) -> Json {
  let s = match v {
    String(s) => s
    _ => ""
  }
  @json.to_json(s + "|" + get_test_event_type_name(e.event))
}

///|
test "投影契约：apply_batch ≡ fold(apply)" {
  let p = @projection.Projection::new(fn() { @json.to_json("") }, proj_apply, fn(
    v,
    es,
  ) {
    es.fold(init=v, fn(acc, e) { proj_apply(acc, e) })
  })
  let e1 = @event.EventMessage::new(TestEvent::Created("a"), "p-1", 1)
  let e2 = @event.EventMessage::new(TestEvent::Updated("b"), "p-1", 2)
  let e3 = @event.EventMessage::new(TestEvent::Deleted, "p-1", 3)
  let batched = (p.apply_batch)((p.init)(), [e1, e2, e3])
  let sequential = proj_apply(proj_apply(proj_apply((p.init)(), e1), e2), e3)
  assert_eq(batched.stringify(), sequential.stringify())
}

///|
test "投影确定性：同输入两次投影同输出" {
  let p = @projection.Projection::new(fn() { @json.to_json("") }, proj_apply, fn(
    v,
    es,
  ) {
    es.fold(init=v, fn(acc, e) { proj_apply(acc, e) })
  })
  let es = [
    @event.EventMessage::new(TestEvent::Created("x"), "p-2", 1),
    @event.EventMessage::new(TestEvent::Updated("y"), "p-2", 2),
  ]
  let v1 = (p.apply_batch)((p.init)(), es)
  let v2 = (p.apply_batch)((p.init)(), es)
  assert_eq(v1.stringify(), v2.stringify())
}
