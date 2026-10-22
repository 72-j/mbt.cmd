# mooncmd

`thy1016/mooncmd` 是一个用 MoonBit 编写的命令侧事件溯源（Event Sourcing /
CQRS）框架库：命令处理器产出纯事件，框架统一包装事件元数据（事件 ID、
correlation / causation 追溯链、时间戳、schema 版本），Router 作为唯一持久化
写入口；内置乐观并发守门、SQLite 事件存储、拉取式投影、快照加速、Effect
重试状态机，以及聚合词表（TOML）代码生成。

## 特性

- 纯事件主链：命令处理器为纯函数
  `(S, C) -> Result[Array[E], CommandError]`，只做业务裁决、不碰元数据与
  存储；`AggregateRoot` 承担生命周期（执行 / 提交 / 重放重建 / 快照）。
- 元数据自动包装：`EventMessage` 由框架独占组装——`event_id`（UUID v4）、
  `correlation_id` 承自命令、`causation_id` 记前因、`user_id` 全链透传、
  `schema_version` 预留位、时间戳唯一取自 `@async.now()` 注入点。
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
- 聚合词表代码生成：TOML 声明（约 30–50 行）自动产出状态结构、事件与
  命令枚举、apply 演化链、命令分派骨架、wire 序列化与契约测试门；
  业务裁决归手写策略钩子。
- Monad 注入面：`monads` 子包提供 State / Writer / Reader / EventWriter
  纯函数基础设施，不含事件溯源语义。

## 安装

确保环境中已安装 MoonBit 工具链，然后在模块根目录：

```bash
moon add thy1016/mooncmd
```

（模块源码同托管于 gitlink `thy7/mbt.cmd`；工作区多模块场景可直接以
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
  account_handler,                                   // (S, C) -> Result[Array[E], CommandError]
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

再生成与校验：

```bash
moon run cmd --target native        # 扫描词表 → 生成产物 → AGG-REGEN:PASS
moon test                           # 黄金门（逐字节）+ 契约门 + 行为金锚
```

生成物包含：状态结构与初值、事件 / 命令枚举、apply 演化链、命令分派
骨架、wire 序列化（含 schema 版本预留位）、契约测试门（init 值契约 +
wire 往返恒等）。事件命名与粒度属通用语言决策，由词表声明；机械演化
与序列化由生成器承担。完整上手路径见 `examples/bank`（可运行全链自证：
`moon run examples/bank --target native`）。

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
| 根包 | `Router` / `RouteEnv` / `RouterBuilder` | 命令分发（含重试配置与批量分发）与依赖注入环境 |

## 错误面

总错误 `EventSourcingErr` 四臂：`CommandErr` / `EventStoreErr` /
`SnapshotErr` / `AggregateErr`。常用变体：`CommandError` 六变体
（`InvalidCommand` / `Unauthorized` / `PreconditionFailed` / `NotFound` /
`Conflict` / `UnregisteredCommand`）；`EventStoreError` 三变体
（`DuplicateVersion` / `StorageError` / `SerializationError`）。均实现
`Show`，可按变体 `match` 处理。

## 设计边界

- 命令处理器只返回纯事件；事件元数据由 `AggregateRoot` 独占包装；
  持久化只经 Router 触发。
- 事件时间戳只来自 `@async.now()` 注入点；投影与确定性路径不读取
  当前时钟。
- 不做分布式 / 跨进程事件总线（`EventBus` 仅进程内可选挂点）；不做
  事件升级 / 迁移框架（`schema_version` 只预留）；不承诺第二存储后端；
  不内置业务聚合（`examples/bank` 为示例与测试模板）。

定位与边界的完整说明见 `spec.md`；设计裁定沿革见 `adr.md`。

## 测试与验证

```bash
moon test                               # 全模块（wasm / native 双支持）
moon run examples/bank --target native  # 全链自证，终行 EXAMPLE:PASS
```

测试面构成：单元与端到端钉（聚合生命周期、乐观并发、投影契约、Router
分发全流程）、聚合词表黄金门（生成产物逐字节比对）、行为金锚（命令脚本
→ 事件流 / 终态已知答案）与免费契约门（init 值契约 + wire 往返恒等）。
版本沿革见 `CHANGELOG.md`。

## 许可证

本项目采用木兰宽松许可证 v2（Mulan PSL v2，见 `LICENSE`）。
官方文本：<http://license.coscl.org.cn/MulanPSL2>。
