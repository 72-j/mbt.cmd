// middleware.mbt —— dispatch 中间件管道(ADR-MC-009;Commanded
// lib/commanded/middleware/ 同位素,收窄为用户挂点:identity 提取与
// 一致性保证两件结构性不需要——dispatch 直收聚合根、Strong 轮询
// 第⑤步内建)。形态 = 记录型函数面三槽(ADR-MC-003 同族,无 trait
// 无 behaviour 宏)。

///|
/// dispatch 中间件只读视角(ADR-MC-009 D3,一记录两相位构造:
/// before/failure 相位 events 空数组、version 为现版本;after 相位
/// events 全量、version 为落库后版本)。
pub(all) struct DispatchContext[Id, C, E] {
  aggregate_id : Id
  command : C
  events : Array[@event.EventMessage[Id, E]]
  version : Int32
}

///|
/// 中间件三槽记录面(ADR-MC-009 D1/D2):
/// - `before`:主链五步前,按数组序;
/// - `after`:主链成功后,逆序(洋葱律,Commanded pipeline 同款);
/// - `failure`:主链五步任一步失败时按数组序,复用 before 相位视角;
///   非 raise 形(用户闭包内自兜落)——原主链错恒原样上浮。
/// before/after 自身抛错直接穿透不进 failure(主链错/挂点错语义
/// 分明,防自触发递归)。
pub(all) struct DispatchMiddleware[Id, C, E] {
  name : String
  before : (DispatchContext[Id, C, E]) -> Unit raise EventSourcingError
  after : (DispatchContext[Id, C, E]) -> Unit raise EventSourcingError
  failure : (DispatchContext[Id, C, E], EventSourcingError) -> Unit
}

///|
/// failure 挂点(数组序;复用 before 相位视角——事件明细不进 failure
/// 槽,需要明细走 after 或 store 侧)。failure 槽非 raise 形,原主链
/// 错恒原样上浮(ADR-MC-009 D2)。
fn[Id, C, E] run_failure_hooks(
  middleware : Array[DispatchMiddleware[Id, C, E]],
  entry_context : DispatchContext[Id, C, E],
  main_error : EventSourcingError,
) -> Unit {
  for middleware_entry in middleware {
    (middleware_entry.failure)(entry_context, main_error)
  }
}

///|
/// 参考件:计时日志中间件(ADR-MC-009 D4——时钟/日志汇两点显式注入:
/// clock 供计时、log 供输出汇;框架不读钟不绑日志面,Logger trait
/// 扩面缓议,槽位收闭包)。
pub fn[Id, C, E] logging_middleware(
  clock~ : () -> Int64,
  log~ : (String) -> Unit,
) -> DispatchMiddleware[Id, C, E] {
  let started_at : Array[Int64] = [0L]
  {
    name: "logging",
    before: context => {
      started_at[0] = clock()
      log("dispatch before: version=\{context.version}")
    },
    after: context => {
      let elapsed_ms = clock() - started_at[0]
      log(
        "dispatch after: version=\{context.version} events=\{context.events.length()} elapsed_ms=\{elapsed_ms}",
      )
    },
    failure: (context, error) => {
      log(
        "dispatch failure: version=\{context.version} error=\{event_sourcing_error_summary(error)}",
      )
    },
  }
}

///|
/// EventSourcingError 摘要词(suberror 无 Show 不插值——显式 match 定文案,
/// 坑账家法:自定义错误插值先补 Show 或改定文案)。
fn event_sourcing_error_summary(error : EventSourcingError) -> String {
  match error {
    CommandErr(_) => "command rejected"
    EventStoreErr(_) => "event store failure"
    EventBusErr(_) => "event bus failure"
    SnapshotErr(_) => "snapshot failure"
    AggregateErr(_) => "aggregate failure"
    ConsistencyErr(msg) => "consistency: \{msg}"
  }
}
