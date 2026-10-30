// ========================================
// System - 真实执行适配层（P0 手维护:接 mooncmd 框架真面）
// FSM: mooncmd_account | Config: mooncmd_quick_machine
// Generated at: 1791000000000（物化源 = quicktest_gen.toml;手维护标记在案）
// ========================================
// 口径（承 moonttl P4.2b:不重写业务语义——被测物 = **框架 exec 管线**）
//   (@aggregate.AggregateRoot 纯裁决 / 事件应用 / 乐观版本推进),域做最小
//   夹具(QkState/QkEvent 本地定义)。余额值面由 bank 契约门承担
//   (quicktest.toml 头注:生成器 assign 表达力只认 true/false,算术不建模)。
// 错误归一化: 业务拒(CommandError)→ Error(1) —— 模型非法转移臂同码。
//
// 本目录是**手维护实例**:`materialize mooncmd quicktest` 只 bootstrap,
// 标记 `.hand-maintained` 在案后不再覆盖。

///|
/// 夹具域状态:exists = 已开户;count = 入账笔数(版本推进的可观侧面)
priv struct QkState {
  exists : Bool
  count : Int32
}

///|
priv enum QkEvent {
  Created
  Deposited
}

///|
/// 纯裁决:未开户只认 Create、已开户只认 Deposit,余者业务拒
/// (与 bank 账户规则同族的最小形——机器命令即域命令,C = Command 直连)
fn qk_handler(
  state : QkState,
  cmd : Command,
) -> Array[QkEvent] raise @command.CommandError {
  match (state.exists, cmd) {
    (false, Create) => [Created]
    (true, Deposit) => [Deposited]
    _ =>
      raise @command.CommandError::InvalidCommand(
        "qk: command invalid for state",
      )
  }
}

///|
fn qk_apply(state : QkState, event : QkEvent) -> QkState {
  match event {
    Created => { exists: true, count: 0, }
    Deposited => { exists: true, count: state.count + 1, }
  }
}

///|
/// System: 被测系统(聚合根,跨命令保持——exec 链式返回自持)
priv struct System {
  mut root : @aggregate.AggregateRoot[String, QkState, Command, QkEvent]
}

///|
fn system_init() -> System {
  {
    root: @aggregate.AggregateRoot::new(
      "qk-main",
      qk_handler,
      @event.EventApplier::Single(qk_apply),
      { exists: false, count: 0, },
    ),
  }
}

///|
/// 真实执行: Command → exec(纯裁决 + 事件应用 + 版本推进)→ Response
/// 错误归一化: 业务拒(CommandError)→ Error(1)(模型非法转移臂同码;
///   模型合法命令若被引擎拒 = postcondition 双执行比较当场红——机器的牙)
fn run_command(command : Command, system : System) -> Response {
  try {
    system.root = system.root.exec(command)
    Continue
  } catch {
    _ => Error(1)
  }
}

///|
/// 冒烟(P0 收口钉):首条转移模型预测 ≡ 引擎响应
test "mooncmd_quick_machine system: 首条转移模型预测 ≡ 引擎响应" {
  let system = system_init()
  let command = Create
  let (_, expected) = model_execute(model_empty(), command)
  assert_eq(run_command(command, system), expected)
}
