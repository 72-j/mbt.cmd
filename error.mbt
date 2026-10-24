// error.mbt —— 顶层错误总族（子错误族随域住各子包，此处留总族门面）

///|
/// 顶层错误类型
pub(all) suberror EventSourcingErr {
  CommandErr(@command.CommandError)
  EventStoreErr(@store.EventStoreError)
  EventBusErr(@event.EventBusError)
  SnapshotErr(@store.SnapshotError)
  AggregateErr(@aggregate.AggregateError)
  ConsistencyErr(String)
}
