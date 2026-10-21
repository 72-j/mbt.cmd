# mooncmd 决策记录（adr）

版本：**v1.1.0**（2026-10-08 建卷；ADR-MC-001..006 自 MCMD-S1 §二拆入；2026-10-21 ADR-MC-007 立条 + 去敏三处）
体例：`bangto/generator/README.md` §2——**追加式**：已接受结论不修改，只能 Supersede 并标注编号；引用必须写全号（`ADR-MC-00x`）。作用域前缀 **`ADR-MC-`**，已登记全仓 ADR 索引（`generator/README.md` §3）。
上游与搬迁声明：《mooncmd 需求档》（MCMD-S1 v0.1.1）§二**原样搬迁**至此（四项封闭改写：卷头/章节序号/交叉引用/卷类上提）；**拆卷 ≠ 签发**——原 `[提案]` 标记原样保留，签发前不充当门判据。源档归档：`bak/requirements.md`。

---

## ADR-MC-001 包定位：主仓通用共享包 `[提案]`

- mooncmd 是 `thy1016/bitbang` 内的**通用** ES 框架包，不隶属任何项目；消费靠包路径（`thy1016/bitbang/mooncmd`）。
- **被否方案**：① 并入宿主仓某项目 cmd 组装层——否，项目组装层挂通用件会造双真源与越界依赖；② 独立仓库——否，宿主单仓多包是现行布局律（world §5.4 扁平式 + 仓根拍平先例），共享由包路径承担。
- **重评估条件**：出现第二个与 bitbang 无关的仓要消费它，且包路径引用造成反向依赖时，再议拆仓。

## ADR-MC-002 核心语义定版（cmd.md 升格）`[提案]`

- 三条为包红线（现录 `const.md` §1）：**①** CommandHandler 只返回纯事件；**②** `AggregateRoot::execute` 独占 `EventMessage` 包装权（`correlation_id` 承自 Command、`causation_id` 记前因）；**③** Router 是唯一的持久化写入口（聚合外不得直接触 EventStore）。
- **被否方案**：Handler 直返 `EventMessage`——否，元数据手工组装正是 cmd.md 否定的旧路径（易漏 correlation/causation）。

## ADR-MC-003 抽象形态：记录型函数面定版 `[提案]`

- `EventStore` / `SnapshotStore` / `EventBus` 以 **struct-of-functions** 为定版形态；旧 trait 注释体**删除**（不留第二形态）。
- 理由：MoonBit trait 不支持高阶类型（`mystate/state.mbt` 头注在案）；记录面可局部组合/替换，测试已绿。
- **被否方案**：trait 形——同上证据；**重评估条件**：MoonBit trait 支持关联类型/HKT 后重议。

## ADR-MC-004 存储后端：首版 SQLite 单后端 `[提案]`

- `SQLiteEventStore` 为唯一落地后端；记录面抽象保留，但**不承诺**第二后端（防假抽象）。
- **被否方案**：首版双后端（内存 + SQLite）——内存版仅作测试夹具价值，不作交付承诺；**重评估条件**：出现真实消费方的第二持久化需求（如消费方乙案事件库导出形态变化）。

## ADR-MC-005 API 基准：async 为主、`dispatch_now` 为显式捷径 `[提案]`

- 依赖 `moonbitlang/async` 已进主链（`@async.now()` 时间源、async test 在用）；对外 API 以 async 为基准，同步变体（`dispatch_now`）保持**显式命名**，不作默认。

## ADR-MC-006 入库序：先入库、后接客 `[提案]`（supported_targets 已拍）

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

## 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.1.0 | 2026-10-21 | **ADR-MC-007 立条**（独立成仓在树 mbt.cmd，Supersede ADR-MC-001 包路径口径）；同步去敏三处（内部项目名→中性表述，release_review ③ 类门对齐）。 |
| v1.0.0 | 2026-10-08 | 建卷（用户令「开 MU2 立卷笔」）：ADR-MC-001..006 自 MCMD-S1 §二原样搬迁（状态标记原样，拆卷 ≠ 签发）；建卷同笔登记全仓 ADR 索引（generator/README.md §3 一行）。源档归档 `bak/requirements.md`。 |
