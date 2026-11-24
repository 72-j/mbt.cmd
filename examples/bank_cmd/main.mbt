///|
/// bank_cmd 点火入口：main 只做编排——用户件（account.mbt）两段调用：
/// ① 组装流（bank_flow_sim:四命令+业务拒+落库重建）② 中间件真发
/// （dispatch 门面 middleware~ 审计槽:log 捕获可断言）。EXAMPLE:PASS 终判。
fn main raise {
  let mut all_green = true
  // ① 用户组装流（bank_flow_sim——store+glue 桥+裁决槽位全谱）
  all_green = all_green && bank_flow_sim()
  // ② 中间件点火（开户后 dispatch 存款;审计 log 捕获 before+after 两印）
  let store = @store.SQLiteEventStore::new(
    ":memory:", account_serialize, account_deserialize, account_type_name,
  )
  let root = @aggregate.AggregateRoot::new(
    "mw-account-001",
    account_handler,
    @event.EventApplier::Single(account_applier),
    account_empty_state(),
  ).exec(CreateAccount("Demo Holder", 1000))
  let mw_log : Array[String] = []
  let after = @mooncmd.dispatch(
    store.to_event_store(),
    None,
    root,
    DepositMoney(500),
    middleware=[audit_middleware_of(mw_log)],
  )
  let mw_ok = mw_log.length() == 2 && after.current_state().balance == 1500
  all_green = all_green &&
    check(
      "中间件点火",
      mw_ok,
      "audit \{mw_log.length()} 印（before+after）——balance \{after.current_state().balance}",
    )
  // ========== ③ PM 点火（行为面 gen 件 + RelayTo 实装 → 同一台泵真跑） ==========
  all_green = all_green && pm_flow_sim()
  // ========== 终判 ==========
  if all_green {
    println(
      "EXAMPLE:PASS — bank_cmd 点火（用户组装流 + 中间件真发）",
    )
  } else {
    println("EXAMPLE:FAIL — 见上方 [FAIL]/[SIM] 行")
  }
}

///|
/// 断言汇报辅助（PASS/FAIL 双色印;返回布尔供 all_green 合账）。
fn check(label : String, ok : Bool, detail : String) -> Bool {
  let verdict = if ok { "PASS" } else { "FAIL" }
  println("[\{verdict}] \{label} — \{detail}")
  ok
}
