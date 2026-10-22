# mooncmd 包宪法（const）

版本：**v1.1.0**（2026-10-22 Supersede：新增 §3 生成红线三条——聚合 TOML 大gen 特性护栏；v1.0.0 2026-10-08 立卷拆自 MCMD-S1 §二）
体例：世界卷 `bangto/world/const.md` §5.1 `const` 卷位——**红线簿，冻结只读**；修改仅允许 Supersede 换版并留变更行。效力域：`mooncmd/` 子树（世界卷条文对其全部适用且不失效力；项目级/世界级回灌另走换版）。
定位一句话：mooncmd（通用 CQRS/事件溯源框架独立模块）的**绝对不允许清单**，九条。

---

## 1. 语义红线（三条）

1. **纯事件返回**：CommandHandler 只返回纯事件数组（`Result[Array[E], CommandError]`），不得组装或携带元数据。（ADR-MC-002）
2. **包装权独占**：`EventMessage` 的包装只允许发生在 `AggregateRoot::execute`——`correlation_id` 承自 `CommandMessage`、`causation_id` 记前因；其余任何代码路径不得手工组装 `EventMessage`。（ADR-MC-002）
3. **Router 唯一写入口**：持久化只允许 Router 触发 `EventStore.append`；聚合与命令处理器不得直触 EventStore。（ADR-MC-002）

## 2. 形态与边界红线（三条）

4. **记录型函数面定版**：`EventStore` / `SnapshotStore` / `EventBus` 以 struct-of-functions 为唯一形态；**禁止**再引入 trait 形态双轨（旧 trait 注释体已退役）。重评估条件：MoonBit trait 支持高阶类型。（ADR-MC-003）
5. **mystate 互渗禁令**：`mystate` 只作纯函数 Monad 基础设施，不得引入事件溯源语义；ES 语义不得下沉进 mystate。（ADR-MC-006；FR-MC-7）
6. **时间源唯一**：事件时间戳只来自 `@async.now()` 注入点；投影与确定性路径禁取当前时钟。（NFR-MC-4；与首个消费方的时间源红线同源）

---

## 3. 生成红线（三条；聚合 TOML 大gen 特性护栏，2026-10-22 随架构探讨立）

> 适用面：若（且仅若）启用聚合词表生成（`<agg>_agg.toml` → 绑定器 → 产物入库；
> 做不做/何时 = todo 役7 D-MG-1 待裁）。特性护栏三条先于特性入宪——**宪法圈定
> 特性可存在的形**，防止生成器长成第二业务面。底稿 = `.mingspace/commanded_mooncmd.md`
> （对勘茗篇）+ 架构探讨五刀边界。

7. **裁决不入表**：命令裁决（decide / guard / 业务条件）只能以**手写钩子**存在于
   策略件（`*_policy.mbt`）；聚合词表（TOML）与生成产物**禁止**表达条件业务语义——
   表内只许**无条件**演化指令，条件归钩子。（宪法 §1 第 3/4 条同源：生成器无业务
   逻辑、无静默推断；jelly 形状表「gen 产分派骨架、手写钩子供实现」同款先例）
8. **演化指令集封闭**：事件演化（event → state）只允许封闭指令集
   `set` / `add` / `append` / `remove` 四件；扩集 = 词表拍改（本簿换版）。
   生成器 scope 门把「表内出现封闭集外指令」判红。（moonttl semantics tags
   「模板指令集可硬编码」同款判例；指令集膨胀 = 滑向 TOML 写业务的前兆）
9. **生成区/手写区双向分离**：生成产物（`*_gen.mbt`：state struct / 事件·命令
   枚举 / apply 全量 / decide 骨架 / wire 映射 / 契约测试脚手架）**禁手写**
   （黄金门重生成逐字节对拍）；裁决钩子与框架装配**禁进生成产物**。双向越界
   皆红——与「生成物禁手写」既有纪律同族，加反向手写件禁入生成区半边。

---

## 4. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.1.0 | 2026-10-22 | **Supersede：生成红线三条立**（裁决不入表 / 演化指令集封闭 set·add·append·remove / 生成区·手写区双向分离）——聚合 TOML 大gen 特性护栏先于特性入宪；特性「做不做/何时」= todo 役7 D-MG-1 待裁，本簿只圈其可存在的形。底稿 = `.mingspace/commanded_mooncmd.md` 对勘茗篇 + 架构探讨五刀边界。六条原红线不变。 |
| v1.0.1 | 2026-10-21 | 红线六条不变；第 6 条交叉引用去敏（WVGEN 内部卷名→消费方中性表述，随独立成仓发布面）；ADR-MC-007 立条另卷。 |
| v1.0.0 | 2026-10-08 | 立卷（用户令「开 MU2 立卷笔」，钉单一定稿）：语义红线三条 + 形态与边界红线三条；拆自 MCMD-S1 §二（ADR-MC-001..006 对位），状态随搬迁。 |
