# mooncmd

`thy1016/mooncmd` 是一个用 MoonBit 编写的命令侧事件溯源（Event Sourcing /
CQRS）框架库：**命令产出纯事件、框架独占元数据包装、Router 独占持久化写入口**。
命令处理器只做业务裁决并返回纯事件数组；`correlation_id` / `causation_id` /
时间戳 / `schema_version` 等元数据由 `AggregateRoot::execute` 统一包装进
`EventMessage`，杜绝手工组装漏项；落库走乐观并发守门（批次首事件版本必须等于
当前版本 + 1，否则 `DuplicateVersion` 拒写）+ 表级 `UNIQUE(aggregate_id, version)`
兜底，事务失败整体回滚不留脏写。

库不绑定业务：聚合/命令/事件由消费方定义，库提供生命周期
（`AggregateRoot` / `from_events` / `commit` / `to_snapshot`）、路由分发
（`Router` / `RouterBuilder` / Reader 注入面 `dispatch_reader_*`）、存储抽象
（记录型函数面 `EventStore` / `SnapshotStore` / `EventBus`）与 SQLite 落地
后端（`SQLiteEventStore`，单表 `event_stream`）。`mystate/` 子包为纯函数
Monad 基础设施（State / Writer / Reader / EventWriter），不含事件溯源语义。

仓库另附三份架构文档：[spec.md](spec.md)（结构事实与契约）、
[const.md](const.md)（红线裁定簿）与 [adr.md](adr.md)（决策记录）。

## 特性

- **纯事件主链**：`CommandHandler = (S, C) -> Result[Array[E], CommandError]`——
  处理器不碰元数据、不碰存储；事件是不可变事实。
- **元数据自动包装**：`EventMessage::from_command` 承接命令的
  correlation/causation 链，`event_id` 为 uuid v4，时间戳唯一来自
  `@async.now()` 注入点（确定性路径禁取时钟）。
- **乐观并发**：expected_version 守门 + UNIQUE 约束竞态兜底，冲突即
  `EventStoreError::DuplicateVersion(current)`，拒写不落脏。
- **快照加速面**：`to_snapshot` / `SnapshotStore` 记录面 + 快照等价测试
  （快照态起跑 + 尾部重放 ≡ 全量重放）。
- **投影面**：`Projection`（init/apply/apply_batch 记录型）+ 订阅位置
  （Origin / Current / FromVersion）。
- **Monad 注入面**：`mystate` 子包 State/Writer/Reader 三法则注记在案，
  Router 分发以 `DispatchReader` 组合子暴露。

## 使用

```moonbit
// 1. 定义命令/事件/状态（业务侧）
// 2. handler : (S, C) -> Result[Array[E], CommandError]（纯函数）
// 3. applier : EventApplier[S, E]
// 4. 组装 RouteEnv + Router，dispatch_now 或 dispatch Reader
```

完整示例见测试面（`command_test.mbt` 银行账户夹具：开户/存款/取款/销户）。

## 许可证

[木兰宽松许可证 v2（Mulan PSL v2）](LICENSE)。
