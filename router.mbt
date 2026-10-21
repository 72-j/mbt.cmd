// router.mbt
//! 命令路由器 - 基于 Reader Monad 的现代实现

// ============ 类型定义 ============

///|
/// 路由环境（依赖注入容器）
pub struct RouteEnv[AggregateId, S, E] {
  event_store : EventStore[AggregateId, E]
  snapshot_store : SnapshotStore[AggregateId, S]
  event_bus : EventBus[AggregateId, E]?
  logger : &Logger
  default_timeout : Int64
  default_retry : Int32
}

///|
pub fn[AggregateId, E, S] RouteEnv::new(
  event_store : EventStore[AggregateId, E],
  snapshot_store : SnapshotStore[AggregateId, S],
  event_bus : EventBus[AggregateId, E]?,
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
  handlers : Map[String, CommandHandler[S, C, E]] // 改为 Map，key 为命令类型名
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
  handler : CommandHandler[S, C, E],
) -> RouterBuilder[AggregateId, S, C, E] {
  self.handlers[command_type] = handler
  self
}

///|
/// 批量添加处理器
pub fn[AggregateId, S, C, E] RouterBuilder::add_handlers(
  self : RouterBuilder[AggregateId, S, C, E],
  command_type : String,
  handlers : Array[CommandHandler[S, C, E]],
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
type DispatchReader[AggregateId, S, E, R] = @mystate.Reader[
  RouteEnv[AggregateId, S, E],
  R,
]

///|
/// 创建一个 DispatchReader
pub fn[AggregateId, S, E, R] dispatch_reader_new(
  f : (RouteEnv[AggregateId, S, E]) -> R,
) -> DispatchReader[AggregateId, S, E, R] {
  @mystate.Reader::new(f)
}

///|
/// 运行 DispatchReader
pub fn[AggregateId, S, E, R] dispatch_reader_run(
  reader : DispatchReader[AggregateId, S, E, R],
  env : RouteEnv[AggregateId, S, E],
) -> R {
  @mystate.Reader::run(reader, env)
}

///|
/// 映射 DispatchReader 的结果
pub fn[AggregateId, S, E, R, A] dispatch_reader_map(
  reader : DispatchReader[AggregateId, S, E, R],
  f : (R) -> A,
) -> DispatchReader[AggregateId, S, E, A] {
  @mystate.Reader::map(reader, f)
}

///|
/// 绑定 DispatchReader
pub fn[AggregateId, S, E, R, A] dispatch_reader_bind(
  reader : DispatchReader[AggregateId, S, E, R],
  f : (R) -> DispatchReader[AggregateId, S, E, A],
) -> DispatchReader[AggregateId, S, E, A] {
  @mystate.Reader::bind(reader, f)
}

///|
/// 获取环境
pub fn[AggregateId, S, E] dispatch_ask() -> DispatchReader[
  AggregateId,
  S,
  E,
  RouteEnv[AggregateId, S, E],
] {
  @mystate.Reader::ask()
}

///|
/// 从环境中提取值
pub fn[AggregateId, S, E, A] dispatch_asks(
  f : (RouteEnv[AggregateId, S, E]) -> A,
) -> DispatchReader[AggregateId, S, E, A] {
  @mystate.Reader::asks(f)
}

// ============ 路由器 ============

///|
/// 路由器（类似 Commanded Router）
pub struct Router[AggregateId, S, C, E] {
  // handlers : Map[String, AnyHandler[AggregateId, S, E]]
  env : RouteEnv[AggregateId, S, E]
  default_config : CommandConfig
  handlers : Map[String, CommandHandler[S, C, E]] // 改为 Map，key 为命令类型名
}

///|
pub fn[AggregateId, S, C, E] Router::new(
  env : RouteEnv[AggregateId, S, E],
  default_config : CommandConfig,
  handlers : Map[String, CommandHandler[S, C, E]], // 改为 Map，key 为命令类型名
) -> Router[AggregateId, S, C, E] {
  { handlers, env, default_config, }

  // {
  //   env,
  // }
}

///|
pub fn[AggregateId, S, C, E] Router::dispatch(
  _self : Router[AggregateId, S, C, E],
  aggregate_id : AggregateId,
  cmd : CommandMessage[C],
  handler : CommandHandler[S, C, E],
  applier : EventApplier[S, E],
  empty_state : S,
) -> DispatchReader[
  AggregateId,
  S,
  E,
  Result[AggregateRoot[AggregateId, S, C, E], EventSourcingErr],
] {
  dispatch_reader_new(env => {
    // ========== Step 1: 加载历史事件 ==========
    let events = (env.event_store.load)(env.event_store, aggregate_id, 0) catch {
      e =>
        return Err(EventSourcingErr::EventStoreErr(StorageError(e.to_string())))
    }

    // ========== Step 2: 重建聚合根 ==========
    // from_events 会重放所有历史事件，恢复到最后的状态
    let aggregate = AggregateRoot::from_events(
      aggregate_id, events, // 如果没有事件，使用空数组
       handler, applier, empty_state,
    )

    // ========== Step 3: 执行命令 ==========
    // execute 是 async 函数，会：
    // 1. 调用 handler(state, cmd.command) → 返回 Array[E]
    // 2. 对每个 E，创建 EventMessage::from_command → Array[EventMessage[E]]
    // 3. 调用 applier 应用事件到新状态
    // 4. 更新 aggregate.state.uncommitted_events
    let aggregate = aggregate.execute(cmd)
    // let aggregate = match (aggregate.execute_sync(cmd)) {
    //   Ok(agg) => agg
    //   Err(e) => return Err(e)
    // }
    let aggregate = match aggregate {
      Ok(agg) => agg
      Err(e) => return Err(EventSourcingErr::CommandErr(e))
    }
    // ========== Step 4: 获取未提交事件 ==========
    // 这些事件已经是 EventMessage[E] 类型，包含完整的元数据
    let uncommitted_events = aggregate.uncommitted_events()

    // ========== Step 5: 保存事件到存储 ==========
    if !uncommitted_events.is_empty() {
      (env.event_store.append)(
        env.event_store,
        aggregate_id,
        uncommitted_events,
      ) catch {
        e =>
          return Err(
            EventSourcingErr::EventStoreErr(StorageError(e.to_string())),
          )
      }
    }

    // ========== Step 6: 保存快照（每 100 个事件）==========
    let version = aggregate.version()
    if version > 0 && version % 100 == 0 {
      let snapshot = aggregate.to_snapshot()
      (env.snapshot_store.save)(
        snapshot.aggregate_id,
        snapshot.state,
        snapshot.version,
        snapshot.timestamp,
      ) catch {
        e =>
          return Err(
            EventSourcingErr::EventStoreErr(StorageError(e.to_string())),
          )
      }
    }

    // ========== Step 7: 提交并返回 ==========
    // commit 会清空 uncommitted_events
    Ok(aggregate.commit())
  })
}

///|
/// 执行命令（直接执行，不返回 Reader）
pub fn[AggregateId, S, C, E] Router::dispatch_now(
  self : Router[AggregateId, S, C, E],
  aggregate_id : AggregateId,
  cmd : CommandMessage[C],
  handler : CommandHandler[S, C, E],
  applier : EventApplier[S, E],
  empty_state : S,
) -> Result[AggregateRoot[AggregateId, S, C, E], EventSourcingErr] {
  // let reader = self.dispatch_typed(cmd, command_type)
  let reader = self.dispatch(aggregate_id, cmd, handler, applier, empty_state)

  dispatch_reader_run(reader, self.env)
}

///|
/// 带配置的命令分发（高级用法）
/// 
/// 支持自定义超时、重试等配置
pub fn[AggregateId, S, C, E] Router::dispatch_with_config(
  self : Router[AggregateId, S, C, E],
  aggregate_id : AggregateId,
  cmd : CommandMessage[C],
  handler : CommandHandler[S, C, E],
  applier : EventApplier[S, E],
  empty_state : S,
  timeout_ms : Int64,
  max_retries : Int32,
) -> DispatchReader[
  AggregateId,
  S,
  E,
  Result[AggregateRoot[AggregateId, S, C, E], EventSourcingErr],
] {
  // TODO: 实现超时和重试逻辑
  // 可以使用 @async.timeout 和重试循环
  let _config = {
    timeout_ms,
    max_retries,
    consistency: self.default_config.consistency,
  }

  self.dispatch(aggregate_id, cmd, handler, applier, empty_state)
}

///|
/// 所有命令要么全部成功，要么全部失败
pub fn[AggregateId, S, C, E] Router::dispatch_batch(
  self : Router[AggregateId, S, C, E],
  commands : Array[(AggregateId, CommandMessage[C])],
  handler : CommandHandler[S, C, E],
  applier : EventApplier[S, E],
  empty_state : S,
) -> DispatchReader[
  AggregateId,
  S,
  E,
  Result[Array[AggregateRoot[AggregateId, S, C, E]], EventSourcingErr],
] {
  dispatch_reader_new(fn(env) {
    let results : Array[AggregateRoot[AggregateId, S, C, E]] = []
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
//   commands : Array[(AggregateId, CommandMessage[C])],
//   handler : CommandHandler[S, C, E],
//   applier : EventApplier[S, E],
//   empty_state : S,
// ) -> DispatchReader[
//   AggregateId,
//   S,
//   E,
//   Result[Array[AggregateRoot[AggregateId, S, C, E]], EventSourcingErr],
// ] {
//   @mystate.Reader::new_async(async fn(env) raise {
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
  cmd : CommandMessage[C],
  applier : EventApplier[S, E],
  empty_state : S,
) -> Result[AggregateRoot[AggregateId, S, C, E], EventSourcingErr] {
  if self.handlers.is_empty() {
    return Err(
      EventSourcingErr::CommandErr(
        CommandError::UnregisteredCommand("No handlers registered"),
      ),
    )
  }

  // 使用第一个注册的处理器
  // 使用第一个注册的处理器
  let handler = match self.handlers.iter().next() {
    Some((_, h)) => h
    None =>
      return Err(
        EventSourcingErr::CommandErr(
          CommandError::UnregisteredCommand("No handlers registered"),
        ),
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
