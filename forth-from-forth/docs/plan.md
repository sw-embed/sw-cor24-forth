# Plan — forth-from-forth (phase 4)

Phase 4 lives in the `.agentrail/` saga `phase-4-forth-from-forth`.
This file is a static per-subset cross-reference; for the
authoritative per-step state, run `agentrail status`.

## Completed

### Step 001 — design (commit e1e4044)

Wrote `docs/design.md` (initially at repo root; moved here in
step 002). Picked the Forth-hosted cross-compiler approach (not
Python, not C, not Rust); compiler emits COR24 assembler text;
shell redirection captures UART output into `kernel.s`. Explained
hashing and recommended shipping without one initially.

### Step 002 — scaffold (this commit)

Created `forth-from-forth/` as a verbatim copy of phase-3
forth-on-forthish: `kernel.s`, five `core/*.fth` tiers, four
`scripts/*.sh` scripts. Added empty-shell `compiler/xcomp.fth`
and `core/prims.fth` (populated in later steps). Wrote
phase-4-specific `docs/prd.md`, `docs/architecture.md`,
this plan, `status.md`, `kernel-sizes.md`. Moved
`docs/forth-from-forth-design.md` from repo root into
`docs/design.md`. Seeded `reg-rs/tf24a_fff_fib` from the
phase-3 baseline (identical output since the kernel and core
are byte-identical at this commit).

## Upcoming

### Step 003 — compiler MVP (runtime.fth only)

Build enough of `compiler/xcomp.fth` to emit a kernel.s whose
Forth dictionary contains only what `core/runtime.fth` defines
(10 colon defs: `DUP DROP OVER SWAP R@ INVERT AND OR XOR NEGATE
-`). Requires: PRIM: / ;PRIM for asm primitives (limited set —
just what runtime.fth needs to resolve), COLON: / ;COLON for
colon defs, numeric-literal emission via `LIT`, the shell-level
`scripts/build-kernel.sh`. Validates the pipeline end-to-end on
the smallest possible scope.

### Step 004 — boot into the image

Modify the emitted kernel.s's `_start` to bypass the UART
bootstrap entirely. Kernel reads LATEST/HERE/QUIT-CFA from
compile-time-known labels and jumps to Forth QUIT. Expect boot
to first `ok` to drop to milliseconds.

### Step 005 — compiler full core

Extend `xcomp.fth` to handle all five tiers. Key additions:
IMMEDIATE control flow (`IF:` / `THEN:` / `ELSE:` / `BEGIN:` /
`AGAIN:` / `UNTIL:` / `WHILE:` / `REPEAT:` / `DO:` / `LOOP:`),
`CONSTANT:` / `VARIABLE:`, `[']:` that emits `LIT <cfa>`,
`STR=` handling (just a Forth word in highlevel.fth, should
compile the same way).

### Step 006 — pure-image boot

Strip all UART-bootstrap asm from the emitted kernel.s. At
this point `do_interpret`, `do_word`, `do_find`, `do_number`,
`do_quit_ok`, `do_quit_restart`, `tick_word_cfa`, `test_thread`,
and the hash-populate loop should all be simply not-emitted.

### Step 007 — delete-validation

Not really a "delete" step — the compiler never emits the dead
code, so there's nothing to rm. This step verifies: (a) every
primitive referenced by any Forth colon def IS emitted, (b) no
asm symbol emitted is unused. Produces a before/after line-count
diff in `kernel-sizes.md`.

### Step 008 — re-baseline reg-rs

`tf24a_fff_fib` already exists from step 002 but was captured
against the phase-3-identical kernel. After step 006 the kernel
output should still produce the same fib numbers, but the " ok"
lead-up will differ (no core-load ok flood since core is in the
image). Re-baseline to capture the real post-step-006 output.

### Step 009 — phase-4 wrap

Final docs pass: `kernel-sizes.md` with real numbers,
`status.md` marked complete, root `CHANGES.md` entry,
`README.md` updated if it mentions the three tracks.
