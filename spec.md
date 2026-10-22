# mooncmd 规格卷（spec）

版本：**v0.2.1**（2026-10-08 立卷；2026-10-22 对账笔换版——六包布局契约面 + 役5b/5c/役7/役8 结构事实同步 + Effect 重试状态机设计入卷，见变更记录）
体例：世界卷 `bangto/world/const.md` §5.1 `spec` 卷位——**结构事实与契约**；**禁止承载决策**（裁定与被否方案归 MCMD-S1 及其拆出 `adr`，本卷只记裁定后的结构结果）。
上游：《mooncmd 需求档》（MCMD-S1 v0.1.1）——**已拆卷归档** `bak/requirements.md`（2026-10-08 MU2 立卷笔）；本卷为拆卷正身，`[提案]` 行原样搬迁（拆卷 ≠ 签发）。
配套：`const.md` v1.1.0（红线九条：语义三/形态三/生成三）/ `adr.md` v1.1.0（ADR-MC-001..007，001..006 已签发）/ `todo.md` v1.1.0（役程至役8 续）/ `ctx.md` v0.2.0（R-01..R-17）/ `cmd.md`（设计注记，本卷 §2 的来源稿）。
定位一句话：`thy1016/mooncmd` = **独立模块**（gitlink `thy7/mbt.cmd`，木兰 PSL v2）通用 CQRS/事件溯源框架库（六包 + 可执行示例）——命令 → 纯事件 → `EventMessage` 自动包装 → EventStore → 投影/快照，配聚合 TOML 大gen 金样与 Effect 重试状态机协议面。

---

## 1. 包定位与依赖（结构事实）

| 项 | 事实 |
|---|---|
| 目录形态 | **六包布局**（役8 ff9ce54）：根包（router + 总错误 + logger）+ `aggregate/` + `command/` + `event/` + `monads/`（原 mystate，ab230a5 改名）+ `projection/` + `store/`；每包独立 `moon.pkg` + `.mbti`；测试命名循 moonttl 标准（黑盒 `*_test.mbt` / 白盒 `*_wbtest.mbt`） |
| 示例面 | `examples/bank`（可执行自证包，native-only）：`main.mbt` 全链演示 + 聚合 gen 五件（`account_agg.toml` 词表 / `account_gen.mbt` 产物含 wire 映射 / `account_policy.mbt` + `account_retry_policy.mbt` 手写钩子 / `account_contract_wbtest.mbt` 免费契约门）+ 黄金门 ×2（产物/契约件逐字节）+ 夹具；再生入口 = `moon run skelschema/cmd --target native` |
| 模块形态 | **独立模块** `thy1016/mooncmd`（moon.mod 在盘，moonspace 范式；ADR-MC-007）；主仓树内在存但主仓不跟踪（主仓 .gitignore 止蚀） |
| 包路径 | 根包 `thy1016/mooncmd`（router/总错误/logger）；分包 `thy1016/mooncmd/{aggregate,command,event,monads,projection,store}`；示例 `thy1016/mooncmd/examples/bank` |
| 运行时依赖 | 包间：aggregate→command/event/store 等（见各 moon.pkg）；外部：`moonbitlang/async@0.22.4` · `moonbit-community/sqlite3@0.2.3` · `f4ah6o/uuidm@0.2.1`；core（utf8/json）内置 |
| 测试依赖 | `moonbitlang/x@0.5.5`（fs）+ `thy1016/skelschema@0.1.0`（黄金门 for-test，随 bank 拆分迁 examples/bank；moon.work 本地树覆盖） |
| 模块账 | moon.mod 独立在盘（uuidm 随迁自主仓，根仓无其它用户）；脚手架 = `proj_dialect.toml` 方言件 + `moonxr/ops_projgen.mbtx`；发布元数据变更须经 `moonxr/release_review.mbtx`（独立 clone 真路径） |
| 入库状态 | 独立仓 gitlink `thy7/mbt.cmd`（master；首推 2026-10-21，用户令）；主仓侧 untrack + .gitignore 止蚀 |
| 目标声明 | 包级 `supported_targets = "wasm+native"`（2026-10-22 用户拍**原生 wasm 加支持 native**——序随定位；2026-10-08 原形 native+wasm 循 sqlite3 逐字，沿革在案）；模块级 `preferred_target = "wasm"`（moon.mod，裸跑即 wasm；examples 可执行包仍 native-only,门 = `moon run examples --target native`） |

