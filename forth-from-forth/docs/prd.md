# Product Requirements — forth-from-forth

## Purpose

Close the bootstrap loop: write a Forth-to-COR24-assembler
cross-compiler **in Forth** and let it emit the next kernel's `.s`
source. After this phase, `forth-from-forth/kernel.s` is a build
artifact — not a hand-edited file — and the asm bootstrap
interpreter that phase 3 kept alive (`do_interpret`, `do_word`,
`do_find`, `do_number`, the asm `do_quit` loop) simply doesn't
get emitted.

This is approach 4 in `../../docs/future.md`.

## Audience

- Readers who want to see Forth bootstrap itself from an earlier
  generation of Forth.
- Contributors eventually targeting RCA1802, IBM 1130, IBM 360 —
  the cross-compiler pattern carries over with only the PRIM:
  declarations and target descriptor changing.

## Goals

1. **Cross-compiler is pure Forth.** No Python, no C, no Rust.
   `compiler/xcomp.fth` runs on the phase-3 `forth-on-forthish`
   REPL and EMITs COR24 assembler text to UART.
2. **Kernel.s is regenerable.** `scripts/build-kernel.sh` rebuilds
   `forth-from-forth/kernel.s` from source at any time; the file
   itself is committed (so fresh clones don't need to build) but
   marked "Generated — do not edit" in its header.
3. **Core Forth source is byte-identical to phase 3.** The five
   `core/*.fth` files in forth-from-forth are verbatim copies of
   their phase-3 counterparts. This proves the portable-surface
   claim: when we target RCA1802, none of the Forth code changes.
4. **No asm bootstrap interpreter in the emitted kernel.**
   `do_interpret`, `do_word`, `do_find`, `do_number`,
   `do_quit_ok`, `do_quit_restart`, `tick_word_cfa`, `test_thread`,
   and the `_start` hash-populate loop are not emitted.
5. **`reg-rs/tf24a_fff_fib` passes with fib output identical to
   phase 3.** Same 1 1 2 3 5 8 13 21 34 55 89 sequence.

## Non-goals

- **Rewriting the core Forth tiers.** If something needs changing,
  do it in forth-on-forthish's copies first, then re-sync here.
- **Multi-target support.** The Target descriptor in design.md is
  reserved for future phases. Phase 4 hardcodes COR24.
- **Pre-compiling `examples/*.fth` into the kernel.** Examples
  stay UART-loaded post-boot so changing an example doesn't
  require rebuilding the kernel.
- **Optimizing FIND.** Ship with linear-walk Forth FIND (no hash
  table). If benchmarking later demands acceleration, add it as
  a follow-up subset per the escalation order in design.md.

## Success criteria

- Running `scripts/build-kernel.sh` from a clean checkout
  regenerates `forth-from-forth/kernel.s` byte-identically.
- `reg-rs/tf24a_fff_fib` passes.
- Emitted kernel.s line count: target ≤ 2000 (down from
  phase-3's 2659 with the bootstrap still alive).
- `forth-from-forth/compiler/xcomp.fth` is hand-written Forth;
  total size ≤ ~500 lines.
- `forth-from-forth/core/*.fth` diffs zero against
  `forth-on-forthish/core/*.fth`.
