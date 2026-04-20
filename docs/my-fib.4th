: 2DUP OVER OVER ;
: 2DROP DROP DROP ;
: 2SWAP >R >R SWAP R> R> SWAP ;
: 2OVER >R >R OVER OVER R> SWAP R> SWAP ;
: NIP SWAP DROP ;
: TUCK SWAP OVER ;
: 1+    1 + ;
: 1-    1 - ;
: FIB ( n -- f )
  >R 0 1 R>
  BEGIN
    DUP 0=
    IF
      DROP
      NIP
      EXIT
    THEN
    >R
    TUCK +
    R> 1-
    0
  UNTIL
;
0 FIB .
1 FIB .
2 FIB .
3 FIB .
4 FIB .
5 FIB .
6 FIB .
7 FIB .
8 FIB .
9 FIB .
10 FIB .

