# Status — forth-on-forthish

Last updated: 2026-04-22

## Progress

| Subset | Description | State | Commit |
|--------|-------------|-------|--------|
| 12 | Scaffold (kernel + core copies, scripts, docs, reg-rs baseline) | done | 79f4350 |
| 13 | `,DOCOL` + Forth `:`/`;` (SMUDGE via asm `do_colon`/`do_semi`) | done | a98b4b8 |
| 14A | `SP!`/`RP@`/`RP!` primitives | done | 3dc723b |
| 14B | `DUP`/`DROP`/`SWAP`/`OVER`/`R@` → Forth | done | 16265d8 |
| 15 | `NAND` primitive; derive `AND`/`OR`/`XOR`/`INVERT` | done | 0600ff9 |
| 16 | `*`/`/MOD`/`-` → Forth loops | done | dd08a94 |
| 17 | `WORD` → Forth (`WORD-BUFFER`/`EOL-FLAG` prims added) | done | 37b1a68 |
| 18 | `FIND` → Forth (`PICK` added) | done | 01a44bb |
| 19 | `NUMBER` → Forth (`DIGIT-VALUE` helper) | done | 62daabb |
| 20 | `INTERPRET`/`QUIT` → Forth | pending | — |
| 21 | Re-baseline reg-rs against this kernel | pending | — |

## Orthogonal work (not subset-numbered)

Landed in both kernels in parallel, driven by gh issue #2:

- `AGAIN`/`WHILE`/`REPEAT` in `core/minimal.fth` (3b4f541)
- `CONSTANT`/`VARIABLE` in `core/lowlevel.fth` (3b4f541)
- `DO`/`LOOP`/`?DO`/`I`/`UNLOOP` — 5 new primitives + IMMEDIATE
  compilers in `core/lowlevel.fth` (92cef7f)

## Starting state (subset 12)

The kernel was a copy of `./forth-in-forth/kernel.s` (carrying the
FIND hash + lookaside cache work from commits a3a63f0..4ea2f79) and
the core/*.fth files verbatim copies of `./forth-in-forth/core/*.fth`.
This means `forth-on-forthish/scripts/demo.sh examples/14-fib.fth`
produced identical output to `forth-in-forth/scripts/demo.sh
examples/14-fib.fth` — `1 1 2 3 5 8 13 21 34 55 89` — captured as
`reg-rs/tf24a_fof_fib`.

## Line counts

| File | Subset 13 + #2 | Now (after subset 19) | Target (after subset 21) |
|------|---------------:|----------------------:|-------------------------:|
| `kernel.s` | 2758 | 2630 | ≤ 800 |
| `core/runtime.fth` | 2 | 13 | ~150 |
| `core/minimal.fth` | 18 | 18 | 15 |
| `core/lowlevel.fth` | 55 | 121 | ~80 |
| `core/midlevel.fth` | 25 | 25 | 25 |
| `core/highlevel.fth` | 129 | 226 | 129 |

Cumulative asm savings through subset 19: **−128 lines** (2758 → 2630).
Three big asm bodies (`do_word` ~140, `do_find` ~250, `do_number`
~190 ≈ 580 lines) are staged for a single subset 20 delete once
`INTERPRET` moves to Forth and stops referencing them by address.
See `docs/kernel-sizes.md` for the per-subset breakdown and
plan-vs-actual comparison.

## Verified compatibility

`scripts/demo.sh examples/14-fib.fth` still matches
`reg-rs/tf24a_fof_fib` after every subset. All 65 reg-rs tf24a
tests pass at HEAD (62daabb).

## Next action

Subset 20: move `INTERPRET` and `QUIT` to Forth. Keep a minimal asm
bootstrap (STATE + IMMEDIATE + compile-mode) sufficient to compile
`core/runtime.fth` into Forth `INTERPRET`/`QUIT`, then hand control
to Forth `QUIT`. This unblocks deleting `do_word`, `do_find`,
`do_number` bodies (~580 asm lines) and the current monolithic
`do_interpret`/`do_quit`/`stack_underflow_err` (~280 asm lines).
