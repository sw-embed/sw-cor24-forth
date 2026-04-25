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
\ recognised CFA's name and unrecognised cells (numeric literals,
\ BRANCH/0BRANCH offsets) as decimal numbers. Stops on a real
\ EXIT instruction and prints `;`.
\
\ Critical: when the current cell is LIT/BRANCH/0BRANCH, the NEXT
\ cell is data (a literal value or branch offset), not code. We
\ must print that following cell without re-checking it for EXIT,
\ otherwise `['] EXIT` (which compiles to `LIT <cfa-of-EXIT>`) is
\ misread as a real EXIT and truncates the decompile mid-body.
\ Issue #4.

\ Print one cell either as a known dict-entry name or as decimal.
: SEE-CELL ( cell -- )
  DUP >NAME DUP 0= IF
    DROP DROP .
  ELSE
    >R >R DROP R> R>
    PRINT-NAME
  THEN ;

: SEE-CFA ( cfa -- )
  6 +
  BEGIN
    DUP @
    DUP ['] EXIT = IF DROP DROP 59 EMIT 10 EMIT EXIT THEN
    DUP ['] LIT =
    OVER ['] BRANCH = OR
    OVER ['] 0BRANCH = OR
    IF
      \ Data-following opcode. Print the opcode itself, advance,
      \ print the operand cell as data (no EXIT check on it).
      SEE-CELL
      3 +
      DUP @ SEE-CELL
    ELSE
      SEE-CELL
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
