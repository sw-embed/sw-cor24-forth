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
| *current* | **subset 14B** (DUP/DROP/SWAP/OVER/R@ → Forth) | 2718 | −97 | 4102 | 256 | deleted 5 asm dict entries, 4 asm bodies (do_drop body kept — `[']` uses it), deleted dead test threads (do_dup's last caller) |

**14A + 14B net**: +57 − 97 = **−40 lines** of asm. Five stack ops now live
in 5 lines of `core/runtime.fth` (DUP, DROP, OVER, SWAP, R@ each one line).

## Plan's claimed per-subset savings vs. actual

From `docs/plan.md` estimates:

| Subset | Plan claim | Actual (so far) | Notes |
|--------|-----------:|----------------:|-------|
| 14 (stack ops via SP@/SP!/RP@/RP!) | ~150 | **−40** | Plan overestimated. `do_drop` stays (used by `[']`); `>R`/`R>` stay (they need atomic r1/r2 manipulation that Forth can't express). New SP!/RP@/RP! prims add 57 lines. |
| 15 (NAND → derive AND/OR/XOR/INVERT) | ~75 | TBD | |
| 16 (`*`/`/MOD`/`-` as Forth loops) | ~80 | TBD | |
| 17 (`WORD` to Forth, + `WORD-BUFFER` prim) | ~150 | TBD | |
| 18 (`FIND` to Forth) | ~200 | TBD | With XMX hash + lookaside, FIND is intricate — savings uncertain |
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
