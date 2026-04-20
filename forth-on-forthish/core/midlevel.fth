\ midlevel.fth: number base, simple I/O, number output.
: CR        10 EMIT ;
: SPACE     32 EMIT ;
: HEX       16 BASE ! ;
: DECIMAL   10 BASE ! ;

\ `.` prints a signed integer in the current BASE, followed by a space.
\ Uses /MOD to extract digits (pushed as ASCII onto the data stack,
\ count kept on the return stack), then a pop-and-emit loop.
: .  ( n -- )
  DUP 0< IF 45 EMIT NEGATE THEN       \ leading minus for negatives
  0 >R                                  \ digit count on return stack
  BEGIN
    BASE @ /MOD SWAP                    ( quot rem )
    DUP 10 < IF 48 + ELSE 55 + THEN     ( quot digit-char )
    SWAP                                ( digit-char quot )
    R> 1 + >R                           \ count++
    DUP 0=                              \ quot==0?
  UNTIL
  DROP R>                               \ drop quot, fetch count
  BEGIN
    DUP 0= IF DROP 32 EMIT EXIT THEN
    1 - SWAP EMIT 0
  UNTIL
;
