// ===== Effect 重试 gen 黄金门（役8 续；源表 account_retry.toml）=====
// parse → emit ≡ 入库产物逐字节（生成红线9）。

///|
test "account retry golden gate: emit byte-equal to committed product" {
  let toml_text = @fs.read_file_to_string("examples/bank/account_retry.toml")
  let def = match @skelschema.parse_mooncmd_retry(toml_text) {
    Ok(found) => found
    Err(msg) => fail(msg)
  }
  let emitted = @skelschema.emit_mooncmd_retry(def)
  let committed = @fs.read_file_to_string("examples/bank/retry_gen.mbt")
  assert_eq(emitted, committed)
}
