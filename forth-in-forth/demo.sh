#!/usr/bin/env bash
# Demo: Run a Forth example against the forth-in-forth kernel.
#
# Usage:  forth-in-forth/demo.sh [example.fth]
# Default: ../examples/14-fib.fth (the compatibility baseline)
#
# Pipes core.fth (Forth-defined words) followed by the chosen example
# through UART into the minimal kernel. During subset 2 core.fth is
# empty and the kernel is a verbatim copy of forth.s — this just proves
# the harness and directory structure are wired up.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."
EXAMPLE="${1:-examples/14-fib.fth}"
# Concatenate all core tiers (minimal → lowlevel → midlevel → highlevel)
# in a fixed order so lower tiers are defined before higher tiers use them.
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$HERE/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done
INPUT="$(cat "${CORE_FILES[@]}" "$EXAMPLE" 2>/dev/null)
"
cor24-run --run "$HERE/kernel.s" -u "$INPUT" --speed 0 -n 200000000 2>&1 \
  | grep "^UART output:" -A 200 || true
