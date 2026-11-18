// ===== transfer PM 装配样板（脚本物化 bootstrap-only；.hand-maintained）=====
// 组合根手改自由（红线7：装配不进词表）；本件落盘后归手维护，
// regen 管线不覆盖（--pm-assembly 显式 out 才重写）。
// 源表：examples/bank/account_pm.toml（词表产物 transfer_pm_gen.mbt = 黄金门逐字节；本件非黄金面）
// 物化：moon run skelschema/cmd -- --pm-assembly <out>（主仓仓根起跑）

///|
/// 内存 SnapshotStore（组合根样板；生产换持久后端构造器）。
fn transfer_pm_asm_store() -> @store.SnapshotStore[
  String,
  @bank.TransferPmState,
] {
  let ledger : Array[Map[String, (@bank.TransferPmState, Int32)]] = [Map([])]
  {
    save: (key, state, version, _ts) => ledger[0][key] = (state, version),
    load: key => ledger[0].get(key),
  }
}

///|
/// runner 构造（emit 闭包 = 命令去向决策，必填显式——无缺省）。
fn transfer_pm_asm_runner(
  emit : (String, @bank.AccountCommand) -> Unit raise @mooncmd.ProcessManagerErr,
) -> @mooncmd.ProcessManagerRunner[
  @bank.TransferPmState,
  @bank.AccountCommand,
  @bank.AccountEvent,
] {
  @mooncmd.ProcessManagerRunner::new(
    @bank.transfer_pm(),
    transfer_pm_asm_store(),
    emit,
  )
}

///|
test "transfer pm assembly smokes: empty flow pumps zero" {
  let sent : Array[(String, @bank.AccountCommand)] = []
  let runner = transfer_pm_asm_runner((target, cmd) => sent.push((target, cmd)))
  let handled = runner.pump_events([])
  assert_eq(handled, 0)
  assert_eq(sent.length(), 0)
}
