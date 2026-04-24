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

\ ----- DUP: : DUP  SP@ @ ;  (first entry, link=0) -----
: EMIT-DUP
  fff-entry-dup EMIT-LABEL-DEF
  0 EMIT-WORD-LITERAL        \ first entry — no predecessor
  3 EMIT-BYTE-LITERAL        \ namelen
  68 EMIT-BYTE-LITERAL       \ 'D'
  85 EMIT-BYTE-LITERAL       \ 'U'
  80 EMIT-BYTE-LITERAL       \ 'P'
  fff-cfa-dup EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  label-sp-fetch EMIT-WORD-LABEL
  label-fetch    EMIT-WORD-LABEL
  label-exit     EMIT-WORD-LABEL
;

\ ----- DROP: : DROP SP@ 3 + SP! ; -----
: EMIT-DROP
  fff-entry-drop EMIT-LABEL-DEF
  fff-entry-dup  EMIT-WORD-LABEL   \ link -> DUP
  4 EMIT-BYTE-LITERAL              \ namelen
  68 EMIT-BYTE-LITERAL             \ 'D'
  82 EMIT-BYTE-LITERAL             \ 'R'
  79 EMIT-BYTE-LITERAL             \ 'O'
  80 EMIT-BYTE-LITERAL             \ 'P'
  fff-cfa-drop EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  label-sp-fetch EMIT-WORD-LABEL
  label-lit      EMIT-WORD-LABEL
  3              EMIT-WORD-LITERAL  \ literal 3
  label-plus     EMIT-WORD-LABEL
  label-sp-store EMIT-WORD-LABEL
  label-exit     EMIT-WORD-LABEL
;

\ ----- OVER: : OVER SP@ 3 + @ ; -----
: EMIT-OVER
  fff-entry-over EMIT-LABEL-DEF
  fff-entry-drop EMIT-WORD-LABEL
  4 EMIT-BYTE-LITERAL
  79 EMIT-BYTE-LITERAL  86 EMIT-BYTE-LITERAL
  69 EMIT-BYTE-LITERAL  82 EMIT-BYTE-LITERAL
  fff-cfa-over EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  label-sp-fetch EMIT-WORD-LABEL
  label-lit      EMIT-WORD-LABEL
  3              EMIT-WORD-LITERAL
  label-plus     EMIT-WORD-LABEL
  label-fetch    EMIT-WORD-LABEL
  label-exit     EMIT-WORD-LABEL
;

\ ----- SWAP: : SWAP >R DUP R> SP@ 6 + ! ; -----
: EMIT-SWAP
  fff-entry-swap EMIT-LABEL-DEF
  fff-entry-over EMIT-WORD-LABEL
  4 EMIT-BYTE-LITERAL
  83 EMIT-BYTE-LITERAL  87 EMIT-BYTE-LITERAL
  65 EMIT-BYTE-LITERAL  80 EMIT-BYTE-LITERAL
  fff-cfa-swap EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  label-tor      EMIT-WORD-LABEL
  fff-cfa-dup    EMIT-WORD-LABEL   \ references earlier Forth def
  label-rfrom    EMIT-WORD-LABEL
  label-sp-fetch EMIT-WORD-LABEL
  label-lit      EMIT-WORD-LABEL
  6              EMIT-WORD-LITERAL
  label-plus     EMIT-WORD-LABEL
  label-store    EMIT-WORD-LABEL
  label-exit     EMIT-WORD-LABEL
;

\ ----- R@: : R@ RP@ 3 + @ ; -----
: EMIT-R-AT
  fff-entry-r-at EMIT-LABEL-DEF
  fff-entry-swap EMIT-WORD-LABEL
  2 EMIT-BYTE-LITERAL
  82 EMIT-BYTE-LITERAL   \ 'R'
  64 EMIT-BYTE-LITERAL   \ '@'
  fff-cfa-r-at EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  label-rp-fetch EMIT-WORD-LABEL
  label-lit      EMIT-WORD-LABEL
  3              EMIT-WORD-LITERAL
  label-plus     EMIT-WORD-LABEL
  label-fetch    EMIT-WORD-LABEL
  label-exit     EMIT-WORD-LABEL
;

