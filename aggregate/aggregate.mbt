// aggregate.mbt
//! 聚合根实现

///|
/// 聚合根状态
pub struct AggregateState[AggregateId, S, E] {
  state : S
  version : Int32
  uncommitted_events : Array[@event.EventMessage[AggregateId, E]]
}

///|
/// 命令处理程序类型
// pub type @command.CommandHandler[S, C, E] = (S, C) -> Array[E] raise @command.CommandError
// pub type @event.EventApplier[S,E] = (S, E) -> S

///|
/// 聚合根
pub struct AggregateRoot[AggregateId, S, C, E] {
  handler : @command.CommandHandler[S, C, E]
  applier : @event.EventApplier[S, E]
  empty_state : S
  mut state : AggregateState[AggregateId, S, E]
  id : AggregateId
  clock : () -> Int64
  id_gen : () -> String
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
/// 缺省系统钟/标识源：信封组装点唯一读钟面（缺省系统钟 @async.now()）
fn default_clock(clock : (() -> Int64)?) -> () -> Int64 {
  match clock {
    Some(clock_fn) => clock_fn
    None => fn() { @async.now() }
  }
}

///|
/// 缺省事件标识源（缺省 @uuid.v4()）
fn default_id_gen(id_gen : (() -> String)?) -> () -> String {
  match id_gen {
    Some(id_fn) => id_fn
    None => fn() { @uuid.v4().to_string() }
  }
}

///|
/// 创建新的聚合根
pub fn[AggregateId, S, C, E] AggregateRoot::new(
  id : AggregateId,
  handler : @command.CommandHandler[S, C, E],
  applier : @event.EventApplier[S, E],
  empty_state : S,
  clock? : () -> Int64,
  id_gen? : () -> String,
) -> AggregateRoot[AggregateId, S, C, E] {
  {
    handler,
    applier,
    empty_state,
    state: { state: empty_state, version: 0, uncommitted_events: [], },
    id,
    clock: default_clock(clock),
    id_gen: default_id_gen(id_gen),
  }
}

///|
/// 从已保存的事件恢复
pub fn[AggregateId, S, C, E] AggregateRoot::from_events(
  id : AggregateId,
  events : Array[@event.EventMessage[AggregateId, E]],
  handler : @command.CommandHandler[S, C, E],
  applier : @event.EventApplier[S, E],
  empty_state : S,
  clock? : () -> Int64,
  id_gen? : () -> String,
) -> AggregateRoot[AggregateId, S, C, E] {
  AggregateRoot::from_snapshot(
    id,
    empty_state,
    empty_state,
    0,
    events,
    handler,
    applier,
    clock=default_clock(clock),
    id_gen=default_id_gen(id_gen),
  )
}

///|
/// 从快照基态 + 尾事件恢复（快照读路径）：base = 快照态/版本，尾事件
/// 折入；尾空 = 版本取快照版本（非 0）。from_events = 本形特例
/// （base = 空态/0，委托）。
pub fn[AggregateId, S, C, E] AggregateRoot::from_snapshot(
  id : AggregateId,
  empty_state : S,
  base_state : S,
  base_version : Int32,
  events : Array[@event.EventMessage[AggregateId, E]],
  handler : @command.CommandHandler[S, C, E],
  applier : @event.EventApplier[S, E],
  clock? : () -> Int64,
  id_gen? : () -> String,
) -> AggregateRoot[AggregateId, S, C, E] {
  let final_state = events.fold(init=base_state, fn(s, e) {
    match applier {
      @event.EventApplier::Single(f) => f(s, e.event)
      @event.EventApplier::Batch(f) => f(s, [e.event])
    }
  })
  let version = match events.last() {
    Some(last) => last.aggregate_version
    None => base_version
  }
  {
    handler,
    applier,
    empty_state,
    state: { state: final_state, version, uncommitted_events: [], },
    id,
    clock: default_clock(clock),
    id_gen: default_id_gen(id_gen),
  }
}

///|
/// 执行命令（借鉴 Commanded 的 execute/apply 模式）
pub fn[AggregateId, S, C, E] AggregateRoot::execute(
  self : AggregateRoot[AggregateId, S, C, E],
  cmd : @command.CommandMessage[C],
) -> AggregateRoot[AggregateId, S, C, E] raise @command.CommandError {
  // 1. Execute: 业务校验，产生事件（handler raise 形，错误直穿）
  let events = (self.handler)(self.state.state, cmd.command)
  // 2. Apply: 应用事件到状态
  let mut current_state = self.state.state
  let mut current_version = self.state.version
  let event_messages : Array[@event.EventMessage[AggregateId, E]] = []
  for event in events {
    current_version += 1
    let event_msg = @event.EventMessage::from_command(
      event,
      self.id,
      current_version,
      cmd,
      clock=self.clock,
      id_gen=self.id_gen,
    )
    event_messages.push(event_msg)
    current_state = match self.applier {
      @event.EventApplier::Single(f) => f(current_state, event)
      @event.EventApplier::Batch(f) => f(current_state, [event])
    }
  }
  // 3. 更新聚合状态
  self.state = {
    state: current_state,
    version: current_version,
    uncommitted_events: self.state.uncommitted_events + event_messages,
  }
  self
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
) -> Array[@event.EventMessage[AggregateId, E]] {
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
) -> @store.Snapshot[AggregateId, S] {
  @store.Snapshot::new(
    self.id,
    self.state.state,
    self.state.version,
    clock=self.clock,
  )
}
// }

///|
/// 形态 A 流式执行:命令自动包装 CommandMessage,
/// 错误 raise 上抛,返回 Self 链式。
/// 用法:root.exec(CreateAccount("main", 100)).exec(DepositMoney(50))
pub fn[AggregateId, S, C, E] AggregateRoot::exec(
  self : AggregateRoot[AggregateId, S, C, E],
  cmd : C,
) -> AggregateRoot[AggregateId, S, C, E] raise @command.CommandError {
  self.execute(
    @command.CommandMessage::new(cmd, clock=self.clock, id_gen=self.id_gen),
  )
}
