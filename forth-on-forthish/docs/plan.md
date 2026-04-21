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

## Upcoming

### Subset 13 — `,DOCOL` primitive + move `:` and `;` to Forth — PARTIAL

**Done**: added `,DOCOL` primitive. It emits the 6-byte far-CFA
template at HERE — exactly what asm `do_colon_cfa` does internally,
now exposed as a named dictionary entry so Forth code can build
colon headers without asm assistance.

**Blocked**: actually moving `:` and `;` to Forth hits the classic
"SMUDGE bit" problem. Sketch:

```
: ; ['] EXIT , 0 STATE ! ; IMMEDIATE   \ defining Forth ;
```

When the compiler reaches the final `;` token at end of this
line, `FIND` walks LATEST and returns the **in-progress NEW `;`
entry** (CREATE published its header at the start of the line).
Since NEW `;` has an incomplete body, executing it immediately
(because it's IMMEDIATE) runs partial threaded code and falls off
into random memory.

Standard Forth kernels avoid this by setting a SMUDGE/HIDDEN bit
at CREATE time and clearing it at `;`. Our asm `:` / `;` don't do
this (they don't need to — asm `:` never re-enters itself during
compile).

**Unblocking options** (for a follow-up subset):
- **(a) Small asm tweak**: extend `do_colon` to OR 0x40 (HIDDEN)
  into `flags_len` of the new entry; extend `do_semi` to AND
  ~0x40 to clear. ~10 asm lines total. Then Forth `:`/`;` can
  bootstrap normally.
- **(b) HIDE-LATEST / UNHIDE-LATEST primitives**: expose the bit
  manipulation as named words. Forth `:` and `;` call them.
- **(c) Modify CREATE** to always set HIDDEN, plus a way to clear
  at `;`. Semantic change.

Resolution deferred — see docs/design.md.

Saves ~150 asm lines when unblocked.

### Subset 14 — stack ops via `SP@`/`SP!`/`RP@`/`RP!`
Add `SP!`, `RP@`, `RP!` primitives (`SP@` already exists). Move
`DUP`, `DROP`, `SWAP`, `OVER`, `>R`, `R>`, `R@` to Forth. They
become 3–6 threaded cells each instead of asm push/pop pairs.

Bootstrap concern: `:` itself uses these stack ops at compile time
via INTERPRET. Once they're Forth, every word definition involves
many more threaded cycles. Test carefully.

Saves ~150 asm lines.

### Subset 15 — `NAND` primitive, derive `AND`/`OR`/`XOR`/`INVERT`
Add `NAND`. Move `AND`/`OR`/`XOR` to `core/lowlevel.fth` as
NAND-derivations. Add `INVERT`. Saves ~75 asm lines.

### Subset 16 — `*` and `/MOD` and `-` as Forth loops
`-` becomes `NEGATE +`. `*` becomes `+`-accumulator loop. `/MOD`
becomes repeated-subtract loop. All move to `core/lowlevel.fth`.
Saves ~80 asm lines.

### Subset 17 — `WORD` to Forth (with `WORD-BUFFER` primitive)
Add `WORD-BUFFER` ( -- addr ) that pushes a known fixed address
where `WORD` builds its counted string. Then `WORD` becomes a
Forth `KEY`-loop into that buffer.

Saves ~150 asm lines.

### Subset 18 — `FIND` to Forth
Walks `LATEST @` chain in Forth using `@`, `C@`, `=`, `AND`. Saves
~200 asm lines.

### Subset 19 — `NUMBER` to Forth
Digit parsing in Forth using `*`, `+`, `<`, `BASE @`. Saves
~220 asm lines.

### Subset 20 — `INTERPRET` and `QUIT` to Forth
The outer loop becomes a Forth `BEGIN…UNTIL` over
`WORD`/`FIND`/`EXECUTE`/`NUMBER`. The asm kernel keeps a tiny
~30-line bootstrap loop just to load `runtime.fth`.

Saves ~180 asm lines.

### Subset 21 — re-baseline reg-rs tests
Re-run the existing reg-rs suite against `forth-on-forthish/kernel.s`,
adjust instruction budgets where needed, capture new baselines under
`reg-rs/tf24a_fof_*`.

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
