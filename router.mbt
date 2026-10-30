// router.mbt
//! 命令路由器 - 基于 Reader Monad 的现代实现

// ============ 类型定义 ============

///|
/// 路由环境（依赖注入容器）
pub struct RouteEnv[AggregateId, S, E] {
  event_store : @store.EventStore[AggregateId, E]
  snapshot_store : @store.SnapshotStore[AggregateId, S]
  event_bus : @event.EventBus[AggregateId, E]?
  logger : &Logger
  default_timeout : Int64
  default_retry : Int32
}

///|
pub fn[AggregateId, E, S] RouteEnv::new(
  event_store : @store.EventStore[AggregateId, E],
  snapshot_store : @store.SnapshotStore[AggregateId, S],
  event_bus : @event.EventBus[AggregateId, E]?,
  // logger: &Logger,
  default_timeout : Int64,
  default_retry : Int32,
) -> RouteEnv[AggregateId, S, E] {
  {
    event_store,
    snapshot_store,
    event_bus,
    logger: make_console_logger(),
    default_timeout,
    default_retry,
  }
}
// }

///|
pub(all) struct CommandConfig {
  timeout_ms : Int64
  max_retries : Int32
  consistency : Consistency
}

///|
pub fn CommandConfig::new() -> CommandConfig {
  { timeout_ms: 5000L, max_retries: 3, consistency: Consistency::Strong, }
}

///|
pub fn CommandConfig::with_timeout(
  self : CommandConfig,
  timeout_ms : Int64,
) -> CommandConfig {
  { ..self, timeout_ms, }
}

///|
pub fn CommandConfig::with_retries(
  self : CommandConfig,
  max_retries : Int32,
) -> CommandConfig {
  { ..self, max_retries, }
}

///|
pub fn CommandConfig::with_consistency(
  self : CommandConfig,
  consistency : Consistency,
) -> CommandConfig {
  { ..self, consistency, }
}

// 1. RouterBuilder

///|
pub(all) struct RouterBuilder[AggregateId, S, C, E] {
  env : RouteEnv[AggregateId, S, E]
  mut default_config : CommandConfig
  handlers : Map[String, @command.CommandHandler[S, C, E]] // 改为 Map，key 为命令类型名
}

///|
pub fn[AggregateId, S, C, E] RouterBuilder::new(
  env : RouteEnv[AggregateId, S, E],
) -> RouterBuilder[AggregateId, S, C, E] {
  { env, default_config: CommandConfig::new(), handlers: Map([]), }
}

///|
pub fn[AggregateId, S, C, E] RouterBuilder::add_handler(
  self : RouterBuilder[AggregateId, S, C, E],
  command_type : String,
  handler : @command.CommandHandler[S, C, E],
) -> RouterBuilder[AggregateId, S, C, E] {
  self.handlers[command_type] = handler
  self
}

///|
/// 批量添加处理器
pub fn[AggregateId, S, C, E] RouterBuilder::add_handlers(
  self : RouterBuilder[AggregateId, S, C, E],
  command_type : String,
  handlers : Array[@command.CommandHandler[S, C, E]],
) -> RouterBuilder[AggregateId, S, C, E] {
  for handler in handlers {
    self.handlers[command_type] = handler
  }
  self
}

///|
/// 设置默认超时时间（毫秒）
pub fn[AggregateId, S, C, E] RouterBuilder::with_default_timeout(
  self : RouterBuilder[AggregateId, S, C, E],
  timeout_ms : Int64,
) -> RouterBuilder[AggregateId, S, C, E] {
  self.default_config = self.default_config.with_timeout(timeout_ms)
  self
}

///|
/// 设置默认重试次数
pub fn[AggregateId, S, C, E] RouterBuilder::with_default_retries(
  self : RouterBuilder[AggregateId, S, C, E],
  max_retries : Int32,
) -> RouterBuilder[AggregateId, S, C, E] {
  self.default_config = self.default_config.with_retries(max_retries)
  self
}

///|
/// 设置一致性级别
pub fn[AggregateId, S, C, E] RouterBuilder::with_consistency(
  self : RouterBuilder[AggregateId, S, C, E],
  consistency : Consistency,
) -> RouterBuilder[AggregateId, S, C, E] {
  self.default_config = self.default_config.with_consistency(consistency)
  self
}

