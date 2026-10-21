# mooncmd 规格卷（spec）

版本：**v0.1.6**（2026-10-08 立卷；同日 MC-6 拍定 + MU1 执行同步；2026-10-21 役5a 收口 + 独立成仓同步，见变更记录）
体例：世界卷 `bangto/world/const.md` §5.1 `spec` 卷位——**结构事实与契约**；**禁止承载决策**（裁定与被否方案归 MCMD-S1 及其拆出 `adr`，本卷只记裁定后的结构结果）。
上游：《mooncmd 需求档》（MCMD-S1 v0.1.1）——**已拆卷归档** `bak/requirements.md`（2026-10-08 MU2 立卷笔）；本卷为拆卷正身，`[提案]` 行原样搬迁（拆卷 ≠ 签发）。
配套：`const.md` v1.0.0（红线六条）/ `adr.md` v1.0.0（ADR-MC-001..006）/ `todo.md` v1.0.0（役1–6，役1–3 已收）/ `ctx.md` v0.1.3（即时账本）/ `cmd.md`（设计注记，本卷 §2 的来源稿）。
定位一句话：`thy1016/mooncmd` = **独立模块**（gitlink `thy7/mbt.cmd`，木兰 PSL v2）通用 CQRS/事件溯源框架库包（`is-main: false`）——命令 → 纯事件 → `EventMessage` 自动包装 → EventStore → 投影/快照的最小完备抽象。

---

## 1. 包定位与依赖（结构事实）

| 项 | 事实 |
|---|---|
| 目录形态 | `mooncmd/`（主包 13 件）+ `mooncmd/mystate/`（函数式基础设施子包 8 件）；扁平式布局（world const §5.4 小项目形态）；测试命名循 moonttl 标准——黑盒 `*_test.mbt` ×4（主包）、白盒 `*_wbtest.mbt` ×3（mystate） |
| 模块形态 | **独立模块** `thy1016/mooncmd`（moon.mod 在盘，moonspace 范式；ADR-MC-007）；主仓树内在存但主仓不跟踪（主仓 .gitignore 止蚀） |
| 包路径 | `thy1016/mooncmd`（模块根包）；子包 `thy1016/mooncmd/mystate` |
| 运行时依赖 | `mystate`（`@mystate`）· `moonbitlang/async@0.22.4` · `moonbit-community/sqlite3@0.2.3`（`@sqlite3`）· `f4ah6o/uuidm@0.2.1`（`@uuid`）；core（utf8/json）内置 |
| 测试依赖 | `moonbitlang/x@0.5.5`（fs；`for "test"`，黑盒测试包专用） |
| 模块账 | moon.mod 独立在盘（uuidm 随迁自主仓，根仓无其它用户）；脚手架 = `proj_dialect.toml` 方言件 + `moonxr/ops_projgen.mbtx`；发布元数据变更须经 `moonxr/release_review.mbtx`（独立 clone 真路径） |
| 入库状态 | 独立仓 gitlink `thy7/mbt.cmd`（master；首推 2026-10-21，用户令）；主仓侧 untrack + .gitignore 止蚀 |
| 目标声明 | 包级 `supported_targets = "native+wasm"`（已拍 2026-10-08，循 sqlite3 逐字）；模块级 `preferred_target = "native"` |

## 2. 主链（结构事实；成文自 `cmd.md` 注记）

```text
Command → CommandMessage（correlation_id / causation_id / user_id）
  → CommandHandler 返回 Result[Array[E], CommandError]   ← 纯事件，不碰元数据
  → AggregateRoot::execute 独占包装：E ⇒ EventMessage
      （补 event_id=uuidv4 / aggregate_id / aggregate_version /
        correlation_id 承自 CommandMessage / causation_id 记前因 /
        timestamp=@async.now() / metadata=Json）
  → AggregateState.uncommitted_events
  → Router（唯一写入口）→ EventStore.append
  → （可选）EventBus.publish ／ SnapshotStore（快照加速）
```

- **红线候选三条**（MCMD-S1 MC-2 `[提案]`，条文落位归包 `const.md`，本卷不载）：① Handler 只返回纯事件；② `AggregateRoot::execute` 独占包装权；③ Router 是唯一持久化写入口。
- 时间源唯一：事件时间戳只来自 `@async.now()` 注入点；投影禁取当前时钟（NFR-MC-4 `[提案]`，与首个消费方的时间源红线同源）。

## 3. 公开契约面（实测 2026-10-08；MU1 后以 `moon info` 生成的 `.mbti` 为准收口）

### 3.1 事件与消息

| 类型 | 形状 | 备注 |
|---|---|---|
| `EventMessage[AggregateId, E]` | `event` · `event_id`（uuid v4）· `aggregate_id` · `aggregate_version : Int` · `correlation_id : String` · `causation_id : String` · `timestamp : Int64` · `metadata : Json` · `schema_version : Int`（役5 落，默认 1，只预留不演进） | `from_command` 复制 CommandMessage 元数据；逐字段以 `.mbti` 收口为准 |
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

### 3.6 mystate 子包

State Monad（`State[S, V]`，三法则注记在案）· Writer Monad（`Writer[W, A]` + `WriterConfig`）· reader · event_writer。定位封界 = FR-MC-7 `[提案]`（纯函数基础设施，不含 ES 语义）。

## 4. 存储布局（SQLiteEventStore，结构事实）

