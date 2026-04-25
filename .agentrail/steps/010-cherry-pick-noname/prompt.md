Cherry-pick `:NONAME` into the layered kernels.

Forth.s gained `:NONAME` in commit ff7b43d (issue #5). The
layered kernels (forth-in-forth, forth-on-forthish,
forth-from-forth) don't have it yet. Per ff7b43d's commit note,
they can have it as a 3-word Forth def in core/runtime.fth:

  : :NONAME HERE @ ,DOCOL ] ;

Stack effect: ( -- xt ). Pushes the future CFA addr (xt), writes
the 6-byte far-DOCOL prelude, enters compile mode. Standard `;`
finalizes — its existing LATEST/HIDDEN clear is a no-op on the
previous (already-unhidden) entry, so no new `;` variant is
needed.

Scope:
- Add the def to forth-in-forth/core/runtime.fth.
- Add to forth-on-forthish/core/runtime.fth.
- Add to forth-from-forth/core/runtime.fth.
- The three core/runtime.fth files are kept in sync via copies;
  the addition should land identically in all three.

Verify (in each kernel, via cor24-run):
- `:NONAME 65 EMIT 10 EMIT ; EXECUTE` produces "A\n".
- `:NONAME 5 0 < IF 78 ELSE 80 THEN EMIT 10 EMIT ; DUP EXECUTE EXECUTE`
  produces "P\nP\n" (anonymous def with control flow, reused).

No new reg-rs test required — forth.s already has tf24a_noname.
Existing reg-rs baselines may need rebasing if WORDS-style tests
include the new `:NONAME` entry.

Out of scope: adding to the asm bootstrap of forth-on-forthish or
forth-from-forth. The Forth-level def is sufficient because those
kernels' Forth `:` and `;` are themselves Forth defs in
runtime.fth — `:NONAME` at the same level fits naturally.
