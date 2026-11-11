#!/bin/sh
# cmd 一令门(开发径收口;air driver 规格:判行 / cleanup / 前检):
#   ① 双目标 check(--deny-warn --no-mbti)
#   ② gen 包 × native|wasm 测试(12 罐:parse 正负例 + golden 双字节探针
#     [gen+glue] + stub/contract/glue 钉;golden 探针 = 治理②漂移探测器
#     本体,二版拍1 扩面)
#   ③ e2e 台(判行 CMD-E2E: PASS)
# cmd 无叠层需求(依赖全在 registry:toml/async/x;漂移探测走 gen 包
# 仓内冻结 fixture,不挂 mooncmd 仓)。
# 用法: sh driver/gate.sh
# 判行: CMD-GATE: PASS / CMD-GATE: FAIL <面清单>
set -u
CMD=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LOG_ROOT=/tmp/cmd_gate
FAILS=""

say() { echo "[cmd-gate] $*"; }
fail() { say "FAIL $1"; FAILS="$FAILS $1"; }

# env 叠层卸干净 + cwd 钉仓根(tests/build 全靠 cwd 解析)
unset MOON_WORK
cd "$CMD"
mkdir -p "$LOG_ROOT"

# ---- ① 双目标 check
for target in native wasm; do
  if moon check --deny-warn --target "$target" --no-mbti "$CMD" > "$LOG_ROOT/check-$target.log" 2>&1; then
    say "PASS check $target"
  else
    fail "check-$target"
    tail -n 20 "$LOG_ROOT/check-$target.log"
  fi
done

# ---- ② gen 包双腿测试
for target in native wasm; do
  if moon test -p gen --target "$target" > "$LOG_ROOT/test-gen-$target.log" 2>&1; then
    say "PASS test gen ($target): $(tail -n 1 "$LOG_ROOT/test-gen-$target.log")"
  else
    fail "test-gen-$target"
    tail -n 20 "$LOG_ROOT/test-gen-$target.log"
  fi
done

# ---- ③ e2e 台
sh "$CMD/driver/e2e.sh" > "$LOG_ROOT/e2e.log" 2>&1
if tail -n 1 "$LOG_ROOT/e2e.log" | grep -q "^CMD-E2E: PASS$"; then
  say "PASS e2e"
else
  fail "e2e"
  tail -n 20 "$LOG_ROOT/e2e.log"
fi

if [ -z "$FAILS" ]; then
  echo "CMD-GATE: PASS"
else
  echo "CMD-GATE: FAIL$FAILS"
  exit 1
fi
