# Design — forth-from-forth (phase 4)

Status: drafted at step 001-design of saga phase-4-forth-from-forth.
Written before `forth-from-forth/` exists; step 002-scaffold will
move this file into `forth-from-forth/docs/design.md`.

## What we're bootstrapping

Phase 3 (`forth-on-forthish`) gave us a Forth that runs on a
hand-written COR24 assembler kernel. Phase 4 closes the bootstrap
loop: write a Forth-to-assembler cross-compiler **in Forth**, run
it on the phase-3 Forth, and let it emit the next kernel's `.s`
source. After phase 4, `forth-from-forth/kernel.s` is a build
artifact — not a hand-edited file.

The cross-compiler targets **COR24 assembler text** (the same
syntax `forth-on-forthish/kernel.s` uses today: `.byte`, `.word`,
labels, opcodes). We are **not** emitting machine code. The cor24
assembler (`cor24-run --assemble` or `--run`) turns that text into
bytes, same as before.

No Python, no C, no Rust. The toolchain is:

- `forth-on-forthish/kernel.s` — phase-3 Forth REPL, unchanged
- `cor24-run` — COR24 assembler and emulator
- Shell (`cat`, pipes, redirection) — stitch inputs and capture UART
- The cross-compiler itself — a `.fth` source file loaded into the
  phase-3 REPL

## The compilation model

```
   cross-compiler.fth  +  core/*.fth  +  a "compile all" command
             │
             ▼
   cor24-run --run forth-on-forthish/kernel.s --terminal
             │ (phase-3 Forth loads the compiler and the core, runs COMPILE-KERNEL)
             │
             ▼
   UART output: a stream of COR24 assembler source text
             │
             ▼
   trivial stream filter (strips REPL "ok" chrome between markers)
             │
             ▼
   forth-from-forth/kernel.s   (a build artifact)
```

Reading the stream out and writing to a file uses only shell
redirection:

```bash
{
  cat forth-from-forth/compiler/xcomp.fth
  cat forth-on-forthish/core/*.fth
  echo 'COMPILE-KERNEL'
} | cor24-run --run forth-on-forthish/kernel.s --terminal \
  | sed -n '/^!!BEGIN-KERNEL!!$/,/^!!END-KERNEL!!$/p' \
  | sed '1d;$d' \
  > forth-from-forth/kernel.s
```

The `!!BEGIN-KERNEL!!` / `!!END-KERNEL!!` markers are `EMIT`ted
by the compiler so the filter knows where the kernel text starts
and ends. Everything else on UART (" ok" lines, diagnostic notes)
is discarded.

## What the cross-compiler is

`xcomp.fth` is a Forth source file that defines an alternate
compilation vocabulary. When loaded into the phase-3 REPL, it adds
words like `PRIM:`, `COLON:`, `;COLON`, `VARIABLE:`, `CONSTANT:`,
`IF:` / `THEN:` / `BEGIN:` / `AGAIN:` / `UNTIL:`. These words
**do not execute at target time**. Their job at host time is to
`EMIT` COR24 assembler bytes.

### The key idea: the compiler reads the same `core/*.fth` files the
phase-3 kernel reads. But instead of *defining* words into the
phase-3 dictionary via `:`/`;`/`CREATE`, the compiler *emits dict
entries as assembler text* via `EMIT`. It models a simulated
target dict internally (name → label, offsets, flags) so later
tokens resolve to the correct emitted labels.

Two modes of source processing:

1. **Primitives file** (new, written by hand): `core/prims.fth`
   describes each asm primitive using `PRIM:` declarations. Each
   declaration bundles (a) the primitive's name, (b) the sequence
   of COR24 opcode mnemonics that form its body. The compiler emits
   one labelled asm block per `PRIM:`.

2. **Forth source files** (reused verbatim from phase 3):
   `core/runtime.fth`, `minimal.fth`, `lowlevel.fth`, `midlevel.fth`,
   `highlevel.fth`. The compiler reads these through the same `WORD`
   stream the phase-3 REPL uses, but with `:` / `;` / control-flow
   IMMEDIATEs remapped so they emit target-side assembler instead of
   executing target-side code.

### Sketch of key compiler words

