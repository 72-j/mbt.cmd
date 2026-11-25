# Changelog

## 0.1.2 (2026-11-25)

发射器命名统一随版（对齐 mooncmd 0.4.0——错误类型后缀统一 Error）+ 新增
PM 脚手架双模式:

- `--pm-assembly <pm表.toml>`:装配样板单件(内存 store 夹具 + runner
  接线 + 冒烟罐,bootstrap-only .hand-maintained);
- `--pm-behavior <pm表.toml>`:行为面 trait 带缺省体单件(五缺省,
  用户最小实装 = `impl <Trait> for <Struct> with fn name`);
- gen/pm_assembly_gen.mbt:发射文本错误类型对齐 `ProcessManagerError`
  (mooncmd 0.4.0 命名统一随版——体保真搬运,治理①主仓先行);
- CLI 提示行随 `pump_events` 泵名(0.3.0 双名对齐)。

## 0.1.1 (2026-11-11)

CLI 面打磨(cmd 仓本地,发射器 gen 包零变,黄金门零波及):

- `--version` / `-V`、`--help` / `-h` 选项;未知选项报错 + 用法两行,
  exit 2(此前 `--version` 被当表径报「表读不到」);
- 输出简化:成功 = 清单形(四件名 + policy 新落/保留标记)+ 三步
  「下一步」,去长句注释体;用法/选项两行制。

## 0.1.0 (2026-11-11)

二版拍1·装配胶水发射(发射器三件套 → 四件,主仓 skelschema 先行、本仓
跟随;治理三律同谱):

- `emit_mooncmd_agg_glue` 六桥件发射(handler/applier/empty_state/
  serialize/deserialize/type_name——handler 桥 decide Result →
  CommandError::InvalidCommand 同界 + hooks 装配;wire 桥 utf8 面;
  type_name 桶 arity 通配,零载荷裸模式);
- driver 三件落盘 → 四件落盘(gen/contract/glue/policy),装配指引印
  升级为配方形(桥面零手写,裁决仍只填 policy 钩子);
- golden 字节探针扩面双探针(gen + glue,钉G2),罐 9→12;e2e 台扩
  五判(四件落盘/glue 体零漂/消费项目核身 glue 腿 = registry 冻结件
  `thy1016/mooncmd@0.2.2` 授亲 + command/utf8 包级 import);
- 上游配套:mooncmd 仓 bank/bank_demo 消费 committed glue(demo 六桥
  手写桥退役 = 消双实现 drift),bank glue 入黄金门(39/39)。

## 0.0.1 (2026-11-10)

首版。mooncmd 聚合词表 → 骨架代码的 moonx 命令面:

- `gen` 包:agg 方言 parse/validate/emit 三件套(抽自主仓 skelschema
  体保真)+ 策略 stub 发射(`let _ =` 哑消费形,deny-warn 干净)+
  契约门脚手架发射;
- golden 字节探针(治理②漂移探测器本体):bank 表 → 期望产物 ≡ 主仓
  已提交 account_gen.mbt 字节(溯源三件换算,产物体零漂);
- 根包 driver:argv → 读表 → parse/validate → 三件落盘(policy
  仅缺位时落,stub-zone)→ 装配指引印;exit 码 0/2/3/4/5;
- 双腿:native + wasm(moonx 对位);一令门 `driver/gate.sh`
  (CMD-GATE: PASS),e2e 台 `driver/e2e.sh`(CMD-E2E: PASS,
  含消费项目编译核身 + only-if-absent 回归);
- 配对锚:targets mooncmd cmd-contract-0.2.3(参考态分支 = mooncmd 仓
  `cmd`;发射器变更主仓先行、cmd 跟随,治理三律见 README)。
