#!/usr/bin/env bash
# build-kernel.sh — run the forth-from-forth cross-compiler.
#
# Pipes xcomp.fth + "COMPILE-RUNTIME" into the phase-3
# forth-on-forthish REPL via cor24-run's -u (UART input) flag.
# Captures UART output, strips everything outside the
# !!BEGIN-KERNEL!! / !!END-KERNEL!! markers, strips the REPL's
# per-line " ok" chrome from the captured payload, and writes
# the result to forth-from-forth/compiler/out/runtime-dict.s.
#
# Step 004a: the compiler emits only a test-payload ("hello from
# xcomp") between the markers, proving the pipeline works.
# Step 004b+ replace the payload with the real asm text for
# core/runtime.fth's 10 colon defs.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FFF="$HERE/.."
FOF="$ROOT/forth-on-forthish"

OUT_DIR="$FFF/compiler/out"
OUT_FILE="$OUT_DIR/runtime-dict.s"

mkdir -p "$OUT_DIR"

cd "$ROOT"

# UART input: all 5 core tiers (so the phase-3 REPL has its Forth
# dictionary built, including BEGIN/UNTIL/CREATE/etc.), then
# xcomp.fth's definitions, then invoke COMPILE-RUNTIME.
# Trailing newline after COMPILE-RUNTIME so the REPL reads it.
INPUT="$(
  cat "$FFF/core/runtime.fth"
  cat "$FFF/core/minimal.fth"
  cat "$FFF/core/lowlevel.fth"
  cat "$FFF/core/midlevel.fth"
  cat "$FFF/core/highlevel.fth"
  cat "$FFF/compiler/xcomp.fth"
)
COMPILE-RUNTIME
"

cor24-run --run "$FOF/kernel.s" -u "$INPUT" --speed 0 -n 800000000 2>&1 \
  | grep -A 1000 '^UART output:' \
  | sed -n '/^!!BEGIN-KERNEL!!$/,/^!!END-KERNEL!!$/p' \
  | sed '1d;$d' \
  | grep -v '^ ok$' \
  > "$OUT_FILE"

echo "build-kernel.sh: wrote $OUT_FILE" >&2
echo "  contents ($(wc -l < "$OUT_FILE") lines):" >&2
sed 's/^/    /' "$OUT_FILE" >&2