///|
/// 获取已注册的处理器数量
pub fn[AggregateId, S, C, E] RouterBuilder::handler_count(
  self : RouterBuilder[AggregateId, S, C, E],
) -> Int32 {
  self.handlers.length()
}

///|
pub fn[AggregateId, S, C, E] RouterBuilder::build(
  self : RouterBuilder[AggregateId, S, C, E],
) -> Router[AggregateId, S, C, E] {
  guard self.handler_count() > 0 else { panic() }
  Router::new(self.env, self.default_config, self.handlers)
}

// ============ 命令分发 Reader ============

///|
type DispatchReader[AggregateId, S, E, R] = @monads.Reader[
  RouteEnv[AggregateId, S, E],
  R,
]

///|
/// 创建一个 DispatchReader
pub fn[AggregateId, S, E, R] dispatch_reader_new(
  f : (RouteEnv[AggregateId, S, E]) -> R,
) -> DispatchReader[AggregateId, S, E, R] {
  @monads.Reader::new(f)
}

///|
/// 运行 DispatchReader
pub fn[AggregateId, S, E, R] dispatch_reader_run(
  reader : DispatchReader[AggregateId, S, E, R],
  env : RouteEnv[AggregateId, S, E],
) -> R {
  @monads.Reader::run(reader, env)
}

///|
/// 映射 DispatchReader 的结果
pub fn[AggregateId, S, E, R, A] dispatch_reader_map(
  reader : DispatchReader[AggregateId, S, E, R],
  f : (R) -> A,
) -> DispatchReader[AggregateId, S, E, A] {
  @monads.Reader::map(reader, f)
}

///|
/// 绑定 DispatchReader
pub fn[AggregateId, S, E, R, A] dispatch_reader_bind(
  reader : DispatchReader[AggregateId, S, E, R],
  f : (R) -> DispatchReader[AggregateId, S, E, A],
) -> DispatchReader[AggregateId, S, E, A] {
  @monads.Reader::bind(reader, f)
}

///|
/// 获取环境
pub fn[AggregateId, S, E] dispatch_ask() -> DispatchReader[
  AggregateId,
  S,
  E,
  RouteEnv[AggregateId, S, E],
] {
  @monads.Reader::ask()
}

///|
/// 从环境中提取值
pub fn[AggregateId, S, E, A] dispatch_asks(
  f : (RouteEnv[AggregateId, S, E]) -> A,
) -> DispatchReader[AggregateId, S, E, A] {
  @monads.Reader::asks(f)
}

// ============ 路由器 ============

///|
/// 路由器（类似 Commanded Router）
pub struct Router[AggregateId, S, C, E] {
  // handlers : Map[String, AnyHandler[AggregateId, S, E]]
  env : RouteEnv[AggregateId, S, E]
  default_config : CommandConfig
  handlers : Map[String, @command.CommandHandler[S, C, E]] // 改为 Map，key 为命令类型名
}

///|
pub fn[AggregateId, S, C, E] Router::new(
  env : RouteEnv[AggregateId, S, E],
  default_config : CommandConfig,
  handlers : Map[String, @command.CommandHandler[S, C, E]], // 改为 Map，key 为命令类型名
) -> Router[AggregateId, S, C, E] {
  { handlers, env, default_config, }

  // {
  //   env,
  // }
}

///|
/// 错误回原族（错误穿透不抹平）：@store.EventStoreError 变体原样上浮
/// （DuplicateVersion 可分辨），非本族错才降维 StorageError 文本。
fn event_store_error_of(e : Error) -> @store.EventStoreError {
  match e {
    @store.EventStoreError::DuplicateVersion(v) =>
      @store.EventStoreError::DuplicateVersion(v)
    @store.EventStoreError::SerializationError(m) =>
      @store.EventStoreError::SerializationError(m)
    _ => @store.EventStoreError::StorageError(e.to_string())
  }
}

///|
fn snapshot_error_of(e : Error) -> @store.SnapshotError {
  match e {
    @store.SnapshotError::StorageError(m) =>
      @store.SnapshotError::StorageError(m)
    @store.SnapshotError::SerializationError(m) =>
      @store.SnapshotError::SerializationError(m)
    _ => @store.SnapshotError::StorageError(e.to_string())
  }
}

///|
fn event_bus_error_of(e : Error) -> @event.EventBusError {
  match e {
    @event.EventBusError::PublishError(m) =>
      @event.EventBusError::PublishError(m)
    _ => @event.EventBusError::PublishError(e.to_string())
  }
}

