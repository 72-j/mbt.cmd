///|
/// Effect 重试状态机库缝七钉（役8 续）：分类器 / 重试两败后成 / 耗尽上抛 /
/// Validation 不重试 / 钩子覆写 / 指数退避序列 / 熔断。
/// 黑盒：夹具本地定义（跨包 helper 不共享）；wait = 收集型假时钟（红线6 注入）；
/// 跨包枚举变体一律限定（@aggregate.Duplicate 形）。

///|
enum EffCmd {
  GoSucceed
  FailTwiceThenOk
  AlwaysConflict
  AlwaysInvalid
}

///|
enum EffEvt {
  Mark
}

///|
struct EffState {
  marks : Int32
}

///|
fn eff_applier(state : EffState, _event : EffEvt) -> EffState {
  { marks: state.marks + 1, }
}

///|
/// 固定退避测试机（max 次重试内每步 interval_ms；超 max = GiveUp）
fn fixed_machine(max : Int32, interval_ms : Int64) -> @aggregate.RetryMachine {
  {
    default_action: fn(kind) {
      match kind {
        @aggregate.Duplicate => @aggregate.ActionRetry
        @aggregate.Validation => @aggregate.ActionExhausted
        @aggregate.Storage => @aggregate.ActionRetry
        @aggregate.Other => @aggregate.ActionExhausted
      }
    },
    decide: fn(attempt, _failures, _kind) {
      if attempt > max {
        @aggregate.GiveUpRaise
      } else {
        @aggregate.WaitRetry(wait_ms=interval_ms)
      }
    },
  }
}

///|
/// 指数退避测试机（base × factor^(attempt-1)，max 截止）
fn exponential_machine(
  max : Int32,
  base_ms : Int64,
  factor : Int64,
) -> @aggregate.RetryMachine {
  {
    default_action: fn(kind) {
      match kind {
        @aggregate.Duplicate => @aggregate.ActionRetry
        _ => @aggregate.ActionExhausted
      }
    },
    decide: fn(attempt, _failures, _kind) {
      if attempt > max {
        @aggregate.GiveUpRaise
      } else {
        let mut ms = base_ms
        let mut step = 1
        while step < attempt {
          ms = ms * factor
          step = step + 1
        }
        @aggregate.WaitRetry(wait_ms=ms)
      }
    },
  }
}

///|
/// 熔断测试机（threshold 连续失败即 GiveUp，退避固定 50ms）
fn circuit_machine(threshold : Int32) -> @aggregate.RetryMachine {
  {
    default_action: fn(kind) {
      match kind {
        @aggregate.Duplicate => @aggregate.ActionRetry
        _ => @aggregate.ActionExhausted
      }
    },
    decide: fn(_attempt, failures, _kind) {
      if failures >= threshold {
        @aggregate.GiveUpRaise
      } else {
        @aggregate.WaitRetry(wait_ms=50L)
      }
    },
  }
}

///|
/// 计数 handler：FailTwiceThenOk 前两次 Conflict（Duplicate 族→可重试），
/// 第三次起放行；AlwaysConflict 永远 Conflict；AlwaysInvalid 永远业务拒。
fn eff_handler(
  calls : Array[Int32],
  _state : EffState,
  cmd : EffCmd,
) -> Result[Array[EffEvt], @command.CommandError] {
  calls[0] = calls[0] + 1
  match cmd {
    GoSucceed => Ok([Mark])
    FailTwiceThenOk =>
      if calls[0] <= 2 {
        Err(@command.CommandError::Conflict(1, 2))
      } else {
        Ok([Mark])
      }
    AlwaysConflict => Err(@command.CommandError::Conflict(1, 2))
    AlwaysInvalid => Err(@command.CommandError::InvalidCommand("nope"))
  }
}

///|
test "分类器钉：命令六变体 + 存储三变体" {
  let kind_of = @aggregate.effect_kind_of_command_error
  assert_true(
    kind_of(@command.CommandError::Conflict(1, 2)) is @aggregate.Duplicate,
  )
  assert_true(
    kind_of(@command.CommandError::InvalidCommand("x")) is @aggregate.Validation,
  )
  assert_true(
    kind_of(@command.CommandError::UnregisteredCommand("x"))
    is @aggregate.Validation,
  )
  assert_true(
    kind_of(@command.CommandError::Unauthorized("x")) is @aggregate.Validation,
  )
  assert_true(
    kind_of(@command.CommandError::PreconditionFailed("x"))
    is @aggregate.Validation,
  )
  assert_true(
    kind_of(@command.CommandError::NotFound("x")) is @aggregate.Validation,
  )
  let store_kind_of = @aggregate.effect_kind_of_store_error
  assert_true(
    store_kind_of(@store.EventStoreError::DuplicateVersion(3))
    is @aggregate.Duplicate,
  )
  assert_true(
    store_kind_of(@store.EventStoreError::StorageError("x"))
    is @aggregate.Storage,
  )
  assert_true(
    store_kind_of(@store.EventStoreError::SerializationError("x"))
    is @aggregate.Storage,
  )
}

///|
test "成功直通：零重试零等待" {
  let calls : Array[Int32] = [0]
  let waits : Array[Int64] = []
  let root = @aggregate.AggregateRoot::new(
    "eff-0",
    fn(state, cmd) { eff_handler(calls, state, cmd) },
    @event.EventApplier::Single(eff_applier),
    { marks: 0, },
  )
  let next = root.exec_with_effect(
    GoSucceed,
    fixed_machine(3, 100L),
    @aggregate.RetryHooks::none(),
    fn(ms) { waits.push(ms) },
  )
  assert_eq(calls[0], 1)
  assert_eq(waits.length(), 0)
  assert_eq(next.version(), 1)
}

