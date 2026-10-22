///|
/// 快照存储 Trait
// pub trait SnapshotStore {
//   /// 保存快照
//   save(self : Self, aggregate_id : Id, state : S, version : Int, timestamp : Int64) -> Unit raise SnapshotError

//   /// 加载快照
//   load(self : Self, aggregate_id : Id) -> Option[(S, Int)] raise SnapshotError
// }
pub(all) struct SnapshotStore[AggregateId, S] {
  save : (AggregateId, S, Int32, Int64) -> Unit raise SnapshotError
  load : (AggregateId) -> (S, Int32)? raise SnapshotError
}

///|
/// 快照
pub struct Snapshot[AggregateId, S] {
  aggregate_id : AggregateId
  state : S
  version : Int32
  timestamp : Int64
}

///|
pub fn[AggregateId, S] Snapshot::new(
  aggregate_id : AggregateId,
  state : S,
  version : Int32,
) -> Snapshot[AggregateId, S] {
  { aggregate_id, state, version, timestamp: @async.now(), }
}
