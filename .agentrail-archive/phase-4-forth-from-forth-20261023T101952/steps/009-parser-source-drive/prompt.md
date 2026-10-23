Wire step 008's parser infrastructure into source-driven
compilation. Replace (or augment) the hardcoded EMIT-<NAME>
helpers with XC-COMPILE-ENTRY / XC-COMPILE-BODY that read .fth
source tokens via WORD and drive XC-EMIT-TOKEN.

Scope for this step:

1. Dynamic label construction. Each def gets labels based on
   a monotonic counter:
     fff_e_N  (dict entry label)
     fff_c_N  (CFA label)
   where N is an integer (1, 2, 3, ...). Labels avoid the
   "non-alphanumeric name" problem (: ; - R@ etc.) by not
   embedding the source name.

2. NUM-C, ( n -- ) : write decimal digits of n as bytes at
   HERE, advancing HERE. Mirrors phase-3 `.` but C,'s instead
   of EMITs. Used by label constructor.

3. MAKE-CFA-LABEL ( counter -- counted-addr ) : build a counted
   string "fff_c_<N>" at HERE, return its address. (Same for
   MAKE-ENTRY-LABEL.)

4. XC-COMPILE-BODY ( -- ) : loop reading WORD until `;`, calling
   XC-EMIT-TOKEN for each non-terminator token. Emit `.word do_exit`
   at `;`.

5. XC-COMPILE-ENTRY ( -- ) :
   - Read name via WORD.
   - Increment xc-counter.
   - Emit dict header: fff_e_<N> label, link (.word fff_e_<N-1>
     or 0), flags_len byte, name bytes.
   - Emit fff_c_<N> label + far-DOCOL prelude.
   - Build name-counted-addr (reuse WORD's buffer? or copy to
     permanent storage).
   - Build cfa-label counted-addr via MAKE-CFA-LABEL.
   - XC-REGISTER name-counted-addr cfa-label-counted-addr so
     future defs can reference this one.
   - Call XC-COMPILE-BODY.

6. Test driver: feed a mini-runtime with one or two simple defs
   (e.g., `: DUP SP@ @ ;`) through the parser, compare output
   to the hardcoded EMIT-DUP emission.

Out of scope:
- IF/THEN/BEGIN/UNTIL/AGAIN/WHILE/REPEAT (control flow).
- `[']` IMMEDIATE.
- IMMEDIATE modifier after `;`.
- All of minimal.fth, lowlevel.fth, etc. (later steps).

Verification:
- New `scripts/parse-kernel.sh` or an extension to build-kernel.sh
  runs the parser against a small synthetic .fth snippet and
  prints the emitted asm. Spot-check one def by eye.
- All 67 existing tests still pass (the hardcoded EMIT-* paths
  are still in place and used for the real runtime-dict.s).
