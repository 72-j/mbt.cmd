// ===== transfer PM 行为面 trait（gen 生成带缺省体;禁手写,const.md §7）=====
// 源表：/home/thy/bitbang2/mooncmd/examples/bank_cmd/account_pm.toml（词表产物 transfer_pm_gen.mbt = 记录面黄金门;
// 本件 = trait 手写径 gen 化——适配器归一进同一记录面,双形同泵）
// 缺省体(安全惰值):saga_id_of = 信封直读 / handle = 零发射 / apply = 透传 /
// init_state = 词表零值态 / interested = 不观注;name 无缺省(每实现必给)。
// 用户最小实装 = impl <Trait> for <Struct> with fn name + 按需覆写(五缺省自动
// 继承——部分实装探针实证 2026-11-18);declare impl 声明形 = 陷阱坑账(编译过+
// 运行时缺省不继承直落 abort——勿用)。再生:moon run skelschema/cmd -- --pm-behavior <out>

///|
/// 行为面 trait（缺省体 = 安全惰值;覆写差异槽即可跑）
pub(open) trait TransferPmBehavior {
  fn name(Self) -> String
  fn init_state(Self) -> TransferPmState = _
  fn interested(Self, AccountEvent) -> Bool = _
  fn saga_id_of(Self, @event.EventMessage[String, AccountEvent]) -> String = _
  fn handle(Self, TransferPmState, AccountEvent) -> Array[
    @mooncmd.DirectedCommand[AccountCommand],
  ] = _
  fn apply(Self, TransferPmState, AccountEvent) -> TransferPmState = _
}

///|
impl TransferPmBehavior with fn init_state(_self) -> TransferPmState {
  TransferPmState::init()
}

///|
impl TransferPmBehavior with fn interested(_self, _e) -> Bool {
  false
}

///|
impl TransferPmBehavior with fn saga_id_of(_self, msg) -> String {
  msg.aggregate_id
}

///|
impl TransferPmBehavior with fn handle(_self, _state, _e) -> Array[
  @mooncmd.DirectedCommand[AccountCommand],
] {
  []
}

///|
impl TransferPmBehavior with fn apply(_self, state, _e) -> TransferPmState {
  state
}

///|
/// 行为面 → 记录面适配（泵消费形唯一;双形同泵）
pub fn transfer_pm_of_behavior(
  behavior : &TransferPmBehavior,
) -> @mooncmd.ProcessManager[TransferPmState, AccountCommand, AccountEvent] {
  {
    name: behavior.name(),
    init_state: () => behavior.init_state(),
    interested: e => behavior.interested(e),
    saga_id_of: msg => behavior.saga_id_of(msg),
    handle: (state, e) => behavior.handle(state, e),
    apply: (state, e) => behavior.apply(state, e),
  }
}
