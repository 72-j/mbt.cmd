# CHANGELOG

## Unreleased（役8 续，2026-10-22）

- **Effect 重试状态机**：`RetryMachine` 协议面（`EffectErrorKind` 四类封闭集 +
  纯裁决 decide）+ `AggregateRoot::exec_with_effect`（错误分类 → 钩子覆写 →
  退避/熔断内算，wait 注入无时钟）；`account_retry.toml` 词表 → gen 产物
  （黄金门逐字节）+ 手写策略钩子（重试策略 = Policy，红线7）；
  Router `dispatch_with_config` 重试裁决迁移同协议（总错误五臂分类 +
  `store_retry_machine`，API 不变）
- **聚合 gen 上手面**（役7+）：wire 映射随 gen 出（`to_wire`/`from_wire`，
  行格式 v1 首列 schema_version 预留位）+ 契约门脚手架（init 值契约 +
  wire roundtrip 每事件恒等，`<name>_contract_wbtest.mbt` 随件免费）+
  再生入口双形：模块内 `moon run cmd --target native`（消费方一等 CLI，
  扫词表目录按内容识别聚合/重试，`AGG-REGEN:PASS` 尾判）+ binder 侧
  `moon run skelschema/cmd`；README「从零定义一个聚合」五步上手节
- 聚合 TOML 大gen 金样转正（役7）：`account_agg.toml` → `account_gen.mbt`
  （类型/apply/分派骨架）+ 黄金门 + 行为金锚
- 六包布局 + monads（原 mystate）改名；Router `dispatch_once` 端到端接通
  （快照基态/尾事件/EventBus publish/user_id 链）；投影契约成文 +
  LiveProjection 实装

## 0.1.0 (2026-10-21)

- **2026-10-22** 目标定位翻转:preferred_target = **wasm**(原生 wasm,native 同支持);examples 门改显式 `--target native`。

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
