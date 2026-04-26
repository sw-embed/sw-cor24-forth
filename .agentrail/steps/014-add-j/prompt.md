Add J (outer-loop index for nested DO) — easy GH #3 win as a
1-line Forth def, no asm changes.

J reads the outer loop's index when called from within a nested
DO body. Phase-3 RS layout per (DO):
  - 0(r1): index    (outermost)
  - 3(r1): limit

When J is called inside an inner loop's body:
  RS top to bottom:
    J_caller_IP    ← DOCOL pushed when J was invoked (3 bytes)
    inner_index    ← from inner (DO) (3 bytes)
    inner_limit    ← from inner (DO) (3 bytes)
    outer_index    ← from outer (DO) — what J wants (3 bytes)
    outer_limit
    ...

So J reads at offset +9 from RP:

  : J RP@ 9 + @ ;

(R@ is `RP@ 3 + @` to skip its own caller IP; J skips the
caller IP plus the inner loop's index/limit.)

Test:
  : NESTED
    3 0 DO
      2 0 DO
        I . J . 32 EMIT
      LOOP
    LOOP 10 EMIT ;
  NESTED
  → "0 0 1 0 0 1 1 1 0 2 1 2 " (each pair: I J)

Apply to all three layered kernels. Add reg-rs test.

Out of scope (need real asm work):
- +LOOP: increment-by-N. Needs new (+LOOP) primitive in kernel.s
  with sign-aware comparison. Whole separate step.
- LEAVE: early-exit from DO. Needs leave-stack or back-patching
  scheme; (UNLOOP) primitive exists but LEAVE compile-time
  semantics are tricky.
- DOES>: extends CREATE'd word's behavior; needs CFA-rewriting
  primitive.

Update GH #3 with progress.