## 2. 主链（结构事实；成文自 `cmd.md` 注记）

```text
Command → CommandMessage（correlation_id / causation_id / user_id）
  → CommandHandler 返回 Result[Array[E], CommandError]   ← 纯事件，不碰元数据
  → AggregateRoot::execute 独占包装：E ⇒ EventMessage
      （补 event_id=uuidv4 / aggregate_id / aggregate_version /
        correlation_id 承自 CommandMessage / causation_id 记前因 /
        user_id 承自 CommandMessage（役5b 链通至落列）/
        timestamp=@async.now() / metadata=Json / schema_version=1）
  → AggregateState.uncommitted_events
  → Router dispatch_once（役5b 接通，唯一写入口）：
      Step0 快照基态（SnapshotStore.load）→ Step1 尾事件（after_version=快照版本）
      → Step2 from_snapshot 重建 → Step3 execute → Step4 EventStore.append
      → Step4.5 EventBus.publish（可空选；失败=Failed 诚实——事件已落库，
        盲重试会双重作用，at-least-once 归消费方接入役）→ Step5 每 100 版存快照
  → 投影（拉取式：Projection + LiveProjection，检查点即版本）

Dispatch 门面（根包 `dispatch`，编排层定稿）：`dispatch(store, bus,
aggregate, cmd, projections~, consistency~, poll_wait~, poll_budget~)`
一个调用串完 ①exec 裁决 ②append 持久化 ③publish 通知（可空选）④提交
⑤Strong 轮询投影检查点（预算超 = `ConsistencyErr`；等待注入，红线6）。
高级编排（快照基态 / 重试机 / Reader）仍走 Router。
```

- **红线三条**（const.md §1，已签发）：① Handler 只返回纯事件；② `execute` 独占包装权；③ Router 唯一持久化写入口。
- 形态 A 链式捷径：`AggregateRoot::exec(cmd) -> Self raise CommandError`（命令自动包装 CommandMessage；役8 前奏在途件）。
- 时间源唯一：事件时间戳只来自 `@async.now()` 注入点；投影/确定性路径禁取当前时钟（红线6）。

### 2.1 Effect 重试状态机（设计定稿 2026-10-22；落码 = 役8 续，`[设计定稿，未落码]`）

分层定位：`exec(命令) --raise--> Effect 重试状态机裁决（重试/放行/熔断）--> EventStore.append`——exec 错误不直接到调用方，先过状态机；状态机自身 = 纯翻译产物（词表 TOML → gen → 骨架 + 手写钩子）。

| 语义 | 状态机表达 | 词表化 |
|---|---|---|
| 固定退避 | Exec→Wait(interval)→Exec ×N | `retry = { max, backoff="fixed", interval }` |
| 指数退避 | Wait→Exec→Wait(×factor)→Exec | `backoff="exponential", base, factor` |
| 条件重试 | 按错误类型分派 | `on_error = { duplicate="retry", validation="exhausted" }` |
| 熔断 | 连续 N 失败→Open→冷却 | `circuit = { threshold, cooldown }` |

协议面（落码形）：

- `EffectErrorKind`（框架错误分类封闭集，结构知识非裁决）：`DuplicateVersion`/`Conflict`→`Duplicate`；`InvalidCommand` 族→`Validation`；`StorageError`/`SerializationError`→`Storage`；余→`Other`。
- `RetryMachine`（记录面，宪法4）：`default_action : (EffectErrorKind) -> RetryAction` + `decide(attempt, consecutive_failures, kind) -> RetryVerdict`——**纯裁决，无时钟无副作用**（红线6）；退避时长与熔断判定均由 decide 内算。
- `exec_with_effect(root, cmd, machine, hooks, wait)`：runner 循环——exec raise → 分类 → 钩子覆写或默认表 → decide → `WaitRetry(ms)` 则 `wait(ms)`（**注入时钟**，测试可记录型假时钟）后重执行；`GiveUpRaise` 原错上抛。幂等前提：`execute` Err 不改态 ⇒ 同命令重放同结果。
- 红线三警惕：① 重试策略是 Policy——gen 只产骨架，裁决归策略件手写钩子（红线7）；② TOML 禁业务条件（红线8 同源——条件演化归钩子）；③ 幂等前提 = exec 幂等。
- 落位：库缝 `aggregate/effect.mbt`（手写）；方言 skelschema 第十三方言 `retry_toml_gen.mbt`；产物 `examples/bank/retry_gen.mbt` + 手写钩子 `account_retry_policy.mbt`；役5b `dispatch_with_config` 重试迁移为后续小笔。

