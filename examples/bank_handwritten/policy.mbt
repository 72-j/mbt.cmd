// ===== 裁决策略（配方行 5 的裁决体；红线 7 裁决不入表/不进 apply 链）=====
// 语义与 examples/bank/account_policy.mbt 同界：开户须未激活且初始额非负 /
// 存取须激活 / 存额须正 / 取须余额足 / 销户须余额清零。
// 钩子是纯函数：只读状态、产出事件或 String 拒因——不碰时钟与存储。

///|
pub fn account_hooks() -> AccountDecideHooks {
  {
    create_account: (state, name, initial) => {
      if state.is_active {
        Err("account already created")
      } else if initial < 0 {
        Err("negative initial balance")
      } else {
        Ok([AccountCreated(name, initial)])
      }
    },
    deposit_money: (state, amount) => {
      if !state.is_active {
        Err("account closed")
      } else if amount <= 0 {
        Err("deposit must be positive")
      } else {
        Ok([MoneyDeposited(amount)])
      }
    },
    withdraw_money: (state, amount) => {
      if !state.is_active {
        Err("account closed")
      } else if state.balance < amount {
        Err("insufficient balance")
      } else {
        Ok([MoneyWithdrawn(amount)])
      }
    },
    close_account: state => {
      if state.balance != 0 {
        Err("balance must be zero before closing")
      } else {
        Ok([AccountClosed])
      }
    },
  }
}
