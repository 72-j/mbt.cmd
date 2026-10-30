# CHANGELOG

## 0.2.1（2026-10-31）

**新增 quicktest：QuickMachine 随机状态机测试面**（参考 pbtgen 思路；
三面 TOML(fsm/生成/业务) → pbtgen 生成器物化骨架 → P0 接框架真面）。

### 新增

- `quicktest` 包：账户生命周期 FSM(Closed/Active + Create/Deposit)的
  随机属性测试机——随机门 60 例 + 固定脚本门 + 覆盖门(long-run 见证
  `resp:Continue`),模型 ≡ 引擎双执行比较(聚合 exec 管线真面,域做最小
  夹具)。`.hand-maintained` 标记在案(bootstrap-only 物化纪律)。
- 依赖:`moonbit-community/quickcheck_statemachine@0.0.1` +
  `moonbitlang/quickcheck@0.15.1`(统一最新;0.14.0 注册表 tarball 为
  旧格式 moon.mod.json,新工具链拒装——统一升级即绕)。

### 测试

- 全套件 native 62→71(quicktest 9 件);wasm 同绿;EXAMPLE:PASS 不变。

## 0.2.0（2026-10-30）

**破坏性：写路径 failable API 迁 raise 风格**（工具链 [0078]
result_error_return 收口，`moon check --deny-warn` 门恢复绿）。

### 对外 API

- **破坏性**：`CommandHandler` 类型别名改为
  `(S, C) -> Array[E] raise CommandError`（原 `Result` 返回形）——
  命令处理器直接 `raise` 业务拒，不再自行包 `Ok/Err`。
- **破坏性**：`AggregateRoot::execute` /
  `Router::dispatch_now` / `Router::dispatch_default` /
  `Router::dispatch_with_retry`（私有）与 `AggregateId::from_string`
  三个内建 impl 同步迁 raise 形。调用方从
  `match f(x) { Ok(..) .. Err(..) }` 改为 `try f(x) catch { .. }`
  （或在 raise 语境直接透传）。
- `Router::dispatch` / `dispatch_with_config`（Reader 形）返回型
  `DispatchReader[..., Result[...]]` 保持不变——Reader 携带的结果仍是
  数据；`dispatch` 统一门面（0.1.1 已是 raise 形）零变更。
- `.mbti` 随签名变更同笔重生成（含 Int→Int32 工具链规范形）。

### 测试

- 双档读数：native 62 / 62、wasm 45 / 45，与 0.1.1 语义零漂移；
  `examples/bank` 全链自证 EXAMPLE:PASS。README 计数表同步
  63 → 62（bank live 门转自足结构钉的 −1 补记）。


## 0.1.1 (2026-10-24)

- **Effect 重试状态机**：`RetryMachine` 协议面（`EffectErrorKind` 四类封闭集 +
  纯裁决 decide）+ `AggregateRoot::exec_with_effect`（错误分类 → 钩子覆写 →
  退避/熔断内算，wait 注入无时钟）；`account_retry.toml` 词表 → gen 产物
  （结构钉守卫）+ 手写策略钩子（重试策略 = Policy，红线7）；
  Router `dispatch_with_config` 重试裁决迁移同协议（总错误六臂分类 +
  `store_retry_machine`，API 不变）
- **Dispatch 统一编排门面**：`@mooncmd.dispatch(store, bus, aggregate, cmd)`
  一个调用串完执行 → 落库 → 通知 → 提交 → Strong 一致性等待（轮询投影
  检查点，等待注入；预算超 `ConsistencyErr`）；bank 示例销户段已切换狗粮
- **聚合 gen 上手面**（役7+）：wire 映射随 gen 出（`to_wire`/`from_wire`，
  行格式 v1 首列 schema_version 预留位）+ 契约门脚手架（init 值契约 +
  wire roundtrip 每事件恒等，`<name>_contract_wbtest.mbt` 随件免费）+
  词表再生成走维护侧骨架生成器（独立仓，不随本模块发布）；README
  「从零定义一个聚合」五步上手节
- 聚合 TOML 大gen 金样转正（役7）：`account_agg.toml` → `account_gen.mbt`
  （类型/apply/分派骨架）+ 黄金门 + 行为金锚
- 六包布局 + monads（原 mystate）改名；Router `dispatch_once` 端到端接通
  （快照基态/尾事件/EventBus publish/user_id 链）；投影契约成文 +
  LiveProjection 实装
- **注释简洁化（黑话表 v1.7 同笔）**：役史切口出码——头注/钉注/门件注改正式
  简明形（钉A–钉G 与 D-MG-\*/FR-MC-\*/ADR-MC-\* 编号体系保留）；gen 产物头注
  经发射器模板拨正（`役7+ D-MG-5 脚手架` → `D-MG-5 脚手架`）+ regen 刷新。

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
