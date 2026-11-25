# mooncmd 决策记录（adr）

版本：**v1.1.0**（2026-10-08 建卷；ADR-MC-001..006 自 MCMD-S1 §二拆入；2026-10-21 ADR-MC-007 立条 + 去敏三处）
体例：`bangto/generator/README.md` §2——**追加式**：已接受结论不修改，只能 Supersede 并标注编号；引用必须写全号（`ADR-MC-00x`）。作用域前缀 **`ADR-MC-`**，已登记全仓 ADR 索引（`generator/README.md` §3）。
上游与搬迁声明：《mooncmd 需求档》（MCMD-S1 v0.1.1）§二**原样搬迁**至此（四项封闭改写：卷头/章节序号/交叉引用/卷类上提）；**拆卷 ≠ 签发**——原 `[定案 2026-10-22 签发]` 标记原样保留，签发前不充当门判据。源档归档：`bak/requirements.md`。

---

## ADR-MC-001 包定位：主仓通用共享包 `[定案 2026-10-22 签发]`

- mooncmd 是 `thy1016/bitbang` 内的**通用** ES 框架包，不隶属任何项目；消费靠包路径（`thy1016/bitbang/mooncmd`）。
- **被否方案**：① 并入宿主仓某项目 cmd 组装层——否，项目组装层挂通用件会造双真源与越界依赖；② 独立仓库——否，宿主单仓多包是现行布局律（world §5.4 扁平式 + 仓根拍平先例），共享由包路径承担。
- **重评估条件**：出现第二个与 bitbang 无关的仓要消费它，且包路径引用造成反向依赖时，再议拆仓。

## ADR-MC-002 核心语义定版（cmd.md 升格）`[定案 2026-10-22 签发]`

- 三条为包红线（现录 `const.md` §1）：**①** CommandHandler 只返回纯事件；**②** `AggregateRoot::execute` 独占 `EventMessage` 包装权（`correlation_id` 承自 Command、`causation_id` 记前因）；**③** Router 是唯一的持久化写入口（聚合外不得直接触 EventStore）。
- **被否方案**：Handler 直返 `EventMessage`——否，元数据手工组装正是 cmd.md 否定的旧路径（易漏 correlation/causation）。

## ADR-MC-003 抽象形态：记录型函数面定版 `[定案 2026-10-22 签发]`

- `EventStore` / `SnapshotStore` / `EventBus` 以 **struct-of-functions** 为定版形态；旧 trait 注释体**删除**（不留第二形态）。
- 理由：MoonBit trait 不支持高阶类型（`mystate/state.mbt` 头注在案）；记录面可局部组合/替换，测试已绿。
- **被否方案**：trait 形——同上证据；**重评估条件**：MoonBit trait 支持关联类型/HKT 后重议。

## ADR-MC-004 存储后端：首版 SQLite 单后端 `[定案 2026-10-22 签发]`

- `SQLiteEventStore` 为唯一落地后端；记录面抽象保留，但**不承诺**第二后端（防假抽象）。
- **被否方案**：首版双后端（内存 + SQLite）——内存版仅作测试夹具价值，不作交付承诺；**重评估条件**：出现真实消费方的第二持久化需求（如消费方乙案事件库导出形态变化）。

## ADR-MC-005 API 基准：async 为主、`dispatch_now` 为显式捷径 `[定案 2026-10-22 签发]`

- 依赖 `moonbitlang/async` 已进主链（`@async.now()` 时间源、async test 在用）；对外 API 以 async 为基准，同步变体（`dispatch_now`）保持**显式命名**，不作默认。

## ADR-MC-006 入库序：先入库、后接客 `[定案 2026-10-22 签发]`（supported_targets 已拍）

- mooncmd 在首个消费方接入前完成入库（与消费方规划卷的重评估条件咬合）；**入库同笔**必含：`supported_targets` 声明 + `moon.pkg` 卫生 + uuidm 依赖入 moon.mod 提交 + 根目录散置草稿清理。
- **已拍（2026-10-08）**：`supported_targets` = **`native+wasm`**（循 `moonbit-community/sqlite3` 的 `moon.pkg:21` 逐字同款）；卫生项已执行（MU1，2026-10-08），**提交动作待业务方令**。

---

## ADR-MC-007 mooncmd 独立成仓在树（mbt.cmd）`[定案 2026-10-21]`

