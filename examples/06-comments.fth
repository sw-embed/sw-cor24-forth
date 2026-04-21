\ This is a line comment (everything after \ is ignored)

( This is a paren comment — can appear inline )

: SQUARE ( n -- n*n ) DUP * ;
: DEMO ( -- ) 7 SQUARE . ;

\ Try it:
DEMO
