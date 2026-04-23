#!/usr/bin/env bash
# build-kernel.sh — regenerate forth-from-forth/kernel.s from source.
#
# Pipeline:
#   cat xcomp.fth + prims.fth + core/*.fth + "COMPILE-KERNEL"
#   | cor24-run --run forth-on-forthish/kernel.s --terminal
#   | sed to strip !!BEGIN-KERNEL!! / !!END-KERNEL!! markers
#   > forth-from-forth/kernel.s
#
# Step 002 ships this script as a stub that exits early. Step 003
# wires up the MVP that handles core/runtime.fth end-to-end, and
# step 005 extends coverage to the full core tier.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FFF="$HERE/.."
FOF="$ROOT/forth-on-forthish"

echo "build-kernel.sh: stub (step 002). Cross-compiler pipeline" \
     "activates in step 003." >&2
echo "Until then, forth-from-forth/kernel.s is a verbatim phase-3 copy." >&2
exit 0

# --- below this line: the pipeline that step 003 turns on ---

cd "$ROOT"

{
  cat "$FFF/compiler/xcomp.fth"
  cat "$FFF/core/prims.fth"
  for tier in runtime minimal lowlevel midlevel highlevel; do
    cat "$FFF/core/$tier.fth"
  done
  echo 'COMPILE-KERNEL'
} \
  | cor24-run --run "$FOF/kernel.s" --terminal --speed 0 -n 2000000000 2>&1 \
  | sed -n '/^!!BEGIN-KERNEL!!$/,/^!!END-KERNEL!!$/p' \
  | sed '1d;$d' \
  > "$FFF/kernel.s.new"

mv "$FFF/kernel.s.new" "$FFF/kernel.s"
echo "Regenerated $FFF/kernel.s ($(wc -l < "$FFF/kernel.s") lines)" >&2