- mooncmd 自 2026-10-21 起为**独立 MoonBit 模块** `thy1016/mooncmd` + **独立 git 仓**（gitlink `thy7/mbt.cmd`，master），在主仓树内存在但主仓不跟踪（主仓 `.gitignore` 止蚀行，moonspace 等先例同款）；许可证木兰宽松 v2（MulanPSL-2.0）。
- 消费方式：经 mooncakes 依赖 `thy1016/mooncmd@0.1.0`（开发态可 path 依赖）；主仓原 `f4ah6o/uuidm` 依赖随迁本模块（根仓无其它用户，实测）。
- **Supersede**：ADR-MC-001 的“包路径消费（`thy1016/bitbang/mooncmd`）与独立仓库否决”口径——重评估条件（第二个无关仓消费）未到，但用户令直接拍定独立成仓，如实记；ADR-MC-001 的“不隶属任何项目”定位不变。
- **被否方案**：① 继续内嵌主仓——嵌套 moon.mod 在盘 = 根仓构建静默跳过（moonlineage M1-2 实证），且无发布版本面；② 真拆出树（移出主仓目录）——失去在树联调便利，moonspace 先例即“在树独立仓”。
- 配套：脚手架经 `moonxr/ops_projgen.mbtx`（`proj_dialect.toml` 方言件在树，管模块根产物）；发布元数据变更须经 `moonxr/release_review.mbtx`（独立 clone 真路径）。

---

## ADR-MC-008 时间源注入代码化（clock/id_gen 可选槽）`[定案 2026-11-07 用户五裁]`

- **裁定五条**（用户 2026-11-07 拍）：D1 = 裸 fn 槽（不立 trait Clock、不加依赖；**后议触发条件：业务侧不注钟 → 永远不议**）；D2 = 两级注入（`RouteEnv` 级 Router 全链受控 + `AggregateRoot` 级单聚合受控）；D3 = 双槽同形（`clock? : () -> Int64` + `id_gen? : () -> String`，uuid 同题同解）；D4 = RouterBuilder 不动（不加 clock 字段）；D5 = 随下版 0.2.3 发布。
- **设计依据**：穿链路径单一——dispatch/Router → `AggregateRoot.execute` → `EventMessage::from_command`，注一点则全链受控；`() -> Int64` 同步裸 fn 零 async 色传导（`@async.now()` 同步可调，0.22.4 mbti 实勘）；信封组装点 = 框架内唯一读钟面。
- **落地面**：信封构造器 ×4（`CommandMessage::new` / `EventMessage::new` / `from_command` / `Snapshot::new`）+ 聚合根三级构造（`new` / `from_events` / `from_snapshot`）+ `RouteEnv::new` 尾部可选参数；`AggregateRoot` / `RouteEnv` 各持双槽字段；缺省 = 现行为不变（`@async.now()` / `@uuid.v4()`）——三条纪律不破：业务代码零直读时钟 / 框架独占组装 / 缺省行为不变。红线 6 随役 Supersede v1.2.0（"时间源唯一"→"时间源唯一且可注入"）。
- **证据罐三件**：bank 定钟全链（事件时间戳全取注入值）/ 同输入同钟同 id 源两次运行事件流逐字段相等（id 消费序 = envelope 1 格 + event 1 格）/ Router env 注钟落库时间戳透传。native 78/78 + EXAMPLE:PASS + 主仓 golden 17/17 零涟漪（gen 链未触）。
- **被否方案**：① trait Clock 注入——加抽象层 + 跨包 impl 面，业务侧无第二形态需求（D1 后议条件封死）；② RouterBuilder 加 clock 字段——两级已覆盖（env 级即 Router 全链），builder 重复（D4）；③ 只注 root 不注 env——Router 内部 from_snapshot 构造点会落到系统钟，全链受控破功（D2 反向依据）。

## ADR-MC-009 dispatch 中间件管道（记录型函数面）`[定案 2026-11-13]`

- **裁定四条**（对标 Commanded pipeline，`lib/commanded/middleware/`；立项 = 对齐茗篇 `commanded_alignment_ming.md` C-09，P2-5）：D1 = **记录型函数面三槽**（`name` + `before` / `after` / `failure`；ADR-MC-003 同族——无 trait 无 behaviour 宏）；D2 = **洋葱律**：`before` 按数组序、`after` 逆序（Commanded pipeline 同款）；`failure` 按数组序且**只对主链五步错误触发**——中间件自身抛错直接穿透不进 failure 槽（防自触发递归 + 主链错/挂点错语义分明）；D3 = **DispatchContext 只读记录**四字段（`aggregate_id` / `command` / `events` / `version`——before 时 events 空数组、version 为现版本；after 时 events 全量、version 为落库后版本）；D4 = **门面零新时钟**：中间件若需计时，时钟由用户闭包捕获注入（红线 6 不破——参考件 `logging_middleware(clock~, ...)` 显式收钟）。
- **设计依据**：Commanded 现役四件中两件结构性不需要——`extract_aggregate_identity`（Commanded 的 dispatch 收命令模块需提取聚合 ID；mooncmd 直收聚合根，ID 在手）与 `consistency_guarantee`（门面第⑤步已内建）。故 mooncmd 中间件面收窄为**用户挂点**（验证 / 日志 / 遥测 / 审计），管道本身零业务语义。
- **落地面**：`dispatch` 门面 +`middleware~` 可选槽（缺省空数组 = 现行为字节稳——宪法新键 optional）；根包新件 `middleware.mbt`（DispatchContext + DispatchMiddleware + logging_middleware 参考件）；测试四钉（触发序/逆序/failure 路径/挂点错误穿透）。
- **被否方案**：① trait 形中间件——加抽象层 + 跨包 impl 面，无第二形态需求（MC-008 D1 同律）；② 中间件错误进 failure 槽——failure 递归自触发风险 + 主链错与挂点错混淆（D2 反向依据）；③ before/after 拆两个记录型——单记录两阶段构造即可，拆面徒增。

