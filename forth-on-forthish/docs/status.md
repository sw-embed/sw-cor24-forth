# Status — forth-on-forthish

Last updated: 2026-04-20

## Progress

| Subset | Description | State | Commit |
|--------|-------------|-------|--------|
| 12 | Scaffold (kernel + core copies, scripts, docs, reg-rs baseline) | done | 79f4350 (prior) |
| 13 | `,DOCOL` + Forth `:`/`;` (SMUDGE via asm `do_colon`/`do_semi`) | **done** | a98b4b8 |
| 14 | Stack ops via `SP@`/`SP!`/`RP@`/`RP!` | pending | — |
| 15 | `NAND` primitive; derive `AND`/`OR`/`XOR`/`INVERT` | pending | — |
| 16 | `*`/`/MOD`/`-` as Forth loops | pending | — |
| 17 | `WORD` to Forth (add `WORD-BUFFER` primitive) | pending | — |
| 18 | `FIND` to Forth | pending | — |
| 19 | `NUMBER` to Forth | pending | — |
| 20 | `INTERPRET`/`QUIT` to Forth | pending | — |
| 21 | Re-baseline reg-rs against this kernel | pending | — |

## Orthogonal work (not subset-numbered)

Landed in both kernels in parallel, driven by gh issue #2:

- `AGAIN`/`WHILE`/`REPEAT` in `core/minimal.fth` (3b4f541)
- `CONSTANT`/`VARIABLE` in `core/lowlevel.fth` (3b4f541)
- `DO`/`LOOP`/`?DO`/`I`/`UNLOOP` — 5 new primitives + IMMEDIATE
  compilers in `core/lowlevel.fth` (92cef7f)

## Starting state (subset 12)

The kernel is a copy of `./forth-in-forth/kernel.s` (carries the
FIND hash + lookaside cache work from commits a3a63f0..4ea2f79) and
the core/*.fth files are verbatim copies of `./forth-in-forth/core/*.fth`.
This means `forth-on-forthish/scripts/demo.sh examples/14-fib.fth`
produces identical output to `forth-in-forth/scripts/demo.sh
examples/14-fib.fth` — `1 1 2 3 5 8 13 21 34 55 89` — captured as
`reg-rs/tf24a_fof_fib`.

## Line counts

| File | Now (subset 13 + #2) | Target (after subset 21) |
|------|----------------------|--------------------------|
| `kernel.s` | 2758 | ≤ 800 |
| `core/runtime.fth` | 2 (Forth `:` / `;`) | ~150 |
| `core/minimal.fth` | 18 (gained AGAIN/WHILE/REPEAT) | 15 |
| `core/lowlevel.fth` | 55 (gained CONSTANT/VARIABLE/DO/?DO/LOOP) | ~80 |
| `core/midlevel.fth` | 25 | 25 |
| `core/highlevel.fth` | 129 | 129 |

Kernel grew, not shrank, because #2 added counted-loop primitives
(`(DO)`/`(LOOP)`/`(?DO)`/`I`/`UNLOOP`) to *both* kernels. Real kernel
shrinkage starts at subset 14 (move stack ops to Forth via `SP!`/`RP@`).

Projected end-state:
- Asm primitive count: 50 → ~22.
- Forth colon defs: 37 → ~70+.

## Word counts: phase 2 → projected phase 3

| Category | forth-in-forth (phase 2) | forth-on-forthish (target) | Δ |
|---|---:|---:|---:|
| asm dictionary entries | 50 | ~22 | −28 |
| Forth colon defs | 37 | ~70 | +33 |
| **Total REPL vocabulary** | **86** | **~92** | **+6** |

(Net vocabulary grows slightly because we add primitives like `,DOCOL`,
`SP!`, `RP@`, `RP!`, `NAND`, `WORD-BUFFER`, `INVERT`, etc.)

## Verified compatibility

`scripts/demo.sh examples/14-fib.fth` passes through this scaffold
kernel (since it is identical to the forth-in-forth kernel at this
stage). `reg-rs/tf24a_fof_fib` is the baseline that subsequent
subsets must continue to satisfy.

## Next action

Subset 14: add `SP!`/`RP@`/`RP!` primitives (we already have `SP@`),
then move `DUP`/`DROP`/`SWAP`/`OVER`/`>R`/`R>`/`R@` to Forth (each
becomes 3–6 threaded cells instead of a hand-rolled asm push/pop).
Test budget carefully — every word definition after this point
consumes more instructions, since compile-time stack ops now go
through INTERPRET.
