#!/usr/bin/env bash
# Run a Forth example against the forth-on-forthish kernel.
#
# Usage:  forth-on-forthish/scripts/demo.sh [example.fth]
# Default example: examples/14-fib.fth (the compatibility baseline).
#
# RESTRICTION: source files passed via this script must not contain the
# literal text \n, \r, \t, or \xNN — cor24-run's --uart-input interprets
# these as escape sequences before the kernel sees the bytes (see
# reg-rs/tf24a_no_bad_escapes.rgt).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FOF="$HERE/.."
cd "$ROOT"
EXAMPLE="${1:-examples/14-fib.fth}"
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$FOF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done
INPUT="$(cat "${CORE_FILES[@]}" "$EXAMPLE" 2>/dev/null)
"
cor24-run --run "$FOF/kernel.s" -u "$INPUT" --speed 0 -n 800000000 2>&1 \
  | grep "^UART output:" -A 200 || true