---

## ADR-MC-010 快照自动节律可配置（snapshot_every 差值判定）`[定案 2026-11-14]`

- **勘定注记**：现役 `dispatch_once` Step 5 已有落帧但形制为**硬编码模判定** `version % 100 == 0`（0.1.0 首发遗留，f3e4e0e 随迁）——茗篇 C-10 描述「缺落帧节律」stale；本役实际落件 = 模判定退役 → Commanded 差值判定 + 配置槽 + 缺省关闭（对标 `lib/commanded/snapshotting.ex:68` 一行判定式，立项 = 茗篇 C-10 / todo P2-6）。
- **裁定四条**：D1 = **RouteEnv 配置槽** `snapshot_every : Int32` + `RouteEnv::new` 可选参（缺省 0 = 关闭；ADR-MC-008 `clock?`/`id_gen?` 同形两级注入位）；D2 = **判定式 Commanded 同款差值制** `version - base_version >= snapshot_every`（base_version = Step 0 快照基版本，无快照 = 0；量纲 = 自上次快照以来的版本跨度 = 重建成本的真量纲）；D3 = **模判定退役**（`% 100` 删除——零测试断言、零文档承诺，首发遗留无兼容面；缺省行为从「每 100 版」变「关闭」= Commanded snapshotting 缺省禁用语义对位）；D4 = **落帧时机与失败语义不动**（Step 5 位置、commit 前、`SnapshotErr` 诚实穿透）。
- **设计依据**：差值制 vs 模制——聚合自快照基版本重建后（如 base=97），模判定只在整百开火（错位盲区），差值制量「自上次快照以来的跨度」与基版本对齐无关；且命令不推进版本时差值不变，无虚假重写。
- **落地面**：`RouteEnv` +1 字段 +1 可选参（9 处调用点零涟漪）；`dispatch_once` Step 5 判定替换 + 头注拨正；spec.md §2 一处措辞；测试四钉（差值开火 / 缺省关闭 / 阈值不满足不落 + 快照后重计 / Step 0 读径闭环）。
- **被否方案**：① 模制保留 + 配置并存——双节律两套语义徒增（装配差异不是代码分叉）；② RouterBuilder / CommandConfig 加槽——节律是环境级（全部 dispatch 路径共用 env），CommandConfig 是单命令执行参数，错位；③ SnapshotPolicy trait / 回调形——无第二形态需求（MC-008/009 D1 同律）。

---

> **签发记(2026-10-22)**:ADR-MC-001..006 全数 [定案 2026-10-22 签发] → **[定案]**——独立仓 0.1.0 首发(RELEASE:PASS)+ 役5a/5b/5d/7 实战检验 + Account 金样对照,定版窗口兑现(随役5c 契约清债笔)。逐条正文不动,状态标记即签发。

## ADR-MC-011 Process Manager 框架面（显式泵 + 词表 gen 化路线）`[定案 2026-11-14]`

**勘定**（C-08 对标,茗篇 commanded_alignment §3）：Commanded saga =
四回调 behaviour（interested?/handle/apply/error）+ 全局事件流重处理。
mooncmd 组装积木勘定三则：EventStore 按 aggregate_id 分流**无全局流**
（重处理面结构性不在）;EventBus 单槽 publish **无订阅多播**;SnapshotStore
面同族可复用（零新表）。落件形态用户拍定 = **词表 gen 化**（2026-11-14）;
切法两役 = 13a 框架面（gen 产物消费的接口面,手写）→ 13b 词表 gen 化
（skelschema `pm_toml_gen` 方言 + cmd 搬运路由 + 演示样例切换 gen 产物）。