///|
/// 单次分发：
/// Step 0 快照基态（快照读路径）→ Step 1 尾事件（after_version =
/// 快照版本）→ Step 2 from_snapshot 重建 → Step 3 执行 → Step 4 append
/// （错误穿透不抹平）→ Step 4.5 EventBus 发布（失败 = Failed
/// 诚实——事件已持久，盲目重试 dispatch 会双重作用，at-least-once 投递
/// 归后续裁定）→ Step 5 快照（每 100 版）→ Step 6 commit。
fn[AggregateId, S, C, E] Router::dispatch_once(
  env : RouteEnv[AggregateId, S, E],
  aggregate_id : AggregateId,
  cmd : @command.CommandMessage[C],
  handler : @command.CommandHandler[S, C, E],
  applier : @event.EventApplier[S, E],
  empty_state : S,
) -> @aggregate.AggregateRoot[AggregateId, S, C, E] raise EventSourcingErr {
  // ========== Step 0: 快照基态 ==========
  let base = (env.snapshot_store.load)(aggregate_id) catch {
    e => raise EventSourcingErr::SnapshotErr(snapshot_error_of(e))
  }
  let (base_state, base_version) = match base {
    Some((state, version)) => (state, version)
    None => (empty_state, 0)
  }
  // ========== Step 1: 加载快照后的尾事件 ==========
  let events = (env.event_store.load)(
    env.event_store,
    aggregate_id,
    base_version,
  ) catch {
    e => raise EventSourcingErr::EventStoreErr(event_store_error_of(e))
  }
  // ========== Step 2: 快照态 + 尾事件重建聚合根 ==========
  let aggregate = @aggregate.AggregateRoot::from_snapshot(
    aggregate_id, empty_state, base_state, base_version, events, handler, applier,
  )
  // ========== Step 3: 执行命令 ==========
  let aggregate = aggregate.execute(cmd) catch {
    e => raise EventSourcingErr::CommandErr(e)
  }
  let uncommitted_events = aggregate.uncommitted_events()
  // ========== Step 4: 保存事件（错误穿透）==========
  if !uncommitted_events.is_empty() {
    (env.event_store.append)(env.event_store, aggregate_id, uncommitted_events) catch {
      e => raise EventSourcingErr::EventStoreErr(event_store_error_of(e))
    }
  }
  // ========== Step 4.5: EventBus 发布 ==========
  match env.event_bus {
    Some(bus) =>
      (bus.publish)(bus, uncommitted_events) catch {
        e => raise EventSourcingErr::EventBusErr(event_bus_error_of(e))
      }
    None => ()
  }
  // ========== Step 5: 保存快照（每 100 个事件）==========
  let version = aggregate.version()
  if version > 0 && version % 100 == 0 {
    let snapshot = aggregate.to_snapshot()
    (env.snapshot_store.save)(
      snapshot.aggregate_id,
      snapshot.state,
      snapshot.version,
      snapshot.timestamp,
    ) catch {
      e => raise EventSourcingErr::SnapshotErr(snapshot_error_of(e))
    }
  }
  // ========== Step 6: 提交并返回 ==========
  aggregate.commit()
}

///|
pub fn[AggregateId, S, C, E] Router::dispatch(
  _self : Router[AggregateId, S, C, E],
  aggregate_id : AggregateId,
  cmd : @command.CommandMessage[C],
  handler : @command.CommandHandler[S, C, E],
  applier : @event.EventApplier[S, E],
  empty_state : S,
) -> DispatchReader[
  AggregateId,
  S,
  E,
  Result[@aggregate.AggregateRoot[AggregateId, S, C, E], EventSourcingErr],
] {
  dispatch_reader_new(env => {
    Ok(
      Router::dispatch_once(
        env, aggregate_id, cmd, handler, applier, empty_state,
      ),
    ) catch {
      e => Err(e)
    }
  })
}

///|
/// 执行命令（直接执行，不返回 Reader）
pub fn[AggregateId, S, C, E] Router::dispatch_now(
  self : Router[AggregateId, S, C, E],
  aggregate_id : AggregateId,
  cmd : @command.CommandMessage[C],
  handler : @command.CommandHandler[S, C, E],
  applier : @event.EventApplier[S, E],
  empty_state : S,
) -> @aggregate.AggregateRoot[AggregateId, S, C, E] raise EventSourcingErr {
  // let reader = self.dispatch_typed(cmd, command_type)
  let reader = self.dispatch(aggregate_id, cmd, handler, applier, empty_state)

  match dispatch_reader_run(reader, self.env) {
    Ok(agg) => agg
    Err(e) => raise e
  }
}

