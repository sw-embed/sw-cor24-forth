# Status — forth-on-forthish

Last updated: 2026-04-22 (phase 3 complete — subsets 12–21 done)

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
| 20 | `INTERPRET`/`QUIT` → Forth (+ `QUIT-VECTOR` prim) | done (partial) | 1c44e0d |
| 21 | Re-baseline reg-rs against this kernel | done | *current* |

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

| File | Subset 13 + #2 | Now (after subset 20) |
|------|---------------:|----------------------:|
| `kernel.s` | 2758 | 2659 |
| `core/runtime.fth` | 2 | 13 |
| `core/minimal.fth` | 18 | 18 |
| `core/lowlevel.fth` | 55 | 121 |
| `core/midlevel.fth` | 25 | 25 |
| `core/highlevel.fth` | 129 | 274 |

Cumulative asm savings through subset 20: **−99 lines** (2758 → 2659).
The original ≤800-line target is no longer realistic in phase 3:
the asm bootstrap can't shrink below the STATE/IMMEDIATE/compile-mode
logic needed to load `runtime.fth`, and the three big asm bodies
(`do_word` ~140, `do_find` ~250, `do_number` ~190 ≈ 580 lines) must
stay alive for the bootstrap. Deleting them requires either a
pre-compiled dict image or the `forth-from-forth` cross-compiled
kernel — deferred out of phase 3. See `docs/kernel-sizes.md` for
the per-subset breakdown and plan-vs-actual.

## Verified compatibility

`scripts/demo.sh examples/14-fib.fth` still matches
`reg-rs/tf24a_fof_fib` after every subset. All 65 reg-rs tf24a
tests pass at HEAD (62daabb).

## Next action

Phase 3 is complete. Further kernel shrinkage moves to the
`forth-from-forth` track (phase 4): cross-compiled kernel, or
pre-compiled dictionary image so the asm bootstrap no longer needs
`do_word`/`do_find`/`do_number`. The existing forth-on-forthish
kernel stays as the baseline Forth-on-asm implementation — the
portable surface (Forth INTERPRET/QUIT) that will migrate to
RCA1802, IBM 1130, IBM 360 without rewrite.
