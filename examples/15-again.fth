\ BEGIN...AGAIN — unconditional backward branch. Needs an explicit
\ exit (EXIT or 0BRANCH) to ever terminate. Here we count down to 0
\ and use IF...EXIT to break out of the loop from its middle.
: CDOWN  ( n -- )
  BEGIN
    DUP .
    1 -
    DUP 0= IF DROP EXIT THEN
  AGAIN
;
5 CDOWN
