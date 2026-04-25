Knock out the easy half of GH #3 (More Forth words).

The issue lists: +LOOP, J, LEAVE, DOES>, RECURSE, PICK, ROLL,
?DUP, MIN, MAX, <=, >=, <>.

Easy wins (one-line Forth defs in core/lowlevel.fth or
core/highlevel.fth, no asm changes):

  : ?DUP   DUP IF DUP THEN ;
  : MIN    OVER OVER < IF DROP ELSE NIP THEN ;
  : MAX    OVER OVER < IF NIP ELSE DROP THEN ;
  : <=     1 + < ;
  : >=     1 - > ;
  : <>     = INVERT ;
  : >      SWAP < ;
  : ROLL   ( xn ... x0 n -- xn-1 ... x0 xn )
            DUP IF SWAP >R 1 - ROLL R> SWAP THEN ;

Note: PICK is already in forth-on-forthish/core/lowlevel.fth from
subset 18 — verify it's correct, lift to forth-in-forth and
forth-from-forth.

Deferred (need asm-level support; separate step):
- +LOOP — the runtime increment-by-N for DO/LOOP (different from
  (LOOP)'s +1 increment).
- J — outer-loop index when nested DO loops; needs RS access.
- LEAVE — early-exit from a DO loop; needs to patch end-of-loop.
- DOES> — runtime extension to a CREATE'd word's CFA; needs a
  primitive that rewrites the just-created CFA prelude.
- RECURSE — compile a reference to the word currently being
  defined; uses LATEST and the HIDDEN bit; might need an
  IMMEDIATE primitive.

Verify each new word with a small inline test (cor24-run -u with
input that exercises stack effects). Add reg-rs tests for the
non-trivial ones (MIN/MAX/<=/>=/ROLL).

Update the issue: comment with the words landed and what's
deferred. Don't close — keep open until the asm-level set lands
in a future step.

Apply across all three layered kernels (forth-in-forth,
forth-on-forthish, forth-from-forth) — they share core/.
Forth.s would also benefit but is a separate body of work.
