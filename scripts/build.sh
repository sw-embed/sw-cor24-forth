#!/usr/bin/env bash
# build.sh — Build and test sw-cor24-forth
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== sw-cor24-forth — Tiny Forth for COR24 ==="

# Every kernel run goes through scripts/run-kernel.sh, which finds cor24-asm
# (sw-cor24-x-assembler) and cor24-emu (sw-cor24-emulator) on PATH or in the
# sibling checkouts and says which is missing.
scripts/run-kernel.sh forth.s -n 1 --speed 0 >/dev/null

# Run test suite
echo ""
echo "--- Running test suite ---"
./demo.sh test

echo ""
echo "=== All tests passed ==="
