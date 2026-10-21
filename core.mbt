// core.mbt
//! Event Sourcing 核心类型类

///|
/// 聚合根 ID Trait
/// 
/// 所有用作聚合根 ID 的类型都必须实现此 trait
// pub type Id = String

///|
/// 聚合根标识
// pub trait AggregateId {
//   to_string() -> String
// }
// pub struct AggregateId(String)
pub trait AggregateId {
  fn to_string(Self) -> String
  fn from_string(s : String) -> Result[Self, EventSourcingErr]
  fn eq(self : Self, other : Self) -> Bool
  // cmp(self : Self, other : Self) -> Int
}

///|
pub impl AggregateId for String with fn to_string(self : String) -> String {
  self
}

///|
pub impl AggregateId for String with fn from_string(s : String) -> Result[
  String,
  EventSourcingErr,
] {
  Ok(s)
}

///|
pub impl AggregateId for String with fn eq(self : String, other : String) -> Bool {
  self == other
}

///|
pub impl AggregateId for Int32 with fn to_string(self : Int32) -> String {

  // MoonBit 中 Int 转 String 的方法
  let mut result = ""
  let mut n = self
  if n == 0 {
    return "0"
  }
  let negative = n < 0
  if negative {
    n = -n
  }
  let digits = []
  while n > 0 {
    let digit = n % 10
    digits.push(digit)
    n = n / 10
  }
  if negative {
    result = "-"
  }
  let mut i = digits.length() - 1
  while i >= 0 {
    result = result + digit_to_char(digits[i])
    i = i - 1
  }
  result
}

///|
pub impl AggregateId for Int32 with fn from_string(s : String) -> Result[
  Int32,
  EventSourcingErr,
] {
  // 简化实现，实际应该处理错误
  let mut result = 0
  let mut negative = false
  let mut i = 0
  let chars = @utf8.encode(s)

  if chars.length() > 0 && chars[0] == 45 { // '-'
    negative = true
    i = 1
  }

  while i < chars.length() {
    let c = chars[i]
    if c >= 48 && c <= 57 { // '0' - '9'
      result = result * 10 + (c.to_int() - 48)
      i = i + 1
    } else {
      return Err(
        EventSourcingErr::AggregateErr(
          IdParseError("Invalid integer string: \{s}"),
        ),
      )
    }
  }

  if negative {
    Ok(-result)
  } else {
    Ok(result)
  }
}

///|
pub impl AggregateId for Int32 with fn eq(self : Int32, other : Int32) -> Bool {
  self == other
}

///|
pub struct AggUUID {
  value : String
}

///|
pub fn AggUUID::new() -> AggUUID {
  AggUUID::{ value: @uuid.v4().to_string(), }
}

///|
pub impl AggregateId for AggUUID with fn to_string(self : AggUUID) -> String {
  // 这里可以添加 UUID 格式验证
  self.value
}

///|
pub impl AggregateId for AggUUID with fn from_string(s : String) -> Result[
  AggUUID,
  EventSourcingErr,
] {
  Ok(AggUUID::{ value: s, })
}

///|
pub impl AggregateId for AggUUID with fn eq(self : AggUUID, other : AggUUID) -> Bool {
  self.value == other.value
}
// pub impl AggregateId for String with cmp(self : String, other : String) -> Int {
//   self.cmp(other)
// }

///|
// pub fn AggregateId::new(id : String) -> AggregateId {
//   AggregateId(id)
// }

///|
// pub fn AggregateId::to_string(self : AggregateId) -> String {
//   self.0
// }

///|
// type C

///|
// type S

///|
// type E

///|
/// 命令：用户意图，可失败
pub trait Command {
  fn type_name() -> String

  /// 执行命令，产生事件或错误
  /// 这是业务校验的地方，不修改状态
  // execute(state : S, cmd : C) -> Result[Array[E], CommandError]
}

///|
/// 事件：已发生的事实，不可变
pub trait Event {
  /// 应用事件到状态，返回新状态
  /// 纯函数，无副作用
  // apply(state : S, event : E) -> S

  /// 事件版本（用于 Schema 演化）
  fn version() -> Int32

  /// 事件类型名称（用于调试）
  fn type_name() -> String
}

// pub struct AggregateId(String)

///|
/// 聚合根：组合命令处理和事件应用
// pub trait Aggregate {
//   /// 获取聚合根 ID
//   id(state : S) -> Id

//   /// 获取当前状态
//   state(aggregate : Self) -> S

//   /// 获取未提交事件
//   uncommitted_events(aggregate : Self) -> Array[E]

//   /// 创建新聚合根（从空状态开始）
//   empty() -> S

//   /// 从快照恢复
//   from_snapshot(state : S, version : Int) -> Self
// }

fn digit_to_char(d : Int32) -> String {
  match d {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    _ => "?"
  }
}

///|
/// R-05 收口（2026-10-08）：显式提升声明，消 implicit_impl_as_method（[0079]）
pub extend AggUUID with AggregateId::{to_string, from_string, eq}
