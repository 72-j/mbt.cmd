// ===== 自建事件存储（配方延伸：EventStore 端口的最小实现）=====
// EventStore 是记录型端口（store 包 pub(all) struct，三函数槽：
// append / load / current_version）——端口即数据访问抽象：起步用内存
// 实现，上生产换 SQLiteEventStore（to_event_store 适配到同一记录面，
// 消费侧代码零改动）。构造形对抄 store/sqlite.mbt 的同款适配器
// （箭头闭包；记录字段作函数调用要带括号且自传首参：
// `(port.append)(port, id, events)`）。

///|
pub struct MemoryEventStore {
  log : Array[@event.EventMessage[String, AccountEvent]]
}

///|
pub fn MemoryEventStore::new() -> MemoryEventStore {
  { log: [], }
}

///|
// 记录面适配：三个函数槽按端口签名直填（箭头闭包捕获共享日志数组）。
// append 内置乐观并发守门（端口合同，与 SQLite 后端同界）：批次首事件
// 版本必须等于当前版本 + 1，否则 DuplicateVersion 拒写。
pub fn MemoryEventStore::to_event_store(
  self : MemoryEventStore,
) -> @store.EventStore[String, AccountEvent] {
  let log = self.log
  let port : @store.EventStore[String, AccountEvent] = {
    append: (_store, aggregate_id, messages) => {
      let mut current : Int32 = 0
      for message in log {
        if message.aggregate_id == aggregate_id {
          current = message.aggregate_version
        }
      }
      if messages.length() > 0 && messages[0].aggregate_version != current + 1 {
        raise @store.EventStoreError::DuplicateVersion(
          messages[0].aggregate_version,
        )
      }
      for message in messages {
        log.push(message)
      }
    },
    load: (_store, aggregate_id, from_version) => {
      let found = []
      for message in log {
        if message.aggregate_id == aggregate_id &&
          message.aggregate_version >= from_version {
          found.push(message)
        }
      }
      found
    },
    current_version: (_store, aggregate_id) => {
      let mut latest : Int32 = 0
      for message in log {
        if message.aggregate_id == aggregate_id &&
          message.aggregate_version > latest {
          latest = message.aggregate_version
        }
      }
      latest
    },
  }
  port
}
