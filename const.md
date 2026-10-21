# mooncmd 包宪法（const）

版本：**v1.0.0**（2026-10-08 立卷；拆自 MCMD-S1 §二，对位 `adr.md` ADR-MC-001..006）
体例：世界卷 `bangto/world/const.md` §5.1 `const` 卷位——**红线簿，冻结只读**；修改仅允许 Supersede 换版并留变更行。效力域：`mooncmd/` 子树（世界卷条文对其全部适用且不失效力；项目级/世界级回灌另走换版）。
定位一句话：mooncmd（主仓通用 CQRS/事件溯源框架包）的**绝对不允许清单**，六条。

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

## 3. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0.1 | 2026-10-21 | 红线六条不变；第 6 条交叉引用去敏（WVGEN 内部卷名→消费方中性表述，随独立成仓发布面）；ADR-MC-007 立条另卷。 |
| v1.0.0 | 2026-10-08 | 立卷（用户令「开 MU2 立卷笔」，钉单一定稿）：语义红线三条 + 形态与边界红线三条；拆自 MCMD-S1 §二（ADR-MC-001..006 对位），状态随搬迁。 |
