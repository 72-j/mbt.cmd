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

// ===== 守恒律测试（固定罐; 随机交错由 runner 的 qcs 门承担） =====
// 被测性质 = exec 管线的四条守恒律（jsonld/moonxml 守恒罐同体例）:
//   ①版本守恒——每条被接受命令恰好推进一版（k 命令 == k 版, 不丢不跳）
//   ②事件流守恒——未提交流恰 k 条（每命令恰一事件）+ 消息版本位连续
//     1..k（aggregate_version 是乐观并发校验的骨架, 跳版/重版即失明）
//   ③账目守恒——引擎可观状态 ≡ 纯模型镜像逐步同步（双执行零漂移）
//   ④拒绝零痕迹——业务拒不推版/不入流/不记账（失败命令零副作用）

///|
test "mooncmd 守恒律①: 版本守恒——k 命令恰 k 版" {
  let system = system_init()
  let script = [Create, Deposit, Deposit, Deposit]
  for index, command in script {
    assert_eq(run_command(command, system), Continue)
    assert_eq(system.root.state.version, index + 1)
  }
}

///|
test "mooncmd 守恒律②: 事件流守恒——流长 k + 消息版本位连续 1..k" {
  let system = system_init()
  let script = [Create, Deposit, Deposit]
  for command in script {
    assert_eq(run_command(command, system), Continue)
  }
  let stream = system.root.state.uncommitted_events
  assert_eq(stream.length(), 3)
  for index, message in stream {
    assert_eq(message.aggregate_version, index + 1)
  }
}

///|
test "mooncmd 守恒律③: 账目守恒——引擎状态 ≡ 模型镜像逐步同步" {
  let mut model = model_empty()
  let system = system_init()
  let mut deposits = 0
  for command in [Create, Deposit, Deposit] {
    let (_, expected) = model_execute(model, command)
    assert_eq(run_command(command, system), expected)
    model = transition(model, command, expected)
    match command {
      Deposit => deposits = deposits + 1
      _ => ()
    }
    let snapshot = system.root.current_state()
    assert_eq(snapshot.exists, model.state == Active)
    assert_eq(snapshot.count, deposits)
  }
}

///|
test "mooncmd 守恒律④: 拒绝零痕迹——业务拒后版本/事件流/账目全冻结" {
  let system = system_init()
  // 未开户先 Deposit → 业务拒, 三读数全零
  assert_eq(run_command(Deposit, system), Error(1))
  assert_eq(system.root.state.version, 0)
  assert_eq(system.root.state.uncommitted_events.length(), 0)
  assert_eq(system.root.current_state().exists, false)
  // 开户后重复 Create → 业务拒; 拒后三读数冻结在拒前值
  assert_eq(run_command(Create, system), Continue)
  assert_eq(run_command(Create, system), Error(1))
  assert_eq(system.root.state.version, 1)
  assert_eq(system.root.state.uncommitted_events.length(), 1)
  let snapshot = system.root.current_state()
  assert_true(snapshot.exists)
  assert_eq(snapshot.count, 0)
}
