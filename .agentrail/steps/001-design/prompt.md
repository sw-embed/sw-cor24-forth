Research and design the phase-4 cross-compiler. Produce
`forth-from-forth/docs/design.md` (new file) covering:

1. Tool choice: Python 3 vs. metacircular Forth cross-compiler.
   Recommend one with rationale. Python likely wins for iteration
   speed; Forth wins for self-host philosophy. Decision is binding
   for later steps.

2. Image format spec:
   - Byte layout of a dict entry (link, flags_len, name, CFA).
     Match phase 3 kernel's layout so the Forth interpreter
     rules work unchanged.
   - CFA format: far-DOCOL (6 bytes) matching phase 3 runtime
     colon-def creation, OR near-DOCOL if we can lay out the
     image to stay within 127B of `do_docol`. Pick one.
   - Variable storage layout (HERE, LATEST, STATE, BASE,
     var_quit_vector, var_sp_base, word_buffer, etc.).
   - Hash table: 256 × 3-byte buckets, pre-computed.

3. Boot handoff: exactly what `_start` does in the new kernel.
   - Initialize `r1` (RSP), `sp` (DSP), `var_sp_base`.
   - Set `LATEST` and `HERE` from image metadata.
   - Install `QUIT-VECTOR` with the Forth QUIT CFA (image knows this).
   - Jump to Forth QUIT's CFA to enter the REPL.
   - No UART reading on boot.

4. Portability parameters: what the image format must abstract
   so the same compiler can emit RCA1802 / IBM 1130 / IBM 360
   images later (endianness, word size, address space layout).
   Don't implement — just document the knobs.

5. `examples/*.fth` handling: pre-compiled into the image, or
   still UART-loaded post-boot? Affects test harness design.

6. Open questions to resolve in subsequent steps.

Do NOT write any code or create `forth-from-forth/` yet. This
step is pure documentation; the scaffolding comes in step 2.

Commit the design doc. Reference it in a root-level index if
there is one, otherwise just the new file.
