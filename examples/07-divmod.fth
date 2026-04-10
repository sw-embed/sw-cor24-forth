\ /MOD demo — division and modulo on COR24
\ /MOD ( n1 n2 -- rem quot ) is the primitive;
\ / and MOD are built from it.

: / /MOD SWAP DROP ;
: MOD /MOD DROP ;

\ basic division
7 2 /MOD . .        \ expect 3 1 (quot rem)
10 3 /MOD . .       \ expect 3 1
6 3 /MOD . .        \ expect 2 0

\ shorthand words
20 7 / .             \ expect 2
20 7 MOD .           \ expect 6

\ fizzbuzz-style check
: FIZZ? 3 MOD 0 = ;
: BUZZ? 5 MOD 0 = ;
15 FIZZ? .           \ expect 1 (true)
15 BUZZ? .           \ expect 1 (true)
7 FIZZ? .            \ expect 0 (false)
