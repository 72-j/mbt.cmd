// pub(all) enum StoreTestEvent {
//   Created(String)
//   Updated(String)
//   Deleted
// } derive(Debug, Eq)

///|
/// 测试用的简单事件类型
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

///|
/// FR-MC-1：乐观并发金样——批次首事件版本 ≠ 当前版本 + 1 ⇒ DuplicateVersion，拒写不落脏
async test "SQLiteEventStore 乐观并发：版本冲突即拒" {
  let db_path = "./test_event_store_conflict.db"
  if @fs.path_exists(db_path) {
    @fs.remove_file(db_path)
  }
  let store = @store.SQLiteEventStore::new(
    db_path, serialize_test_event, deserialize_test_event, get_test_event_type_name,
  )
  let aggregate_id = "conflict-aggregate"
  store.append(aggregate_id, [
    @event.EventMessage::new(TestEvent::Created("A"), aggregate_id, 1),
  ])
  let stale = @event.EventMessage::new(TestEvent::Updated("B"), aggregate_id, 1)
  let mut conflict = false
  store.append(aggregate_id, [stale]) catch {
    e =>
      match e {
        @store.EventStoreError::DuplicateVersion(_) => conflict = true
        _ => ()
      }
  }
  assert_true(conflict)
  // 拒写后不落脏：当前版本仍是 1
  assert_eq(store.current_version(aggregate_id), 1)
  if @fs.path_exists(db_path) {
    @fs.remove_file(db_path)
  }
}
