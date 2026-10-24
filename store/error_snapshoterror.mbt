// ===== SnapshotError 错误族 =====

///|
pub(all) suberror SnapshotError {
  StorageError(String)
  SerializationError(String)
}
