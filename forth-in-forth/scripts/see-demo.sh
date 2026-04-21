#!/usr/bin/env bash
# Non-interactive demo of SEE: defines two words, calls them, decompiles
# them, and dumps the whole dictionary.
#
# RESTRICTION (see demo.sh): no literal \n/\r/\t/\xNN in source files.
#
# The core/*.fth load produces ~170 lines of " ok" noise. We inject a
# visible marker (42 EMITs of '=') before the test commands and crop the
# shown output to just what follows.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FIF="$HERE/.."
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$FIF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done

MARKER='61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 10 EMIT'
INPUT=$'\n'"$(cat "${CORE_FILES[@]}")"$'\n'"$MARKER"$'\n: SQUARE DUP * ;\n: CUBE DUP SQUARE * ;\n5 SQUARE .\n3 CUBE .\nVER\nSEE SQUARE\nSEE CUBE\n'

cor24-run --run "$FIF/kernel.s" -u "$INPUT" --speed 0 -n 800000000 2>&1 \
  | grep "^UART output:" -A 400 \
  | awk '/========/{flag=1; next} flag' \
  | sed '/^$/d; /^Executed/q'
