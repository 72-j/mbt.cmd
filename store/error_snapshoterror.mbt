// ===== SnapshotError 错误族(役8 拆分)=====

///|
pub(all) suberror SnapshotError {
  StorageError(String)
  SerializationError(String)
}
