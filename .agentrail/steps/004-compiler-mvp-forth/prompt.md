Build the minimum viable pure-Forth cross-compiler that can
process `forth-from-forth/core/runtime.fth` end-to-end and emit
the COR24 assembler text for the **dict entries** those 10 colon
defs produce. Output is text on UART, captured by shell
redirection.

Scope: **runtime.fth only.** That's 10 colon defs:

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

Plus the Forth `:` / `;` definitions on lines 12-13 that use the
old asm `:` / `;` to bootstrap the Forth ones. For this step,
just DROP those two lines — the cross-compiler has its own
COLON: / ;COLON; it doesn't need to process `: : ... ;` at all.
(The emitted kernel won't have asm `:` / `;` either — the
cross-compiler will emit colon-def dict entries directly from
COLON: declarations that we'll hand-write in prims.fth in step 005.)

**Out of scope for step 003:**

- Asm primitives: no PRIM: declarations yet. runtime.fth's colon
  bodies reference primitives (`SP@`, `@`, `+`, `SP!`, `>R`, `R>`,
  `RP@`, `NAND`) by name; the compiler resolves them to the
  **existing phase-3 asm labels** (`do_sp_fetch`, `do_fetch`,
  `do_plus`, `do_sp_store`, `do_to_r`, `do_r_from`, `do_rp_fetch`,
  `do_nand`). No kernel.s regeneration in this step.
- IMMEDIATE control flow (IF / BEGIN / UNTIL / etc.): runtime.fth
  doesn't use any. Step 005 adds those.
- Numeric literal compilation: runtime.fth has exactly one
  literal (the `1` in `: NEGATE INVERT 1 + ;`). Implement just
  enough to emit `LIT` + the word for that single case.

**Deliverables:**

1. `forth-from-forth/compiler/xcomp.fth`: ~150-250 lines of Forth
   defining:
     - a target-side symbol table (target-word-name → emitted
       asm label, plus known-primitive-CFA lookup for the ~8
       primitives runtime.fth needs).
     - `COLON:` and `;COLON` — IMMEDIATE words that, when
       executed in the phase-3 REPL, EMIT the dict-entry header
       (link, flags_len, name bytes) plus the far-DOCOL CFA
       prelude, then compile subsequent tokens as `.word
       <primitive-label>` lines.
     - `COMPILE-RUNTIME` ( -- ) : top-level word that emits a
       `!!BEGIN-KERNEL!!` marker, then walks a hand-coded
       sequence of COLON: forms corresponding to runtime.fth's
       10 defs, then emits `!!END-KERNEL!!`.

2. `forth-from-forth/scripts/build-kernel.sh`: remove the `exit 0`
   stub. Wire up the real pipeline that pipes xcomp.fth +
   compile-cmd through phase-3 Forth and captures the text.
   For step 003 the input is `xcomp.fth` + the literal string
   `COMPILE-RUNTIME`. The output goes to a scratch file
   `forth-from-forth/compiler/out/runtime-dict.s` — NOT
   kernel.s. We're not integrating into the kernel yet.

3. A test/verification step: `diff` between the hand-run
   runtime-dict.s and the equivalent dict-entry bytes the
   phase-3 kernel produces when it INTERPRETs runtime.fth at
   runtime. They should match byte-for-byte (or, if CFA label
   names differ, functionally-equivalent). Document any
   divergence in the commit message.

**What this step is NOT:**

- Not regenerating forth-from-forth/kernel.s (step 004 does the
  first kernel integration).
- Not touching forth-from-forth/kernel.s in any way.
- Not doing asm primitives — ~8 primitive CFA labels are
  hard-coded as constants in xcomp.fth for this step; the
  PRIM: mechanism lands in step 005.
- Not writing any tests in a host language. If we want a test,
  it's a shell check: `scripts/build-kernel.sh && diff
  compiler/out/runtime-dict.s expected.s`.

**Design references:**

- `forth-from-forth/docs/design.md` — full architecture.
- `forth-from-forth/docs/architecture.md` — directory layout +
  bootstrap flow.
- `forth-from-forth/docs/plan.md` — step-sequence narrative.

Commit as a single commit, `feat(forth-from-forth): step 003 —
compiler MVP emitting runtime.fth dict entries`. Include the
generated `runtime-dict.s` in the commit so reviewers can see
what the compiler produces.