**裁定**：
- **D1 = 四回调记录面**（记录型函数面同族——middleware/projection
  同形制）：`interested`（相关性预判）/ `saga_id_of`（分片键,收完整
  EventMessage 信封——键可取 aggregate_id 或载荷字段）/ `handle`（产
  `DirectedCommand`（命令本体 + target_aggregate_id 跨聚合地址）/ `apply`
  （状态演化）。error/3 裁决**不立**——显式泵下失败 = raise 透传
  （EmitFailed/StateFailed 独立 suberror,不混 dispatch 主链
  EventSourcingError——加臂涟漪重试裁决六臂分类）,裁决权在调用方
  catch;钩子槽挂账候真需求。
- **D2 = 显式泵**（`ProcessManagerRunner.pump_events/pump_event`）：逐事件
  interested→装态（load 缺失 = init）→handle→逐条 emit（任一失败
  fail-fast,状态不推进）→apply→save。订阅组装留调用方（bus publish
  闭包串 pump / dispatch 后显式喂任选）。**语义差诚实记**：Commanded
  「事件确认前崩溃→重启重处理」不在 mooncmd 面（无全局流）;emit 成功
  后 save 前崩溃 = 命令已发状态未进,重喂重发——exactly-once 责任在
  调用方泵序,add 类 evolve 不幂等挂账。
- **D3 = 状态持久化复用 SnapshotStore**：键 = "<pm名>:<saga_id>"
  命名空间隔离多 PM;version 槽 = 源事件聚合版本（诚实溯源,saga
  语义弱化——PM 不在同一聚合流上）。多 PM = 多 runner 互不干扰。
- **D4 = 命令发射注入闭包**：`(target_id, C) -> Unit raise
  ProcessManagerErr`——调用方组装 dispatch/Router 任一径;失败转译
  一次进 EmitFailed 文案。

**被否方案**：①EventBus 扩订阅多播（动现役记录面,bank bus 用法涟漪,
且推模式常驻泵与 mooncmd 无进程驻留哲学相抵）②EventSourcingError 加
ProcessManagerErr 臂（六臂分类消费面全涟漪）③error/3 钩子槽（无
第二形态需求,显式泵调用方裁决已足）。

**13b 预告**（词表 gen 化边界,红线7 同族）：gen 产 = interested
封闭集 match + handle 字段直通映射（emit 行:命令名+target_field+
字段 source→target 对）+ apply evolve 行（复用 set/add 封闭集）+
状态 struct;计算级映射 = stub zone 手写（红线7 裁决不入表）。

**13b 履行笔**（2026-11-14 当日落地,边界兑现核对）：`skelschema/
pm_toml_gen.mbt` 方言件（parse/validate/emit 三件套,schema 0.2.0）
+ `examples/bank/account_pm.toml` 样例表 + `account_pm_gen.mbt` 入库产物
（transfer saga 手写件退役随批）+ `pm_toml_gen_test.mbt` 四钉（解析
校验/词根拒/saga_key 双径/形状锚+装配哨兵）+ 主仓黄金门 PM 行;cmd
仓搬运同步（方言件体保真 + CLI
PM 路由双拒合成错 + serde 第五件随补 + 役12 漂移补齐）。预告边界
逐条兑现：六段产物（状态 struct/interested 封闭集/saga_id_of/
handle 直通映射/apply evolve 行/PM 记录面）全机械;`emit` 行 =
数据;装配（ProcessManagerRunner::new/emit 闭包/SnapshotStore）不
在词表 = 消费方组合根（红线7 同源,PM 罐哨兵钉死产物零装配体）。

## 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.4.0 | 2026-11-14 | **ADR-MC-011 立条**（Process Manager 框架面:四回调记录面 + 显式泵 + SnapshotStore 复用 + 命令发射注入;词表 gen 化两役切法 13a→13b,13b 同日落地,履行笔见上）。 |
| v1.3.0 | 2026-11-14 | **ADR-MC-010 立条**（快照自动节律可配置，差值判定 + RouteEnv 槽缺省关闭，模判定退役）；ADR-MC-009 变更记录行补账（役11 立条时漏行）。 |
| v1.2.0 | 2026-11-07 | **ADR-MC-008 立条**（时间源注入代码化，用户五裁定案 D1–D5：裸 fn 槽 / 两级 / 双槽同形 / RouterBuilder 不动 / 随下版 0.2.3）；红线 6 Supersede 走 const.md v1.2.0 另簿。 |
| v1.1.0 | 2026-10-21 | **ADR-MC-007 立条**（独立成仓在树 mbt.cmd，Supersede ADR-MC-001 包路径口径）；同步去敏三处（内部项目名→中性表述，release_review ③ 类门对齐）。 |
| v1.0.0 | 2026-10-08 | 建卷（用户令「开 MU2 立卷笔」）：ADR-MC-001..006 自 MCMD-S1 §二原样搬迁（状态标记原样，拆卷 ≠ 签发）；建卷同笔登记全仓 ADR 索引（generator/README.md §3 一行）。源档归档 `bak/requirements.md`。 |
