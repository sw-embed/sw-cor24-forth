# Saga: phase-4-tab-4 — finish forth-from-forth and show it

Goal: the fourth COR24 Forth kernel, `forth-from-forth/`, boots from a
dictionary image emitted by a cross-compiler written in Forth, with no
UART bootstrap and none of the asm WORD/FIND/NUMBER/INTERPRET bodies.
Then show it three ways: a fourth tab in web-sw-cor24-forth, a brief
for the blog agent, and the "Forth on COR24" deck updated to four tabs.

Starting point (2026-10-23): previous saga `phase-4-forth-from-forth`
(archived) got the compiler to emit the runtime.fth tier and a passing
self-test, but the source-driven parser fails when XC-COMPILE-ENTRY is
reached through XC-COMPILE-TEST (see
forth-from-forth/docs/parser-debug-notes.md). kernel.s is still a
byte-identical copy of forth-on-forthish. Steps 016-020 of the old saga
were never started; this saga supersedes them.

Repositories: kernel work in sw-cor24-forth (this repo). Step 6 works in
../web-sw-cor24-forth. Step 8 edits docs/presentation/ here.

Constraints:
- forth.s and the physical-board build must not change.
- forth-on-forthish stays as it is; forth-from-forth is a new kernel.
- The emitted kernel must keep the UART poll-loop labels the web pump
  recognises (key_poll at minimum; see web-sw-cor24-forth/src/pump.rs
  POLL_LABELS) or tab 4 will never feed input.
- Every step: reg-rs suite green (REG_RS_DATA_DIR=$PWD/reg-rs reg-rs run -p tf24a --parallel),
  stack-leak check on any new word, commit before `agentrail complete`.

Steps:
1. parser-integration-fix
2. compile-runtime-from-source
3. compile-full-core
4. prims-and-image-boot
5. delete-bootstrap-and-rebaseline
6. web-tab-4 (web-sw-cor24-forth)
7. blog-brief
8. deck-update
