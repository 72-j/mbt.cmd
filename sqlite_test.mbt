/// SQLite Event Store 测试

///|

///|
/// 序列化函数
fn serialize_test_event(event : TestEvent) -> Bytes {
  let json_str = match event {
    Created(name) => "{\"type\":\"Created\",\"name\":\"\{name}\"}"
    Updated(name) => "{\"type\":\"Updated\",\"name\":\"\{name}\"}"
    Deleted =>
      (
        #|{"type":"Deleted"}
      )
  }
  @utf8.encode(json_str)
}

///|
/// 反序列化函数
fn deserialize_test_event(data : Bytes) -> TestEvent raise {
  let json_str = @utf8.decode(data)
  let json_obj = @json.parse(json_str)

  let evt = match json_obj {
    Object({ "name": String(name), "type": String(type_name), .. }) =>
      match type_name {
        "Created" => TestEvent::Created(name)
        "Updated" => TestEvent::Updated(name)
        _ => panic()
      }
    Object({ "type": String(type_name), .. }) =>
      match type_name {
        "Deleted" => TestEvent::Deleted
        _ => panic()
      }
    _ => panic()
  }

  evt
}

///|
test "@mooncmd.SQLiteEventStore 创建和初始化" {
  let db_path = "/tmp/test_event_store_1.db"

  // 删除可能存在的旧数据库文件
  if @fs.path_exists(db_path) {
      @fs.remove_file(db_path)
    }

  let _store = @mooncmd.SQLiteEventStore::new(
    db_path, serialize_test_event, deserialize_test_event, get_test_event_type_name,
  )
  assert_true(@fs.is_file(db_path))
  // println(store)
  // 验证 store 创建成功
  // assert_eq(store , true)

  // 清理
  if @fs.path_exists(db_path) {
      @fs.remove_file(db_path)
    }
}

///|
async test "@mooncmd.SQLiteEventStore 追加和加载事件" {
  let db_path = "/tmp/test_event_store_2.db"
  /// 获取事件类型名称

  // 删除可能存在的旧数据库文件
  if @fs.path_exists(db_path) {
      @fs.remove_file(db_path)
    }

  let store = @mooncmd.SQLiteEventStore::new(
    db_path, serialize_test_event, deserialize_test_event, get_test_event_type_name,
  )

  let aggregate_id = "test-aggregate-1"

  // 创建测试事件
  let event1 = @mooncmd.EventMessage::new(
    TestEvent::Created("Test Account"),
    aggregate_id,
    1,
  )

  let event2 = @mooncmd.EventMessage::new(
    TestEvent::Updated("Updated Account"),
    aggregate_id,
    2,
  )

  // 追加事件
  store.append(aggregate_id, [event1, event2])

  // 加载事件
  let loaded_events = store.load(aggregate_id, 0)

  // 验证加载的事件数量
  assert_eq(loaded_events.length(), 2)

  // 验证事件内容
  assert_eq(loaded_events[0].aggregate_version, 1)
  assert_eq(loaded_events[1].aggregate_version, 2)

  // 验证事件类型
  match loaded_events[0].event {
    TestEvent::Created(name) => assert_eq(name, "Test Account")
    _ => fail("期望 Created 事件，实得其它变体")
  }

  match loaded_events[1].event {
    TestEvent::Updated(name) => assert_eq(name, "Updated Account")
    _ => fail("期望 Updated 事件，实得其它变体")
  }

  // 清理
  if @fs.path_exists(db_path) {
      @fs.remove_file(db_path)
    }
}

// test "@mooncmd.SQLiteEventStore 加载指定版本之后的事件" {
//   let db_path = "/tmp/test_event_store_3.db"

//   // 删除可能存在的旧数据库文件
//   try {
//     @sys.remove_file(db_path)
//   } catch {
//     _ => ()
//   }

//   let store = comanded.@mooncmd.SQLiteEventStore::new(
//     db_path,
//     serialize_test_event,
//     deserialize_test_event,
//   )

//   let aggregate_id = "test-aggregate-2"

//   // 创建并追加多个事件
//   for i in 1..6 {
//     let event = comanded.@mooncmd.EventMessage::new(
//       if i % 2 ,0 {
//         TestEvent::Updated("Version \{i}")
//       } else {
//         TestEvent::Created("Version \{i}")
//       },
//       aggregate_id,
//       i,
//     )
//     store.append(aggregate_id, [event])
//   }

//   // 加载版本 3 之后的事件
//   let loaded_events = store.load(aggregate_id, 3)

//   // 应该只加载版本 4 和 5 的事件
//   assert_eq(loaded_events.length() ,2)
//   assert_eq(loaded_events[0].aggregate_version ,4)
//   assert_eq(loaded_events[1].aggregate_version ,5)

//   // 清理
//   try {
//     @sys.remove_file(db_path)
//   } catch {
//     _ => ()
//   }
// }

// test "@mooncmd.SQLiteEventStore 获取当前版本" {
//   let db_path = "/tmp/test_event_store_4.db"

