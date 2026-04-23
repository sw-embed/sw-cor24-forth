#!/usr/bin/env bash
# Non-interactive DUMP-ALL demo, mirroring the "SEE (all words)" entry
# in ../web-sw-cor24-forth/src/demos.rs (DUMP_ALL_SRC). Defines SQUARE
# and CUBE first so the listing includes two non-primitive colon defs
# at the top; then DUMP-ALL walks the whole dictionary, printing
# `: NAME body ;` per entry (or `: NAME [primitive] ;` for primitives).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FOF="$HERE/.."
CORE_FILES=()
for tier in runtime minimal lowlevel midlevel highlevel; do
  f="$FOF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done

MARKER='61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 10 EMIT'
INPUT=$'\n'"$(cat "${CORE_FILES[@]}")"$'\n'"$MARKER"$'\n: SQUARE DUP * ;\n: CUBE DUP SQUARE * ;\nDUMP-ALL\n'

cor24-run --run "$FOF/kernel.s" -u "$INPUT" --speed 0 -n 1000000000 2>&1 \
  | grep "^UART output:" -A 1000 \
  | awk '/========/{flag=1; next} flag' \
  | sed '/^ ok$/d; /^$/d; /^Executed/q'
