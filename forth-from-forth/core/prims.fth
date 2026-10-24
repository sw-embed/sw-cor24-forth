\ prims.fth — the asm primitives the cross-compiler may reference.
\
\ Each line registers a Forth name and the kernel label of its code:
\     PRIM: <forth-name> <asm-label>
\ Loaded after compiler/xcomp.fth and before the source being
\ compiled.
\
\ The primitives' code is in core/prims-asm.fth, which only
\ scripts/build-image.sh loads.

PRIM: EXIT    do_exit
PRIM: LIT     do_lit
PRIM: @       do_fetch
PRIM: !       do_store
PRIM: C@      do_cfetch
PRIM: C!      do_cstore
PRIM: +       do_plus
PRIM: NAND    do_nand
PRIM: SP@     do_sp_fetch
PRIM: SP!     do_sp_store
PRIM: RP@     do_rp_fetch
PRIM: >R      do_tor
PRIM: R>      do_rfrom
PRIM: ,       do_comma
PRIM: ,DOCOL  do_comma_docol
PRIM: CREATE  do_create
PRIM: ]       do_rbrac
PRIM: HERE    do_here
PRIM: LATEST  do_latest
PRIM: STATE   do_state
PRIM: EMIT        do_emit
PRIM: KEY         do_key
PRIM: <           do_less
PRIM: EXECUTE     do_execute
PRIM: BRANCH      do_branch
PRIM: 0BRANCH     do_zbranch
PRIM: BASE        do_base
PRIM: WORD-BUFFER do_word_buffer
PRIM: EOL-FLAG    do_eol_flag
PRIM: (DO)        do_paren_do
PRIM: (?DO)       do_paren_qdo
PRIM: (LOOP)      do_paren_loop
