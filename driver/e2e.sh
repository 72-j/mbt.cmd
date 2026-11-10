#!/bin/sh
# cmd e2e 台(进程外,罐外证):driver 双运行时(native exe + moonrun 直跑
# wasm——moonx = 取注册表预编译 wasm → moonrun,wasm 腿是 moonx 的本地
# 对位)× 五判:
#   ① 三件落盘:native 跑 bank fixture 表 → gen/contract/policy 齐 + exit 0
#   ② 产物零漂:gen 体(tail -n +8)逐字节 ≡ 仓内 golden fixture(治理②
#      探测器的 e2e 对位;头注溯源随调用径变 = 预期差异,不入判)
#   ③ policy only-if-absent 回归:改桩再跑 → 桩内容保留 + regen 不覆写
#   ④ wasm 腿:moonrun 直跑同表 → 三件写成功(exit 0)
#   ⑤ 消费项目编译核身:scratch 消费模块收三件 → moon check --deny-warn
#      + moon test(契约罐:init 契约 + wire roundtrip 全绿)
# 用法: sh driver/e2e.sh
# 判行: CMD-E2E: PASS / CMD-E2E: FAIL <面清单>
set -u
CMD=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=/tmp/cmd_e2e
MOONRUN=${MOONRUN:-moonrun}
FAILS=""

say() { echo "[cmd-e2e] $*"; }
fail() { say "FAIL $1"; FAILS="$FAILS $1"; }

# env 叠层卸干净:cwd 钉仓根,消费项目侧同样卸防爬升误入
unset MOON_WORK
cd "$CMD"

rm -rf "$ROOT"
mkdir -p "$ROOT/scratch"

# ---- 构建 native(产物行 = 包 / 目标 / 绝对路径)
moon build --target native "$CMD" > "$ROOT/build-native.log" 2>&1
EXE=$(awk '$1 == "thy1016/cmd" && $2 == "native" { print $3 }' "$ROOT/build-native.log" | tail -1)
if [ -x "$EXE" ]; then
  say "native=$EXE"
else
  say "native build failed"; cat "$ROOT/build-native.log"; echo "CMD-E2E: FAIL build-native"; exit 1
fi

# ---- ① 三件落盘
cp "$CMD/gen/testdata/bank_account_agg.toml" "$ROOT/scratch/account_agg.toml"
(cd "$ROOT/scratch" && "$EXE" account_agg.toml) > "$ROOT/native-run.log" 2>&1
code=$?
for f in account_gen.mbt account_contract_wbtest.mbt account_policy.mbt; do
  [ -f "$ROOT/scratch/$f" ] || fail "native-emit($f 缺)"
done
if [ "$code" = "0" ] && [ -z "$FAILS" ]; then
  say "PASS native emit (exit 0, 三件齐)"
else
  fail "native-emit(exit=$code)"; cat "$ROOT/native-run.log"
fi

# ---- ② 产物零漂(gen 体 ≡ golden fixture 体)
tail -n +8 "$ROOT/scratch/account_gen.mbt" > "$ROOT/gen-body.txt"
tail -n +8 "$CMD/gen/testdata/bank_account_gen.golden" > "$ROOT/golden-body.txt"
if cmp -s "$ROOT/gen-body.txt" "$ROOT/golden-body.txt"; then
  say "PASS gen body bytes == golden fixture"
else
  fail "gen-body-drift(diff 见 /tmp/cmd_e2e/gen-body.txt)"
fi

# ---- ③ policy only-if-absent 回归
python3 - "$ROOT/scratch/account_policy.mbt" <<'PYTAMPER'
import sys
p = sys.argv[1]
c = open(p, encoding="utf-8").read()
assert "TODO(DepositMoney)" in c, "stub guard anchor missing"
open(p, "w", encoding="utf-8").write(c.replace("TODO(DepositMoney)", "FILLED(DepositMoney)"))
PYTAMPER
(cd "$ROOT/scratch" && "$EXE" account_agg.toml) >> "$ROOT/native-run.log" 2>&1
filled=$(grep -c FILLED "$ROOT/scratch/account_policy.mbt")
todos=$(grep -c TODO "$ROOT/scratch/account_policy.mbt")
if [ "$filled" -ge 1 ] && [ "$todos" -ge 3 ]; then
  say "PASS policy only-if-absent (FILLED=$filled 存活, TODO=$todos 保留)"
else
  fail "policy-overwrite(FILLED=$filled TODO=$todos)"
fi

# ---- ④ wasm 腿(moonrun 直跑 = moonx 本地对位)
moon build --target wasm "$CMD" > "$ROOT/build-wasm.log" 2>&1
WASM=$(awk '$1 == "thy1016/cmd" && $2 == "wasm" { print $3 }' "$ROOT/build-wasm.log" | tail -1)
if [ -f "$WASM" ]; then
  (cd "$ROOT/scratch" && "$MOONRUN" "$WASM" -- account_agg.toml) > "$ROOT/wasm-run.log" 2>&1
  code=$?
  if [ "$code" = "0" ] && [ -f "$ROOT/scratch/account_gen.mbt" ]; then
    say "PASS wasm run (exit 0, 产物在)"
  else
    fail "wasm-run(exit=$code)"; tail -10 "$ROOT/wasm-run.log"
  fi
else
  fail "wasm-build"; tail -10 "$ROOT/build-wasm.log"
fi

# ---- ⑤ 消费项目编译核身(三件进空模块,契约罐全绿)
mkdir -p "$ROOT/consumer"
cat > "$ROOT/consumer/moon.mod" <<'PYMOD'
name = "cmd_e2e_consumer"
PYMOD
touch "$ROOT/consumer/moon.pkg"
cp "$ROOT/scratch/account_gen.mbt" "$ROOT/scratch/account_policy.mbt" \
   "$ROOT/scratch/account_contract_wbtest.mbt" "$ROOT/consumer/"
(cd "$ROOT/consumer" && env -u MOON_WORK moon check --deny-warn) > "$ROOT/consumer-check.log" 2>&1 \
  && (cd "$ROOT/consumer" && env -u MOON_WORK moon test) > "$ROOT/consumer-test.log" 2>&1
if [ $? = 0 ]; then
  say "PASS consumer compile+contract (check deny-warn + test)"
else
  fail "consumer"; tail -n 20 "$ROOT/consumer-check.log"; tail -n 20 "$ROOT/consumer-test.log"
fi

if [ -z "$FAILS" ]; then
  echo "CMD-E2E: PASS"
else
  echo "CMD-E2E: FAIL$FAILS"
  exit 1
fi
