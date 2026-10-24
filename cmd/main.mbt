// ===== cmd —— 聚合词表再生命令（上手面;胶水脚本）=====
// 用法：模块根 `moon run cmd --target native` 或 workspace 仓根
// `moon run mooncmd/cmd --target native`（双路锚点探测）。
// 流程：扫 examples/bank/*.toml → 按内容识别（[aggregate]/[retry]）→
//   parse → emit → 写同目录产物（agg 双件 gen+契约门；retry 单件 gen）。
// 尾判：AGG-REGEN:PASS（全量重生成完毕，黄金门由消费方测试兜底）。
// 产物禁手写（红线9）；改表 → 本命令 → moon test 黄金门复验。

///|
/// 锚点探测（双路先例）：workspace 仓根 cwd（锚 ./mooncmd）与独立仓模块根
/// cwd（锚 .）两形兼容——探词表首件在即定锚。
fn anchor() -> String {
  let probe = @fs.read_file_to_string(
    "./mooncmd/examples/bank/account_agg.toml",
  ) catch {
    _ => ""
  }
  if probe != "" {
    return "./mooncmd"
  }
  "."
}

///|
fn main raise {
  let root = anchor()
  let dir = "\{root}/examples/bank"
  let mut regenerated = 0
  for name in @fs.read_dir(dir) {
    if !name.has_suffix(".toml") {
      continue
    }
    let path = "\{dir}/\{name}"
    let text = @fs.read_file_to_string(path)
    if text.contains("[aggregate]") {
      let def = match @skelschema.parse_mooncmd_agg(text) {
        Ok(found) => found
        Err(msg) => {
          println("AGG-REGEN:FAIL \{name}: \{msg}")
          return
        }
      }
      @fs.write_string_to_file(
        "\{dir}/\{def.name}_gen.mbt",
        @skelschema.emit_mooncmd_agg(def),
      )
      @fs.write_string_to_file(
        "\{dir}/\{def.name}_contract_wbtest.mbt",
        @skelschema.emit_mooncmd_agg_contract_tests(def),
      )
      regenerated += 1
      println(
        "  [agg] \{name} → \{def.name}_gen.mbt + \{def.name}_contract_wbtest.mbt",
      )
    } else if text.contains("[retry]") {
      let def = match @skelschema.parse_mooncmd_retry(text) {
        Ok(found) => found
        Err(msg) => {
          println("AGG-REGEN:FAIL \{name}: \{msg}")
          return
        }
      }
      @fs.write_string_to_file(
        "\{dir}/\{def.name}_retry_gen.mbt",
        @skelschema.emit_mooncmd_retry(def),
      )
      regenerated += 1
      println("  [retry] \{name} → \{def.name}_retry_gen.mbt")
    }
  }
  if regenerated > 0 {
    println(
      "AGG-REGEN:PASS（\{regenerated} 张词表重生成完毕;黄金门由消费方测试兜底）",
    )
  } else {
    println("AGG-REGEN:FAIL: 未发现词表（扫 \{dir}）")
  }
}
