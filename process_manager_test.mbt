// 役13a 罐:PM 框架面五钉(mirror saga 手写参照实现——役13b gen 化的
// oracle;双实现罐面先例:gen 产物行为对拍此罐面语义)。
// 夹具 pm_ 前缀自建(黑盒伪包跨文件共享命名空间,不撞 e2e/sr 族)。

///|
struct PmState {
  stage : Int32
}

///|
enum PmCommand {
  Mark(Int32)
}

///|
#derive(Eq)
enum PmEvent {
  Poked(Int32)
  Touched(Int32)
}

///|
// 内存 SnapshotStore(记录面直构;引用型闭包捕获 Map 单元,多钉独立实例零串扰)。
fn pm_mem_store() -> @store.SnapshotStore[String, PmState] {
  let ledger : Array[Map[String, (PmState, Int32)]] = [Map([])]
  {
    save: (key, state, version, _ts) => ledger[0][key] = (state, version),
    load: key => ledger[0].get(key),
  }
}

///|
// runner 构造 helper:emit 收账 + 可选第 N 次 emit raise(0 = 不失败;
// calls 数组引用型捕获,罐侧读计数)。
fn pm_runner(
  sent : Array[(String, Int32)],
  calls : Array[Int32],
  fail_nth_emit : Int32,
  store : @store.SnapshotStore[String, PmState],
) -> @mooncmd.ProcessManagerRunner[PmState, PmCommand, PmEvent] {
  @mooncmd.ProcessManagerRunner::new(
    {
      name: "mirror",
      init_state: () => { stage: 0, },
      interested: e => e is Poked(_),
      saga_id_of: msg => msg.aggregate_id,
      handle: (_state, e) => {
        match e {
          Poked(n) => [{ target_aggregate_id: "mirror-1", command: Mark(n), }]
          Touched(_) => []
        }
      },
      apply: (state, e) => {
        match e {
          Poked(n) => { stage: state.stage + n, }
          Touched(_) => state
        }
      },
    },
    store,
    (target, cmd) => {
      calls[0] = calls[0] + 1
      if fail_nth_emit > 0 && calls[0] == fail_nth_emit {
        raise EmitFailed("boom")
      }
      let n = match cmd {
        Mark(n) => n
      }
      sent.push((target, n))
    },
  )
}

///|
// 事件信封便捷件(version 槽真版本)。
fn pm_msg(
  event : PmEvent,
  aggregate_id : String,
  version : Int32,
) -> @event.EventMessage[String, PmEvent] {
  @event.EventMessage::new(event, aggregate_id, version)
}

///|
// 钉1 全链:interested 命中 → init 态 → handle 产命令 → emit 收账 →
// apply 演化 → save 持久;第二事件 load 命中(不走 init)继续累加。
test "pm nail 1: full chain + persistence across events" {
  let sent : Array[(String, Int32)] = []
  let calls : Array[Int32] = [0]
  let store = pm_mem_store()
  let runner = pm_runner(sent, calls, 0, store)
  let m1 = pm_msg(Poked(5), "s1", 1)
  let handled1 = runner.pump_event(m1) catch {
    e => fail("nail1 first pump failed: \{e.to_string()}")
  }
  assert_true(handled1)
  assert_eq(sent.length(), 1)
  assert_eq(sent[0].0, "mirror-1")
  assert_eq(sent[0].1, 5)
  let m2 = pm_msg(Poked(3), "s1", 2)
  let handled2 = runner.pump_event(m2) catch {
    e => fail("nail1 second pump failed: \{e.to_string()}")
  }
  assert_true(handled2)
  // 状态累加 = 第二事件 load 命中已存态(stage 5),apply 加 3。
  let loaded = (store.load)("mirror:s1") catch { _ => None }
  match loaded {
    Some((state, version)) => {
      assert_eq(state.stage, 8)
      assert_eq(version, 2)
    }
    None => fail("nail1 state not persisted")
  }
}

///|
// 钉2 skip 律:非 interested 事件静默跳过——零发射零态变零持久,返 false。
test "pm nail 2: uninterested events skip silently" {
  let sent : Array[(String, Int32)] = []
  let calls : Array[Int32] = [0]
  let store = pm_mem_store()
  let runner = pm_runner(sent, calls, 0, store)
  let m = pm_msg(Touched(9), "s2", 1)
  let handled = runner.pump_event(m) catch {
    e => fail("nail2 pump failed: \{e.to_string()}")
  }
  assert_false(handled)
  assert_eq(sent.length(), 0)
  assert_eq(calls[0], 0)
  let loaded = (store.load)("mirror:s2") catch { _ => None }
  assert_true(loaded is None)
}

