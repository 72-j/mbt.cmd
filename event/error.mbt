// error.mbt —— 总线错误族(役8 归位自旧根 error.mbt)

///|
pub(all) suberror EventBusError {
  PublishError(String)
}

///|
pub extend EventBusError with Show::{to_string}

///|
impl Show for EventBusError with fn output(self, buf) {
  match self {
    PublishError(v) => buf.write_string("PublishError: \{v}")
  }
}
