// event.mbt
//! 事件定义

///|
/// 带元数据的事件
pub(all) struct EventMessage[AggregateId, E] {
  event : E
  event_id : String
  aggregate_id : AggregateId
  aggregate_version : Int32
  correlation_id : String
  causation_id : String
  user_id : String?
  timestamp : Int64
  metadata : Json
  schema_version : Int32
}

// impl[E] EventMessage[E] {

///|
pub fn[AggregateId, E] EventMessage::new(
  event : E,
  aggregate_id : AggregateId,
  version : Int32,
) -> EventMessage[AggregateId, E] {
  {
    event,
    event_id: @uuid.v4().to_string(),
    aggregate_id,
    aggregate_version: version,
    correlation_id: @uuid.v4().to_string(),
    causation_id: "",
    user_id: None,
    timestamp: @async.now(),
    metadata: @json.to_json("{}"),
    schema_version: 1,
  }
}

///|
pub fn[AggregateId, E, C] EventMessage::from_command(
  event : E,
  aggregate_id : AggregateId,
  version : Int32,
  cmd : @command.CommandMessage[C],
) -> EventMessage[AggregateId, E] {
  {
    event,
    event_id: @uuid.v4().to_string(),
    aggregate_id,
    aggregate_version: version,
    correlation_id: cmd.correlation_id,
    causation_id: cmd.command_id,
    user_id: cmd.user_id,
    timestamp: @async.now(),
    metadata: cmd.metadata,
    schema_version: 1,
  }
}
// }

///|
/// 事件流（不可变序列）
pub(all) enum EventStream[AggregateId, E] {
  Nil
  Cons(EventMessage[AggregateId, E], EventStream[AggregateId, E])
}

// impl[E] EventStream[E] {

///|
pub fn[AggregateId, E] EventStream::to_array(
  self : EventStream[AggregateId, E],
) -> Array[EventMessage[AggregateId, E]] {
  fn go(
    stream : EventStream[AggregateId, E],
    acc : Array[EventMessage[AggregateId, E]],
  ) -> Array[EventMessage[AggregateId, E]] {
    match stream {
      Nil => acc
      Cons(event, tail) => go(tail, acc + [event])
    }
  }
  go(self, [])
}

///|
pub fn[AggregateId, E] EventStream::length(
  self : EventStream[AggregateId, E],
) -> Int32 {
  fn go(stream : EventStream[AggregateId, E], acc : Int32) -> Int32 {
    match stream {
      Nil => acc
      Cons(_, tail) => go(tail, acc + 1)
    }
  }
  go(self, 0)
}
// }

// pub trait EventApplier {
//   /// 应用单个事件
//   apply(self: Self,state: S, event: E) -> S

//   /// 批量应用事件
//   apply_batch(self: Self, state: S, events: Array[E]) -> S
// }

///|
pub(all) enum EventApplier[S, E] {
  Single((S, E) -> S)
  Batch((S, Array[E]) -> S)
}
