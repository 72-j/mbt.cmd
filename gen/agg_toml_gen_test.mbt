///|
/// cmd/gen 黑盒测试面(抽自主仓同族测试件体保真;@skelschema→@gen 限定
/// 换名,发射钉面同谱)+ golden 字节探针(治理②漂移探测器本体):bank 表
/// → 期望产物 = 主仓已提交 account_gen.mbt 字节(溯源三件勘定修正:三件
/// 非两行——源表/再生/绑定器行三处换算,产物体零漂)。主仓发射器一变,
/// 本罐当场红,照差移植(红灯驱动同步,治理①的下游哨兵)。
const AGG_SAMPLE : String =
  #|schema_version = "1.0"
  #|generator = "mooncmd_agg_gen"
  #|target_package = "thy1016/cmd/samples"
  #|
  #|[aggregate]
  #|name = "counter"
  #|id = "string"
  #|
  #|[aggregate.state]
  #|fields = [
  #|  { name = "count", type = "int", init = "0" },
  #|  { name = "log", type = "string", init = "\"\"" },
  #|]
  #|
  #|[[aggregate.events]]
  #|name = "Bumped"
  #|fields = [ { name = "delta", type = "int" } ]
  #|evolve = ["add count=delta"]
  #|
  #|[[aggregate.commands]]
  #|name = "Bump"
  #|fields = [ { name = "delta", type = "int" } ]

///|
/// 罐面溯源三件（合成值——钉面只认产物体,不认头注;黄金门/再生驱动的
/// 真值对另钉于 golden/mooncmd_gate_test.mbt 与 skelschema/cmd 双写互钉）。
fn agg_test_prov() -> @gen.SchemaProvenance {
  @gen.SchemaProvenance::{
    source_table: "test/account_agg.toml",
    regen_command: "test",
    binder_path: "skelschema/mooncmd_agg_toml_gen.mbt(parse/validate/emit 三件套)",
  }
}

///|
/// 钉1·解析+校验过线:sample 全绿,词根/事件/命令齐。
test "mooncmd agg binder parses and validates sample" {
  let def = match @gen.parse_mooncmd_agg(AGG_SAMPLE) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  assert_eq(def.name, "counter")
  assert_eq(def.state_fields.length(), 2)
  assert_eq(def.events.length(), 1)
  assert_eq(def.commands.length(), 1)
}

///|
/// 钉2·演化指令封闭集(红线8):封闭集外 op 判红。
test "mooncmd agg binder rejects op outside closed set" {
  let bad = AGG_SAMPLE.replace(
    old="add count=delta",
    new="multiply count=delta",
  )
  match @gen.parse_mooncmd_agg(bad) {
    Err(msg) => assert_true(msg.contains("outside closed set"))
    Ok(_) => fail("expected closed-set rejection")
  }
}

///|
/// 钉3·裁决不入表(红线7):decide 词形在 TOML = 不识别即忽略/红,钩子面
/// 归策略件——gen 产物含 DecideHooks 记录与分派,不含任何裁决体。
test "mooncmd agg emit contains hooks record and dispatch, no decision body" {
  let def = match @gen.parse_mooncmd_agg(AGG_SAMPLE) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  let provenance = agg_test_prov()
  let emitted = @gen.emit_mooncmd_agg(def, provenance~)
  assert_true(emitted.contains("pub(all) struct CounterDecideHooks"))
  assert_true(emitted.contains("counter_decide"))
  assert_true(
    emitted.contains("let s0 = { ..state, count: state.count + delta, }"),
  )
}

///|
/// 钉4·发射确定性:同输入双次发射逐字节相等(黄金门前提)。
test "mooncmd agg emit is deterministic" {
  let def = match @gen.parse_mooncmd_agg(AGG_SAMPLE) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  let provenance = agg_test_prov()
  assert_eq(
    @gen.emit_mooncmd_agg(def, provenance~),
    @gen.emit_mooncmd_agg(def, provenance~),
  )
}

///|
/// 钉5·wire 映射（役7+ D-MG-6）:to_wire/from_wire 在册 + v1 预留位校验 + 无时钟。
test "mooncmd agg emit contains wire mapping" {
  let def = match @gen.parse_mooncmd_agg(AGG_SAMPLE) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  let provenance = agg_test_prov()
  let emitted = @gen.emit_mooncmd_agg(def, provenance~)
  assert_true(emitted.contains("pub fn CounterEvent::to_wire"))
  assert_true(emitted.contains("pub fn CounterEvent::from_wire"))
  assert_true(emitted.contains("1\\tBumped\\t\\{delta}"))
  assert_true(emitted.contains("parts[0] != \"1\""))
  assert_true(emitted.contains("counter_wire_int"))
  assert_false(emitted.contains("now()"))
}

