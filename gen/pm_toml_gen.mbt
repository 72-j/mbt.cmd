// pm_toml_gen.mbt —— mooncmd Process Manager 方言（役13b 体保真搬运自
// 主仓 skelschema；ADR-MC-011 下半；宪法〇：一方言一文件，复用 agg 方言
// 同包 helpers：agg_word_ok / agg_variant_ok / AggFieldDef /
// agg_parse_field / agg_parse_evolve_op / agg_emit_apply_arm 形制）。
// 词表面 = <agg>_pm.toml 的 [process_manager] + [[process_manager.watch]]；
// 产物 = <name>_pm_gen.mbt（四回调记录面直通映射）。
// 分工判据（红线7）：字段直通 = gen 域；计算级映射 = stub zone 留手写
// （apply 拒 "..."）；runner 装配（emit 闭包 / SnapshotStore）= 组合根手写，
// 不进词表。

///|
/// PM 发射行（词表）：命令构造 + 参数映射（"cmd_field=event_field"，右值 =
/// 本 watch 行载荷字段直通——纯直通，字面量/算式不收）。
pub(all) struct PmEmitDef {
  command : String
  args : Array[String]
}

///|
/// PM watch 行（词表）：盯哪个事件（载荷全列 = 编译期漂移探测器）、发往
/// 目标（字面量 target XOR 载荷字段 target_field，恰一）、发射链、状态
/// 演化（封闭集同 agg 方言）。
pub(all) struct PmWatchDef {
  event : String
  fields : Array[AggFieldDef]
  target : String
  target_field : String
  emit : Array[PmEmitDef]
  apply : Array[String]
}

///|
/// Process Manager 词表根（表头三件 + 本体；event_type/command_type = 消费
/// 包既有枚举名，产物裸名引用不生成）。
pub(all) struct MooncmdPmDef {
  schema_version : String
  generator : String
  target_package : String
  name : String
  event_type : String
  command_type : String
  saga_key : String
  state_fields : Array[AggFieldDef]
  watch : Array[PmWatchDef]
}

///|
/// 发射行校验：命令 = 变体词形；参数 = "cmd_field=event_field" 双侧非空且
/// 右值 ∈ 本行载荷。
fn pm_emit_ok(
  emit : PmEmitDef,
  row : PmWatchDef,
  where_ : String,
) -> Result[Unit, String] {
  if !agg_variant_ok(emit.command) {
    return Err("\{where_}: bad command name \"\{emit.command}\"")
  }
  for arg in emit.args {
    let halves : Array[StringView] = arg.split("=").collect()
    if halves.length() != 2 {
      return Err(
        "\{where_}: bad arg \"\{arg}\" (want \"cmd_field=event_field\")",
      )
    }
    if halves[0].to_owned() == "" || halves[1].to_owned() == "" {
      return Err("\{where_}: bad arg \"\{arg}\" (empty side)")
    }
    let source = halves[1].to_owned()
    let mut found = false
    for field in row.fields {
      if field.name == source {
        found = true
      }
    }
    if !found {
      return Err(
        "\{where_}: arg source \"\{source}\" is not a payload field of \"\{row.event}\"",
      )
    }
  }
  Ok(())
}

///|
/// PM apply 指令校验：封闭集同 agg 方言（set|add|append|remove，经
/// agg_parse_evolve_op）；`...` 拒收——PM = 记录面直通映射，计算级演化 =
/// stub zone 留手写（红线7）。
fn pm_apply_ok(
  op_text : String,
  row : PmWatchDef,
  state_fields : Array[AggFieldDef],
  where_ : String,
) -> Result[Unit, String] {
  if op_text == "..." {
    return Err(
      "\{where_}: apply \"...\" not supported in pm dialect — 计算级映射 = stub zone 留手写（红线7）",
    )
  }
  agg_parse_evolve_op(op_text, row.fields, state_fields, where_)
}

///|
/// 字段引用判别：target_field / emit 参数右值 / apply operand（去 "-" 后非
/// true/false 字面）三面任一。
fn pm_field_referenced(name : String, row : PmWatchDef) -> Bool {
  if row.target_field == name {
    return true
  }
  for emit_row in row.emit {
    for arg in emit_row.args {
      let halves : Array[StringView] = arg.split("=").collect()
      if halves.length() == 2 && halves[1].to_owned() == name {
        return true
      }
    }
  }
  for op_text in row.apply {
    let halves : Array[StringView] = op_text.split("=").collect()
    if halves.length() == 2 {
      let operand = halves[1].to_owned()
      if !(operand is ("true" | "false")) {
        let chars = operand.to_array()
        let candidate = if chars[0] == '-' {
          operand[1:].to_owned()
        } else {
          operand
        }
        if candidate == name {
          return true
        }
      }
    }
  }
  false
}

