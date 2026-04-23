# forth-from-forth compiler

A Forth-to-COR24-assembler cross-compiler, written in Forth.

## Usage

```
scripts/build-kernel.sh      # regenerate forth-from-forth/kernel.s
```

The script cats `compiler/xcomp.fth`, `core/prims.fth`, the five
`core/*.fth` tiers, and a trailing `COMPILE-KERNEL` invocation
into `cor24-run --run forth-on-forthish/kernel.s --terminal`. The
phase-3 Forth REPL reads xcomp.fth (which defines the alternate
compilation vocabulary), then walks the prims + core sources
through that vocabulary, EMITting COR24 assembler text to UART.
A `sed` filter strips everything outside the
`!!BEGIN-KERNEL!!` / `!!END-KERNEL!!` markers and redirects to
`forth-from-forth/kernel.s`.

## Why Forth?

Because the project is called "forth-from-forth". The kernel is
Forth running on Forth-emitted asm; the compiler that produced
that asm is itself Forth. No Python, no C, no Rust at any step.

See `../docs/design.md` for the full rationale and architecture.

## Files

- `xcomp.fth` — the cross-compiler proper. Defines `PRIM:`,
  `COLON:` / `;COLON`, `VARIABLE:`, `CONSTANT:`, and IMMEDIATE
  control-flow emitters (`IF:`, `THEN:`, `BEGIN:`, `AGAIN:`,
  `UNTIL:`, `WHILE:`, `REPEAT:`). Each emits COR24 assembler
  text to UART via `EMIT` / `TYPE`.
- `../core/prims.fth` — per-primitive declarations consumed by
  xcomp's `PRIM:` to emit the asm primitive section.
- `../scripts/build-kernel.sh` — the one-line shell wrapper.

Step 002 ships xcomp.fth as a stub. Step 003 starts filling it
in; step 005 completes it for all tiers.
