// store.mbt
//! 事件存储抽象

///|
/// @event.EventMessage 记录类型定义

///|
/// 事件存储抽象
// pub trait EventStore {
//   /// 追加事件
//   append(self : Self, aggregate_id : Id, events : Array[@event.EventMessage[E]]) -> Unit raise

//   /// 加载事件
//   load(self : Self, aggregate_id : Id, after_version : Int) -> Array[
//     @event.EventMessage[E],
//   ] raise

//   /// 获取当前版本
//   current_version(self : Self, aggregate_id : Id) -> Int raise
// }
pub(all) struct EventStore[AggregateId, E] {
  append : (
    EventStore[AggregateId, E],
    AggregateId,
    Array[@event.EventMessage[AggregateId, E]],
  ) -> Unit raise EventStoreError
  load : (EventStore[AggregateId, E], AggregateId, Int32) -> Array[
    @event.EventMessage[AggregateId, E],
  ] raise EventStoreError
  current_version : (EventStore[AggregateId, E], AggregateId) -> Int32 raise EventStoreError
}
