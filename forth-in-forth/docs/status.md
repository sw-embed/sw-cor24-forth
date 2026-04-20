# Status — forth-in-forth

Last updated: 2026-04-20

## Progress

| Subset | Description | State | Commit |
|--------|-------------|-------|--------|
| 1 | Baseline fib example, demo, reg-rs test | done | 86edf74 |
| 2 | Scaffold forth-in-forth/ directory | done | 94e76b2 |
| 3 | Move IF/THEN/ELSE/BEGIN/UNTIL to Forth | done | 686c65f |
| 4 | Move `\` and `(` to Forth | pending | — |
| 5 | Stack & arith helpers in core/lowlevel.fth | pending | — |
| 6 | `=` and `0=` via XOR | pending | — |
| 7 | CR SPACE HEX DECIMAL to Forth | pending | — |
| 8 | `.` to Forth | pending | — |
| 9 | DEPTH / .S to Forth (add SP@ primitive) | pending | — |
| 10 | WORDS VER SEE to Forth | pending | — |
| 11 | REPL demo | pending | — |

## Line counts

| File | Lines |
|------|-------|
| `forth.s` (original, reference) | 2983 |
| `forth-in-forth/kernel.s` (current) | 2852 |
| `forth-in-forth/core/minimal.fth` | 8 |
| `forth-in-forth/core/lowlevel.fth` | — |
| `forth-in-forth/core/midlevel.fth` | — |
| `forth-in-forth/core/highlevel.fth` | — |

Projected kernel after subset 10: ~2260 lines.
Stretch target (move `*`, `/MOD`, `:`/`;`): ~2000 lines.

## Verified compatibility

`forth-in-forth/demo.sh examples/14-fib.fth` at 200M instructions
produces `1 1 2 3 5 8 13 21 34 55 89`, matching `reg-rs/tf24a_fth_fib.out`
baseline (which ran the same example on `forth.s` at 40M instructions).

Other examples have not yet been re-run on the new kernel; that
happens incrementally as their required words are moved. Compatibility
of all of `examples/00–14` is a subset 10 exit criterion.

## Known issues

None.

## Next action

Subset 4: move `\` and `(` to `core/minimal.fth` using `KEY` loops.
Targets ~70 more asm lines removed.
