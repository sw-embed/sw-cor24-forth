# Plan — forth-on-forthish

Incremental subsets, modeled on the `./forth-in-forth/` discipline.
Each subset is a single git commit; each must keep
`scripts/demo.sh examples/14-fib.fth` passing the
`reg-rs/tf24a_fof_fib` baseline before the next subset starts.

## Completed

### Subset 12 — scaffold (this commit)
- `forth-on-forthish/kernel.s` = verbatim copy of
  `forth-in-forth/kernel.s` (50 dict entries).
- `forth-on-forthish/core/*.fth` = verbatim copies of the four
  forth-in-forth tiers.
- `scripts/{demo,see-demo,dump,repl}.sh`: paths adjusted; functionality
  identical to the forth-in-forth equivalents.
- `docs/{prd,architecture,design,plan,status}.md`: this set.
- `reg-rs/tf24a_fof_fib`: pins fib output through this kernel.

### Subset 13 — `,DOCOL` primitive + Forth `:` / `;` — DONE (a98b4b8)

- `,DOCOL` primitive exposes the 6-byte far-CFA template (asm
  `do_colon_cfa`) as a named dictionary entry.
- SMUDGE/HIDDEN handling added to asm `do_colon` / `do_semi` per
  option **(a)** from the three options originally considered:
  `do_colon` sets bit 6 of `flags_len`, `do_semi` clears it. ~15 asm
  lines total.
- `core/runtime.fth` introduced as the earliest-loading Forth tier
  with: `: : CREATE ,DOCOL LATEST @ 3 + DUP C@ 64 OR SWAP C! ] ;`
  and `: ; ['] EXIT , LATEST @ 3 + DUP C@ 191 AND SWAP C! 0 STATE ! ; IMMEDIATE`.

### Subset 14A — `SP!`/`RP@`/`RP!` primitives — DONE (3dc723b)

Added the three missing stack-pointer primitives (`SP@` already
existed). Prerequisite for 14B.

### Subset 14B — `DUP`/`DROP`/`SWAP`/`OVER`/`R@` → Forth — DONE (16265d8)

