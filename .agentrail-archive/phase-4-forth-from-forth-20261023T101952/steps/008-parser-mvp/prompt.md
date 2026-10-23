Build a minimal Forth-hosted parser in xcomp.fth that reads
target-Forth source tokens via WORD and emits asm, replacing
the hardcoded per-def EMIT-* helpers for simple cases.

MVP scope (step 008):

1. **Symbol table** in xcomp.fth — a linked list of entries
   recording (name-counted-addr, label-counted-addr) for each
   target-side word (asm primitives + already-emitted Forth
   defs). New helper XC-REGISTER appends entries; XC-FIND
   searches by name.

2. **XC-EMIT-TOKEN** ( c-addr u -- ) dispatches a single token:
   - Try XC-FIND. If found, emit `.word <label>`.
   - Else try to parse as a decimal number (use phase-3's NUMBER).
     On success, emit `.word do_lit\n.word <n>`.
   - Else: undefined word. Emit a diagnostic and halt (via BYE
     in the phase-3 REPL — or just print and continue).

3. **XC-COMPILE-BODY** ( -- ) loops reading WORDs until `;`:
   - Empty WORD (EOL): continue.
   - `;`: emit `.word do_exit`, return.
   - Other: XC-EMIT-TOKEN.

4. **XC-COMPILE-ENTRY** ( -- ) reads next name, emits the header
   (link, flags_len, name bytes) + far-DOCOL prelude, then calls
   XC-COMPILE-BODY. Registers the new entry in the symbol table.

5. **COMPILE-CORE** ( -- ) top-level loop:
   - Emit BEGIN marker.
   - Loop reading WORD until special end-marker token (e.g. `STOP`).
   - `:` → XC-COMPILE-ENTRY.
   - Other → error.
   - Emit END marker.

6. **Initial symbol-table population** — helper to register all
   ~20 asm primitives by calling XC-REGISTER with name/label
   pairs (reusing the STR: constants already in xcomp.fth).

Out of scope for this step (defer to 009):
   - IF / THEN / ELSE / BEGIN / UNTIL / WHILE / REPEAT —
     these require offset computation and back-patching. Use
     a def-body buffer + xc-here tracking to enable this.
   - `[']` (IMMEDIATE tick) — reads next token and emits
     LIT+cfa. Straightforward once parse loop exists.
   - `IMMEDIATE` modifier after `;` — requires either lookahead
     or body buffering to delay flags_len emission.

Coverage this step: runtime.fth's FIRST 11 defs (DUP DROP OVER
SWAP R@ INVERT AND OR XOR NEGATE MINUS). The last 2 (`:` and `;`)
depend on `[']` and IMMEDIATE — keep their EMIT-* hardcoded
helpers invoked by COMPILE-RUNTIME until step 009 generalizes.

Verification:
- build-kernel.sh produces runtime-dict.s with correct entries
  for the 11 parsed defs + the 2 still-hardcoded ones.
- test-kernel.sh → tf24a_fff_selftest still passes (all 11
  parsed + the 2 hardcoded behave identically).

Deliverable: xcomp.fth grows with ~200-300 lines of parser
infrastructure. Per-def EMIT-DUP, EMIT-DROP, ..., EMIT-MINUS
are removed (replaced by parser + runtime.fth source driving
it). EMIT-COLON, EMIT-SEMI stay.
