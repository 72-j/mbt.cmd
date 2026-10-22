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
pub fn AccountState::init() -> AccountState {
  { name: "", balance: 0, is_active: false,  }
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
      let s0 = { ..state, name: name }
      let s1 = { ..s0, balance: initial }
      let s2 = { ..s1, is_active: true }
      s2
    }
    MoneyDeposited(amount) => {
      let s0 = { ..state, balance: state.balance + amount }
      s0
    }
    MoneyWithdrawn(amount) => {
      let s0 = { ..state, balance: state.balance - amount }
      s0
    }
    AccountClosed => {
      let s0 = { ..state, is_active: false }
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
  deposit_money : (AccountState, Int32) -> Result[
    Array[AccountEvent],
    String,
  ]
  withdraw_money : (AccountState, Int32) -> Result[
    Array[AccountEvent],
    String,
  ]
  close_account : (AccountState) -> Result[
    Array[AccountEvent],
    String,
  ]
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
