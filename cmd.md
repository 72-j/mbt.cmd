// 1. 定义命令和事件
pub struct CreateUser { name : String }
pub struct UserCreated { user_id : String, name : String }

// 2. CommandHandler 返回纯事件
let handler = async fn(state : UserState, cmd : CreateUser) -> Result[Array[UserEvent], CommandError] {
  Ok([UserCreated { user_id: "123", name: cmd.name }])  // ← 只返回纯事件
}

// 3. AggregateRoot::execute 自动包装
// 内部会调用 EventMessage::from_command，生成：
// EventMessage {
//   event: UserCreated { ... },
//   aggregate_id: "user-123",
//   aggregate_version: 1,
//   correlation_id: "...",  // 从 cmd 复制
//   causation_id: "...",    // 从 cmd 复制
//   timestamp: ...,
//   ...
// }

// 4. Router 保存 EventMessage
event_store.append("user-123", [event_message])

EventMessage 的传递路径：

CommandHandler 返回 Array[E]
    ↓
AggregateRoot::execute 包装成 Array[EventMessage[E]]
    ↓
存储在 AggregateState.uncommitted_events
    ↓
通过 uncommitted_events() 暴露给 Router
    ↓
Router 调用 event_store.append 保存
    ↓
EventStore 持久化 Array[EventMessage[E]]
这样设计的优点是：

职责分离：CommandHandler 只关心业务逻辑，不关心元数据
自动化：EventMessage 的包装由 AggregateRoot 自动完成
追踪性：correlation_id 和 causation_id 从 Command 自动传递到 Event


CommandHandler 返回 Array[E]
    ↓
AggregateRoot::execute 内部循环：
  for event in events {
    EventMessage::from_command(event, ...)  // ← 包装
    event_messages.push(event_msg)
  }
    ↓
存储在 aggregate.state.uncommitted_events : Array[EventMessage[E]]
    ↓
aggregate.uncommitted_events() 暴露给 Router
    ↓
Router 调用 event_store.append(id, uncommitted_events)
    ↓
EventStore 持久化 Array[EventMessage[E]]