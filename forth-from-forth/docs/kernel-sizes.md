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

## Emitted dictionary (saga phase-4-tab-4)

| Step | What the compiler emits | Definitions | asm lines | bytes | build time |
|------|-------------------------|------------:|----------:|------:|-----------:|
| 5 (2026-10-23) | all five core tiers, from source | 82 | 2410 | 5432 | ~38 s |

Bytes are the assembled size of the dictionary alone (kernel + dict minus
kernel, 4001 bytes). The kernel is still the phase-3 copy; step 6 replaces it
with emitted primitives and an image boot.

## Image boot (step 6a)

`kernel.s` = primitive template + compiled core, booting into the Forth
QUIT. Instructions until the first UART output for the input `7777 .`:

| Kernel | How the core arrives | First output at |
|---|---|---:|
| forth.s | all assembly | 80,000 |
| forth-from-forth | compiled into the image | 710,000 |
| forth-in-forth | 4 tiers over the UART | 87,440,000 |
| forth-on-forthish | 5 tiers over the UART | 149,560,000 |

Every example except 21-hog (never ends) and 13 (needs the switch) gives the
same output as on forth-on-forthish, except 00-smoke and 12-selftest, where
forth-on-forthish shows a stray stack cell from its bootstrap (see status.md).

## Dead code removed (step 7)

`build-image.sh` unlinks assembly entries the compiled core redefines
(`:` `;` `INTERPRET` `QUIT`, and `[']` once forth-from-forth's highlevel.fth
gained a Forth `[']`), drops the underflow handler's fallback to the asm
bootstrap, and strips every unreachable block (`scripts/dead-code.py`).

| | asm lines | assembled bytes |
|---|---:|---:|
| forth-on-forthish/kernel.s (template, primitives + bootstrap) | 2,659 | 4,001 |
| forth-from-forth/kernel.s, step 6a (template + compiled core) | 5,087 | 9,450 |
| forth-from-forth/kernel.s, step 7 (bootstrap stripped) | 4,060 | 8,168 |

Of the step-7 image, 2,427 lines are the compiled core (83 definitions);
the rest is the template's surviving primitives. Gone: the asm INTERPRET,
QUIT, NUMBER, WORD, FIND, `:`, `;`, `[']` and 81 helper blocks (1,043 lines).
Still present but unused: the FIND hash table, which CREATE maintains and
_start fills; it goes when the primitives move into core/prims.fth.

## Hash table removed (2026-10-24)

With the primitives in Forth, the unused FIND hash machinery was deleted
from `core/prims-asm.fth`: the table (768 bytes), the loop in `_start` that
filled it, the update in `CREATE`, `compute_hash` and its cells, the
lookaside cache cells. 259 lines.

| forth-from-forth/kernel.s | lines | bytes |
|---|---:|---:|
| before | 3,917 | 8,168 |
| after | 3,508 | 7,098 |

## Real work per kernel (2026-10-24)

Instructions with every input byte handed over as soon as the kernel polls
for it (web-sw-cor24-forth `tests/boot_cost.rs`, 50-instruction batches):

| Kernel | Boot to the prompt | `7777 .` |
|---|---:|---:|
| forth.s | ~100 | 13,750 |
| forth-in-forth | 1,743,700 | 13,150 |
| forth-on-forthish | 10,177,150 | 638,100 |
| forth-from-forth | ~100 | 634,200 |

The "Image boot" table above measured first output under `cor24-emu -u`,
which hands over at most one input byte per 10,000-instruction batch; for
the kernels that stream their core, that pacing is most of the count.
