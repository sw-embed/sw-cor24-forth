\ VARIABLE — name a mutable cell. NAME pushes the address; use @ and
\ ! to read and write. COUNTER shows a variable as a small helper
\ with BUMP and RESET words wrapped around its address.
VARIABLE COUNTER
: BUMP   COUNTER @ 1 + COUNTER ! ;
: RESET  0 COUNTER ! ;
: SHOW   COUNTER @ . ;
RESET
SHOW
BUMP BUMP BUMP
SHOW
BUMP BUMP
SHOW
RESET
SHOW
