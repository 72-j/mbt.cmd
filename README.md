# thy1016/cmd

mooncmd 聚合词表 → 骨架代码的 **moonx 命令面**(独立薄模块;wasm-safe,
moonx = 取注册表预编译 wasm → moonrun 执行)。

读一份 aggregate 词表 TOML,发射四件骨架代码(agg 方言);读一份
`[[process_manager]]` 词表则走 PM 方言(单件 + 脚手架双模式,见下):

| 产物 | 内容 | regen 行为 |
|---|---|---|
| `<名>_gen.mbt` | 骨架本体(事件/命令/状态/分派/wire/账本) | 每次再生覆写(纯产物) |
| `<名>_contract_wbtest.mbt` | 契约门脚手架(init 契约 + wire roundtrip + 确定性) | 每次再生覆写(纯产物) |
| `<名>_glue.mbt` | 装配胶水六桥件(handler/applier/empty_state/serialize/deserialize/type_name) | 每次再生覆写(纯产物) |
| `<名>_policy.mbt` | 裁决策略 stub(正确签名守卫闭包,`Err("TODO(...)")` 即未填) | **仅缺位时落,regen 永不覆写**(stub-zone) |

## 用法

```sh
moonx thy1016/cmd@latest <table.toml>
```

模式(脚手架单件径,bootstrap-only):

```sh
moonx thy1016/cmd@latest --pm-assembly <pm表.toml>   # 装配样板(内存 store 夹具+runner 接线)
moonx thy1016/cmd@latest --pm-behavior <pm表.toml>   # 行为面 trait 带缺省体
```

选项:`--version` / `-V`、`--help` / `-h`。`@latest` 恒写(消费口径;版本钉进
产物头注溯源)。产物落**表同目录**。
exit 码:0 成功 / 2 缺参或未知选项 / 3 表读不到 / 4 parse 拒 / 5 validate 拒。

产出后两步:

1. 填裁决体:`<名>_policy.mbt` 里每钩子 = 正确签名闭包,把
   `Err("TODO(<Cmd>): 裁决体待填——红线7")` 换成真实裁决(红线7:裁决
   不入表,策略件是唯一手写面;glue 的 handler 桥内装配 `<名>_hooks()`,
   桥面零手写);
2. 装配 + 验:六桥件已发射,消费包 `moon.pkg` 生产 import 块加
   `thy1016/mooncmd/command` + `moonbitlang/core/encoding/utf8`
   (moon.mod 模块级授亲 `thy1016/mooncmd@<版>`),然后

   ```moonbit
   let root = AggregateRoot::new(id, <名>_handler,
     EventApplier::Single(<名>_applier), <名>_empty_state())
   let store = SQLiteEventStore::new(path, <名>_serialize,
     <名>_deserialize, <名>_type_name)
   ```

   契约罐 `<名>_contract_wbtest.mbt` 随包 `moon test` 即验。

## 词表格式(aggregate 方言)

```toml
schema_version = "1.0"
generator = "mooncmd_agg_gen"
target_package = "你的包路径"

[aggregate]
name = "account"          # 词根(Pascal/snake 两形派生)
id = "string"             # id 域(封闭集:string)

[aggregate.state]
fields = [
  { name = "balance", type = "int", init = "0" },
]

[[aggregate.events]]
name = "Deposited"
fields = [ { name = "amount", type = "int" } ]
evolve = ["add balance=amount"]     # 演化指令封闭集:set|add|append|remove

[[aggregate.commands]]
name = "Deposit"
fields = [ { name = "amount", type = "int" } ]
```

封闭集:字段类型 `string|int|bool`;演化指令 `set|add|append|remove`;
裁决语义**不入表**(红线7)——词表只描述结构与演化,裁决在策略件。

## PM 方言(`[[process_manager]]`)

PM 表走单件径:`<名>_pm_gen.mbt`(状态/interested/saga_id_of/handle/
apply/PM 记录面六段;emit 闭包与 SnapshotStore 装配 = 消费方组合根,
红线7 同源)。泵 API:`pump_event` 单事件 / `pump_events` 批量
fail-fast。

脚手架双模式(bootstrap-only,实装体住产出件——gen 零手编):

| 模式 | 产物 | 用户实装 |
|---|---|---|
| `--pm-assembly` | `<名>_pm_asm.mbt`(内存 store 夹具 + runner 接线 + 冒烟罐) | store 换持久构造器;emit 闭包 = 命令去向决策(必填显式) |
| `--pm-behavior` | `<名>_pm_behavior.mbt`(行为面 trait 五缺省体 + 适配器) | 最小实装 = `impl <Trait> for <Struct> with fn name` + 差异槽覆写(interested/handle/apply 照业务) |

缺省体(安全惰值):saga_id_of = 信封 `aggregate_id` 直读 / handle =
零发射 / apply = 透传 / init_state = 词表零值态 / interested = 不观注;
name 唯一必填(state_key 命名空间 `<名>:<saga_id>`)。
`declare impl` 声明形**勿用**——编译过但运行时缺省不继承直落 abort
(勘证 2026-11-18)。

## 治理三律(与上游 mooncmd 的契约)

1. **变更单向律**:发射器能力变更只先落主仓
   `bitbang/skelschema/mooncmd_agg_toml_gen.mbt`,本仓 `gen/` 只跟随
   搬运(体保真);
2. **漂移探测律**:本仓 `gen/` 测试面 golden 字节双探针 = bank 表 →
   期望产物 ≡ 主仓已提交 `account_gen.mbt` + `account_glue.mbt` 字节
   (溯源三件换算,产物体零漂)——主仓发射器一变,本罐当场红,照差移植
   (红灯驱动同步);
3. **发布配对律**:发射器变更 = mooncmd 与 cmd 同日发版。

## 开发

```sh
sh driver/gate.sh     # 一令门:双目标 check(--deny-warn)+ gen 双腿测试(12 罐)+ e2e 台
sh driver/e2e.sh      # 单跑 e2e:native+wasm 双运行时 × 五判(四件落盘/产物零漂[gen+glue]/only-if-absent 回归/wasm/消费项目核身[glue 依赖走 registry 冻结件])
```

判行:`CMD-GATE: PASS` / `CMD-E2E: PASS`。无叠层需求(依赖全在
registry);golden 探针用仓内冻结 fixture,不挂 mooncmd 仓。

## 配套文档

词表语义/红线全谱 = `mooncmd` 仓 `const.md` + `README`(agg 表头注记);
配方节见 mooncmd README「从词表到骨架」。