///|
test "重试两败后成：Conflict→Duplicate→retry×2→成功" {
  let calls : Array[Int32] = [0]
  let waits : Array[Int64] = []
  let root = @aggregate.AggregateRoot::new(
    "eff-1",
    fn(state, cmd) { eff_handler(calls, state, cmd) },
    @event.EventApplier::Single(eff_applier),
    { marks: 0, },
  )
  let next = root.exec_with_effect(
    FailTwiceThenOk,
    fixed_machine(3, 100L),
    @aggregate.RetryHooks::none(),
    fn(ms) { waits.push(ms) },
  )
  assert_eq(calls[0], 3)
  assert_eq(waits, [100L, 100L])
  assert_eq(next.version(), 1)
  assert_eq(next.current_state().marks, 1)
}

///|
test "耗尽上抛：max=3 → 三等一回后第四次失败 GiveUp 原错上抛" {
  let calls : Array[Int32] = [0]
  let waits : Array[Int64] = []
  let root = @aggregate.AggregateRoot::new(
    "eff-2",
    fn(state, cmd) { eff_handler(calls, state, cmd) },
    @event.EventApplier::Single(eff_applier),
    { marks: 0, },
  )
  let mut raised_conflict = false
  try {
    let _ = root.exec_with_effect(
      AlwaysConflict,
      fixed_machine(3, 100L),
      @aggregate.RetryHooks::none(),
      fn(ms) { waits.push(ms) },
    )
  } catch {
    e => raised_conflict = e is @command.CommandError::Conflict(_, _)
  }
  assert_true(raised_conflict)
  assert_eq(calls[0], 4)
  assert_eq(waits, [100L, 100L, 100L])
}

///|
test "Validation 不重试：业务拒直接上抛，零等待" {
  let calls : Array[Int32] = [0]
  let waits : Array[Int64] = []
  let root = @aggregate.AggregateRoot::new(
    "eff-3",
    fn(state, cmd) { eff_handler(calls, state, cmd) },
    @event.EventApplier::Single(eff_applier),
    { marks: 0, },
  )
  let mut raised_invalid = false
  try {
    let _ = root.exec_with_effect(
      AlwaysInvalid,
      fixed_machine(3, 100L),
      @aggregate.RetryHooks::none(),
      fn(ms) { waits.push(ms) },
    )
  } catch {
    e => raised_invalid = e is @command.CommandError::InvalidCommand(_)
  }
  assert_true(raised_invalid)
  assert_eq(calls[0], 1)
  assert_eq(waits.length(), 0)
}

///|
test "钩子覆写：Duplicate→Exhausted 覆写后零重试（红线7 裁决归钩子）" {
  let calls : Array[Int32] = [0]
  let waits : Array[Int64] = []
  let root = @aggregate.AggregateRoot::new(
    "eff-4",
    fn(state, cmd) { eff_handler(calls, state, cmd) },
    @event.EventApplier::Single(eff_applier),
    { marks: 0, },
  )
  let hooks : @aggregate.RetryHooks = {
    override_action: fn(kind) {
      match kind {
        @aggregate.Duplicate => Some(@aggregate.ActionExhausted)
        _ => None
      }
    },
  }
  let mut raised_conflict = false
  try {
    let _ = root.exec_with_effect(
      AlwaysConflict,
      fixed_machine(3, 100L),
      hooks,
      fn(ms) { waits.push(ms) },
    )
  } catch {
    e => raised_conflict = e is @command.CommandError::Conflict(_, _)
  }
  assert_true(raised_conflict)
  assert_eq(calls[0], 1)
  assert_eq(waits.length(), 0)
}

///|
test "指数退避序列：base=100 factor=2 → waits=[100,200,400]" {
  // 四败后成（指数机 max=4 跑满三次等待：100/200/400）
  let calls : Array[Int32] = [0]
  let handler_four_fails_then_ok = fn(
    _state : EffState,
    cmd : EffCmd,
  ) -> Result[Array[EffEvt], @command.CommandError] {
    calls[0] = calls[0] + 1
    match cmd {
      GoSucceed => Ok([Mark])
      _ =>
        if calls[0] <= 3 {
          Err(@command.CommandError::Conflict(1, 2))
        } else {
          Ok([Mark])
        }
    }
  }
  let waits : Array[Int64] = []
  let root = @aggregate.AggregateRoot::new(
    "eff-5",
    handler_four_fails_then_ok,
    @event.EventApplier::Single(eff_applier),
    { marks: 0, },
  )
  let next = root.exec_with_effect(
    AlwaysConflict,
    exponential_machine(4, 100L, 2L),
    @aggregate.RetryHooks::none(),
    fn(ms) { waits.push(ms) },
  )
  assert_eq(calls[0], 4)
  assert_eq(waits, [100L, 200L, 400L])
  assert_eq(next.version(), 1)
}

///|
test "熔断钉：threshold=2 → 第二次连续失败即 GiveUp（max 未到也拦）" {
  let calls : Array[Int32] = [0]
  let waits : Array[Int64] = []
  let root = @aggregate.AggregateRoot::new(
    "eff-6",
    fn(state, cmd) { eff_handler(calls, state, cmd) },
    @event.EventApplier::Single(eff_applier),
    { marks: 0, },
  )
  let mut raised_conflict = false
  try {
    let _ = root.exec_with_effect(
      AlwaysConflict,
      circuit_machine(2),
      @aggregate.RetryHooks::none(),
      fn(ms) { waits.push(ms) },
    )
  } catch {
    e => raised_conflict = e is @command.CommandError::Conflict(_, _)
  }
  assert_true(raised_conflict)
  assert_eq(calls[0], 2)
  assert_eq(waits, [50L])
}
