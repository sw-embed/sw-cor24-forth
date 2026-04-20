# Plan — forth-in-forth

Incremental roadmap. Each subset is its own git commit, each passes
the compatibility target (fib first, then other examples touching the
moved words) before the next subset starts.

## Completed

### Subset 1 — establish baseline (commit 86edf74)
- `examples/14-fib.fth` ported from `docs/my-fib.4th`.
- `demos/fib.sh` runs it against `forth.s`.
- `reg-rs/tf24a_fth_fib` locks the compatibility output:
  `1 1 2 3 5 8 13 21 34 55 89`.

### Subset 2 — scaffold (commit 94e76b2)
- `forth-in-forth/kernel.s` = verbatim copy of `forth.s`.
- `forth-in-forth/core.fth` (empty placeholder).
- `forth-in-forth/demo.sh` = minimal harness that pipes core.fth +
  example through UART to the new kernel. Confirmed identical output.

### Subset 3 — control flow to Forth (commit 686c65f)
- Unhid `BRANCH` and `0BRANCH` (flag bytes 70/71 → 6/7).
- Stripped `entry_if` through `entry_until` + their code from asm.
- Added one IMMEDIATE helper `[']` (~30 asm lines).
- Restructured `core.fth` → `core/{minimal,lowlevel,midlevel,highlevel}.fth`.
- `core/minimal.fth`: IF/THEN/ELSE/BEGIN/UNTIL defined in Forth.
- Kernel: 2983 → 2852 lines (−131).

## Upcoming

### Subset 4 — comments to Forth (target: kernel ≈2780)
Move `\` and `(` IMMEDIATE words to `core/minimal.fth`.
Uses `KEY` in a loop until a delimiter char (`\n`/`\r` or `)`).
Depends on nothing we don't already have.

### Subset 5 — stack & arith helpers (target: kernel unchanged, core grows)
Purely additive to `core/lowlevel.fth`:
`ROT NIP TUCK 2DUP 2DROP 2SWAP 2OVER 1+ 1- NEGATE / MOD`.
These are already expressed in `docs/my-fib.4th` — lift them in.

### Subset 6 — `=` and `0=` via XOR (target: kernel ≈2750)
Optional win. `=` becomes `XOR 0=`; `0=` becomes a small Forth def
using `IF`. Keeps `<` in asm for now (signed-compare isn't as easy).

### Subset 7 — simple I/O to Forth (target: kernel ≈2690)
`CR SPACE HEX DECIMAL` to `core/midlevel.fth`. Each is 2–3 lines of
Forth (EMIT 10, EMIT 32, 16 BASE !, 10 BASE !).

### Subset 8 — `.` to Forth (target: kernel ≈2560, the big one)
`.` in `core/midlevel.fth` using `/MOD`, `BASE @`, and a digit-push
loop. ~10 Forth lines replaces ~130 asm lines.
Risk: need to be careful with negative-number handling to match the
existing `-5  ok` output style.

### Subset 9 — `DEPTH` and `.S` (target: kernel ≈2360)
Requires one new primitive `SP@` (push data-stack pointer). Then
`DEPTH` computes `sp_base - SP@ / 3` in Forth; `.S` walks the stack
with `.` printing each cell. Trades ~200 asm lines for ~15 Forth
lines plus one new 10-line primitive.

### Subset 10 — `WORDS`, `VER`, `SEE` (target: kernel ≈2260)
`WORDS` walks `LATEST @` following link fields, emitting each name.
`VER` becomes a simple colon def printing the banner.
`SEE` is new: takes a word name, walks the threaded body, reverse-
looks up each CFA in the dictionary, prints `name ` for each. Brief
treatment of primitives (which have no body) as `[primitive name]`.
This is the decompilation demo the user asked for.

### Subset 11 — REPL demo (no asm change)
`forth-in-forth/repl.sh` pipes `core/*.fth` through UART first and
then hands off to `cor24-run --terminal --echo` for live use. User
can `SEE FIB`, `WORDS`, define new words interactively.

## Open questions

- **Do we want to move `*` and `/MOD` to Forth?** They'd become
  repeated-addition / repeated-subtraction loops. Educational value:
  high. Runtime cost: significant (FIB uses `+ -` but not `*`; no
  examples use heavy multiplication). **Deferred to `./forth-on-forthish/`**
  (the next-phase project) — see `../../docs/future.md`.
- **Should the final kernel keep asm `:` and `;`?** Moving them would
  require a Forth-level way to emit the 6-byte far-CFA template.
  Technically possible with `C,` and some `CREATE` tricks. Would save
  another ~120 asm lines. **Deferred to `./forth-on-forthish/`** —
  it's the centerpiece of that approach.
- **Regression tests for each subset?** Current plan: rely on
  `examples/14-fib.fth` as the smoke test for every subset, plus ad
  hoc runs of examples that specifically exercise the moved words
  (08/09 for IF/THEN, 10 for BEGIN/UNTIL, 06 for comments, 00/12 for
  smoke/selftest). Adding per-subset reg-rs baselines against the
  `forth-in-forth/kernel.s` can come after subset 10 once the kernel
  stabilizes.

## Dependency graph

```
  [1: baseline] → [2: scaffold] → [3: control flow]
                                        ↓
                                  [4: comments]
                                        ↓
                      ┌── [5: stack helpers (additive)]
                      ↓
                [6: = 0=]     [7: CR SPACE HEX DECIMAL]
                      ↓                   ↓
                      └─── [8: `.`] ──────┘
                               ↓
                         [9: DEPTH .S]
                               ↓
                      [10: WORDS VER SEE]
                               ↓
                         [11: REPL demo]
                               ↓
                  ──────────────────────────────────────
                  Beyond `./forth-in-forth/` (separate dirs):
                  - `./forth-on-forthish/`  approach 3 (minimal primitives)
                  - `./forth-from-forth/`   approach 4 (cross-compiled kernel)
```
