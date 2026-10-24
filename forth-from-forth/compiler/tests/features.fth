\ Cross-compiler feature test: each line exercises one thing the
\ source-driven compiler must handle. Locked by
\ reg-rs/tf24a_fff_xc_compile_test.
: ONE    SP@ @ ;                 \ primitives only
: TWO    ( n -- n ) ONE 2 + ;    \ paren comment, earlier def, literal
: NEG    -1 -65280 + ;           \ negative literals
: TICK   ['] EXIT , ;            \ ['] compiles LIT <cfa>
: IMM    1 ; IMMEDIATE           \ IMMEDIATE after ;
: LOOPY  LOOPY ;                 \ a definition can name itself
: R@     RP@ 3 + @ ;             \ non-alphanumeric name mangling
: BAD    NO-SUCH-WORD ;          \ unresolved token is reported, not fatal
