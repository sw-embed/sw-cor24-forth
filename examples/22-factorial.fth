\ Recursion. A word being defined is already in the dictionary, so it can
\ call itself by name. FACT stops at 1 (and gives 0! = 1 too).
: FACT  ( n -- n! )  DUP 2 < IF DROP 1 ELSE DUP 1 - FACT * THEN ;
0 FACT .          \ 1
1 FACT .          \ 1
5 FACT .          \ 120
10 FACT .         \ 3628800