```forth
\ Target-side symbol table: a parallel dict held in Forth variables,
\ mapping target word names to emitted label names and flags. Used
\ to resolve cross-references when compiling later defs.

VARIABLE  xc-here          \ simulated target HERE (bytes emitted so far)
VARIABLE  xc-latest        \ simulated target LATEST entry label

\ Emit a labelled primitive. Body is the literal asm text between
\ `PRIM:` and `;PRIM`. The compiler prefixes a dict header and the
\ label, appends a trailing NEXT inline, and updates xc-latest.
: PRIM:    ( "name" "body..." -- )  ... ;
: ;PRIM    ( -- )  ... ;

\ Start a colon-def: emit the header + far-DOCOL CFA prelude.
: COLON:   ( "name" -- )  ... ;
\ Compile a subsequent token as a reference to its target CFA.
\ Called internally by COLON:'s body loop for each non-IMMEDIATE token.
: xc-compile-word  ( c-addr -- ) ... ;
\ End a colon-def: emit do_exit label, close the entry.
: ;COLON   ( -- )  ... ; IMMEDIATE

\ Control flow. IF: emits a 0BRANCH placeholder and stashes a patch
\ address on the compile stack. THEN: back-patches it.
: IF:      ... ; IMMEDIATE
: THEN:    ... ; IMMEDIATE
: ELSE:    ... ; IMMEDIATE
: BEGIN:   ... ; IMMEDIATE
: AGAIN:   ... ; IMMEDIATE
: UNTIL:   ... ; IMMEDIATE
: WHILE:   ... ; IMMEDIATE
: REPEAT:  ... ; IMMEDIATE

\ Numeric literals. When the interpretation of a token produces a
\ number (per standard NUMBER rules), emit `LIT` + the literal bytes.
: xc-compile-literal ( n -- ) ... ;

\ Top-level driver. Reads the pre-prepared sources and emits the
\ complete kernel.s to UART, wrapped in !!BEGIN-KERNEL!! markers.
: COMPILE-KERNEL ( -- )
  32 EMIT  \ debug...
  S" !!BEGIN-KERNEL!!" TYPE CR
  emit-asm-preamble
  emit-asm-primitives       \ walks PRIM: declarations
  emit-asm-boot
  emit-asm-dict             \ walks COLON: / VARIABLE: / CONSTANT: defs
  emit-asm-variables
  emit-asm-epilogue
  S" !!END-KERNEL!!" TYPE CR
;
```

Numbers in the sketch are illustrative; the real implementation
grows step by step over saga steps 003 (runtime only) through 005
(full core including IMMEDIATEs).

## Output structure

The emitted `kernel.s`:

```asm
; Generated by forth-from-forth. Do not edit.
_start:
    la r1, 983040
    ; snapshot initial sp
    mov fp, sp
    push fp
    pop r0
    la r2, var_sp_base
    sw r0, 0(r2)
    ; Install Forth QUIT's CFA in the vector (label known at
    ; compile time — emitted by the COLON: that compiled QUIT).
    la r0, do_quit_forth_cfa
    la r2, var_quit_vector
    sw r0, 0(r2)
    ; Enter Forth QUIT. Never returns.
    la r0, var_quit_vector
    lw r0, 0(r0)
    jmp (r0)

; ========== ASM PRIMITIVES (emitted from PRIM: declarations) ==========
entry_emit:
    .word 0
    .byte 4
    .byte 69, 77, 73, 84
do_emit:
    pop r0
    add r1, -3
    sw r2, 0(r1)
    ...

; (many more primitives...)

; ========== FORTH DICTIONARY (emitted from COLON:/VARIABLE:/CONSTANT:) ==========
entry_dup:
    .word entry_previous       ; link
    .byte 3                    ; flags_len
    .byte 68, 85, 80           ; "DUP"
do_dup_cfa:
    .byte 125                  ; push r0
    .byte 41                   ; la opcode
    .word do_docol_far         ; la target
    .byte 38                   ; jmp (r0)
    .word do_sp_fetch          ; SP@
    .word do_fetch             ; @
    .word do_exit              ; ;
...
do_quit_forth_cfa:
    .byte 125, 41
    .word do_docol_far
    .byte 38
    ; body of Forth QUIT
    ...

; ========== RUNTIME VARIABLES ==========
var_here_val:    .word dict_end
var_latest_val:  .word entry_quit_vector    ; last emitted entry
var_state_val:   .word 0
var_base_val:    .word 10
var_sp_base:     .word 0
var_quit_vector: .word 0

dict_end:
```

