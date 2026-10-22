# commanded × mooncmd 对勘：ES 两生态位的先进性与真差距（茗谈笔记）

> 议题：参照件 **commanded**（Elixir 生态十年 ES/CQRS 框架；源码抽读
> `bak/commanded/`——lib 208 文件 / 11,238 行，MIT，gitignore 吞不入 VCS）
> × **mooncmd**（本模块，3,552 行全仓）对勘。方法论 = 承重源码细读
> （aggregates/middleware/process_managers/subscriptions/snapshotting/
> serialization/guides）× 双仓实证读数（commanded 十年生产；
> mooncmd 41/41 + deny 0 + EXAMPLE:PASS + wasm 原生）。
> 2026-10-22 收编。关联卷：spec.md v0.1.7 / adr.md ADR-MC-007 /
> todo.md 役5b·5c·6；下游 = moonrdb tx.md §5（ES 底座候选）/
> link.todo.md §14（遗忘对接）。

---

## 1. 总判

**不是谁先进，是两个生态位各自把先进性做到了头。** commanded 把
「服务端分布式 ES 应用框架」做满（进程模型、saga、事件演进、可观测、
分布式——五项真领先）；mooncmd 把「嵌入式 ES 内核」做满（静态类型
编译期契约、wasm 原生零运行时、3.5k 全仓可审计、确定性红线——四项
反向领先）。**思想三处完全同构**：框架独占元数据包装（execute 独占
EventMessage vs 红线②）、乐观并发（expected_version 守门 + UNIQUE
兜底 vs DuplicateVersion + UNIQUE 同强度）、确定性纪律（commanded
correlation/causation 传播 vs mooncmd 时间源唯一/投影禁取时钟——与
moonrdb「重放禁止重算非确定值」三门同话）。**差距是成熟度的肉，
按锚逐块长即可**（§3 五条全部带锚，不预立——moonrdb R-3 同款纪律）。

## 2. 对勘表（维度 × 判）

| 维度 | commanded | mooncmd | 判 |
|---|---|---|---|
| 并发控制 | 聚合 = GenServer（temporary），命令邮箱串行化，lifespan 闲置回收 | execute 纯函数 + 乐观并发，串行化交宿主 | 分生态位：服务端 commanded；嵌入式 mooncmd（moonrdb 以 SQLite 事务+指纹代进程） |
| 扩展点 | Middleware 三钩子管道（Pipeline.assigns 共享袋） | CommandConfig（consistency/retries） | commanded |
| 强一致阻塞 | consistency_guarantee（dispatch 后等订阅追上） | 无（moonrdb 拍 ghost 容忍+重建 D-Tx-2） | commanded 有原语；嵌入式等价取舍 |
| 长事务/saga | Process Managers 原语（自认 saga pattern + 补偿命令回滚） | 无（补偿 = Policy 手写） | commanded |
| 事件演进 | serialization 上转型 transformers | schema_version 只预留不演进 | commanded（真差距 #1） |
| 订阅/投影 | subscriptions 检查点 + ack | LiveProjection 空壳（役5c） | commanded（真差距 #2） |
| 分布式 | pubsub/registration/hive | 单机内嵌 | commanded（定位使然，不追） |
| 可观测 | 全链 telemetry 四段命名族 | logger 基础件 | commanded（真差距清单外参考 #11） |
| 类型安全 | 动态 + compile_time_assertions 补 | 泛型 [Id,S,C,E] 编译期咬合 | mooncmd |
| 嵌入性 | 必须活在整个 OTP 应用里 | wasm 原生零运行时 | mooncmd |
| 元数据/确定性 | 独占包装 + correlation 传播 | 独占包装 + 时间源唯一 | 平手（同构） |
| 存储强度 | behaviour 多适配器 | 守门 + UNIQUE + 回滚 | 平手 |
| 审计面 | 11k + OTP 耦合 | 3.5k 全读 | mooncmd |
| 成熟度 | 十年生产集群 | 0.1.0 首发 | commanded（时间资产） |

## 3. 真差距清单（可收编，全部带锚不预立）

1. **事件演进机制**（commanded serialization transformers）：mooncmd 的
   schema_version 只预留——**锚 = 首次事件模式变更**，届时 transformers
   思想入投影/上转型；
2. **订阅检查点**：役5c 投影契约成文时吸收 checkpoint/ack 语义——
   moonrdb 的投影重建（向量/图）正是订阅方，checkpoint 能省全量重放；
3. **Middleware 管道**：锚 = 首个横切需求（telemetry/审计）；moonrdb
   侧的等价物其实已经长出来了——tx.md 的 **Effect 缝就是同一思想的
   MoonBit 形**；
4. **Process Manager/saga 原语**：锚 = 首个跨聚合补偿需求（与 moonrdb
   D-Tx-2 (b) 同源，**两家一起等锚**）；
5. **一致性阻塞原语**：若 moonrdb 将来要强一致双写（翻 D-Tx-2 案），
   commanded 的 consistency_guarantee 是现成设计稿。

## 4. 参考点分档（bak 翻件索引；学形不抄码）

**现役可参考（不等锚）**：`event/mapper+handler+error_handler` 三面
= 投影契约设计稿（喂役5c FR-MC-3）· `guides/` 十二篇 = 文档分篇骨架 ·
`assertions/` = ES 测试断言 DSL 形 · `bench/` = 基准负载形 ·
`middleware/consistency_guarantee.ex` = 强一致阻塞稿。

**等锚设计稿**：`process_managers/` 全家桶（**failure_context.ex** =
补偿上下文通用底座，#4 翻案时先读）· `serialization/` 上转型链（#1）·
`snapshotting.ex`（SnapshotData + TypeProvider + 阈值 = moonrdb
「快照边界」件直接设计稿）· `subscriptions/registry.ex`（#2）·
`aggregates/aggregate_lifespan.ex`（闲置回收，moonrdb 内存聚合膨胀时）·
`telemetry.ex` 命名族（观测面役）。

**只借思想**：event_store behaviour 适配器最小面判定（append/load/
current_version 三件——mooncmd 面形一致，同源）；分布式整块不参考。

## 5. 纪律与关联

- **MIT + gitignore 吞**：本地参照不入分发，义务解除；**学形不抄码**，
  结构命名收编时按 mooncmd 词表改名，卷面引用出处（commanded + 文件名）；
- mooncmd 定位自持：**「库不绑定业务」+ wasm 原生**（2026-10-22
  preferred_target = wasm 拍）与 commanded 的 OTP 绑定形成**生态位互补**，非竞争关系——本篇不触发
  任何役，五条差距全部待锚；
- 下游关联：moonrdb tx.md §5 前置清单三件已清二件半（抽仓 ✅ /
  三红 ✅（过渡伪影勘正）/ sealed 疑虑消解于 ADR-MC-003 记录面 ✅※），
  剩 workspace 加员或 registry 发布一件随接线役拍。
