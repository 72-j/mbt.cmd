# mooncmd

`thy1016/mooncmd` 是一个用 MoonBit 编写的事件溯源（Event Sourcing /
CQRS）框架库：命令处理器产出纯事件，框架统一包装事件元数据（事件 ID、
correlation / causation 追溯链、时间戳、schema 版本），Router 作为唯一持久化
写入口；内置乐观并发守门、SQLite 事件存储、拉取式投影、快照加速、Effect
重试状态机，以及聚合词表（TOML）代码生成。


## 特性

- 纯事件主链：命令处理器为纯函数
  `(S, C) -> Array[E] raise CommandError`，只做业务裁决、不碰元数据与
  存储；`AggregateRoot` 承担生命周期（执行 / 提交 / 重放重建 / 快照）。
- 元数据自动包装：`EventMessage` 由框架独占组装——`event_id`（UUID v4）、
  `correlation_id` 承自命令、`causation_id` 记前因、`user_id` 全链透传、
  `schema_version` 预留位；时间/标识源可注入——`clock?` / `id_gen?`
  可选槽（两级：`RouteEnv` 与 `AggregateRoot` 构造点），缺省
  `@async.now()` / `@uuid.v4()`，注一点则全链受控。
- 乐观并发：批次首事件版本必须等于当前版本 + 1，否则
  `DuplicateVersion` 拒写；表级 `UNIQUE(aggregate_id, version)` 竞态兜底；
  事务失败整体回滚。
- 快照加速：`to_snapshot` / `SnapshotStore` 记录面 + `from_snapshot`
  基态重建（快照读路径已接入分发主流程）；快照态起跑 + 尾部重放与全量
  重放等价有契约钉。
- 拉取式投影：`Projection` 记录面 + `LiveProjection`（订阅位置
  Origin / Current / FromVersion，检查点即版本）+ SQLite 持久化投影。
- Effect 重试状态机：`RetryMachine` 协议面（错误分类封闭集 + 纯裁决，
  无时钟无副作用）+ `exec_with_effect`（固定 / 指数退避、按错误类别
  分派、熔断；退避等待由调用方注入）。
- 聚合词表代码生成（维护侧工具链，产物已随模块入库）：TOML 声明（约 30–50 行）自动产出状态结构、事件与
  命令枚举、apply 演化链、命令分派骨架、wire 序列化与契约测试门；
  业务裁决归手写策略钩子。
- Monad 注入面：`monads` 子包提供 State / Writer / Reader / EventWriter
  纯函数基础设施，不含事件溯源语义。

## 安装

确保环境中已安装 MoonBit 工具链，然后在模块根目录：

```bash
moon add thy1016/mooncmd
```

（模块源码正式地址：gitlink <https://gitlink.org.cn/thy7/mbt.cmd> 与
GitHub 镜像 <https://github.com/72-j/mbt.cmd>；工作区多模块场景可直接以
本地树路径引用。）

框架按域分包，在用到它的包的 `moon.pkg` `import` 块中按需添加：

```moonbit
import {
  "thy1016/mooncmd/aggregate",
  "thy1016/mooncmd/command",
  "thy1016/mooncmd/event",
  "thy1016/mooncmd/store",
}
```

## 快速上手

### 定义聚合并执行命令

命令处理器与事件应用器均为纯函数；`exec` 自动包装 `CommandMessage`
并链式返回：

```moonbit
let root = @aggregate.AggregateRoot::new(
  "account-001",
  account_handler,                                   // (S, C) -> Array[E] raise CommandError
  @event.EventApplier::Single(account_applier),      // (S, E) -> S
  AccountState::init(),
)
let root = root.exec(AccountCommand::CreateAccount("Demo", 1000))
let root = root.exec(AccountCommand::DepositMoney(500))
```

### SQLite 落库与重放重建

```moonbit
let store = @store.SQLiteEventStore::new(
  "ledger.db", account_serialize, account_deserialize, account_type_name,
)
store.append("account-001", root.uncommitted_events())
let rebuilt = @aggregate.AggregateRoot::from_events(
  "account-001", store.load("account-001", 0),
  account_handler, @event.EventApplier::Single(account_applier),
  AccountState::init(),
)
```

### 统一分发（dispatch 门面）

执行、落库、通知、提交、强一致等待，一个调用串完：

```moonbit
let committed = @mooncmd.dispatch(
  records,                                  // EventStore 记录面
  None,                                     // EventBus（可选）
  root,                                     // 聚合根
  AccountCommand::DepositMoney(500),        // 命令
  projections=[live_projection],            // Strong 模式需等待的投影
  consistency=@mooncmd.Strong,              // 默认 Eventual
)
```

### Effect 重试（乐观并发自动重试）

