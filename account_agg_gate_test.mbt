// ===== 聚合 gen 黄金门 + 行为金锚（役7 D-MG;源表 account_agg.toml）=====
// 黄金门:parse → emit ≡ 入库产物逐字节（生成红线9）。
// 金锚:命令脚本 → 事件流/终态已知答案（策略件语义）。

///|
test "account aggregate golden gate: emit byte-equal to committed product" {
  let toml_text = @fs.read_file_to_string("examples/account_agg.toml")
  let def = match @skelschema.parse_mooncmd_agg(toml_text) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  let emitted = @skelschema.emit_mooncmd_agg(def)
  let committed = @fs.read_file_to_string("examples/account_gen.mbt")
  assert_eq(emitted, committed)
}
