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

\ ---- Subset 18: user-level FIND as a Forth linked-list walk ----
\ STR= ( a1 a2 n -- flag )  byte-compare two n-byte strings.
: STR=  ( a1 a2 n -- flag )
  BEGIN DUP WHILE
    1 -
    >R
    OVER C@ OVER C@ = INVERT IF
      R> DROP 2DROP 0 EXIT
    THEN
    SWAP 1 + SWAP 1 +
    R>
  REPEAT
  2DROP DROP -1
;

\ FIND ( c-addr -- cfa 1-or-minus-1 | c-addr 0 )
\ Walk LATEST chain. Skip HIDDEN; compare flags_len&63 to search len,
\ then byte-compare name. Returns (cfa, 1) for IMMEDIATE, (cfa, -1) for
\ normal, or (c-addr, 0) if not found. No hash/lookaside — linear walk.
: FIND  ( c-addr -- cfa 1-or-minus-1 | c-addr 0 )
  DUP C@ OVER 1 +
  LATEST @
  BEGIN DUP WHILE
    DUP 3 + C@ 64 AND IF
      @
    ELSE
      DUP 3 + C@ 63 AND
      3 PICK = IF
        DUP 3 + C@ 63 AND
        OVER 4 +
        3 PICK
        ROT
        STR= IF
          DUP 3 + C@
          DUP 63 AND
          2 PICK + 4 +
          SWAP 128 AND
          IF 1 ELSE -1 THEN
          >R >R
          DROP DROP DROP DROP
          R> R>
          EXIT
        THEN
      THEN
      @
    THEN
  REPEAT
  DROP DROP DROP
  0
;

\ ---- ' (tick): runtime CFA lookup ----
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
    DUP 3 + C@
    DUP 64 AND 0=
    IF
      OVER 4 + SWAP 63 AND
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

\ ---- >NAME: reverse CFA lookup. Returns name-addr+namelen or 0 0. ----
: >NAME ( cfa -- name-addr namelen )
  LATEST @
  BEGIN
    DUP 0= IF DROP DROP 0 0 EXIT THEN
    DUP 3 + C@ 63 AND >R
    OVER OVER 4 + R@ + =
    IF
      NIP 4 + R> EXIT
    THEN
    R> DROP
    @
    0
  UNTIL ;

\ ---- SEE-CFA: decompile the body of a colon def given its CFA. ----
\ Skips the 6-byte far-CFA template, then walks cells, printing each
\ recognised CFA's name and unrecognised cells (LIT operands and
\ BRANCH offsets) as decimal numbers. Stops on EXIT and prints `;`.
: SEE-CFA ( cfa -- )
  6 +
  BEGIN
    DUP @
    DUP ['] EXIT = IF DROP DROP 59 EMIT 10 EMIT EXIT THEN
    DUP >NAME
    DUP 0= IF
      DROP DROP
      .
    ELSE
      >R >R
      DROP
      R> R>
      PRINT-NAME
    THEN
    3 +
    0
  UNTIL ;

\ ---- SEE: decompile a named word. ----
: SEE ( "name" -- )
  ' DUP 0= IF DROP EXIT THEN
  SEE-CFA ;

\ ---- PRIM-MARKER: emit "[primitive] ;" then a newline. ----
: PRIM-MARKER
  91 EMIT 112 EMIT 114 EMIT 105 EMIT 109 EMIT
  105 EMIT 116 EMIT 105 EMIT 118 EMIT 101 EMIT
  93 EMIT 32 EMIT 59 EMIT 10 EMIT ;

\ ---- DUMP-ALL: walk LATEST and decompile every non-HIDDEN entry. ----
\ For each entry prints `: NAME body ;` on its own line. Primitives
\ (whose CFA does not start with 0x7D, the `push r0` opcode of the
\ far-CFA template) get `[primitive] ;` instead of a body.
: DUMP-ALL ( -- )
  LATEST @
  BEGIN
    DUP 0= IF DROP EXIT THEN
    DUP 3 + C@
    DUP 64 AND 0=
    IF
      58 EMIT 32 EMIT                          \ ": "
      OVER 4 + OVER 63 AND PRINT-NAME          \ name + space
      63 AND >R                                \ stash namelen
      DUP 4 + R> +                             \ CFA = entry+4+namelen
      DUP C@ 125 = IF
        SEE-CFA
      ELSE
        DROP PRIM-MARKER
      THEN
    ELSE
      DROP
    THEN
    @ 0
  UNTIL ;
