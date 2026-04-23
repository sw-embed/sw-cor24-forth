\ xcomp.fth — forth-from-forth cross-compiler
\
\ Step 004a: string foundation + pipeline proof-of-concept.
\ Defines minimal string-output helpers (C, STR: TYPE COUNT) and a
\ stub COMPILE-RUNTIME that emits BEGIN/END markers with a test
\ message between them. Future steps extend COMPILE-RUNTIME to
\ emit the actual asm text for core/runtime.fth's 10 colon defs.
\
\ Runs inside the phase-3 forth-on-forthish REPL. Emits to UART;
\ shell pipeline captures via `cor24-run -u`, strips REPL " ok"
\ chrome with sed between the markers, writes output to
\ forth-from-forth/compiler/out/runtime-dict.s.
\
\ String convention: Pascal-style counted strings (length byte,
\ then chars). Matches the phase-3 dict-name format.

\ --- C, ( c -- ) : append byte at HERE, advance HERE.
: C,  HERE @ C!  HERE @ 1 + HERE ! ;

\ --- STR: ( "name" -- ) : define a word that, when invoked, pushes
\ the address of the counted-string bytes that follow in the dict.
\ Pattern: CREATE + ,DOCOL + LIT + <addr-of-where-bytes-will-go>
\ + EXIT. The HERE@9+ captures the post-body offset at definition
\ time so the compiled LIT loads exactly the address of the first
\ user-appended byte.
: STR:  CREATE ,DOCOL HERE @ 9 + LIT LIT , , LIT EXIT , ;

\ --- COUNT ( c-addr -- c-addr+1 u ) : unwrap counted to addr/len.
: COUNT  DUP 1 + SWAP C@ ;

\ --- TYPE ( c-addr u -- ) : emit u chars from c-addr, no trailing.
: TYPE
  BEGIN
    DUP 0= IF 2DROP EXIT THEN
    SWAP DUP C@ EMIT 1 + SWAP 1 -
    0
  UNTIL
;

\ --- EMIT-COUNTED ( c-addr -- ) : print a counted string.
: EMIT-COUNTED  COUNT TYPE ;

\ --- NL : newline.
: NL  10 EMIT ;

\ --- Marker strings (counted) and test payload ---
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

\ "hello from xcomp" — 16 chars, test payload.
STR: greeting
  16 C,
  104 C, 101 C, 108 C, 108 C, 111 C, 32 C,
  102 C, 114 C, 111 C, 109 C, 32 C,
  120 C, 99 C, 111 C, 109 C, 112 C,

\ --- top-level compilation driver ---
\ Emits a BEGIN marker, a test payload, an END marker, each on its
\ own line. Later steps replace the payload with the real asm.

: COMPILE-RUNTIME
  NL
  marker-begin EMIT-COUNTED NL
  greeting     EMIT-COUNTED NL
  marker-end   EMIT-COUNTED NL
;
