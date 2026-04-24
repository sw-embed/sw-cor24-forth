#!/usr/bin/env bash
# test-kernel.sh — assemble and run the self-test kernel to
# exercise the emitted runtime.fth dict.
#
# Pipeline:
#   1. Run build-kernel.sh to (re)generate runtime-dict.s from
#      xcomp.fth.
#   2. Concatenate selftest-scaffold.s + runtime-dict.s into
#      compiler/out/runtime-selftest.s.
#   3. Assemble with cor24-run; run with no UART input.
#   4. Print the UART output (which is the test result).
#
# Expected successful output:
#     AA
#     A
#     ABA
#     AB
#     1
#     7
#     @
#     DONE
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FFF="$HERE/.."

OUT_DIR="$FFF/compiler/out"
DICT_S="$OUT_DIR/runtime-dict.s"
SELFTEST_S="$OUT_DIR/runtime-selftest.s"
SCAFFOLD="$FFF/compiler/selftest-scaffold.s"

cd "$ROOT"

# Step 1: regenerate the emitted dict
"$HERE/build-kernel.sh" >&2

# Step 2: combine scaffold + emitted dict
mkdir -p "$OUT_DIR"
{
  cat "$SCAFFOLD"
  echo ""
  echo "; === emitted dict (from build-kernel.sh) ==="
  cat "$DICT_S"
  echo ""
  echo "; === end of emitted dict ==="
  echo "dict_end:"
} > "$SELFTEST_S"

echo "test-kernel.sh: wrote $SELFTEST_S ($(wc -l < "$SELFTEST_S") lines)" >&2

# Step 3: run the self-test, capture UART output
cor24-run --run "$SELFTEST_S" --speed 0 -n 200000000 2>&1 \
  | grep -A 100 '^UART output:' \
  | sed -n '/^UART output:/,$p'
