// MoonBit module manifest — cmd
// 定位:mooncmd(消费者径)的 moonx 命令面——薄模块,根包即可执行。
// 吃聚合词表 TOML,吐骨架代码四件(`<name>_gen.mbt` 纯生成区 /
// `<name>_glue.mbt` 装配胶水六桥件 / `<name>_policy.mbt` 决策体 stub
// 区 / `<name>_contract_wbtest.mbt` 契约罐)。preferred_target = wasm:moonx 只跑注册表预编译 wasm
// (经 moonrun 宿主,async 栈同一 API)。air 同形(bitbang3 = wasm 版
// moonx 轻量版库)。发射器抽自主仓 skelschema 体保真;治理三律
// (变更单向 / golden 漂移探测 / 发布配对)见 README;契约锚 =
// mooncmd 仓 tag cmd-contract-*。
// 依赖面:发射器零 mooncmd 耦合(account_gen.mbt 全文无 import 实证)
// ——本模块不依赖 thy1016/mooncmd;唯一发射面依赖 = @toml。
// 驻地:mooncmd 仓 `cmd` 分支(本仓 master = mooncmd 本体;tag 系
// cmd-* 与 v* 分命名空间)。开发门:driver/gate.sh 一令门。

name = "thy1016/cmd"

version = "0.1.0"

readme = "README.md"

license = "MulanPSL-2.0"

keywords = [ "command-line", "moonx", "wasm", "codegen", "event-sourcing" ]

description = "cmd —— mooncmd 的 moonx 命令面:聚合词表 TOML 一令生成骨架代码(手写孪生件形状,消费者径)"

preferred_target = "wasm"

import {
  "moonbitlang/async@0.22.7",
  "moonbitlang/x@0.5.6",
  "moonbit-community/toml@0.5.0",
}
