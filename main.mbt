// ===== cmd —— mooncmd 聚合词表 → 骨架代码(命令面)=====
// 用法:moonx thy1016/cmd@latest <table.toml>
// 读 aggregate 词表 → parse/validate → 发射三件(落表同目录):
//   <名>_gen.mbt             骨架本体(事件/命令/状态/分派/wire/账本)
//   <名>_contract_wbtest.mbt 契约门脚手架(init 契约 + wire roundtrip + 确定性)
//   <名>_policy.mbt          裁决策略 stub(仅缺位时落,regen 永不覆写)
// 溯源三件烙进产物头注(source_table = 调用方给的径;治理②:换库换径即
// 重发)。exit 码:0 成功 / 2 缺参 / 3 表读不到 / 4 parse 拒 / 5 validate 拒。
// 发射本体住 gen 包(纯 String→String,wasm-safe;治理三律见 README)。

///|
/// 表径的目录前缀(含尾 '/';无 '/' = 空串 = 产物落当前目录)。
fn dir_prefix_of_table(table_path : String) -> String {
  let mut cut = -1
  for i in 0..<table_path.length() {
    if table_path[i].to_int() == 47 {
      cut = i
    }
  }
  if cut < 0 {
    ""
  } else {
    table_path[:cut + 1].to_owned()
  }
}

///|
/// driver 主径:argv → 读表 → parse/validate → 发射三件 → 指引印。
/// 返回 exit 码(main 统一出口)。
async fn run(args : Array[String]) -> Int32 {
  if args.length() < 1 {
    println(
      "用法:moonx thy1016/cmd@latest <table.toml>(aggregate 词表;产出 <名>_gen.mbt + <名>_contract_wbtest.mbt + <名>_policy.mbt[仅缺位时落])",
    )
    return 2
  }
  let table_path = args[0]
  let readable = try {
    let _ = @fs.read_file(table_path).binary()
    true
  } catch {
    _ => false
  }
  if !readable {
    println("cmd: 表读不到(\{table_path})")
    return 3
  }
  let toml_text = @utf8.decode(@fs.read_file(table_path).binary())
  let def = match @gen.parse_mooncmd_agg(toml_text) {
    Ok(found) => found
    Err(msg) => {
      println("cmd: parse 拒:\{msg}")
      return 4
    }
  }
  match @gen.validate_mooncmd_agg(def) {
    Ok(_) => ()
    Err(msg) => {
      println("cmd: validate 拒:\{msg}")
      return 5
    }
  }
  let dir = dir_prefix_of_table(table_path)
  let gen_path = dir + def.name + "_gen.mbt"
  let contract_path = dir + def.name + "_contract_wbtest.mbt"
  let policy_path = dir + def.name + "_policy.mbt"
  let provenance = @gen.SchemaProvenance::{
    source_table: table_path,
    regen_command: "moonx thy1016/cmd@latest " + table_path,
    binder_path: "thy1016/cmd/gen(agg 方言 parse/validate/emit 三件套)",
  }
  @fs.write_file(
    gen_path,
    @utf8.encode(@gen.emit_mooncmd_agg(def, provenance~)),
  )
  @fs.write_file(
    contract_path,
    @utf8.encode(@gen.emit_mooncmd_agg_contract_tests(def)),
  )
  let policy_absent = try {
    let _ = @fs.read_file(policy_path).binary()
    false
  } catch {
    _ => true
  }
  if policy_absent {
    @fs.write_file(
      policy_path,
      @utf8.encode(@gen.emit_mooncmd_agg_policy_stub(def)),
    )
    println(
      "policy stub 已落(仅缺位时落,regen 永不覆写): \{policy_path}",
    )
  } else {
    println("policy 已在,未触碰: \{policy_path}")
  }
  println("cmd codegen: \{gen_path} + \{contract_path} 已写")
  println(
    "装配指引:\{def.name}_hooks() 填好裁决体后传入 \{def.name}_decide(见 \{gen_path} 分派骨架);契约罐 \{contract_path} 随包 moon test 即验",
  )
  return 0
}

///|
/// cmd 根包 = 薄启动器(air 形):argv 切头,业务码统一出口。
async fn main {
  let argv = @env.args()
  let args : Array[String] = []
  for i in 1..<argv.length() {
    args.push(argv[i])
  }
  let code = run(args)
  if code != 0 {
    @sys.exit(code)
  }
}
