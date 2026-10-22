// ===== EventStoreError 错误族(役8 拆分自 error.mbt)=====

///|
pub(all) suberror EventStoreError {
  DuplicateVersion(Int32)
  StorageError(String)
  SerializationError(String)
}

///|
pub extend EventStoreError with Show::{to_string}

///|
impl Show for EventStoreError with fn output(self, buf) {
  match self {
    DuplicateVersion(v) => buf.write_string("DuplicateVersion: \{v}")
    StorageError(msg) => buf.write_string("StorageError: \{msg}")
    SerializationError(msg) => buf.write_string("SerializationError: \{msg}")
  }
}
