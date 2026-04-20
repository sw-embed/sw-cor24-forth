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
CORE="$HERE/core.fth"
[ -f "$CORE" ] || touch "$CORE"
INPUT="$(cat "$CORE" "$EXAMPLE")
"
cor24-run --run "$HERE/kernel.s" -u "$INPUT" --speed 0 -n 40000000 2>&1 \
  | grep "^UART output:" -A 100 || true
