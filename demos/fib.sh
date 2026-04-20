#!/usr/bin/env bash
# Demo: Fibonacci — defines 2DUP 2DROP 2SWAP 2OVER NIP TUCK 1+ 1- FIB, prints FIB(0)..FIB(10)
cor24-run --run forth.s -u "$(cat examples/14-fib.fth)
" --speed 0 -n 40000000 2>&1 | grep "^UART output:" -A30 | tail -n +3
