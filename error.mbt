// error.mbt —— 顶层错误总族(役8:子族随域迁子包,总族留门面)

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
