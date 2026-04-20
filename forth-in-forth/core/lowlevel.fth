\ lowlevel.fth: stack and arithmetic helpers built from primitives.
\ Additive — no kernel words removed at this tier.

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
