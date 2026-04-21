\ BEGIN...WHILE...REPEAT — test-in-middle loop. Runs the body
\ while the WHILE condition is non-zero, then branches back to BEGIN.
\ TRIANGLE sums 1+2+...+n without needing a separate counter word.
: TRIANGLE  ( n -- sum )
  0 SWAP
  BEGIN
    DUP
  WHILE
    TUCK + SWAP 1 -
  REPEAT
  DROP
;
1 TRIANGLE .
5 TRIANGLE .
10 TRIANGLE .
