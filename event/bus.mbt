// bus.mbt —— 事件总线

///|
pub(all) struct EventBus[AggregateId, E] {
  publish : (EventBus[AggregateId, E], Array[EventMessage[AggregateId, E]]) -> Unit raise EventBusError
}
