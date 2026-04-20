# Design notes — forth-in-forth

Captures the key decisions made while building this kernel, including
why certain things stay in asm and why the first-draft Forth
definitions had to be revised.

## Why not self-host `FIND` / `WORD` / `NUMBER`?

These three are the largest primitives in `forth.s` (~400 lines total).
Rewriting them in Forth is technically possible but requires a
bootstrap trick: you need at minimum a character-level `KEY`-loop
interpreter in asm just so that the Forth versions of `FIND`/`WORD`
can get loaded. That bootstrap is its own ~100-line bundle of
primitives. The net savings would be negative.

Pragmatic choice: keep them in asm. They're already debugged (the
compatibility target depends on their exact behavior, including EOL
handling and the `word_buffer` convention) and moving them would
churn things without educational benefit.

## Why unhide `BRANCH` and `0BRANCH`?

In `forth.s` both had `HIDDEN` set in their flag byte (so `FIND`
skips them). That's fine when `IF`/`THEN`/`BEGIN`/`UNTIL` are asm
primitives writing `do_zbranch`'s code label directly into HERE:

```asm
la r0, do_zbranch
sw r0, 0(r2)      ; mem[HERE] = do_zbranch
```

Once `IF` is a Forth colon def, it can't reference a C-like symbol.
It needs to compile the CFA of a *named word*. Unhiding `BRANCH` and
`0BRANCH` lets `[']` look them up. The user can now accidentally type
`0BRANCH` at the REPL, but that's a small price for the
simplification.

## Why a single new primitive `[']`?

Three alternatives were considered:

1. **`LIT,`** `( xt -- )`: takes an xt on the stack and compiles
   `LIT xt`. Doesn't work directly for `IF` because IF needs the
   0BRANCH xt embedded in IF's **own body** at compile time, not
   read from IF's runtime data stack.
2. **Standalone `CONSTANT`s** holding the CFAs:
   `' 0BRANCH CONSTANT _0BR`, then `: IF _0BR , HERE 0 , ;`.
   Requires both `CONSTANT` and `'` (tick). `'` is essentially
   what `[']` already is; `CONSTANT` is another colon-like
   defining word.
3. **`[']` directly** — the ANS Forth name for exactly this
   need. Implemented as a short `DOCOL_far` colon def using
   only already-present primitives (`WORD FIND DROP LIT , EXIT`).
   Minimal. Chosen.

## Why the tiered `core/*.fth` layout?

Initially a single `core.fth`. Split into `minimal/lowlevel/midlevel/highlevel`
so that:

- **Each tier builds only on what came before.** `minimal.fth` uses
  nothing but primitives. `lowlevel.fth` uses primitives + `minimal`.
  This keeps the dependency DAG easy to reason about when extending.
- **Tests can load partial stacks.** A regression test that only
  exercises control flow needs `minimal.fth`; no need to pay the
  compile cost of `.` or `.S`.
- **The teaching story is linear.** Readers can walk the four files
  in order and see Forth extending itself layer by layer.

`demo.sh` concatenates whichever tiers exist in order, so adding a
new tier doesn't require updating the harness — dropping a file into
`core/` is enough.

## The HERE-address pitfall

`forth.s` defines `HERE` as pushing `&var_here_val`, not the value
itself. This is a pattern used for all four system variables so they
can be written with `!`:

```asm
do_here:
    la r0, var_here_val
    push r0
```

When Forth-level IF was first drafted as `: IF ['] 0BRANCH , HERE 0 , ; IMMEDIATE`,
this silently failed: `HERE` pushed `&HERE`, then `0 ,` wrote 0 at
whatever HERE pointed to, then `&HERE` was left on the stack as a
"patch address". THEN's `!` wrote the computed offset into `&HERE`
itself, overwriting the dictionary pointer. First IF in a line worked
by luck; subsequent tokens on the same line went to garbage because
the dictionary was corrupt.

**Fix**: every place Forth code wants the current value of a system
variable, write `HERE @` (or `LATEST @` etc.). Documented explicitly
in `architecture.md` because this convention is unusual and would
otherwise keep biting.

Trade-off considered: we could have *changed* the kernel to push
values, ANS-style, and provide `HERE!` etc. for the write side. That
would have required touching `forth.s`'s primitives *and* the existing
reg-rs tests that rely on the current behavior. Cheaper to document
the convention and fetch explicitly in the Forth files.

## Instruction budget growth

Moving IMMEDIATE words to Forth makes *compilation* slower (each
`IF`/`THEN` now runs a small threaded sequence instead of a dozen
inline asm instructions). Runtime of the compiled user code is
unaffected — the end result is still `0BRANCH offset`.

Baseline `examples/14-fib.fth` on `forth.s`: 40M instructions.
On the subset-3 kernel: ~120M instructions suffice; `demo.sh` uses
200M for headroom. Expect this to grow roughly 1.5–2× more as
`.` `CR` and friends become colon defs.

## What subsequent subsets cost and save

| Subset | Moves                          | Est. asm lines saved | Risk |
|--------|--------------------------------|----------------------|------|
| 4      | `\` `(` comments               | ~70                  | low  |
| 5      | stack helpers, arith helpers   | 0 (additive)         | low  |
| 6      | `= 0=` via XOR                 | ~30                  | low  |
| 7      | `CR SPACE HEX DECIMAL`         | ~60                  | low  |
| 8      | `.`                            | ~130                 | med  |
| 9      | `DEPTH .S` + new `SP@`         | ~200 (minus ~15)     | med  |
| 10     | `WORDS VER SEE`                | ~100                 | low  |

Projected kernel after all subsets: ~2300 lines (down from ~3000).
Further reductions (e.g. moving `*` and `/MOD` to Forth loops, or
moving `:` and `;`) are deferred to `./forth-on-forthish/` — see
`../../docs/future.md` for the full four-approach plan, including the
fully cross-compiled `./forth-from-forth/` end state.
