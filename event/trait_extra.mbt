///|
/// 事件：已发生的事实，不可变
pub trait Event {
  /// 应用事件到状态，返回新状态
  /// 纯函数，无副作用
  // apply(state : S, event : E) -> S

  /// 事件版本（用于 Schema 演化）
  fn version() -> Int32

  /// 事件类型名称（用于调试）
  fn type_name() -> String
}

// pub struct AggregateId(String)

///|
/// 聚合根：组合命令处理和事件应用
// pub trait Aggregate {
//   /// 获取聚合根 ID
//   id(state : S) -> Id

//   /// 获取当前状态
//   state(aggregate : Self) -> S

//   /// 获取未提交事件
//   uncommitted_events(aggregate : Self) -> Array[E]

//   /// 创建新聚合根（从空状态开始）
//   empty() -> S

//   /// 从快照恢复
//   from_snapshot(state : S, version : Int) -> Self
// }
