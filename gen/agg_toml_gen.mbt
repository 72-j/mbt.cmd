///|
/// cmd/gen agg 方言发射器:抽自主仓 skelschema/mooncmd_agg_toml_gen.mbt
/// 体保真搬运(役13b 漂移补齐 2026-11-14——上轮快照缺 declare 槽位+
/// 钩子工厂尾段,golden 哨兵红灯驱动同步)。治理①变更单向律——本件
/// 只跟随搬运,能力变更先落主仓。
/// `mooncmd` 聚合词表方言（役7 D-MG;第十二方言）——`<agg>_agg.toml` 定义集：
/// [aggregate]（词根/id 域）+ [aggregate.state] 字段（形状区+init 值区）+
/// [[aggregate.events]] 事件（字段+演化指令）+ [[aggregate.commands]] 命令词形。
/// 分工判据（宪法 §1 同源;mooncmd const.md 红线7-9 护栏）:gen 产**类型/apply/
/// 分派骨架**（形状与机械演化）,**裁决 = 策略件手写钩子**（红线7 裁决不入表;
/// 演化指令集封闭 set/add/append/remove——红线8,scope 门把封闭集外指令判红）。
/// 产物 = 消费包 `<agg>_gen.mbt`:state struct + init + 事件/命令枚举（标签
/// 载荷）+ apply（evolve 指令逐条链式,同字段后写覆前写）+ DecideHooks 记录
/// + decide 分派（载荷拆包后直调钩子）。词表封闭:类型 string/int/bool;
/// id 词形安全检查(保留字族)。

///|
/// `mooncmd` 保留字族（词根/字段名安全检查;AGENTS 坑账汇总）。
fn agg_reserved_words() -> Array[String] {
  [
    "is", "impl", "derive", "priv", "method", "type", "local", "module", "guard",
    "match", "let", "fn", "if", "else", "while", "for", "in", "return", "break",
    "continue", "struct", "enum", "trait", "pub", "const", "test", "using", "mut",
    "async", "alias", "self",
  ]
}

///|
/// 词形:[a-z][a-z0-9_]*、非保留字。
fn agg_word_ok(word : String) -> Bool {
  if word == "" || agg_reserved_words().contains(word) {
    return false
  }
  let chars = word.to_array()
  let first = chars[0]
  if !(first >= 'a' && first <= 'z') {
    return false
  }
  for index, char in chars {
    if index > 0 {
      let lower = char >= 'a' && char <= 'z'
      let digit = char >= '0' && char <= '9'
      let underscore = char == '_'
      if !(lower || digit || underscore) {
        return false
      }
    }
  }
  true
}

///|
/// 变体词形(事件/命令名):[A-Z][A-Za-z0-9]*、非保留字。
fn agg_variant_ok(word : String) -> Bool {
  if word == "" || agg_reserved_words().contains(word) {
    return false
  }
  let chars = word.to_array()
  let first = chars[0]
  if !(first >= 'A' && first <= 'Z') {
    return false
  }
  for index, char in chars {
    if index > 0 {
      let lower = char >= 'a' && char <= 'z'
      let upper = char >= 'A' && char <= 'Z'
      let digit = char >= '0' && char <= '9'
      if !(lower || upper || digit) {
        return false
      }
    }
  }
  true
}

///|
/// 字段定义（state 字段带 init 值区;事件/命令载荷字段无 init）。
pub(all) struct AggFieldDef {
  name : String
  ty : String
  init : String
}

///|
/// 事件定义:fields = 载荷;evolve = 演化指令原文（封闭集校验在 validate）。
pub(all) struct AggEventDef {
  name : String
  fields : Array[AggFieldDef]
  evolve : Array[String]
}

///|
/// 命令定义:fields = 载荷;裁决体 = 钩子（红线7,不入表）。
pub(all) struct AggCommandDef {
  name : String
  fields : Array[AggFieldDef]
}

///|
pub(all) struct MooncmdAggDef {
  schema_version : String
  generator : String
  target_package : String
  name : String
  id : String
  state_fields : Array[AggFieldDef]
  events : Array[AggEventDef]
  commands : Array[AggCommandDef]
  /// 役10 serde 键控：[aggregate.serde] json=true 时发射
  /// `<name>_serde_gen.mbt`（serde wire 投影）;缺席 = false = 零发射
  /// （旧表字节稳——四刀律①可选键缺省即旧形）。
  serde_json : Bool
}

///|
/// 类型封闭集（红线8 同族;扩类型 = 词表拍改）。
fn agg_type_ok(ty : String) -> Bool {
  ty is ("string" | "int" | "bool")
}

///|
/// MoonBit 型映射。
fn agg_moonbit_type(ty : String) -> String {
  match ty {
    "string" => "String"
    "int" => "Int32"
    _ => "Bool"
  }
}

///|
/// init 值缺省（值区缺项时按类型给零值;moonbit 字面形）。
fn agg_init_default(ty : String) -> String {
  match ty {
    "string" => "\"\""
    "int" => "0"
    _ => "true"
  }
}

///|
fn agg_parse_field(
  row : Map[String, @toml.TomlValue],
  where_ : String,
) -> Result[AggFieldDef, String] {
  let name = match schema_toml_string_req(row, "name", where_) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  if !agg_word_ok(name) {
    return Err("\{where_}: bad field name \"\{name}\"")
  }
  let ty = match schema_toml_string_req(row, "type", where_) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  if !agg_type_ok(ty) {
    return Err("\{where_}: type \"\{ty}\" outside closed set (string|int|bool)")
  }
  let init = match
    schema_toml_string_or(row, "init", agg_init_default(ty), where_) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  Ok({ name, ty, init, })
}

///|
/// 演化指令解析:"<op> <field>=<operand>" → (op, state_field, operand)。
fn agg_parse_evolve_op(
  op_text : String,
  event_fields : Array[AggFieldDef],
  state_fields : Array[AggFieldDef],
  where_ : String,
) -> Result[Unit, String] {
  let parts : Array[StringView] = op_text.split(" ").collect()
  if parts.length() != 2 {
    return Err(
      "\{where_}: bad op \"\{op_text}\" (want \"<op> <field>=<operand>\")",
    )
  }
  let op = parts[0].to_owned()
  if !(op is ("set" | "add" | "append" | "remove")) {
    return Err(
      "\{where_}: op \"\{op}\" outside closed set (set|add|append|remove) — 红线8",
    )
  }
  let halves : Array[StringView] = parts[1].split("=").collect()
  if halves.length() != 2 {
    return Err(
      "\{where_}: bad assignment \"\{op_text}\" (want \"<field>=<operand>\")",
    )
  }
  let state_field = halves[0].to_owned()
  let mut known = false
  for field in state_fields {
    if field.name == state_field {
      known = true
    }
  }
  if !known {
    return Err("\{where_}: unknown state field \"\{state_field}\"")
  }
  // operand:事件载荷字段引用(可 "-" 前缀取负)或字面量(true/false/整数)
  let operand = halves[1].to_owned()
  if !(operand is ("true" | "false")) {
    let chars = operand.to_array()
    let candidate = if chars[0] == '-' {
      operand[1:].to_owned()
    } else {
      operand
    }
    let mut found = false
    for field in event_fields {
      if field.name == candidate {
        found = true
      }
    }
    if !found {
      return Err(
        "\{where_}: operand \"\{operand}\" is not an event payload field",
      )
    }
  }
  Ok(())
}

