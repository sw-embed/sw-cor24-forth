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
