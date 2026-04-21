\ DO...LOOP / ?DO — counted loops. DO pushes limit+index to RS;
\ LOOP increments and branches back; ?DO skips the loop entirely
\ when start == limit. Use I to read the current index, UNLOOP
\ to drop loop state from RS before an early EXIT. These words are
\ IMMEDIATE so they must appear inside a colon definition.

: RANGE    ( limit start -- )  DO I . LOOP ;
: RANGE?   ( limit start -- )  ?DO I . LOOP ;
: FACT     ( n -- n! )  1 SWAP 1 + 1 ?DO I * LOOP ;
: FIND-5   ( -- 5 )
  10 0 DO
    I 5 = IF I UNLOOP EXIT THEN
  LOOP
  -1                                    \ sentinel: not found
;

5 0 RANGE CR                            \ 0 1 2 3 4
10 3 RANGE CR                           \ 3 4 5 6 7 8 9
5 5 RANGE? CR                           \ (empty — start == limit)
1 FACT .                                \ 1
5 FACT .                                \ 120
10 FACT .  CR                           \ 3628800
FIND-5 . CR                             \ 5