## 3. 公开契约面（六包分包面；以各包 `moon info` 生成的 `.mbti` 为准收口）

### 3.0 六包分包面（役8 布局，2026-10-22 实测）

| 包 | 面 | 备注 |
|---|---|---|
| 根包 | `dispatch` 编排门面（五步串行 + Strong 一致性等待）/ `Router`（`dispatch`/`dispatch_now`/`dispatch_once`/`dispatch_with_config`/`dispatch_batch`/`dispatch_default` + `DispatchReader` 组合子）/ `RouteEnv`/`CommandConfig`/`RouterBuilder` / 总错误 `EventSourcingErr`（六臂，含 ConsistencyErr）/ `Logger` | router_e2e 六钉（役5b 五钉 + 钉G Strong） |
| `aggregate/` | `AggregateRoot`（`new`/`from_events`/`from_snapshot`/`execute`/`exec` 形态 A（在途）/`commit`/`uncommitted_events`/`version`/`current_state`/`to_snapshot`）· `AggregateId` trait + `String`/`Int32`/`AggUUID` impl · `AggregateError` | exec 形态 A 在途件 |
| `command/` | `CommandMessage`（`new`/`with_correlation`/`with_user`）· `CommandHandler` 型 · `Command` trait · `CommandError`（六变体，Show 全） | FR-MC-6 已闭 |
| `event/` | `EventMessage`（含 `schema_version`/`user_id`）· `EventStream` · `EventApplier` · `EventBus`（publish 已接通）· `Event` trait · `EventBusError` | |
| `monads/` | `State`/`Writer`/`Reader`/`EventWriter` 纯函数 Monad（原 mystate，ab230a5 改名） | 封界 = 红线5 |
| `projection/` | `Projection` 记录面 · `SubscriptionPosition` · `LiveProjection`（实装：装载/refresh/get_view/checkpoint）· `PersistedProjection` | 契约四条头注（役5c）；gate 两钉 |
| `store/` | `EventStore`/`SnapshotStore` 记录面 · `SQLiteEventStore`（含 `to_event_store` 适配器，役5b）· `Snapshot` · `EventStoreError`/`SnapshotError` | user_version 迁移策略头注 |

> 下文 §3.1–§3.6 为拆包前历史卷面（单包视角），类型归属以 §3.0 为准；逐字段以各包 `.mbti` 为准。

### 3.1 事件与消息

| 类型 | 形状 | 备注 |
|---|---|---|
| `EventMessage[AggregateId, E]` | `event` · `event_id`（uuid v4）· `aggregate_id` · `aggregate_version : Int` · `correlation_id : String` · `causation_id : String` · `timestamp : Int64` · `metadata : Json` · `schema_version : Int`（役5 落，默认 1，只预留不演进）· `user_id : String?`（役5b 落，承自 CommandMessage 链至落列） | `from_command` 复制 CommandMessage 元数据；逐字段以 `.mbti` 收口为准 |
| `CommandMessage[C]` | 含 `correlation_id`（实测引用）；全形状 `[待勘]` | sqlite 侧有 `user_id` 列与之对应 |

### 3.2 存储与总线（记录型函数面，struct-of-functions）

| 类型 | 函数面 | 错误 |
|---|---|---|
| `EventStore[AggregateId, E]` | `append(self, AggregateId, Array[EventMessage]) -> Unit raise` · `load(self, AggregateId, after_version : Int) -> Array[EventMessage] raise` · `current_version(self, AggregateId) -> Int raise` | `EventStoreError` |
| `SnapshotStore[AggregateId, S]` | 记录型（`snapshot.mbt:10`） | —— |
| `EventBus[AggregateId, E]` | `publish(self, Array[EventMessage]) -> Unit raise`（`RouteEnv.event_bus` 可空选） | `EventBusError` |

> 形态裁定（ADR-MC-003 `[提案]`）：记录型函数面为**定版**；旧 trait 注释体删除（时机待拍，ADR-MC-003）。佐证：MoonBit trait 不支持高阶类型（`mystate/state.mbt` 头注在案）。

### 3.3 聚合生命周期

`AggregateState[AggregateId, S, E]` / `AggregateRoot[AggregateId, S, C, E]`：
`new` · `from_events` · `execute` · `commit` · `uncommitted_events` · `version` · `current_state` · `to_snapshot`（`aggregate.mbt`，八面实测）。

