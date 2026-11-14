// 役13b 罐:词表 gen 产物消费面——transfer_pm() 记录面经 ProcessManagerRunner
// 真泵(直通映射语义对拍 13a 手写参照罐;四钉 = 全链持久 / 命令直通 /
// 子集 skip 律 / 零载荷臂)。夹具 pm_gen_ 前缀自建(黑盒跨文件命名空间)。

///|
// 内存 SnapshotStore(记录面直构;引用型闭包捕获 Map 单元)。
fn pm_gen_store() -> @store.SnapshotStore[String, @bank.TransferPmState] {
  let ledger : Array[Map[String, (@bank.TransferPmState, Int32)]] = [Map([])]
  {
    save: (key, state, version, _ts) => ledger[0][key] = (state, version),
    load: key => ledger[0].get(key),
  }
}

///|
test "pm gen: transfer_pm record face pumps end to end" {
  let store = pm_gen_store()
  let sent : Array[(String, @bank.AccountCommand)] = []
  let runner = @mooncmd.ProcessManagerRunner::new(@bank.transfer_pm(), store, (
    target,
    cmd,
  ) => sent.push((target, cmd)))
  // 钉1 全链:withdraw 30 → DepositMoney(30) 发往 account-2,状态持久。
  let m1 = @event.EventMessage::new(@bank.MoneyWithdrawn(30), "account-1", 1)
  let handled1 = runner.pump_event(m1) catch {
    e => fail("pm gen first pump failed: \{e.to_string()}")
  }
  assert_true(handled1)
  assert_eq(sent.length(), 1)
  assert_eq(sent[0].0, "account-2")
  match sent[0].1 {
    @bank.DepositMoney(n) => assert_eq(n, 30)
    _ => fail("pm gen: want DepositMoney passthrough")
  }
  // 钉2 子集 skip 律:MoneyDeposited 在事件封闭集但不在 watch 表 →
  // interested false,零发射零态变。
  let m2 = @event.EventMessage::new(@bank.MoneyDeposited(5), "account-1", 2)
  let handled2 = runner.pump_event(m2) catch {
    e => fail("pm gen skip pump failed: \{e.to_string()}")
  }
  assert_false(handled2)
  assert_eq(sent.length(), 1)
  // 钉3 saga 累加:同 saga 第二事件 load 命中,transferred 30+12=42。
  let m3 = @event.EventMessage::new(@bank.MoneyWithdrawn(12), "account-1", 3)
  let handled3 = runner.pump_event(m3) catch {
    e => fail("pm gen accumulate pump failed: \{e.to_string()}")
  }
  assert_true(handled3)
  assert_eq(sent.length(), 2)
  let loaded = (store.load)("transfer:account-1") catch { _ => None }
  match loaded {
    Some((state, version)) => {
      assert_eq(state.transferred, 42)
      assert_eq(version, 3)
    }
    None => fail("pm gen: saga state missing")
  }
  // 钉4 零载荷臂:AccountClosed → 裸 CloseAccount 构造,closed=true 演化。
  let m4 = @event.EventMessage::new(@bank.AccountClosed, "account-1", 4)
  let handled4 = runner.pump_event(m4) catch {
    e => fail("pm gen close pump failed: \{e.to_string()}")
  }
  assert_true(handled4)
  assert_eq(sent.length(), 3)
  match sent[2].1 {
    @bank.CloseAccount => ()
    _ => fail("pm gen: want bare CloseAccount")
  }
  let loaded2 = (store.load)("transfer:account-1") catch { _ => None }
  match loaded2 {
    Some((state, _version)) => assert_true(state.closed)
    None => fail("pm gen: state missing after close")
  }
}
