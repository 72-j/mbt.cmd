///|
pub trait Logger {
  fn info(Self, String) -> Unit
}

///|
struct ConsoleLogger {}

///|
pub fn make_console_logger() -> ConsoleLogger {
  ConsoleLogger::{ }
}

///|
pub impl Logger for ConsoleLogger with fn info(_self, msg) {
  println("[INFO] \{msg}")
}

///|
struct MuteLogger {}

///|
pub impl Logger for MuteLogger with fn info(_self, _msg) {
  // Do nothing
}

///|
pub fn make_mute_logger() -> MuteLogger {
  MuteLogger::{ }
}

///|
pub fn log_warn(msg : String) -> Unit {
  // 实现日志记录
  // println("WARN: \{msg}")
  ConsoleLogger::info(make_console_logger(), "[WARN] " + msg)
}

///|
/// R-05 收口（2026-10-08）：显式提升声明，消 implicit_impl_as_method（[0079]）
pub extend ConsoleLogger with Logger::{info}

///|
pub extend MuteLogger with Logger::{info}
