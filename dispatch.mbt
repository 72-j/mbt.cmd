// dispatch.mbt
//! Dispatch 统一编排门面（Commanded dispatch 同位素，更薄——无进程内
//! GenServer、无分布式）：一个调用串完五步——
//!   ① exec 纯裁决产出事件（元数据自动包装）
//!   ② EventStore.append 持久化（乐观并发守门在 store 径）
//!   ③ EventBus.publish 通知订阅方（可空选；失败诚实——事件已落库，
//!      盲重试会双重作用）
//!   ④ 提交（清空未提交事件——已持久化即已提交）
//!   ⑤ Strong 一致性：轮询投影检查点追上目标版本（预算内未追上 =
//!      ConsistencyErr）。轮询等待由调用方注入（红线6：门面不读时钟）。
//! 高级编排（快照基态 / 重试机 / Reader 注入）仍走 Router；本门面是
//! 单聚合直连的默认路径。

/// 一致性级别 Consistency（Eventual/Strong）沿用 router.mbt 定义，此处不重复声明。

///|
/// Dispatch 统一编排门面。
/// projections = Strong 模式下需等待的投影注册表（Eventual 可空）；
/// poll_wait = Strong 轮询间的等待注入（测试用假钟 / 生产接 async sleep）；
/// poll_budget = 轮询次数上限（超过即 ConsistencyErr）。
pub fn[Id, S, C, E] dispatch(
  store : @store.EventStore[Id, E],
  bus : @event.EventBus[Id, E]?,
  aggregate : @aggregate.AggregateRoot[Id, S, C, E],
  cmd : C,
  projections~ : Array[@projection.LiveProjection[Id, E]] = [],
  consistency~ : Consistency = Eventual,
  poll_wait~ : (Int64) -> Unit = fn(_ms) { () },
  poll_budget~ : Int = 100,
) -> @aggregate.AggregateRoot[Id, S, C, E] raise EventSourcingErr {
  // ① 纯裁决（业务拒 → CommandErr，不产出事件）
  let committed = match
    (try {
      Ok(aggregate.exec(cmd))
    } catch {
      e => Err(e)
    }) {
    Ok(next) => next
    Err(e) => raise EventSourcingErr::CommandErr(e)
  }
  let events = committed.uncommitted_events()
  // ② 持久化（DuplicateVersion 等守门错误原样上浮——分类/重试归上层 Effect 协议）
  (store.append)(store, aggregate.id, events) catch {
    e => raise EventSourcingErr::EventStoreErr(e)
  }
  // ③ 通知（可空选）
  match bus {
    Some(bus_ref) =>
      (bus_ref.publish)(bus_ref, events) catch {
        e => raise EventSourcingErr::EventBusErr(e)
      }
    None => ()
  }
  // ④ 提交：清空未提交事件（连续 dispatch 同一根不再重发旧事件）
  let committed = committed.commit()
  // ⑤ Strong 一致性：轮询投影检查点追上目标版本
  if consistency is Strong && projections.length() > 0 {
    let target = committed.version()
    let mut polls = 0
    let mut caught_up = false
    while polls < poll_budget && !caught_up {
      caught_up = true
      for projection in projections {
        projection.refresh() catch {
          e => raise EventSourcingErr::EventStoreErr(e)
        }
        if projection.checkpoint() < target {
          caught_up = false
        }
      }
      if !caught_up {
        poll_wait(50L)
        polls += 1
      }
    }
    if !caught_up {
      raise EventSourcingErr::ConsistencyErr(
        "projection checkpoint behind version \{target} after \{poll_budget} polls",
      )
    }
  }
  committed
}
