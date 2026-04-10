# Changelog

## Fix: Dictionary Chain + Test Coverage (2026-04-10)

### Fixed

- Dictionary chain broken by `entry_ver` linking to `entry_begin` instead of
  `entry_until`, causing UNTIL and BYE to be unreachable from FIND/WORDS.
  Root cause: commit a4fa7c9 added VER to the dictionary but skipped two
  entries in the link chain. Fix: changed entry_ver link to entry_until.
- Demo scripts `demos/if-else.sh` and `demos/loop.sh` used `tail -n +5` to
  skip boot messages that were removed by the silent startup change; updated
  to `tail -n +3`.
- `demo.sh` WORDS expected string was missing UNTIL.

### Added

- Regression tests: `tf24a_if_true`, `tf24a_if_false`, `tf24a_if_else`,
  `tf24a_begin_until`, `tf24a_ver` (5 new reg-rs tests, 55 total).
- `demo.sh` tests for IF true/false, IF/ELSE true/false, BEGIN/UNTIL, VER
  (6 new checks, 45 total).

## Bug Fix: Comment Words (2026-04-10)

### Fixed

- `\` (backslash line comment) and `(` (paren comment) hung when executed
  via `cor24-run -u` or any UART input. Root cause: the RX polling spin
  loops in `do_backslash` and `do_paren` branched to a label after the
  UART base address reload, so `r0` was clobbered from `0xFF0100` to `1`
  on the second iteration, causing reads from address 2 instead of the
  UART status register. Fix: branch to `backslash_loop`/`paren_loop`
  (which reload `r0`) instead of `backslash_rx`/`paren_rx`.
- Rebased `tf24a_words_no_leak` regression test baseline to include
  THEN, IF, `\`, `(` in WORDS output.

## Fork Migration (2026-03-30)

Forked from [sw-vibe-coding/tf24a](https://github.com/sw-vibe-coding/tf24a)
to [sw-embed/sw-cor24-forth](https://github.com/sw-embed/sw-cor24-forth)
as part of the COR24 ecosystem consolidation.

### Changes

- Renamed project references from `tf24a` to `sw-cor24-forth`
- Updated README.md with ecosystem links and provenance
- Updated CLAUDE.md — removed legacy agentrail protocol, added provenance
- Added `scripts/build.sh` for unified build/test entry point
- Removed legacy `.agentrail/` session data and `.claude/` settings
- Updated `demo.sh` banner messages
- Updated `forth.s` header comment