///|
// 钉3 saga 分片律:同 runner 两 saga id 各持独立态——互不串账。
test "pm nail 3: two sagas isolated state" {
  let sent : Array[(String, Int32)] = []
  let calls : Array[Int32] = [0]
  let store = pm_mem_store()
  let runner = pm_runner(sent, calls, 0, store)
  let m1 = pm_msg(Poked(5), "sa", 1)
  let handled1 = runner.pump_event(m1) catch {
    e => fail("nail3 sa pump failed: \{e.to_string()}")
  }
  assert_true(handled1)
  let m2 = pm_msg(Poked(3), "sb", 1)
  let handled2 = runner.pump_event(m2) catch {
    e => fail("nail3 sb pump failed: \{e.to_string()}")
  }
  assert_true(handled2)
  let state_a = (store.load)("mirror:sa") catch { _ => None }
  let state_b = (store.load)("mirror:sb") catch { _ => None }
  match (state_a, state_b) {
    (Some((a, _)), Some((b, _))) => {
      assert_eq(a.stage, 5)
      assert_eq(b.stage, 3)
    }
    (_, _) => fail("nail3 states missing")
  }
}

///|
// 钉4 fail-fast 律:第 2 次 emit raise → EmitFailed 透传,状态不推进
// (apply/save 不执行);重喂同事件重发两命令(exactly-once 责任在泵序,
// ADR-MC-011 D4 语义钉)。handle 产双命令需专用 runner(fail_nth=2)。
test "pm nail 4: emit failure fast-fail, state not advanced" {
  let sent : Array[(String, Int32)] = []
  let calls : Array[Int32] = [1]
  let store = pm_mem_store()
  let runner = pm_runner(sent, calls, 2, store)
  let m = pm_msg(Poked(7), "s4", 1)
  let tag : Array[String] = [""]
  let outcome = runner.pump_event(m) catch {
    e => {
      tag[0] = match e {
        EmitFailed(_) => "EmitFailed"
        StateFailed(_) => "StateFailed"
      }
      false
    }
  }
  assert_false(outcome)
  assert_eq(tag[0], "EmitFailed")
  assert_eq(sent.length(), 0)
  // calls 预置 1 → 本次第 2 次调用即 raise(双命令第一发就咬第 2 次)。
  // 状态不推进 = save 未执行 = load 仍 None。
  let loaded = (store.load)("mirror:s4") catch { _ => None }
  assert_true(loaded is None)
  // 重喂(重置哨兵):calls 已 = 2,fail_nth=2 不再命中(calls 只增)。
  // 用新 runner + 复用 store 验状态真空窗:重喂前 store 无态。
  let sent2 : Array[(String, Int32)] = []
  let calls2 : Array[Int32] = [0]
  let runner2 = pm_runner(sent2, calls2, 0, store)
  let outcome2 = runner2.pump_event(m) catch {
    e => fail("nail4 repump failed: \{e.to_string()}")
  }
  assert_true(outcome2)
  assert_eq(sent2.length(), 1)
  assert_eq(sent2[0].1, 7)
  // 且重喂是重发(原 runner 的 sent 零沉淀——第一发就咬第 2 次)。
  assert_eq(sent.length(), 0)
}

///|
// 钉5 既有态装载律:pump 前 seed 快照(绕 runner 直写 store,模拟 saga
// 中断重启的恢复面)——load 命中不走 init,apply 从 seed 态继续演化。
test "pm nail 5: seeded state loaded instead of init" {
  let sent : Array[(String, Int32)] = []
  let calls : Array[Int32] = [0]
  let store = pm_mem_store()
  (store.save)("mirror:s5", { stage: 100, }, 3, 0L) catch {
    _ => fail("nail5 seed failed")
  }
  let runner = pm_runner(sent, calls, 0, store)
  let m = pm_msg(Poked(5), "s5", 4)
  let handled = runner.pump_event(m) catch {
    e => fail("nail5 pump failed: \{e.to_string()}")
  }
  assert_true(handled)
  assert_eq(sent[0].1, 5)
  let loaded = (store.load)("mirror:s5") catch { _ => None }
  match loaded {
    Some((state, version)) => {
      assert_eq(state.stage, 105)
      assert_eq(version, 4)
    }
    None => fail("nail5 state missing")
  }
}

///|
// 钉7(0.3.0)·错误钩子 Skip:emit 首发即咬 → 钩子 Skip 吞错 →
// pump 返 false(事件弃处理),saga 态不落,零 raise。
// 已发不撤(at-least-once):本罐 fail 在首发 = 零已发;部分已发形态
// 由钉4 覆盖(透传径)。
test "pm error hook skip swallows emit failure" {
  let store = pm_mem_store()
  let hook_err : Array[String] = [""]
  let runner = @mooncmd.ProcessManagerRunner::new(
    {
      name: "skip",
      init_state: () => { stage: 0, },
      interested: e => e is Poked(_),
      saga_id_of: msg => msg.aggregate_id,
      handle: (_state, e) => {
        match e {
          Poked(n) => [{ target_aggregate_id: "t1", command: Mark(n), }]
          Touched(_) => []
        }
      },
      apply: (state, e) => {
        match e {
          Poked(n) => { stage: state.stage + n, }
          Touched(_) => state
        }
      },
    },
    store,
    (_target, _cmd) => raise EmitFailed("boom"),
    on_error=Hook(err => {
      hook_err[0] = err.to_string()
      Skip
    }),
  )
  let handled = runner.pump_event(pm_msg(Poked(5), "s7", 1))
  assert_false(handled) // Skip = 弃处理(与未处理同形计数)
  assert_true(hook_err[0].contains("boom")) // 钩子收原错
  let loaded = (store.load)("skip:s7") catch { _ => None }
  assert_true(loaded is None) // 状态不落
}

