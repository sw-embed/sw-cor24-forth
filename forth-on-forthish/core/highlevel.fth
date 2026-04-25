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

\ ---- Subset 19: user-level NUMBER and DIGIT-VALUE ----
\ DIGIT-VALUE ( char -- n -1 | char 0 )  — convert ASCII digit char to
\ its numeric value in the current BASE's supported range (0–9, A–F,
\ a–f). Returns (n, -1) on success, leaves (char, 0) on failure so the
\ caller can emit a diagnostic.
: DIGIT-VALUE  ( char -- n -1 | char 0 )
  DUP 48 < IF 0 EXIT THEN
  DUP 58 < IF 48 - -1 EXIT THEN
  DUP 65 < IF 0 EXIT THEN
  DUP 71 < IF 55 - -1 EXIT THEN
  DUP 97 < IF 0 EXIT THEN
  DUP 103 < IF 87 - -1 EXIT THEN
  0
;

\ NUMBER ( c-addr -- n 0 | 0 -1 )  — parse counted string at c-addr
\ as a signed integer in BASE. Handles leading '-'. Returns (n, 0) on
\ success, (0, -1) on failure (empty, bare '-', or any non-digit char).
\ Layout during the digit loop: sign and running accumulator live on
\ RS (RS top = acc, below = sign); DS carries (rem ptr).
: NUMBER  ( c-addr -- n 0 | 0 -1 )
  DUP C@
  DUP 0= IF 2DROP 0 -1 EXIT THEN
  SWAP 1 +
  1 >R                                   \ RS: sign=1
  OVER C@ 45 = IF
    R> DROP -1 >R                        \ sign=-1
    1 + SWAP 1 - SWAP
    OVER 0= IF 2DROP R> DROP 0 -1 EXIT THEN
  THEN
  0 >R                                   \ RS: sign, acc=0
  BEGIN
    OVER
  WHILE
    DUP C@ DIGIT-VALUE IF
      R> BASE @ * + >R                   \ acc = acc*BASE + digit
      1 + SWAP 1 - SWAP                  \ ptr++, rem--
    ELSE
      DROP 2DROP R> DROP R> DROP 0 -1 EXIT
    THEN
  REPEAT
  2DROP
  R> R> *
  0
;

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

\ ---- Subset 20: INTERPRET + QUIT moved to Forth ----
\ Reads tokens until WORD returns empty (EOL). Per token:
\   found → IMMEDIATE or STATE=0 ⇒ EXECUTE; else compile with `,`
\   not found → NUMBER; success ⇒ push or compile LIT+n; fail ⇒ "? "
\ Mirrors asm do_interpret's visible behavior. The `LIT LIT` pair
\ in the compile-literal arm is the standard trick to push LIT's own
\ CFA at runtime (first LIT pushes the cell that follows, which is
\ another LIT_cfa) so we can `,` it into the caller's definition.
: INTERPRET ( -- )
  BEGIN
    WORD
    DUP C@ 0= IF DROP EXIT THEN
    FIND
    DUP IF
      STATE @ 0= OVER 1 = OR IF
        DROP EXECUTE
      ELSE
        DROP ,
      THEN
    ELSE
      DROP
      NUMBER
      IF
        DROP 63 EMIT 32 EMIT
      ELSE
        STATE @ IF LIT LIT , , THEN
      THEN
    THEN
  AGAIN
;

\ Outer REPL loop. Prints space-o-k-LF after each interpret-mode
\ line; silent in compile mode. Never returns. Installed in
\ QUIT-VECTOR so stack_underflow_err can re-enter after reset.
: QUIT ( -- )
  BEGIN
    INTERPRET
    STATE @ 0= IF 32 EMIT 111 EMIT 107 EMIT 10 EMIT THEN
  AGAIN
;

\ Hand control from asm bootstrap to Forth QUIT. The asm do_quit /
\ do_quit_ok / do_quit_restart continue to drive lines up to this
\ point; once QUIT executes here it never returns, and all
\ subsequent input (including examples/*.fth) flows through Forth.
' QUIT QUIT-VECTOR !
QUIT
