Complete runtime.fth emission. Step 005 emitted 10 defs (DUP
through NEGATE) but missed the last 3:

  : -       NEGATE + ;
  : :       CREATE ,DOCOL LATEST @ 3 + DUP C@ 64 OR SWAP C! ] ;
  : ;       ['] EXIT , LATEST @ 3 + DUP C@ 191 AND SWAP C! 0 STATE ! ; IMMEDIATE

Scope for this step:

1. Add EMIT-MINUS, EMIT-COLON, EMIT-SEMI to xcomp.fth.

2. New primitive-label counted-string constants needed:
   - do_create          (asm primitive, phase-3 kernel.s:1175)
   - do_comma_docol     (,DOCOL, phase-3 kernel.s:1531)
   - do_latest          (LATEST, find its phase-3 body)
   - do_rbrac           (], phase-3 primitive for STATE=1)
   - do_state           (STATE, variable pushing &var_state_val)
   - do_cfetch          (C@)
   - do_cstore          (C!)

   Check forth-from-forth/kernel.s (copy of phase-3) to confirm
   each label exists; add if found.

3. Support IMMEDIATE flag on emitted entries. The semicolon def
   needs flags_len = 0x81 (128 + 1) instead of just 1. Simplest:
   add an EMIT-IMMEDIATE-BYTE-LITERAL that emits ".byte 129"
   for length-1-IMMEDIATE. Generalize later.

4. Handle `[']` inside `;`'s body. `[']` is IMMEDIATE — at
   cross-compile time it reads the next token and compiles
   `LIT <cfa>`. In our hardcoded EMIT-SEMI helper, we just inline
   the equivalent asm: emit `.word do_lit`, `.word do_exit`.

5. Extend selftest-scaffold.s to add a `-` test. `:` and `;`
   can't be exercised without a more complete kernel (they
   depend on LATEST/HERE/STATE machinery and the COMPILE path);
   skip them in the self-test but VERIFY via `cor24-run
   --assemble` that the emitted asm still assembles cleanly.

6. Re-baseline tf24a_fff_selftest to include the `-` test line.

Expected additions to UART output:
     C    (minus: '5' 5 - = '0' = 48)  OR similar simple test.

Actually simpler: push 10 (decimal 10), 3, MINUS → 7. Then add
48 ('0' offset) → 55 ('7'). EMIT → "7". That's a new line in
the selftest: "7\n" before or after DONE.

Deliverables:
- xcomp.fth extended (~150 new lines for 3 more defs + 7 new
  label constants + IMMEDIATE byte emitter).
- runtime-dict.s grows to ~230 lines.
- selftest-scaffold.s adds a MINUS test.
- tf24a_fff_selftest rebased with new baseline.
- All tests pass.

Out of scope:
- minimal.fth (step 008 — first IMMEDIATE-control-flow tier).
- lowlevel.fth, midlevel.fth, highlevel.fth (subsequent steps).
- Integrating into a full working kernel (later step).
