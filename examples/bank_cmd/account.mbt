// ===== account.mbt —— 用户手写面（bank_cmd_gen 骨架的配套编写件）=====
// 配对：gen 件封存房 bank_cmd_gen/（mooncmd/examples 下,未下线——
// cmd CLI 产物原样）+ 本房自持 gen 副本（moon.mod 钉 registry 0.2.3）；本件 = 用户实装面模拟形（函数头 + 注释体;
// 非真实现），分区参照 .playground/bank_demo2/account.mbt 手写架构。
// 升格路径：把本文件 ① 段的槽体填进 bank_cmd_gen/account_policy.mbt
// 的占位（stub-zone：regen 仅缺位时落,永不覆写——填过的槽就是真装）。

// ========== ① 裁决 4 槽（必写面；与 gen 的 declare 槽位逐一配对） ==========

///|
pub let account_create_account : (AccountState, String, Int32) -> Result[
  Array[AccountEvent],
  String,
] = (state, name, initial) => {
  // TODO(用户手写): 开户裁决——
  //   守卫:state.is_active = 已激活拒重复开户;name 非空;initial >= 0
  //   通过 → Ok([AccountCreated(name, initial)])
  //   拒绝 → Err("文案")
  // 真役参照（examples/bank/account_policy.mbt 同槽形）:
  //   if state.is_active { Err("account already created") }
  //   else { Ok([AccountCreated(name, initial)]) }
  if state.is_active {
    Err("account already created")
  } else if initial < 0 {
    Err("negative initial balance")
  } else {
    Ok([AccountCreated(name, initial)])
  }
}

///|
pub let account_deposit_money : (AccountState, Int32) -> Result[
  Array[AccountEvent],
  String,
] = (state, amount) => {
  // TODO(用户手写): 存款裁决——
  //   守卫:!state.is_active = 销户拒存;amount > 0
  //   通过 → Ok([MoneyDeposited(amount)])
  // 真役参照:
  //   if !state.is_active { Err("account closed") }
  //   else { Ok([MoneyDeposited(amount)]) }
  if !state.is_active {
    Err("account closed")
  } else if amount <= 0 {
    Err("non-positive deposit")
  } else {
    Ok([MoneyDeposited(amount)])
  }
}

///|
pub let account_withdraw_money : (AccountState, Int32) -> Result[
  Array[AccountEvent],
  String,
] = (state, amount) => {
  // TODO(用户手写): 取款裁决——
  //   守卫:!state.is_active 拒;amount > 0;state.balance < amount 拒（余额足）
  //   通过 → Ok([MoneyWithdrawn(amount)])
  // 真役参照:
  //   if !state.is_active { Err("account closed") }
  //   else if state.balance < amount { Err("insufficient balance") }
  //   else { Ok([MoneyWithdrawn(amount)]) }
  if !state.is_active {
    Err("account closed")
  } else if state.balance < amount {
    Err("insufficient balance")
  } else {
    Ok([MoneyWithdrawn(amount)])
  }
}

///|
pub let account_close_account : (AccountState) -> Result[
  Array[AccountEvent],
  String,
  // TODO(用户手写): 销户裁决——
  //   守卫:!state.is_active = 已销户拒;state.balance != 0 拒（余额清零才销）
  //   通过 → Ok([AccountClosed])
  // 真役参照:
  //   if !state.is_active { Err("account already closed") }
  //   else { Ok([AccountClosed]) }
] = state => {
  if !state.is_active {
    Err("account already closed")
  } else if state.balance != 0 {
    Err("balance must be drained before closing")
  } else {
    Ok([AccountClosed])
  }
}

// ========== ② 编写量台账（本聚合消费者面） ==========

// 必写面 = 裁决 4 槽（本文件 ① 段）:
//   头 ×4 ≈ 12 行(签名折形) + 体 = 真业务行数——真役参照 5-9 行/槽,
//   全填 ≈ 40-55 行（examples/bank/account_policy.mbt = 55 行实证）。
// 选写面（按需,非必写）:
//   事件演化 = 词表 evolve 指令(0 行用户码——gen 直链,本表 AccountCreated
//          即机械链形)或 evolve = ["..."] 委托钩子(+1 闭包 ≈ 3-6 行/事件);
//   装配组合根(main 侧,一次性) ≈ 8-15 行(本文件 bank_flow_sim 注释体);
//   中间件 ≈ 10-15 行/条(三槽壳 + 业务体);
//   PM 件 = 词表径 0 码 + 组合根 8 行,或 trait 手写径净重 ~25 行。

// ========== ③ 选写面一：演化委托钩子（若词表把事件标 ["..."]） ==========
// 槽名 = gen 启用态 declare 形（家法 agg_hook_slot_name:account_<snake(Event)>;
// shelved 期 gen 暂无此 declare——升格启用时以 gen declare 配对为本槽名）。

