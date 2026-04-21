#!/usr/bin/env bash
# Dump every dictionary word's definition (DUMP-ALL).
#
# RESTRICTION (see demo.sh): no literal \n/\r/\t/\xNN in source files.
#
# Filters core-load " ok" noise by injecting a visible marker before
# DUMP-ALL and showing only what follows.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FIF="$HERE/.."
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$FIF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done

MARKER='61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 10 EMIT'
INPUT=$'\n'"$(cat "${CORE_FILES[@]}")"$'\n'"$MARKER"$'\nDUMP-ALL\n'

cor24-run --run "$FIF/kernel.s" -u "$INPUT" --speed 0 -n 2000000000 2>&1 \
  | grep "^UART output:" -A 1000 \
  | awk '/========/{flag=1; next} flag' \
  | sed '/^Executed/q'
