# Changelog

## Refactor: split forth.s into a target-independent core and a hardware layer (2026-10-22)

### Changed

- `forth-core.s` holds everything that does not touch hardware; `forth-uart.s`
  is the stand-alone board layer (UART polling, return stack at 0x0F0000,
  open-ended dictionary, halting `BYE`, plain branches). `forth.s` is now
  generated from the two by `scripts/build-forth.sh` and stays checked in,
  since the web demo compiles it in by path; `--check` reports staleness.
- The 29 inline UART sites in the kernel became calls to two layer routines,
  `io_emit ( c -- )` and `io_key ( -- c )`, made through the return stack so
  no link register is needed and r1 (RSP) is never disturbed. `BYE`, `BRANCH`
  and `0BRANCH` defer to `io_bye`, `io_branch`, `io_zbranch`, giving a host
  layer a place to end a session and to yield or notice a stop request on
  loop branches. The return-stack base is read from `var_rstack_top`, which
  `layer_init` sets; `HERE` starts at the layer's `dict_start`.
- Behavior is unchanged: 73 of 73 reg-rs tests and 47 of 47 `demo.sh test`
  checks pass against the regenerated kernel. Memory layout on the stand-alone
  build is unchanged too (same return-stack base, dictionary still grows from
  the end of the image), so the web debugger's stack views still apply. The
  image is 91 bytes larger (4010 vs 3919).
- The sw-tos layer, which routes I/O through SWTOS kernel services, lives in
  the sw-tos repository as `hal/cor24/forth-swtos.s` against a vendored copy
  of the core.

## Tooling: finish the move off the combined `cor24-run` (2026-10-22)

### Changed

- The assembler (`cor24-asm`, sw-cor24-x-assembler) and the emulator
  (`cor24-emu`, sw-cor24-emulator) have been separate programs for a while,
  but 70 of the 73 reg-rs tests, `demo.sh`, `demos/*.sh`, `scripts/build.sh`
  and every `forth-*/scripts/*.sh` still invoked the deprecated combined
  `cor24-run --run`, so none of them could run. New `scripts/run-kernel.sh`
  assembles a kernel to a private temporary `.lgo` and runs `cor24-emu` on it
  with the caller's options, finding the tools on `PATH`, via
  `COR24_ASM`/`COR24_EMU`, in the sibling checkouts, or in
  `../sw-tos/tools/bin`. Every script and test command now goes through it.
- `reg-rs/` is the test data directory: run the suite from the repository
  root with `REG_RS_DATA_DIR=$PWD/reg-rs reg-rs run -p tf24a --parallel`.
- `tf24a_underflow_drop` passes `--stack-bounds none`: the current emulator
  halts on its own SP bounds check before Forth's QUIT-level underflow check
  can report, and that Forth check is what the test exists to prove.
- `tf24a_fff_selftest` rebased: the old emulator's trailing
  `CPU halted (self-branch detected)` line is not printed by `cor24-emu`.
- `demo.sh test` uses POSIX `sed` instead of the `sed-rs` binary, which was
  one more tool the suite could not find, and its expected `WORDS` listing
  now includes `:NONAME` (added to the kernel in step 010 after the
  expectation was last updated). 47 of 47 checks pass.
- Living docs (`CLAUDE.md`, `README.md`, the `forth-*/docs/architecture.md`
  files, the compiler README and design) teach the new form. Dated notes
  under `docs/` are history and keep the commands they were written with.

## Fix: `13-loop-switch-led.fth` data-stack leak + switch-toggle regression tests (2026-10-20)

### Fixed

- `examples/13-loop-switch-led.fth`: `DELAY`, `PAUSE` and `MIRROR` were
  written as `100 0 BEGIN 1 + DUP 100 = UNTIL DROP`, which leaves the
  limit literal behind on every call — two cells leaked per MIRROR
  iteration. With a 3 KB data stack the SP crossed below the EBR base
  after ~500 iterations (10–20 M instructions, a few seconds in the web
  debugger), the emulator's bounds check halted the CPU, and D2 froze —
  reported as "toggling S2 does nothing" on every web tab. The loops now
  count up from 0 with only the counter on the stack. Forth source only;
  no kernel or assembly change, so the FPGA build is unaffected.

### Added

- `reg-rs/tf24a_loop_switch_led_follow` — runs the demo under
  `cor24-emu --switch-at 6000000:on,8000000:off,10000000:on` and keeps
  only the `[S2 @ N]` / `[LED @ N]` lines: D2 must follow every toggle.
- `reg-rs/tf24a_loop_switch_led_no_leak` — runs MIRROR to completion
  then `DEPTH .`; expects `0` and no stack-overflow report (~8 s).
- Both need `cor24-asm` and `cor24-emu` (sw-cor24-x-assembler,
  sw-cor24-emulator with `--switch-at`) on PATH. The rest of the suite
  still calls `cor24-run --run`, which the current emulator no longer
  builds; those tests need the same `cor24-asm … && cor24-emu --lgo …`
  form before they can run against current tooling.

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