///|
/// 校验（结构+词形+封闭集；错误前缀 mooncmd_pm 与 agg/retry 同款）。
pub fn validate_mooncmd_pm(def : MooncmdPmDef) -> Result[Unit, String] {
  if !agg_word_ok(def.name) {
    return Err("mooncmd_pm: bad pm name \"\{def.name}\"")
  }
  if !agg_variant_ok(def.event_type) {
    return Err("mooncmd_pm: bad event_type \"\{def.event_type}\"")
  }
  if !agg_variant_ok(def.command_type) {
    return Err("mooncmd_pm: bad command_type \"\{def.command_type}\"")
  }
  if def.state_fields.length() == 0 {
    return Err("mooncmd_pm: pm \"\{def.name}\" has no state fields")
  }
  for field in def.state_fields {
    if !agg_word_ok(field.name) {
      return Err("mooncmd_pm: bad state field name \"\{field.name}\"")
    }
  }
  if def.watch.length() == 0 {
    return Err("mooncmd_pm: pm \"\{def.name}\" has no watch rows")
  }
  // saga_key："aggregate_id"（信封槽）或每行载荷都有的 string 字段。
  if !(def.saga_key is "aggregate_id") {
    for row in def.watch {
      let mut found = false
      for field in row.fields {
        if field.name == def.saga_key {
          found = field.ty is "string"
        }
      }
      if !found {
        return Err(
          "mooncmd_pm: saga_key \"\{def.saga_key}\" missing (or non-string) in watch row \"\{row.event}\"",
        )
      }
    }
  }
  for row in def.watch {
    if !agg_variant_ok(row.event) {
      return Err("mooncmd_pm: bad watch event name \"\{row.event}\"")
    }
    for field in row.fields {
      if !agg_word_ok(field.name) {
        return Err("mooncmd_pm: bad watch field name \"\{field.name}\"")
      }
    }
    // 目标：字面量 XOR 载荷字段，恰一。
    if row.target != "" && row.target_field != "" {
      return Err(
        "mooncmd_pm: watch row \"\{row.event}\" sets both target and target_field",
      )
    }
    if row.target == "" && row.target_field == "" {
      return Err(
        "mooncmd_pm: watch row \"\{row.event}\" needs target or target_field",
      )
    }
    if row.target_field != "" {
      let mut found = false
      for field in row.fields {
        if field.name == row.target_field {
          found = true
        }
      }
      if !found {
        return Err(
          "mooncmd_pm: target_field \"\{row.target_field}\" is not a payload field of \"\{row.event}\"",
        )
      }
    }
    for emit_row in row.emit {
      let where_ = "mooncmd_pm: watch \"\{row.event}\" emit \"\{emit_row.command}\""
      let check = pm_emit_ok(emit_row, row, where_)
      match check {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
    }
    let where_apply = "mooncmd_pm: watch \"\{row.event}\""
    for op_text in row.apply {
      let check = pm_apply_ok(op_text, row, def.state_fields, where_apply)
      match check {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
    }
  }
  Ok(())
}

///|
/// 解析：<agg>_pm.toml → 词表（表头经 schema_header_field；本体 =
/// [process_manager] 根 + state 子表 + [[process_manager.watch]] 行）。
pub fn parse_mooncmd_pm(content : String) -> Result[MooncmdPmDef, String] {
  let root = match schema_toml_root(content) {
    Ok(table) => table
    Err(msg) => return Err(msg)
  }
  let pm = match root.get("process_manager") {
    Some(TomlTable(inner)) => inner
    Some(_) =>
      return Err("process_manager: key \"process_manager\" must be a table")
    None => return Err("process_manager: missing table \"process_manager\"")
  }
  let name = match schema_toml_string_req(pm, "name", "process_manager") {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let event_type = match
    schema_toml_string_req(pm, "event_type", "process_manager") {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let command_type = match
    schema_toml_string_req(pm, "command_type", "process_manager") {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let saga_key = match
    schema_toml_string_req(pm, "saga_key", "process_manager") {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let state_table = match
    schema_toml_table_opt(pm, "state", "process_manager") {
    Ok(table) => table
    Err(msg) => return Err(msg)
  }
  let state_fields : Array[AggFieldDef] = []
  match state_table {
    Some(table) =>
      match schema_toml_table_array(table, "fields", "process_manager.state") {
        Ok(rows) =>
          for index, row in rows {
            let field = match
              agg_parse_field(row, "process_manager.state[\{index}]") {
              Ok(value) => value
              Err(msg) => return Err(msg)
            }
            state_fields.push(field)
          }
        Err(msg) => return Err(msg)
      }
    None => ()
  }
  let watch : Array[PmWatchDef] = []
  let watch_rows = match
    schema_toml_table_array(pm, "watch", "process_manager") {
    Ok(rows) => rows
    Err(msg) => return Err(msg)
  }
  for index, row in watch_rows {
    let where_ = "process_manager.watch[\{index}]"
    let event = match schema_toml_string_req(row, "event", where_) {
      Ok(value) => value
      Err(msg) => return Err(msg)
    }
    let fields : Array[AggFieldDef] = []
    match schema_toml_table_array(row, "fields", "\{where_}.fields") {
      Ok(rows2) =>
        for index2, row2 in rows2 {
          let field = match
            agg_parse_field(row2, "\{where_}.fields[\{index2}]") {
            Ok(value) => value
            Err(msg) => return Err(msg)
          }
          fields.push(field)
        }
      Err(msg) => return Err(msg)
    }
    let target = match schema_toml_string_or(row, "target", "", where_) {
      Ok(value) => value
      Err(msg) => return Err(msg)
    }
    let target_field = match
      schema_toml_string_or(row, "target_field", "", where_) {
      Ok(value) => value
      Err(msg) => return Err(msg)
    }
    let emit : Array[PmEmitDef] = []
    match schema_toml_table_array(row, "emit", "\{where_}.emit") {
      Ok(rows2) =>
        for index2, row2 in rows2 {
          let where_emit = "\{where_}.emit[\{index2}]"
          let command = match
            schema_toml_string_req(row2, "command", where_emit) {
            Ok(value) => value
            Err(msg) => return Err(msg)
          }
          let args = match schema_toml_string_array(row2, "args", where_emit) {
            Ok(value) => value
            Err(msg) => return Err(msg)
          }
          emit.push({ command, args, })
        }
      Err(msg) => return Err(msg)
    }
    let apply = match schema_toml_string_array(row, "apply", where_) {
      Ok(value) => value
      Err(msg) => return Err(msg)
    }
    watch.push({ event, fields, target, target_field, emit, apply, })
  }
  let def = MooncmdPmDef::{
    schema_version: schema_header_field(root, "schema_version"),
    generator: schema_header_field(root, "generator"),
    target_package: schema_header_field(root, "target_package"),
    name,
    event_type,
    command_type,
    saga_key,
    state_fields,
    watch,
  }
  match validate_mooncmd_pm(def) {
    Ok(_) => Ok(def)
    Err(msg) => Err(msg)
  }
}

///|
/// 拆包 binder 段：被引用字段 = 裸名，未引用 = `_`（模式占位——全载荷
/// arity 保持，未用槽不吃 unused 告警）。
fn pm_emit_unpack(fields : Array[AggFieldDef], row : PmWatchDef) -> String {
  let parts : Array[String] = []
  for field in fields {
    let used = pm_field_referenced(field.name, row)
    parts.push(if used { field.name } else { "_" })
  }
  agg_join(parts, ", ")
}

///|
/// handle 回调臂：emit 行直通构造（目标字面量加引号 / target_field 裸名；
/// 命令 = 变体名+参数位置直通，零参 = 裸构造器）；臂行 ≤80 收单行，超宽 =
/// fmt 正典折臂体形（臂体整体落下一行 6 空格，不拆括号）。
fn pm_emit_handle_arm(sb : StringBuilder, row : PmWatchDef) -> Unit {
  let unpack = pm_emit_unpack(row.fields, row)
  let head = if unpack == "" {
    "    \{row.event}"
  } else {
    "    \{row.event}(\{unpack})"
  }
  let prefix = "\{head} => "
  if row.emit.length() == 0 {
    sb <+ "\{prefix}[]\n"
    return
  }
  let rows : Array[String] = []
  for emit_row in row.emit {
    let target_expr = if row.target != "" {
      "\"\{row.target}\""
    } else {
      row.target_field
    }
    let args : Array[String] = []
    for arg in emit_row.args {
      let halves : Array[StringView] = arg.split("=").collect()
      if halves.length() == 2 {
        args.push(halves[1].to_owned())
      }
    }
    let ctor = if args.length() == 0 {
      emit_row.command
    } else {
      "\{emit_row.command}(\{agg_join(args, ", ")})"
    }
    rows.push("{ target_aggregate_id: \{target_expr}, command: \{ctor}, }")
  }
  let joined = agg_join(rows, ", ")
  if prefix.length() + joined.length() + 2 <= 80 {
    sb <+ "\{prefix}[\{joined}]\n"
  } else {
    sb <+ "\{head} =>\n"
    sb <+ "      [\{joined}]\n"
  }
}

///|
/// apply 回调臂：演化封闭集与 agg 方言同源（set/add/append/remove，
/// punning / "-" 取负同款）；零指令 = 透传 state。
fn pm_emit_apply_arm(sb : StringBuilder, row : PmWatchDef) -> Unit {
  let unpack = pm_emit_unpack(row.fields, row)
  if row.apply.length() == 0 {
    if unpack == "" {
      sb <+ "    \{row.event} => state\n"
    } else {
      sb <+ "    \{row.event}(\{unpack}) => state\n"
    }
    return
  }
  if unpack == "" {
    sb <+ "    \{row.event} => {\n"
  } else {
    sb <+ "    \{row.event}(\{unpack}) => {\n"
  }
  let mut chain = "state"
  let mut step = 0
  for op_text in row.apply {
    let parts : Array[StringView] = op_text.split(" ").collect()
    let op = parts[0].to_owned()
    let halves : Array[StringView] = parts[1].split("=").collect()
    let target = halves[0].to_owned()
    let operand = halves[1].to_owned()
    let chars = operand.to_array()
    let negated = chars[0] == '-'
    let value = if negated { operand[1:].to_owned() } else { operand }
    let var_name = chain
    let next_name = "s\{step}"
    if op == "set" {
      // 字段名与值同名标识符 → punning（发射器铁律：emit ≡ fmt）。
      if target == value {
        sb <+ "      let \{next_name} = { ..\{var_name}, \{target}, }\n"
      } else {
        sb <+
          "      let \{next_name} = { ..\{var_name}, \{target}: \{value}, }\n"
      }
    } else if op == "add" {
      let sign = if negated { "-" } else { "+" }
      sb <+
        "      let \{next_name} = { ..\{var_name}, \{target}: \{var_name}.\{target} \{sign} \{value}, }\n"
    } else if op == "append" {
      sb <+
        "      let \{next_name} = { ..\{var_name}, \{target}: \{var_name}.\{target} + [\{value}] }\n"
    } else {
      // remove:同 agg 方言占位形（list 类型扩集时启用）。
      sb <+ "      let \{next_name} = { ..\{var_name}, \{target}: fn go(\n"
      sb <+ "        list : Array[@nothing],\n"
      sb <+ "      ) -> Array[@nothing] { list }( []) }\n"
    }
    chain = next_name
    step = step + 1
  }
  sb <+ "      \{chain}\n"
  sb <+ "    }\n"
}

///|
/// PM 方言发射：<name>_pm_gen.mbt 产物体（状态结构 + \{name}_pm() 记录面
/// 构造器；三类型槽 = 消费包既有型裸名引用，@mooncmd = 框架根包）。
pub fn emit_mooncmd_pm(
  def : MooncmdPmDef,
  provenance~ : SchemaProvenance,
) -> String {
  let sb = StringBuilder()
  let state_type = schema_upper_first(def.name) + "PmState"
  schema_emit_header(
    sb,
    provenance,
    def.schema_version,
    "// Process Manager 方言：事件→命令字段直通映射（interested 封闭集 / handle 字段直通 / apply 机械演化，封闭集 = agg 方言同源 set|add|append|remove）；计算级映射 = stub zone 留手写（红线7），runner 装配（emit 闭包 / SnapshotStore）= 组合根手写。",
  )
  sb <+ "\n"
  sb <+ "///|\n"
  sb <+ "/// \{state_type}——\{def.name} PM 状态（saga 实例态）。\n"
  sb <+ "pub(all) struct \{state_type} {\n"
  for field in def.state_fields {
    sb <+ "  \{field.name} : \{agg_moonbit_type(field.ty)}\n"
  }
  sb <+ "}\n"
  sb <+ "\n"
  sb <+ "///|\n"
  sb <+ "/// 零值态（init 契约：字段缺省值直通）。\n"
  sb <+ "pub fn \{state_type}::init() -> \{state_type} {\n"
  sb <+ "  { "
  let inits : Array[String] = []
  for field in def.state_fields {
    inits.push("\{field.name}: \{field.init}")
  }
  sb <+ "\{agg_join(inits, ", ")}, }\n"
  sb <+ "}\n"
  // 四回调 = 具名顶层 fn（记录字面量内 lambda 臂双语句 = 解析雷；具名
  // fn 体 = agg 方言同款正典形）。
  sb <+ "\n"
  sb <+ "///|\n"
  sb <+
    "/// interested——watch 行封闭集（子集匹配，未列事件 = 不相关）。\n"
  sb <+ "pub fn \{def.name}_pm_interested(e : \{def.event_type}) -> Bool {\n"
  sb <+ "  match e {\n"
  for row in def.watch {
    if row.fields.length() == 0 {
      sb <+ "    \{row.event} => true\n"
    } else {
      sb <+ "    \{row.event}(_) => true\n"
    }
  }
  sb <+ "    _ => false\n"
  sb <+ "  }\n"
  sb <+ "}\n"
  sb <+ "\n"
  sb <+ "///|\n"
  sb <+
    "/// saga_id_of——saga 分片键（信封 aggregate_id 直读）。\n"
  if def.saga_key is "aggregate_id" {
    sb <+ "pub fn \{def.name}_pm_saga_id_of(\n"
    sb <+ "  msg : @event.EventMessage[String, \{def.event_type}],\n"
    sb <+ ") -> String {\n"
    sb <+ "  msg.aggregate_id\n"
    sb <+ "}\n"
  } else {
    sb <+ "pub fn \{def.name}_pm_saga_id_of(\n"
    sb <+ "  msg : @event.EventMessage[String, \{def.event_type}],\n"
    sb <+ ") -> String {\n"
    sb <+ "  match msg.event {\n"
    for row in def.watch {
      let parts : Array[String] = []
      for field in row.fields {
        parts.push(if field.name == def.saga_key { field.name } else { "_" })
      }
      let unpack = agg_join(parts, ", ")
      if unpack == "" {
        // 不可达（校验拒零载荷 saga 行）——封闭形补全。
        sb <+ "    \{row.event} => \"\"\n"
      } else {
        sb <+ "    \{row.event}(\{unpack}) => \{def.saga_key}\n"
      }
    }
    sb <+ "    _ => \"\"\n"
    sb <+ "  }\n"
    sb <+ "}\n"
  }
  sb <+ "\n"
  sb <+ "///|\n"
  sb <+
    "/// handle——事件→命令直通映射（未列事件 = 空发射）。\n"
  sb <+ "pub fn \{def.name}_pm_handle(\n"
  sb <+ "  _state : \{state_type},\n"
  sb <+ "  e : \{def.event_type},\n"
  sb <+ ") -> Array[@mooncmd.DirectedCommand[\{def.command_type}]] {\n"
  sb <+ "  match e {\n"
  for row in def.watch {
    pm_emit_handle_arm(sb, row)
  }
  sb <+ "    _ => []\n"
  sb <+ "  }\n"
  sb <+ "}\n"
  sb <+ "\n"
  sb <+ "///|\n"
  sb <+
    "/// apply——状态机械演化（封闭集同 agg 方言；未列事件 = 透传）。\n"
  sb <+ "pub fn \{def.name}_pm_apply(\n"
  sb <+ "  state : \{state_type},\n"
  sb <+ "  e : \{def.event_type},\n"
  sb <+ ") -> \{state_type} {\n"
  sb <+ "  match e {\n"
  for row in def.watch {
    pm_emit_apply_arm(sb, row)
  }
  sb <+ "    _ => state\n"
  sb <+ "  }\n"
  sb <+ "}\n"
  sb <+ "\n"
  sb <+ "///|\n"
  sb <+
    "/// \{def.name}_pm——Process Manager 记录面（事件→命令跨聚合编排；\n"
  sb <+
    "/// 词表驱动直通映射；命令发射闭包由组合根注入）。\n"
  // 签名行 >80 = fmt 正典泛型逐参折行（阈值带黄金门自显）。
  let sig_line = "pub fn \{def.name}_pm() -> @mooncmd.ProcessManager[\{state_type}, \{def.command_type}, \{def.event_type}] {"
  if sig_line.length() <= 80 {
    sb <+ "\{sig_line}\n"
  } else {
    sb <+ "pub fn \{def.name}_pm() -> @mooncmd.ProcessManager[\n"
    sb <+ "  \{state_type},\n"
    sb <+ "  \{def.command_type},\n"
    sb <+ "  \{def.event_type},\n"
    sb <+ "] {\n"
  }
  sb <+ "  {\n"
  sb <+ "    name: \"\{def.name}\",\n"
  sb <+ "    init_state: \{state_type}::init,\n"
  sb <+ "    interested: \{def.name}_pm_interested,\n"
  sb <+ "    saga_id_of: \{def.name}_pm_saga_id_of,\n"
  sb <+ "    handle: \{def.name}_pm_handle,\n"
  sb <+ "    apply: \{def.name}_pm_apply,\n"
  sb <+ "  }\n"
  sb <+ "}\n"
  sb.to_string()
}
