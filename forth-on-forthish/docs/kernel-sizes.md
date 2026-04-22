# Kernel size tracking — forth-on-forthish

One row per committed milestone. `kernel.s` is the asm source; assembled
bytes come from `cor24-run --run kernel.s` report. Core tier totals are
summed Forth source lines for `runtime/minimal/lowlevel/midlevel/highlevel`.

| Commit | Milestone | kernel.s lines | Δ kernel.s | assembled bytes | core tier lines | Notes |
|--------|-----------|---------------:|-----------:|----------------:|----------------:|-------|
| 79f4350 | subset 12 (scaffold copy of forth-in-forth) | 2239 | — | — | 227 | baseline = pristine forth-in-forth kernel |
| a98b4b8 | subset 13 (Forth `:`/`;`, `,DOCOL`) | 2630 | +391 | — | 229 | new `runtime.fth` tier (2 lines); asm `:`/`;` keep SMUDGE bit handling |
| 3b4f541 | #2 part 1 (AGAIN/WHILE/REPEAT + CONSTANT/VARIABLE) | 2630 | 0 | — | 240 | pure core/*.fth additions; no kernel change |
| 92cef7f | #2 part 2 (DO/LOOP/?DO/I/UNLOOP) | 2758 | +128 | 4099 | 251 | 5 new counted-loop primitives |
| 3dc723b | **subset 14A** (SP!/RP@/RP! primitives) | 2815 | +57 | 4130 | 251 | prerequisite for 14B |
| 16265d8 | **subset 14B** (DUP/DROP/SWAP/OVER/R@ → Forth) | 2718 | −97 | 4102 | 256 | deleted 5 asm dict entries, 4 asm bodies (do_drop body kept — `[']` uses it), deleted dead test threads (do_dup's last caller) |
| 0600ff9 | **subset 15** (NAND prim, AND/OR/XOR/INVERT → Forth) | 2685 | −33 | 4061 | 260 | deleted 3 asm ALU primitives (~51 lines), added NAND primitive (~20 lines), added 4 Forth colon defs in runtime.fth |
| dd08a94 | **subset 16** (`*`, `-`, `/MOD` → Forth) | 2617 | −68 | 3971 | 263 | deleted 3 asm arithmetic primitives (~69 lines). Kept `+` (asm; used everywhere). NEGATE moved to runtime.fth (needs INVERT). `*` = repeated-add loop, `/MOD` = repeated-subtract loop — slower than the `mul`/division-loop asm but within fib's 800M-instruction budget |
| 37b1a68 | **subset 17** (WORD → Forth + WORD-BUFFER/EOL-FLAG prims) | 2628 | **+11** | 3981 | 302 | User-level WORD is now 29-line Forth colon def in lowlevel.fth. Asm `do_word` body **stays** (~140 lines): INTERPRET and tick_word_cfa call it via `.word do_word` directly; no way to replace with Forth WORD's CFA until INTERPRET itself moves to Forth (subset 20). Added WORD-BUFFER and EOL-FLAG primitives (exposing addresses) as 22-line pair. Removed EOL! primitive (~15 lines) — minimal.fth's `\` now uses `1 EOL-FLAG C!`. |
| 01a44bb | **subset 18** (FIND → Forth; PICK added) | 2630 | **+2** | 3973 | 353 | User-visible FIND is a 30-line Forth colon def in highlevel.fth with a 12-line STR= helper. Asm `do_find` body **stays** (~250 lines) — same reason as do_word: INTERPRET and tick_word_cfa reference it by address. Added PICK (1 line) in lowlevel.fth. Removed entry_find dict entry (4 lines); replaced with 4-line comment. No asm shrink. |
| *current* | **subset 19** (NUMBER → Forth; DIGIT-VALUE) | 2630 | **0** | 3963 | 403 | User-visible NUMBER is a ~25-line Forth colon def using a DIGIT-VALUE helper. Asm `do_number` body **stays** (~190 lines) — INTERPRET's thread references it by address, same pattern as WORD/FIND. Dict-entry-for-comment swap is zero-sum. |

**14A + 14B net**: +57 − 97 = **−40 lines** of asm. Five stack ops now live
in 5 lines of `core/runtime.fth` (DUP, DROP, OVER, SWAP, R@ each one line).

**15 net**: **−33 lines** of asm. AND/OR/XOR (4 lines in runtime.fth:
INVERT, AND, OR, XOR) plus 1 new asm primitive (NAND). Classical NAND-gate
identities: `INVERT = DUP NAND`; `AND = NAND INVERT`; `OR = INVERT SWAP
INVERT NAND` (DeMorgan); `XOR = OVER OVER NAND DUP >R NAND SWAP R> NAND
NAND` (4-NAND XOR).

**Cumulative 14+15 savings**: −73 asm lines.

**Cumulative 14+15+16 savings**: −141 asm lines (−5.1% from the 2758-line
pre-14 baseline). Core Forth tier grew from 251 to 263 lines (+12).

**Cumulative 14+15+16+17**: −130 asm lines (subset 17 added 11). Core
Forth tier up to 302 (+39 for WORD's implementation). The full payoff
of moving WORD lands when subset 20 (INTERPRET → Forth) lets us delete
do_word's asm body.

**Cumulative 14+15+16+17+18**: −128 asm lines. Subset 18 is a wiring
commit (same as 17): Forth FIND exists but asm do_find body stays
until INTERPRET moves. Core tier now 353 lines (+51 for FIND/STR=
in highlevel.fth, plus PICK in lowlevel.fth).

**Cumulative 14+15+16+17+18+19**: −128 asm lines (subset 19 zero-sum).
Core tier 403 lines (+50 for NUMBER + DIGIT-VALUE). The three big
asm bodies (do_word 140, do_find 250, do_number 190) total ~580
lines of asm that all delete together in subset 20 when INTERPRET
moves to Forth.

## Plan's claimed per-subset savings vs. actual

From `docs/plan.md` estimates:

| Subset | Plan claim | Actual (so far) | Notes |
|--------|-----------:|----------------:|-------|
| 14 (stack ops via SP@/SP!/RP@/RP!) | ~150 | **−40** | Plan overestimated. `do_drop` stays (used by `[']`); `>R`/`R>` stay (they need atomic r1/r2 manipulation that Forth can't express). New SP!/RP@/RP! prims add 57 lines. |
| 15 (NAND → derive AND/OR/XOR/INVERT) | ~75 | **−33** | Plan overestimated again. NAND prim is 20 lines; the three removed ALU primitives were ~51 lines (17 lines each). Forth defs fit in 4 one-liners. |
| 16 (`*`/`/MOD`/`-` as Forth loops) | ~80 | **−68** | Closest to plan so far. Three asm primitives (`*` 17, `-` 17, `/MOD` 35) went out; `+` stayed. Runtime cost: fib demo bumps from ~8.2s → ~8.5s (within budget). |
| 17 (`WORD` to Forth, + `WORD-BUFFER` prim) | ~150 | **+11** | Plan was wrong about this one. asm `do_word` can't go until INTERPRET is itself Forth (subset 20), because INTERPRET's thread (`.word do_word`) references the asm routine by address, not CFA. Subset 17 is really "wire up the Forth-level WORD and primitives it needs so subset 20 has something to call". Real savings (~140 lines) deferred to subset 20. |
| 18 (`FIND` to Forth) | ~200 | **+2** | Same "wiring" pattern as 17. asm do_find (~250 lines) + hash table + lookaside (~300 more lines) all stay until INTERPRET moves in subset 20. Forth FIND (30 lines), STR= helper (12), PICK (1) added to core tier. |
| 19 (`NUMBER` to Forth) | ~220 | **0** | Same wiring. asm do_number (~190 lines) stays. Forth NUMBER (~25) + DIGIT-VALUE (~8) added to core tier. |
| 19 (`NUMBER` to Forth) | ~220 | TBD | |
| 20 (`INTERPRET`/`QUIT` to Forth) | ~180 | TBD | |

**Aspirational end-state**: ~800 lines. **Realistic projection after 14A+14B
calibration**: if each remaining subset yields 60–70% of its claimed savings
(~460 lines total), kernel lands around **2260 lines**. Getting below 1000
would require additional moves (UART drivers, dictionary helpers, the hash
infrastructure) not in the current plan.

## Method note

`kernel.s` lines counted with `wc -l`; assembled bytes read from `cor24-run`
output. Core tier lines summed across the five `.fth` files in
`forth-on-forthish/core/`. Commit hashes refer to the commit where the
milestone *landed*; deltas are measured against the previous row.
