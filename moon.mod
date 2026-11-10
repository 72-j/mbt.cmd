// MoonBit module manifest — cmd
// 定位:mooncmd(消费者径)的 moonx 命令面——薄模块,根包即可执行。
// 吃聚合词表 TOML,吐骨架代码三件(`<name>_gen.mbt` 纯生成区 /
// `<name>_policy.mbt` 决策体 stub 区 / `<name>_contract_wbtest.mbt`
// 契约罐)。preferred_target = wasm:moonx 只跑注册表预编译 wasm
// (经 moonrun 宿主,async 栈同一 API)。air 同形(bitbang3 = wasm 版
// moonx 轻量版库)。发射器抽自主仓 skelschema 体保真;治理三律
// (变更单向 / golden 漂移探测 / 发布配对)见 README 与本地卷
// cmd_ming.md;契约锚 = mooncmd 仓 tag cmd-contract-*。
// 依赖面:发射器零 mooncmd 耦合(account_gen.mbt 全文无 import 实证)
// ——本模块不依赖 thy1016/mooncmd;唯一发射面依赖 = @toml。
// 叠层开发(未发布期):仓内 moon.work(gitignore 忽略不入仓)——
// 见 README 开发节;发版后删之回注册表解析。

name = "thy1016/cmd"

version = "0.0.1"

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