No `do_interpret`. No `do_word`. No `do_find`. No `do_number`.
No `do_quit_ok`. No `do_quit_restart`. No `test_thread`. No
`_start` hash-table populate loop.

## Hashing

### What problem does hashing solve?

`FIND` is called once per token the interpreter reads. On a naive
dictionary implementation, `FIND` walks the linked LATEST chain
from newest to oldest and byte-compares each entry's name against
the search target. For a 90-word dictionary with random
first-character distribution, average walk length is ~45 entries
with ~4 chars-per-compare = ~180 byte-compares per FIND. At
~1500 FINDs during a typical boot + fib demo, that's ~270,000
byte-compares — hundreds of thousands of emulator instructions
spent purely on name matching.

Hashing accelerates FIND by partitioning the dictionary across
many short chains. With 256 buckets, the expected chain length
drops from 45 to ~0.35 (90/256). Average FIND becomes: compute
the hash (~10 instructions × name length), index the bucket
(1 load), walk a chain of 0–3 entries (byte-compare each, ~4–16
compares total). Typical FIND: ~50 instructions instead of ~180
compares.

### How hashing works in this kernel

Three cooperating pieces (from phase 3):

1. **Hash function**: compute a 24-bit integer from the name's
   bytes.
2. **Hash table**: 256 buckets, each holding a 3-byte link to the
   most-recent entry whose name hashes into that bucket.
3. **Per-entry hash chain**: every dict entry has, in addition to
   its `.word link` (newest-to-oldest chronological chain), a
   separate link to the previous entry in the same hash bucket.

`FIND` becomes: `hash(name); bucket = hash & 0xFF; entry =
hash_table[bucket]; while entry: if name matches: return; entry
= entry.hash_link;`.

At boot, the `_start` code walks the whole LATEST chain once and
populates `hash_table` by inserting each entry at the head of its
bucket. As new entries get CREATEd at runtime, CREATE must both
update LATEST and splice the new entry into the appropriate
hash bucket.

### The hash function: 2-Round XMX

Phase 3 uses 2-Round XMX per `docs/hashing-analysis.md`:

```
h = 0
for each byte c of the name:
  h = h XOR c               ; mix in the byte
  h = h * 0xDEADB5          ; 24-bit multiply (truncates natively)
  h = h XOR (h SRL 12)      ; avalanche: fold high half into low half
bucket = h AND 0xFF         ; take the low 8 bits as bucket index
```

`0xDEADB5` (decimal 14,592,437) is an odd 24-bit multiplier with
good bit-distribution characteristics. The `SRL 12` (shift-right
logical 12) is the "avalanche" step that ensures every input bit
influences every output bit after two rounds, so even 1–3-char
names (which is most Forth primitives: `@`, `!`, `+`, `DUP`) end
up with chaotic-looking hashes.

Why XMX wins on this ISA per the analysis:
- **Register-efficient**: uses 2 registers, we have 3 GPRs.
- **Bit-width-native**: 24-bit multiply matches COR24's word size,
  so there's no overflow-truncation waste (unlike running a 32-bit
  hash on a 24-bit machine).
- **Good avalanche on short names**: the SRL-12 fold gives short
  names the same distribution quality as long ones.

Measured collision counts on the 90-word phase-3 dictionary
across 256 buckets: 2-Round XMX = **15 collisions**, compared
to 47 for first-char hashing (the trivial baseline). Worst-bucket
depth is 3 (vs. 7 for first-char).

Per-character cost is ~10 COR24 instructions, vs. 4 for the
simpler `mult33` hash. On a 4-char name that's 24 extra
instructions per FIND. At 1500 FINDs per boot, ~36K extra
instructions — negligible compared to the ~150K saved by fewer
chain walks.

### The 1-entry lookaside cache

