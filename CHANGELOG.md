# Changelog

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