5 stack ops now live in 5 one-liners in `core/runtime.fth`.
`>R`/`R>` kept in asm: they need atomic r1/r2 manipulation that
Forth can't express. `do_drop` body kept: `[']` references it by
address. Net: **−40 asm lines** (plan claimed ~150 — over-estimated
because `do_drop`/`>R`/`R>` had to stay).

### Subset 15 — `NAND` primitive, derive `AND`/`OR`/`XOR`/`INVERT` — DONE (0600ff9)

Added `NAND` asm primitive (~20 lines); deleted `AND`/`OR`/`XOR`
asm bodies (~51 lines). 4 one-liners in `runtime.fth` via classical
NAND identities: `INVERT = DUP NAND`, `AND = NAND INVERT`, `OR =
INVERT SWAP INVERT NAND`, `XOR = OVER OVER NAND DUP >R NAND SWAP
R> NAND NAND`. Net: **−33 asm lines** (plan ~75).

### Subset 16 — `*`/`-`/`/MOD` → Forth loops — DONE (dd08a94)

`-` = `NEGATE +`; `*` = repeated-add loop; `/MOD` = repeated-
subtract loop. `+` kept in asm (used everywhere). `NEGATE` moved
to `runtime.fth` (needs `INVERT` from subset 15). Runtime cost:
fib demo ~8.2s → ~8.5s, within 800M-instruction budget. Net:
**−68 asm lines** (plan ~80, closest match so far).

### Subset 17 — `WORD` → Forth (+ `WORD-BUFFER`/`EOL-FLAG` prims) — DONE (37b1a68)

User-visible `WORD` is now a 29-line Forth def in `lowlevel.fth`.
Asm `do_word` body (~140 lines) **stays** — `INTERPRET`'s thread
and `tick_word_cfa` reference it by address, not by CFA. Added
`WORD-BUFFER`/`EOL-FLAG` primitives (~22 lines) exposing fixed
addresses. Removed `EOL!` (~15 lines): `\` now uses
`1 EOL-FLAG C!`. Net: **+11 asm lines** (plan expected ~150
savings; real payoff deferred to subset 20).

### Subset 18 — `FIND` → Forth (+ `PICK`) — DONE (01a44bb)

User-visible `FIND` is a 30-line Forth def in `highlevel.fth`
with a 12-line `STR=` helper. Asm `do_find` + hash + lookaside
(~550 lines total) **stay** for the same reason as `do_word`:
`INTERPRET` references them by address. Added `PICK` (1 line).
Net: **+2 asm lines** (plan expected ~200 savings; deferred to 20).

### Subset 19 — `NUMBER` → Forth (+ `DIGIT-VALUE`) — DONE (62daabb)

User-visible `NUMBER` is a ~25-line Forth def in `highlevel.fth`
with an 8-line `DIGIT-VALUE` helper. Asm `do_number` (~190 lines)
**stays** — same wiring pattern as 17/18. Net: **0 asm lines**
(plan expected ~220; deferred to 20).

### Subset 20 — `INTERPRET` and `QUIT` to Forth — DONE (partial, *current*)

Forth `INTERPRET` and `QUIT` added to `highlevel.fth`; their CFAs
installed in a new `QUIT-VECTOR` primitive and QUIT invoked at the
end of the file to hand control off the asm bootstrap. Once that
line runs, all subsequent input (including `examples/*.fth`) flows
through Forth. `stack_underflow_err` reworked to prefer Forth QUIT
when the vector is set; falls back to asm `do_quit` during bootstrap.

**Plan claimed ~180 asm lines saved. Actual: +29 (kernel grew).**
The aspirational "~30-line bootstrap" was wrong: the asm boot loop
genuinely needs STATE + IMMEDIATE + compile-mode to parse runtime.fth
at all. The ~580-line asm bodies (`do_word`/`do_find`/`do_number`)
plus the ~280-line `do_interpret`/`do_quit`/`stack_underflow_err`
stay because the bootstrap still references them by address.

**What actually landed:** the runtime REPL (post-boot) is written
in Forth — the portable surface that will migrate unchanged to
RCA1802, IBM 1130, IBM 360, and beyond. Further kernel shrinkage
is deferred to the `forth-from-forth` / pre-compiled-image track.

### Subset 21 — re-baseline reg-rs tests — DONE (*current*)

Only one reg-rs test targets `forth-on-forthish/kernel.s`:
`tf24a_fof_fib`. Preprocess widened from `grep -A 100` to
`grep -A 250` so the fib numbers actually land inside the captured
window (subset 20 added ~22 " ok" lines during highlevel load,
pushing the fib output past line 100). Baseline rebased with
`reg-rs rebase`; repo's `reg-rs/tf24a_fof_fib.{rgt,out}` updated
to match `~/.local/reg-rs/`. All 65 `tf24a` tests pass.

## Phase 3 complete

The forth-on-forthish track is complete at this scope. Kernel
landed at **2659 asm lines**, 99 below pre-subset-14 baseline but
well above the aspirational ≤800. Core Forth tier grew from 229
to 450 lines. The runtime REPL is now in Forth.

Further kernel shrinkage moves to the `forth-from-forth` / phase 4
track: cross-compiled kernel or pre-compiled dictionary image,
which would let us delete the asm bootstrap (including `do_word`,
`do_find`, `do_number` bodies ≈ 580 asm lines, plus
`do_interpret`/`do_quit` ≈ 280 lines).

## Open questions

- **Will the boot-time instruction budget become impractical?** Each
  Forth-defined `:` of a Forth-defined `:` definition takes several ×
  more instructions to compile. Loading 200 lines of `core/*.fth` may
  need 5–10 GB instructions. May need to compile incrementally and
  cache, or just accept multi-second boot times.
- **Can we collapse `runtime.fth` and `minimal.fth`?** Perhaps. They
  serve similar bootstrap roles. Leave separate at first for
  pedagogical clarity.
- **`HERE` pushing address vs value** — phase 4 might change this.
  Phase 3 keeps the existing convention.

## Dependency graph

```
  [12: scaffold (today)] ── reg-rs/tf24a_fof_fib baseline
           ↓
  [13: ,DOCOL + : ;] ──── new core/runtime.fth tier
           ↓
  [14: stack ops via SP@/SP!/RP@/RP!]
           ↓
  [15: NAND, derive AND OR XOR]
           ↓
  [16: * /MOD - as Forth loops]
           ↓
  [17: WORD to Forth (+ WORD-BUFFER prim)]
           ↓
  [18: FIND to Forth]
           ↓
  [19: NUMBER to Forth]
           ↓
  [20: INTERPRET/QUIT to Forth]
           ↓
  [21: re-baseline reg-rs against forth-on-forthish kernel]
           ↓
  ─────────────────────────────────────────
  Beyond `./forth-on-forthish/`:
  - `./forth-from-forth/` (approach 4: cross-compiled kernel)
```
