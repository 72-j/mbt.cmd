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

## 从零定义一个聚合（上手路径）

消费方只需两件：**词表 TOML**（声明）+ **裁决钩子**（业务语义，红线7）。
以 `examples/bank` 为活模板：

1. **写词表**：复制 `examples/bank/account_agg.toml`，改三段——
   `[aggregate.state]` 字段（名/类型/init 值区）、`[[aggregate.events]]`
   事件（载荷字段 + `evolve` 机械演化指令，封闭集 `set/add/append/remove`）、
   `[[aggregate.commands]]` 命令词形。类型封闭集：`string / int / bool`。
2. **再生产物**：词表放 `examples/bank/`（或你的包目录），然后
   `moon run cmd --target native`（模块根）/ `moon run mooncmd/cmd --target native`
   （workspace 仓根，双路锚点）—— 扫 `*.toml` 按内容识别（聚合/重试），
   产 `<name>_gen.mbt`（state/init/事件与命令枚举/apply 演化链/decide 分派/
   wire 映射）+ `<name>_contract_wbtest.mbt`（免费契约门：init 值契约 +
   wire roundtrip 每事件恒等）+ `<name>_retry_gen.mbt`（重试词表时）。
   尾判 `AGG-REGEN:PASS`；产物禁手写（红线9），黄金门逐字节钉死。
3. **写裁决钩子**：`<name>_policy.mbt` 实现 `<Name>DecideHooks`——每命令一个
   `(state, 载荷...) -> Result[Array[Event], String]` 纯函数；重试策略等
   Policy 同理归钩子件（参考 `account_retry_policy.mbt`）。
4. **接线**：`AggregateRoot::new(id, handler 桥, applier, <Name>State::init())`
   → `exec` 链；落库 `SQLiteEventStore::new(path, to_wire/from_wire 包装,
   type_name)`（wire 序列化已随 gen 出，`schema_version` 预留位在首列）。
5. **跑门**：`moon test`（黄金门 + 契约门）与
   `moon run examples/bank --target native`（EXAMPLE:PASS 全链自证）。

事件命名/粒度/归并属通用语言决策，人供（词表）；机械演化与序列化归 gen——
语义归人、机械归机器。

## 许可证

[木兰宽松许可证 v2（Mulan PSL v2）](LICENSE)。
