Delete the dead asm bootstrap interpreter code from
`forth-from-forth/kernel.s`.

Deletions (expected line counts from phase 3 baseline):
- `do_interpret` + all its i_* helper labels and threads (~200 lines)
- `do_word` body (~140 lines) + `entry_word_buffer` / `entry_eol_flag`
  reassessment (keep if still used by Forth WORD)
- `do_find` body (~250 lines) + hash table update code that's no
  longer needed if image ships with pre-populated hash table
- `do_number` body (~190 lines)
- `tick_word_cfa` (~15 lines) — `[']` was a Forth colon def from
  subset 20, but the asm version was never deleted; delete it now
- `do_quit_ok`, `do_quit_restart`, `quit_thread` (~75 lines) —
  the asm outer-loop; with pure image boot these are unreferenced
- `do_drop` internal body — kept for phase-3 `[']`; now dead

Expected kernel.s line count after this step: ≤ 1000 (target),
≤ 1200 (acceptable).

Before deletion, verify with `grep -n <symbol>` that each target
has zero remaining references. If something still references a
symbol we intended to delete, investigate and document before
proceeding — do not force-delete.

Update dict chain pointers where dict entries disappear. The
LATEST init target probably changes.

All 65 reg-rs tests must still pass. Re-baseline `tf24a_fff_fib`
if legitimate output drift exists (preprocess window likely
widens as core-load " ok"s are gone).

Update `docs/kernel-sizes.md` with the big delta.
