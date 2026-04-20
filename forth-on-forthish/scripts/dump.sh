#!/usr/bin/env bash
# Dump every dictionary word's definition (DUMP-ALL) on the
# forth-on-forthish kernel.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FOF="$HERE/.."
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$FOF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done

INPUT=$'\n'"$(cat "${CORE_FILES[@]}")"$'\nDUMP-ALL\n'

cor24-run --run "$FOF/kernel.s" -u "$INPUT" --speed 0 -n 3000000000 2>&1 \
  | grep "^UART output:" -A 1000 || true
