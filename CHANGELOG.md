# CHANGELOG

## 0.1.0 (2026-10-21)

首次成模（独立模块化，moonspace 范式；代码自 2026-10-08 起在主仓演进）：

- 主包 `mooncmd`：命令 → 纯事件 → `EventMessage` 自动包装（correlation/causation/
  timestamp/schema_version）→ `AggregateRoot` 生命周期（execute/commit/from_events/
  to_snapshot）→ `Router` / `RouterBuilder` / `DispatchReader` 组合子
- `SQLiteEventStore`：单表 `event_stream`，乐观并发守门（`DuplicateVersion` 拒写）+
  `UNIQUE(aggregate_id, version)` 兜底 + 事务回滚（errdefer 形）
- 记录型函数面：`EventStore` / `SnapshotStore` / `EventBus`（struct-of-functions 定版）
- 投影面：`Projection` 记录型 + `SubscriptionPosition` + SQLite 持久化投影
- 子包 `mystate`：State / Writer / Reader / EventWriter 纯函数 Monad 基础设施
- `examples/` 可执行示例包：银行账户聚合全链自证（`moon run examples`——
  定义→命令链→落库→重放→乐观并发拒写→销户闭环→快照两径同果，
  终判 `EXAMPLE:PASS`）；用法即文档，业务夹具不入库公开契约面
- 错误面：`EventSourcingErr`（Command/EventStore/Snapshot/Aggregate 四臂 suberror）
- 门读数：104 测试全绿（主包 62 + mystate 42）；`moon check --deny-warn` 双 0

已知路线（详见 todo.md 役5b/5c）：SQLiteEventStore→EventStore 适配器与 Router
端到端接通、EventBus/快照读路径接通、Account 测试夹具出公开契约面、ADR 签发。