### 3.4 路由与配置

| 件 | 面 |
|---|---|
| `RouteEnv[AggregateId, S, E]` | `event_store` · `snapshot_store` · `event_bus : EventBus[..]?` · `logger : &Logger` · `default_timeout : Int64` · `default_retry : Int` |
| `CommandConfig` | `new` · `with_timeout` · `with_retries` · `with_consistency` |
| `RouterBuilder` | `new` · `add_handler` · `add_handlers` · `with_default_timeout` · `with_default_retries` · `with_consistency` · `handler_count` · `build` |
| `Router` | `new` · `dispatch` · `dispatch_now`（显式同步捷径）· `dispatch_with_config` |
| `DispatchReader` 组合子 | `dispatch_reader_new` / `_run` / `_map` / `_bind` · `dispatch_ask` · `dispatch_asks`（Reader Monad 注入面） |

### 3.5 错误面

总错误含 `CommandErr(CommandError)` / `EventStoreErr(EventStoreError)` 两臂；`CommandError`、`EventStoreError` 均 `suberror` 且带 `Show` 实例（`error.mbt`）。语义稳定承诺 = FR-MC-6 `[提案]`。

### 3.6 monads 子包（原 mystate）

State Monad（`State[S, V]`，三法则注记在案）· Writer Monad（`Writer[W, A]` + `WriterConfig`）· reader · event_writer。定位封界 = FR-MC-7 `[提案]`（纯函数基础设施，不含 ES 语义）。

## 4. 存储布局（SQLiteEventStore，结构事实）

- 表 `event_stream`：`event_data` · `version` · `event_id` · `correlation_id` · `causation_id` · `timestamp` · `metadata` · `user_id`（建表语句 `sqlite.mbt:31`；类型/主键以收口后 schema 为准）。
- `load` = 按 `aggregate_id` 且 `version > after_version`；`current_version` = `COALESCE(MAX(version), 0) WHERE aggregate_id = ?`（`sqlite.mbt:156`）。
- **已知缺口（本包单一事实源，实现在 `reality` 地位；2026-10-22 对账笔同步）**：
  1. ~~无 `expected_version` 守门~~ **已闭**（役5：批次首事件版本 ≠ 当前+1 ⇒ `DuplicateVersion` 拒写；FR-MC-1）；
  2. ~~`(aggregate_id, version)` 唯一索引未实证~~ **已闭**（役5：表级 UNIQUE + 索引 + wbtest 钉子；竞态兜底靠 UNIQUE 冲突→回滚上抛）；
  3. ~~无事件 `schema_version` 字段~~ **已闭**（役5：字段+列+默认 1；只预留）；
  4. ~~存量老库无迁移路径~~ **已闭**（役5b：user_version 逐版策略，K1 形降级声明入 `sqlite.mbt` 头注）；
  5. ~~无适配器~~ **已闭**（役5b：`SQLiteEventStore::to_event_store`，错误回原族不抹平）；
  6. ~~错误抹平~~ **已闭**（役5b：穿透 helper 回原族，DuplicateVersion 原样上浮，router_e2e 钉）。
- 现存开放项：Effect 重试状态机未落码（§2.1，役8 续）；dispatch_with_config 的 timeout_ms 随 async 面另役。

## 5. 现状：已落 / 未落（2026-10-22 对账笔同步）

| 能力 | 状态 | 去向 |
|---|---|---|
| 命令 → 纯事件 → 自动包装主链 | **已落**（含 user_id 链） | —— |
| EventStore 记录面 + SQLite 后端 + 适配器 | **已落全接**（`to_event_store`，役5b） | —— |
| Router dispatch_once（快照基态/尾事件/EventBus publish） | **已落**（router_e2e 五钉） | —— |
| 快照读路径（load 加速重建） | **已落**（役5b Step0） | —— |
| 投影契约 + LiveProjection | **已落**（役5c 四条成文 + gate 两钉） | —— |
| 乐观并发 / 幂等约束 / schema_version | **已落** | —— |
| 聚合 TOML 大gen 金样 | **已落**（役7 五拍：词表/方言/产物/钩子/黄金门/金锚） | —— |
| Effect 重试状态机 | **设计定稿未落码**（§2.1） | 役8 续 |
| dispatch_with_config timeout_ms | 未落（随 async 面） | 另役 |
| Account 测试夹具 | **已出契约面**（随 bank 拆分迁 examples/bank） | —— |
| 包卫生 | 独立仓 mbt.cmd；本地领先远端 4 笔待推；`bak/` 底稿仅存本机盘待裁 | 待裁 |

