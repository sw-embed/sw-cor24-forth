#!/usr/bin/env bash
# Non-interactive DUMP-ALL demo, mirroring the "SEE (all words)" entry
# in ../web-sw-cor24-forth/src/demos.rs (DUMP_ALL_SRC). Defines SQUARE
# and CUBE first so the listing includes two non-primitive colon defs
# at the top; then DUMP-ALL walks the whole dictionary, printing
# `: NAME body ;` per entry (or `: NAME [primitive] ;` for primitives).
#
# RESTRICTION (see demo.sh): no literal \n/\r/\t/\xNN in source files.
#
# The core/*.fth load produces ~170 " ok" prompts. We inject a visible
# marker (8 '=' then LF) before the demo commands and crop the shown
# output to just what follows, plus filter remaining bare " ok" lines.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FIF="$HERE/.."
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$FIF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done

MARKER='61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 61 EMIT 10 EMIT'
INPUT=$'\n'"$(cat "${CORE_FILES[@]}")"$'\n'"$MARKER"$'\n: SQUARE DUP * ;\n: CUBE DUP SQUARE * ;\nDUMP-ALL\n'

cor24-run --run "$FIF/kernel.s" -u "$INPUT" --speed 0 -n 800000000 2>&1 \
  | grep "^UART output:" -A 1000 \
  | awk '/========/{flag=1; next} flag' \
  | sed '/^ ok$/d; /^$/d; /^Executed/q'
