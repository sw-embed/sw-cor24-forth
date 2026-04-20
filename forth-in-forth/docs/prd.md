# Product Requirements — forth-in-forth

## Purpose

Demonstrate that Forth can extend itself. Replace as much of the
existing assembly kernel (`forth.s`) as possible with Forth code
loaded at boot, while keeping the asm portion small and focused on
primitives that genuinely require machine code.

## Audience

- People learning how Forth works from the inside (how `IF`/`THEN`
  lay down branch offsets; how `:` and `;` compile headers and exits;
  how `CREATE` and `,` turn input text into dictionary entries).
- Contributors to the COR24 ecosystem who want a smaller, easier-to-read
  kernel than `forth.s`.

## Goals

1. **Minimal asm kernel.** The `.s` file should contain only primitives
   that need to access hardware, the inner interpreter, or dictionary
   state directly. Everything else moves to `.fth` files.
2. **Bootstrap over UART.** No special loader. The host feeds
   `core/*.fth` followed by the chosen example through UART; the
   kernel's existing `QUIT` interprets line by line.
3. **Full backward compatibility.** All existing `examples/00–14.fth`
   must produce byte-for-byte identical UART output (modulo timing
   stamps) under the new kernel.
4. **Tiered Forth source.** `core/minimal.fth` must load first and
   contain just enough to make higher-tier files expressible in normal
   Forth (control flow, comments). `core/lowlevel.fth`, `midlevel.fth`,
   `highlevel.fth` each build on what preceded them.
5. **Diagnostic Forth.** Ship a `SEE` word that can decompile any
   colon definition, plus a `repl.sh` that lands you at an interactive
   prompt after `core/*.fth` has loaded.

## Non-goals

- **Not a replacement for `forth.s`.** The existing kernel remains the
  canonical runtime used by the web frontend, existing demos, and
  regression tests. `forth-in-forth/` is an educational parallel
  implementation.
- **No performance improvements.** Moving work from asm to threaded
  Forth is strictly slower. Instruction budgets for tests will grow.
- **No ANS Forth compliance.** Only the subset the existing examples
  rely on.

## Success criteria

- `forth-in-forth/kernel.s` is materially smaller than `forth.s`
  (target: under 2100 lines; stretch: under 1500).
- `forth-in-forth/demo.sh examples/14-fib.fth` produces
  `1 1 2 3 5 8 13 21 34 55 89` — matching `reg-rs/tf24a_fth_fib.out`.
- Each of `examples/00–14.fth` runs under the new kernel and
  produces the same UART output as the original `forth.s` run.
- `SEE FIB` prints a readable decompilation of the compiled FIB.
- `repl.sh` launches an interactive session with all core words
  already defined.

## Out-of-scope risks explicitly accepted

- Much larger instruction budgets (4× or more for examples that
  exercise compile-time IMMEDIATE words now defined in Forth).
- A small number of additional primitives if strictly needed
  (currently: just `[']`; later: `SP@` for `DEPTH`/`.S`).