```moonbit
let machine : @aggregate.RetryMachine = {
  default_action: fn(kind) {
    match kind {
      @aggregate.Duplicate => @aggregate.ActionRetry   // 并发冲突：重放重执行
      _ => @aggregate.ActionExhausted                  // 业务拒：重放同结果，不重试
    }
  },
  decide: fn(attempt, _failures, _kind) {
    if attempt > 3 {
      @aggregate.GiveUpRaise
    } else {
      @aggregate.WaitRetry(wait_ms=100L)
    }
  },
}
let root = root.exec_with_effect(
  AccountCommand::DepositMoney(500), machine,
  @aggregate.RetryHooks::none(), fn(ms) { /* 退避等待，由调用方注入 */ },
)
```

## 聚合词表代码生成

用 TOML 声明聚合形状（字段 / 事件 / 命令 / 机械演化指令），生成器产出
其余全部样板；模板见 `examples/bank/account_agg.toml`：

```toml
[aggregate.state]
fields = [{ name = "balance", type = "int", init = "0" }]

[[aggregate.events]]
name = "MoneyDeposited"
fields = [{ name = "amount", type = "int" }]
evolve = ["add balance=amount"]
```

校验（自足，克隆即可跑）：

```bash
moon test                           # 生成产物结构钉 + 契约测试 + 已知答案校验
```

词表再生成属维护侧工具链：发射器集中主仓（bitbang 仓 `skelschema` 包，
不随本模块发布），本仓持词表（TOML）与生成产物。改 `account_agg.toml`
等词表后，主仓仓根 `moon run skelschema/cmd` 再生刷新产物；主仓 golden
统一户黄金门逐字节对拍（REGEN≡DISK，再生 ≡ 入库产物）；**生成物禁手写**。

生成物包含：状态结构与初值、事件 / 命令枚举、apply 演化链、命令分派
骨架、wire 序列化（含 schema 版本预留位）、契约测试门（init 值契约 +
wire 往返恒等）。事件命名与粒度属通用语言决策，由词表声明；机械演化
与序列化由生成器承担。完整上手路径见 `examples/bank_demo`（可运行全链自证：
`moon run examples/bank_demo --target native`；行为与测试住 `examples/bank` 库包）。

### 命令面发射（消费者径，moonx）

不想手写的消费者走 moonx 命令面（`thy1016/cmd`，独立薄模块，
wasm-safe；moonx = 取注册表预编译 wasm → moonrun）：

```bash
moonx thy1016/cmd@latest <table.toml>
```

`@latest` 恒写。产出三件落**表同目录**：`<名>_gen.mbt` +
`<名>_contract_wbtest.mbt`（regen 覆写）+ `<名>_policy.mbt`（裁决策略
stub，**仅缺位时落，regen 永不覆写**——stub-zone）。填好裁决体后装配：
`<名>_hooks()` 传入 `<名>_decide`（见 gen 分派骨架）；契约罐随包
`moon test` 即验。发射器与 mooncmd 词表方言的契约 = 治理三律（变更
单向 / 漂移探测 / 发布配对），见 cmd 仓 README。

### 手写聚合配方（消费者径）

发射器不随本模块发布——构建自己的聚合时，把词表当**设计工作表**，
按分区手写同等结构（形状对抄 `examples/bank/account_gen.mbt`，约 190 行
样板即清单）：

| 词表分区 | 手写件 | 形状要点 |
|---|---|---|
| `[aggregate.state]` | 状态结构 + `init()` | `pub(all) struct` + `#derive(Eq)`；每字段一行，初值对齐表 `init` |
| `[[aggregate.events]]` | 事件枚举 | `pub(all) enum`，一行一变体，载荷字段照表 |
| `[[aggregate.commands]]` | 命令枚举 | 同上 |
| evolve 指令 | `apply` 演化链 | 封闭集四指令（set/add/append/remove）直写 `{ ..state, field: value, }` 更新链（同字段后写覆前写）；封闭集外的演化属裁决，进钩子 |
| —— | 裁决钩子 + 分派 | `DecideHooks` 记录型函数面 + `decide` 分派骨架（只做载荷拆包）；**裁决体手写**（红线 7：余额不足类业务裁决不进 apply 链，参照 `account_policy.mbt`；MoonBit 记录字段作函数调用要带括号：`(hooks.deposit_money)(state, amount)`） |
| —— | wire 序列化 | `to_wire` / `from_wire` 行格式 `"1\t<Event>\t<fields>"`，首列 = `schema_version` 预留位（现版只认 `"1"`，坏载荷返 `None`） |

手写验收清单 = 上段「生成物包含」逐项自配：init 值契约（每字段初值可
从 `init()` 读回）、wire 往返恒等（`from_wire(to_wire(e)) == Some(e)`）、
已知答案（apply 逐事件对拍状态）——断言形可参照 `examples/bank` 的
契约测试件。口径拨清：「生成物禁手写」约束的是 owner 仓的 regen 面
（防手改被再生覆盖）；消费者手写自己的词汇层不受此限，本节即其配方。

完整可跑的手写示例见 `examples/bank_handwritten`——与生成产物
`account_gen.mbt` 同族同形的手写孪生件（账户开户/存取/销户，纯
MoonBit 面 native+wasm 双腿），另附 EventStore 端口的内存实现
（`memory_store.mbt`，生产径换 `SQLiteEventStore` 消费侧零改动），
7 个契约测试逐项演示验收清单的断言形。