///|
/// 钉6·契约门脚手架（D-MG-5）:init 契约 + wire roundtrip + 发射确定性。
test "mooncmd agg contract scaffold emission" {
  let def = match @gen.parse_mooncmd_agg(AGG_SAMPLE) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  let tests = @gen.emit_mooncmd_agg_contract_tests(def)
  assert_true(
    tests.contains("counter init contract: fields equal declared inits"),
  )
  assert_true(tests.contains("assert_eq(state.count, 0)"))
  assert_true(
    tests.contains("counter wire contract: roundtrip identity per event"),
  )
  assert_true(tests.contains("CounterEvent::from_wire(sample.to_wire())"))
  assert_eq(tests, @gen.emit_mooncmd_agg_contract_tests(def))
}

///|
/// 钉7·策略 stub 发射（stub-zone）:工厂名 + 守卫 Err("TODO") + stub-zone
/// 头注 + 发射确定性（形状 = bank 手写孪生件 account_policy.mbt 同构）。
test "mooncmd agg policy stub emission" {
  let def = match @gen.parse_mooncmd_agg(AGG_SAMPLE) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  let stub = @gen.emit_mooncmd_agg_policy_stub(def)
  assert_true(stub.contains("pub fn counter_hooks() -> CounterDecideHooks"))
  assert_true(stub.contains("bump: (state, delta) => {"))
  // 哑消费行(deny-warn 面:stub 参数全未用 = unused_value 红,消费项目
  // 核身实证 2026-11-10)——多参元组形/单参裸形各钉。
  assert_true(stub.contains("let _ = (state, delta)"))
  assert_true(
    stub.contains("Err(\"TODO(Bump): 裁决体待填——红线7\")"),
  )
  assert_true(stub.contains("仅缺位时落,regen 永不覆写"))
  assert_eq(stub, @gen.emit_mooncmd_agg_policy_stub(def))
}

///|
/// 钉8·stub 单参裸形（fmt 正典）:零载荷命令闭包 = `cmd: state =>` 无括号形。
test "mooncmd agg policy stub zero-payload bare lambda" {
  let sample = AGG_SAMPLE.replace(
    old="[[aggregate.commands]]\nname = \"Bump\"\nfields = [ { name = \"delta\", type = \"int\" } ]",
    new="[[aggregate.commands]]\nname = \"Bump\"\nfields = [ { name = \"delta\", type = \"int\" } ]\n\n[[aggregate.commands]]\nname = \"Reset\"\nfields = []",
  )
  let def = match @gen.parse_mooncmd_agg(sample) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  let stub = @gen.emit_mooncmd_agg_policy_stub(def)
  assert_true(stub.contains("bump: (state, delta) => {"))
  assert_true(stub.contains("reset: state => {"))
  assert_true(stub.contains("let _ = state\n"))
  assert_true(
    stub.contains("Err(\"TODO(Reset): 裁决体待填——红线7\")"),
  )
}

///|
/// 钉9·装配胶水发射（二版拍1）:六桥件名位（蛇形+pub 形）+ handler 桥
/// hooks 装配/InvalidCommand 同界 + wire 桥 utf8 面 + 依赖 note 烙明
/// + 发射确定性。
test "mooncmd agg glue emission six bridges" {
  let def = match @gen.parse_mooncmd_agg(AGG_SAMPLE) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  let glue = @gen.emit_mooncmd_agg_glue(def, provenance=agg_test_prov())
  assert_true(glue.contains("pub fn counter_handler("))
  assert_true(glue.contains("pub fn counter_applier("))
  assert_true(glue.contains("pub fn counter_empty_state() -> CounterState"))
  assert_true(
    glue.contains("pub fn counter_serialize(event : CounterEvent) -> Bytes"),
  )
  assert_true(
    glue.contains(
      "pub fn counter_deserialize(data : Bytes) -> CounterEvent raise",
    ),
  )
  assert_true(
    glue.contains("pub fn counter_type_name(event : CounterEvent) -> String"),
  )
  assert_true(glue.contains("match counter_decide(state, cmd, counter_hooks())"))
  assert_true(
    glue.contains(
      "Err(msg) => raise @command.CommandError::InvalidCommand(msg)",
    ),
  )
  assert_true(glue.contains("@utf8.encode(event.to_wire())"))
  assert_true(glue.contains("abort(\"bad event wire payload: \\{text}\")"))
  // type_name 桥:单载荷 arity 通配 + 依赖 note 行烙明
  assert_true(glue.contains("Bumped(_) => \"Bumped\""))
  assert_true(
    glue.contains("thy1016/mooncmd/command + moonbitlang/core/encoding/utf8"),
  )
  assert_eq(glue, @gen.emit_mooncmd_agg_glue(def, provenance=agg_test_prov()))
}

