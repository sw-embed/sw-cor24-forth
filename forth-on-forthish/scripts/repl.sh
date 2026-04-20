#!/usr/bin/env bash
# Interactive REPL for the forth-on-forthish kernel.
# Loads core/{minimal,lowlevel,midlevel,highlevel}.fth, then bridges
# stdin/stdout to the kernel. Ctrl-] exits.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FOF="$HERE/.."
CORE_FILES=()
for tier in minimal lowlevel midlevel highlevel; do
  f="$FOF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done
( cat "${CORE_FILES[@]}"; cat ) \
  | cor24-run --run "$FOF/kernel.s" --terminal --echo --speed 0
