Wire the compiled image into `forth-from-forth/kernel.s` so the
kernel boots with runtime.fth pre-loaded, bypassing asm
`do_interpret` for those 10 colon defs.

Strategy:
- Emit the compiled blob at a known address inside `kernel.s`
  via `.incbin "compiler/out/runtime.bin"` (or equivalent —
  check what the cor24 assembler supports; fall back to
  generating `.byte` directives from the compiler if `.incbin`
  isn't available).
- Modify `_start` to:
  - Set `LATEST` to the blob's last-entry address (provided by
    the compiler as a symbol or in the blob metadata).
  - Set `HERE` to the blob's end-of-used address.
  - Proceed to the rest of boot (hash table init — but hash
    table is pre-computed in the blob, skip re-init if so).
  - Jump to asm `do_quit` as before. Since Forth runtime.fth is
    already loaded, the REPL will start with those defs available.
- Remove runtime.fth from the UART input in `scripts/demo.sh`
  (since it's now in the image, no need to re-load).
  Keep minimal/lowlevel/midlevel/highlevel on UART for now —
  they still load via asm bootstrap.

Verify:
- `scripts/demo.sh examples/14-fib.fth` produces identical fib
  output to phase 3.
- `reg-rs/tf24a_fff_fib` still matches baseline (or rebase it
  if ok-count now differs).
- Boot is measurably faster (fewer instructions to reach first
  " ok") — record the delta in `docs/kernel-sizes.md`.

This is the first step where kernel.s diverges structurally
from phase 3. Keep the diff tight; document the exact insertion
points in commit message.
