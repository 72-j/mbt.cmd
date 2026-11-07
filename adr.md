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

---

> **签发记(2026-10-22)**:ADR-MC-001..006 全数 [定案 2026-10-22 签发] → **[定案]**——独立仓 0.1.0 首发(RELEASE:PASS)+ 役5a/5b/5d/7 实战检验 + Account 金样对照,定版窗口兑现(随役5c 契约清债笔)。逐条正文不动,状态标记即签发。

## 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.2.0 | 2026-11-07 | **ADR-MC-008 立条**（时间源注入代码化，用户五裁定案 D1–D5：裸 fn 槽 / 两级 / 双槽同形 / RouterBuilder 不动 / 随下版 0.2.3）；红线 6 Supersede 走 const.md v1.2.0 另簿。 |
| v1.1.0 | 2026-10-21 | **ADR-MC-007 立条**（独立成仓在树 mbt.cmd，Supersede ADR-MC-001 包路径口径）；同步去敏三处（内部项目名→中性表述，release_review ③ 类门对齐）。 |
| v1.0.0 | 2026-10-08 | 建卷（用户令「开 MU2 立卷笔」）：ADR-MC-001..006 自 MCMD-S1 §二原样搬迁（状态标记原样，拆卷 ≠ 签发）；建卷同笔登记全仓 ADR 索引（generator/README.md §3 一行）。源档归档 `bak/requirements.md`。 |
