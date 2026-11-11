// ===== GENERATED FILE — DO NOT EDIT（生成物禁手写，const.md §7）=====
// 源表：examples/bank/account_agg.toml（schema 1.0）
// 再生：moon run skelschema/cmd(仓根起跑;改表 → 再生 → 黄金门对拍)
// 绑定器：skelschema/mooncmd_agg_toml_gen.mbt(parse/validate/emit 三件套)
// 装配胶水:六桥件（handler/applier/empty_state/serialize/deserialize/type_name）——依赖 thy1016/mooncmd/command + moonbitlang/core/encoding/utf8,消费者包 moon.pkg 生产 import 块自配;裁决装配点 = account_hooks()（policy 件手写——红线7 裁决不入表）。

///|
/// 桥接:gen 分派（String 错域）→ 框架命令错误（InvalidCommand 同界）——
/// 裁决装配点 = account_hooks()（policy 件手写——红线7 裁决不入表）
pub fn account_handler(
  state : AccountState,
  cmd : AccountCommand,
) -> Array[AccountEvent] raise @command.CommandError {
  match account_decide(state, cmd, account_hooks()) {
    Ok(events) => events
    Err(msg) => raise @command.CommandError::InvalidCommand(msg)
  }
}

///|
/// 事件应用器（EventApplier::Single 装配位）
pub fn account_applier(
  state : AccountState,
  event : AccountEvent,
) -> AccountState {
  event.apply(state)
}

///|
/// 空初态（AggregateRoot::new / from_events 装配位）
pub fn account_empty_state() -> AccountState {
  AccountState::init()
}

///|
/// 事件序列化（SQLiteEventStore::new 装配位;wire 契约 = 契约门 roundtrip 钉）
pub fn account_serialize(event : AccountEvent) -> Bytes {
  @utf8.encode(event.to_wire())
}

///|
/// 事件反序列化（坏载荷 abort——wire 格式契约由契约门钉）
pub fn account_deserialize(data : Bytes) -> AccountEvent raise {
  let text = @utf8.decode(data)
  match AccountEvent::from_wire(text) {
    Some(event) => event
    None => abort("bad event wire payload: \{text}")
  }
}

///|
/// 事件类型标签（SQLite store 记录面;裸事件名）
pub fn account_type_name(event : AccountEvent) -> String {
  match event {
    AccountCreated(_, _) => "AccountCreated"
    MoneyDeposited(_) => "MoneyDeposited"
    MoneyWithdrawn(_) => "MoneyWithdrawn"
    AccountClosed => "AccountClosed"
  }
}