///|
pub let account_money_deposited : (AccountState, Int32) -> AccountState = (
  _state,
  _amount,
  // TODO(用户手写): 演化体——真实现参照 1 行:
  //   { ..state, balance: state.balance + amount, }
) => abort("TODO(account_money_deposited)")

// ========== ④ 选写面二：装配组合根（main 侧一次性,bank 业务流） ==========

///|
/// 用户组装流真跑：store + glue 桥 + 裁决槽位 → 四命令 + 业务拒 + 落库
/// 重建等价（全过返 true——main ① 段调用）。
pub fn bank_flow_sim() -> Bool raise {
  let id = "sim-account-001"
  let store = @store.SQLiteEventStore::new(
    ":memory:", account_serialize, account_deserialize, account_type_name,
  )
  let root0 = @aggregate.AggregateRoot::new(
    id,
    account_handler,
    @event.EventApplier::Single(account_applier),
    account_empty_state(),
  )
  let root = root0
    .exec(CreateAccount("Demo Holder", 1000))
    .exec(DepositMoney(500))
    .exec(WithdrawMoney(300))
  let flow_ok = root.version() == 3 && root.current_state().balance == 1200
  // 业务拒零痕迹:余额非零销户守卫拒——版本不推、流不加
  let guarded = root.exec(CloseAccount) catch { _ => root }
  let reject_ok = guarded.version() == 3 &&
    guarded.uncommitted_events().length() == 3
  // 落库 + 重放重建等价(from_events ≡ 原态)
  store.append(id, root.uncommitted_events())
  let rebuilt = @aggregate.AggregateRoot::from_events(
    id,
    store.load(id, 0),
    account_handler,
    @event.EventApplier::Single(account_applier),
    account_empty_state(),
  )
  let rebuild_ok = rebuilt.version() == root.version() &&
    rebuilt.current_state().balance == root.current_state().balance &&
    rebuilt.current_state().name == root.current_state().name
  let ok = flow_ok && reject_ok && rebuild_ok
  println(
    "[SIM] bank_flow_sim — 版本 \{root.version()} balance \{root.current_state().balance} 守卫拒 \{reject_ok} 重建 \{rebuild_ok}",
  )
  ok
}

// ========== ⑤ 选写面三：中间件（dispatch 管道,ADR-MC-009） ==========
// 面 = 记录型三槽(name/before/after/failure)——Context 一记录两相位:
// before/failure 相位 events = 空数组、version = 现版本;after 相位
// events = 全量信封、version = 落库后版本。before/after 自身抛错直接
// 穿透不进 failure(防自触发递归);failure 非 raise 形(自兜落,原错恒
// 原样上浮)。接线:dispatch(..., middleware~=[audit_middleware_of(log)])。

///|
/// 审计中间件构造器（log 捕获形——main 点火真发可断言;注释体 = 业务位）
pub fn audit_middleware_of(
  log : Array[String],
) -> @mooncmd.DispatchMiddleware[String, AccountCommand, AccountEvent] {
  {
    name: "audit",
    before: ctx => {
      // TODO(用户手写): 审计开票/幂等键提取/限流预判——
      //   可读 ctx.aggregate_id + ctx.command;events 尚空(未执行)
      log.push("before \{ctx.aggregate_id} events=\{ctx.events.length()}")
    },
    after: ctx => {
      // TODO(用户手写): 审计回执/埋点上报——
      //   ctx.events = 全量事件信封;ctx.version = 落库后版本
      //   逆序执行(洋葱律,Commanded pipeline 同款)
      log.push("after v\{ctx.version} events=\{ctx.events.length()}")
    },
    failure: (ctx, err) => {
      // TODO(用户手写): 告警/对账/死信登记——
      //   只对主链五步错触发;自兜落(原主链错恒原样上浮)
      log.push("failure \{ctx.aggregate_id}")
      let _ = err
    },
  }
}

// ========== ⑥ 选写面四：PM 件（跨聚合编排,ADR-MC-011） ==========
// gen 件已随 wasm cmd --pm-behavior 落本房（transfer_pm_behavior.mbt =
// 五缺省体 trait + 适配器,禁手写）。下面 = 用户实装:最小 name 必填槽 +
// 差异槽覆写（照 bank 转账业务——与 gen 记录面语义孪生）+ 组合根真跑。

///|
priv struct RelayTo {
  target : String
}

///|
// name 必填槽(state_key 命名空间 <名>:<saga_id>)——五缺省自动继承:
// saga_id_of = 信封直读(本业务恰对,零覆写)/init_state = 零值态/
// interested = 不观注/handle = 零发射/apply = 透传。
impl TransferPmBehavior for RelayTo with fn name(_self) -> String {
  "transfer"
}

