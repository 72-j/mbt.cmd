///|
/// 役5（FR-MC-4/FR-MC-2 白盒钉子）：UNIQUE(aggregate_id, version) 在册 + schema_version 列通
/// 白盒原因：`conn` 为包内私有面，黑盒不可达；自带最小事件夹具（黑盒测试包互不可见）。
enum WbEvent {
  Wb
}

///|
fn wb_ser(_e : WbEvent) -> Bytes {
  // 白盒件无 for "test" 导入面（utf8 不可达）——字节字面量直取，主包免挂 utf8
  b"{}"
}

///|
fn wb_de(data : Bytes) -> WbEvent raise {
  // 反序列化面真实用 raise（消 [0024] unused_error_type）：空载荷即拒
  if data.length() == 0 {
    raise EventStoreError::SerializationError("wb: empty payload")
  }
  WbEvent::Wb
}

///|
fn wb_name(_e : WbEvent) -> String {
  "Wb"
}

///|
test "schema 钉子：UNIQUE(aggregate_id, version) 在册且 schema_version 列通" {
  // :memory: 库——白盒件不可用 @fs 清理（白盒无 for "whitebox-test" 导入面），
  // 内存库免落盘，根除 /tmp 陈旧旧-schema 库导致的跨机假红
  let store = SQLiteEventStore::new(":memory:", wb_ser, wb_de, wb_name)
  let stmt = store.conn.prepare(
    "SELECT sql FROM sqlite_master WHERE type='table' AND name='event_stream'",
  )
  assert_true(stmt.step())
  let sql : String = stmt.column(index=0)
  stmt.finalize()
  assert_true(sql.contains("UNIQUE(aggregate_id, version)"))
  assert_true(sql.contains("schema_version"))
  // schema_version 列通：落一笔读回 = 1（预留值；演进只加不改）
  let msg = @event.EventMessage::new(WbEvent::Wb, "wb-agg", 1)
  store.append("wb-agg", [msg])
  let loaded = store.load("wb-agg", 0)
  assert_eq(loaded.length(), 1)
  assert_eq(loaded[0].schema_version, 1)
}
