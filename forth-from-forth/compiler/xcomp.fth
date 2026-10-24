\ xcomp.fth — forth-from-forth cross-compiler
\
\ Step 005: hardcoded emission for runtime.fth's 10 colon defs.
\ Extends step 004a's pipeline proof to produce real COR24 asm
\ text for the dict entries + threaded bodies.
\
\ Runs inside the phase-3 forth-on-forthish REPL. Emits to UART;
\ scripts/build-kernel.sh captures and writes to
\ compiler/out/runtime-dict.s.
\
\ String convention: Pascal-style counted strings (length byte
\ then chars).

\ ============================================================
\ Primitive string helpers
\ ============================================================

: C,  HERE @ C!  HERE @ 1 + HERE ! ;

\ STR: defines a word that pushes the address of its counted-
\ string data. Pattern: CREATE + ,DOCOL + LIT + <pre-computed-
\ address-of-data> + EXIT. HERE@9+ captures the post-body offset
\ at definition time, so the compiled LIT loads the address of
\ the first user-appended byte exactly.
: STR:  CREATE ,DOCOL HERE @ 9 + LIT LIT , , LIT EXIT , ;

: COUNT  DUP 1 + SWAP C@ ;

: TYPE
  BEGIN
    DUP 0= IF 2DROP EXIT THEN
    SWAP DUP C@ EMIT 1 + SWAP 1 -
    0
  UNTIL
;

: EMIT-COUNTED  COUNT TYPE ;

: NL  10 EMIT ;

\ ============================================================
\ Number output without trailing space
\ ============================================================
\ Phase-3 `.` always appends a trailing space; that breaks
\ `.byte 125` emission where we need "125" tight. Copy `.`'s
\ logic but strip the trailing-space emit.

: N.
  DUP 0< IF 45 EMIT NEGATE THEN
  0 >R
  BEGIN
    BASE @ /MOD SWAP
    DUP 10 < IF 48 + ELSE 55 + THEN
    SWAP
    R> 1 + >R
    DUP 0=
  UNTIL
  DROP R>
  BEGIN
    DUP 0= IF DROP EXIT THEN
    1 - SWAP EMIT 0
  UNTIL
;

\ ============================================================
\ Asm emission helpers
\ ============================================================

\ Emit ".byte " then the number, then newline.
: EMIT-BYTE-LITERAL  ( n -- )
  46 EMIT 98 EMIT 121 EMIT 116 EMIT 101 EMIT 32 EMIT   \ ".byte "
  N. NL ;

\ Emit ".word " then the number, then newline.
: EMIT-WORD-LITERAL  ( n -- )
  46 EMIT 119 EMIT 111 EMIT 114 EMIT 100 EMIT 32 EMIT  \ ".word "
  N. NL ;

\ Emit ".word " then a counted-string label, then newline.
: EMIT-WORD-LABEL  ( counted-c-addr -- )
  46 EMIT 119 EMIT 111 EMIT 114 EMIT 100 EMIT 32 EMIT  \ ".word "
  EMIT-COUNTED NL ;

\ Emit a counted-string label followed by ":" and newline.
: EMIT-LABEL-DEF  ( counted-c-addr -- )
  EMIT-COUNTED
  58 EMIT NL ;

\ ============================================================
\ Marker strings
\ ============================================================

\ "!!BEGIN-KERNEL!!" — 16 chars
STR: marker-begin
  16 C,
  33 C, 33 C, 66 C, 69 C, 71 C, 73 C, 78 C, 45 C,
  75 C, 69 C, 82 C, 78 C, 69 C, 76 C, 33 C, 33 C,

\ "!!END-KERNEL!!" — 14 chars
STR: marker-end
  14 C,
  33 C, 33 C, 69 C, 78 C, 68 C, 45 C,
  75 C, 69 C, 82 C, 78 C, 69 C, 76 C, 33 C, 33 C,

\ ============================================================
\ Primitive CFA label strings (referenced by colon-def bodies)
\ ============================================================

\ "do_docol_far" — 12 chars
STR: label-docol-far  12 C,
  100 C, 111 C, 95 C,
  100 C, 111 C, 99 C, 111 C, 108 C, 95 C,
  102 C, 97 C, 114 C,

\ "do_exit" — 7 chars
STR: label-exit  7 C,
  100 C, 111 C, 95 C, 101 C, 120 C, 105 C, 116 C,

