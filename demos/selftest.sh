#!/usr/bin/env bash
# Demo: Show version banner and run kernel test suite
cor24-run --run forth.s --speed 0 -n 5000000 2>&1 | grep "^UART output:" -A3
echo ""
./demo.sh test
