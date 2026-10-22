// bus.mbt —— 事件总线(役8 归位自旧根 store.mbt)

///|
pub(all) struct EventBus[AggregateId, E] {
  publish : (EventBus[AggregateId, E], Array[EventMessage[AggregateId, E]]) -> Unit raise EventBusError
}
