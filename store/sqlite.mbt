// 存量库 schema 迁移策略:init_schema = IF NOT EXISTS 幂等建;
// 列变更策略 = user_version 逐版迁移(moonrdb K1 同款形),首个 schema 变更需求
// 触发实现;schema_version 列 = 事件 schema 版本(只预留)。

///|
/// SQLite 实现
pub struct SQLiteEventStore[E] {
  conn : @sqlite3.Connection
  serialize : (E) -> Bytes
  deserialize : (Bytes) -> E raise
  get_type_name : (E) -> String
}

// impl[E] SQLiteEventStore[E] {

///|

///|
/// 错误回原族(DuplicateVersion 原样上浮可分辨)
fn event_store_error_of(e : Error) -> EventStoreError {
  match e {
    EventStoreError::DuplicateVersion(v) => DuplicateVersion(v)
    EventStoreError::SerializationError(m) => SerializationError(m)
    _ => StorageError(e.to_string())
  }
}

///|
pub fn[E] SQLiteEventStore::new(
  db_path : String,
  serialize : (E) -> Bytes,
  deserialize : (Bytes) -> E raise,
  get_type_name : (E) -> String,
) -> SQLiteEventStore[E] raise {
  let conn = @sqlite3.Connection::open(db_path)
  let store = { conn, serialize, deserialize, get_type_name, }
  store.init_schema()
  store
}

///|
pub fn[E] SQLiteEventStore::init_schema(
  self : SQLiteEventStore[E],
) -> Unit raise {
  // 注意：prepare 只编译第一条语句，多条 DDL 必须逐条执行
  let create_table =
    #| CREATE TABLE IF NOT EXISTS event_stream (
    #|  id INTEGER PRIMARY KEY AUTOINCREMENT,
    #|  aggregate_id TEXT NOT NULL,
    #|   event_id TEXT NOT NULL,
    #|   event_type TEXT NOT NULL,
    #|   event_data BLOB NOT NULL,
    #|   version INTEGER NOT NULL,
    #|   correlation_id TEXT,
    #|   causation_id TEXT,
    #|   user_id TEXT,
    #|   timestamp INTEGER NOT NULL,
    #|   metadata TEXT,
    #|   schema_version INTEGER NOT NULL DEFAULT 1,
    #|   UNIQUE(aggregate_id, version)
    #|  )
  let idx_aggregate =
    #| CREATE INDEX IF NOT EXISTS idx_aggregate_version
    #| ON event_stream(aggregate_id, version)
  let idx_correlation =
    #| CREATE INDEX IF NOT EXISTS idx_correlation
    #| ON event_stream(correlation_id)

  for sql in [create_table, idx_aggregate, idx_correlation] {
    let stmt = self.conn.prepare(sql)
    ignore(stmt.step())
    stmt.finalize()
  }
}

///|
pub fn[E] SQLiteEventStore::append(
  self : SQLiteEventStore[E],
  aggregate_id : String,
  events : Array[@event.EventMessage[String, E]],
) -> Unit raise {
  // FR-MC-1 乐观并发守门：批次首事件版本必须 = 当前版本 + 1，否则 DuplicateVersion（拒写不落脏）
  if events.length() > 0 {
    let expected = events[0].aggregate_version
    let current = self.current_version(aggregate_id)
    if expected != current + 1 {
      raise EventStoreError::DuplicateVersion(current)
    }
  }
  let insert_sql =
    #|  INSERT INTO event_stream 
    #|  (aggregate_id, event_id, event_type, event_data, version, correlation_id, causation_id, user_id, timestamp, metadata, schema_version)
    #|  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)

  let begin_stmt = self.conn.prepare("BEGIN TRANSACTION")
  ignore(begin_stmt.step())
  begin_stmt.finalize()
  // FR-MC-1/4：任一 INSERT 失败（含 UNIQUE 冲突竞态）⇒ ROLLBACK 后原样上抛，禁静默脏写/悬挂事务
  // （errdefer 形：错误路径自动回滚并重抛原错，消 [0092] fragile_catch_all）
  errdefer {
    let rollback_stmt = self.conn.prepare("ROLLBACK")
    ignore(rollback_stmt.step())
    rollback_stmt.finalize()
  }
  for event in events {
    let stmt = self.conn.prepare(insert_sql)
    stmt.bind(index=1, aggregate_id)
    stmt.bind(index=2, event.event_id)
    stmt.bind(index=3, (self.get_type_name)(event.event))
    stmt.bind(index=4, (self.serialize)(event.event))
    stmt.bind(index=5, event.aggregate_version)
    stmt.bind(index=6, event.correlation_id)
    stmt.bind(index=7, event.causation_id)
    // user_id 列保留在 schema 里；@event.EventMessage 不携带 user_id（命令面才有），落空串
    // user_id 链：CommandMessage.user_id → @event.EventMessage → 落列
    stmt.bind(
      index=8,
      match event.user_id {
        Some(u) => u
        None => ""
      },
    )
    stmt.bind(index=9, event.timestamp)
    stmt.bind(index=10, event.metadata.stringify())
    stmt.bind(index=11, event.schema_version)

    ignore(stmt.step())
    stmt.finalize()
  }

  let commit_stmt = self.conn.prepare("COMMIT")
  ignore(commit_stmt.step())
  commit_stmt.finalize()
}

