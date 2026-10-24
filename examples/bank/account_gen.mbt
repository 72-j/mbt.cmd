// ===== GENERATED FILE — DO NOT EDIT =====
// 源表：mooncmd/examples/bank/account_agg.toml（schema 1.0）
// 绑定器：skelschema/mooncmd_agg_toml_gen.mbt（聚合方言;gen 骨架+机械演化,
// 裁决 = 策略件手写钩子——mooncmd const.md 红线7-9）
// 再生：改表 → 黄金门测试重生成逐字节对拍

///|
pub(all) struct AccountState {
  name : String
  balance : Int32
  is_active : Bool
} derive(Eq)

///|
pub extend AccountState with Eq::{not_equal, equal}

///|
pub fn AccountState::init() -> AccountState {
  { name: "", balance: 0, is_active: false, }
}

///|
pub(all) enum AccountEvent {
  AccountCreated(String, Int32)
  MoneyDeposited(Int32)
  MoneyWithdrawn(Int32)
  AccountClosed
} derive(Eq)

///|
pub extend AccountEvent with Eq::{not_equal, equal}

///|
pub(all) enum AccountCommand {
  CreateAccount(String, Int32)
  DepositMoney(Int32)
  WithdrawMoney(Int32)
  CloseAccount
} derive(Eq)

///|
pub extend AccountCommand with Eq::{not_equal, equal}

///|
/// 事件演化（机械:evolve 指令逐条链式;同字段后写覆前写）
pub fn AccountEvent::apply(
  self : AccountEvent,
  state : AccountState,
) -> AccountState {
  match self {
    AccountCreated(name, initial) => {
      let s0 = { ..state, name, }
      let s1 = { ..s0, balance: initial, }
      let s2 = { ..s1, is_active: true, }
      s2
    }
    MoneyDeposited(amount) => {
      let s0 = { ..state, balance: state.balance + amount, }
      s0
    }
    MoneyWithdrawn(amount) => {
      let s0 = { ..state, balance: state.balance - amount, }
      s0
    }
    AccountClosed => {
      let s0 = { ..state, is_active: false, }
      s0
    }
  }
}

///|
/// 裁决钩子（记录型函数面,ADR-MC-003 同族;策略件手写实现——红线7 裁决不入表）
pub(all) struct AccountDecideHooks {
  create_account : (AccountState, String, Int32) -> Result[
    Array[AccountEvent],
    String,
  ]
  deposit_money : (AccountState, Int32) -> Result[Array[AccountEvent], String]
  withdraw_money : (AccountState, Int32) -> Result[Array[AccountEvent], String]
  close_account : (AccountState) -> Result[Array[AccountEvent], String]
}

///|
/// 裁决分派骨架（gen 只产分派与载荷拆包;裁决体 = 钩子）
pub fn account_decide(
  state : AccountState,
  cmd : AccountCommand,
  hooks : AccountDecideHooks,
) -> Result[Array[AccountEvent], String] {
  match cmd {
    CreateAccount(name, initial) => (hooks.create_account)(state, name, initial)
    DepositMoney(amount) => (hooks.deposit_money)(state, amount)
    WithdrawMoney(amount) => (hooks.withdraw_money)(state, amount)
    CloseAccount => (hooks.close_account)(state)
  }
}

///|
/// wire 映射（役7+ D-MG-6;行格式 = "1\t<Event>\t<fields...>";首列 = schema_version 预留位,现版只认 1）
pub fn AccountEvent::to_wire(self : AccountEvent) -> String {
  match self {
    AccountCreated(name, initial) => "1\tAccountCreated\t\{name}\t\{initial}"
    MoneyDeposited(amount) => "1\tMoneyDeposited\t\{amount}"
    MoneyWithdrawn(amount) => "1\tMoneyWithdrawn\t\{amount}"
    AccountClosed => "1\tAccountClosed"
  }
}

///|
/// 行格式解析（坏载荷 = None;首列只认 "1"——schema_version 预留位）
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
/// 行格式整数字段解析（wire 专用;非数字形 = 0——格式对齐由 parts 校验与 roundtrip 契约兜底）
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
