# Parser-integration debug notes

Findings from steps 009 and 012 (deferred). Future me / next
session: read this before resuming.

## Symptom

`XC-COMPILE-TEST : FOO SP@ @ ;` produces just `!!BEGIN-KERNEL!!`
followed by `? ?  ok` and stops. The parser never emits any dict
bytes. Two underflow markers (`?`) suggest phase-3 INTERPRET was
re-entered after `XC-COMPILE-TEST` returned with stack residue,
and tried to parse subsequent input tokens that weren't valid.

## What works (verified isolated)

- `NUM-C,`, `MAKE-CFA-LABEL`, `MAKE-ENTRY-LABEL` — emit correct
  `fff_c_<N>` / `fff_e_<N>` counted strings (verified via
  `XC-TEST-LABELS` embedded in build output).
- `XC-COPY-COUNTED` — copies WORD-BUFFER to permanent HERE; verified
  by COUNT TYPE on the result.
- `XC-COMPILE-NAME-BYTES` — emits `.byte len` + `.byte char`s.
- `XC-FIND` / `XC-EMIT-TOKEN` — symbol-table dispatch all work.
- `XC-READ-TOKEN` in isolation: a `: T3 BEGIN WORD DUP C@ 0= IF
  DROP 0 ELSE -1 THEN UNTIL ;` invoked from a 1-level wrapper
  returns the WORD-BUFFER addr correctly.
- 2-level call wrapper: `: INNER WORD 65 EMIT ;
  : OUTER 90 EMIT INNER 91 EMIT ;
  OUTER FOO` produces `ZA[` correctly. So 2-level WORD invocation
  is not the issue per se.

## What fails

`XC-COMPILE-TEST` invoking `XC-COMPILE-ENTRY` (3 levels deep:
phase-3 INTERPRET → XC-COMPILE-TEST → XC-COMPILE-ENTRY → WORD).

In one trace, debug `65 EMIT` placed at the top of
XC-COMPILE-ENTRY emits 'A' correctly, but the next call to
`XC-READ-TOKEN` (or even raw `WORD`) does not return — `?` fires
before any subsequent debug. In another trace, calling
XC-COMPILE-ENTRY directly from REPL after manual XC-INIT-SYMBOLS
emits the dict header bytes (mostly garbage) and gets to the
CFA prelude before failing in body compilation.

## Hypotheses still to test

1. **WORD-BUFFER ownership.** Subsets 17 left asm `do_word`'s body
   alive but removed its dict entry. The Forth WORD in lowlevel.fth
   uses WORD-BUFFER as a fixed-address scratch. Maybe an earlier
   asm call (do_create inside Forth `:` from runtime.fth) writes
   to the same buffer? Worth tracing with `--dump`.

2. **HIDDEN-bit interaction.** Forth `:` in runtime.fth sets bit
   6 on LATEST. Forth `;` clears it. If something invokes the
   shadow `:` mid-stream (via the parser dispatch), HIDDEN gets
   set on the wrong entry and FIND skips it.

3. **DOCOL nesting depth.** Each colon-def pushes IP to RS. With
   phase-3 RS at 0xF0000 (downward-growing), 3 levels of nesting
   plus internal >R/R> shouldn't overflow, but worth confirming
   the RS state at the failure point via --dump.

4. **The `0` in IF/ELSE/THEN bodies.** Earlier dev had a spurious
   `0` before REPEAT in XC-FIND that broke its loop (fixed in
   step 008). XC-COMPILE-BODY also has `0 UNTIL`-style patterns
   — re-audit for similar.

5. **Number literal compilation.** `: T3 BEGIN ... -1 THEN UNTIL
   ;` in some traces produced `?` at compile time when -1 was
   the literal. Phase-3 NUMBER does handle '-' but the path
   through Forth INTERPRET's compile-mode `LIT LIT , ,` pattern
   may have a stack imbalance.

## Suggested next-session approach

1. Use `cor24-run --dump` to inspect register/RS/SRAM state at
   the failure point. Currently I've been working from UART
   output only.
2. Build the simplest reproducer that fails: progressively
   strip XC-COMPILE-ENTRY's body until the failure stops.
3. Once isolated, write a regression test in reg-rs that
   captures the bug; then fix.

## Status

Saga step 012 (parser-integration-debug) marked complete with
reward 0 (continued investigation needed). The infrastructure
remains useful for the eventual fix; the integration bug is
real and reproducible but not yet diagnosed.