\ "do_lit" — 6 chars
STR: label-lit  6 C,
  100 C, 111 C, 95 C, 108 C, 105 C, 116 C,

\ "do_sp_fetch" — 11 chars
STR: label-sp-fetch  11 C,
  100 C, 111 C, 95 C, 115 C, 112 C, 95 C,
  102 C, 101 C, 116 C, 99 C, 104 C,

\ "do_sp_store" — 11 chars
STR: label-sp-store  11 C,
  100 C, 111 C, 95 C, 115 C, 112 C, 95 C,
  115 C, 116 C, 111 C, 114 C, 101 C,

\ "do_rp_fetch" — 11 chars
STR: label-rp-fetch  11 C,
  100 C, 111 C, 95 C, 114 C, 112 C, 95 C,
  102 C, 101 C, 116 C, 99 C, 104 C,

\ "do_tor" — 6 chars
STR: label-tor  6 C,
  100 C, 111 C, 95 C, 116 C, 111 C, 114 C,

\ "do_rfrom" — 8 chars
STR: label-rfrom  8 C,
  100 C, 111 C, 95 C, 114 C, 102 C, 114 C, 111 C, 109 C,

\ "do_fetch" — 8 chars
STR: label-fetch  8 C,
  100 C, 111 C, 95 C, 102 C, 101 C, 116 C, 99 C, 104 C,

\ "do_store" — 8 chars
STR: label-store  8 C,
  100 C, 111 C, 95 C, 115 C, 116 C, 111 C, 114 C, 101 C,

\ "do_plus" — 7 chars
STR: label-plus  7 C,
  100 C, 111 C, 95 C, 112 C, 108 C, 117 C, 115 C,

\ "do_nand" — 7 chars
STR: label-nand  7 C,
  100 C, 111 C, 95 C, 110 C, 97 C, 110 C, 100 C,

\ ============================================================
\ Forth-def entry labels (link chain + reference targets)
\ ============================================================
\ Naming convention: fff_entry_<NAME> for dict header,
\                    fff_cfa_<NAME> for CFA start (body = PFA).

\ "fff_entry_DUP" — 13 chars
STR: fff-entry-dup  13 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  68 C, 85 C, 80 C,

\ "fff_cfa_DUP" — 11 chars
STR: fff-cfa-dup  11 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  68 C, 85 C, 80 C,

\ "fff_entry_DROP" — 14 chars
STR: fff-entry-drop  14 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  68 C, 82 C, 79 C, 80 C,

\ "fff_cfa_DROP" — 12 chars
STR: fff-cfa-drop  12 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  68 C, 82 C, 79 C, 80 C,

\ "fff_entry_OVER" — 14 chars
STR: fff-entry-over  14 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  79 C, 86 C, 69 C, 82 C,

\ "fff_cfa_OVER" — 12 chars
STR: fff-cfa-over  12 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  79 C, 86 C, 69 C, 82 C,

\ "fff_entry_SWAP" — 14 chars
STR: fff-entry-swap  14 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  83 C, 87 C, 65 C, 80 C,

\ "fff_cfa_SWAP" — 12 chars
STR: fff-cfa-swap  12 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  83 C, 87 C, 65 C, 80 C,

\ "fff_entry_R@" — 12 chars
STR: fff-entry-r-at  12 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  82 C, 64 C,

\ "fff_cfa_R@" — 10 chars
STR: fff-cfa-r-at  10 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  82 C, 64 C,

\ "fff_entry_INVERT" — 16 chars
STR: fff-entry-invert  16 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  73 C, 78 C, 86 C, 69 C, 82 C, 84 C,

\ "fff_cfa_INVERT" — 14 chars
STR: fff-cfa-invert  14 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  73 C, 78 C, 86 C, 69 C, 82 C, 84 C,

\ "fff_entry_AND" — 13 chars
STR: fff-entry-and  13 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  65 C, 78 C, 68 C,

\ "fff_cfa_AND" — 11 chars
STR: fff-cfa-and  11 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  65 C, 78 C, 68 C,

\ "fff_entry_OR" — 12 chars
STR: fff-entry-or  12 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  79 C, 82 C,

\ "fff_cfa_OR" — 10 chars
STR: fff-cfa-or  10 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  79 C, 82 C,