## 6. 判据与门（NFR，自 MCMD-S1 §四 `[提案]` 原样搬迁）

| 门 | 判据 |
|---|---|
| 测试计数棘轮 | 独立模块口径 **48**（46 + 黄金门 + 金锚，2026-10-22 实测；裸跑 = wasm，native 同）；沿革：41（10-21 单包口径）← 104（根仓口径，连坐子包+双后端重复计数，仅作参考） |
| 可执行门 | `moon run examples/bank --target native` → **EXAMPLE:PASS**（十项检查） |
| 静态 | `moon check --deny-warn` **0 错 0 警**（**已闭** 2026-10-08 收口笔；两包实测，主包 25 tasks 零告警） |
| 契约面 | 公开面变更必 `moon info` 同笔提交（`.mbti` 无漂移，主仓先例同款） |
| 时间源 | 投影/确定性测试不含当前时钟读取（NFR-MC-4） |

门的设计遵循世界卷 const §6.4（可证伪 / 冷跑 / 禁整行跳过）；数字只作展示，结论须同报缺口（const §6.2.5）。

## 7. 非目标（自 MCMD-S1 §五 `[提案]` 原样搬迁）

1. 不做分布式/跨进程事件总线（`EventBus` 仅进程内可选挂点）。
2. 不做事件升级/迁移框架（`schema_version` 只预留）。
3. 不承诺第二存储后端；不内置加密/审计/权限。
4. 库包（`is-main: false`），无 CLI/GUI。
5. 不做 RDF/N3 事件序列化（将来投影目标候选，非本包职责）。
6. 不内置业务聚合——`account_fixture` 只属测试夹具，不入公开契约面。

## 8. 追溯矩阵（FR → 现状 → 落点）

| FR（MCMD-S1） | 现状 | 落点 |
|---|---|---|
| FR-MC-1 乐观并发 | **已落**（守门 + 金样） | 役5b：Router 侧穿透 |
| FR-MC-2 schema_version | **已落**（预留值 1） | —— |
| FR-MC-3 投影契约 | 未成文 | 役5c |
| FR-MC-4 幂等约束 | **已落**（UNIQUE + 钉子；竞态路径测试待补） | 役5b |
| FR-MC-5 快照等价 | **已落**（等价测试）；读路径接通未落 | 役5b |
| FR-MC-6 错误面稳定 | 已落（Show），承诺成文 | 役5c |
| FR-MC-7 mystate 封界 | 已隔离 | 役5c（包 const 候选） |

## 9. 消费方与互锁

- **首个消费方（宿主内部项目，规划中）**：以其世界卷生成为引擎候选场景；本模块初始化（已完成 2026-10-21）前置其摄取+存储 spike；发现抽象缺陷同笔回灌本卷 §3 契约面。
- 引用本卷须带节号；本卷换版必须同步所有引用方（world const §5.1 `spec` 行效力纪律）。

