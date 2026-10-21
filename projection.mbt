// projection.mbt
//! 投影：从事件构建读模型

///|
type View = Json

///|
/// 投影处理器
// pub trait Projection {
//   /// 初始视图
//   init(Self) -> View

//   /// 应用事件到视图
//   apply(self : Self, view : View, event : EventMessage[E]) -> View

//   /// 批量应用
//   apply_batch(self : Self, view : View, events : Array[EventMessage[E]]) -> View
//   //  {
//   //   events.fold(view, |v : View, e : EventMessage[E]| Self::apply(v, e))
//   // }
// }

pub(all) struct Projection[AggregateId, E] {
  init : () -> View
  apply : (View, EventMessage[AggregateId, E]) -> View
  apply_batch : (View, Array[EventMessage[AggregateId, E]]) -> View
}

///|
pub fn[AggregateId, E] Projection::new(
  init : () -> View,
  apply : (View, EventMessage[AggregateId, E]) -> View,
  apply_batch : (View, Array[EventMessage[AggregateId, E]]) -> View,
) -> Projection[AggregateId, E] {
  { init, apply, apply_batch, }
}

///|
/// 订阅位置
pub(all) enum SubscriptionPosition {
  Origin // 从头开始
  Current // 只订阅新事件
  FromVersion(Int32)
}

///|
/// 实时投影（内存中维护）
pub(all) struct LiveProjection[AggregateId, E] {
  view : View
  last_version : Int32
  projection : Projection[AggregateId, E]
  event_store : EventStore[AggregateId, E]
  aggregate_id : AggregateId
}

///|
// pub impl Projection for LiveProjection with init(self : LiveProjection) -> View {
//   self.view
// }

///|
// pub impl Projection for LiveProjection with apply(
//   self : LiveProjection,
//   view : View,
//   event :EventMessage[E],
// ) -> View {
//   ...
// }

///|
// pub impl Projection for LiveProjection with apply_batch(
//   self : LiveProjection,
//   view : View,
//   events : Array[EventMessage[E]],
// ) -> View {
//   ...
// }
// impl LiveProjection[E, View] {
// pub fn LiveProjection::new(
//   aggregate_id : String,
//   event_store : EventStore[String, E],
//   projection : Projection[E, View],
//   position : SubscriptionPosition
// ) -> LiveProjection[E, View]! {
//   let start_version = match position {
//     Origin => 0
//     Current => event_store.current_version(aggregate_id)?
//     FromVersion(v) => v
//   }

//   let events = event_store.load(aggregate_id, start_version)?
//   let view = projection.apply_batch(projection.init(), events)
//   let last_version = if events.is_empty() { start_version } else { events[events.length() - 1].aggregate_version }

//   {
//     view,
//     last_version,
//     projection,
//     event_store,
//     aggregate_id
//   }
// }

// /// 刷新：拉取新事件
// pub fn LiveProjection::refresh( self :LiveProjection[E, View]) -> Unit! {
//   let events = self.event_store.load(self.aggregate_id, self.last_version)?
//   self.view = self.projection.apply_batch(self.view, events)
//   if not events.is_empty() {
//     self.last_version = events[events.length() - 1].aggregate_version
//   }
// }

// pub fn LiveProjection::get_view(self : LiveProjection[E, View]) -> View {
//   self.view
// }
// }

///|
/// SQLite 持久化投影
struct PersistedProjection {
  conn : @sqlite3.Connection
  table_name : String
}

// impl[View : @json.ToJson + @json.FromJson] PersistedProjection[View] {

///|
pub fn PersistedProjection::new(
  conn : @sqlite3.Connection,
  table_name : String,
) -> PersistedProjection {
  let proj = { conn, table_name, }
  proj.init_schema()
  proj
}

///|
fn PersistedProjection::init_schema(self : PersistedProjection) -> Unit {
  let sql =
    #| "CREATE TABLE IF NOT EXISTS \{self.table_name} (
    #|  id TEXT PRIMARY KEY,
    #|  view_data TEXT NOT NULL,
    #|  last_version INTEGER NOT NULL,
    #|  updated_at INTEGER DEFAULT (unixepoch())
    #|)"
  try {
    let stmt = self.conn.prepare(sql)
    ignore(stmt.step())
    stmt.finalize()
  } catch {
    _ => panic()
  }
}

///|
pub fn PersistedProjection::save(
  self : PersistedProjection,
  id : String,
  view : View,
  version : Int32,
) -> Unit {
  let sql = "INSERT OR REPLACE INTO \{self.table_name} (id, view_data, last_version) VALUES (?, ?, ?)"
  try {
    let stmt = self.conn.prepare(sql)
    stmt.bind(index=1, id)
    stmt.bind(index=2, @json.to_json(view).stringify())
    stmt.bind(index=3, version)
    ignore(stmt.step())
    stmt.finalize()
  } catch {
    _ => panic()
  }
}

///|
pub fn PersistedProjection::load(
  self : PersistedProjection,
  id : String,
) -> (View, Int32)? raise {
  let sql = "SELECT view_data, last_version FROM \{self.table_name} WHERE id = ?"
  let stmt = self.conn.prepare(sql)
  stmt.bind(index=1, id)
  if stmt.step() {
    let data : String = stmt.column(index=0)
    let version : Int64 = stmt.column(index=1)
    stmt.finalize()
    let view = @json.parse(data)
    Some((view, version.to_int()))
  } else {
    stmt.finalize()
    None
  }
}
// }
