// ===== Account Effect 重试策略钩子（手写，红线7：裁决不入表）=====
// 词表默认分派 = account_retry.toml [retry.on_error]（retry_gen.mbt 产物内表）；
// 本件 = 业务覆写面——None 沿词表默认，Some 覆写。

///|
/// 纯透形（零覆写）：全沿词表默认分派。
pub fn account_retry_hooks_pure() -> @aggregate.RetryHooks {
  @aggregate.RetryHooks::none()
}

///|
/// 覆写形（演示）：本业务裁定 storage 族亦不重试（例：存储层已知不可重试故障，
/// 重试只增延迟不增成功率）——词表 storage="retry" 被钩子收紧为 exhausted。
pub fn account_retry_hooks_strict() -> @aggregate.RetryHooks {
  {
    override_action: fn(kind) {
      match kind {
        @aggregate.Storage => Some(@aggregate.ActionExhausted)
        _ => None
      }
    },
  }
}
