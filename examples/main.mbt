///|
/// mooncmd 全链自证示例（可执行）：银行账户聚合从定义到落库的一跑。
/// 叙事序 = 消费方接入序：① 定义聚合 → ② 内存命令链 → ③ SQLite 落库
/// 与重放重建 → ④ 乐观并发拒写 → ⑤ 销户闭环 → ⑥ 快照加速等价。
/// 终行 EXAMPLE:PASS。

///|
/// ① 聚合三件套（消费方自定义）：状态 / 命令 / 事件
struct DemoAccountState {
  name : String
  balance : Int32
  is_active : Bool
}

///|
enum DemoCommand {
  CreateAccount(String, Int32)
  DepositMoney(Int32)
  WithdrawMoney(Int32)
  CloseAccount
}

///|
enum DemoEvent {
  AccountCreated(String, Int32)
  MoneyDeposited(Int32)
  MoneyWithdrawn(Int32)
  AccountClosed
}

///|
/// 命令处理器：纯函数——只做业务裁决，返回纯事件，不碰元数据不碰存储
fn demo_handler(
  state : DemoAccountState,
  cmd : DemoCommand,
) -> Result[Array[DemoEvent], @mooncmd.CommandError] {
  match cmd {
    CreateAccount(name, initial_balance) =>
      if state.is_active {
        Err(@mooncmd.CommandError::InvalidCommand("Account already exists"))
      } else if initial_balance < 0 {
        Err(
          @mooncmd.CommandError::InvalidCommand(
            "Initial balance cannot be negative",
          ),
        )
      } else {
        Ok([AccountCreated(name, initial_balance)])
      }
    DepositMoney(amount) =>
      if !state.is_active {
        Err(@mooncmd.CommandError::InvalidCommand("Account is not active"))
      } else if amount <= 0 {
        Err(
          @mooncmd.CommandError::InvalidCommand(
            "Deposit amount must be positive",
          ),
        )
      } else {
        Ok([MoneyDeposited(amount)])
      }
    WithdrawMoney(amount) =>
      if !state.is_active {
        Err(@mooncmd.CommandError::InvalidCommand("Account is not active"))
      } else if amount > state.balance {
        Err(@mooncmd.CommandError::InvalidCommand("Insufficient funds"))
      } else {
        Ok([MoneyWithdrawn(amount)])
      }
    CloseAccount =>
      if state.balance != 0 {
        Err(
          @mooncmd.CommandError::InvalidCommand(
            "Cannot close account with non-zero balance",
          ),
        )
      } else {
        Ok([AccountClosed])
      }
  }
}

///|
/// 事件应用器：纯函数——事件是事实，应用即演进状态
fn demo_applier(
  state : DemoAccountState,
  event : DemoEvent,
) -> DemoAccountState {
  match event {
    AccountCreated(name, initial_balance) =>
      { name, balance: initial_balance, is_active: true, }
    MoneyDeposited(amount) => { ..state, balance: state.balance + amount, }
    MoneyWithdrawn(amount) => { ..state, balance: state.balance - amount, }
    AccountClosed => { ..state, is_active: false, }
  }
}

///|
fn demo_empty_state() -> DemoAccountState {
  { name: "", balance: 0, is_active: false, }
}

///|
/// 事件序列化（演示用最简手写形；消费方可换 json/protobuf）
fn demo_serialize(event : DemoEvent) -> Bytes {
  let text = match event {
    AccountCreated(name, amount) => "created:\{name}:\{amount}"
    MoneyDeposited(amount) => "deposited:\{amount}"
    MoneyWithdrawn(amount) => "withdrawn:\{amount}"
    AccountClosed => "closed"
  }
  @utf8.encode(text)
}

///|
fn demo_deserialize(data : Bytes) -> DemoEvent raise {
  let text = @utf8.decode(data)
  let parts = text.split(":").collect()
  if parts.length() == 3 && parts[0] == "created" {
    return AccountCreated(parts[1].to_owned(), parse_int(parts[2].to_owned()))
  }
  if parts.length() == 2 && parts[0] == "deposited" {
    return MoneyDeposited(parse_int(parts[1].to_owned()))
  }
  if parts.length() == 2 && parts[0] == "withdrawn" {
    return MoneyWithdrawn(parse_int(parts[1].to_owned()))
  }
  if text == "closed" {
    return AccountClosed
  }
  abort("bad event payload: \{text}")
}