///|
pub fn[E] SQLiteEventStore::load(
  self : SQLiteEventStore[E],
  aggregate_id : String,
  after_version : Int32,
) -> Array[@event.EventMessage[String, E]] raise {
  let sql =
    #| SELECT event_data, version, event_id, correlation_id, causation_id, timestamp, metadata, user_id, schema_version
    #| FROM event_stream
    #| WHERE aggregate_id = ? AND version > ?
    #| ORDER BY version ASC

  let stmt = self.conn.prepare(sql)
  stmt.bind(index=1, aggregate_id)
  stmt.bind(index=2, after_version.to_int64())

  let events : Array[@event.EventMessage[String, E]] = []

  while stmt.step() {
    let data : Bytes = stmt.column(index=0)
    let version : Int64 = stmt.column(index=1)
    let event_id : String = stmt.column(index=2)
    let correlation_id : String = stmt.column(index=3)
    let causation_id : String = stmt.column(index=4)
    let timestamp : Int64 = stmt.column(index=5)
    let metadata_str : String = stmt.column(index=6)
    let user_id : String = stmt.column(index=7)
    let schema_version : Int64 = stmt.column(index=8)

    let event = (self.deserialize)(data)
    let metadata = @json.parse(metadata_str)

    events.push(@event.EventMessage::{
      event,
      event_id,
      aggregate_id,
      aggregate_version: version.to_int(),
      correlation_id,
      causation_id,
      timestamp,
      metadata,
      schema_version: schema_version.to_int(),
      user_id: if user_id == "" {
        None
      } else {
        Some(user_id)
      },
    })
  }

  stmt.finalize()
  events
}

///|
pub fn[E] SQLiteEventStore::current_version(
  self : SQLiteEventStore[E],
  aggregate_id : String,
) -> Int32 raise {
  let sql =
    #|SELECT COALESCE(MAX(version), 0) FROM event_stream WHERE aggregate_id = ?
  let stmt = self.conn.prepare(sql)
  stmt.bind(index=1, aggregate_id)

  let version = if stmt.step() {
    let v : Int64 = stmt.column(index=0)
    stmt.finalize()
    v.to_int()
  } else {
    stmt.finalize()
    0
  }

  version
}

///|
/// EventStore 记录面适配器：SQLite 实现接入记录型函数面——
/// 错误穿透不抹平（EventStoreError 变体原样上浮，DuplicateVersion 可分辨）。
/// 聚合 id 域 = String（event_stream.aggregate_id 列 TEXT）。
pub fn[E] SQLiteEventStore::to_event_store(
  self : SQLiteEventStore[E],
) -> EventStore[String, E] {
  {
    append: (_store, aggregate_id, events) => {
      self.append(aggregate_id, events) catch {
        e => raise event_store_error_of(e)
      }
    },
    load: (_store, aggregate_id, after_version) => {
      self.load(aggregate_id, after_version) catch {
        e => raise event_store_error_of(e)
      }
    },
    current_version: (_store, aggregate_id) => {
      self.current_version(aggregate_id) catch {
        e => raise event_store_error_of(e)
      }
    },
  }
}
