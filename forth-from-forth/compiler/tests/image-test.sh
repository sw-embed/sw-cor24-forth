#!/usr/bin/env bash
# image-test.sh — compile all five core tiers with the cross-compiler, link
# the emitted dictionary after forth-from-forth/kernel.s, and run a test
# thread that calls compiled words directly (no UART bootstrap, no
# INTERPRET). Proves the emitted dictionary executes, not just that it
# looks right. Expected UART output:
#     1234 -55 42 2 1 3 2 1 3 2 FF
set -euo pipefail
set -f
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
FFF="$ROOT/forth-from-forth"
WORK="${KEEP_WORK:-$(mktemp -d -t image-test)}"; [ -n "${KEEP_WORK:-}" ] || trap 'rm -rf "$WORK"' EXIT; mkdir -p "$WORK"
cd "$ROOT"
# The core minus the QUIT-VECTOR hand-off at the end of highlevel.fth,
# which is top-level code for the UART bootstrap, not a definition.
cat "$FFF"/core/{runtime,minimal,lowlevel,midlevel,highlevel}.fth \
  | grep -v -x -e "' QUIT QUIT-VECTOR !" -e "QUIT" > "$WORK/core.fth"
XC_SOURCE="$WORK/core.fth" XC_OUT="$WORK/dict.s" "$FFF/scripts/build-kernel.sh" >/dev/null 2>&1
n=$(grep -c '^fff_e' "$WORK/dict.s"); u=$(grep -c '^; ?' "$WORK/dict.s" || true)
echo "emitted $n definitions, $u unresolved" >&2
cfa() { grep -oE "^fff_c[0-9]+_$1:" "$WORK/dict.s" | tail -1 | tr -d ':'; }
DOT=$(cfa _46); STAR=$(cfa _42)
w() { echo "    .word $1"; }
lit() { w do_lit; w "$1"; }
{
  cat "$FFF/kernel.s"
  cat "$WORK/dict.s"
  echo "fff_test_start:"
  echo "    mov fp, sp          ; var_sp_base = reset sp, as _start does"
  echo "    push fp"
  echo "    pop r0"
  echo "    la r2, var_sp_base"
  echo "    sw r0, 0(r2)"
  echo "    la r1, 983040"
  echo "    la r2, fff_test_thread"
  echo "    lw r0, 0(r2)"
  echo "    add r2, 3"
  echo "    jmp (r0)"
  echo "fff_test_thread:"
  lit 1234; w "$DOT"
  lit -55; w "$DOT"
  lit 6; lit 7; w "$STAR"; w "$DOT"
  lit 17; lit 5; w "$(cfa MOD)"; w "$DOT"
  lit 1; lit 2; lit 3; w "$(cfa ROT)"; w "$DOT"; w "$DOT"; w "$DOT"
  lit 1; lit 2; lit 3; lit 2; w "$(cfa ROLL)"; w "$DOT"; w "$DOT"; w "$DOT"
  w "$(cfa HEX)"; lit 255; w "$DOT"; w "$(cfa DECIMAL)"
  w "$(cfa CR)"
  w do_bye
} > "$WORK/image.s"
ASM="${COR24_ASM:-$(command -v cor24-asm || echo "$ROOT/../sw-cor24-x-assembler/target/release/cor24-asm")}"
EMU="${COR24_EMU:-$(command -v cor24-emu || echo "$ROOT/../sw-cor24-emulator/target/release/cor24-emu")}"
"$ASM" "$WORK/image.s" -o "$WORK/image.lgo" --entry fff_test_start
"$EMU" --lgo "$WORK/image.lgo" --speed 0 --time 600 -n 200000000 2>&1 | sed -n '/^UART output:/,$p'
