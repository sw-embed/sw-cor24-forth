#!/usr/bin/env bash
# build.sh — Build and test sw-cor24-forth
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== sw-cor24-forth — Tiny Forth for COR24 ==="

# Verify cor24-run is available
if ! command -v cor24-run &>/dev/null; then
  echo "ERROR: cor24-run not found. Build sw-cor24-emulator first."
  exit 1
fi

# Run test suite
echo ""
echo "--- Running test suite ---"
./demo.sh test

echo ""
echo "=== All tests passed ==="
