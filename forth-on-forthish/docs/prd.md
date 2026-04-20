# Product Requirements — forth-on-forthish

## Purpose

Push the asm kernel down to the irreducible minimum — roughly the 22
primitives that genuinely cannot be expressed in Forth — and move
everything else (including `:`, `;`, `WORD`, `FIND`, `NUMBER`,
`INTERPRET`, `QUIT`, the stack ops, and `*`/`/MOD`) into Forth.

The result is a kernel so reduced that the Forth code runs **on**
something that's already Forth-**ish** in shape (instead of **in** an
asm-flavored host as in `./forth-in-forth/`).

This is approach 3 in `../../docs/future.md`.

## Audience

- Readers who want to see how thin a hand-written asm Forth kernel can
  practically get.
- Future contributors planning approach 4 (`./forth-from-forth/`); the
  primitive set we settle on here is exactly what the cross-compiler
  has to emit.

## Goals

1. **Cut the asm kernel to ≤ 22 primitives, ≤ 800 lines.** Achieved by
   adding small enabling primitives (`,DOCOL`, `RP@`, `RP!`, `SP!`,
   `NAND`) and removing high-level ones (`:` `;` `WORD` `FIND` `NUMBER`
   `INTERPRET` `QUIT` `*` `/MOD` `-` `AND` `OR` `XOR` plus the asm
   stack-op set).
2. **Keep full compatibility with the forth-in-forth examples.**
   `examples/14-fib.fth` and friends must produce the same UART output
   under `./forth-on-forthish/kernel.s` as under `./forth-in-forth/kernel.s`.
3. **Tiered Forth source survives the move**, with new tiers added if
   needed (likely `core/runtime.fth` for `:`/`;`/`WORD`/`FIND`/etc.
   that come before today's `minimal.fth` content).
4. **Each subset is committed and verified independently** against the
   compatibility target — same incremental discipline as `./forth-in-forth/`.

## Non-goals

- **Not a replacement for `forth-in-forth/`.** Both kernels stay in
  the tree as parallel implementations of the same Forth.
- **No performance work.** Approach-3 Forth is strictly slower than
  approach-2 because more of the bootstrap path is interpreted threaded
  code. Instruction budgets will grow several × — that's expected.
- **No new user-visible features** beyond what `./forth-in-forth/`
  provides. The point is structural reduction of the asm kernel, not
  new vocabulary.

## Success criteria

- `forth-on-forthish/kernel.s` ≤ 800 lines (vs. 2239 in
  `./forth-in-forth/`); equivalently, ≤ ~22 dictionary entries.
- `forth-on-forthish/scripts/demo.sh examples/14-fib.fth` produces
  `1 1 2 3 5 8 13 21 34 55 89` — matching `reg-rs/tf24a_fth_fib.out`.
- `SEE`, `WORDS`, `DUMP-ALL` continue to work.
- A reg-rs test (`tf24a_fof_fib`) pins the new kernel's fib output.

## Out-of-scope risks explicitly accepted

- Compile-time work goes through Forth-defined `:`/`;`/`WORD`/`FIND`/
  `NUMBER`/`INTERPRET`. Loading a non-trivial example at boot will need
  ~10× the instruction budget of `./forth-in-forth/`.
- Bootstrap ordering is harder. The Forth-defined `WORD` and `FIND`
  must be loadable by an asm bootstrap that itself does *almost no
  text processing*. Plan: a tiny pre-stage (just enough to read one
  line of Forth source via `KEY`-loop) that loads the rest.
- Stack ops via `SP@`/`SP!` are slower than direct `push`/`pop`. Every
  `DUP`/`SWAP` becomes 4–6 threaded primitives instead of one asm
  instruction.
