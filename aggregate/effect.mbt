// effect.mbt
//! Effect 重试状态机库缝（spec §2.1）：
//! exec(命令) --raise--> 状态机裁决（重试/放行/熔断）--> 调用方。
//! 状态机自身 = gen 产物（词表 TOML 经骨架生成器产骨架 +
//! 手写钩子）；本件只定协议面与 runner，不含任何策略裁决。

///|
/// 框架错误分类封闭集（结构知识非裁决——分类固定；动作归词表+钩子）
pub(all) enum EffectErrorKind {
  Duplicate // 乐观并发冲突族：DuplicateVersion / Conflict——可重试性质
  Validation // 业务拒绝族：InvalidCommand 等——重放同结果，永不重试
  Storage // 存储层族：StorageError / SerializationError
  Other
}

///|
/// 重试动作封闭集（词表 on_error 值域）
pub(all) enum RetryAction {
  ActionRetry
  ActionExhausted
}

///|
/// 状态机裁决输出
pub(all) enum RetryVerdict {
  WaitRetry(wait_ms~ : Int64)
  GiveUpRaise
}

///|
/// Effect 重试状态机协议（记录面，宪法4；gen 产物实现）
pub(all) struct RetryMachine {
  /// 词表默认分派表（on_error 四类 → 动作）
  default_action : (EffectErrorKind) -> RetryAction
  /// 纯裁决（无时钟无副作用，红线6）：attempt = 本次将为第几次重试（1 起）；
  /// consecutive_failures = 含本次失败的连续失败数。退避时长与熔断判定由此内算。
  decide : (Int32, Int32, EffectErrorKind) -> RetryVerdict
}

///|
/// 策略钩子（红线7：业务裁决归钩子；None = 沿用词表默认分派）
pub(all) struct RetryHooks {
  override_action : (EffectErrorKind) -> RetryAction?
}

///|
/// 纯透钩子（零覆写）
pub fn RetryHooks::none() -> RetryHooks {
  { override_action: fn(_kind) { None }, }
}

///|
/// 命令错误分类（结构知识：Conflict → Duplicate——命令面乐观并发镜像，可重试性质）
pub fn effect_kind_of_command_error(
  err : @command.CommandError,
) -> EffectErrorKind {
  match err {
    Conflict(_, _) => Duplicate
    InvalidCommand(_) => Validation
    UnregisteredCommand(_) => Validation
    Unauthorized(_) => Validation
    PreconditionFailed(_) => Validation
    NotFound(_) => Validation
  }
}

///|
/// 存储错误分类（dispatch 层 with_config 挂钩用）
pub fn effect_kind_of_store_error(
  err : @store.EventStoreError,
) -> EffectErrorKind {
  match err {
    DuplicateVersion(_) => Duplicate
    StorageError(_) => Storage
    SerializationError(_) => Storage
  }
}

///|
/// Effect 形态执行（spec §2.1 分层）：exec 上抛先过状态机——
/// 钩子覆写 > 词表默认 → decide → WaitRetry(ms) 则 wait(ms)（注入时钟，红线6 同源）
/// 后重执行；ActionExhausted / GiveUpRaise（含熔断）→ 原错上抛。
/// 幂等前提：execute Err 不改态 ⇒ 同命令重放同结果。
pub fn[AggregateId, S, C, E] AggregateRoot::exec_with_effect(
  self : AggregateRoot[AggregateId, S, C, E],
  cmd : C,
  machine : RetryMachine,
  hooks : RetryHooks,
  wait : (Int64) -> Unit,
) -> AggregateRoot[AggregateId, S, C, E] raise @command.CommandError {
  let mut attempt = 0
  let mut consecutive_failures = 0
  let mut root = self
  let mut running = true
  while running {
    let outcome : Result[
      AggregateRoot[AggregateId, S, C, E],
      @command.CommandError,
    ] = Ok(root.exec(cmd)) catch { e => Err(e) }
    match outcome {
      Ok(next) => {
        root = next
        running = false
      }
      Err(e) => {
        consecutive_failures = consecutive_failures + 1
        let kind = effect_kind_of_command_error(e)
        let action = match (hooks.override_action)(kind) {
          Some(overridden) => overridden
          None => (machine.default_action)(kind)
        }
        match action {
          ActionExhausted => raise e
          ActionRetry => {
            attempt = attempt + 1
            match (machine.decide)(attempt, consecutive_failures, kind) {
              WaitRetry(wait_ms~) => wait(wait_ms)
              GiveUpRaise => raise e
            }
          }
        }
      }
    }
  }
  root
}