///|
/// 带配置的命令分发（重试裁决走 Effect 协议）：
/// **max_retries 生效** = Duplicate 族乐观并发重试（重载→重执行→重追加，
/// ES 正统重试语义——命令对最新态重新裁决），裁决走 RetryMachine 记录面
/// （effect_kind_of_sourcing_err 分类 + 机器 decide 上限门——分类/动作/上限
/// 全机器面，与 aggregate/effect 协议同源）；**timeout_ms 降级声明** = MVP
/// 同步径无定时器，退避时长同步径忽略（WaitRetry → 立即重试），随 async
/// dispatch 面另行接入。dispatch_with_config 与 dispatch 的差别仅此。
pub fn[AggregateId, S, C, E] Router::dispatch_with_config(
  self : Router[AggregateId, S, C, E],
  aggregate_id : AggregateId,
  cmd : @command.CommandMessage[C],
  handler : @command.CommandHandler[S, C, E],
  applier : @event.EventApplier[S, E],
  empty_state : S,
  timeout_ms : Int64,
  max_retries : Int32,
) -> DispatchReader[
  AggregateId,
  S,
  E,
  Result[@aggregate.AggregateRoot[AggregateId, S, C, E], EventSourcingErr],
] {
  ignore(timeout_ms)
  ignore(self)
  let machine = Router::store_retry_machine(max_retries)
  dispatch_reader_new(env => {
    Ok(
      Router::dispatch_with_retry(
        env, aggregate_id, cmd, handler, applier, empty_state, machine,
      ),
    ) catch {
      e => Err(e)
    }
  })
}

///|
/// 总错误分类（Effect 协议结构知识面——分类固定非裁决）：
/// 命令/存储族各归各分类器；快照故障归 Storage；聚合 id 解析形归 Other。
pub fn effect_kind_of_sourcing_err(
  err : EventSourcingErr,
) -> @aggregate.EffectErrorKind {
  match err {
    CommandErr(e) => @aggregate.effect_kind_of_command_error(e)
    EventStoreErr(e) => @aggregate.effect_kind_of_store_error(e)
    SnapshotErr(_) => @aggregate.Storage
    EventBusErr(_) => @aggregate.Storage
    ConsistencyErr(_) => @aggregate.Other
    AggregateErr(_) => @aggregate.Other
  }
}

///|
/// 分发重试机（router 径词表：Duplicate 族 retry，余 exhausted；上限 =
/// max_retries；WaitRetry(0) = 同步径立即重试，退避随 async 面接入）
fn Router::store_retry_machine(max_retries : Int32) -> @aggregate.RetryMachine {
  {
    default_action: fn(kind) {
      match kind {
        @aggregate.Duplicate => @aggregate.ActionRetry
        _ => @aggregate.ActionExhausted
      }
    },
    decide: fn(attempt, _failures, _kind) {
      if attempt > max_retries {
        @aggregate.GiveUpRaise
      } else {
        @aggregate.WaitRetry(wait_ms=0L)
      }
    },
  }
}

///|
/// 乐观并发重试循环（协议形：分类 → 机器默认分派 → decide 门；
/// 无手写错误硬匹配。WaitRetry 同步径立即重试——退避时长随 async 面接入）
fn[AggregateId, S, C, E] Router::dispatch_with_retry(
  env : RouteEnv[AggregateId, S, E],
  aggregate_id : AggregateId,
  cmd : @command.CommandMessage[C],
  handler : @command.CommandHandler[S, C, E],
  applier : @event.EventApplier[S, E],
  empty_state : S,
  machine : @aggregate.RetryMachine,
) -> @aggregate.AggregateRoot[AggregateId, S, C, E] raise EventSourcingErr {
  let mut attempts = 0
  let mut consecutive_failures = 0
  let mut result = Ok(
    Router::dispatch_once(env, aggregate_id, cmd, handler, applier, empty_state),
  ) catch {
    e => Err(e)
  }
  let mut running = result is Err(_)
  while running {
    let err = match result {
      Err(e) => e
      Ok(agg) => return agg
    }
    consecutive_failures += 1
    let kind = effect_kind_of_sourcing_err(err)
    match (machine.default_action)(kind) {
      @aggregate.ActionExhausted => {
        running = false
        raise err
      }
      @aggregate.ActionRetry => {
        attempts += 1
        match (machine.decide)(attempts, consecutive_failures, kind) {
          @aggregate.WaitRetry(_) =>
            result = Ok(
              Router::dispatch_once(
                env, aggregate_id, cmd, handler, applier, empty_state,
              ),
            ) catch {
              e => Err(e)
            }
          @aggregate.GiveUpRaise => {
            running = false
            raise err
          }
        }
      }
    }
  }
  match result {
    Ok(agg) => agg
    Err(e) => raise e
  }
}

