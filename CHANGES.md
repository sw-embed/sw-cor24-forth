# Changelog

## Feature: DO/LOOP family + defining words + Forth `:`/`;` (2026-04-20)

### Added — both kernels (`forth-in-forth` and `forth-on-forthish`)

- `,DOCOL` primitive: emits the 6-byte far-CFA template at `HERE`,
  exposing the colon-def header machinery to Forth-level code.
- `AGAIN`, `WHILE`, `REPEAT` in `core/minimal.fth` (built on
  `0BRANCH`/`BRANCH`, no new primitives).
- `CONSTANT`, `VARIABLE` in `core/lowlevel.fth` (layered on
  `CREATE` + `,DOCOL` + `LIT`, no `DOES>` yet).
- Counted loops: `(DO)`/`(LOOP)`/`(?DO)`/`I`/`UNLOOP` kernel
  primitives plus IMMEDIATE `DO`/`LOOP`/`?DO` compilers in
  `core/lowlevel.fth`. RS layout inside a loop body is
  `[index][limit][caller-IP]`; `UNLOOP` must precede `EXIT`.
- `LIT` unhidden (flag byte 67→3) so Forth code can compile
  `['] LIT` references.
- Demos: `examples/15-again.fth`, `16-while.fth`, `17-constant.fth`,
  `18-variable.fth`, `19-do-loop.fth`.

### Added — `forth-on-forthish` (phase 3 subset 13)

- Forth-defined `:` and `;` in new `core/runtime.fth` tier. Asm `:`
  and `;` remain but are shadowed at Forth level. SMUDGE/HIDDEN bit
  handling added to asm `do_colon` / `do_semi` so the in-progress
  entry is invisible to `FIND` until `;` runs.

### Fixed

- FIND performance — hash-indexed FIND with 1-entry lookaside cache
  (issue #1). 8-bucket XMX hash (see `docs/hashing-analysis.md`)
  reduced worst-case chain length for the bootstrap vocabulary from
  47 entries to 11–15 depending on variant.
- `scripts/see-demo.sh` (both kernels): was calling `SEE SQUARE` /
  `SEE CUBE`, which prints only the body with no `: NAME` prefix.
  Swapped to `DUMP-ALL` to match the web demo (`DUMP_ALL_SRC` in
  `../web-sw-cor24-forth/src/demos.rs`). Also filters bare ` ok`
  prompt lines from the output.
- `scripts/see-demo.sh` / `scripts/dump.sh`: core-load ` ok` noise
  now truncated at a visible `========` marker.

### Known issues

- `SEE-CFA` linear decompiler treats any cell equal to `do_exit`'s
  CFA as end-of-body, so words that compile `['] EXIT` (e.g. Forth
  `CONSTANT`, `;`) show truncated bodies in `DUMP-ALL` output
  (issue #4).
- Issue #3 tracks remaining follow-up words: `+LOOP`, `J`, `LEAVE`,
  `DOES>`, `RECURSE`, `PICK`/`ROLL`/`?DUP`/`MIN`/`MAX`/`<=`/`>=`/`<>`.

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
