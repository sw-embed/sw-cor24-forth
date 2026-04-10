#!/usr/bin/env bash
# Demo: FizzBuzz 1-20
cor24-run --run forth.s -u "$(cat examples/11-fizzbuzz.fth)
" --speed 0 -n 200000000 2>&1 | grep "^UART output:" -A30 | tail -n +5
