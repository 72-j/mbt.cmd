// process_manager.mbt —— Process Manager(saga)框架面(役13a;ADR-MC-011;
// Commanded lib/commanded/process_managers/ 同位素:「aggregates handle
// commands and create events; process managers handle events and create
// commands」)。形态 = 记录型函数面(middleware/projection 同族,无 trait)。
// 事件源 = 显式泵(ADR-MC-011 D2:mooncmd EventStore 无全局流、EventBus
// 无订阅多播——Commanded 的发布订阅重处理面结构性不在,订阅组装留调用方;
// 崩溃重处理挂账候 store 全局流扩面)。状态持久化复用 SnapshotStore 面
// (键 = "<pm名>:<saga_id>";同族面零新表)。命令发射 = 注入闭包(组合
// 自由度:调用方组装 dispatch/Router 任一径)。

///|
/// PM 处理错误面(独立 suberror,不混 dispatch 主链 EventSourcingError
/// ——加臂涟漪重试裁决六臂分类;PM runner 是独立消费面)。
pub(all) suberror ProcessManagerError {
  EmitFailed(String)
  StateFailed(String)
}

///|
/// 错误文案(罐/日志面;suberror 无 Show 家法)。
pub fn ProcessManagerError::to_string(self : ProcessManagerError) -> String {
  match self {
    EmitFailed(reason) => "pm emit failed: \{reason}"
    StateFailed(reason) => "pm state failed: \{reason}"
  }
}

///|
/// 事件→命令的分发目标(跨聚合编排骨):命令本体 + 发往哪个聚合。
pub(all) struct DirectedCommand[C] {
  target_aggregate_id : String
  command : C
}

///|
/// PM 四回调记录面(Commanded ProcessManager behaviour 对位):
/// - `interested`:事件相关性预判(interested?/1 对位);
/// - `saga_id_of`:实例分片键(identity 对位——同键事件归同一 saga 态);
/// - `handle`:产命令(handle/2 对位;可产零到多条,各自带目标聚合);
/// - `apply`:状态演化(apply/2 对位;emit 全成功后才演化后持久)。
/// error/3 裁决不立(ADR-MC-011 D3):显式泵下失败 = raise 透传,
/// 状态不推进,裁决权在调用方 catch(挂账候真需求再立钩子槽)。
pub(all) struct ProcessManager[S, C, E] {
  name : String
  init_state : () -> S
  interested : (E) -> Bool
  saga_id_of : (@event.EventMessage[String, E]) -> String
  handle : (S, E) -> Array[DirectedCommand[C]]
  apply : (S, E) -> S
}

///|
/// PM runner(显式泵形):状态面 = SnapshotStore(键 "<name>:<saga_id>",
/// version 槽 = 事件源聚合版本——诚实溯源,saga 语义弱化记 ADR),
/// 命令发射 = 注入闭包。多 PM = 多 runner 互不干扰(Commanded 多进程
/// 管理器对位)。
pub(all) struct ProcessManagerRunner[S, C, E] {
  manager : ProcessManager[S, C, E]
  snapshots : @store.SnapshotStore[String, S]
  emit : (String, C) -> Unit raise ProcessManagerError
  on_error : PmOnError
  emit_cause : (String, C, @event.EventMessage[String, E]) -> Unit raise ProcessManagerError
}

///|
/// PM 错误裁决(泵错误时由钩子定夺;缺省 Transparent 原错透传):
/// Raise = 原错透传(fail-fast,状态不推进——0.2.x 缺省语义);
/// Skip = 吞错:本事件弃处理(状态不推进,已发命令不撤——at-least-once,
/// ADR-MC-011 D2 语差),泵继续下一事件。
pub(all) enum PmErrorDecision {
  Raise
  Skip
}

///|
/// 错误钩子面(入口 = ProcessManagerError 原错;产出裁决)。
pub(all) enum PmOnError {
  Transparent
  Hook((ProcessManagerError) -> PmErrorDecision)
}

///|
/// 因果发射槽（emit 三参变体:第三参 = 触发事件信封——消费方组
/// causation 链的锚;缺省 = 旧两参 emit 包装,第三参弃用）。
pub(all) enum PmEmitSink[C, E] {
  Sink(
    (String, C, @event.EventMessage[String, E]) -> Unit raise ProcessManagerError,
  )
}

