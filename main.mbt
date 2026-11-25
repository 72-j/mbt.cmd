// ===== cmd —— mooncmd 词表 → 骨架代码(命令面)=====
// 用法:moonx thy1016/cmd@latest <table.toml>
// 方言路由:PM 先试([process_manager] 词根,单件 <名>_pm_gen.mbt);
// 拒则落回 aggregate 词表 → parse/validate → 发射四件(落表同目录):
//   <名>_gen.mbt             骨架本体(事件/命令/状态/分派/wire/账本)
//   <名>_contract_wbtest.mbt 契约门脚手架(init 契约 + wire roundtrip + 确定性)
//   <名>_glue.mbt            装配胶水六桥件(handler/applier/empty_state/
//                            serialize/deserialize/type_name)
//   <名>_policy.mbt          裁决策略 stub(仅缺位时落,regen 永不覆写)
// 溯源三件烙进产物头注(source_table = 调用方给的径;治理②:换库换径即
// 重发)。exit 码:0 成功 / 2 缺参或未知选项 / 3 表读不到 / 4 parse 拒 /
// 5 validate 拒。发射本体住 gen 包(纯 String→String,wasm-safe;治理
// 三律见 README)。

///|
/// CLI 版本位(与 moon.mod version 同步改——发布两处纪律)。
const VERSION : String = "0.1.2"

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
/// CLI 用法两行(无参/未知选项共用)。
fn print_usage() -> Unit {
  println(
    "cmd \{VERSION} — mooncmd 词表 → 骨架代码(agg 四件 / PM 单件 / PM 脚手架)",
  )
  println("用法: moonx thy1016/cmd@latest <table.toml>")
  println(
    "模式: --pm-assembly <table.toml>(装配样板)  --pm-behavior <table.toml>(行为面 trait 带缺省体)",
  )
  println("选项: --version  --help")
}

///|
/// CLI 选项预扫:命中即短路返回 exit 码。首遇 '-' 开头实参判定,
/// 非选项位留给表径。
fn scan_flags(args : Array[String]) -> Int32? {
  for arg in args {
    if arg.has_prefix("-") {
      match arg {
        "--version" | "-V" => {
          println("cmd \{VERSION}")
          return Some(0)
        }
        "--help" | "-h" => {
          print_usage()
          return Some(0)
        }
        _ => {
          println("cmd: 未知选项 \{arg}")
          print_usage()
          return Some(2)
        }
      }
    }
  }
  None
}

///|
/// 首个非选项实参 = 表径。
fn positional_arg(args : Array[String]) -> String? {
  for arg in args {
    if !arg.has_prefix("-") {
      return Some(arg)
    }
  }
  None
}

