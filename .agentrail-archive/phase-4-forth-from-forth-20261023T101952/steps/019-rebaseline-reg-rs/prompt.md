Re-baseline all `tf24a_*` reg-rs tests that touch
forth-from-forth. Specifically:
- `tf24a_fff_fib` — already the target; confirm it matches the
  post-delete kernel output.
- Add `tf24a_fff_*` counterparts for any tf24a tests that should
  exercise the forth-from-forth kernel (currently only fib has
  a _fof_ variant). Decide which existing `tf24a_*` tests should
  gain `_fff_` mirrors.
- Update `reg-rs/` repo copies to match `~/.local/reg-rs/`.
- Run `reg-rs run -p tf24a --parallel` and ensure all tests
  (original 64 tf24a_* + fof + fff) pass.

Document in `docs/status.md` the final test count and the
boot-speed improvement (if measurable).