///|
/// 校验（结构+词形+封闭集）。
pub fn validate_mooncmd_agg(def : MooncmdAggDef) -> Result[Unit, String] {
  if !agg_word_ok(def.name) {
    return Err("mooncmd_agg: bad aggregate name \"\{def.name}\"")
  }
  if !(def.id is "string") {
    return Err(
      "mooncmd_agg: id domain \"\{def.id}\" outside closed set (string)",
    )
  }
  if def.state_fields.length() == 0 {
    return Err("mooncmd_agg: aggregate \"\{def.name}\" has no state fields")
  }
  if def.events.length() == 0 {
    return Err("mooncmd_agg: aggregate \"\{def.name}\" has no events")
  }
  if def.commands.length() == 0 {
    return Err("mooncmd_agg: aggregate \"\{def.name}\" has no commands")
  }
  for event in def.events {
    if !agg_variant_ok(event.name) {
      return Err("mooncmd_agg: bad event name \"\{event.name}\"")
    }
    for field in event.fields {
      if !agg_word_ok(field.name) {
        return Err("mooncmd_agg: bad event field name \"\{field.name}\"")
      }
    }
    // `...` 整件委托（演化手写域）:唯一元才合法——混合 = 偷渡偏序语义（红线8 扩条）
    let delegated = agg_event_hook_delegated(event)
    let mut has_ellipsis = delegated
    for op_text in event.evolve {
      if op_text == "..." {
        has_ellipsis = true
        break
      }
    }
    if has_ellipsis && !delegated {
      return Err(
        "mooncmd_agg: event \"\{event.name}\" evolve mixes \"...\" with mechanical ops — 整件委托须唯一元（红线8 扩条）",
      )
    }
    if delegated {
      continue
    }
    for op_text in event.evolve {
      match
        agg_parse_evolve_op(op_text, event.fields, def.state_fields, event.name) {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
    }
  }
  for command in def.commands {
    if !agg_variant_ok(command.name) {
      return Err("mooncmd_agg: bad command name \"\{command.name}\"")
    }
    for field in command.fields {
      if !agg_word_ok(field.name) {
        return Err("mooncmd_agg: bad command field name \"\{field.name}\"")
      }
    }
  }
  Ok(())
}

///|
/// 解析 `account_agg.toml` 一类聚合词表:结构绑定（未知键忽略,向前兼容）。
pub fn parse_mooncmd_agg(content : String) -> Result[MooncmdAggDef, String] {
  let table = match schema_toml_root(content) {
    Ok(table) => table
    Err(msg) => return Err("mooncmd_agg: \{msg}")
  }
  let aggregate = match table.get("aggregate") {
    Some(TomlTable(inner)) => inner
    _ => return Err("mooncmd_agg: missing [aggregate] table")
  }
  // [aggregate.state] 是单表(非 [[array]]):从 aggregate 内取 state 子表
  let state_table : Map[String, @toml.TomlValue] = match
    aggregate.get("state") {
    Some(TomlTable(inner)) => inner
    _ => return Err("mooncmd_agg: missing [aggregate.state] table")
  }
  let state_field_rows = match
    schema_toml_table_array(state_table, "fields", "aggregate.state") {
    Ok(value) => value
    Err(msg) => return Err("mooncmd_agg: \{msg}")
  }
  if state_field_rows.length() == 0 {
    return Err("mooncmd_agg: aggregate.state has no fields")
  }
  let state_fields : Array[AggFieldDef] = []
  let mut index = 0
  for row in state_field_rows {
    match agg_parse_field(row, "state.fields[\{index}]") {
      Ok(value) => state_fields.push(value)
      Err(msg) => return Err("mooncmd_agg: \{msg}")
    }
    index = index + 1
  }
  let event_rows = match
    schema_toml_table_array(aggregate, "events", "aggregate") {
    Ok(value) => value
    Err(msg) => return Err("mooncmd_agg: \{msg}")
  }
  let events : Array[AggEventDef] = []
  let mut index = 0
  for row in event_rows {
    let name = match schema_toml_string_req(row, "name", "events[\{index}]") {
      Ok(value) => value
      Err(msg) => return Err("mooncmd_agg: \{msg}")
    }
    let field_rows = match
      schema_toml_table_array(row, "fields", "events[\{index}]") {
      Ok(value) => value
      Err(msg) => return Err("mooncmd_agg: \{msg}")
    }
    let fields : Array[AggFieldDef] = []
    let mut findex = 0
    for field_row in field_rows {
      match agg_parse_field(field_row, "events[\{index}].fields[\{findex}]") {
        Ok(value) => fields.push(value)
        Err(msg) => return Err("mooncmd_agg: \{msg}")
      }
      findex = findex + 1
    }
    let evolve = match
      schema_toml_string_array(row, "evolve", "events[\{index}]") {
      Ok(value) => value
      Err(msg) => return Err("mooncmd_agg: \{msg}")
    }
    events.push({ name, fields, evolve, })
    index = index + 1
  }
  let command_rows = match
    schema_toml_table_array(aggregate, "commands", "aggregate") {
    Ok(value) => value
    Err(msg) => return Err("mooncmd_agg: \{msg}")
  }
  let commands : Array[AggCommandDef] = []
  let mut index = 0
  for row in command_rows {
    let name = match schema_toml_string_req(row, "name", "commands[\{index}]") {
      Ok(value) => value
      Err(msg) => return Err("mooncmd_agg: \{msg}")
    }
    let field_rows = match
      schema_toml_table_array(row, "fields", "commands[\{index}]") {
      Ok(value) => value
      Err(msg) => return Err("mooncmd_agg: \{msg}")
    }
    let fields : Array[AggFieldDef] = []
    let mut findex = 0
    for field_row in field_rows {
      match agg_parse_field(field_row, "commands[\{index}].fields[\{findex}]") {
        Ok(value) => fields.push(value)
        Err(msg) => return Err("mooncmd_agg: \{msg}")
      }
      findex = findex + 1
    }
    commands.push({ name, fields, })
    index = index + 1
  }
  let name = match
    schema_toml_string_or(aggregate, "name", "account", "aggregate") {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let id = match schema_toml_string_or(aggregate, "id", "string", "aggregate") {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  // [aggregate.serde] 可选键（役10 四刀律②双构造点：缺席 = false = 零发射;
  // 键在而值坏 = Err——键在即严格,缺席才缺省）
  let serde_json : Bool = match aggregate.get("serde") {
    Some(TomlTable(inner)) =>
      match inner.get("json") {
        Some(TomlBoolean(value)) => value
        Some(_) =>
          return Err("mooncmd_agg: [aggregate.serde] json must be a boolean")
        None => return Err("mooncmd_agg: [aggregate.serde] missing json key")
      }
    Some(_) => return Err("mooncmd_agg: [aggregate.serde] must be a table")
    None => false
  }
  let def = MooncmdAggDef::{
    schema_version: schema_header_field(table, "schema_version"),
    generator: schema_header_field(table, "generator"),
    target_package: schema_header_field(table, "target_package"),
    name,
    id,
    state_fields,
    events,
    commands,
    serde_json,
  }
  match validate_mooncmd_agg(def) {
    Ok(_) => Ok(def)
    Err(msg) => Err(msg)
  }
}

///|
/// 串接（sep 分隔;StringBuilder 手写——core 无 interleave）。
fn agg_join(parts : Array[String], sep : String) -> String {
  let out = StringBuilder()
  let mut first = true
  for part in parts {
    if !first {
      out.write_string(sep)
    }
    out.write_string(part)
    first = false
  }
  out.to_string()
}

///|
/// 字段序列 → 枚举载荷段（标签形:`name~ : T`;空 = 空串）。
fn agg_emit_payload(fields : Array[AggFieldDef]) -> String {
  let parts : Array[String] = []
  for field in fields {
    parts.push(agg_moonbit_type(field.ty))
  }
  agg_join(parts, ", ")
}

///|
/// 载荷拆包段（模式侧punning:`name~, initial~`;无字段 = 空串）。
fn agg_emit_unpack(fields : Array[AggFieldDef]) -> String {
  let parts : Array[String] = []
  for field in fields {
    parts.push(field.name)
  }
  agg_join(parts, ", ")
}

///|
/// 蛇形（CreateAccount → create_account;钩子字段名）。
fn agg_snake(word : String) -> String {
  let out = StringBuilder()
  let chars = word.to_array()
  for index, char in chars {
    if index > 0 && char >= 'A' && char <= 'Z' {
      out.write_char('_')
    }
    out.write_char(
      if char >= 'A' && char <= 'Z' {
        // 大写→小写 = ASCII 偏移 32(safe 形;域已由大写分支守卫,失败回退原字符)
        match (char.to_int() + 32).to_char() {
          Some(lower) => lower
          None => char
        }
      } else {
        char
      },
    )
  }
  out.to_string()
}

///|
/// 整件委托判别（`...` 钩子委托）:evolve = ["..."] 唯一元 = 该事件演化
/// 属手写域（表内明示边界）——gen 只产臂形与钩子记录,演化体 = policy 件。
fn agg_event_hook_delegated(event : AggEventDef) -> Bool {
  event.evolve.length() == 1 && event.evolve[0] == "..."
}

///|
/// 表内 `...` 委托事件存在判别（表驱动 apply 签名:含委托事件 → 双参
/// hooks;全机械表单参——bank 旧形字节稳）。
fn agg_has_hook_delegated(events : Array[AggEventDef]) -> Bool {
  let mut found = false
  for event in events {
    if agg_event_hook_delegated(event) {
      found = true
    }
  }
  found
}

///|
/// 演化指令链发射:每指令一条 let（s0/s1/…链式,同字段后写覆前写）;
/// operand = 载荷引用（punning 变量; "-" 前缀取负）或字面量;
/// 委托事件（`...` 或 evolve 留空骨架位）= 钩子记录字段直调臂（载荷
/// 拆包全量透传;实装 = policy 件槽闭包）。
fn agg_emit_apply_arm(sb : StringBuilder, event : AggEventDef) -> Unit {
  if agg_event_hook_delegated(event) {
    let hook_field = agg_snake(event.name)
    let names : Array[String] = ["state"]
    for field in event.fields {
      names.push(field.name)
    }
    let call_args = agg_join(names, ", ")
    let unpack = agg_emit_unpack(event.fields)
    // 判宽:单行 >80 折 `=>` 续行形(fmt 实测正典——invoice 长臂案校准)
    let line = if unpack == "" {
      "    \{event.name} => (hooks.\{hook_field})(\{call_args})"
    } else {
      "    \{event.name}(\{unpack}) => (hooks.\{hook_field})(\{call_args})"
    }
    if line.length() > 80 {
      if unpack == "" {
        sb <+ "    \{event.name} =>\n"
      } else {
        sb <+ "    \{event.name}(\{unpack}) =>\n"
      }
      sb <+ "      (hooks.\{hook_field})(\{call_args})\n"
    } else {
      sb <+ "\{line}\n"
    }
    return
  }
  let unpack = agg_emit_unpack(event.fields)
  if event.evolve.length() == 0 {
    sb <+ "    \{event.name} => state\n"
    return
  }
  if unpack == "" {
    sb <+ "    \{event.name} => {\n"
  } else {
    sb <+ "    \{event.name}(\{unpack}) => {\n"
  }
  let mut chain = "state"
  let mut step = 0
  for op_text in event.evolve {
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
      // 新 fmt 正典：字段名与值同名标识符 → punning（发射器铁律：emit ≡ fmt）
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
      // remove:列表按值滤除（封闭集第四件;list 字段类型扩集时启用）
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
/// 钩子槽位名（聚合根前缀 + 蛇形词——`account_create_account` 形;
/// 用户拍 2026-11-13:名字带表前缀,聚合根前缀）。
fn agg_hook_slot_name(def_name : String, word : String) -> String {
  "\{def_name}_\{agg_snake(word)}"
}

///|
/// 裁决槽位 declare 行发射（Result 型:头部 ≤80 单行,超宽折 Result 载荷
/// 2 空格续行+`]` 落 0 列——fmt 正典探针 2026-11-13 二轮,顶层形）。
fn agg_emit_declare_result(
  sb : StringBuilder,
  slot : String,
  param_types : Array[String],
  event_type : String,
) -> Unit {
  let params = "(\{agg_join(param_types, ", ")})"
  let head = "declare pub let \{slot} : \{params} -> Result[Array[\{event_type}], String]"
  if head.length() <= 80 {
    sb <+ "\{head}\n"
  } else {
    sb <+
      "declare pub let \{slot} : \{params} -> Result[\n  Array[\{event_type}],\n  String,\n]\n"
  }
}

///|
/// 演化槽位 declare 行发射（plain 型:≤94 单行——fmt 实测 92 字符并行行、
/// 116 折参数（2026-11-13 探针）,超宽折参数逐行）。
fn agg_emit_declare_plain(
  sb : StringBuilder,
  slot : String,
  param_types : Array[String],
  state_type : String,
) -> Unit {
  let one_line = "declare pub let \{slot} : (\{agg_join(param_types, ", ")}) -> \{state_type}"
  if one_line.length() <= 94 {
    sb <+ "\{one_line}\n"
  } else {
    sb <+ "declare pub let \{slot} : (\n"
    for ty in param_types {
      sb <+ "  \{ty},\n"
    }
    sb <+ ") -> \{state_type}\n"
  }
}

///|
/// 钩子工厂发射（机械映射:记录字段 → policy 槽位值——表加命令 regen 自动扩,
/// 用户只补槽体;记录体 ≤80 单行,超宽逐字段——fmt 正典探针 2026-11-13）。
fn agg_emit_hooks_factory(
  sb : StringBuilder,
  factory_name : String,
  hooks_type : String,
  mappings : Array[String],
) -> Unit {
  sb <+ "\n///|\n"
  sb <+
    "/// 钩子工厂（机械映射——裁决/演化体 = policy 件槽位闭包,红线7）\n"
  sb <+ "pub fn \{factory_name}() -> \{hooks_type} {\n"
  if mappings.length() == 0 {
    // 空 struct 字面 `{}` 在返回位置解析为空 Map（坑账 [0022] 族）——全形收口
    sb <+ "  \{hooks_type}::{}\n"
  } else {
    let one_line = "  { \{agg_join(mappings, ", ")}, }"
    if one_line.length() <= 80 {
      sb <+ "\{one_line}\n"
    } else {
      sb <+ "  {\n"
      for m in mappings {
        sb <+ "    \{m},\n"
      }
      sb <+ "  }\n"
    }
  }
  sb <+ "}\n"
}

///|
/// 产物发射（byte-stable:遍历序 = 表序,零时间戳零哈希）。
pub fn emit_mooncmd_agg(
  def : MooncmdAggDef,
  provenance~ : SchemaProvenance,
) -> String {
  let sb = StringBuilder()
  let state_type = schema_upper_first(def.name) + "State"
  let event_type = schema_upper_first(def.name) + "Event"
  let command_type = schema_upper_first(def.name) + "Command"
  let hooks_type = schema_upper_first(def.name) + "DecideHooks"
  let hooks_evolve_type = schema_upper_first(def.name) + "EvolveHooks"
  let has_hooks = agg_has_hook_delegated(def.events)
  schema_emit_header(
    sb,
    provenance,
    def.schema_version,
    "// 聚合方言:gen 骨架+机械演化,裁决 = 策略件手写钩子——mooncmd const.md 红线7-9。",
  )
  // 统一头尾留恰好一个换行;本方言首块(state struct)无前导空行,自补一空行
  sb <+ "\n"
  // state struct + init
  sb <+ "///|\n"
  sb <+ "#derive(Eq)\npub(all) struct \{state_type} {\n"
  for field in def.state_fields {
    sb <+ "  \{field.name} : \{agg_moonbit_type(field.ty)}\n"
  }
  sb <+ "}\n\n"
  sb <+ "///|\n"
  sb <+ "pub extend \{state_type} with Eq::{not_equal, equal}\n\n"
  sb <+ "///|\n"
  sb <+ "pub fn \{state_type}::init() -> \{state_type} {\n  { "
  for field in def.state_fields {
    sb <+ "\{field.name}: \{field.init}, "
  }
  // 末字段模板自带尾空格，收口不再添——新 fmt 正典 = `, }` 单空格
  sb <+ "}\n}\n\n"
  // events enum
  sb <+ "///|\n"
  sb <+ "#derive(Eq)\npub(all) enum \{event_type} {\n"
  for event in def.events {
    let payload = agg_emit_payload(event.fields)
    if payload == "" {
      sb <+ "  \{event.name}\n"
    } else {
      sb <+ "  \{event.name}(\{payload})\n"
    }
  }
  sb <+ "}\n\n"
  sb <+ "///|\n"
  sb <+ "pub extend \{event_type} with Eq::{not_equal, equal}\n\n"
  // commands enum
  sb <+ "///|\n"
  sb <+ "#derive(Eq)\npub(all) enum \{command_type} {\n"
  for command in def.commands {
    let payload = agg_emit_payload(command.fields)
    if payload == "" {
      sb <+ "  \{command.name}\n"
    } else {
      sb <+ "  \{command.name}(\{payload})\n"
    }
  }
  sb <+ "}\n\n"
  sb <+ "///|\n"
  sb <+ "pub extend \{command_type} with Eq::{not_equal, equal}\n\n"
  // apply（表驱动签名:表含 `...` 委托事件 → 双参 hooks;全机械表单参字节稳）
  sb <+ "///|\n"
  sb <+
    "/// 事件演化（机械:evolve 指令逐条链式;同字段后写覆前写）\n"
  sb <+ "pub fn \{event_type}::apply(\n"
  sb <+ "  self : \{event_type},\n"
  sb <+ "  state : \{state_type},\n"
  if has_hooks {
    sb <+ "  hooks : \{hooks_evolve_type},\n"
  }
  sb <+ ") -> \{state_type} {\n"
  sb <+ "  match self {\n"
  for event in def.events {
    agg_emit_apply_arm(sb, event)
  }
  sb <+ "  }\n}\n\n"
  // hooks record
  sb <+ "///|\n"
  sb <+
    "/// 裁决钩子（记录型函数面,ADR-MC-003 同族;策略件手写实现——红线7 裁决不入表）\n"
  sb <+ "pub(all) struct \{hooks_type} {\n"
  for command in def.commands {
    let snake = agg_snake(command.name)
    let mut params = "(\{state_type}"
    for field in command.fields {
      params = params + ", \{agg_moonbit_type(field.ty)}"
    }
    params = params + ")"
    let one_line = "  \{snake} : \{params} -> Result[Array[\{event_type}], String]"
    // 新 fmt 正典：≤80 收单行，超宽才折 Result 载荷（R-G1a 宽度判据）
    if one_line.length() <= 80 {
      sb <+ "\{one_line}\n"
    } else {
      sb <+
        "  \{snake} : \{params} -> Result[\n    Array[\{event_type}],\n    String,\n  ]\n"
    }
  }
  sb <+ "}\n\n"
  // decide
  sb <+ "///|\n"
  sb <+
    "/// 裁决分派骨架（gen 只产分派与载荷拆包;裁决体 = 钩子）\n"
  sb <+ "pub fn \{def.name}_decide(\n"
  sb <+ "  state : \{state_type},\n"
  sb <+ "  cmd : \{command_type},\n"
  sb <+ "  hooks : \{hooks_type},\n"
  sb <+ ") -> Result[Array[\{event_type}], String] {\n"
  sb <+ "  match cmd {\n"
  for command in def.commands {
    let snake = agg_snake(command.name)
    let unpack = agg_emit_unpack(command.fields)
    let names : Array[String] = ["state"]
    for field in command.fields {
      names.push(field.name)
    }
    let call_args = agg_join(names, ", ")
    // 判宽:单行 >80 折 `=>` 续行形(fmt 实测正典——invoice 长名案校准)
    let line = if unpack == "" {
      "    \{command.name} => (hooks.\{snake})(state)"
    } else {
      "    \{command.name}(\{unpack}) => (hooks.\{snake})(\{call_args})"
    }
    if line.length() > 80 {
      if unpack == "" {
        sb <+ "    \{command.name} =>\n"
      } else {
        sb <+ "    \{command.name}(\{unpack}) =>\n"
      }
      sb <+ "      (hooks.\{snake})(\{call_args})\n"
    } else {
      sb <+ "\{line}\n"
    }
  }
  sb <+ "  }\n}\n"
  // 裁决钩子槽位+工厂（declare let 顶层值声明——实现 = policy 件
  // <agg>_<snake(Cmd)> let 闭包;槽全部缺位 = [0068] 告警+运行时 init 陷阱,响亮）
  sb <+ "\n///|\n"
  sb <+
    "/// 裁决钩子槽位（declare let 顶层值;实现 = policy 件 let 闭包,槽名 = \{def.name}_<snake(Cmd)>——缺位 = [0068] 告警+运行时 init 陷阱）\n"
  let mut first_decide_slot = true
  for command in def.commands {
    let slot = agg_hook_slot_name(def.name, command.name)
    let param_types : Array[String] = [state_type]
    for field in command.fields {
      param_types.push(agg_moonbit_type(field.ty))
    }
    // fmt 正典:连续 declare 各自独立 ///| 块（探针 2026-11-13——doc 随首槽,
    // 后续槽各起一块）
    if first_decide_slot {
      first_decide_slot = false
    } else {
      sb <+ "\n///|\n"
    }
    agg_emit_declare_result(sb, slot, param_types, event_type)
  }
  let decide_mappings : Array[String] = []
  for command in def.commands {
    let slot = agg_hook_slot_name(def.name, command.name)
    decide_mappings.push("\{agg_snake(command.name)}: \{slot}")
  }
  agg_emit_hooks_factory(sb, "\{def.name}_hooks", hooks_type, decide_mappings)
  // 演化钩子记录（`...` 委托事件表次发射;演化体 = policy 件槽闭包——无裁决,返终态）
  if has_hooks {
    sb <+ "\n///|\n"
    sb <+
      "/// 演化钩子（`...` 事件整件委托;演化体 = policy 件手写——无裁决,返终态）\n"
    sb <+ "pub(all) struct \{hooks_evolve_type} {\n"
    for event in def.events {
      if agg_event_hook_delegated(event) {
        let snake = agg_snake(event.name)
        let mut params = "(\{state_type}"
        for field in event.fields {
          params = params + ", \{agg_moonbit_type(field.ty)}"
        }
        params = params + ")"
        let one_line = "  \{snake} : \{params} -> \{state_type}"
        // 新 fmt 正典：≤80 收单行，超宽折参数逐行（R-G1a 宽度判据）
        if one_line.length() <= 80 {
          sb <+ "\{one_line}\n"
        } else {
          sb <+ "  \{snake} : (\n    \{state_type},\n"
          for field in event.fields {
            sb <+ "    \{agg_moonbit_type(field.ty)},\n"
          }
          sb <+ "  ) -> \{state_type}\n"
        }
      }
    }
    sb <+ "}\n"
    // 演化槽位+工厂（declare let;实现 = policy 件 <agg>_<snake(Event)> let 闭包）
    sb <+ "\n///|\n"
    sb <+
      "/// 演化钩子槽位（declare let 顶层值;实现 = policy 件 let 闭包——缺位 = [0068] 告警+运行时 init 陷阱）\n"
    let evolve_mappings : Array[String] = []
    let mut first_evolve_slot = true
    for event in def.events {
      if agg_event_hook_delegated(event) {
        let slot = agg_hook_slot_name(def.name, event.name)
        let param_types : Array[String] = [state_type]
        for field in event.fields {
          param_types.push(agg_moonbit_type(field.ty))
        }
        // fmt 正典:连续 declare 各自独立 ///| 块（同裁决面）
        if first_evolve_slot {
          first_evolve_slot = false
        } else {
          sb <+ "\n///|\n"
        }
        agg_emit_declare_plain(sb, slot, param_types, state_type)
        evolve_mappings.push("\{agg_snake(event.name)}: \{slot}")
      }
    }
    agg_emit_hooks_factory(
      sb,
      "\{def.name}_evolve_hooks",
      hooks_evolve_type,
      evolve_mappings,
    )
  }
  // wire 映射（役7+ D-MG-6）
  sb <+ "\n///|\n"
  sb <+
    "/// wire 映射（役7+ D-MG-6;行格式 = \"1\\t<Event>\\t<fields...>\";首列 = schema_version 预留位,现版只认 1）\n"
  sb <+ "pub fn \{event_type}::to_wire(self : \{event_type}) -> String {\n"
  sb <+ "  match self {\n"
  for event in def.events {
    if event.fields.length() == 0 {
      sb <+ "    \{event.name} => \"1\\t\{event.name}\"\n"
    } else {
      let unpack = agg_emit_unpack(event.fields)
      // 判宽:先拼单行候选,>80 折 `=>` 续行形(fmt 实测正典——长事件名案)
      let mut line = "    \{event.name}(\{unpack}) => \"1\\t\{event.name}"
      for field in event.fields {
        line = line + "\\t\\{" + field.name + "}"
      }
      line = line + "\""
      if line.length() > 80 {
        sb <+ "    \{event.name}(\{unpack}) =>\n"
        let mut body = "      \"1\\t\{event.name}"
        for field in event.fields {
          body = body + "\\t\\{" + field.name + "}"
        }
        sb <+ "\{body}\"\n"
      } else {
        sb <+ "\{line}\n"
      }
    }
  }
  sb <+ "  }\n}\n\n"
  sb <+ "///|\n"
  sb <+
    "/// 行格式解析（坏载荷 = None;首列只认 \"1\"——schema_version 预留位）\n"
  sb <+ "pub fn \{event_type}::from_wire(text : String) -> \{event_type}? {\n"
  sb <+ "  let parts = text.split(\"\\t\").collect()\n"
  sb <+ "  if parts.length() < 2 {\n    return None\n  }\n"
  sb <+ "  if parts[0] != \"1\" {\n    return None\n  }\n"
  for event in def.events {
    let total = 2 + event.fields.length()
    sb <+ "  if parts[1] == \"\{event.name}\" && parts.length() == \{total} {\n"
    if event.fields.length() == 0 {
      sb <+ "    return Some(\{event.name})\n  }\n"
    } else {
      let args : Array[String] = []
      let mut slot = 2
      for field in event.fields {
        match field.ty {
          "string" => args.push("parts[\{slot}].to_owned()")
          "int" => args.push("\{def.name}_wire_int(parts[\{slot}].to_owned())")
          _ => args.push("parts[\{slot}].to_owned() == \"true\"")
        }
        slot += 1
      }
      let ctor = "\{event.name}(\{agg_join(args, ", ")})"
      let one_line = "    return Some(\{ctor})"
      // 新 fmt 正典：≤80 单行；超宽折 Some( 构造子行 + 尾逗号
      if one_line.length() <= 80 {
        sb <+ "\{one_line}\n  }\n"
      } else {
        sb <+ "    return Some(\n      \{ctor},\n    )\n  }\n"
      }
    }
  }
  sb <+ "  None\n}\n"
  // int 助手（仅当事件表含 int 字段时发射）
  let mut has_int = false
  for event in def.events {
    for field in event.fields {
      if field.ty == "int" {
        has_int = true
      }
    }
  }
  if has_int {
    sb <+ "\n///|\n"
    sb <+
      "/// 行格式整数字段解析（wire 专用;非数字形 = 0——格式对齐由 parts 校验与 roundtrip 契约兜底）\n"
    sb <+ "fn \{def.name}_wire_int(text : String) -> Int32 {\n"
    sb <+ "  let mut value : Int32 = 0\n"
    sb <+ "  let mut sign : Int32 = 1\n"
    sb <+ "  for ch in text.iter() {\n"
    sb <+ "    if ch == '-' {\n      sign = -1\n"
    sb <+ "    } else if ch >= '0' && ch <= '9' {\n"
    sb <+ "      value = value * 10 + (ch.to_int() - 48)\n"
    sb <+ "    } else {\n      return 0\n    }\n  }\n"
    sb <+ "  value * sign\n}\n"
  }
  sb.to_string()
}

///|
/// serde wire 投影发射（役10;[aggregate.serde] 键控——调用方判键后调用，
/// byte-stable:遍历序 = 表序,零时间戳零哈希;模板 = .mingspace/serde_probe
/// 探针手稿形,fmt 正典对齐）。
pub fn emit_mooncmd_agg_serde(
  def : MooncmdAggDef,
  provenance~ : SchemaProvenance,
) -> String {
  let sb = StringBuilder()
  let enum_name = schema_upper_first(def.name) + "Event"
  schema_emit_header(
    sb,
    provenance,
    def.schema_version,
    "// serde wire 投影(役10;JSON 外部标签制,反读按表序 index 分派;变体表/臂序 = 词表序——词表加变体 = 同批再生)",
  )
  sb <+ "\n"
  // 变体名表(反读分派基表)——fmt 宽度判据复刻:内联打包形(fmt 把短表
  // 折成单内行;94 = 实测稳定上限,更长词表逐行,阈值带由黄金门自显)。
  sb <+ "///|\n"
  sb <+
    "/// 变体名表(反读分派 = 表序 index;词表加变体 = 同批再生,漏行 = 金罐红)。\n"
  sb <+ "let \{def.name}_event_variants : ReadOnlyArray[String] = [\n"
  let mut line = ""
  for event in def.events {
    let item = "\"\{event.name}\","
    if line == "" {
      line = "  " + item
    } else {
      let candidate = line + " " + item
      if candidate.length() <= 94 {
        line = candidate
      } else {
        sb <+ "\{line}\n"
        line = "  " + item
      }
    }
  }
  if line != "" {
    sb <+ "\{line}\n"
  }
  sb <+ "]\n\n"
  // Serialize impl
  sb <+ "///|\n"
  sb <+
    "/// 序列化(外部标签制:unit=裸串/载荷=单条目对象;臂序 = 词表序)。\n"
  sb <+
    "pub impl @serde.Serialize for \{enum_name} with fn serialize(self, s) {\n"
  sb <+ "  let enum_name = \"\{enum_name}\"\n"
  sb <+ "  match self {\n"
  let mut index = 0
  for event in def.events {
    match event.fields.length() {
      0 => {
        // fmt 宽度判据(R-G1a 同款):单行 ≤80 单行;>80 折「臂换行+调用单行」
        let one_line = "    \{event.name} => s.serialize_unit_variant({ enum_name, index: \{index}, name: \"\{event.name}\", })"
        if one_line.length() <= 80 {
          sb <+ "\{one_line}\n"
        } else {
          sb <+
            "    \{event.name} =>\n      s.serialize_unit_variant({ enum_name, index: \{index}, name: \"\{event.name}\", })\n"
        }
      }
      1 => {
        let field = event.fields[0]
        let one_line = "    \{event.name}(\{field.name}) => s.serialize_newtype_variant({ enum_name, index: \{index}, name: \"\{event.name}\", }, \{field.name})"
        let call_line = "      s.serialize_newtype_variant({ enum_name, index: \{index}, name: \"\{event.name}\", }, \{field.name})"
        if one_line.length() <= 80 {
          sb <+ "\{one_line}\n"
        } else if call_line.length() <= 80 {
          sb <+ "    \{event.name}(\{field.name}) =>\n\{call_line}\n"
        } else {
          sb <+
            "    \{event.name}(\{field.name}) =>\n      s.serialize_newtype_variant(\n        { enum_name, index: \{index}, name: \"\{event.name}\", },\n        \{field.name},\n      )\n"
        }
      }
      _ => {
        let unpack = agg_emit_unpack(event.fields)
        let total = event.fields.length()
        sb <+ "    \{event.name}(\{unpack}) => {\n"
        sb <+
          "      s.serialize_tuple_variant_begin(\n        { enum_name, index: \{index}, name: \"\{event.name}\", },\n        \{total},\n      )\n"
        for field in event.fields {
          sb <+ "      s.serialize_tuple_variant_element(\{field.name})\n"
        }
        sb <+ "      s.serialize_tuple_variant_end()\n"
        sb <+ "    }\n"
      }
    }
    index = index + 1
  }
  sb <+ "  }\n}\n\n"
  // Deserialize impl
  sb <+ "///|\n"
  sb <+
    "/// 反序列化(反读按 index 分派 = 表序;未知 index = UnknownVariant)。\n"
  sb <+
    "pub impl @serde.Deserialize for \{enum_name} with fn deserialize(d) {\n"
  sb <+
    "  let value = match\n    d.deserialize_enum_begin(\"\{enum_name}\", \{def.name}_event_variants) {\n"
  let mut index = 0
  for event in def.events {
    match event.fields.length() {
      0 => {
        sb <+ "    \{index} => {\n"
        sb <+ "      d.deserialize_unit_variant()\n"
        sb <+ "      \{event.name}\n"
        sb <+ "    }\n"
      }
      1 => {
        let one_line = "    \{index} => \{event.name}(d.deserialize_newtype_variant())"
        // fmt 宽度判据(R-G1a 同款):≤80 单行,超宽折括号形
        if one_line.length() <= 80 {
          sb <+ "\{one_line}\n"
        } else {
          sb <+
            "    \{index} =>\n      \{event.name}(d.deserialize_newtype_variant())\n"
        }
      }
      _ => {
        let total = event.fields.length()
        sb <+ "    \{index} => {\n"
        sb <+ "      d.deserialize_tuple_begin(\{total})\n"
        for field in event.fields {
          sb <+ "      let \{field.name} = d.deserialize_tuple_next()\n"
        }
        sb <+ "      d.deserialize_tuple_end()\n"
        sb <+ "      \{event.name}(\{agg_emit_unpack(event.fields)})\n"
        sb <+ "    }\n"
      }
    }
    index = index + 1
  }
  sb <+
    "    index =>\n      raise @serde.UnknownVariant(\n        path=d.path(),\n        variant=index.to_string(),\n        expected=\{def.name}_event_variants,\n      )\n"
  sb <+ "  }\n"
  sb <+ "  d.deserialize_enum_end()\n  value\n}\n\n"
  // [0079] 收口 ×2(deprecate+hide 双属性,单行参数表——家法)
  sb <+ "///|\n"
  sb <+
    "#deprecated(\"reach it through the `Serialize` bound\", skip_current_package=true)\n#doc(hidden)\npub extend \{enum_name} with @serde.Serialize::{serialize}\n\n"
  sb <+ "///|\n"
  sb <+
    "#deprecated(\"reach it through the `Deserialize` bound\", skip_current_package=true)\n#doc(hidden)\npub extend \{enum_name} with @serde.Deserialize::{deserialize}\n"
  sb.to_string()
}

///|
/// 契约门脚手架发射（D-MG-5;byte-stable）：免费两钉——
/// ① init 契约 = 词表值区声明 ② wire roundtrip 每事件恒等（Eq derived）。
/// 场景契约（重放等价/并发拒写）= 业务语义人填（红线7），只留指路注释。
pub fn emit_mooncmd_agg_contract_tests(def : MooncmdAggDef) -> String {
  let sb = StringBuilder()
  let state_type = schema_upper_first(def.name) + "State"
  let event_type = schema_upper_first(def.name) + "Event"
  sb <+
    "// ===== \{def.name} 聚合契约门（D-MG-5 脚手架;源表 \{def.target_package}/\{def.name}_agg.toml;生成物禁手写,regen 刷新;白盒件——同包命名空间,夹具/黑盒本地型零遮蔽）=====\n\n"
  sb <+ "///|\n"
  sb <+
    "/// init 契约:字段初值 = 词表值区声明（形状即契约）\n"
  sb <+ "test \"\{def.name} init contract: fields equal declared inits\" {\n"
  sb <+ "  let state = \{state_type}::init()\n"
  for field in def.state_fields {
    sb <+ "  assert_eq(state.\{field.name}, \{field.init})\n"
  }
  sb <+ "}\n\n"
  sb <+ "///|\n"
  sb <+
    "/// wire roundtrip 契约:每事件样本 to_wire→from_wire 恒等（Eq）\n"
  sb <+ "test \"\{def.name} wire contract: roundtrip identity per event\" {\n"
  let elements : Array[String] = []
  for event in def.events {
    if event.fields.length() == 0 {
      elements.push("\{event.name}")
    } else {
      let args : Array[String] = []
      for field in event.fields {
        match field.ty {
          "string" => args.push("\"contract\"")
          "int" => args.push("1")
          _ => args.push("true")
        }
      }
      elements.push("\{event.name}(\{agg_join(args, ", ")})")
    }
  }
  let one_line = "  let samples : Array[\{event_type}] = [\{agg_join(elements, ", ")}]"
  // 新 fmt 正典：≤80 单行；超宽逐元素一行 + 尾逗号
  if one_line.length() <= 80 {
    sb <+ "\{one_line}\n"
  } else {
    sb <+ "  let samples : Array[\{event_type}] = [\n"
    for element in elements {
      sb <+ "    \{element},\n"
    }
    sb <+ "  ]\n"
  }
  sb <+ "  for sample in samples {\n"
  sb <+ "    match \{event_type}::from_wire(sample.to_wire()) {\n"
  sb <+ "      Some(back) => assert_true(back.to_wire() == sample.to_wire())\n"
  sb <+ "      None => fail(\"wire roundtrip lost payload\")\n"
  sb <+ "    }\n  }\n}\n\n"
  sb <+ "///|\n"
  sb <+
    "// 场景契约脚手架（红线7:业务语义人填）——重放等价/并发拒写样板见 examples/bank/main.mbt\n"
  sb <+
    "// §③④ 与 store_test 乐观并发钉;填充点 = 命令脚本 → 期望事件流/终态表。\n"
  sb.to_string()
}

///|
/// 策略 stub 发射（stub-zone 宪法红线）：<name>_policy.mbt 的**首次落盘形**
/// ——发射只给**槽位 let 闭包守卫体**（Err("TODO(<Cmd>)") 即未填）。
/// 文件层契约 = **仅缺位时落，regen 永不覆写**（user fill-in 永不被再生
/// 覆盖；只若不在由驱动层 fs 判定）。形状与 gen 件的 declare 槽位配对：
/// 槽名 = <agg>_<snake(Cmd/Event)>（聚合根前缀,用户拍 2026-11-13）;
/// 分派/工厂/胶水 = gen 机械面,本件只补槽体。守卫体 = 体注释 +
/// `let _ = (参数…)` 哑消费 + Err/abort 守卫（deny-warn 干净——2026-11-10 实证）。
pub fn emit_mooncmd_agg_policy_stub(def : MooncmdAggDef) -> String {
  let sb = StringBuilder()
  let state_type = schema_upper_first(def.name) + "State"
  let event_type = schema_upper_first(def.name) + "Event"
  let has_hooks = agg_has_hook_delegated(def.events)
  sb <+
    "// ===== \{schema_upper_first(def.name)} 裁决策略 stub（仅缺位时落,regen 永不覆写——宪法 stub-zone）=====\n"
  sb <+ "// 源表：\{def.target_package}/\{def.name}_agg.toml\n"
  sb <+
    "// 钩子槽位与 \{def.name}_gen.mbt 的 declare 声明配对（分派/工厂/胶水 = gen 机械面——\n"
  sb <+
    "// 本件只补槽体）。裁决 = 手写闭包（mooncmd const.md 红线7 裁决不入表）：\n"
  sb <+
    "// 每槽 = let 闭包,Err(\"TODO(<Cmd>)\") 即未填;演化槽 abort 即未填（静默恒等是数据黑洞）。\n"
  // 裁决槽位（Result 型:头部 ≤80 单行收整行,超宽折 Result 载荷 2 空格续行
  // +`] = lambda` 0 列缀行尾——fmt 正典 2026-11-13 二轮探针+bank 盘上真源）
  for command in def.commands {
    let slot = agg_hook_slot_name(def.name, command.name)
    let names : Array[String] = ["state"]
    for field in command.fields {
      names.push(field.name)
    }
    let lam = if names.length() == 1 {
      "state"
    } else {
      "(\{agg_join(names, ", ")})"
    }
    let param_types : Array[String] = [state_type]
    for field in command.fields {
      param_types.push(agg_moonbit_type(field.ty))
    }
    let params = "(\{agg_join(param_types, ", ")})"
    let head = "pub let \{slot} : \{params} -> Result[Array[\{event_type}], String]"
    sb <+ "\n///|\n"
    if head.length() > 80 {
      sb <+
        "pub let \{slot} : \{params} -> Result[\n  Array[\{event_type}],\n  String,\n] = \{lam} => {\n"
    } else {
      sb <+
        "pub let \{slot} : \{params} -> Result[Array[\{event_type}], String] = \{lam} => {\n"
    }
    sb <+
      "  // TODO(\{command.name}): 裁决体待填——红线7（Ok([<Event>(载荷)]) 或 Err(拒绝原因)）\n"
    sb <+ "  let _ = \{lam}\n"
    sb <+ "  Err(\"TODO(\{command.name}): 裁决体待填——红线7\")\n"
    sb <+ "}\n"
  }
  // 演化槽位（plain 型:头 ≤80 单行+整行超宽折 lambda 参数;头超宽 type 参数
  // 拆形+lambda 单行缀——fmt 正典 2026-11-13 二轮探针 s2 形）
  if has_hooks {
    for event in def.events {
      if agg_event_hook_delegated(event) {
        let slot = agg_hook_slot_name(def.name, event.name)
        let names : Array[String] = ["state"]
        for field in event.fields {
          names.push(field.name)
        }
        let lam = if names.length() == 1 {
          "state"
        } else {
          "(\{agg_join(names, ", ")})"
        }
        let param_types : Array[String] = [state_type]
        for field in event.fields {
          param_types.push(agg_moonbit_type(field.ty))
        }
        let one_line = "pub let \{slot} : (\{agg_join(param_types, ", ")}) -> \{state_type} = \{lam} => {"
        sb <+ "\n///|\n"
        let head_plain = "pub let \{slot} : (\{agg_join(param_types, ", ")}) -> \{state_type}"
        if head_plain.length() > 80 {
          // type 段超宽:参数拆形+lambda 单行缀（fmt 正典探针 2026-11-13 s2 形）
          sb <+ "pub let \{slot} : (\n"
          for ty in param_types {
            sb <+ "  \{ty},\n"
          }
          sb <+ ") -> \{state_type} = \{lam} => {\n"
        } else if one_line.length() > 80 {
          // 头单行+整行超宽:lambda 参数拆形（counter_bumped 罐形正典;参数面
          // = names 全列含 state 首参——2026-11-13 invoice 真件咬出丢参修正）
          sb <+
            "pub let \{slot} : (\{agg_join(param_types, ", ")}) -> \{state_type} = (\n"
          for nm in names {
            sb <+ "  \{nm},\n"
          }
          sb <+ ") => {\n"
        } else {
          sb <+ "\{one_line}\n"
        }
        sb <+
          "  // TODO(evolve \{event.name}): 演化体待填（返终态——abort 即未填,静默恒等是数据黑洞）\n"
        sb <+ "  let _ = \{lam}\n"
        sb <+ "  abort(\"TODO(evolve \{event.name}): 演化体待填\")\n"
        sb <+ "}\n"
      }
    }
  }
  sb.to_string()
}

///|
/// 装配胶水发射（二版拍1;byte-stable）：六桥件（handler/applier/
/// empty_state/serialize/deserialize/type_name）= 消费者对 gen 产面的
/// 纯换名包装（bank_demo 手写六桥机械升格;零裁决语义——红线7 裁决仍在
/// policy 手写钩子）。落位 = 第四件 `<name>_glue.mbt`（regen 覆写区,
/// 与 gen 同形 committed 进 owner 包）。依赖 thy1016/mooncmd/command +
/// moonbitlang/core/encoding/utf8——消费者包 moon.pkg 生产 import 块自配
/// （note 行烙明）。handler 桥错 = InvalidCommand(msg) 机械缺省（策略
/// String 错域唯一去处）;type_name = 裸事件名（owner 包内视角,store
/// 仅记不比对——标签串演进不破读链）。
pub fn emit_mooncmd_agg_glue(
  def : MooncmdAggDef,
  provenance~ : SchemaProvenance,
) -> String {
  let sb = StringBuilder()
  let state_type = schema_upper_first(def.name) + "State"
  let event_type = schema_upper_first(def.name) + "Event"
  let command_type = schema_upper_first(def.name) + "Command"
  let has_hooks = agg_has_hook_delegated(def.events)
  schema_emit_header(
    sb,
    provenance,
    def.schema_version,
    "// 装配胶水:六桥件（handler/applier/empty_state/serialize/deserialize/type_name）——依赖 thy1016/mooncmd/command + moonbitlang/core/encoding/utf8,消费者包 moon.pkg 生产 import 块自配;裁决装配点 = \{def.name}_hooks()（policy 件手写——红线7 裁决不入表）。",
  )
  // 统一头尾留恰好一个换行;首块（handler 桥）无前导空行,自补一空行
  sb <+ "\n"
  // handler 桥:decide Result → 框架命令错误（bank_demo 手写形升格）
  sb <+ "///|\n"
  sb <+
    "/// 桥接:gen 分派（String 错域）→ 框架命令错误（InvalidCommand 同界）——\n"
  sb <+
    "/// 裁决装配点 = \{def.name}_hooks()（policy 件手写——红线7 裁决不入表）\n"
  sb <+ "pub fn \{def.name}_handler(\n"
  sb <+ "  state : \{state_type},\n"
  sb <+ "  cmd : \{command_type},\n"
  sb <+ ") -> Array[\{event_type}] raise @command.CommandError {\n"
  sb <+ "  match \{def.name}_decide(state, cmd, \{def.name}_hooks()) {\n"
  sb <+ "    Ok(events) => events\n"
  sb <+ "    Err(msg) => raise @command.CommandError::InvalidCommand(msg)\n"
  sb <+ "  }\n}\n\n"
  // applier bridge wiring: `...` tables get two-param apply; mechanical tables keep single-param (byte-stable)
  sb <+ "///|\n"
  if has_hooks {
    sb <+ "/// 事件应用器（EventApplier::Single 装配位）\n"
    sb <+ "pub fn \{def.name}_applier(\n"
    sb <+ "  state : \{state_type},\n"
    sb <+ "  event : \{event_type},\n"
    sb <+ ") -> \{state_type} {\n"
    sb <+ "  event.apply(state, \{def.name}_evolve_hooks())\n}\n\n"
  } else {
    sb <+ "/// 事件应用器（EventApplier::Single 装配位）\n"
    sb <+ "pub fn \{def.name}_applier(\n"
    sb <+ "  state : \{state_type},\n"
    sb <+ "  event : \{event_type},\n"
    sb <+ ") -> \{state_type} {\n"
    sb <+ "  event.apply(state)\n}\n\n"
  }
  // empty_state 桥
  sb <+ "///|\n"
  sb <+ "/// 空初态（AggregateRoot::new / from_events 装配位）\n"
  sb <+ "pub fn \{def.name}_empty_state() -> \{state_type} {\n"
  sb <+ "  \{state_type}::init()\n}\n\n"
  // serialize 桥（役10 键控:键开 = serde JSON 径;键关 = wire 行格式径字节稳）
  sb <+ "///|\n"
  if def.serde_json {
    sb <+
      "/// 事件序列化（SQLiteEventStore::new 装配位;serde JSON 外部标签制——\n"
    sb <+
      "/// [aggregate.serde] 键开投影;事件域封闭 = 全原语字段,SerError 结构性\n"
    sb <+
      "/// 不可达,catch 臂为型收口——端口签名无 raise 域）\n"
    sb <+ "pub fn \{def.name}_serialize(event : \{event_type}) -> Bytes {\n"
    sb <+
      "  @json.to_bytes(event) catch {\n    _ => Bytes::from_array([])\n  }\n}\n\n"
  } else {
    sb <+
      "/// 事件序列化（SQLiteEventStore::new 装配位;wire 契约 = 契约门 roundtrip 钉）\n"
    sb <+ "pub fn \{def.name}_serialize(event : \{event_type}) -> Bytes {\n"
    sb <+ "  @utf8.encode(event.to_wire())\n}\n\n"
  }
  // deserialize 桥（键控同上）
  sb <+ "///|\n"
  if def.serde_json {
    sb <+
      "/// 事件反序列化（serde JSON 径——坏载荷 raise SerError 透传,store 重放错误域自然传播）\n"
    sb <+
      "pub fn \{def.name}_deserialize(data : Bytes) -> \{event_type} raise {\n"
    sb <+ "  @json.from_string(@utf8.decode(data))\n}\n\n"
  } else {
    sb <+
      "/// 事件反序列化（坏载荷 abort——wire 格式契约由契约门钉）\n"
    sb <+
      "pub fn \{def.name}_deserialize(data : Bytes) -> \{event_type} raise {\n"
    sb <+ "  let text = @utf8.decode(data)\n"
    sb <+ "  match \{event_type}::from_wire(text) {\n"
    sb <+ "    Some(event) => event\n"
    sb <+ "    None => abort(\"bad event wire payload: \\{text}\")\n"
    sb <+ "  }\n}\n\n"
  }
  // type_name 桥:逐变体 arity 通配（零载荷 = 裸构造模式）
  sb <+ "///|\n"
  sb <+ "/// 事件类型标签（SQLite store 记录面;裸事件名）\n"
  sb <+ "pub fn \{def.name}_type_name(event : \{event_type}) -> String {\n"
  sb <+ "  match event {\n"
  for event in def.events {
    let arity = event.fields.length()
    if arity == 0 {
      sb <+ "    \{event.name} => \"\{event.name}\"\n"
    } else {
      let wildcards : Array[String] = []
      for _ in 0..<arity {
        wildcards.push("_")
      }
      sb <+
        "    \{event.name}(\{agg_join(wildcards, ", ")}) => \"\{event.name}\"\n"
    }
  }
  sb <+ "  }\n}\n"
  sb.to_string()
}