///|
/// driver 主径:argv → 选项预扫 → 读表 → parse/validate → 发射四件
/// → 清单汇报。返回 exit 码(main 统一出口)。
async fn run(args : Array[String]) -> Int32 {
  // 脚手架模式预扫(--pm-assembly/--pm-behavior):旗标摘出,余下走
  // 常规选项/表径扫描(未知 '-' 实参仍 exit 2)。
  let mut scaffold_mode = ""
  let rest_args : Array[String] = []
  for arg in args {
    if arg == "--pm-assembly" || arg == "--pm-behavior" {
      scaffold_mode = arg
    } else {
      rest_args.push(arg)
    }
  }
  match scan_flags(rest_args) {
    Some(exit_code) => return exit_code
    None => ()
  }
  let table_path = match positional_arg(rest_args) {
    Some(path) => path
    None => {
      print_usage()
      return 2
    }
  }
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
  // 方言路由（役13b 体保真搬运）:PM 先试（[process_manager] 词根），
  // 拒则落回 agg 原径；双拒 = 两行合成错，exit 4。PM 产物单件
  // <name>_pm_gen.mbt（emit 闭包 / SnapshotStore 装配 = 消费方组合根，
  // 红线7 同源）。
  let pm_parsed = @gen.parse_mooncmd_pm(toml_text)
  let pm_msg = match pm_parsed {
    Ok(_) => ""
    Err(m) => m
  }
  if scaffold_mode != "" {
    match pm_parsed {
      Ok(pm_def) => return run_pm_scaffold(scaffold_mode, table_path, pm_def)
      Err(m) => {
        println(
          "cmd: 脚手架模式需 PM 表(\{scaffold_mode})——pm parse 拒:\{m}",
        )
        return 4
      }
    }
  }
  if pm_parsed is Ok(pm_def) {
    return run_pm_path(table_path, pm_def)
  }
  let def = match @gen.parse_mooncmd_agg(toml_text) {
    Ok(found) => found
    Err(msg) => {
      println("cmd: parse 拒:\{msg}")
      println("cmd: pm 拒(参考):\{pm_msg}")
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
  let gen_file = def.name + "_gen.mbt"
  let contract_file = def.name + "_contract_wbtest.mbt"
  let glue_file = def.name + "_glue.mbt"
  let policy_file = def.name + "_policy.mbt"
  let provenance = @gen.SchemaProvenance::{
    source_table: table_path,
    regen_command: "moonx thy1016/cmd@latest " + table_path,
    binder_path: "thy1016/cmd/gen(agg 方言 parse/validate/emit 三件套)",
  }
  @fs.write_file(
    dir + gen_file,
    @utf8.encode(@gen.emit_mooncmd_agg(def, provenance~)),
  )
  @fs.write_file(
    dir + contract_file,
    @utf8.encode(@gen.emit_mooncmd_agg_contract_tests(def)),
  )
  @fs.write_file(
    dir + glue_file,
    @utf8.encode(@gen.emit_mooncmd_agg_glue(def, provenance~)),
  )
  // serde 投影第五件（役10 键控:表 serde_json 开才落;与 skelschema/cmd
  // 驱动行为对齐——cmd 仓役13b 同步带上该发射器,路由随补）。
  if def.serde_json {
    @fs.write_file(
      dir + def.name + "_serde_gen.mbt",
      @utf8.encode(@gen.emit_mooncmd_agg_serde(def, provenance~)),
    )
  }
  let policy_absent = try {
    let _ = @fs.read_file(dir + policy_file).binary()
    false
  } catch {
    _ => true
  }
  if policy_absent {
    @fs.write_file(
      dir + policy_file,
      @utf8.encode(@gen.emit_mooncmd_agg_policy_stub(def)),
    )
  }
  let header_line = if dir == "" {
    "✓ \{def.name} 骨架四件"
  } else {
    "✓ \{def.name} 骨架四件 · \{dir}"
  }
  println(header_line)
  println("  \{gen_file}")
  println("  \{contract_file}")
  println("  \{glue_file}")
  let policy_mark = if policy_absent { "新落" } else { "保留" }
  println("  \{policy_file}    \{policy_mark}")
  if def.serde_json {
    println("  \{def.name}_serde_gen.mbt")
  }
  println("下一步")
  println("  1. 填裁决体 \{policy_file}")
  println(
    "  2. import thy1016/mooncmd/command + moonbitlang/core/encoding/utf8",
  )
  println("  3. moon test")
  return 0
}

///|
/// PM 径:parse 已过(validate 内建于 parse)→ 单件发射 → 汇报。
/// 产物 = <名>_pm_gen.mbt(状态/interested/saga_id/handle/apply/PM 面
/// 六段);emit 闭包与 SnapshotStore 装配 = 消费方组合根(红线7 同源)。
async fn run_pm_path(table_path : String, pm_def : @gen.MooncmdPmDef) -> Int32 {
  let dir = dir_prefix_of_table(table_path)
  let gen_file = pm_def.name + "_pm_gen.mbt"
  let provenance = @gen.SchemaProvenance::{
    source_table: table_path,
    regen_command: "moonx thy1016/cmd@latest " + table_path,
    binder_path: "thy1016/cmd/gen(pm 方言 parse/validate/emit 三件套)",
  }
  @fs.write_file(
    dir + gen_file,
    @utf8.encode(@gen.emit_mooncmd_pm(pm_def, provenance~)),
  )
  let header_line = if dir == "" {
    "✓ \{pm_def.name} PM 产物单件"
  } else {
    "✓ \{pm_def.name} PM 产物单件 · \{dir}"
  }
  println(header_line)
  println("  \{gen_file}")
  println("下一步(组合根装配;装配不在词表)")
  println(
    "  1. import thy1016/mooncmd + thy1016/mooncmd/event + thy1016/mooncmd/store",
  )
  println("  2. let pm = \{pm_def.name}_pm()")
  println(
    "  3. let runner = ProcessManagerRunner::new(pm, store, emit 闭包)(emit 形 (String, C) -> Unit raise ProcessManagerErr)",
  )
  println(
    "  4. runner.pump_events(events:Array[@event.EventMessage[String, E]])",
  )
  println("  5. moon test")
  return 0
}

///|
/// PM 脚手架径(装配样板/行为面 trait 带缺省体):单件发射落表同目录,
/// bootstrap-only .hand-maintained(实装体住用户件——红线9 编辑点)。
async fn run_pm_scaffold(
  mode : String,
  table_path : String,
  pm_def : @gen.MooncmdPmDef,
) -> Int32 {
  let dir = dir_prefix_of_table(table_path)
  let out_file = if mode == "--pm-assembly" {
    pm_def.name + "_pm_asm.mbt"
  } else {
    pm_def.name + "_pm_behavior.mbt"
  }
  let provenance = @gen.SchemaProvenance::{
    source_table: table_path,
    regen_command: "moonx thy1016/cmd@latest \{mode} " + table_path,
    binder_path: "thy1016/cmd/gen(pm 行为面/装配样板发射件)",
  }
  let text = if mode == "--pm-assembly" {
    @gen.emit_mooncmd_pm_assembly(pm_def, provenance~)
  } else {
    @gen.emit_mooncmd_pm_behavior(pm_def, provenance~)
  }
  @fs.write_file(dir + out_file, @utf8.encode(text))
  let header_line = if dir == "" {
    "✓ \{pm_def.name} PM 脚手架单件(bootstrap-only .hand-maintained)"
  } else {
    "✓ \{pm_def.name} PM 脚手架单件 · \{dir}\{out_file}"
  }
  println(header_line)
  println("下一步(实装体住本件;gen 件零手编)")
  if mode == "--pm-assembly" {
    println("  1. store 夹具换持久构造器(生产径)")
    println(
      "  2. emit 闭包 = 命令去向决策(必填显式——无缺省)",
    )
    println("  3. runner.pump_events(事件流)——泵序责任在调用方")
  } else {
    println(
      "  1. impl <Trait> for <Struct> with fn name(唯一必填;五缺省自动继承)",
    )
    println("  2. 差异槽覆写(interested/handle/apply 照业务)")
    println(
      "  3. declare impl 声明形勿用(编译过+运行时缺省不继承直落)",
    )
  }
  println("  moon test")
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
