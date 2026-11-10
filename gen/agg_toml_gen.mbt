///|
/// `mooncmd` 聚合词表方言（消费者径）——`<agg>_agg.toml` 定义集：
/// [aggregate]（词根/id 域）+ [aggregate.state] 字段（形状区+init 值区）+
/// [[aggregate.events]] 事件（字段+演化指令）+ [[aggregate.commands]] 命令词形。
/// 分工判据（mooncmd README 配方节 + const.md 红线7-9 护栏）:gen 产**类型/apply/
/// 分派骨架**（形状与机械演化）,**裁决 = 策略件手写钩子**（红线7 裁决不入表;
/// 演化指令集封闭 set/add/append/remove——红线8,scope 门把封闭集外指令判红）。
/// 产物 = 消费包 `<agg>_gen.mbt`:state struct + init + 事件/命令枚举（标签
/// 载荷）+ apply（evolve 指令逐条链式,同字段后写覆前写）+ DecideHooks 记录
/// + decide 分派（载荷拆包后直调钩子）。词表封闭:类型 string/int/bool;
/// id 词形安全检查(保留字族)。
/// 抽出源 = 主仓 skelschema/mooncmd_agg_toml_gen.mbt(体保真);治理三律
/// (变更单向/golden 漂移探测/发布配对)见仓 README——本件只跟随搬运,
/// 发射能力变更先落主仓 skelschema。

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
  let def = MooncmdAggDef::{
    schema_version: schema_header_field(table, "schema_version"),
    generator: schema_header_field(table, "generator"),
    target_package: schema_header_field(table, "target_package"),
    name,
    id,
    state_fields,
    events,
    commands,
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
/// 演化指令链发射:每指令一条 let（s0/s1/…链式,同字段后写覆前写）;
/// operand = 载荷引用（punning 变量; "-" 前缀取负）或字面量。
fn agg_emit_apply_arm(sb : StringBuilder, event : AggEventDef) -> Unit {
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
  // apply
  sb <+ "///|\n"
  sb <+
    "/// 事件演化（机械:evolve 指令逐条链式;同字段后写覆前写）\n"
  sb <+ "pub fn \{event_type}::apply(\n"
  sb <+ "  self : \{event_type},\n"
  sb <+ "  state : \{state_type},\n"
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
    if unpack == "" {
      sb <+ "    \{command.name} => (hooks.\{snake})(state)\n"
    } else {
      sb <+ "    \{command.name}(\{unpack}) => (hooks.\{snake})(\{call_args})\n"
    }
  }
  sb <+ "  }\n}\n"
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
      sb <+ "    \{event.name}(\{unpack}) => \"1\\t\{event.name}"
      for field in event.fields {
        sb <+ "\\t\\{\{field.name}}"
      }
      sb <+ "\"\n"
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
/// ——裁决体 = 手写钩子（红线7 裁决不入表），发射只给**正确签名守卫闭包**
/// （Err("TODO(<Cmd>)") 即未填）。文件层契约 = **仅缺位时落，regen 永不
/// 覆写**（user fill-in 永不被再生覆盖；只若不在由驱动层 fs 判定）。形状
/// 与 bank 手写孪生件（examples/bank/account_policy.mbt）同构：工厂
/// `<name>_hooks()` + 记录字面量 + arrow 闭包（单参裸形 = fmt 正典）。
/// 守卫体首行 = `let _ = (参数…)` 哑消费——stub 参数全未用会咬
/// unused_value × deny-warn（消费项目核身实证 2026-11-10），未填体
/// 也须 deny-warn 干净。
pub fn emit_mooncmd_agg_policy_stub(def : MooncmdAggDef) -> String {
  let sb = StringBuilder()
  let hooks_type = schema_upper_first(def.name) + "DecideHooks"
  sb <+
    "// ===== \{schema_upper_first(def.name)} 裁决策略 stub（仅缺位时落,regen 永不覆写——宪法 stub-zone）=====\n"
  sb <+ "// 源表：\{def.target_package}/\{def.name}_agg.toml\n"
  sb <+
    "// 裁决体 = 手写钩子（mooncmd const.md 红线7 裁决不入表）：每钩子 =\n"
  sb <+
    "// 正确签名守卫闭包，Err(\"TODO(<Cmd>)\") 即未填；语义填好后装配进\n"
  sb <+ "// \{def.name}_decide（见 \{def.name}_gen.mbt 分派骨架）。\n"
  sb <+ "\n///|\n"
  sb <+ "pub fn \{def.name}_hooks() -> \{hooks_type} {\n"
  sb <+ "  {\n"
  for command in def.commands {
    let snake = agg_snake(command.name)
    let names : Array[String] = ["state"]
    for field in command.fields {
      names.push(field.name)
    }
    if names.length() == 1 {
      sb <+ "    \{snake}: state => {\n"
      sb <+ "      let _ = state\n"
    } else {
      sb <+ "    \{snake}: (\{agg_join(names, ", ")}) => {\n"
      sb <+ "      let _ = (\{agg_join(names, ", ")})\n"
    }
    sb <+ "      Err(\"TODO(\{command.name}): 裁决体待填——红线7\")\n"
    sb <+ "    },\n"
  }
  sb <+ "  }\n}\n"
  sb.to_string()
}
