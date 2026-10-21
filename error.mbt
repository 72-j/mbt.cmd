///|
/// 命令错误类型
pub(all) suberror EventSourcingErr {
  CommandErr(CommandError)
  EventStoreErr(EventStoreError)
  SnapshotErr(SnapshotError)
  AggregateErr(AggregateError)
}

///|
pub(all) suberror AggregateError {
  IdParseError(String)
}

///|
pub(all) suberror CommandError {
  InvalidCommand(String)
  UnregisteredCommand(String)
  Unauthorized(String)
  PreconditionFailed(String)
  NotFound(String)
  Conflict(Int32, Int32)
  // StorageError(String)
}

///|
impl Show for CommandError with fn output(self, buf) {
  match self {
    InvalidCommand(reason) => buf.write_string("InvalidCommand: \{reason}")
    Unauthorized(reason) => buf.write_string("Unauthorized: \{reason}")
    PreconditionFailed(reason) =>
      buf.write_string("PreconditionFailed: \{reason}")
    NotFound(id) => buf.write_string("NotFound: \{id}")
    Conflict(v, e) => buf.write_string("Conflict: version \{v} expected \{e}")
    UnregisteredCommand(cmd) => buf.write_string("UnregisteredCommand: \{cmd}")
    // StorageError(msg) => buf.write_string("StorageError: \{msg}")
  }
}

///|
/// 存储错误类型
pub(all) suberror EventStoreError {
  DuplicateVersion(Int32)
  StorageError(String)
  SerializationError(String)
}

///|
/// 显式晋升 Show::to_string（[0079] 隐式晋升已弃用）
pub extend EventStoreError with Show::{to_string}

///|
impl Show for EventStoreError with fn output(self, buf) {
  match self {
    DuplicateVersion(v) => buf.write_string("DuplicateVersion: \{v}")
    StorageError(msg) => buf.write_string("StorageError: \{msg}")
    SerializationError(msg) => buf.write_string("SerializationError: \{msg}")
  }
}

///|
pub(all) suberror EventBusError {
  PublishError(String)
}

///|
impl Show for EventBusError with fn output(self, buf) {
  match self {
    PublishError(v) => buf.write_string("PublishError: \{v}")
  }
}

///|
pub(all) suberror SnapshotError {
  StorageError(String)
  SerializationError(String)
}

///|
/// 显式晋升 Show::to_string（[0079] 隐式晋升已弃用）
pub extend SnapshotError with Show::{to_string}

///|
impl Show for SnapshotError with fn output(self, buf) {
  match self {
    StorageError(msg) => buf.write_string("StorageError: \{msg}")
    SerializationError(msg) => buf.write_string("SerializationError: \{msg}")
  }
}
