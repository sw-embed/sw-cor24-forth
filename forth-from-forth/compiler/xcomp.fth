\ xcomp.fth — forth-from-forth cross-compiler (stub)
\
\ Loaded into the phase-3 forth-on-forthish REPL. Defines an
\ alternate compilation vocabulary (PRIM:, COLON: / ;COLON,
\ VARIABLE:, CONSTANT:, IMMEDIATE control-flow emitters) whose
\ job is to EMIT COR24 assembler text to UART instead of
\ updating the phase-3 dictionary.
\
\ The top-level COMPILE-KERNEL word wraps all emitted output in
\ !!BEGIN-KERNEL!! / !!END-KERNEL!! markers so the build script
\ can strip REPL chrome with a trivial sed filter.
\
\ Step 002 ships this file as a one-comment stub. Step 003 adds
\ the MVP that handles core/runtime.fth end-to-end.
