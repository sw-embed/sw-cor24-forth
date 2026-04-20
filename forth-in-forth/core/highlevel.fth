\ highlevel.fth: stack diagnostics built on the SP@ primitive.

\ DEPTH: how many cells the user has on the data stack.
\ sp_base = 0xFEEC00 = 16706560 (hardware-reset sp on COR24).
\ SP@ pushes sp at primitive entry (which is sp at the call site).
: DEPTH ( -- n )  SP@ 16706560 SWAP - 3 / ;

\ .S : non-destructive print of the data stack.
\ Format: <N> v1 v2 ... vN  where v1 is bottom, vN is top.
\ After we DUP DEPTH, sp has DEPTH on top; underneath are the user
\ values. Walk from bottom (sp + 3*DEPTH) toward top (sp + 3),
\ stepping by -3 each time.
: .S ( -- )
  60 EMIT                         \ '<'
  DEPTH DUP .                     \ print depth, leaves it on stack
  62 EMIT                         \ '>'
  DUP 0= IF DROP EXIT THEN        \ no values to walk
  SP@ OVER 3 * +                  \ ( count addr=sp+3*count )
  BEGIN
    DUP @ .                       \ print value at addr (with trailing space)
    3 -                           \ addr -= 3 (toward top)
    SWAP 1 - SWAP                 \ count--
    OVER 0=                       \ count==0?
  UNTIL
  DROP DROP                       \ drop addr and 0
;