///|
/// 钉10·glue 零载荷事件裸名模式:type_name 零 arity = 裸构造（非 `X()` 形）。
test "mooncmd agg glue zero-payload event bare pattern" {
  let sample = AGG_SAMPLE.replace(
    old="evolve = [\"add count=delta\"]",
    new="evolve = [\"add count=delta\"]\n\n[[aggregate.events]]\nname = \"Reset\"\nfields = []",
  )
  let def = match @gen.parse_mooncmd_agg(sample) {
    Ok(def) => def
    Err(msg) => fail(msg)
  }
  let glue = @gen.emit_mooncmd_agg_glue(def, provenance=agg_test_prov())
  assert_true(glue.contains("Reset => \"Reset\""))
  assert_true(glue.contains("Bumped(_) => \"Bumped\""))
}

///|
/// 钉G2·glue golden 字节探针(治理②漂移探测器扩面):bank 表 → parse →
/// validate → emit_glue → 逐字节等 golden 文件(= 主仓 committed
/// account_glue.mbt + 溯源三件换算)。头注同源钉随行。
async test "gen golden probe glue: bank table emits committed glue bytes" {
  let table_text = @utf8.decode(
    @fs.read_file("gen/testdata/bank_account_agg.toml").binary(),
  )
  let def = match @gen.parse_mooncmd_agg(table_text) {
    Ok(value) => value
    Err(msg) => fail("golden glue: parse failed: \{msg}")
  }
  match @gen.validate_mooncmd_agg(def) {
    Ok(_) => ()
    Err(msg) => fail("golden glue: validate failed: \{msg}")
  }
  let emitted = @gen.emit_mooncmd_agg_glue(def, provenance=golden_probe_prov())
  let golden = @utf8.decode(
    @fs.read_file("gen/testdata/bank_account_glue.golden").binary(),
  )
  assert_eq(emitted, golden)
  assert_true(golden.contains("moonx thy1016/cmd@latest"))
}

///|
/// golden 探针溯源三件(与 fixture 头注换算三行逐字节同源——probe 侧
/// 字符串与 fixture 换算必须一致,失一致 = 假红)。
fn golden_probe_prov() -> @gen.SchemaProvenance {
  @gen.SchemaProvenance::{
    source_table: "gen/testdata/bank_account_agg.toml",
    regen_command: "moonx thy1016/cmd@latest gen/testdata/bank_account_agg.toml",
    binder_path: "thy1016/cmd/gen(agg 方言 parse/validate/emit 三件套)",
  }
}

///|
/// 钉G·golden 字节探针(治理②漂移探测器本体):bank 表 → parse →
/// validate → emit → 逐字节等 golden 文件(= 主仓 committed account_gen.mbt
/// + 溯源三件换算)。另钉头注同源(死指针刷新判据:入库产物必须烙再生
/// 入口真值)。
async test "gen golden probe: bank table emits committed bytes" {
  let table_text = @utf8.decode(
    @fs.read_file("gen/testdata/bank_account_agg.toml").binary(),
  )
  let def = match @gen.parse_mooncmd_agg(table_text) {
    Ok(value) => value
    Err(msg) => fail("golden: parse failed: \{msg}")
  }
  match @gen.validate_mooncmd_agg(def) {
    Ok(_) => ()
    Err(msg) => fail("golden: validate failed: \{msg}")
  }
  let emitted = @gen.emit_mooncmd_agg(def, provenance=golden_probe_prov())
  let golden = @utf8.decode(
    @fs.read_file("gen/testdata/bank_account_gen.golden").binary(),
  )
  assert_eq(emitted, golden)
  assert_true(golden.contains("moonx thy1016/cmd@latest"))
}
