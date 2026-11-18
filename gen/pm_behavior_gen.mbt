// pm_behavior_gen.mbt —— PM 行为面 trait 发射(带缺省体;用户 2026-11-18 拍)。
// gen 产 trait+缺省体+适配器(禁手写,const.md §7);实装体 = 用户件 override
// (只写差异槽)。缺省形(安全惰值):saga_id_of = 信封 aggregate_id 直读 /
// handle = 零发射 / apply = 透传 / init_state = 词表零值态 / interested =
// 不观注;name 无缺省(PM 名 = 每实现必给——state_key 命名空间)。
// 与记录面的分界:记录面(<名>_pm()) = 泵消费形唯一(黄金门);本件 = trait
// 手写径的 gen 化(适配器归一进同一记录面,双形同泵)。

///|
/// PM 行为面 trait(带缺省体) + 适配器发射。
pub fn emit_mooncmd_pm_behavior(
  def : MooncmdPmDef,
  provenance~ : SchemaProvenance,
) -> String {
  let sb = StringBuilder()
  let state_type = schema_upper_first(def.name) + "PmState"
  let trait_type = schema_upper_first(def.name) + "PmBehavior"
  sb <+
    "// ===== \{def.name} PM 行为面 trait（gen 生成带缺省体;禁手写,const.md §7）=====\n"
  sb <+
    "// 源表：\{provenance.source_table}（词表产物 \{def.name}_pm_gen.mbt = 记录面黄金门;\n"
  sb <+
    "// 本件 = trait 手写径 gen 化——适配器归一进同一记录面,双形同泵）\n"
  sb <+
    "// 缺省体(安全惰值):saga_id_of = 信封直读 / handle = 零发射 / apply = 透传 /\n"
  sb <+
    "// init_state = 词表零值态 / interested = 不观注;name 无缺省(每实现必给)。\n"
  sb <+
    "// 用户最小实装 = impl <Trait> for <Struct> with fn name + 按需覆写(五缺省自动\n"
  sb <+
    "// 继承——部分实装探针实证 2026-11-18);declare impl 声明形 = 陷阱坑账(编译过+\n"
  sb <+
    "// 运行时缺省不继承直落 abort——勿用)。再生:moon run skelschema/cmd -- --pm-behavior <out>\n"
  sb <+ "\n///|\n"
  sb <+
    "/// 行为面 trait（缺省体 = 安全惰值;覆写差异槽即可跑）\n"
  sb <+ "pub(open) trait \{trait_type} {\n"
  sb <+ "  fn name(Self) -> String\n"
  sb <+ "  fn init_state(Self) -> \{state_type} = _\n"
  sb <+ "  fn interested(Self, \{def.event_type}) -> Bool = _\n"
  let saga_line = "  fn saga_id_of(Self, @event.EventMessage[String, \{def.event_type}]) -> String = _"
  if saga_line.length() > 80 {
    sb <+ "  fn saga_id_of(\n"
    sb <+ "    Self,\n"
    sb <+ "    @event.EventMessage[String, \{def.event_type}],\n"
    sb <+ "  ) -> String = _\n"
  } else {
    sb <+ "\{saga_line}\n"
  }
  let handle_line = "  fn handle(Self, \{state_type}, \{def.event_type}) -> Array[@mooncmd.DirectedCommand[\{def.command_type}]] = _"
  if handle_line.length() > 80 {
    // fmt 实测正典(2026-11-18):参数保持单行,返型泛括折行
    sb <+ "  fn handle(Self, \{state_type}, \{def.event_type}) -> Array[\n"
    sb <+ "    @mooncmd.DirectedCommand[\{def.command_type}],\n"
    sb <+ "  ] = _\n"
  } else {
    sb <+ "\{handle_line}\n"
  }
  sb <+
    "  fn apply(Self, \{state_type}, \{def.event_type}) -> \{state_type} = _\n"
  sb <+ "}\n"
  // 缺省体(trait 级 impl;无 for Type——core Eq/not_equal 同款)
  sb <+ "\n///|\n"
  sb <+ "impl \{trait_type} with fn init_state(_self) -> \{state_type} {\n"
  sb <+ "  \{state_type}::init()\n"
  sb <+ "}\n"
  sb <+ "\n///|\n"
  sb <+ "impl \{trait_type} with fn interested(_self, _e) -> Bool {\n"
  sb <+ "  false\n"
  sb <+ "}\n"
  sb <+ "\n///|\n"
  sb <+ "impl \{trait_type} with fn saga_id_of(_self, msg) -> String {\n"
  sb <+ "  msg.aggregate_id\n"
  sb <+ "}\n"
  sb <+ "\n///|\n"
  let handle_impl = "impl \{trait_type} with fn handle(_self, _state, _e) -> Array[@mooncmd.DirectedCommand[\{def.command_type}]] {"
  if handle_impl.length() > 80 {
    // fmt 实测正典:参数单行,返型泛括折行(同 trait 体判形)
    sb <+ "impl \{trait_type} with fn handle(_self, _state, _e) -> Array[\n"
    sb <+ "  @mooncmd.DirectedCommand[\{def.command_type}],\n"
    sb <+ "] {\n"
  } else {
    sb <+ "\{handle_impl}\n"
  }
  sb <+ "  []\n"
  sb <+ "}\n"
  sb <+ "\n///|\n"
  sb <+
    "impl \{trait_type} with fn apply(_self, state, _e) -> \{state_type} {\n"
  sb <+ "  state\n"
  sb <+ "}\n"
  // 适配器(记录面唯一消费形;trait 对象直调,[0079] 零晋升)
  sb <+ "\n///|\n"
  sb <+
    "/// 行为面 → 记录面适配（泵消费形唯一;双形同泵）\n"
  sb <+ "pub fn \{def.name}_pm_of_behavior(\n"
  sb <+ "  behavior : &\{trait_type},\n"
  sb <+
    ") -> @mooncmd.ProcessManager[\{state_type}, \{def.command_type}, \{def.event_type}] {\n"
  sb <+ "  {\n"
  sb <+ "    name: behavior.name(),\n"
  sb <+ "    init_state: () => behavior.init_state(),\n"
  sb <+ "    interested: e => behavior.interested(e),\n"
  sb <+ "    saga_id_of: msg => behavior.saga_id_of(msg),\n"
  sb <+ "    handle: (state, e) => behavior.handle(state, e),\n"
  sb <+ "    apply: (state, e) => behavior.apply(state, e),\n"
  sb <+ "  }\n"
  sb <+ "}\n"
  sb.to_string()
}
