#!/usr/bin/env bash
# Demo: BEGIN/UNTIL loop
scripts/run-kernel.sh forth.s -u "$(cat examples/10-loop.fth)
" --speed 0 -n 50000000 2>&1 | grep "^UART output:" -A20 | tail -n +3