Phase 3 also adds a 1-entry cache sitting *in front* of the hash
lookup: `(full_24bit_hash, cfa, flag)`. When FIND is called, it
first compares the input's hash against the cached hash. If they
match and `cfa != 0`, it returns `(cfa, flag)` directly. No bucket
load, no chain walk, no name compare.

Wins on patterns like `: FOO DUP DUP DROP ... ;` where the same
word appears consecutively — common inside colon-def bodies. Loses
nothing on a miss: one extra memory load + compare.

Only positive lookups are cached. Negative lookups (word not in
dict) are skipped deliberately: if the user types `FOO` (miss,
prints "?"), then defines `: FOO ... ;`, the next `FOO` must
hit the real FIND.

### Recommendation for phase 4: ship without it

**Don't include a hash table in the first forth-from-forth kernel.**

The reasoning:

- Forth `FIND` in `core/highlevel.fth` (shipped in subset 18)
  does a straight linear walk of `LATEST`. No hash. It works
  correctly on ~90 words. Boot takes < 1 second on the emulator.
- The 256-bucket hash table in the phase-3 kernel serves **asm
  `do_find` only**. We're deleting asm `do_find` in phase 4.
  After deletion, the hash table has no callers.
- Not including the table saves ~768 bytes of storage, ~30
  instructions of `_start` populate-loop, and ~40 instructions of
  `compute_hash` primitive. And every `CREATE` no longer needs to
  update a hash chain. Smaller kernel, simpler boot, simpler
  runtime word-definition.