## API 总览

| 包 | 入口 | 作用 |
|---|---|---|
| `aggregate` | `AggregateRoot` | 生命周期：`new` / `from_events` / `from_snapshot` / `exec` / `execute` / `commit` / `to_snapshot` |
| `aggregate` | `exec_with_effect` | Effect 重试状态机执行（`RetryMachine` + 策略钩子 + 等待注入） |
| `command` | `CommandMessage` / `CommandHandler` | 命令信封（correlation / causation / user）与纯函数处理器类型 |
| `event` | `EventMessage` / `EventApplier` / `EventBus` | 事件信封（元数据全集）/ 事件应用器 / 进程内事件外发 |
| `store` | `SQLiteEventStore` / `EventStore` / `SnapshotStore` | SQLite 后端（含 `to_event_store` 适配器）与记录型存储抽象 |
| `projection` | `Projection` / `LiveProjection` / `PersistedProjection` | 投影定义、内存实时投影（检查点推进）、SQLite 持久化投影 |
| `monads` | `State` / `Writer` / `Reader` / `EventWriter` | 纯函数 Monad 基础设施 |
| 根包 | `dispatch` / `Router` / `RouteEnv` / `RouterBuilder` | `dispatch` 统一编排门面（执行→落库→通知→提交→强一致等待）；`Router` 高级编排（快照基态 / 重试机 / Reader 注入） |

## 错误面

总错误 `EventSourcingErr` 六臂：`CommandErr` / `EventStoreErr` /
`SnapshotErr` / `EventBusErr` / `AggregateErr` / `ConsistencyErr`
（Strong 一致性轮询超预算）。常用变体：`CommandError` 六变体
（`InvalidCommand` / `Unauthorized` / `PreconditionFailed` / `NotFound` /
`Conflict` / `UnregisteredCommand`）；`EventStoreError` 三变体
（`DuplicateVersion` / `StorageError` / `SerializationError`）。均实现
`Show`，可按变体 `match` 处理。

## 设计边界

- 命令处理器只返回纯事件；事件元数据由 `AggregateRoot` 独占包装；
  持久化只经 Router 触发。
- 事件时间戳/事件标识只来自注入的 `clock` / `id_gen` 槽（缺省系统钟
  `@async.now()` / `@uuid.v4()`）；业务代码零直读时钟，投影与确定性
  路径不读取当前时钟——同输入 + 同注钟 + 同 id 源 ⇒ 同事件流。
- 不做分布式 / 跨进程事件总线（`EventBus` 仅进程内可选挂点）；不做
  事件升级 / 迁移框架（`schema_version` 只预留）；不承诺第二存储后端；
  不内置业务聚合（`examples/bank` 为示例与测试模板）。

定位与边界的完整说明见 `spec.md`；设计裁定沿革见 `adr.md`。

## 测试与验证

```bash
moon test --target native               # 全模块测试（wasm 同支持）
moon run examples/bank_demo --target native  # 全链自证，终行 EXAMPLE:PASS
```

运行时输出各测试面的计数行（下表实测于 2026-10-31；分包读数，native
合计 75 / 75，wasm 58 / 58）：

| 面 | 读数 |
|---|---|
| 单元与端到端测试（主包 + 各域子包：聚合生命周期、乐观并发、投影契约、Router 分发全流程） | 45 / 45 |
| 词表生成门与契约测试（`examples/bank`：生成产物逐字节比对、已知答案、init 值契约 + wire 往返恒等） | 17 / 17 |
| quicktest 随机状态机（生命周期机 + 守恒律四罐） | 13 / 13 |
| 示例全链自证（`moon run examples/bank_demo`） | 终行 `EXAMPLE:PASS` |

### quicktest 生命周期随机状态机

`quicktest/` 内置随机状态机测试件（pbtgen QuickMachine 脚手架生成），驱动与
`examples/bank` 同族的最小账户域（开户 / 入账生命周期），以事件溯源管线的
四条守恒律为被测性质：

- **版本守恒**：每条被接受命令恰好推进一版（k 条命令后聚合版本为 k）；
- **事件流守恒**：未提交事件流恰 k 条，且消息版本位连续 1..k（乐观并发
  校验的记账骨架）；
- **账目守恒**：引擎可观状态与纯模型镜像逐步同步（双执行零漂移）；
- **拒绝零痕迹**：业务拒命令不推版、不入流、不记账。

随机 60 例 + 固定脚本回归基线 + 覆盖门；余额算术值面由 `examples/bank`
契约门承担，本机只取生命周期位面。

```bash
moon test -p thy1016/mooncmd/quicktest
```

版本沿革见 `CHANGELOG.md`。

## 许可证

本项目采用木兰宽松许可证 v2（Mulan PSL v2，见 `LICENSE`）。
官方文本：<http://license.coscl.org.cn/MulanPSL2>。
