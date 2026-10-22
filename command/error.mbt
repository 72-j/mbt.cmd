// ===== 命令错误族(役8 拆分自 error.mbt)=====

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
/// 显式晋升 Show::to_string（[0079] 隐式晋升已弃会；examples 插值面需要——FR-MC-6 错误面 Show 稳定）
pub extend CommandError with Show::{to_string}

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