///|
fn demo_type_name(event : DemoEvent) -> String {
  match event {
    AccountCreated(_, _) => "AccountCreated"
    MoneyDeposited(_) => "MoneyDeposited"
    MoneyWithdrawn(_) => "MoneyWithdrawn"
    AccountClosed => "AccountClosed"
  }
}

///|
fn parse_int(text : String) -> Int32 {
  let mut value = 0
  for byte in text.iter() {
    if byte >= '0' && byte <= '9' {
      value = value * 10 + (byte.to_int() - 48)
    }
  }
  value
}

///|
fn check(label : String, ok : Bool, detail : String) -> Bool {
  let verdict = if ok { "PASS" } else { "FAIL" }
  println("[\{verdict}] \{label} — \{detail}")
  ok
}

///|
fn main raise {
  let mut all_green = true
  let aggregate_id = "demo-account-001"
  // ========== ② 内存命令链：命令 → 纯事件 → EventMessage 自动包装 ==========
  let aggregate = @mooncmd.AggregateRoot::new(
    aggregate_id,
    demo_handler,
    @mooncmd.EventApplier::Single(demo_applier),
    demo_empty_state(),
  )
  let aggregate = match
    aggregate.execute(
      @mooncmd.CommandMessage::new(CreateAccount("Demo Holder", 1000)),
    ) {
    Ok(agg) => agg
    Err(e) => {
      println("[FAIL] 开户命令被拒：\{e.to_string()}")
      return
    }
  }
  let aggregate = match
    aggregate.execute(@mooncmd.CommandMessage::new(DepositMoney(500))) {
    Ok(agg) => agg
    Err(e) => {
      println("[FAIL] 存款命令被拒：\{e.to_string()}")
      return
    }
  }
  let aggregate = match
    aggregate.execute(@mooncmd.CommandMessage::new(WithdrawMoney(300))) {
    Ok(agg) => agg
    Err(e) => {
      println("[FAIL] 取款命令被拒：\{e.to_string()}")
      return
    }
  }
  let chain_ok = aggregate.version() == 3
  all_green = all_green &&
    check("内存命令链", chain_ok, "版本 = \{aggregate.version()}")
  let state = aggregate.current_state()
  let state_ok = state.balance == 1200 && state.is_active
  all_green = all_green &&
    check(
      "状态演进",
      state_ok,
      "balance = \{state.balance}, active = \{state.is_active}",
    )
  // 元数据自动包装佐证：版本 1..3 连续、schema_version 预留位在
  let uncommitted = aggregate.uncommitted_events()
  let meta_ok = uncommitted.length() == 3 &&
    uncommitted[0].aggregate_version == 1 &&
    uncommitted[2].aggregate_version == 3
  all_green = all_green &&
    check(
      "元数据自动包装",
      meta_ok,
      "3 事件，版本 1..3，schema_version = \{uncommitted[0].schema_version}",
    )
  // ========== ③ SQLite 落库 + 重放重建 ==========
  let store = @mooncmd.SQLiteEventStore::new(
    ":memory:", demo_serialize, demo_deserialize, demo_type_name,
  )
  store.append(aggregate_id, uncommitted)
  let loaded = store.load(aggregate_id, 0)
  let load_ok = loaded.length() == 3
  all_green = all_green &&
    check("落库读回", load_ok, "load 回 \{loaded.length()} 事件")
  let rebuilt = @mooncmd.AggregateRoot::from_events(
    aggregate_id,
    loaded,
    demo_handler,
    @mooncmd.EventApplier::Single(demo_applier),
    demo_empty_state(),
  )
  let rebuilt_state = rebuilt.current_state()
  let rebuild_ok = rebuilt.version() == aggregate.version() &&
    rebuilt_state.balance == state.balance &&
    rebuilt_state.name == state.name
  all_green = all_green &&
    check(
      "重放重建等价",
      rebuild_ok,
      "重建版本 \{rebuilt.version()} / balance \{rebuilt_state.balance} / 户名 \{rebuilt_state.name}",
    )
  // ========== ④ 乐观并发：旧批次重放即拒（DuplicateVersion，不落脏）==========
  let mut conflict_rejected = false
  store.append(aggregate_id, uncommitted) catch {
    err =>
      match err {
        @mooncmd.EventStoreError::DuplicateVersion(current) => {
          println(
            "[PASS] 乐观并发拒写 — DuplicateVersion: 当前版本 \{current}",
          )
          conflict_rejected = true
        }
        _ => println("[FAIL] 乐观并发 — 非预期错误形")
      }
  }
  all_green = all_green && conflict_rejected
  let version_after_reject = store.current_version(aggregate_id)
  let clean_ok = version_after_reject == 3
  all_green = all_green &&
    check(
      "拒写不落脏",
      clean_ok,
      "当前版本仍 = \{version_after_reject}",
    )
  // ========== ⑤ 销户闭环：余额清零 → CloseAccount（AccountClosed 事件）==========
  let closable = @mooncmd.AggregateRoot::from_events(
    aggregate_id,
    store.load(aggregate_id, 0),
    demo_handler,
    @mooncmd.EventApplier::Single(demo_applier),
    demo_empty_state(),
  )
  let closable = match
    closable.execute(@mooncmd.CommandMessage::new(WithdrawMoney(1200))) {
    Ok(agg) => agg
    Err(e) => {
      println("[FAIL] 清零取款被拒：\{e.to_string()}")
      return
    }
  }
  let closed = match
    closable.execute(@mooncmd.CommandMessage::new(CloseAccount)) {
    Ok(agg) => agg
    Err(e) => {
      println("[FAIL] 销户命令被拒：\{e.to_string()}")
      return
    }
  }
  let closed_state = closed.current_state()
  let close_ok = closed_state.balance == 0 && !closed_state.is_active
  all_green = all_green &&
    check(
      "销户闭环",
      close_ok,
      "户名 \{closed_state.name}，balance = \{closed_state.balance}，active = \{closed_state.is_active}",
    )
  // ========== ⑥ 快照加速：销户事件入库；快照@v3 全量态 + 尾部 v4/v5 重放 ≡ 全量 ==========
  store.append(aggregate_id, closed.uncommitted_events())
  let snapshottable = @mooncmd.AggregateRoot::from_events(
    aggregate_id,
    loaded,
    demo_handler,
    @mooncmd.EventApplier::Single(demo_applier),
    demo_empty_state(),
  )
  let snapshot = snapshottable.to_snapshot()
  let from_snapshot = @mooncmd.AggregateRoot::from_events(
    aggregate_id,
    store.load(aggregate_id, snapshot.version),
    demo_handler,
    @mooncmd.EventApplier::Single(demo_applier),
    snapshot.state,
  )
  let snap_state = from_snapshot.current_state()
  let snap_ok = from_snapshot.version() == 5 &&
    snap_state.balance == 0 &&
    !snap_state.is_active
  all_green = all_green &&
    check(
      "快照等价",
      snap_ok,
      "快照@v\{snapshot.version}（balance \{snapshot.state.balance}）+ 尾部重放 → v\{from_snapshot.version()}，balance \{snap_state.balance}",
    )
  // 与全量重放对照：两径同果
  let full_replay = @mooncmd.AggregateRoot::from_events(
    aggregate_id,
    store.load(aggregate_id, 0),
    demo_handler,
    @mooncmd.EventApplier::Single(demo_applier),
    demo_empty_state(),
  )
  let full_state = full_replay.current_state()
  let equiv_ok = full_replay.version() == from_snapshot.version() &&
    full_state.balance == snap_state.balance &&
    full_state.is_active == snap_state.is_active &&
    full_state.name == snap_state.name
  all_green = all_green &&
    check(
      "两径同果",
      equiv_ok,
      "快照径 ≡ 全量径：v\{full_replay.version()} / balance \{full_state.balance} / 户名 \{full_state.name}",
    )
  // ========== 终判 ==========
  if all_green {
    println(
      "EXAMPLE:PASS — mooncmd 全链自证（聚合/命令/事件/落库/并发/销户/快照）",
    )
  } else {
    println("EXAMPLE:FAIL — 见上方 [FAIL] 行")
  }
}
