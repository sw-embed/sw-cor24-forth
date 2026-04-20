#!/usr/bin/env bash
# Dump every dictionary word's definition. For colon defs, prints
# `: NAME body... ;` via SEE-CFA. For primitives, prints
# `: NAME [primitive] ;`. Uses DUMP-ALL (in core/highlevel.fth).
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

INPUT=$'\n'"$(cat "${CORE_FILES[@]}")"$'\nDUMP-ALL\n'

cor24-run --run "$FIF/kernel.s" -u "$INPUT" --speed 0 -n 2000000000 2>&1 \
  | grep "^UART output:" -A 1000 || true
