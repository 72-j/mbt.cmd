// aggregate.mbt
//! 聚合根实现

///|
/// 聚合根状态
pub struct AggregateState[AggregateId, S, E] {
  state : S
  version : Int32
  uncommitted_events : Array[EventMessage[AggregateId, E]]
}

///|
/// 命令处理程序类型
// pub type CommandHandler[S, C, E] = (S, C) -> Result[Array[E], CommandError]
// pub type EventApplier[S,E] = (S, E) -> S

///|
/// 聚合根
pub struct AggregateRoot[AggregateId, S, C, E] {
  handler : CommandHandler[S, C, E]
  applier : EventApplier[S, E]
  empty_state : S
  mut state : AggregateState[AggregateId, S, E]
  id : AggregateId
}
/// 聚合根数据结构
// pub struct AggregateRoot[Id, S, E] {
//   id : Id
//   state : S
//   version : Int
//   uncommitted_events : Array[E]
// }
// impl[Id, S,C,E] AggregateRoot[Id, S,C,E] {

///|
/// 创建新的聚合根
pub fn[AggregateId, S, C, E] AggregateRoot::new(
  id : AggregateId,
  handler : CommandHandler[S, C, E],
  applier : EventApplier[S, E],
  empty_state : S,
) -> AggregateRoot[AggregateId, S, C, E] {
  {
    handler,
    applier,
    empty_state,
    state: { state: empty_state, version: 0, uncommitted_events: [], },
    id,
  }
}

///|
/// 从已保存的事件恢复
pub fn[AggregateId, S, C, E] AggregateRoot::from_events(
  id : AggregateId,
  events : Array[EventMessage[AggregateId, E]],
  handler : CommandHandler[S, C, E],
  applier : EventApplier[S, E],
  empty_state : S,
) -> AggregateRoot[AggregateId, S, C, E] {
  let final_state = events.fold(init=empty_state, fn(s, e) {
    // applier.apply(s, e.event)
    // Batch 与 execute 路径同构：逐事件单批应用（Batch applier 内部自行折叠）
    match applier {
      EventApplier::Single(f) => f(s, e.event)
      EventApplier::Batch(f) => f(s, [e.event])
    }
  })
  let version = if events.is_empty() {
    0
  } else {
    events[events.length() - 1].aggregate_version
  }

  {
    handler,
    applier,
    empty_state,
    state: { state: final_state, version, uncommitted_events: [], },
    id,
  }
}

///|
/// 执行命令（借鉴 Commanded 的 execute/apply 模式）
pub fn[AggregateId, S, C, E] AggregateRoot::execute(
  self : AggregateRoot[AggregateId, S, C, E],
  cmd : CommandMessage[C],
) -> Result[AggregateRoot[AggregateId, S, C, E], CommandError] {
  // 1. Execute: 业务校验，产生事件
  match (self.handler)(self.state.state, cmd.command) {
    Ok(events) => {
      // 2. Apply: 应用事件到状态
      let mut current_state = self.state.state
      let mut current_version = self.state.version

      let event_messages : Array[EventMessage[AggregateId, E]] = []

      for event in events {
        current_version += 1
        let event_msg = EventMessage::from_command(
          event,
          self.id,
          current_version,
          cmd,
        )
        event_messages.push(event_msg)
        current_state = match self.applier {
          EventApplier::Single(f) => f(current_state, event)
          EventApplier::Batch(f) => f(current_state, [event])
        }
      }

      // 3. 更新聚合状态
      self.state = {
        state: current_state,
        version: current_version,
        uncommitted_events: self.state.uncommitted_events + event_messages,
      }

      Ok(self)
    }
    Err(err) => Err(err)
  }
}

///|
/// 提交事件（清空未提交事件）
pub fn[AggregateId, S, C, E] AggregateRoot::commit(
  self : AggregateRoot[AggregateId, S, C, E],
) -> AggregateRoot[AggregateId, S, C, E] {
  self.state = {
    state: self.state.state,
    version: self.state.version,
    uncommitted_events: [],
  }
  self
}

///|
/// 获取未提交事件
pub fn[AggregateId, S, C, E] AggregateRoot::uncommitted_events(
  self : AggregateRoot[AggregateId, S, C, E],
) -> Array[EventMessage[AggregateId, E]] {
  self.state.uncommitted_events
}

///|
/// 获取当前版本
pub fn[AggregateId, S, C, E] AggregateRoot::version(
  self : AggregateRoot[AggregateId, S, C, E],
) -> Int32 {
  self.state.version
}

///|
/// 获取状态
pub fn[AggregateId, S, C, E] AggregateRoot::current_state(
  self : AggregateRoot[AggregateId, S, C, E],
) -> S {
  self.state.state
}

///|
/// 创建快照
pub fn[AggregateId, S, C, E] AggregateRoot::to_snapshot(
  self : AggregateRoot[AggregateId, S, C, E],
) -> Snapshot[AggregateId, S] {
  Snapshot::new(self.id, self.state.state, self.state.version)
}
// }
