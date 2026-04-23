#!/usr/bin/env bash
# Dump every dictionary word's definition on forth-from-forth.
# Filters core-load " ok" noise via a visible marker.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FOF="$HERE/.."
CORE_FILES=()
for tier in runtime minimal lowlevel midlevel highlevel; do
  f="$FOF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done

MARKER='61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 10 EMIT'
INPUT=$'\n'"$(cat "${CORE_FILES[@]}")"$'\n'"$MARKER"$'\nDUMP-ALL\n'

cor24-run --run "$FOF/kernel.s" -u "$INPUT" --speed 0 -n 3000000000 2>&1 \
  | grep "^UART output:" -A 1000 \
  | awk '/========/{flag=1; next} flag' \
  | sed '/^Executed/q'
