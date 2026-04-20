# Status — forth-in-forth

Last updated: 2026-04-20

## Progress

| Subset | Description | State | Commit |
|--------|-------------|-------|--------|
| 1 | Baseline fib example, demo, reg-rs test | done | 86edf74 |
| 2 | Scaffold forth-in-forth/ directory | done | 94e76b2 |
| 3 | Move IF/THEN/ELSE/BEGIN/UNTIL to Forth | done | 686c65f |
| 4 | Move `\` and `(` to Forth (add EOL!) | done | 71e1627 |
| 5 | Stack & arith helpers in core/lowlevel.fth | done | 7d0037c |
| 6 | `=` and `0=` via XOR | done | ce57489 |
| 7 | CR SPACE HEX DECIMAL to Forth | done | 06a8dca |
| 8 | `.` to Forth (hide asm `.`) | done | 12de5b1 |
| 9 | DEPTH / .S to Forth (add SP@ primitive) | done | d65ae26 |
| 10 | WORDS VER SEE to Forth (add `'`, `>NAME`) | done | c908615 |
| 11 | repl.sh and see-demo.sh | done | 8c9104a |

All 11 subsets shipped. The kernel now contains only what genuinely
needs assembly; everything user-visible above the inner interpreter is
written in Forth.

## Today's word movement (subsets 3-11)

**Moved from `.s` → `.fth`** (existed as asm primitives, now Forth) — 18 total:

| Subset | Words |
|--------|-------|
| 3 | IF, THEN, ELSE, BEGIN, UNTIL (5) |
| 4 | `\`, `(` (2) |
| 6 | `=`, `0=` (2) |
| 7 | CR, SPACE, HEX, DECIMAL (4) |
| 8-9 | `.`, DEPTH, .S (3) |
| 10 | WORDS, VER (2) |

**Added in `.s`** (new asm primitives) — 3 total:

| Subset | Word | Why it can't be Forth |
|--------|------|------------------------|
| 3 | `[']` | reads next input token + compiles `LIT cfa`; needed so Forth IF/THEN can name BRANCH/0BRANCH at compile time |
| 4 | `EOL!` | sets the asm-internal word_eol_flag; Forth `\` needs it to tell QUIT the line is done after consuming the newline |
| 9 | `SP@` | exposes the data-stack pointer; required by Forth DEPTH and .S |

**Added in `.fth`** (new derived words, didn't exist before) — 19 total:

| Tier | Words |
|------|-------|
| lowlevel (15) | NIP, TUCK, ROT, -ROT, 2DUP, 2DROP, 2SWAP, 2OVER, 1+, 1-, NEGATE, ABS, /, MOD, 0< |
| highlevel (4) | `'`, PRINT-NAME, >NAME, SEE |

**Net change in asm primitive count**: 18 removed − 3 added = **−15**.
**Net new vocabulary visible at the REPL**: 18 still defined (now in
Forth) − 0 lost + 19 brand-new + 3 new asm primitives = **+22 names**.

## Word counts: before vs. after

| Category | Before today | After today | Δ |
|---|---|---|---|
| asm dictionary entries (`grep -c '^entry_' kernel.s`) | 65 | 50 | −15 |
| of which HIDDEN (LIT, BRANCH, 0BRANCH originally) | 3 | 1 | −2 |
| of which visible at REPL | 62 | 49 | −13 |
| Forth colon defs (`grep -c '^: ' core/*.fth`) | 0 | 37 | +37 |
| **Total vocabulary visible at REPL** | **62** | **86** | **+24** |

Forth defs by tier:

| Tier | Count | Words |
|------|-------|-------|
| minimal.fth | 9 | BEGIN UNTIL IF THEN ELSE `0=` `=` `(` `\` |
| lowlevel.fth | 15 | NIP TUCK ROT -ROT 2DUP 2DROP 2SWAP 2OVER `0<` 1+ 1- NEGATE ABS `/` MOD |
| midlevel.fth | 5 | CR SPACE HEX DECIMAL `.` |
| highlevel.fth | 8 | DEPTH .S `'` PRINT-NAME WORDS VER >NAME SEE |

The 3 new asm primitives added today (`[']`, `EOL!`, `SP@`) are
counted in the asm row above.

## Line counts

| File | Before subset 3 | Now |
|------|-----------------|-----|
| forth.s (original reference, untouched) | 2983 | 2983 |
| forth-in-forth/kernel.s | 2852 | 2239 |
| forth-in-forth/core/minimal.fth | — | 15 |
| forth-in-forth/core/lowlevel.fth | — | 27 |
| forth-in-forth/core/midlevel.fth | — | 25 |
| forth-in-forth/core/highlevel.fth | — | 94 |

Kernel went from 2852 → 2239 lines (−613 lines, −22%).
Assembled binary went from 3879 → 2786 bytes (−1093 bytes, −28%).

## Verified compatibility

- `forth-in-forth/demo.sh examples/14-fib.fth` produces
  `1 1 2 3 5 8 13 21 34 55 89` — matches `reg-rs/tf24a_fth_fib.out`.
- Examples 06-comments, 08-if-then, 10-loop run with output matching
  the original `forth.s` kernel.
- `see-demo.sh` confirms `SEE SQUARE` → `DUP * ;` and `SEE CUBE` →
  `DUP SQUARE * ;`.
- `repl.sh` boots an interactive prompt with all core words loaded.

## Known cosmetic differences

- Forth `.S` prints `<N >` (extra space before `>`) instead of asm's
  `<N>`. The asm version open-coded a single-digit print without
  trailing space; the Forth version uses `.` which always emits one.
  Functionally identical; supports arbitrary depth (asm supported only
  single digits).

## Next directions (not yet planned as subsets)

- Move `*` and `/MOD` to Forth as repeated-add / repeated-subtract
  loops. Saves ~50 more asm lines, costs significant runtime.
- Move `:` and `;` to Forth. Requires a Forth-level way to emit the
  6-byte far-CFA template via `C,`. Saves another ~120 lines but is
  the trickiest move.
- Refine `SEE` to peek at LIT operands and BRANCH offsets and label
  them (currently they print as bare decimal cells).
- Re-baseline the existing reg-rs tests against `forth-in-forth/kernel.s`
  so the new kernel has the same regression coverage as `forth.s`.
