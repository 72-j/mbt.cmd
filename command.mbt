// command.mbt
//! 命令定义和处理
/// 命令类型 Trait
// pub trait CommandType {
//   type_name() -> String
// }

///|
/// 命令提取器 Trait
/// 用于从命令中提取聚合根 ID
// pub trait CommandExtractor {
//   /// 从命令中提取聚合根 ID
//   extract_id(self : Self) -> String
//   // type_name(self: Self) -> String
//   /// 获取命令类型名称（可选，用于日志）
//   command_type (self : Self) -> String

//   /// 验证命令（可选，前置校验）
//   // validate(self: Self, cmd: C) -> Result[Unit, CommandError] 
// }

///|
/// 带元数据的命令
pub struct CommandMessage[C] {
  command : C
  command_id : String
  mut correlation_id : String // 用于追踪
  causation_id : String // 父命令 ID
  mut user_id : String?
  timestamp : Int64
  metadata : Json
}

///|
pub fn[C] CommandMessage::new(command : C) -> CommandMessage[C] {
  {
    command,
    command_id: @uuid.v4().to_string(),
    correlation_id: "",
    causation_id: "",
    user_id: None,
    timestamp: @async.now(),
    metadata: @json.to_json("{}"),
  }
}

///|
pub fn[C] CommandMessage::with_correlation(
  self : CommandMessage[C],
  correlation_id : String,
) -> CommandMessage[C] {
  self.correlation_id = correlation_id
  self
}

///|
pub fn[C] CommandMessage::with_user(
  self : CommandMessage[C],
  user_id : String,
) -> CommandMessage[C] {
  self.user_id = Some(user_id)
  self
}

/// 命令处理器接口
// pub trait CommandHandler {
//   /// 处理命令，返回新聚合根
//  handle(self: Self, aggregate : AggregateRoot[Id, C, S, E], cmd : CommandMessage[C]) -> Result[AggregateRoot[Id, C, S, E], CommandError]
// }

///|
/// 命令处理程序类型
pub type CommandHandler[S, C, E] = (S, C) -> Result[Array[E], CommandError]
