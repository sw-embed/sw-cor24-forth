\ lowlevel.fth: stack, arithmetic, and division helpers built from primitives.
\ (0= and = moved up to minimal.fth because the comment parsers depend on them.)

\ ---- Single-cell stack helpers ----
: NIP   SWAP DROP ;
: TUCK  SWAP OVER ;
: ROT   >R SWAP R> SWAP ;
: -ROT  ROT ROT ;

\ ---- Double-cell stack helpers ----
: 2DUP  OVER OVER ;
: 2DROP DROP DROP ;
: 2SWAP >R >R SWAP R> R> SWAP ;
: 2OVER >R >R OVER OVER R> SWAP R> SWAP ;

\ ---- 0< : negative test via 24-bit sign bit (0x800000 = 8388608) ----
: 0<  8388608 AND 0= 0= ;

\ ---- Arithmetic shorthand ----
: 1+      1 + ;
: 1-      1 - ;
\ NEGATE moved to runtime.fth (needs INVERT; subset 16 moved `-` to Forth).
: ABS     DUP 0< IF NEGATE THEN ;

\ ---- Subset 16: multiply and divide-mod as Forth loops ----
\ `*` by repeated addition: a acc loop counter b down-to-0.
\   a b -- a*b. O(b) threaded cycles — slow for large b but saves
\   17 asm lines and makes the ISA self-hosting path clear.
: *  ( a b -- a*b )
  0 SWAP
  BEGIN DUP WHILE
    1 - >R OVER + R>
  REPEAT
  DROP NIP
;

\ `/MOD` by repeated subtraction. Keeps divisor on RS as a loop
\ invariant. Behaviour matches the old asm: unsigned, loops
\ forever on divisor=0.
: /MOD  ( dividend divisor -- rem quot )
  >R 0 SWAP
  BEGIN DUP R@ < INVERT WHILE
    R@ - SWAP 1 + SWAP
  REPEAT
  R> DROP SWAP
;

\ ---- Division helpers on top of /MOD ----
: /     /MOD SWAP DROP ;
: MOD   /MOD DROP ;

\ ---- Subset 17: WORD ( -- c-addr ) ----
\ Build a counted string at WORD-BUFFER. Skip leading whitespace;
\ treat LF (10) and CR (13) as end-of-line → return empty and
\ preserve EOL-FLAG semantics from minimal.fth's `\` comment.
\ Read until whitespace; if terminator was LF/CR, set EOL-FLAG so
\ the NEXT WORD call also returns empty.
\
\ Internal asm threads in INTERPRET / `[']` still call the asm
\ do_word directly (via `.word do_word`); this Forth WORD shadows
\ the old dict entry for user-level lookups only.
: WORD  ( -- c-addr )
  EOL-FLAG C@ IF
    0 EOL-FLAG C!
    WORD-BUFFER 0 OVER C! EXIT
  THEN
  BEGIN
    KEY
    DUP 10 = OVER 13 = OR IF
      DROP WORD-BUFFER 0 OVER C! EXIT
    THEN
    DUP 33 <
  WHILE DROP REPEAT
  WORD-BUFFER 1 + >R
  R@ C!
  R> 1 + >R
  BEGIN
    KEY
    DUP 33 < INVERT
  WHILE
    R@ C!
    R> 1 + >R
  REPEAT
  DUP 10 = OVER 13 = OR IF 1 EOL-FLAG C! THEN
  DROP
  R> WORD-BUFFER 1 + -
  WORD-BUFFER C!
  WORD-BUFFER
;

\ ---- CONSTANT / VARIABLE: CREATE a headed entry, then stamp a
\ colon-def CFA at HERE with ,DOCOL and compile a LIT-based body.
\ n CONSTANT NAME   → NAME pushes n
\ VARIABLE NAME     → NAME pushes the address of a cell initialised to 0
\ VARIABLE body layout after ,DOCOL (6 bytes): LIT , <addr> , EXIT , <cell>
\ so the address pushed is HERE+9 at definition time (LIT=3, addr=3, EXIT=3).
: CONSTANT  CREATE ,DOCOL ['] LIT , , ['] EXIT , ;
: VARIABLE  CREATE ,DOCOL HERE @ 9 + ['] LIT , , ['] EXIT , 0 , ;

\ ---- DO / LOOP / ?DO — IMMEDIATE compilers for the (DO)/(LOOP)/(?DO)
\ primitives. Compile-stack convention during a DO-loop definition:
\   ( body-addr  patch-addr-or-0 )   with patch-addr != 0 only for ?DO.
\ LOOP compiles the backward branch, then patches the forward branch
\ reserved by ?DO if present. DO reserves no forward branch, so it
\ leaves a 0 marker that LOOP's IF/ELSE handles.
: DO    ['] (DO) , HERE @ 0 ; IMMEDIATE
: ?DO   ['] (?DO) , HERE @ 0 , HERE @ SWAP ; IMMEDIATE
: LOOP
  ['] (LOOP) ,
  OVER HERE @ - ,                 \ backward offset to body
  DUP IF
    HERE @ OVER - SWAP !          \ patch ?DO's forward branch
  ELSE
    DROP
  THEN
  DROP
; IMMEDIATE
