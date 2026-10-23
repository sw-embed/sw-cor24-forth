Drive core/runtime.fth through the source-driven parser instead of the hand-listed COMPILE-RUNTIME.

Today compiler/xcomp.fth emits the runtime tier from an explicit per-word list (steps 005-007 of the archived saga). Replace that with: xcomp reads runtime.fth's text token by token (XC-COMPILE-ENTRY per colon definition, fixed in step 1), resolves each token against the symbol table (primitives from core/prims.fth declarations, earlier colon defs by dynamic label), and emits LIT for numeric literals.

Done when: (a) scripts/build-kernel.sh produces compiler/out/runtime-dict.s from runtime.fth source with no per-word list left in xcomp.fth; (b) the emitted dict is byte-for-byte equivalent to the current compiler/out/runtime-dict.s (label names may differ; assembled bytes must match, compare with cor24-asm output); (c) compiler/out/runtime-selftest.s still passes; (d) a reg-rs test locks the self-test output; (e) compiler/README.md describes the real pipeline.
