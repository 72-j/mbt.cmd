// ===== Command trait(役8 拆分自 core.mbt)=====

///|
/// 命令：用户意图，可失败
pub trait Command {
  fn type_name() -> String

  /// 执行命令，产生事件或错误
  /// 这是业务校验的地方，不修改状态
  // execute(state : S, cmd : C) -> Result[Array[E], CommandError]
}