\ ----- INVERT: : INVERT DUP NAND ; -----
: EMIT-INVERT
  fff-entry-invert EMIT-LABEL-DEF
  fff-entry-r-at EMIT-WORD-LABEL
  6 EMIT-BYTE-LITERAL
  73 EMIT-BYTE-LITERAL  78 EMIT-BYTE-LITERAL
  86 EMIT-BYTE-LITERAL  69 EMIT-BYTE-LITERAL
  82 EMIT-BYTE-LITERAL  84 EMIT-BYTE-LITERAL
  fff-cfa-invert EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  fff-cfa-dup EMIT-WORD-LABEL
  label-nand  EMIT-WORD-LABEL
  label-exit  EMIT-WORD-LABEL
;

\ ----- AND: : AND NAND INVERT ; -----
: EMIT-AND
  fff-entry-and EMIT-LABEL-DEF
  fff-entry-invert EMIT-WORD-LABEL
  3 EMIT-BYTE-LITERAL
  65 EMIT-BYTE-LITERAL  78 EMIT-BYTE-LITERAL  68 EMIT-BYTE-LITERAL
  fff-cfa-and EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  label-nand     EMIT-WORD-LABEL
  fff-cfa-invert EMIT-WORD-LABEL
  label-exit     EMIT-WORD-LABEL
;

\ ----- OR: : OR INVERT SWAP INVERT NAND ; -----
: EMIT-OR
  fff-entry-or EMIT-LABEL-DEF
  fff-entry-and EMIT-WORD-LABEL
  2 EMIT-BYTE-LITERAL
  79 EMIT-BYTE-LITERAL  82 EMIT-BYTE-LITERAL
  fff-cfa-or EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  fff-cfa-invert EMIT-WORD-LABEL
  fff-cfa-swap   EMIT-WORD-LABEL
  fff-cfa-invert EMIT-WORD-LABEL
  label-nand     EMIT-WORD-LABEL
  label-exit     EMIT-WORD-LABEL
;

\ ----- XOR: : XOR OVER OVER NAND DUP >R NAND SWAP R> NAND NAND ; -----
: EMIT-XOR
  fff-entry-xor EMIT-LABEL-DEF
  fff-entry-or EMIT-WORD-LABEL
  3 EMIT-BYTE-LITERAL
  88 EMIT-BYTE-LITERAL  79 EMIT-BYTE-LITERAL  82 EMIT-BYTE-LITERAL
  fff-cfa-xor EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  fff-cfa-over EMIT-WORD-LABEL
  fff-cfa-over EMIT-WORD-LABEL
  label-nand   EMIT-WORD-LABEL
  fff-cfa-dup  EMIT-WORD-LABEL
  label-tor    EMIT-WORD-LABEL
  label-nand   EMIT-WORD-LABEL
  fff-cfa-swap EMIT-WORD-LABEL
  label-rfrom  EMIT-WORD-LABEL
  label-nand   EMIT-WORD-LABEL
  label-nand   EMIT-WORD-LABEL
  label-exit   EMIT-WORD-LABEL
;

\ ----- NEGATE: : NEGATE INVERT 1 + ; -----
: EMIT-NEGATE
  fff-entry-negate EMIT-LABEL-DEF
  fff-entry-xor EMIT-WORD-LABEL
  6 EMIT-BYTE-LITERAL
  78 EMIT-BYTE-LITERAL  69 EMIT-BYTE-LITERAL
  71 EMIT-BYTE-LITERAL  65 EMIT-BYTE-LITERAL
  84 EMIT-BYTE-LITERAL  69 EMIT-BYTE-LITERAL
  fff-cfa-negate EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  fff-cfa-invert EMIT-WORD-LABEL
  label-lit      EMIT-WORD-LABEL
  1              EMIT-WORD-LITERAL
  label-plus     EMIT-WORD-LABEL
  label-exit     EMIT-WORD-LABEL
;

\ ----- MINUS: : - NEGATE + ; -----
: EMIT-MINUS
  fff-entry-minus EMIT-LABEL-DEF
  fff-entry-negate EMIT-WORD-LABEL
  1 EMIT-BYTE-LITERAL         \ namelen
  45 EMIT-BYTE-LITERAL         \ '-'
  fff-cfa-minus EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  fff-cfa-negate EMIT-WORD-LABEL
  label-plus     EMIT-WORD-LABEL
  label-exit     EMIT-WORD-LABEL
