: DUP   SP@ @ ;
: DROP  SP@ 3 + SP! ;
: OVER  SP@ 3 + @ ;
: SWAP  >R DUP R> SP@ 6 + ! ;
: R@    RP@ 3 + @ ;
: : CREATE ,DOCOL LATEST @ 3 + DUP C@ 64 OR SWAP C! ] ;
: ; ['] EXIT , LATEST @ 3 + DUP C@ 191 AND SWAP C! 0 STATE ! ; IMMEDIATE