\ "fff_entry_XOR" — 13 chars
STR: fff-entry-xor  13 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  88 C, 79 C, 82 C,

\ "fff_cfa_XOR" — 11 chars
STR: fff-cfa-xor  11 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  88 C, 79 C, 82 C,

\ "fff_entry_NEGATE" — 16 chars
STR: fff-entry-negate  16 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  78 C, 69 C, 71 C, 65 C, 84 C, 69 C,

\ "fff_cfa_NEGATE" — 14 chars
STR: fff-cfa-negate  14 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  78 C, 69 C, 71 C, 65 C, 84 C, 69 C,

\ ============================================================
\ Additional primitive labels needed for - : ; defs
\ ============================================================

\ "do_create" — 9 chars
STR: label-create  9 C,
  100 C, 111 C, 95 C,
  99 C, 114 C, 101 C, 97 C, 116 C, 101 C,

\ "do_comma_docol" — 14 chars
STR: label-comma-docol  14 C,
  100 C, 111 C, 95 C,
  99 C, 111 C, 109 C, 109 C, 97 C, 95 C,
  100 C, 111 C, 99 C, 111 C, 108 C,

\ "do_latest" — 9 chars
STR: label-latest  9 C,
  100 C, 111 C, 95 C,
  108 C, 97 C, 116 C, 101 C, 115 C, 116 C,

\ "do_rbrac" — 8 chars
STR: label-rbrac  8 C,
  100 C, 111 C, 95 C,
  114 C, 98 C, 114 C, 97 C, 99 C,

\ "do_state" — 8 chars
STR: label-state  8 C,
  100 C, 111 C, 95 C,
  115 C, 116 C, 97 C, 116 C, 101 C,

\ "do_cfetch" — 9 chars
STR: label-cfetch  9 C,
  100 C, 111 C, 95 C,
  99 C, 102 C, 101 C, 116 C, 99 C, 104 C,

\ "do_cstore" — 9 chars
STR: label-cstore  9 C,
  100 C, 111 C, 95 C,
  99 C, 115 C, 116 C, 111 C, 114 C, 101 C,

\ "do_comma" — 8 chars
STR: label-comma  8 C,
  100 C, 111 C, 95 C,
  99 C, 111 C, 109 C, 109 C, 97 C,

\ ============================================================
\ Additional Forth-def labels for -, :, ;
\ ============================================================
\ The actual NAMES (byte values 45, 58, 59) are non-alphanumeric,
\ so labels use spelled-out forms: MINUS, COLON, SEMI.

\ "fff_entry_MINUS" — 15 chars
STR: fff-entry-minus  15 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  77 C, 73 C, 78 C, 85 C, 83 C,

\ "fff_cfa_MINUS" — 13 chars
STR: fff-cfa-minus  13 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  77 C, 73 C, 78 C, 85 C, 83 C,

\ "fff_entry_COLON" — 15 chars
STR: fff-entry-colon  15 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  67 C, 79 C, 76 C, 79 C, 78 C,

\ "fff_cfa_COLON" — 13 chars
STR: fff-cfa-colon  13 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  67 C, 79 C, 76 C, 79 C, 78 C,

\ "fff_entry_SEMI" — 14 chars
STR: fff-entry-semi  14 C,
  102 C, 102 C, 102 C, 95 C, 101 C, 110 C, 116 C, 114 C, 121 C, 95 C,
  83 C, 69 C, 77 C, 73 C,

\ "fff_cfa_SEMI" — 12 chars
STR: fff-cfa-semi  12 C,
  102 C, 102 C, 102 C, 95 C, 99 C, 102 C, 97 C, 95 C,
  83 C, 69 C, 77 C, 73 C,

\ ============================================================
\ Symbol-table infrastructure (step 008 parser MVP)
\ ============================================================
\ Each entry is 9 bytes: [prev:3][name-ptr:3][label-ptr:3].
\ `name-ptr` and `label-ptr` are counted-string addresses
\ defined via STR:.
\ xc-symbols holds the head of the linked list (0 = empty).

VARIABLE xc-symbols
0 xc-symbols !

: XC-REGISTER  ( name-ptr label-ptr -- )
  HERE @ >R                  \ save new-node address
  xc-symbols @ ,             \ prev = current head
  SWAP , ,                   \ name-ptr, then label-ptr
  R> xc-symbols !            \ head = new node
