\ highlevel.fth: stack diagnostics, dictionary tools, decompiler.

\ ---- DEPTH and .S (rely on the SP@ primitive) ----
\ sp_base = 0xFEEC00 = 16706560 (hardware-reset sp on COR24).
: DEPTH ( -- n )  SP@ 16706560 SWAP - 3 / ;

: .S ( -- )
  60 EMIT
  DEPTH DUP .
  62 EMIT
  DUP 0= IF DROP EXIT THEN
  SP@ OVER 3 * +
  BEGIN
    DUP @ .
    3 -
    SWAP 1 - SWAP
    OVER 0=
  UNTIL
  DROP DROP
;

\ ---- ' (tick): runtime CFA lookup ----
\ Reads the next input token, finds it, returns CFA. (FIND already
\ pushes flag on top; DROP discards it. Assumes the word is found.)
: '  WORD FIND DROP ;

\ ---- PRINT-NAME: emit N chars from a name buffer + trailing space.
: PRINT-NAME ( name-addr namelen -- )
  BEGIN
    DUP 0= IF DROP DROP 32 EMIT EXIT THEN
    SWAP DUP C@ EMIT 1 + SWAP 1 -
    0
  UNTIL ;

\ ---- WORDS: walk LATEST chain, print each non-HIDDEN entry's name.
\ Dict header: link(3) flags_len(1) name(N). HIDDEN = bit 6 of flags_len.
: WORDS ( -- )
  LATEST @
  BEGIN
    DUP 0= IF DROP EXIT THEN
    DUP 3 + C@                       \ ( entry flags_len )
    DUP 64 AND 0=
    IF
      OVER 4 + SWAP 63 AND           \ ( entry name-addr namelen )
      PRINT-NAME
    ELSE
      DROP
    THEN
    @
    0
  UNTIL ;

\ ---- VER: version banner ----
: VER  67 EMIT 79 EMIT 82 EMIT 50 EMIT 52 EMIT 32 EMIT
       70 EMIT 111 EMIT 114 EMIT 116 EMIT 104 EMIT 32 EMIT
       118 EMIT 48 EMIT 46 EMIT 10 EMIT ;

\ ---- >NAME: reverse CFA lookup. Returns (name-addr namelen) or (0 0). ----
: >NAME ( cfa -- name-addr namelen )
  LATEST @
  BEGIN
    DUP 0= IF DROP DROP 0 0 EXIT THEN
    DUP 3 + C@ 63 AND >R              \ ( cfa entry ) R: namelen
    OVER OVER 4 + R@ + =              \ this_cfa = entry+4+namelen, compare
    IF
      NIP 4 + R> EXIT                 \ match: name_addr = entry+4
    THEN
    R> DROP
    @
    0
  UNTIL ;

\ ---- SEE: simple decompiler. Walks colon body, prints CFA names.
\ Cells that don't match any dict entry (like LIT operands and BRANCH
\ offsets) print as decimal numbers with trailing space.
: SEE ( "name" -- )
  ' DUP 0= IF DROP EXIT THEN
  6 +                                  \ skip far-CFA template
  BEGIN
    DUP @                              ( ip cell )
    DUP ['] EXIT = IF DROP DROP 59 EMIT 10 EMIT EXIT THEN
    DUP >NAME                          ( ip cell name-addr namelen )
    DUP 0= IF
      DROP DROP                        ( ip cell )
      .
    ELSE
      >R >R                            ( ip cell ) R: namelen, name-addr
      DROP                             ( ip ) R: namelen, name-addr
      R> R>                            ( ip name-addr namelen )
      PRINT-NAME
    THEN
    3 +
    0
  UNTIL ;
