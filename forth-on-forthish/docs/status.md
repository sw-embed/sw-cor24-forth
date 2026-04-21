# Status — forth-on-forthish

Last updated: 2026-04-20

## Progress

| Subset | Description | State | Commit |
|--------|-------------|-------|--------|
| 12 | Scaffold (kernel + core copies, scripts, docs, reg-rs baseline) | done | (this commit) |
| 13 | `,DOCOL` primitive + move `:` and `;` to Forth | pending | — |
| 14 | Stack ops via `SP@`/`SP!`/`RP@`/`RP!` | pending | — |
| 15 | `NAND` primitive; derive `AND`/`OR`/`XOR`/`INVERT` | pending | — |
| 16 | `*`/`/MOD`/`-` as Forth loops | pending | — |
| 17 | `WORD` to Forth (add `WORD-BUFFER` primitive) | pending | — |
| 18 | `FIND` to Forth | pending | — |
| 19 | `NUMBER` to Forth | pending | — |
| 20 | `INTERPRET`/`QUIT` to Forth | pending | — |
| 21 | Re-baseline reg-rs against this kernel | pending | — |

## Starting state (subset 12)

The kernel is a copy of `./forth-in-forth/kernel.s` (carries the
FIND hash + lookaside cache work from commits a3a63f0..4ea2f79) and
the core/*.fth files are verbatim copies of `./forth-in-forth/core/*.fth`.
This means `forth-on-forthish/scripts/demo.sh examples/14-fib.fth`
produces identical output to `forth-in-forth/scripts/demo.sh
examples/14-fib.fth` — `1 1 2 3 5 8 13 21 34 55 89` — captured as
`reg-rs/tf24a_fof_fib`.

## Line counts

| File | Now (subset 12) | Target (after subset 21) |
|------|-----------------|--------------------------|
| `kernel.s` | 2239 | ≤ 800 |
| `core/runtime.fth` | — (will exist after subset 13) | ~150 |
| `core/minimal.fth` | 15 | 15 |
| `core/lowlevel.fth` | 27 | ~80 (gains `*` `/MOD` `-` AND OR XOR) |
| `core/midlevel.fth` | 25 | 25 |
| `core/highlevel.fth` | 94 | 94 |

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

Subset 13: add `,DOCOL` primitive, move `:` and `;` to Forth.
Introduce `core/runtime.fth` as the new earliest-loading tier.