;

\ XC-MATCH? ( c-addr u entry -- flag )
\ Does `entry`'s name (a counted string at entry+3) equal the
\ input c-addr/u string? Consumes all three inputs; returns
\ -1 on match, 0 on mismatch.
: XC-MATCH?  ( c-addr u entry -- flag )
  3 + @                    \ c-addr u name-ptr
  DUP C@                   \ c-addr u name-ptr name-len
  2 PICK = IF              \ name-len == u ?
    1 +                    \ c-addr u name-start   (skip length byte)
    ROT                    \ u name-start c-addr
    SWAP                   \ u c-addr name-start
    ROT                    \ c-addr name-start u
    STR=
  ELSE
    DROP DROP DROP 0
  THEN
;

\ XC-FIND ( c-addr u -- entry-addr | 0 )
\ Walk xc-symbols newest-to-oldest, return matching entry or 0.
: XC-FIND  ( c-addr u -- entry-addr | 0 )
  xc-symbols @
  BEGIN DUP WHILE
    \ Stack: c-addr u entry
    2 PICK 2 PICK 2 PICK   \ duplicate triple for non-destructive match
    XC-MATCH? IF
      NIP NIP EXIT         \ drop u and c-addr, leave entry
    THEN
    \ No match; follow prev link. Stack: c-addr u entry
    @                      \ entry → prev
  REPEAT
  NIP NIP                  \ drop u and c-addr, leave 0
;

\ ============================================================
\ Target-side word NAMES (counted strings for symbol-table
\ lookup). Separate from the emitted asm LABELS (already
\ defined as label-* counted strings above).
\ ============================================================

\ Primitive names — what appears in .fth source.

\ "SP@" — 3 chars
STR: name-sp-fetch  3 C,  83 C, 80 C, 64 C,

\ "@" — 1 char
STR: name-fetch     1 C,  64 C,

\ "+" — 1 char
STR: name-plus      1 C,  43 C,

\ "NAND" — 4 chars
STR: name-nand      4 C,  78 C, 65 C, 78 C, 68 C,

