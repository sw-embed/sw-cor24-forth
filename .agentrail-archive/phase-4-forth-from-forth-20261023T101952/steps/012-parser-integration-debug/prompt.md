Resume the parser-integration debug from step 009.

Step 009 left xcomp.fth with all the building blocks proven in
isolation:
  - NUM-C, MAKE-CFA-LABEL MAKE-ENTRY-LABEL (dynamic labels work)
  - XC-COPY-COUNTED (permanent name storage works)
  - XC-COMPILE-NAME-BYTES (byte emission works)
  - XC-FIND XC-EMIT-TOKEN (symbol-table dispatch works)
  - XC-READ-TOKEN XC-IS-SEMI? (parser primitives work)

The integration via XC-COMPILE-TEST hits a context-dependent
failure: when called from a colon def via `XC-COMPILE-TEST : FOO
SP@ @ ;`, the inner XC-READ-TOKEN inside XC-COMPILE-ENTRY returns
0 instead of the counted-string addr. The pattern
`BEGIN ... 0= IF DROP 0 ELSE -1 THEN UNTIL` works in smaller
isolation tests but not in this nested invocation.

Hypothesis: interaction between WORD's transient buffer reuse
and the compile-time IF/ELSE patching when XC-COMPILE-ENTRY's
def is itself being parsed by a chain of nested INTERPRET calls.
Or possibly a stack-imbalance somewhere I haven't traced yet.

Diagnostics to try:
1. Add per-line debug emits inside the BEGIN/UNTIL body of
   XC-READ-TOKEN to confirm WORD is returning the right thing.
2. Explicitly DEPTH-check before/after XC-READ-TOKEN to confirm
   stack balance.
3. Try replacing the BEGIN/UNTIL with a simpler `WORD` call and
   see if the failure is in the loop or in the IF/ELSE.
4. Test in isolation: `XC-COMPILE-ENTRY` invoked at top-level
   (not inside another `:` def) with a synthetic input.

Once XC-COMPILE-ENTRY emits one def correctly, build COMPILE-CORE
that loops reading top-level `:` tokens and dispatches each to
XC-COMPILE-ENTRY. Then re-emit runtime.fth via the parser
(replacing the hardcoded EMIT-DUP/DROP/etc helpers in
COMPILE-RUNTIME) and verify byte-for-byte match against the
hardcoded output.

Out of scope (defer to next step):
- IMMEDIATE control flow (IF/THEN/BEGIN/UNTIL emission with
  offset patching). Requires xc-here tracking + def-body buffer.
- `[']` IMMEDIATE word.
- IMMEDIATE modifier after `;`.

Acceptance: build-kernel.sh produces runtime-dict.s identical to
or functionally-equivalent to the current hardcoded output, but
generated from an actual parser run over runtime.fth source.
All 68 tf24a tests still pass.
