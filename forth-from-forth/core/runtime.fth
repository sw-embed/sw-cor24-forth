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
: -       NEGATE + ;
: : CREATE ,DOCOL LATEST @ 3 + DUP C@ 64 OR SWAP C! ] ;
: ; ['] EXIT , LATEST @ 3 + DUP C@ 191 AND SWAP C! 0 STATE ! ; IMMEDIATE
\ :NONAME ( -- xt ) — anonymous colon def; xt is the future CFA.
\ Standard `;` finalizes. See GH #5.
: :NONAME  HERE @ ,DOCOL ] ;
