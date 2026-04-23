\ prims.fth — per-primitive PRIM: declarations (stub)
\
\ Hand-written Forth declarations, one per asm primitive, that
\ the cross-compiler walks to emit the asm primitive section of
\ the generated kernel.s. Each declaration bundles the primitive's
\ name, its dict-entry flags, and the asm body text.
\
\ Step 002 ships this file as a one-comment stub. Step 003 adds
\ the subset of primitives runtime.fth needs (SP@, @, NAND, +, 1,
\ DUP, ,DOCOL, etc.). Step 005 completes the full set of ~35
\ primitives.