\ "DUP" — 3 chars (register for lookup after it's emitted)
STR: name-dup       3 C,  68 C, 85 C, 80 C,

\ ============================================================
\ Initial symbol-table population — a handful of primitives for
\ the parser MVP test. Full set added in step 009.
\ ============================================================

: XC-INIT-SYMBOLS
  name-sp-fetch label-sp-fetch XC-REGISTER
  name-fetch    label-fetch    XC-REGISTER
  name-plus     label-plus     XC-REGISTER
  name-nand     label-nand     XC-REGISTER
  name-dup      fff-cfa-dup    XC-REGISTER
;

\ ============================================================
\ Dynamic label construction (step 009)
\ ============================================================
\ NUM-C, ( n -- )  — write n's decimal digits as bytes at HERE.
\ Mirrors phase-3 `.` but C,'s instead of EMITs.
\ Handles n=0 specially; otherwise: /MOD loop pushes digit-chars
\ (LSD-first) onto DS while counting on RS, then pops count from
\ RS and C,'s digit-chars in LIFO order (MSD-first).
: NUM-C,
  DUP 0= IF DROP 48 C, EXIT THEN
  0 >R
  BEGIN
    10 /MOD              \ ( rem quot )
    SWAP 48 + SWAP       \ ( digit-char quot )
    R> 1 + >R            \ increment digit count on RS
    DUP 0=
  UNTIL
  DROP                   \ drop final 0 quot
  R>                     \ digit count from RS
  0 DO C, LOOP
;

\ Counter for monotonic label names (fff_c_1, fff_c_2, ...).
VARIABLE xc-counter
0 xc-counter !

\ MAKE-CFA-LABEL ( n -- counted-addr )
\ Build "fff_c_<n>" as a counted string at HERE; return start addr.
: MAKE-CFA-LABEL
  HERE @ >R                  \ save start addr
  0 C,                       \ placeholder length byte
  102 C, 102 C, 102 C,       \ "fff"
  95  C,                     \ "_"
  99  C,                     \ "c"
  95  C,                     \ "_"
  NUM-C,                     \ decimal digits of n
  HERE @ R@ - 1 -            \ length = HERE - start - 1 (excludes length byte)
  R@ C!                      \ patch length byte
  R>                         \ return start
;

\ MAKE-ENTRY-LABEL ( n -- counted-addr ) — "fff_e_<n>"
: MAKE-ENTRY-LABEL
  HERE @ >R
  0 C,
  102 C, 102 C, 102 C,       \ "fff"
  95  C,                     \ "_"
  101 C,                     \ "e"
  95  C,                     \ "_"
  NUM-C,
  HERE @ R@ - 1 -
  R@ C!
  R>
;

\ ============================================================
\ Token-emit dispatch
\ ============================================================
\ ?DUP ( x -- x x | 0 ) — dup if non-zero. Not in phase-3 Forth.
: ?DUP  DUP IF DUP THEN ;

\ XC-EMIT-TOKEN ( counted-addr -- )
\ Resolve a source-Forth token (counted string) to emitted
\ asm text. Three outcomes:
\   - Symbol-table hit: emit ".word <label>".
\   - Parseable number: emit ".word do_lit\n.word <n>".
\   - Otherwise: emit "<name>" diagnostic on its own line so
\     the failure is visible in the captured build output.
: XC-EMIT-TOKEN  ( counted-addr -- )
  DUP COUNT XC-FIND              \ counted entry-or-0
  ?DUP IF
    \ Match. Stack: counted entry.
    6 + @                        \ entry label-ptr
    EMIT-WORD-LABEL
    DROP                         \ drop counted
    EXIT
  THEN
  \ Not found via XC-FIND. Try NUMBER.
  DUP NUMBER                     \ counted n flag   (flag: 0 ok, -1 fail)
  0= IF
    \ Success. Stack: counted n.
    SWAP DROP                    \ drop counted, keep n
    label-lit EMIT-WORD-LABEL
    EMIT-WORD-LITERAL
    EXIT
  THEN
  \ Failure. Stack: counted 0.
  DROP                           \ drop the 0 placeholder
  \ Emit the unresolvable token on its own line.
  COUNT TYPE NL
;

\ ============================================================
\ Def emission helpers
\ ============================================================

\ Each EMIT-<NAME> emits one dict entry: header (link, flags_len,
\ name bytes) + far-DOCOL prelude + threaded body + do_exit.
\ The link argument is the counted-string for the PREVIOUS entry
\ label, or 0 for the first.

\ Emit the far-DOCOL CFA prelude bytes:
\     .byte 125
\     .byte 41
\     .word do_docol_far
\     .byte 38
: EMIT-FAR-DOCOL
  125 EMIT-BYTE-LITERAL
  41  EMIT-BYTE-LITERAL
  label-docol-far EMIT-WORD-LABEL
  38  EMIT-BYTE-LITERAL
;

\ Emit a dict header given (link-counted-or-0, name-len-chars on
\ stack as separate items). Flexibility isn't worth the churn;
\ instead per-def helpers inline the header bytes themselves.

\ ============================================================
\ Top-level driver
\ ============================================================

\ ============================================================
\ Source-driven compilation (step 009)
\ ============================================================
\ Track the LAST emitted entry label so the next entry's link
\ field can point at it. 0 = no previous entry.
VARIABLE xc-prev-entry
0 xc-prev-entry !

\ Track a permanent copy of the current name being compiled so
\ XC-REGISTER can hand it to the symbol table. WORD returns
\ a pointer into the WORD-BUFFER which gets overwritten on the
\ next WORD call — we need to duplicate the bytes to HERE-area
\ storage before the next read.
\ XC-COPY-COUNTED ( counted-src -- counted-dst )
\ Copy a counted string from src to HERE, return the new addr.
: XC-COPY-COUNTED
  HERE @ >R                \ save dst start
  DUP C@                   \ src len
  DUP C, SWAP              \ store length, stack: (len src)
  1 + SWAP                 \ stack: (src-bytes len)
  0 DO
    DUP C@ C, 1 +
  LOOP
  DROP
  R>
;

\ XC-COMPILE-NAME-BYTES ( counted -- )
\ Emit `.byte <len>` then `.byte <c>` per char of counted string.
: XC-COMPILE-NAME-BYTES
  DUP C@                   \ len
  DUP EMIT-BYTE-LITERAL    \ emit length
  SWAP 1 + SWAP            \ (start-bytes len)
  0 DO
    DUP C@ EMIT-BYTE-LITERAL
    1 +
  LOOP
  DROP
;

\ XC-READ-TOKEN ( -- counted-addr )  read next non-empty token.
\ Skips EOL-induced empty WORD returns; returns when WORD gives
\ a counted string with length > 0.
: XC-READ-TOKEN
  BEGIN
    WORD                   \ counted (phase-3 WORD)
    DUP C@                 \ counted len
    0= IF DROP 0 ELSE -1 THEN
  UNTIL
;

\ XC-IS-SEMI? ( counted-addr -- flag )
\ Is this token exactly the single character `;` ?
: XC-IS-SEMI?
  DUP C@ 1 = IF
    1 + C@ 59 =
  ELSE
    DROP 0
  THEN
;

\ XC-COMPILE-BODY ( -- )  loop reading tokens, emit each via
\ XC-EMIT-TOKEN, stop at `;` (emit do_exit).
: XC-COMPILE-BODY
  BEGIN
    XC-READ-TOKEN
    DUP XC-IS-SEMI? IF
      DROP
      label-exit EMIT-WORD-LABEL
      EXIT
    THEN
    XC-EMIT-TOKEN
  AGAIN
;

\ XC-COMPILE-ENTRY ( -- )  read name, emit dict header + DOCOL
\ prelude, register in symbol table, compile body.
\ NOTE (step 009 stop): integration of XC-READ-TOKEN +
\ XC-COMPILE-BODY + IF/ELSE/UNTIL inside this def hits a
\ phase-3 corner case that returns 0 instead of the counted
\ string addr. Pieces tested individually all work:
\   - NUM-C, emits decimal digits to HERE.
\   - MAKE-CFA-LABEL / MAKE-ENTRY-LABEL build "fff_c_<N>" /
\     "fff_e_<N>" counted strings (verified via XC-TEST-LABELS
\     embedded in build-kernel.sh output).
\   - XC-COPY-COUNTED dups WORD's transient buffer to HERE.
\   - XC-COMPILE-NAME-BYTES emits ".byte" header bytes.
\   - XC-READ-TOKEN, XC-IS-SEMI? work in isolation.
\ Resolved 2026-10-23: the failure was phase-3 NUMBER rejecting -1;
\ see docs/parser-debug-notes.md "Resolution".
: XC-COMPILE-ENTRY
  XC-READ-TOKEN
  XC-COPY-COUNTED
  xc-counter @ 1 + xc-counter !
  xc-counter @ MAKE-ENTRY-LABEL
  DUP EMIT-LABEL-DEF
  xc-prev-entry @ ?DUP IF
    EMIT-WORD-LABEL
  ELSE
    0 EMIT-WORD-LITERAL
  THEN
  xc-prev-entry !
  DUP XC-COMPILE-NAME-BYTES
  xc-counter @ MAKE-CFA-LABEL
  DUP EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  XC-REGISTER
  XC-COMPILE-BODY
;

\ Step 009 test: emit a label for counters 1, 2, 17 as a smoke
\ check. Kept for now to spot-check MAKE-*-LABEL output.
: XC-TEST-LABELS
  1 MAKE-CFA-LABEL EMIT-WORD-LABEL
  2 MAKE-ENTRY-LABEL EMIT-WORD-LABEL
  17 MAKE-CFA-LABEL EMIT-WORD-LABEL
;

\ XC-COMPILE-TEST ( -- )
\ Step 009 top-level test. Initialize symbol table, wrap output
\ in BEGIN/END markers, then read one `: NAME body ;` sequence
\ from the UART stream and cross-compile it via XC-COMPILE-ENTRY.
\ Used by a dedicated test script that feeds a synthetic def.
: XC-COMPILE-TEST
  XC-INIT-SYMBOLS
  NL marker-begin EMIT-COUNTED NL
  XC-READ-TOKEN DROP          \ consume `:`, ignore it
  XC-COMPILE-ENTRY
  marker-end EMIT-COUNTED NL
;

\ ============================================================
\ Source-driven compiler (saga phase-4-tab-4 step 002)
\ ============================================================
\ XC-COMPILE-SOURCE reads target Forth source from the input
\ stream until the token XC-END and emits one dictionary entry
\ per colon definition. The primitive symbol table comes from
\ core/prims.fth (PRIM: lines); each definition registers its
\ own name before its body is read, so later bodies (and the
\ definition itself, for recursion) resolve to it.
\
\ The header's flags_len byte must say IMMEDIATE, but IMMEDIATE
\ follows the `;`. The assembler has no equates to patch it, so
\ the body is collected into a buffer first, one token after `;`
\ is read to see whether it is IMMEDIATE (if not, it is pushed
\ back for the driver), and only then is the entry emitted.

\ XC-LIT-STR ( "tok" -- counted )  copy the next token to HERE.
\ Used at load time with CONSTANT to name the tokens the
\ compiler must recognise without executing them.
: XC-LIT-STR  XC-READ-TOKEN XC-COPY-COUNTED ;
XC-LIT-STR ;         CONSTANT tok-semi
XC-LIT-STR :         CONSTANT tok-colon
XC-LIT-STR IMMEDIATE CONSTANT tok-immediate
XC-LIT-STR \         CONSTANT tok-backslash
XC-LIT-STR (         CONSTANT tok-paren
XC-LIT-STR [']       CONSTANT tok-tick
XC-LIT-STR XC-END    CONSTANT tok-end

\ XC-SAME? ( c1 c2 -- flag )  are two counted strings equal?
: XC-SAME?
  OVER C@ OVER C@ = 0= IF 2DROP 0 EXIT THEN
  DUP C@ >R  1 + SWAP 1 +  R> STR=
;

\ PRIM: ( "name" "label" -- )  register an asm primitive.
: PRIM:  XC-READ-TOKEN XC-COPY-COUNTED  XC-READ-TOKEN XC-COPY-COUNTED  XC-REGISTER ;

\ ---- Label mangling: fff_c<n>_<NAME>, fff_e<n>_<NAME>.
\ Letters and digits are kept; any other character becomes
\ _<decimal code>, so R@ -> R_64 and - -> _45. The counter keeps
\ labels unique even if a name is defined twice.
: XC-ALNUM?  ( c -- flag )
  DUP 48 < IF DROP 0 EXIT THEN
  DUP 58 < IF DROP -1 EXIT THEN
  DUP 65 < IF DROP 0 EXIT THEN
  DUP 91 < IF DROP -1 EXIT THEN
  DUP 97 < IF DROP 0 EXIT THEN
  123 <
;
: XC-MANGLE-CHAR,  ( c -- )  DUP XC-ALNUM? IF C, ELSE 95 C, NUM-C, THEN ;
: XC-MANGLE,  ( counted -- )  COUNT 0 ?DO DUP C@ XC-MANGLE-CHAR, 1 + LOOP DROP ;

\ XC-MAKE-LABEL ( name n kind-char -- label )
: XC-MAKE-LABEL
  HERE @ >R  0 C,  102 C, 102 C, 102 C, 95 C,
  C,  NUM-C,  95 C,  XC-MANGLE,
  HERE @ R@ - 1 -  R@ C!  R>
;

\ ---- Body buffer: 2 cells per item, ( kind value ).
\ kind 0 = .word <label>, 1 = LIT <n>, 2 = unresolved token.
VARIABLE xc-body
HERE @ xc-body !  HERE @ 3000 + HERE !
VARIABLE xc-body-end
: XC-BODY-RESET  xc-body @ xc-body-end ! ;
: XC-BODY,  ( value kind -- )
  xc-body-end @ !  xc-body-end @ 3 + !  xc-body-end @ 6 + xc-body-end !
;

\ XC-RESOLVE ( counted -- value kind )
: XC-RESOLVE
  DUP COUNT XC-FIND ?DUP IF NIP 6 + @ 0 EXIT THEN
  DUP NUMBER 0= IF NIP 1 EXIT THEN
  DROP XC-COPY-COUNTED 2
;

\ ---- Tracing. `1 xc-trace !` before XC-COMPILE-SOURCE writes every
\ token read, and the data-stack depth after each definition, as
\ `;` comment lines in the emitted asm. The assembler ignores them,
\ so a traced build assembles to the same bytes. Use it to find
\ where compilation goes wrong (build-kernel.sh XC_TRACE=1).
VARIABLE xc-trace     0 xc-trace !
: XC-TRACE-TOKEN  ( counted -- counted )
  xc-trace @ IF 59 EMIT 32 EMIT 116 EMIT 32 EMIT DUP EMIT-COUNTED NL THEN ;
: XC-TRACE-DEPTH  ( -- )
  xc-trace @ IF 59 EMIT 32 EMIT 100 EMIT 32 EMIT DEPTH N. NL THEN ;

\ XC-COLLECT-BODY ( -- )  read tokens up to `;` into the buffer.
: XC-COLLECT-BODY
  XC-BODY-RESET
  BEGIN
    XC-READ-TOKEN XC-TRACE-TOKEN
    DUP tok-semi XC-SAME? IF DROP EXIT THEN
    DUP tok-backslash XC-SAME? IF DROP ['] \ EXECUTE ELSE
    DUP tok-paren XC-SAME? IF DROP ['] ( EXECUTE ELSE
    DUP tok-tick XC-SAME? IF
      DROP label-lit 0 XC-BODY,  XC-READ-TOKEN XC-RESOLVE XC-BODY,
    ELSE
      XC-RESOLVE XC-BODY,
    THEN THEN THEN
  AGAIN
;

\ XC-EMIT-BODY ( -- )  write the buffered body as asm text.
: XC-EMIT-BODY
  xc-body @
  BEGIN DUP xc-body-end @ < WHILE
    DUP 3 + @  OVER @            \ addr value kind
    DUP 0= IF DROP EMIT-WORD-LABEL ELSE
    1 = IF label-lit EMIT-WORD-LABEL EMIT-WORD-LITERAL ELSE
      59 EMIT 32 EMIT 63 EMIT 32 EMIT EMIT-COUNTED NL   \ "; ? tok"
    THEN THEN
    6 +
  REPEAT
  DROP
;

VARIABLE xc-pending   0 xc-pending !
VARIABLE xc-imm       0 xc-imm !

: XC-NEXT-TOKEN  ( -- counted )
  xc-pending @ ?DUP IF 0 xc-pending ! EXIT THEN  XC-READ-TOKEN XC-TRACE-TOKEN ;

\ XC-EMIT-NAME ( name -- )  flags_len byte, then the name bytes.
: XC-EMIT-NAME
  DUP C@ xc-imm @ IF 128 + THEN EMIT-BYTE-LITERAL
  COUNT 0 ?DO DUP C@ EMIT-BYTE-LITERAL 1 + LOOP DROP
;

\ XC-COMPILE-DEF ( -- )  the `:` has been read.
: XC-COMPILE-DEF
  XC-READ-TOKEN XC-COPY-COUNTED                 \ name
  xc-counter @ 1 + xc-counter !
  DUP xc-counter @ 99 XC-MAKE-LABEL             \ name cfa
  2DUP XC-REGISTER
  XC-COLLECT-BODY
  0 xc-imm !
  XC-READ-TOKEN DUP tok-immediate XC-SAME?
  IF DROP -1 xc-imm ! ELSE xc-pending ! THEN
  OVER xc-counter @ 101 XC-MAKE-LABEL           \ name cfa entry
  DUP EMIT-LABEL-DEF
  xc-prev-entry @ ?DUP IF EMIT-WORD-LABEL ELSE 0 EMIT-WORD-LITERAL THEN
  xc-prev-entry !                               \ name cfa
  SWAP XC-EMIT-NAME
  EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  XC-EMIT-BODY
  label-exit EMIT-WORD-LABEL
  XC-TRACE-DEPTH
;

\ XC-COMPILE-SOURCE ( -- )  compile definitions until XC-END.
: XC-COMPILE-SOURCE
  0 xc-counter !  0 xc-prev-entry !  0 xc-pending !
  NL marker-begin EMIT-COUNTED NL
  BEGIN
    XC-NEXT-TOKEN
    DUP tok-end XC-SAME? IF DROP marker-end EMIT-COUNTED NL EXIT THEN
    DUP tok-colon XC-SAME? IF DROP XC-COMPILE-DEF ELSE
    DUP tok-backslash XC-SAME? IF DROP ['] \ EXECUTE ELSE
    DUP tok-paren XC-SAME? IF DROP ['] ( EXECUTE ELSE
      59 EMIT 32 EMIT 63 EMIT 32 EMIT EMIT-COUNTED NL   \ top-level token not compiled
    THEN THEN THEN
  AGAIN
;