///|
/// SnapshotError → 文案(两臂拆载;store 面未给 to_string)。
fn snapshot_error_text(e : @store.SnapshotError) -> String {
  match e {
    @store.SnapshotError::StorageError(m) => "storage: \{m}"
    @store.SnapshotError::SerializationError(m) => "serialization: \{m}"
  }
}

///|
/// 状态存储键("<pm名>:<saga_id>" 命名空间隔离多 PM)。
fn[S, C, E] ProcessManagerRunner::state_key(
  self : ProcessManagerRunner[S, C, E],
  saga_id : String,
) -> String {
  "\{self.manager.name}:\{saga_id}"
}

///|
/// 错误裁决(钩子缺席 = 透传;Hook 臂 = 钩子定夺)。
fn[S, C, E] ProcessManagerRunner::decide(
  self : ProcessManagerRunner[S, C, E],
  err : ProcessManagerError,
) -> PmErrorDecision {
  match self.on_error {
    Transparent => Raise
    Hook(h) => h(err)
  }
}

///|
/// 构造器(记录面直构同款便捷形;on_error 缺省 = 透传——0.2.x 语义零漂)。
pub fn[S, C, E] ProcessManagerRunner::new(
  manager : ProcessManager[S, C, E],
  snapshots : @store.SnapshotStore[String, S],
  emit : (String, C) -> Unit raise ProcessManagerError,
  on_error? : PmOnError,
  emit_cause? : PmEmitSink[C, E],
) -> ProcessManagerRunner[S, C, E] {
  let on_error = match on_error {
    Some(h) => h
    None => Transparent
  }
  // 归一化:emit_cause 缺席 = 旧两参 emit 包装(第三参弃用——0.2.x 零漂)
  let emit_cause = match emit_cause {
    Some(PmEmitSink::Sink(f)) => f
    None =>
      fn(target, cmd, _msg) -> Unit raise ProcessManagerError {
        emit(target, cmd)
      }
  }
  { manager, snapshots, emit, on_error, emit_cause, }
}

///|
/// 单事件泵:interested? → 装态(load 缺失 = init)→ handle 产命令 →
/// 逐条 emit(任一失败即 raise,状态不推进)→ apply 演化 → save 持久。
/// 返回 = 是否处理(interested 判定,调用方可计数)。
/// 语义注记(ADR-MC-011 D4):emit 成功后崩溃(save 前)= 命令已发、
/// 状态未进——重喂同事件会重发命令;exactly-once 责任在调用方泵序,
/// 词表 evolve 的 set 行幂等、add 行不幂等(挂账)。
pub fn[S, C, E] ProcessManagerRunner::pump_event(
  self : ProcessManagerRunner[S, C, E],
  msg : @event.EventMessage[String, E],
) -> Bool raise ProcessManagerError {
  if !(self.manager.interested)(msg.event) {
    return false
  }
  let saga_id = (self.manager.saga_id_of)(msg)
  let key = self.state_key(saga_id)
  let current = (self.snapshots.load)(key) catch {
    e => raise StateFailed(snapshot_error_text(e))
  }
  let state = match current {
    Some((state, _version)) => state
    None => (self.manager.init_state)()
  }
  let commands = (self.manager.handle)(state, msg.event)
  for directed in commands {
    (self.emit_cause)(directed.target_aggregate_id, directed.command, msg) catch {
      e =>
        match self.decide(EmitFailed(e.to_string())) {
          Raise => raise EmitFailed(e.to_string())
          Skip => return false // 吞错:本事件弃处理(已发命令不撤),泵继续
        }
    }
  }
  let next_state = (self.manager.apply)(state, msg.event)
  (self.snapshots.save)(key, next_state, msg.aggregate_version, msg.timestamp) catch {
    e =>
      match self.decide(StateFailed(snapshot_error_text(e))) {
        Raise => raise StateFailed(snapshot_error_text(e))
        Skip => return false // 吞错:状态不推进(handle 已发命令不撤)
      }
  }
  true
}

///|
/// 批量泵(便捷件):逐事件 pump_event,返回处理计数;任一失败即
/// fail-fast raise(已处理事件不回滚——显式泵序由调用方裁决重喂)。
pub fn[S, C, E] ProcessManagerRunner::pump_events(
  self : ProcessManagerRunner[S, C, E],
  events : Array[@event.EventMessage[String, E]],
) -> Int32 raise ProcessManagerError {
  let mut handled = 0
  for msg in events {
    if self.pump_event(msg) {
      handled = handled + 1
    }
  }
  handled
}