///|
// 差异槽覆写:watch 封闭集(缺省 false = 惰性安全;覆写才活)
impl TransferPmBehavior for RelayTo with fn interested(_self, e) -> Bool {
  match e {
    MoneyWithdrawn(_) => true
    AccountClosed => true
    _ => false
  }
}

///|
// 差异槽覆写:事件→命令直通映射(缺省 [] = 零发射)——金额保真直通发 target
impl TransferPmBehavior for RelayTo with fn handle(self, _state, e) -> Array[
  @mooncmd.DirectedCommand[AccountCommand],
] {
  match e {
    MoneyWithdrawn(amount) =>
      [{ target_aggregate_id: self.target, command: DepositMoney(amount), }]
    AccountClosed =>
      [{ target_aggregate_id: self.target, command: CloseAccount, }]
    _ => []
  }
}

///|
// 差异槽覆写:saga 态演化(缺省透传)——transferred 累加/closed 置位
impl TransferPmBehavior for RelayTo with fn apply(_self, state, e) -> TransferPmState {
  match e {
    MoneyWithdrawn(amount) =>
      { ..state, transferred: state.transferred + amount, }
    AccountClosed => { ..state, closed: true, }
    _ => state
  }
}

///|
/// 内存 SnapshotStore（PM 组合根样板;生产换持久构造器）
fn pm_memory_store() -> @store.SnapshotStore[String, TransferPmState] {
  let ledger : Array[Map[String, (TransferPmState, Int32)]] = [Map([])]
  {
    save: (key, state, version, _ts) => ledger[0][key] = (state, version),
    load: key => ledger[0].get(key),
  }
}

///|
/// PM 组合根真跑：RelayTo 行为面 → gen 适配器 → 同一台泵（泵序责任在
/// 调用方——EventStore 无全局流）。三对拍 = 命令直通(金额保真发 target)/
/// skip 律(子集外零发射)/saga 态持久(累加+closed@v4)。main ③ 段调用。
pub fn pm_flow_sim() -> Bool raise {
  let pm_sent : Array[(String, AccountCommand)] = []
  // 因果锚捕获:emit_cause 三参槽第三参 = 触发事件信封(0.3.0 新面)
  let pm_cause : Array[String] = []
  // 错误钩子哨兵(0.3.0 新面):本流全过 = 钩子不触发;哨兵留痕演示接线形
  let pm_err_log : Array[String] = [""]
  let store = pm_memory_store()
  let runner = @mooncmd.ProcessManagerRunner::new(
    transfer_pm_of_behavior(RelayTo::{ target: "acc-002", }),
    store,
    (target, cmd) => pm_sent.push((target, cmd)),
    on_error=Hook(err => {
      pm_err_log[0] = err.to_string()
      Raise
    }),
    emit_cause=@mooncmd.PmEmitSink::Sink((
      target : String,
      cmd : AccountCommand,
      msg : @event.EventMessage[String, AccountEvent],
    ) => {
      pm_sent.push((target, cmd))
      pm_cause.push(msg.event_id)
    }),
  )
  // 事件流直喂:两笔取出 + 子集外存入(skip) + 销户(版本位连续)
  let events = [
    @event.EventMessage::new(MoneyWithdrawn(30), "pm-account-1", 1),
    @event.EventMessage::new(MoneyWithdrawn(12), "pm-account-1", 2),
    @event.EventMessage::new(MoneyDeposited(5), "pm-account-1", 3),
    @event.EventMessage::new(AccountClosed, "pm-account-1", 4),
  ]
  let handled = runner.pump_events(events)
  // 命令直通对拍:三令全发 target,金额保真+销户裸令
  let sent_ok = pm_sent.length() == 3 &&
    pm_sent[0].0 == "acc-002" &&
    (match pm_sent[0].1 {
      DepositMoney(n) => n == 30
      _ => false
    }) &&
    (match pm_sent[2].1 {
      CloseAccount => true
      _ => false
    })
  // saga 态持久对拍:transferred 42(30+12 累加)+closed @v4
  // (键 = <pm名>:<saga_id> 命名空间;store 单实例共享——双建即查空)
  let loaded = (store.load)("transfer:pm-account-1") catch { _ => None }
  let saga_ok = match loaded {
    Some((state, version)) =>
      state.transferred == 42 && state.closed && version == 4
    None => false
  }
  // 因果透传对拍:三印 = 三次发射的触发信封 event_id(0.3.0 新面)
  let cause_ok = pm_cause.length() == 3 && pm_cause[0] == events[0].event_id
  let ok = handled == 3 && sent_ok && saga_ok && cause_ok
  println(
    "[SIM] pm_flow_sim — handled \{handled}/4 sent \{pm_sent.length()} saga(42,closed@v4) 因果 \{pm_cause.length()} 印 \{cause_ok}",
  )
  ok
}
