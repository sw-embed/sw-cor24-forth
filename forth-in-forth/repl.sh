#!/usr/bin/env bash
# Interactive REPL for the forth-in-forth kernel.
#
# Loads core/{minimal,lowlevel,midlevel,highlevel}.fth via UART first,
# then bridges your terminal to the kernel. Type Forth at the prompt;
# Ctrl-] exits.
#
# Try:
#   1 2 + .
#   : SQUARE DUP * ;  5 SQUARE .
#   SEE SQUARE
#   WORDS
#   VER
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$HERE/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done
# Concatenate the .fth tiers, then continue reading from the terminal.
# The trailing `cat` keeps stdin open for live input after the bootstrap.
( cat "${CORE_FILES[@]}"; cat ) \
  | cor24-run --run "$HERE/kernel.s" --terminal --echo --speed 0
