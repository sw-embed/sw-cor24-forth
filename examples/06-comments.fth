\ This is a line comment (everything after \ is ignored)

( This is a paren comment — can appear inline )

: square ( n -- n*n ) dup * ;
: demo ( -- ) 7 square . ;

\ Try it:
demo