;

\ ----- COLON: : : CREATE ,DOCOL LATEST @ 3 + DUP C@ 64 OR SWAP C! ] ; -----
: EMIT-COLON
  fff-entry-colon EMIT-LABEL-DEF
  fff-entry-minus EMIT-WORD-LABEL
  1 EMIT-BYTE-LITERAL          \ namelen
  58 EMIT-BYTE-LITERAL          \ ':'
  fff-cfa-colon EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  label-create      EMIT-WORD-LABEL
  label-comma-docol EMIT-WORD-LABEL
  label-latest      EMIT-WORD-LABEL
  label-fetch       EMIT-WORD-LABEL
  label-lit         EMIT-WORD-LABEL
  3                 EMIT-WORD-LITERAL
  label-plus        EMIT-WORD-LABEL
  fff-cfa-dup       EMIT-WORD-LABEL
  label-cfetch      EMIT-WORD-LABEL
  label-lit         EMIT-WORD-LABEL
  64                EMIT-WORD-LITERAL
  fff-cfa-or        EMIT-WORD-LABEL
  fff-cfa-swap      EMIT-WORD-LABEL
  label-cstore      EMIT-WORD-LABEL
  label-rbrac       EMIT-WORD-LABEL
  label-exit        EMIT-WORD-LABEL
;

\ ----- SEMI: : ; ['] EXIT , LATEST @ 3 + DUP C@ 191 AND SWAP C! 0 STATE ! ; IMMEDIATE -----
\ IMMEDIATE: flags_len byte = 128 + namelen = 128 + 1 = 129.
\ `['] EXIT` at source-parse time pushes do_exit's CFA. In the
\ compiled body it becomes `LIT do_exit`.
: EMIT-SEMI
  fff-entry-semi EMIT-LABEL-DEF
  fff-entry-colon EMIT-WORD-LABEL
  129 EMIT-BYTE-LITERAL         \ flags_len = IMMEDIATE | 1
  59 EMIT-BYTE-LITERAL           \ ';'
  fff-cfa-semi EMIT-LABEL-DEF
  EMIT-FAR-DOCOL
  label-lit         EMIT-WORD-LABEL   \ ['] EXIT → push do_exit
  label-exit        EMIT-WORD-LABEL   \ the EXIT cfa as LIT operand
  label-comma       EMIT-WORD-LABEL   \ , — compile it
  label-latest      EMIT-WORD-LABEL
  label-fetch       EMIT-WORD-LABEL
  label-lit         EMIT-WORD-LABEL
  3                 EMIT-WORD-LITERAL
  label-plus        EMIT-WORD-LABEL
  fff-cfa-dup       EMIT-WORD-LABEL
  label-cfetch      EMIT-WORD-LABEL
  label-lit         EMIT-WORD-LABEL
  191               EMIT-WORD-LITERAL
  fff-cfa-and       EMIT-WORD-LABEL
  fff-cfa-swap      EMIT-WORD-LABEL
  label-cstore      EMIT-WORD-LABEL
  label-lit         EMIT-WORD-LABEL
  0                 EMIT-WORD-LITERAL
  label-state       EMIT-WORD-LABEL
  label-store       EMIT-WORD-LABEL
  label-exit        EMIT-WORD-LABEL
;

\ ============================================================
\ Top-level driver
\ ============================================================

: COMPILE-RUNTIME
  \ Step 008 laid down the symbol-table infrastructure
  \ (XC-REGISTER / XC-FIND / XC-INIT-SYMBOLS) but the XC-FIND
  \ walking loop needs further debugging — ran into instruction-
  \ budget timeouts during validation. Left in place for step
  \ 009 to continue. COMPILE-RUNTIME still uses the hardcoded
  \ EMIT-<NAME> helpers from steps 005/007 — they work and keep
  \ the 67-test reg-rs suite green.
  NL
  marker-begin EMIT-COUNTED NL
  EMIT-DUP
  EMIT-DROP
  EMIT-OVER
  EMIT-SWAP
  EMIT-R-AT
  EMIT-INVERT
  EMIT-AND
  EMIT-OR
  EMIT-XOR
  EMIT-NEGATE
  EMIT-MINUS
  EMIT-COLON
  EMIT-SEMI
  marker-end EMIT-COUNTED NL
;
