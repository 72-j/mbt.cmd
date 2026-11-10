// ===== wire 序列化（配方行 6）=====
// 行格式 = "1\t<Event>\t<fields...>"；首列 = schema_version 预留位
// （现版只认 "1"，坏载荷返 None）。落库配 @utf8.encode/decode 即可
// （SQLiteEventStore 的 serialize / deserialize 槽位）。

///|
pub fn AccountEvent::to_wire(self : AccountEvent) -> String {
  match self {
    AccountCreated(name, initial) => "1\tAccountCreated\t\{name}\t\{initial}"
    MoneyDeposited(amount) => "1\tMoneyDeposited\t\{amount}"
    MoneyWithdrawn(amount) => "1\tMoneyWithdrawn\t\{amount}"
    AccountClosed => "1\tAccountClosed"
  }
}

///|
// 行格式解析（坏载荷 = None；首列只认 "1"——schema_version 预留位；
// 事件名与元数双校验，缺一返 None）。
pub fn AccountEvent::from_wire(text : String) -> AccountEvent? {
  let parts = text.split("\t").collect()
  if parts.length() < 2 {
    return None
  }
  if parts[0] != "1" {
    return None
  }
  if parts[1] == "AccountCreated" && parts.length() == 4 {
    return Some(
      AccountCreated(parts[2].to_owned(), account_wire_int(parts[3].to_owned())),
    )
  }
  if parts[1] == "MoneyDeposited" && parts.length() == 3 {
    return Some(MoneyDeposited(account_wire_int(parts[2].to_owned())))
  }
  if parts[1] == "MoneyWithdrawn" && parts.length() == 3 {
    return Some(MoneyWithdrawn(account_wire_int(parts[2].to_owned())))
  }
  if parts[1] == "AccountClosed" && parts.length() == 2 {
    return Some(AccountClosed)
  }
  None
}

///|
// 行格式整数字段解析（wire 专用；非数字形 = 0——格式对齐由 parts 校验与
// roundtrip 契约兜底）。
fn account_wire_int(text : String) -> Int32 {
  let mut value : Int32 = 0
  let mut sign : Int32 = 1
  for ch in text.iter() {
    if ch == '-' {
      sign = -1
    } else if ch >= '0' && ch <= '9' {
      value = value * 10 + (ch.to_int() - 48)
    } else {
      return 0
    }
  }
  value * sign
}
