///|
/// cmd/gen 共享机器(base):抽自主仓 skelschema/toml_gen_base.mbt 体保真
/// 搬运(役13b 漂移补齐 2026-11-14——上轮快照缺 helper,CLI 烟测咬出
/// agg 产物缺钩子工厂尾段,红灯驱动同步)。按需子集:主仓其他方言专用
/// helper(cmd 两方言零引用)随搬运裁除,防 unused 警。治理①变更单向律
/// ——本件只跟随搬运,能力变更先落主仓。
/// schema gen 的**共享机器**（base）：TOML 读件 + 代码发射件。
/// 本文件不含任何一张表的语义——各表（编解码 / 存储 / 工具 / 属性测试）
/// 分文件演进（AGENTS.md：一个方言一个生成器文件，共享机器在 base 文件）。
/// 只依赖通用 `@toml` 库，不与 FsmIR 耦合。

///|
/// 首字母大写（其余原样）——枚举变体名构造件（jsonld_upper_first 同款）。
fn schema_upper_first(part : String) -> String {
  let sb = StringBuilder()
  let mut first = true
  for ch in part {
    if first {
      let head = "\{ch}"
      sb <+ "\{head.to_upper()}"
      first = false
    } else {
      sb <+ "\{ch}"
    }
  }
  sb.to_string()
}

///|
/// 取字符串键：缺键 / 型错 = None（供表头体例键等可选读取）。
fn schema_toml_string(
  table : Map[String, @toml.TomlValue],
  key : String,
) -> String? {
  match table.get(key) {
    Some(TomlString(value)) => Some(value)
    _ => None
  }
}

///|
/// 可省字符串键：缺键 = Ok(None)；键在但型错 = 红。
fn schema_toml_string_opt(
  table : Map[String, @toml.TomlValue],
  key : String,
  where_ : String,
) -> Result[String?, String] {
  match table.get(key) {
    Some(TomlString(value)) => Ok(Some(value))
    Some(_) => Err("\{where_}: key \"\{key}\" must be a string")
    None => Ok(None)
  }
}

///|
/// 带默认值字符串键：缺键 = Ok(default)；键在但型错 = 红。
fn schema_toml_string_or(
  table : Map[String, @toml.TomlValue],
  key : String,
  default : String,
  where_ : String,
) -> Result[String, String] {
  match table.get(key) {
    Some(TomlString(value)) => Ok(value)
    Some(_) => Err("\{where_}: key \"\{key}\" must be a string")
    None => Ok(default)
  }
}

///|
/// 必填字符串键：缺键 / 型错 = 红。
fn schema_toml_string_req(
  table : Map[String, @toml.TomlValue],
  key : String,
  where_ : String,
) -> Result[String, String] {
  match schema_toml_string_opt(table, key, where_) {
    Ok(Some(value)) => Ok(value)
    Ok(None) => Err("\{where_}: missing string key \"\{key}\"")
    Err(msg) => Err(msg)
  }
}

///|
/// 字符串数组键：缺键 = Ok([])；键在但非数组 / 含非串元素 = 红。
fn schema_toml_string_array(
  table : Map[String, @toml.TomlValue],
  key : String,
  where_ : String,
) -> Result[Array[String], String] {
  match table.get(key) {
    Some(TomlArray(items)) => {
      let out : Array[String] = []
      for item in items {
        match item {
          TomlString(value) => out.push(value)
          _ =>
            return Err("\{where_}: key \"\{key}\" must be an array of strings")
        }
      }
      Ok(out)
    }
    Some(_) => Err("\{where_}: key \"\{key}\" must be an array of strings")
    None => Ok([])
  }
}

///|
/// 可省子表键：缺键 = Ok(None)；键在但非表 = 红。
fn schema_toml_table_opt(
  table : Map[String, @toml.TomlValue],
  key : String,
  where_ : String,
) -> Result[Map[String, @toml.TomlValue]?, String] {
  match table.get(key) {
    Some(TomlTable(inner)) => Ok(Some(inner))
    Some(_) => Err("\{where_}: key \"\{key}\" must be a table")
    None => Ok(None)
  }
}

///|
/// 子表数组键（[[xxx]]）：缺键 = Ok([])；键在但非数组 / 含非表元素 = 红。
fn schema_toml_table_array(
  table : Map[String, @toml.TomlValue],
  key : String,
  where_ : String,
) -> Result[Array[Map[String, @toml.TomlValue]], String] {
  match table.get(key) {
    Some(TomlArray(items)) => {
      let out : Array[Map[String, @toml.TomlValue]] = []
      for item in items {
        match item {
          TomlTable(inner) => out.push(inner)
          _ =>
            return Err("\{where_}: key \"\{key}\" must be an array of tables")
        }
      }
      Ok(out)
    }
    Some(_) => Err("\{where_}: key \"\{key}\" must be an array of tables")
    None => Ok([])
  }
}

///|
/// 解析 TOML 文本到根表（统一入口：各表生成器共用）。
pub fn schema_toml_root(
  content : String,
) -> Result[Map[String, @toml.TomlValue], String] {
  let root = try @toml.parse(content) catch {
    err => return Err("TOML parse error: \{err}")
  } noraise {
    v => v
  }
  match root {
    TomlTable(table) => Ok(table)
    _ => Err("root must be a table")
  }
}

///|
/// 表头三件（gen 体例键）读取：缺键 = 空串（非协议字段，不参与口径校验）。
fn schema_header_field(
  table : Map[String, @toml.TomlValue],
  key : String,
) -> String {
  schema_toml_string(table, key).unwrap_or("")
}

///|
/// 溯源三件（链面事实，评审役 R-评a 定案）：源表径 / 再生命令 / 绑定器径。
/// 由调用方（再生命令、黄金门）给——方言 emit 不硬编码。硬编码已实证
/// 腐烂：生成器分家搬迁后 7/8 方言的入库生成物头注烙着陈径；第二张表
/// = 调用方给新三件，emit 零改动（新表 = 新数据在链上兑现）。
pub(all) struct SchemaProvenance {
  source_table : String
  regen_command : String
  binder_path : String
}

///|
/// 生成物文件头（各表统一体例；溯源三件由调用方给，note = 方言自述）。
/// 尾留**恰好一个换行**——各发射块自带前导空行，首块不另加前导空行时须自补。
/// schema_version 空 = 源表行不带「（schema …）」版次尾注（rl 等无版次表的复用位）。
pub fn schema_emit_header(
  sb : StringBuilder,
  provenance : SchemaProvenance,
  schema_version : String,
  note : String,
) -> Unit {
  sb <+
    "// ===== GENERATED FILE — DO NOT EDIT（生成物禁手写，const.md §7）=====\n"
  // 版次尾注：空版次 = 不带尾注（同一函数服务有/无版次两类表）。
  let version_tail = if schema_version == "" {
    ""
  } else {
    "（schema \{schema_version}）"
  }
  sb <+ "// 源表：\{provenance.source_table}\{version_tail}\n"
  sb <+ "// 再生：\{provenance.regen_command}\n"
  sb <+ "// 绑定器：\{provenance.binder_path}\n"
  sb <+ "\{note}\n"
}
