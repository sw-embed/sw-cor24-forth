#!/usr/bin/env bash
# compare-core.sh — compare-see.sh over the four upper core tiers (runtime.fth
# is prepended by compare-see.sh itself). Leaves out the QUIT-VECTOR hand-off
# at the end of highlevel.fth, which is top-level code, not a definition.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FFF="$(cd "$HERE/../.." && pwd)"
T="$(mktemp -t compare-core)"; trap 'rm -f "$T"' EXIT
cat "$FFF"/core/{minimal,lowlevel,midlevel,highlevel}.fth \
  | grep -v -x -e "' QUIT QUIT-VECTOR !" -e "QUIT" > "$T"
"$HERE/compare-see.sh" "$T"
