#!/usr/bin/env bash
# Interactive REPL for the forth-in-forth kernel.
#
# Loads core/{minimal,lowlevel,midlevel,highlevel}.fth via UART first,
# then bridges your terminal to the kernel for live use. Ctrl-] exits.
#
# Try at the prompt:
#   1 2 + .
#   : SQUARE DUP * ;  5 SQUARE .
#   SEE SQUARE
#   WORDS
#   DUMP-ALL
#   VER
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FIF="$HERE/.."
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$FIF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done
( cat "${CORE_FILES[@]}"; cat ) \
  | cor24-run --run "$FIF/kernel.s" --terminal --echo --speed 0