//   // 删除可能存在的旧数据库文件
//   try {
//     @sys.remove_file(db_path)
//   } catch {
//     _ => ()
//   }

//   let store = comanded.@mooncmd.SQLiteEventStore::new(
//     db_path,
//     serialize_test_event,
//     deserialize_test_event,
//   )

//   let aggregate_id = "test-aggregate-3"

//   // 初始版本应该是 0
//   let initial_version = store.current_version(aggregate_id)
//   assert_eq(initial_version ,0)

//   // 追加事件
//   let event1 = comanded.@mooncmd.EventMessage::new(
//     TestEvent::Created("Test"),
//     aggregate_id,
//     1,
//   )
//   store.append(aggregate_id, [event1])

//   // 版本应该是 1
//   let version1 = store.current_version(aggregate_id)
//   assert_eq(version1 ,1)

//   // 再追加一个事件
//   let event2 = comanded.@mooncmd.EventMessage::new(
//     TestEvent::Updated("Updated"),
//     aggregate_id,
//     2,
//   )
//   store.append(aggregate_id, [event2])

//   // 版本应该是 2
//   let version2 = store.current_version(aggregate_id)
//   assert_eq(version2 ,2)

//   // 清理
//   try {
//     @sys.remove_file(db_path)
//   } catch {
//     _ => ()
//   }
// }

// test "@mooncmd.SQLiteEventStore 不同聚合体的事件隔离" {
//   let db_path = "/tmp/test_event_store_5.db"

//   // 删除可能存在的旧数据库文件
//   try {
//     @sys.remove_file(db_path)
//   } catch {
//     _ => ()
//   }

//   let store = comanded.@mooncmd.SQLiteEventStore::new(
//     db_path,
//     serialize_test_event,
//     deserialize_test_event,
//   )

//   let aggregate_id_1 = "aggregate-1"
//   let aggregate_id_2 = "aggregate-2"

//   // 为第一个聚合体追加事件
//   let event1 = comanded.@mooncmd.EventMessage::new(
//     TestEvent::Created("Account 1"),
//     aggregate_id_1,
//     1,
//   )
//   store.append(aggregate_id_1, [event1])

//   // 为第二个聚合体追加事件
//   let event2 = comanded.@mooncmd.EventMessage::new(
//     TestEvent::Created("Account 2"),
//     aggregate_id_2,
//     1,
//   )
//   store.append(aggregate_id_2, [event2])

//   // 分别加载两个聚合体的事件
//   let events_1 = store.load(aggregate_id_1, 0)
//   let events_2 = store.load(aggregate_id_2, 0)

//   // 验证每个聚合体只加载自己的事件
//   assert_eq(events_1.length() ,1)
//   assert_eq(events_2.length() ,1)

//   match events_1[0].event {
//     TestEvent::Created(name) => assert_eq(name ,"Account 1")
//     _ => assert_eq(false)
//   }

//   match events_2[0].event {
//     TestEvent::Created(name) => assert_eq(name ,"Account 2")
//     _ => assert_eq(false)
//   }

//   // 清理
//   try {
//     @sys.remove_file(db_path)
//   } catch {
//     _ => ()
//   }
// }

// test "@mooncmd.SQLiteEventStore 空聚合体加载" {
//   let db_path = "/tmp/test_event_store_6.db"

//   // 删除可能存在的旧数据库文件
//   try {
//     @sys.remove_file(db_path)
//   } catch {
//     _ => ()
//   }

//   let store = comanded.@mooncmd.SQLiteEventStore::new(
//     db_path,
//     serialize_test_event,
//     deserialize_test_event,
//   )

//   let aggregate_id = "non-existent-aggregate"

//   // 加载不存在的事件应该返回空数组
//   let events = store.load(aggregate_id, 0)
//   assert_eq(events.length() ,0)

//   // 清理
//   try {
//     @sys.remove_file(db_path)
//   } catch {
//     _ => ()
//   }
// }

// test "@mooncmd.SQLiteEventStore 事务回滚测试" {
//   let db_path = "/tmp/test_event_store_7.db"

//   // 删除可能存在的旧数据库文件
//   try {
//     @sys.remove_file(db_path)
//   } catch {
//     _ => ()
//   }

//   let store = comanded.@mooncmd.SQLiteEventStore::new(
//     db_path,
//     serialize_test_event,
//     deserialize_test_event,
//   )

//   let aggregate_id = "test-aggregate-tx"

//   // 先添加一个有效事件
//   let event1 = comanded.@mooncmd.EventMessage::new(
//     TestEvent::Created("Initial"),
//     aggregate_id,
//     1,
//   )
//   store.append(aggregate_id, [event1])

//   // 验证事件已保存
//   let events_before = store.load(aggregate_id, 0)
//   assert_eq(events_before.length() ,1)

//   // 清理
//   try {
//     @sys.remove_file(db_path)
//   } catch {
//     _ => ()
//   }
// }
