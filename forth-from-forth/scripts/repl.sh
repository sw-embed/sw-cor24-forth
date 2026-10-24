#!/usr/bin/env bash
# Interactive REPL for the forth-from-forth kernel.
# Boots the image kernel (core already compiled in), then bridges
# stdin/stdout to the kernel. Ctrl-] exits.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FOF="$HERE/.."
CORE_FILES=()
# kernel.s is an image with the core already compiled in (build-image.sh),
# so no core files are sent.
for tier in; do
  f="$FOF/core/$tier.fth"
  [ -f "$f" ] && CORE_FILES+=("$f")
done
( cat ${CORE_FILES[@]+"${CORE_FILES[@]}"}; cat ) \
  | "$FOF/../scripts/run-kernel.sh" "$FOF/kernel.s" --terminal --echo --speed 0
