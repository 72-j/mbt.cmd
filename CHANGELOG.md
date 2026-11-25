# CHANGELOG

## 0.3.0（2026-11-25）

**PM 错误裁决钩子**：`ProcessManagerRunner::new(..., on_error=Hook(...))`——
泵错误（EmitFailed/StateFailed）由钩子定夺：`Skip` 吞错（本事件弃处理，
状态不推进，已发命令不撤——at-least-once，泵继续）/ `Raise` 原错透传
（缺省 `Transparent` = 0.2.x 语义零漂）。load 面保持透传（存储不可读
无裁决域）。

**causation 透传**：`new(..., emit_cause=PmEmitSink::Sink(...))` 因果
发射槽——第三参 = 触发事件信封（因果锚）；`EventMessage::caused_by`
构造器（correlation 承父 / causation = 父 event_id / user_id 透传）——
PM 产命令的跨聚合追溯链不再断（0.2.x 裸命令 `correlation_id=""` 实录
销账）。

**reset 维护面**：`SQLiteEventStore::reset`——清空事件流（Commanded
reset! 对位；乐观并发守卫随空表复位；测试/开发卫生，生产禁用）。

## 0.2.4（2026-11-25）

**依赖升钉**：`moonbit-community/sqlite3` 0.2.3 → **0.2.5**——新工具链
core `lexbuf.StringScanner` 转只读咬冻结件编译（0.2.3 传递面编译红，
0.2.5 上游已治）；下游消费方升钉本版即随。

**示例面重组**：`examples/bank` / `bank_demo` 下线迁 `.playground`
沙盘（自持微模块，registry 0.2.3 消费形）；新双房 `examples/bank_cmd`
（可点火房：cmd CLI 产物 + 裁决槽位实装 + main 三段编排，
`moon run examples/bank_cmd --target native` → `EXAMPLE:PASS`）+
`examples/bank_cmd_gen`（cmd CLI 产物封存房）；README 快速上手回灌
裁决槽位最小形 + 读数全量刷新（native 全模块 81 / 81）。

## 0.2.3（2026-11-18）

**Process Manager 框架面**（ADR-MC-011）：`ProcessManager` 四回调
记录面（`interested` / `saga_id_of`（收 EventMessage 信封）/
`handle`（产 `DirectedCommand`（命令 + `target_aggregate_id` 跨聚合
地址））/ `apply`）+ `ProcessManagerRunner` 显式泵（单事件
interested→装态（load 缺失 = init）→handle→逐条 emit（任一失败
fail-fast 状态不推进）→apply→save）；状态复用 SnapshotStore（键
`<pm名>:<saga_id>`）；命令发射注入闭包；错误面 `ProcessManagerErr`
独立 suberror（不混 dispatch 主链）。语义差诚实记 ADR：EventStore
无全局流（Commanded 崩溃重处理不在）、emit 成功后 save 前崩溃 =
命令已发状态未进、exactly-once 责任在调用方泵序。罐五钉（全链
持久化 / skip 律 / saga 分片 / fail-fast / 既有态装载）+ native
100/100 + wasm 79/79 + bank 21/21 零涟漪。**词表 gen 化落地**（役
13b,ADR-MC-011 下半,当日续）：`[[process_manager]]` 方言件
`pm_toml_gen.mbt`（skelschema parse/validate/emit 三件套;schema
0.2.0;六段产物 = 状态 struct / interested 封闭集 / saga_id_of /
handle 直通映射 / apply evolve 行 / PM 记录面;装配不在词表 = 红线
7 同源）+ `examples/bank/account_pm.toml` 样例表 +
`account_pm_gen.mbt`
入库产物（transfer saga 手写件退役随批）+ `pm_toml_gen_test.mbt` 四钉 +
主仓黄金门 PM 行（REGEN≡DISK）;cmd 仓搬运同步 = 方言件体保真 + CLI PM 路由
（双拒合成错 exit 4）+ serde 第五件随补 + 役12 漂移补齐（hooks
工厂/declare 槽位/serde 发射器三面,烟测咬出）。

**快照自动节律可配置**（ADR-MC-010）：`RouteEnv::new` 尾部可选参
`snapshot_every? : Int32`（缺省 0 = 关闭，`clock?`/`id_gen?` 同形）；
Router 分发主流程 Step5 快照判定换 Commanded 同款差值制
`version - 快照基版本 >= snapshot_every`（错位免疫），硬编码
`version % 100` 模判定退役（0.1.0 首发遗留，零测试零文档依赖）。
节律四钉（阈值精确 / 缺省关闭 / 错位基版本 / 快照后重计）+
根包 74/74 + native deny-warn 95/95 + bank 21/21 零涟漪。

**dispatch 中间件管道**（ADR-MC-009）：`dispatch` 门面增 `middleware~`
可选槽（缺省空数组 = 行为字节稳）；`DispatchMiddleware` 记录型函数面
三槽（before 顺 / after 逆 / failure 只对主链五步错触发，挂点自身抛错
穿透不进 failure 防自触发递归）；`logging_middleware` 参考件
（`clock~` / `log~` 闭包显式注入）。middleware 四钉 +
根包 70/70 + bank 21/21 零涟漪。

**serde JSON 投影 gen 化**（役10，词表可选键 `[aggregate.serde]`
`json = true` 键控发射，键缺席 = 零发射 = 存量表字节零漂）。
发射器（主仓 skelschema）增 `emit_mooncmd_agg_serde`：事件枚举的
serde.mbt JSON 投影（Serialize/Deserialize 双 impl 外部标签制三形
unit/newtype/tuple + 变体 index=表序 + UnknownVariant 拒收 +
`[0079]` 显式 extend 收口），产物 `<聚合根前缀>_serde_gen.mbt`
（例 `examples/bank/account_serde_gen.mbt`，黄金门逐字节随批）。
开键后胶水 serialize/deserialize 桥件换 JSON 径（`@json.to_bytes`
catch 空收口——事件域封闭全原语字段，SerError 结构性不可达 +
`@json.from_string`）；词表加变体 regen 同批刷新投影，手写
Deserialize 漏新字段的数据黑洞结构性不发生。消费者依赖自带：
moon.mod 钉 `moonbit-community/serde.mbt@0.3.1` + moon.pkg 主
import 块 `@serde`/`json` 显式别名；mooncmd 主模块零 serde 依赖。
罐面：bank 负例分变体（Some 包装形精确捕获 UnknownVariant）+
roundtrip 四变体金罐字节锚；主仓 skelschema 四钉（键缺席缺省/
键开形状锚三形全谱/键在值坏拒收/glue 键控臂）+ golden serde 门
（键开 = 逐字节对拍，键关 = 产物不在清单）。读数：mooncmd native
87/87 + wasm 66/66（bank 为 native 钉包，serde 罐随 bank 分包
21/21），主仓 golden 39/39，skelschema 61/61。

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
双探针同谱。README「命令面发射」小节回灌 cmd 0.1.1 使用说明（CLI
选项 `--version` / `-V`、`--help` / `-h`；exit 码 0/2/3/4/5；成功输出
清单形）与注意事项五条（词表封闭集与红线 7 / 三件纯产物禁手改
stub-zone 唯一手写 / target_package 溯源 / 生成即验收 / 治理三律）。

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
