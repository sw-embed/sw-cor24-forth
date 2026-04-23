Extend COMPILE-RUNTIME in forth-from-forth/compiler/xcomp.fth so
it emits the real COR24 asm text for core/runtime.fth's 10 colon
defs. Step 004a proved the pipeline (markers + shell capture);
this step puts actual dict-entry bytes between the markers.

Scope: hardcoded emission for each of the 10 defs. No parsing of
runtime.fth. Step 007 (compiler-full-core) builds the actual
parser; this step just proves we can produce correct asm.

The 10 colon defs (from forth-from-forth/core/runtime.fth):

  : DUP   SP@ @ ;
  : DROP  SP@ 3 + SP! ;
  : OVER  SP@ 3 + @ ;
  : SWAP  >R DUP R> SP@ 6 + ! ;
  : R@    RP@ 3 + @ ;
  : INVERT  DUP NAND ;
  : AND     NAND INVERT ;
  : OR      INVERT SWAP INVERT NAND ;
  : XOR     OVER OVER NAND DUP >R NAND SWAP R> NAND NAND ;
  : NEGATE  INVERT 1 + ;

For each def, emit asm text in this form:

  fff_entry_DUP:
      .word <prev-entry-label-or-0>
      .byte 3
      .byte 68, 85, 80
  fff_cfa_DUP:
      .byte 125
      .byte 41
      .word do_docol_far
      .byte 38
      .word do_sp_fetch       ; SP@
      .word do_fetch          ; @
      .word do_exit           ; ;

(Number literal in NEGATE compiles as `.word do_lit` + `.word 1`.)

Deliverables:

1. Extend xcomp.fth (~100-200 lines more) with:
   - N. ( n -- ) : print a number without `.`'s trailing space.
   - EMIT-WORD-LITERAL ( n -- ) : emit ".word n<newline>".
   - EMIT-BYTE-LITERAL ( n -- ) : emit ".byte n<newline>".
   - EMIT-WORD-LABEL ( c-addr -- ) : emit ".word <counted-label><newline>".
   - EMIT-LABEL-DEF ( c-addr -- ) : emit "<counted-label>:<newline>".
   - Counted-string constants for: the asm labels we emit
     ("fff_entry_DUP", "fff_cfa_DUP", etc. — 20 label strings),
     the primitive CFA labels we reference ("do_sp_fetch",
     "do_fetch", "do_plus", "do_sp_store", "do_to_r", "do_r_from",
     "do_rp_fetch", "do_nand", "do_lit", "do_exit",
     "do_docol_far"), the name bytes for each of the 10 def
     names ("DUP", "DROP", ...).
   - Per-def emit helpers: EMIT-DUP, EMIT-DROP, EMIT-OVER, etc. —
     each ~5-10 lines of Forth that emits the def's entry header
     and threaded body.
   - COMPILE-RUNTIME calls all 10 emit-* helpers between the
     BEGIN/END markers.

2. scripts/build-kernel.sh already works; no changes needed.

3. Verification:
   - Run build-kernel.sh. Inspect compiler/out/runtime-dict.s.
     Expect ~100 lines of asm (10 defs × ~10 lines each).
   - Check a specific def by eye — DUP should produce exactly
     the dict entry bytes that phase-3 produces at runtime when
     it compiles `: DUP SP@ @ ;` (modulo the link address,
     which is fff_entry-prefixed vs. the asm entry chain).
   - Optional: try `cor24-run --assemble` on a wrapper that
     concatenates runtime-dict.s with a minimal scaffold
     defining `do_docol_far`, `do_exit`, etc. Confirms the
     emitted syntax assembles.

Out of scope:
- Parsing runtime.fth (the .fth file isn't read by this step).
- Integrating the emitted dict into the actual kernel.s (step 006).
- Handling IMMEDIATE control flow, numeric-literal auto-compile,
  etc. (step 007).
