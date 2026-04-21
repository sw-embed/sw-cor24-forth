#!/usr/bin/env bash
# Non-interactive demo of SEE on the forth-on-forthish kernel.
# Filters core-load " ok" noise via a visible marker.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FOF="$HERE/.."
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$FOF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done

MARKER='61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 10 EMIT'
INPUT=$'\n'"$(cat "${CORE_FILES[@]}")"$'\n'"$MARKER"$'\n: SQUARE DUP * ;\n: CUBE DUP SQUARE * ;\n5 SQUARE .\n3 CUBE .\nVER\nSEE SQUARE\nSEE CUBE\n'

cor24-run --run "$FOF/kernel.s" -u "$INPUT" --speed 0 -n 1000000000 2>&1 \
  | grep "^UART output:" -A 400 \
  | awk '/========/{flag=1; next} flag' \
  | sed '/^$/d; /^Executed/q'