## 10. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v0.2.1 | 2026-10-22 | **对账笔换版**：① §1 六包布局 + 示例面 + 分包路径/依赖；② §2 主链改 dispatch_once 全流程（快照基态/尾事件/EventBus publish/user_id）+ 新 §2.1 **Effect 重试状态机设计**（分层/词表四语义表/协议面/红线三警惕，`[设计定稿，未落码]`）；③ §3.0 六包分包面总览（§3.1–3.6 转历史卷面）+ 3.6 改名 monads；④ §4 缺口 4–6 划闭（user_version 迁移/适配器/错误穿透）；⑤ §5 已落-未落全表改口；⑥ §6 棘轮 48 + 可执行门。配套行同步四卷版本。 |
| v0.2.0 | 2026-10-22 | **役5c 契约清债笔**:投影契约成文(FR-MC-3——拉取非推送/检查点即版本/apply 纯函数禁时钟/持久化可选,吸收 commanded checkpoint·ack 语义)/LiveProjection 实装(new·refresh·checkpoint 拉取形)/PersistedProjection 修通(SQL 首字符引号 bug+panic 吞错→errdefer·自然上抛)/ADR-MC-001..006 签发/役6 挂起(WVGEN 卷不存在,锚=世界卷生成需求真立项;moonrdb ES 同挂锚=审计回放需求)/proj 测试双偏差修复。 |
| v0.1.9 | 2026-10-22 | **役5b 接通笔**：EventMessage +user_id 链（§3.1）/ Router dispatch_once 重构（快照读路径 + EventBus 接通 + 错误穿透不抹平）/ with_config 重试实装（timeout 降级声明）/ SQLiteEventStore::to_event_store 适配器 / from_snapshot 聚合形——C-06 断链九项清七，余二归 5c。46/46（native+wasm 双跑）· deny 0 · EXAMPLE:PASS。 |
| v0.1.8 | 2026-10-22 | **目标定位翻转（用户拍「原生 wasm 加支持 native」）**：moon.mod preferred_target native→wasm + 包级 supported_targets 序 wasm+native；裸跑即 wasm（_build 单 wasm 实证）41/41，native 矩阵 41/41 守恒，examples 门改显式 `--target native`（native-only 包不随模块默认）。 |
| v0.1.7 | 2026-10-21 | **役5d 示例拆分**：Account 夹具出生产面/契约面（迁 `account_fixture_test.mbt` 测试包私有，.mbti 零 Account，§7.6 违约销账）；新立 `examples/` 可执行示例包（moonspace 先例形，全链自证终判 EXAMPLE:PASS）；`CommandError` 补 `Show::to_string` 显式晋升（FR-MC-6）。 |
| v0.1.6 | 2026-10-21 | **独立成仓同步（ADR-MC-007）**：定位行/§1 模块形态重写（独立模块 thy1016/mooncmd + gitlink mbt.cmd + 依赖钉版随迁）；§6 棘轮改独立模块口径 41（根仓 104 为沿革参考）；§2/§9 内部卷名去敏（WVGEN→消费方中性表述，release_review ③ 类门对齐）。 |
| v0.1.5 | 2026-10-21 | **役5a 收口同步**：§3.1 EventMessage 补 schema_version 字段；§4 缺口 1–3 划闭、新增缺口 4–6（迁移/适配器/错误抹平）；§5 已落-未落表对实态改口；§6 棘轮 98→104（根仓口径）；§8 追溯矩阵改口。役5 主体（10-09~16）当时未同步本卷——补齐对账。 |
| v0.1.4 | 2026-10-08 | **MU2 立卷笔（spec 侧收尾）**：头部上游/配套行随拆卷实态更新（需求档归档 `bak/requirements.md`；const/adr/todo 三卷立）；§3.2 交叉引用改指 ADR-MC-003，顺修 mystore 拼写。 |
| v0.1.3 | 2026-10-08 | R-05 收口笔同步（§6 静态门**已闭**：--deny-warn 两包 0 错 0 警；98/98 守恒）。 |
| v0.1.2 | 2026-10-08 | 测试命名循 moonttl 标准改造同步（§1 目录形态行 + 依赖表行：`for "test"` = fs/json/utf8 黑盒专用；debug 不再入测试依赖）；98/98 守恒。 |
| v0.1.1 | 2026-10-08 | MC-6 拍定落卷（supported_targets = native+wasm，§1 目标声明行同步）+ MU1 执行同步（§5 包卫生行 / §6 静态门行：警告已消，余存量 8 项在册未闭，收口另立笔）。 |
| v0.1.0 | 2026-10-08 | 立卷（用户令「生成 mooncmd 项目的 spec.md」）：包定位与依赖 / 主链成文 / 公开契约面（§3.1–3.6，实测）/ 存储布局与三缺口 / 已落-未落表 / 判据与门 / 非目标 / 追溯矩阵 / 消费方互锁。拆自 MCMD-S1 §一/§三/§四/§五/§七/§八；`[提案]` 行原样搬迁（拆卷 ≠ 签发），决策正文未随迁（归需求档及将来包 `adr`）。 |
| 2026-10-22 | **现代性分析锚定（茗篇 `.mingspace/modernity_analysis.md` 收编）** | 七维评审（架构范式/类型驱动/错误即值/并发控制/事件模型/持久化抽象/部署适应性——均 ≥★★★★）+ 反模式回避六则 + 前沿对标（Commanded/Marten 逐项）| **锚定五条（R-3）**：① 事件上转型——首次 schema v2 变更 ② 订阅检查点——首个多投影消费者 ③ 可观测性——首个生产部署 ④ Process Manager——首个跨聚合工作流 ⑤ 投影强类型——投影消费方类型化需求。五锚均未命中不预立，登记在案。|
