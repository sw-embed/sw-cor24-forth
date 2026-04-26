Add RECURSE and ROLL to the layered kernels — productive GH #3
progress while parser-integration-debug is parked.

RECURSE is IMMEDIATE; at compile time it compiles a reference
to the CFA of the in-progress (currently-compiling) colon def.
Standard impl is one line: LATEST @ + namelen + 4 = CFA addr,
then `,` it.

  : RECURSE
    LATEST @ DUP 3 + C@ 63 AND + 4 + , ; IMMEDIATE

ROLL uses RECURSE for its recursive standard def:

  : ROLL ( xu xu-1 ... x0 u -- xu-1 ... x0 xu )
    ?DUP IF
      SWAP >R
      1 - RECURSE
      R> SWAP
    THEN ;

Note: the standard ROLL def is `?DUP IF SWAP >R 1 - RECURSE R>
SWAP THEN`. The trailing ; is the def-end. No explicit DROP for
the 0 case because ?DUP already drops in that path.

Wait actually for u=0, ?DUP leaves (xu...x0 0). IF consumes the 0,
skips body. Stack: (xu...x0). Done. ✓
For u=N, ?DUP leaves (xu...x0 N N). IF consumes top N → true.
Stack: (xu...x0 N). Body runs, recursion eats one off N each
call, base case unwinds. ✓

Locations: forth-in-forth/core/lowlevel.fth, forth-on-forthish/
core/lowlevel.fth, forth-from-forth/core/lowlevel.fth. Place
right after the existing GH #3 block (?DUP MIN MAX <= >= <> >).

Testing:
- `1 2 3 0 ROLL` → stack (1 2 3); top is 3.
- `1 2 3 1 ROLL` → stack (1 3 2); 1 ROLL = SWAP.
- `1 2 3 2 ROLL` → stack (2 3 1); 2 ROLL = ROT.
- `1 2 3 4 5 4 ROLL` → stack (2 3 4 5 1).

For RECURSE: define a recursive countdown to verify:
  : COUNT-DOWN DUP IF DUP . 1 - RECURSE THEN DROP ;
  3 COUNT-DOWN  →  3 2 1

Add reg-rs test for the new words.

Caveat to verify: phase-3 forth-on-forthish / forth-from-forth's
Forth `:` sets HIDDEN bit on the in-progress entry. RECURSE uses
LATEST @ which is independent of HIDDEN — should still find the
correct entry's CFA. Verify in each kernel.

Update GH #3 with progress; the issue stays open for the
remaining asm-needing words: +LOOP, J, LEAVE, DOES>.
