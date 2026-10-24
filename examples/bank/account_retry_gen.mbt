// 生成物禁手写（生成红线9）——绑定器 skelschema/retry_toml_gen.mbt；黄金门 = mooncmd 侧 parse→emit ≡ 本件逐字节。
// 源词表：account_retry.toml（[retry] max=3 backoff=fixed interval=100 + [retry.on_error] + [circuit]?）
// 业务裁决 = account_retry_policy.mbt 手写钩子（红线7：裁决不入表）。

///|
/// account_retry_machine——Effect 重试状态机（词表驱动纯翻译，退避/熔断内算；无时钟无副作用）
pub fn account_retry_machine() -> @aggregate.RetryMachine {
  {
    default_action: fn(kind) {
      match kind {
        @aggregate.Duplicate => @aggregate.ActionRetry
        @aggregate.Validation => @aggregate.ActionExhausted
        @aggregate.Storage => @aggregate.ActionRetry
        @aggregate.Other => @aggregate.ActionExhausted
      }
    },
    decide: fn(attempt, consecutive_failures, _kind) {
      // 熔断（circuit.threshold = 5，cooldown = 30000——冷却窗口词表值，接续裁决归调用方）
      if consecutive_failures >= 5 {
        return @aggregate.GiveUpRaise
      }
      // 重试上限（retry.max = 3）
      if attempt > 3 {
        return @aggregate.GiveUpRaise
      }
      // 固定退避（backoff = fixed，interval = 100）
      @aggregate.WaitRetry(wait_ms=100L)
    },
  }
}
