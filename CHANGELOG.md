# CHANGELOG

## 未发布

**时间源注入代码化**（`clock?` / `id_gen?` 可选槽，缺省行为不变）。
信封构造器（`CommandMessage::new` / `EventMessage::new` /
`EventMessage::from_command` / `Snapshot::new`）、聚合根三级构造
（`AggregateRoot::new` / `from_events` / `from_snapshot`）与
`RouteEnv::new` 增尾部可选参数 `clock? : () -> Int64` +
`id_gen? : () -> String`；`AggregateRoot` 与 `RouteEnv` 各持双槽字段，
框架内唯一穿链点（execute → from_command / exec → 信封组装 /
to_snapshot）全走注入槽。缺省 = 现行为不变（`@async.now()` /
`@uuid.v4()`）；两级注入（env 级 Router 全链受控，root 级单聚合受控）；
RouterBuilder 不动；业务代码零直读时钟纪律不破。确定性证据罐三件：
定钟全链（事件时间戳全取注入值）、同输入同钟同 id 源两次运行事件流
逐字段相等、Router env 注钟落库时间戳透传（native 78/78 +
EXAMPLE:PASS + 主仓 golden 17/17 零涟漪）。

**结构：`examples/bank` 拆 lib/cmd**（工具链演化：main 包黑盒测试件
`_test.mbt` 被弃用警告）。`examples/bank` 转示例库包（行为 + 全部测试面
原位不动）；可执行全链自证入口迁 `examples/bank_demo`（`main.mbt` 随迁，
bank 包成员改 `@bank.` 限定）。可执行门换径：`moon run examples/bank_demo
--target native`（README/spec 同步）。测试读数不变（native 75/75，wasm
58/58），EXAMPLE:PASS 续绿。

**装配胶水六桥件入 regen 面**（二版拍1,发射器主仓 skelschema 先行,
本仓 bank/bank_demo 跟随消费;mooncmd 本体 API 零变,不动版）。
`examples/bank` 增 `account_glue.mbt`（发射产物,黄金门逐字节:六桥件
handler/applier/empty_state/serialize/deserialize/type_name,桥面零
手写）;`examples/bank_demo` 六桥手写桥退役改直消费 `@bank.*`（消双
实现 drift;type_name 标签随 glue 裸名形,store 仅记不比对）。测试读数
不变（native 85/85 + EXAMPLE:PASS）;主仓黄金门 39/39 + cmd 仓 golden
双探针同谱。

## 0.2.2（2026-10-31）

文档面版本：README「测试与验证」补 quicktest 生命周期随机状态机说明（事件
溯源守恒律四罐：版本守恒 / 事件流守恒 + 消息版本位连续 / 账目镜像 / 拒绝
零痕迹），读数表随新（native 75 / 75，wasm 58 / 58，quicktest 13 例单列）；
对外 API 与行为零变化。

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
