// ===== GENERATED FILE — DO NOT EDIT（生成物禁手写，const.md §7）=====
// 源表：examples/bank/account_agg.toml（schema 1.0）
// 再生：moon run skelschema/cmd(仓根起跑;改表 → 再生 → 黄金门对拍)
// 绑定器：skelschema/mooncmd_agg_toml_gen.mbt(parse/validate/emit 三件套)
// serde wire 投影(役10;JSON 外部标签制,反读按表序 index 分派;变体表/臂序 = 词表序——词表加变体 = 同批再生)

///|
/// 变体名表(反读分派 = 表序 index;词表加变体 = 同批再生,漏行 = 金罐红)。
let account_event_variants : ReadOnlyArray[String] = [
  "AccountCreated", "MoneyDeposited", "MoneyWithdrawn", "AccountClosed",
]

///|
/// 序列化(外部标签制:unit=裸串/载荷=单条目对象;臂序 = 词表序)。
pub impl @serde.Serialize for AccountEvent with fn serialize(self, s) {
  let enum_name = "AccountEvent"
  match self {
    AccountCreated(name, initial) => {
      s.serialize_tuple_variant_begin(
        { enum_name, index: 0, name: "AccountCreated", },
        2,
      )
      s.serialize_tuple_variant_element(name)
      s.serialize_tuple_variant_element(initial)
      s.serialize_tuple_variant_end()
    }
    MoneyDeposited(amount) =>
      s.serialize_newtype_variant(
        { enum_name, index: 1, name: "MoneyDeposited", },
        amount,
      )
    MoneyWithdrawn(amount) =>
      s.serialize_newtype_variant(
        { enum_name, index: 2, name: "MoneyWithdrawn", },
        amount,
      )
    AccountClosed =>
      s.serialize_unit_variant({ enum_name, index: 3, name: "AccountClosed", })
  }
}

///|
/// 反序列化(反读按 index 分派 = 表序;未知 index = UnknownVariant)。
pub impl @serde.Deserialize for AccountEvent with fn deserialize(d) {
  let value = match
    d.deserialize_enum_begin("AccountEvent", account_event_variants) {
    0 => {
      d.deserialize_tuple_begin(2)
      let name = d.deserialize_tuple_next()
      let initial = d.deserialize_tuple_next()
      d.deserialize_tuple_end()
      AccountCreated(name, initial)
    }
    1 => MoneyDeposited(d.deserialize_newtype_variant())
    2 => MoneyWithdrawn(d.deserialize_newtype_variant())
    3 => {
      d.deserialize_unit_variant()
      AccountClosed
    }
    index =>
      raise @serde.UnknownVariant(
        path=d.path(),
        variant=index.to_string(),
        expected=account_event_variants,
      )
  }
  d.deserialize_enum_end()
  value
}

///|
#deprecated("reach it through the `Serialize` bound", skip_current_package=true)
#doc(hidden)
pub extend AccountEvent with @serde.Serialize::{serialize}

///|
#deprecated("reach it through the `Deserialize` bound", skip_current_package=true)
#doc(hidden)
pub extend AccountEvent with @serde.Deserialize::{deserialize}
