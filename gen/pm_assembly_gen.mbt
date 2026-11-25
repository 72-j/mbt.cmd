// pm_assembly_gen.mbt —— PM 装配样板发射（bootstrap-only 物化面）。
// 读同一 MooncmdPmDef，发组合根样板段（store 夹具 + runner 构造器 +
// 冒烟罐）。与词表件的分界：词表产物 = 黄金门逐字节禁手改；本件 =
// .hand-maintained，落盘后归手维护，regen 管线不覆盖（--pm-assembly
// 显式 out 才重写）。pbtgen bootstrap-only 物化纪律同款。
// 模板 ≡ fmt 正典（家法18）：五处判宽点（store 签名/ledger 注解/smoke
// runner 行/runner 返型/new 调用）>80 发折形——折形 = fmt 实测目录
// （泛型括号逐行/闭包块形）；emit 参数行 fmt 实测 99 字符不折（参数行
// 阈值更高），超长词表发现即校准（eetf 阈值带同款）。

///|
/// 包别名派生：target_package 尾段（examples/bank → bank → @bank）。
fn pm_assembly_alias(target_package : String) -> String {
  match target_package.rev_find("/") {
    Some(idx) => target_package[idx + 1:].to_owned()
    None => target_package
  }
}

///|
/// PM 装配样板发射：store 夹具 + runner 构造器 + 冒烟罐（空流泵零）。
/// emit 闭包 = 命令去向决策，样板只收参不缺省（静默吞禁形）。
pub fn emit_mooncmd_pm_assembly(
  def : MooncmdPmDef,
  provenance~ : SchemaProvenance,
) -> String {
  let sb = StringBuilder()
  let state_type = schema_upper_first(def.name) + "PmState"
  let pkg_alias = pm_assembly_alias(def.target_package)
  let t_state = "@\{pkg_alias}.\{state_type}"
  let t_cmd = "@\{pkg_alias}.\{def.command_type}"
  let t_evt = "@\{pkg_alias}.\{def.event_type}"
  sb <+
    "// ===== \{def.name} PM 装配样板（脚本物化 bootstrap-only；.hand-maintained）=====\n"
  sb <+
    "// 组合根手改自由（红线7：装配不进词表）；本件落盘后归手维护，\n"
  sb <+ "// regen 管线不覆盖（--pm-assembly 显式 out 才重写）。\n"
  sb <+
    "// 源表：\{provenance.source_table}（词表产物 \{def.name}_pm_gen.mbt = 黄金门逐字节；本件非黄金面）\n"
  sb <+
    "// 物化：moon run skelschema/cmd -- --pm-assembly <out>（主仓仓根起跑）\n"
  sb <+ "\n"
  sb <+ "///|\n"
  sb <+
    "/// 内存 SnapshotStore（组合根样板；生产换持久后端构造器）。\n"
  // 判宽点① store 签名
  let store_sig = "fn \{def.name}_pm_asm_store() -> @store.SnapshotStore[String, \{t_state}] {"
  if store_sig.length() > 80 {
    sb <+ "fn \{def.name}_pm_asm_store() -> @store.SnapshotStore[\n"
    sb <+ "  String,\n"
    sb <+ "  \{t_state},\n"
    sb <+ "] {\n"
  } else {
    sb <+ "\{store_sig}\n"
  }
  // 判宽点② ledger 注解
  let ledger_line = "  let ledger : Array[Map[String, (\{t_state}, Int32)]] = [Map([])]"
  if ledger_line.length() > 80 {
    sb <+ "  let ledger : Array[\n"
    sb <+ "    Map[String, (\{t_state}, Int32)],\n"
    sb <+ "  ] = [Map([])]\n"
  } else {
    sb <+ "\{ledger_line}\n"
  }
  sb <+ "  {\n"
  sb <+
    "    save: (key, state, version, _ts) => ledger[0][key] = (state, version),\n"
  sb <+ "    load: key => ledger[0].get(key),\n"
  sb <+ "  }\n"
  sb <+ "}\n"
  sb <+ "\n"
  sb <+ "///|\n"
  sb <+
    "/// runner 构造（emit 闭包 = 命令去向决策，必填显式——无缺省）。\n"
  sb <+ "fn \{def.name}_pm_asm_runner(\n"
  sb <+
    "  emit : (String, \{t_cmd}) -> Unit raise @mooncmd.ProcessManagerError,\n"
  // 判宽点③ runner 返型
  let runner_ret = ") -> @mooncmd.ProcessManagerRunner[\{t_state}, \{t_cmd}, \{t_evt}] {"
  if runner_ret.length() > 80 {
    sb <+ ") -> @mooncmd.ProcessManagerRunner[\n"
    sb <+ "  \{t_state},\n"
    sb <+ "  \{t_cmd},\n"
    sb <+ "  \{t_evt},\n"
    sb <+ "] {\n"
  } else {
    sb <+ "\{runner_ret}\n"
  }
  // 判宽点④ new 调用
  let new_call = "  @mooncmd.ProcessManagerRunner::new(@\{pkg_alias}.\{def.name}_pm(), \{def.name}_pm_asm_store(), emit)"
  if new_call.length() > 80 {
    sb <+ "  @mooncmd.ProcessManagerRunner::new(\n"
    sb <+ "    @\{pkg_alias}.\{def.name}_pm(),\n"
    sb <+ "    \{def.name}_pm_asm_store(),\n"
    sb <+ "    emit,\n"
    sb <+ "  )\n"
  } else {
    sb <+ "\{new_call}\n"
  }
  sb <+ "}\n"
  sb <+ "\n"
  sb <+ "///|\n"
  sb <+ "test \"\{def.name} pm assembly smokes: empty flow pumps zero\" {\n"
  sb <+ "  let sent : Array[(String, \{t_cmd})] = []\n"
  // 判宽点⑤ smoke runner 行（长名闭包折块形 = fmt 实测）
  let smoke_line = "  let runner = \{def.name}_pm_asm_runner((target, cmd) => sent.push((target, cmd)))"
  if smoke_line.length() > 80 {
    sb <+ "  let runner = \{def.name}_pm_asm_runner((target, cmd) => {\n"
    sb <+ "    sent.push((target, cmd))\n"
    sb <+ "  })\n"
  } else {
    sb <+ "\{smoke_line}\n"
  }
  sb <+ "  let handled = runner.pump_events([])\n"
  sb <+ "  assert_eq(handled, 0)\n"
  sb <+ "  assert_eq(sent.length(), 0)\n"
  sb <+ "}\n"
  sb.to_string()
}
