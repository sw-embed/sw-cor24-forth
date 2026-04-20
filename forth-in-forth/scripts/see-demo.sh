#!/usr/bin/env bash
# Non-interactive demo of SEE: defines two words, calls them, decompiles them.
#
# RESTRICTION (see demo.sh): no literal \n/\r/\t/\xNN in source files.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FIF="$HERE/.."
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$FIF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done

INPUT=$'\n'"$(cat "${CORE_FILES[@]}")"$'\n: SQUARE DUP * ;\n: CUBE DUP SQUARE * ;\n5 SQUARE .\n3 CUBE .\nVER\nSEE SQUARE\nSEE CUBE\n'

cor24-run --run "$FIF/kernel.s" -u "$INPUT" --speed 0 -n 800000000 2>&1 \
  | grep "^UART output:" -A 200 || true
