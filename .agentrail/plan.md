# Phase 4: forth-from-forth — cross-compiled kernel

Build the `forth-from-forth/` track that eliminates the asm
bootstrap interpreter via a pre-compiled dictionary image baked
into the kernel at build time.

## Starting state (end of phase 3)

- `forth-on-forthish/kernel.s` is 2659 asm lines. It keeps alive
  ~860 lines of bootstrap-only asm:
  - `do_interpret` (~195 lines) — the asm REPL that loads
    `core/*.fth` from UART at boot.
  - `do_word` (~140), `do_find` (~250), `do_number` (~190) —
    primitive bodies that only `do_interpret` and `tick_word_cfa`
    reference by address.
  - `do_quit` / `do_quit_ok` / `do_quit_restart` (~80) — the asm
    outer loop that drives bootstrap.
- The runtime REPL (post-boot) is already Forth: Forth `INTERPRET`
  and `QUIT` in `core/highlevel.fth` installed in `QUIT-VECTOR`
  and invoked at end of highlevel.fth.

## Goal

- Pre-compile `core/*.fth` + `examples/*.fth` into a binary image
  at build time (host tool, not the target kernel).
- Kernel boots by pointing `LATEST` at the image's dictionary and
  jumping straight to Forth `QUIT`'s CFA. No UART-driven loading
  at boot; no asm bootstrap interpreter.
- Delete `do_interpret`, `do_word`, `do_find`, `do_number` bodies.
  Kernel should land ≤ 1000 asm lines — below the ≤ 800 aspiration
  from phase 3 if the primitive set can be further trimmed.

## Architecture sketch

1. Host tool (Python or Forth) reads `core/*.fth`, walks the Forth
   interpreter rules, and emits a binary blob:
   - Dictionary entries (link chain + flags_len + name bytes + CFA)
   - Variable storage (HERE, LATEST, STATE, BASE, ...)
   - Pre-computed hash table (same 256-bucket layout as phase 3)
2. Blob is included into `kernel.s` via `.incbin` or similar and
   placed at a known address.
3. Kernel boot sets `LATEST = &blob_dict_latest`, `HERE =
   &blob_free_ptr`, installs `QUIT-VECTOR`, and jumps to Forth QUIT.

## Open questions for design step

- Tool language: Python 3 (easy, fast iteration) vs. a metacircular
  Forth cross-compiler (closer to spirit). Pick one.
- CFA format: near-DOCOL (bra + pad, 3 bytes) vs. far-DOCOL (push
  r0 + la + jmp, 6 bytes). Phase 3 uses far-DOCOL for runtime
  colon-def creation; the pre-compiled image could use either.
- Whether `examples/*.fth` (like 14-fib.fth) get pre-compiled too
  or are still read from UART post-boot via Forth INTERPRET.
- Portability hook: the same image-based boot should work on
  RCA1802 / IBM 1130 / IBM 360 once their asm primitives are
  written. Design the image format to be endianness/word-size
  parameterized.

## Success criteria

- `forth-from-forth/kernel.s` is ≤ 1000 asm lines.
- `reg-rs/tf24a_fff_fib` passes with the same fib output.
- The Forth INTERPRET/QUIT source in `core/*.fth` is UNCHANGED
  from phase 3 (proves portability of the Forth layer).
