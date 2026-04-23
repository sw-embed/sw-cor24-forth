# Kernel size tracking — forth-from-forth

One row per committed phase-4 step. `kernel.s` is the generated
asm source (or, at step 002, a verbatim phase-3 copy). `assembled
bytes` comes from `cor24-run --assemble` output. Core tier totals
sum Forth source lines across the five `.fth` files plus
`core/prims.fth`.

| Commit | Step | kernel.s lines | Δ kernel.s | assembled bytes | compiler lines | prims.fth | core tier | Notes |
|--------|------|---------------:|-----------:|----------------:|---------------:|----------:|----------:|-------|
| *current* | **002 scaffold** | 2659 | — | — | 1 (stub) | 1 (stub) | 450 | Verbatim copy of phase-3 forth-on-forthish. No cross-compiler yet; kernel identical to phase 3. Baseline row. |

## Expectations for upcoming steps

These are pre-coding estimates and will be edited down to
actuals as each step lands.

| Step | kernel.s | assembled | Notes |
|------|---------:|----------:|-------|
| 003 compiler MVP (runtime only) | 2659 | ~4000 | Kernel still identical; step 003 builds the compiler but doesn't regenerate kernel.s yet. First end-to-end build happens at step 004. |
| 004 runtime-image boot | ~2500 | ~4000 | Emit a kernel where runtime.fth is pre-compiled into the image; asm bootstrap still loads minimal/lowlevel/mid/high from UART. Minor shrink from skipping runtime.fth parsing. |
| 005 compiler full core | 2659 | — | Compiler reaches feature-complete, but kernel.s still a verbatim phase-3 copy; step 006 flips the switch. |
| 006 pure-image boot | ~1600–1900 | ~3000 | Delete asm do_interpret (~200), do_word (~140), do_find (~250), do_number (~190), do_quit_ok + do_quit_restart (~75), tick_word_cfa (~15), compute_hash + hash-populate (~70). All simply not emitted. |
| 007 delete-validation | ~1600–1900 | same | Verification pass; no structural change. |
| 009 phase-4 wrap | same | same | Docs only. |

## Success target

Kernel.s ≤ 2000 lines, assembled ≤ 3000 bytes, zero asm
bootstrap interpreter code in the emitted file. Core Forth
tier byte-identical to phase 3 — no changes to the 450 lines
of user-visible Forth.
