///|
/// cmd/gen PM 方言黑盒测试面（役13b 体保真搬运随件——与 agg_toml_gen_test
/// 同谱:@gen 限定 + for "test" 授亲 + golden 字节探针 = 治理②漂移探测器
/// 本体:bank PM 表 → 期望产物 = 主仓已提交 account_pm_gen.mbt 字节
/// (溯源三件换算三行,产物体零漂)。
const PM_SAMPLE : String =
  #|schema_version = "0.2.0"
  #|generator = "skelschema/pm_toml_gen.mbt"
  #|target_package = "thy1016/cmd/samples"
  #|
  #|[process_manager]
  #|name = "relay"
  #|event_type = "OrderEvent"
  #|command_type = "OrderCommand"
  #|saga_key = "aggregate_id"
  #|
  #|[process_manager.state]
  #|
  #|[[process_manager.state.fields]]
  #|name = "paid"
  #|type = "bool"
  #|init = "false"
  #|
  #|[[process_manager.watch]]
  #|event = "OrderPaid"
  #|fields = [ { name = "amount", type = "int" } ]
  #|target = "warehouse-1"
  #|emit = [ { command = "ShipOrder", args = ["amount=amount"] } ]
  #|apply = ["set paid=true"]
  #|

///|
/// PM 罐面溯源三件（合成值——钉面只认产物体,不认头注）。
fn pm_test_prov() -> @gen.SchemaProvenance {
  @gen.SchemaProvenance::{
    source_table: "test/account_pm.toml",
    regen_command: "test",
    binder_path: "thy1016/cmd/gen(pm 方言 parse/validate/emit 三件套)",
  }
}

///|
/// 钉1·parse/validate 正例 + 词根负例（非 PM 表 = 双拒第一腿）。
test "mooncmd pm parse accept and root rejection" {
  let def = match @gen.parse_mooncmd_pm(PM_SAMPLE) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  assert_eq(def.name, "relay")
  assert_eq(def.saga_key, "aggregate_id")
  match @gen.validate_mooncmd_pm(def) {
    Ok(_) => ()
    Err(msg) => fail("validate failed: \{msg}")
  }
  // 非 PM 表(无 [process_manager])必须拒——方言路由双拒合成错的第一腿。
  match @gen.parse_mooncmd_pm(AGG_SAMPLE) {
    Ok(_) => fail("agg table must not parse as pm")
    Err(_) => ()
  }
}

///|
/// 钉2·发射形状锚:六段产物(init/interested/saga_id/handle/apply/PM 面)
/// + 发射确定性。
test "mooncmd pm emit shape anchors and determinism" {
  let def = match @gen.parse_mooncmd_pm(PM_SAMPLE) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  let emitted = @gen.emit_mooncmd_pm(def, provenance=pm_test_prov())
  assert_true(emitted.contains("pub(all) struct RelayPmState {"))
  assert_true(emitted.contains("pub fn RelayPmState::init() -> RelayPmState"))
  assert_true(
    emitted.contains("pub fn relay_pm_interested(e : OrderEvent) -> Bool"),
  )
  assert_true(emitted.contains("pub fn relay_pm_saga_id_of("))
  assert_true(emitted.contains("pub fn relay_pm_handle("))
  assert_true(emitted.contains("pub fn relay_pm_apply("))
  assert_true(emitted.contains("pub fn relay_pm() -> @mooncmd.ProcessManager["))
  // 装配不在词表(红线7 同源):产物不得含 runner/emit 闭包装配体。
  assert_true(!emitted.contains("ProcessManagerRunner::new"))
  assert_eq(emitted, @gen.emit_mooncmd_pm(def, provenance=pm_test_prov()))
}

///|
/// 钉G·golden 字节探针（治理②漂移探测器本体）:bank PM 表 → parse →
/// validate → emit → 逐字节等 golden 文件(= 主仓 committed
/// account_pm_gen.mbt + 溯源三件换算)。另钉头注同源(死指针刷新判据)。
async test "gen golden probe: bank pm table emits committed bytes" {
  let table_text = @utf8.decode(
    @fs.read_file("gen/testdata/bank_account_pm.toml").binary(),
  )
  let def = match @gen.parse_mooncmd_pm(table_text) {
    Ok(value) => value
    Err(msg) => fail("golden: pm parse failed: \{msg}")
  }
  match @gen.validate_mooncmd_pm(def) {
    Ok(_) => ()
    Err(msg) => fail("golden: pm validate failed: \{msg}")
  }
  let emitted = @gen.emit_mooncmd_pm(def, provenance={
    source_table: "gen/testdata/bank_account_pm.toml",
    regen_command: "moonx thy1016/cmd@latest gen/testdata/bank_account_pm.toml",
    binder_path: "thy1016/cmd/gen(pm 方言 parse/validate/emit 三件套)",
  })
  let golden = @utf8.decode(
    @fs.read_file("gen/testdata/bank_account_pm_gen.golden").binary(),
  )
  assert_eq(emitted, golden)
  assert_true(golden.contains("moonx thy1016/cmd@latest"))
}