///|
/// 所有命令要么全部成功，要么全部失败
pub fn[AggregateId, S, C, E] Router::dispatch_batch(
  self : Router[AggregateId, S, C, E],
  commands : Array[(AggregateId, @command.CommandMessage[C])],
  handler : @command.CommandHandler[S, C, E],
  applier : @event.EventApplier[S, E],
  empty_state : S,
) -> DispatchReader[
  AggregateId,
  S,
  E,
  Result[
    Array[@aggregate.AggregateRoot[AggregateId, S, C, E]],
    EventSourcingErr,
  ],
] {
  dispatch_reader_new(fn(env) {
    let results : Array[@aggregate.AggregateRoot[AggregateId, S, C, E]] = []
    for item in commands {
      let id = item.0
      let cmd = item.1
      let reader = self.dispatch(id, cmd, handler, applier, empty_state)
      match dispatch_reader_run(reader, env) {
        Ok(aggregate) => results.push(aggregate)
        Err(e) => return Err(e)
      }
    }
    Ok(results)
  })
}

// pub fn[AggregateId, S, C, E] Router::dispatch_batch_parallel(
//   self : Router[AggregateId, S, C, E],
//   commands : Array[(AggregateId, @command.CommandMessage[C])],
//   handler : @command.CommandHandler[S, C, E],
//   applier : @event.EventApplier[S, E],
//   empty_state : S,
// ) -> DispatchReader[
//   AggregateId,
//   S,
//   E,
//   Result[Array[@aggregate.AggregateRoot[AggregateId, S, C, E]], EventSourcingErr],
// ] {
//   @monads.Reader::new_async(async fn(env) raise {
//     let results = Ref::new(Array::new())
//     let errors = Ref::new(Array::new())

//     ignore(@async.with_task_group( fn(tg)  {
//       for item in commands {
//         let id = item.0
//         let cmd = item.1
//         let env_clone = env

//         ignore(tg.spawn( fn ()  {
//           let reader = self.dispatch(id, cmd, handler, applier, empty_state)
//           match dispatch_reader_run(reader, env_clone) {
//             Ok(aggregate) => results.update(fn(arr) { 
//               arr.push(aggregate)
//               arr
//             })
//             Err(e) => errors.update(fn(arr) {
//               arr.push(e)
//               arr
//             })
//           }
//         }))
//       }
//     }))

//     // 等待所有任务完成
//     let error_arr = errors.val
//     if !error_arr.is_empty() {
//       Err(error_arr[0])
//     } else {
//       Ok(results.val)
//     }
//   })
// }

///|
/// 如果只注册了一个处理器，可以直接使用此方法
pub fn[AggregateId, S, C, E] Router::dispatch_default(
  self : Router[AggregateId, S, C, E],
  aggregate_id : AggregateId,
  cmd : @command.CommandMessage[C],
  applier : @event.EventApplier[S, E],
  empty_state : S,
) -> @aggregate.AggregateRoot[AggregateId, S, C, E] raise EventSourcingErr {
  if self.handlers.is_empty() {
    raise EventSourcingErr::CommandErr(
      @command.CommandError::UnregisteredCommand("No handlers registered"),
    )
  }

  // 使用第一个注册的处理器
  // 使用第一个注册的处理器
  let handler = match self.handlers.iter().next() {
    Some((_, h)) => h
    None =>
      raise EventSourcingErr::CommandErr(
        @command.CommandError::UnregisteredCommand("No handlers registered"),
      )
  }
  self.dispatch_now(aggregate_id, cmd, handler, applier, empty_state)
}

///|

// ============ 辅助类型 ============

///|
pub(all) enum Consistency {
  Eventual
  Strong
}
