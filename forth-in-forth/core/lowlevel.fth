\ lowlevel.fth: stack, arithmetic, and division helpers built from primitives.
\ (0= and = moved up to minimal.fth because the comment parsers depend on them.)

\ ---- Single-cell stack helpers ----
: NIP   SWAP DROP ;
: TUCK  SWAP OVER ;
: ROT   >R SWAP R> SWAP ;
: -ROT  ROT ROT ;
\ PICK ( xn..x0 n -- xn..x0 xn ). 0 PICK = DUP; 1 PICK = OVER.
\ Computes (n+1)*3 as n+1 + n+1 + n+1 to avoid the Forth-level `*`.
: PICK  1 + DUP DUP + + SP@ + @ ;

\ ---- GH #3: comparison and stack words built on < ----
: ?DUP    DUP IF DUP THEN ;
: >       SWAP < ;
: <=      1 + < ;
: >=      1 - > ;
: <>      = 0= ;
: MIN     OVER OVER < IF DROP ELSE NIP THEN ;
: MAX     OVER OVER < IF NIP ELSE DROP THEN ;

\ RECURSE ( -- )  IMMEDIATE — at compile time, compile the CFA of
\ the in-progress colon-def. CFA = LATEST + 4 + namelen.
: RECURSE  LATEST @ DUP 3 + C@ 63 AND + 4 + , ; IMMEDIATE

\ ROLL ( xu xu-1 ... x0 u -- xu-1 ... x0 xu )  rotate u+1 items.
\ 0 ROLL is no-op; 1 ROLL = SWAP; 2 ROLL = ROT.
: ROLL    ?DUP IF SWAP >R 1 - RECURSE R> SWAP THEN ;

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
: NEGATE  0 SWAP - ;
: ABS     DUP 0< IF NEGATE THEN ;

\ ---- Division helpers on top of /MOD ----
: /     /MOD SWAP DROP ;
: MOD   /MOD DROP ;

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