- 表 `event_stream`：`event_data` · `version` · `event_id` · `correlation_id` · `causation_id` · `timestamp` · `metadata` · `user_id`（建表语句 `sqlite.mbt:31`；类型/主键以收口后 schema 为准）。
- `load` = 按 `aggregate_id` 且 `version > after_version`；`current_version` = `COALESCE(MAX(version), 0) WHERE aggregate_id = ?`（`sqlite.mbt:156`）。
- **已知缺口（本包单一事实源，实现在 `reality` 地位；2026-10-21 役5a 末实测）**：
  1. ~~无 `expected_version` 守门~~ **已闭**（役5：批次首事件版本 ≠ 当前+1 ⇒ `DuplicateVersion` 拒写；FR-MC-1）；
  2. ~~`(aggregate_id, version)` 唯一索引未实证~~ **已闭**（役5：表级 UNIQUE + 索引 + wbtest 钉子；竞态兜底靠 UNIQUE 冲突→回滚上抛）；
  3. ~~无事件 `schema_version` 字段~~ **已闭**（役5：字段+列+默认 1；只预留）；
  4. **存量老库无 schema 迁移路径**（`CREATE TABLE IF NOT EXISTS` 不改旧表——旧 schema 库遇新 INSERT 即炸；役5b 裁）；
  5. **`SQLiteEventStore` 与 `EventStore` 记录面之间无适配器**——Router 主链（命令→Router→SQLite）尚未端到端接通（役5b）；
  6. Router 分发路径对 `EventStoreError::DuplicateVersion` 等预期错误一律抹平为 `StorageError(String)`（役5b）。

## 5. 现状：已落 / 未落（2026-10-08 实测）

| 能力 | 状态 | 去向 |
|---|---|---|
| 命令 → 纯事件 → 自动包装主链 | **已落**（62/62，2026-10-21） | —— |
| EventStore 记录面 + SQLite 后端 | **已落（各自）**；ⓠ 两者间无适配器，端到端未接 | 役5b |
| Router / Builder / DispatchReader | **已落（面）**；Router 分发路径零测试覆盖、注册表未参与分发 | 役5b |
| 快照（to_snapshot / SnapshotStore） | **已落（面 + 等价测试）**；读路径（load 加速重建）未接、EventBus publish 未接 | 役5b |
| 投影（projection.mbt） | **已落（面）**，契约未成文 | FR-MC-3，役5c |
| 乐观并发 | **已落**（守门 + DuplicateVersion + 金样） | —— |
| 幂等写入约束 | **已落**（表级 UNIQUE + 钉子；竞态路径测试待补） | 役5b |
| schema_version 预留 | **已落**（默认 1，只预留） | —— |
| Account 测试夹具 | ⚠ **违约在册**：`pub(all)` 入 .mbti（spec §7.6 非目标） | 役5c |
| 包卫生 | MU1 已执行；独立仓 gitlink `thy7/mbt.cmd`（2026-10-21，ADR-MC-007）；`bak/` 本地归档不入仓（底稿仅存本机盘，待裁） | 待裁 |

## 6. 判据与门（NFR，自 MCMD-S1 §四 `[提案]` 原样搬迁）

| 门 | 判据 |
|---|---|
| 测试计数棘轮 | 独立模块口径 **41**（主包 20 + mystate 21，2026-10-21 实测；`--target all` 矩阵 wasm 41 / wasm-gc 21 / js 21 / native 41 全绿）；⚠ 历史根仓口径 104 = 连坐子包 + 双后端重复计数，仅作沿革参考（见 ctx R-08） |
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
| v0.1.6 | 2026-10-21 | **独立成仓同步（ADR-MC-007）**：定位行/§1 模块形态重写（独立模块 thy1016/mooncmd + gitlink mbt.cmd + 依赖钉版随迁）；§6 棘轮改独立模块口径 41（根仓 104 为沿革参考）；§2/§9 内部卷名去敏（WVGEN→消费方中性表述，release_review ③ 类门对齐）。 |
| v0.1.5 | 2026-10-21 | **役5a 收口同步**：§3.1 EventMessage 补 schema_version 字段；§4 缺口 1–3 划闭、新增缺口 4–6（迁移/适配器/错误抹平）；§5 已落-未落表对实态改口；§6 棘轮 98→104（根仓口径）；§8 追溯矩阵改口。役5 主体（10-09~16）当时未同步本卷——补齐对账。 |
| v0.1.4 | 2026-10-08 | **MU2 立卷笔（spec 侧收尾）**：头部上游/配套行随拆卷实态更新（需求档归档 `bak/requirements.md`；const/adr/todo 三卷立）；§3.2 交叉引用改指 ADR-MC-003，顺修 mystore 拼写。 |
| v0.1.3 | 2026-10-08 | R-05 收口笔同步（§6 静态门**已闭**：--deny-warn 两包 0 错 0 警；98/98 守恒）。 |
| v0.1.2 | 2026-10-08 | 测试命名循 moonttl 标准改造同步（§1 目录形态行 + 依赖表行：`for "test"` = fs/json/utf8 黑盒专用；debug 不再入测试依赖）；98/98 守恒。 |
| v0.1.1 | 2026-10-08 | MC-6 拍定落卷（supported_targets = native+wasm，§1 目标声明行同步）+ MU1 执行同步（§5 包卫生行 / §6 静态门行：警告已消，余存量 8 项在册未闭，收口另立笔）。 |
| v0.1.0 | 2026-10-08 | 立卷（用户令「生成 mooncmd 项目的 spec.md」）：包定位与依赖 / 主链成文 / 公开契约面（§3.1–3.6，实测）/ 存储布局与三缺口 / 已落-未落表 / 判据与门 / 非目标 / 追溯矩阵 / 消费方互锁。拆自 MCMD-S1 §一/§三/§四/§五/§七/§八；`[提案]` 行原样搬迁（拆卷 ≠ 签发），决策正文未随迁（归需求档及将来包 `adr`）。 |
