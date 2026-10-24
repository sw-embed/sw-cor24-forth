\ xcomp.fth — forth-from-forth cross-compiler
\
\ Reads target Forth source (core/*.fth) and emits COR24 assembler
\ text: one dictionary entry per colon definition, threaded bodies
\ resolved against the primitive registry in core/prims.fth. The
\ driver is XC-COMPILE-SOURCE at the end of this file.
\
\ Runs inside the phase-3 forth-on-forthish REPL. Emits to UART;
\ scripts/build-kernel.sh keeps the text between the begin/end
\ markers and writes it to compiler/out/runtime-dict.s.
\
\ Never write a backslash followed by n, r, t, x or 0 in this file,
\ even in a comment: cor24-emu -u turns them into control bytes.
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
  \ -8388608 (0x800000) negates to itself, so the digit loop below
  \ cannot print it. It is the bit pattern behind every 0< test.
  DUP 8388608 = IF DROP 45 EMIT 56 EMIT 51 EMIT 56 EMIT 56 EMIT 54 EMIT 48 EMIT 56 EMIT EXIT THEN
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
\ Labels the compiler emits itself
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

\ ============================================================
\ Symbol table: source name -> asm label
\ ============================================================
\ Each entry is 9 bytes: [prev:3][name-ptr:3][label-ptr:3].
\ `name-ptr` and `label-ptr` are counted-string addresses.
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
\ Decimal digits into a label
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

\ Counter for unique labels (fff_c<n>_<NAME>, fff_e<n>_<NAME>).
VARIABLE xc-counter
0 xc-counter !

\ ============================================================
\ Token-emit dispatch
\ ============================================================
\ ?DUP ( x -- x x | 0 ) — dup if non-zero. Not in phase-3 Forth.
: ?DUP  DUP IF DUP THEN ;

\ ============================================================
\ Def emission helpers
\ ============================================================

\ Each dict entry is: header (link, flags_len, name bytes) +
\ far-DOCOL prelude + threaded body + do_exit.

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

\ ============================================================
\ Source-reading helpers
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
\ kind 0 = .word <label>, 1 = LIT <n>, 2 = unresolved token,
\ 3 = .word <n> (a branch offset). xc-body-cells counts the cells
\ the body will occupy in the target, so branch offsets can be
\ computed: kinds 0 and 3 take one cell, LIT two, unresolved none.
VARIABLE xc-body
HERE @ xc-body !  HERE @ 3000 + HERE !
VARIABLE xc-body-end
VARIABLE xc-body-cells
: XC-BODY-RESET  xc-body @ xc-body-end !  0 xc-body-cells ! ;
: XC-KIND-CELLS  ( kind -- n )
  DUP 1 = IF DROP 2 EXIT THEN  2 = IF 0 EXIT THEN  1 ;
: XC-BODY,  ( value kind -- )
  DUP XC-KIND-CELLS xc-body-cells @ + xc-body-cells !
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

\ ---- Control flow. Lays down BRANCH / 0BRANCH and an offset cell,
\ as core/minimal.fth's IMMEDIATE words do at runtime: offset =
\ target - address of the offset cell, in bytes (3 per cell). The
\ open IF/WHILE/BEGIN positions live on the data stack while the
\ body is collected, exactly as in a running Forth:
\   IF/ELSE/WHILE leave ( slot idx ): buffer slot + cell index of
\   the offset cell to patch; BEGIN leaves ( idx ) of its target.
XC-LIT-STR do_branch   CONSTANT label-branch
XC-LIT-STR do_zbranch  CONSTANT label-zbranch
XC-LIT-STR IF      CONSTANT tok-if
XC-LIT-STR ELSE    CONSTANT tok-else
XC-LIT-STR THEN    CONSTANT tok-then
XC-LIT-STR BEGIN   CONSTANT tok-begin
XC-LIT-STR UNTIL   CONSTANT tok-until
XC-LIT-STR AGAIN   CONSTANT tok-again
XC-LIT-STR WHILE   CONSTANT tok-while
XC-LIT-STR REPEAT  CONSTANT tok-repeat
XC-LIT-STR RECURSE CONSTANT tok-recurse

\ CFA label of the definition being compiled (for RECURSE).
VARIABLE xc-current-cfa   0 xc-current-cfa !

: XC-HERE-CELL  ( -- idx )  xc-body-cells @ ;
: XC-OFFSET  ( target idx -- bytes )  - DUP DUP + + ;
: XC-PLACEHOLDER  ( -- slot idx )  xc-body-end @ XC-HERE-CELL  0 3 XC-BODY, ;
: XC-RESOLVE-FWD  ( slot idx -- )  XC-HERE-CELL SWAP XC-OFFSET  SWAP 3 + ! ;
: XC-BACK,  ( target-idx -- )  XC-HERE-CELL XC-OFFSET 3 XC-BODY, ;

: XC-IF      label-zbranch 0 XC-BODY, XC-PLACEHOLDER ;
: XC-THEN    XC-RESOLVE-FWD ;
: XC-ELSE    label-branch 0 XC-BODY, XC-PLACEHOLDER >R >R XC-RESOLVE-FWD R> R> ;   \ not 2SWAP: see core lowlevel.fth
: XC-BEGIN   XC-HERE-CELL ;
: XC-UNTIL   label-zbranch 0 XC-BODY, XC-BACK, ;
: XC-AGAIN   label-branch 0 XC-BODY, XC-BACK, ;
: XC-WHILE   label-zbranch 0 XC-BODY, XC-PLACEHOLDER ROT ;
: XC-REPEAT  label-branch 0 XC-BODY, XC-BACK, XC-RESOLVE-FWD ;

\ XC-CONTROL ( ... counted -- ... flag )  compile a control word;
\ false (token left alone) if it is not one.
: XC-CONTROL
  DUP tok-if     XC-SAME? IF DROP XC-IF     -1 EXIT THEN
  DUP tok-then   XC-SAME? IF DROP XC-THEN   -1 EXIT THEN
  DUP tok-else   XC-SAME? IF DROP XC-ELSE   -1 EXIT THEN
  DUP tok-begin  XC-SAME? IF DROP XC-BEGIN  -1 EXIT THEN
  DUP tok-until  XC-SAME? IF DROP XC-UNTIL  -1 EXIT THEN
  DUP tok-again  XC-SAME? IF DROP XC-AGAIN  -1 EXIT THEN
  DUP tok-while  XC-SAME? IF DROP XC-WHILE  -1 EXIT THEN
  DUP tok-repeat XC-SAME? IF DROP XC-REPEAT -1 EXIT THEN
  DUP tok-recurse XC-SAME? IF DROP xc-current-cfa @ 0 XC-BODY, -1 EXIT THEN
  0
;

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
      XC-CONTROL 0= IF XC-RESOLVE XC-BODY, THEN
    THEN THEN THEN
  AGAIN
;

\ XC-EMIT-BODY ( -- )  write the buffered body as asm text.
: XC-EMIT-BODY
  xc-body @
  BEGIN DUP xc-body-end @ < WHILE
    DUP 3 + @  OVER @            \ addr value kind
    DUP 0= IF DROP EMIT-WORD-LABEL ELSE
    DUP 1 = IF DROP label-lit EMIT-WORD-LABEL EMIT-WORD-LITERAL ELSE
    3 = IF EMIT-WORD-LITERAL ELSE
      59 EMIT 32 EMIT 63 EMIT 32 EMIT EMIT-COUNTED NL   \ "; ? tok"
    THEN THEN THEN
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
  DUP xc-current-cfa !
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
