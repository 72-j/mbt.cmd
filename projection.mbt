// projection.mbt
//! 投影：从事件构建读模型（FR-MC-3 投影契约,役5c 成文）
//!
//! 契约（吸收 commanded 检查点语义,MoonBit 形）：
//! 1. **拉取非推送**：投影是 EventStore 的订阅方——只认
//!    `load(aggregate_id, after_checkpoint)`;EventBus 推送与投影无关
//!    （推送 = 通知,投影 = 重放,两法源）。
//! 2. **检查点即版本**：`last_version` = checkpoint;`refresh` 拉取
//!    checkpoint 之后的事件,apply_batch 折入视图,推进检查点——幂等
//!    （同 checkpoint 重拉重放,视图不变）。
//! 3. **apply 纯函数**：投影函数禁副作用、**禁取当前时钟**（时间源唯一,
//!    const 红线6）;视图演化只由事件驱动。
//! 4. **视图持久化可选**：`PersistedProjection` = 视图 + checkpoint 的
//!    SQLite 落点（save 即 ack;load 即恢复）,与 `LiveProjection` 组合
//!    = 重启续跑。
//! MVP 口径：拉取形（poll）;推送订阅随消费需求另役。

///|
/// 视图（MVP 口径 = Json;强类型视图随消费需求扩形）
type View = Json

///|
/// 投影器（记录型函数面,ADR-MC-003 同族）：init 出初始视图,
/// apply 单事件演化,apply_batch 批量折叠（缺省 = 逐事件 apply）。
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
/// 缺省批量折叠（逐事件 apply——多数投影够用;性能敏感可自定义）。
pub fn[AggregateId, E] default_batch(
  apply : (View, EventMessage[AggregateId, E]) -> View,
) -> (View, Array[EventMessage[AggregateId, E]]) -> View {
  fn(view, events) {
    events.fold(init=view, fn(acc, event) { apply(acc, event) })
  }
}

///|
/// 订阅位置（刷新起点语义）
pub(all) enum SubscriptionPosition {
  Origin // 从头开始
  Current // 只订阅新事件
  FromVersion(Int32)
}

///|
/// 解析订阅位置为起始版本（Current 需 store 探版本）。
fn[AggregateId, E] position_version(
  position : SubscriptionPosition,
  event_store : EventStore[AggregateId, E],
  aggregate_id : AggregateId,
) -> Int32 raise EventStoreError {
  match position {
    Origin => 0
    Current => (event_store.current_version)(event_store, aggregate_id)
    FromVersion(v) => v
  }
}

///|
/// 实时投影（内存视图 + 检查点;拉取刷新形——FR-MC-3 参考实装）。
pub(all) struct LiveProjection[AggregateId, E] {
  mut view : View
  mut last_version : Int32
  projection : Projection[AggregateId, E]
  event_store : EventStore[AggregateId, E]
  aggregate_id : AggregateId
}

///|
/// 构造:按订阅位置装载——拉取起始版本之后的事件,批量折入初始视图,
/// 检查点 = 已折末事件版本（流空 = 起始版本）。
pub fn[AggregateId, E] LiveProjection::new(
  aggregate_id : AggregateId,
  event_store : EventStore[AggregateId, E],
  projection : Projection[AggregateId, E],
  position : SubscriptionPosition,
) -> LiveProjection[AggregateId, E] raise EventStoreError {
  let start_version = position_version(position, event_store, aggregate_id)
  let events = (event_store.load)(event_store, aggregate_id, start_version) catch {
    e => raise event_store_error_of(e)
  }
  let view = (projection.apply_batch)((projection.init)(), events)
  let last_version = match events.last() {
    Some(last) => last.aggregate_version
    None => start_version
  }
  { view, last_version, projection, event_store, aggregate_id, }
}

///|
/// 刷新:拉取检查点之后的事件,折入视图,推进检查点;流空 = no-op。
pub fn[AggregateId, E] LiveProjection::refresh(
  self : LiveProjection[AggregateId, E],
) -> Unit raise EventStoreError {
  let events = (self.event_store.load)(
    self.event_store,
    self.aggregate_id,
    self.last_version,
  ) catch {
    e => raise event_store_error_of(e)
  }
  if !events.is_empty() {
    self.view = (self.projection.apply_batch)(self.view, events)
    self.last_version = match events.last() {
      Some(last) => last.aggregate_version
      None => self.last_version
    }
  }
}

///|
/// 读视图
pub fn[AggregateId, E] LiveProjection::get_view(
  self : LiveProjection[AggregateId, E],
) -> View {
  self.view
}

///|
/// 读检查点
pub fn[AggregateId, E] LiveProjection::checkpoint(
  self : LiveProjection[AggregateId, E],
) -> Int32 {
  self.last_version
}

///|
/// SQLite 持久化投影落点（视图 + checkpoint;save 即 ack,load 即恢复——
/// 与 LiveProjection 组合 = 重启续跑）。
pub(all) struct PersistedProjection {
  conn : @sqlite3.Connection
  table_name : String
}

///|
pub fn PersistedProjection::new(
  conn : @sqlite3.Connection,
  table_name : String,
) -> PersistedProjection raise {
  let proj = { conn, table_name, }
  proj.init_schema()
  proj
}

///|
fn PersistedProjection::init_schema(self : PersistedProjection) -> Unit raise {
  let sql = "CREATE TABLE IF NOT EXISTS \{self.table_name} (id TEXT PRIMARY KEY, view_data TEXT NOT NULL, last_version INTEGER NOT NULL, updated_at INTEGER DEFAULT (unixepoch()))"
  let stmt = self.conn.prepare(sql)
  let _ = stmt.step()
  let _ = stmt.finalize() catch { _ => () }
}

///|
pub fn PersistedProjection::save(
  self : PersistedProjection,
  id : String,
  view : View,
  version : Int32,
) -> Unit raise {
  let sql = "INSERT OR REPLACE INTO \{self.table_name} (id, view_data, last_version) VALUES (?, ?, ?)"
  let stmt = self.conn.prepare(sql)
  errdefer {
    let _ = stmt.finalize() catch { _ => () }
  }
  stmt.bind(index=1, id)
  stmt.bind(index=2, @json.to_json(view).stringify())
  stmt.bind(index=3, version)
  let _ = stmt.step()
}

///|
pub fn PersistedProjection::load(
  self : PersistedProjection,
  id : String,
) -> (View, Int32)? raise {
  let sql = "SELECT view_data, last_version FROM \{self.table_name} WHERE id = ?"
  let stmt = self.conn.prepare(sql)
  errdefer {
    let _ = stmt.finalize() catch { _ => () }
  }
  stmt.bind(index=1, id)
  if stmt.step() {
    let data : String = stmt.column(index=0)
    let version : Int64 = stmt.column(index=1)
    let view = @json.parse(data)
    Some((view, version.to_int()))
  } else {
    None
  }
}