The XMX analysis isn't wasted. If phase-4 benchmarking ever
shows Forth `FIND` is too slow, we revisit as a follow-up
**inside Forth**: add a `HASH` primitive (or implement 2-Round
XMX in pure Forth using the primitives we keep: `XOR`, `*`, `SRL`
would need to exist as a primitive since we don't have it yet)
and a Forth-managed hash table. The algorithm is proven; the
integration changes.

Concrete "when to revisit":

- If boot-to-first `ok` exceeds 1 s wall-clock on WASM, **OR**
- If emulator instructions to boot exceed 100 M, **THEN**
- Add hash-accelerated Forth FIND. Start with 2-Round XMX.

Otherwise, leave it out. Simplicity wins over every-cycle
optimization when the kernel's already below the performance
threshold.

### If we had to ship with a hash from day one

If phase 4 is wrong about the "good enough" call and we need
hashing earlier, the **good-enough-simplest approach is first-char
hashing**:

```
bucket = name[0] AND 0x3F      ; low 6 bits of first char → 64 buckets
```

First-char hash has 47 collisions on the 90-word dict (mediocre),
but it's **one instruction** per FIND — no multiplies, no shifts,
no loop. Performance improvement over linear walk is still 2-3×,
even with the clustering problem. And it's trivial to implement
in Forth (no need for a new primitive).

Only if first-char proves inadequate should we escalate to
2-Round XMX. That order — linear → first-char → XMX — matches
actual cost/benefit, not speculative engineering.

## Boot handoff

`_start` in the emitted kernel:

1. Set RSP (`la r1, 983040`).
2. Snapshot initial `sp` into `var_sp_base`.
3. Install Forth QUIT's CFA in `var_quit_vector` (the compiler
   knows QUIT's label at emit time — it emitted it).
4. Jump to Forth QUIT's CFA. Never returns.

No UART read on boot. No `test_thread`. No asm INTERPRET.

LATEST and HERE get their initial values directly from the
`.word var_latest_val: .word entry_last_emitted` declaration —
the compiler emits the final dict entry's label there. HERE
starts at `dict_end` (the label after the last compiled entry).
As the user defines new Forth words at runtime, HERE and LATEST
advance into the SRAM-allocated variable-storage region, same as
phase 3.

## Portability — deferred until phase 4 is working

`docs/future.md` lists RCA1802, IBM 1130, IBM 360 as eventual
targets. The cross-compiler pattern supports them in principle —
the PRIM: declarations would use each target's mnemonics, and
COLON: / control-flow emitters would compute offsets in each
target's cell size. For phase 4 we implement the COR24 target
only. Abstracting over cell size and endianness is a later concern
and can be done as a clean refactor once the COR24 path works.

Open question: do we keep the PRIM: declarations as pure-text
asm bodies (no cross-target abstraction), or factor them into
Forth words that emit per-target opcodes? The text approach is
simpler and gets us to a working phase 4 faster. The Forth-word
approach is more elegant and portable. **Start with text**,
factor later if actually targeting a new ISA.

## examples/*.fth stay on UART

Examples (`examples/14-fib.fth` and siblings) are **not**
pre-compiled into the kernel. They load post-boot via Forth
INTERPRET as they do today. Changing an example must not require
rebuilding the kernel.

Consequence: the kernel output during boot will no longer include
the ~200 " ok" lines that used to fire for core-file loading —
the core is already compiled into the kernel, no UART processing
happens for it. Only example-file lines produce " ok" during
tests. Subset 008-rebaseline-reg-rs handles that drift.

## Unknowns flagged for later steps

1. **Interacting with the phase-3 REPL's " ok" output mid-compile.**
   The compiler runs inside a `:` def (interpret mode at the
   enclosing `COMPILE-KERNEL` call), so its EMITs go to UART
   uninterrupted. Only a single " ok" fires at the end. Simple.
   *Unless* the compiler stays in interpret-mode-at-top-level
   between declarations; then " ok" fires per line and corrupts
   the stream. Solution: wrap everything in `COMPILE-KERNEL`.

2. **Host-side stream filter.** The `sed` one-liner in the build
   command strips everything outside the BEGIN/END markers. If
   sed isn't available in CI, a tiny Forth filter or an awk
   one-liner works the same.

3. **Regeneration workflow.** Every `core/*.fth` change requires
   re-running the compiler. Step 002-scaffold adds a `scripts/
   build-kernel.sh` (a shell one-liner) so the regeneration is
   one command.

4. **Testing the emitted kernel.** `reg-rs/tf24a_fff_fib`
   exercises it end-to-end. The test command runs `scripts/
   build-kernel.sh` then `cor24-run --run forth-from-forth/
   kernel.s -u '<fib input>'`. Baseline captures fib output.

5. **Primitives still needed.** We keep all ~35 asm primitives
   currently live in `forth-on-forthish/kernel.s`. We delete
   only: `do_interpret`, `do_word`, `do_find`, `do_number`,
   `do_quit_ok`, `do_quit_restart`, `tick_word_cfa`,
   `do_drop` (internal), `test_thread`, `compute_hash`, and
   the hash-populate loop in `_start`. Step 007 does the count
   and validation.

## Size projection

- Hand-written `forth-from-forth/compiler/xcomp.fth`: ~300–500
  lines of Forth.
- Hand-written `forth-from-forth/core/prims.fth` (per-primitive
  PRIM: declarations wrapping asm text): ~400 lines.
- Generated `forth-from-forth/kernel.s`: expected ~1500–2000
  lines (asm primitives ~1200, dict bytes ~300–800, boot/vars
  ~50). **Target ≤ 2000; below phase-3's 2659.**
- Zero new directories of host-language code.

## Path forward

After this design step:

- **Step 002**: scaffold `forth-from-forth/` as a directory;
  move this design doc into place; copy `core/*.fth` verbatim
  from phase 3; write `scripts/build-kernel.sh`; stub
  `compiler/xcomp.fth` and `core/prims.fth` (empty shells);
  seed `reg-rs/tf24a_fff_fib`.
- **Step 003**: compiler MVP — `xcomp.fth` handles just enough
  to emit a kernel that boots to Forth QUIT with `runtime.fth`
  (10 colon defs) as its only Forth content. Prove the pipeline
  end-to-end on the smallest possible scope.
- **Steps 004–006**: extend compiler to all core tiers, include
  IMMEDIATE control-flow emitters, and switch the emitted
  kernel to pure-image boot (no asm interpreter at all).
- **Step 007**: validate that the unused asm bodies really are
  unreferenced in the emitted kernel and are therefore already
  gone — there's nothing left to "delete" because the compiler
  simply never emitted them.
- **Step 008**: re-baseline reg-rs; add `tf24a_fff_*` mirrors
  for any tests worth cross-testing.
- **Step 009**: docs wrap, CHANGES.md entry, phase-3 status
  note about supersession.