///|
// 钉8·错误钩子 Raise 臂显式形:与透传缺省同果(原错原样上浮)。
test "pm error hook raise re-raises typed" {
  let store = pm_mem_store()
  let runner = @mooncmd.ProcessManagerRunner::new(
    {
      name: "raise-hook",
      init_state: () => { stage: 0, },
      interested: e => e is Poked(_),
      saga_id_of: msg => msg.aggregate_id,
      handle: (_state, e) => {
        match e {
          Poked(n) => [{ target_aggregate_id: "t1", command: Mark(n), }]
          Touched(_) => []
        }
      },
      apply: (state, e) => {
        match e {
          Poked(n) => { stage: state.stage + n, }
          Touched(_) => state
        }
      },
    },
    store,
    (_target, _cmd) => raise EmitFailed("boom"),
    on_error=Hook(_err => Raise),
  )
  let mut tagged = ""
  let handled = runner.pump_event(pm_msg(Poked(5), "s8", 1)) catch {
    e => {
      tagged = match e {
        EmitFailed(_) => "EmitFailed"
        StateFailed(_) => "StateFailed"
      }
      false
    }
  }
  assert_false(handled)
  assert_eq(tagged, "EmitFailed")
}

///|
// save 炸仓夹具(save 面 StorageError;load 面 None)。
fn pm_fail_save_store() -> @store.SnapshotStore[String, PmState] {
  {
    save: (_key, _state, _version, _ts) => {
      raise @store.SnapshotError::StorageError("save-boom")
    },
    load: _key => None,
  }
}

///|
// 钉9·错误钩子 Skip 于 save 面:状态不推进(handle 已发命令不撤——
// at-least-once 已发不撤),泵继续。
test "pm error hook skip swallows save failure" {
  let store = pm_fail_save_store()
  let sent : Array[(String, Int32)] = []
  let calls : Array[Int32] = [0]
  let runner = @mooncmd.ProcessManagerRunner::new(
    {
      name: "skip-save",
      init_state: () => { stage: 0, },
      interested: e => e is Poked(_),
      saga_id_of: msg => msg.aggregate_id,
      handle: (_state, e) => {
        match e {
          Poked(n) => [{ target_aggregate_id: "t1", command: Mark(n), }]
          Touched(_) => []
        }
      },
      apply: (state, e) => {
        match e {
          Poked(n) => { stage: state.stage + n, }
          Touched(_) => state
        }
      },
    },
    store,
    (target, cmd) => {
      calls[0] = calls[0] + 1
      let n = match cmd {
        Mark(n) => n
      }
      sent.push((target, n))
    },
    on_error=Hook(_err => Skip),
  )
  let handled = runner.pump_event(pm_msg(Poked(5), "s9", 1)) catch {
    _ => false
  }
  assert_false(handled) // skip = 弃处理
  assert_eq(calls[0], 1) // 命令已发不撤(at-least-once)
  assert_eq(sent.length(), 1)
}

///|
// 钉10(0.3.0)·emit_msg 因果槽:sink 收触发事件信封(因果锚可用)——
// 消费方 caused_by 组链:correlation 承父/causation = 父 event_id。
test "pm emit_msg sink exposes triggering envelope for causation" {
  let store = pm_mem_store()
  let seen_msgs : Array[@event.EventMessage[String, PmEvent]] = []
  let runner = @mooncmd.ProcessManagerRunner::new(
    {
      name: "sink",
      init_state: () => { stage: 0, },
      interested: e => e is Poked(_),
      saga_id_of: msg => msg.aggregate_id,
      handle: (_state, e) => {
        match e {
          Poked(n) => [{ target_aggregate_id: "t1", command: Mark(n), }]
          Touched(_) => []
        }
      },
      apply: (state, e) => {
        match e {
          Poked(n) => { stage: state.stage + n, }
          Touched(_) => state
        }
      },
    },
    store,
    (_target, _cmd) => (),
    emit_cause=@mooncmd.PmEmitSink::Sink((_target, _cmd, msg) => {
      seen_msgs.push(msg)
    }),
  )
  let m = pm_msg(Poked(5), "s10", 1)
  let handled = runner.pump_event(m)
  assert_true(handled)
  assert_eq(seen_msgs.length(), 1)
  assert_eq(seen_msgs[0].event_id, m.event_id) // 因果锚 = 触发信封
  // 消费方组链(caused_by 构造器:correlation 承父/causation = 父 event_id)
  let child = @event.EventMessage::caused_by(
    seen_msgs[0],
    Poked(9),
    "s10-child",
    1,
  )
  assert_eq(child.causation_id, m.event_id)
  assert_eq(child.correlation_id, m.correlation_id)
}
