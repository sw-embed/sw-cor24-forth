#!/usr/bin/env bash
# Demo: IF/THEN/ELSE conditional
cor24-run --run forth.s -u "$(cat examples/09-if-else.fth)
" --speed 0 -n 50000000 2>&1 | grep "^UART output:" -A20 | tail -n +3
