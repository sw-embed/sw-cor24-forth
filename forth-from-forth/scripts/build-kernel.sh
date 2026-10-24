#!/usr/bin/env bash
# build-kernel.sh — run the forth-from-forth cross-compiler.
#
# Pipes xcomp.fth + prims.fth + XC-COMPILE-SOURCE into the phase-3
# forth-on-forthish REPL via cor24-emu's -u (UART input) flag.
# Captures UART output, strips everything outside the
# !!BEGIN-KERNEL!! / !!END-KERNEL!! markers, strips the REPL's
# per-line " ok" chrome from the captured payload, and writes
# the result to forth-from-forth/compiler/out/runtime-dict.s.
#
# The compiler reads core/runtime.fth as source (override with
# XC_SOURCE=path) and emits one dictionary entry per colon definition
# to compiler/out/runtime-dict.s (override with XC_OUT=path).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FFF="$HERE/.."
FOF="$ROOT/forth-on-forthish"

OUT_DIR="$FFF/compiler/out"
OUT_FILE="${XC_OUT:-$OUT_DIR/runtime-dict.s}"

mkdir -p "$OUT_DIR"

cd "$ROOT"

# UART input: the five core tiers (so the phase-3 REPL has its Forth
# dictionary: BEGIN/UNTIL/CONSTANT/STR= and friends), then the compiler
# and the primitive registry, then XC-COMPILE-SOURCE followed by the
# target source and the XC-END sentinel.
SOURCE="${XC_SOURCE:-$FFF/core/runtime.fth}"
INPUT="$(
  cat "$FFF/core/runtime.fth"
  cat "$FFF/core/minimal.fth"
  cat "$FFF/core/lowlevel.fth"
  cat "$FFF/core/midlevel.fth"
  cat "$FFF/core/highlevel.fth"
  cat "$FFF/compiler/xcomp.fth"
  cat "$FFF/core/prims.fth"
)
${XC_TRACE:+1 xc-trace !}
XC-COMPILE-SOURCE
$(cat "$SOURCE")
XC-END
"

"$FOF/../scripts/run-kernel.sh" "$FOF/kernel.s" -u "$INPUT" --speed 0 -t 600 -n 3000000000 2>&1 \
  | sed -n '/^UART output:/,$p' \
  | sed -n '/^!!BEGIN-KERNEL!!$/,/^!!END-KERNEL!!$/p' \
  | sed '1d;$d' \
  | grep -v '^ ok$' \
  > "$OUT_FILE"

echo "build-kernel.sh: wrote $OUT_FILE" >&2
echo "  contents ($(wc -l < "$OUT_FILE") lines):" >&2
sed 's/^/    /' "$OUT_FILE" >&2
