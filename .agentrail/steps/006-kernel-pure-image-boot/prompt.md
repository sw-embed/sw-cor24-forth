Switch `forth-from-forth/kernel.s` to boot ENTIRELY from the
pre-compiled image. Strip the UART bootstrap for core files —
only `examples/*.fth` lines are read from UART post-boot.

Kernel changes:
- `_start`: set LATEST/HERE from image, install QUIT-VECTOR from
  image metadata (the image knows Forth QUIT's CFA), jump
  directly to Forth QUIT via the vector. No asm `do_quit`
  invocation for startup.
- `scripts/demo.sh`: feed only `examples/14-fib.fth` to UART
  (not the core files). The image has them already.
- Re-baseline `reg-rs/tf24a_fff_fib` — instruction count should
  drop dramatically (no asm-INTERPRET loop to drive ~450 lines
  of Forth source at boot).

Acceptance:
- Fib output identical to phase 3.
- Boot instructions at least 10× lower (measure and record).
- Asm `do_interpret`, `do_word`, `do_find`, `do_number`,
  `tick_word_cfa` still present but UNREFERENCED — verify with
  symbol usage count. Step 7 deletes them.
