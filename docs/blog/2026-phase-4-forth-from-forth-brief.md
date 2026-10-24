# Blog brief: forth-from-forth ships as tab 4

Input for the blog-writing agent. Facts, numbers, sources and excerpts only;
the agent supplies voice and structure. Everything here is checkable in
`sw-embed/sw-cor24-forth` and `sw-embed/web-sw-cor24-forth` at the commits
cited. Written 2026-10-24.

## 1. Thesis

The fourth COR24 Forth kernel, forth-from-forth, no longer streams its core
Forth source at boot. A cross-compiler written in Forth (`compiler/xcomp.fth`)
reads the five core tiers as source and emits their dictionary as COR24
assembly; `scripts/build-image.sh` splices that dictionary into the kernel,
which boots straight into the Forth `QUIT`. The assembly bootstrap
interpreter that phases 2 and 3 could not get rid of is gone from the image.
Since 2026-10-24 the primitives are Forth too: `core/prims-asm.fth`
writes them in a small COR24 assembler vocabulary (`r0 r2 add,`), so the
generated kernel.s has no assembly template behind it. That vocabulary
prints assembler text that cor24-asm still assembles; there is no Forth
instruction encoder yet.

## 2. Numbers

All measured on the COR24 emulator (`cor24-emu`), not estimated.

Instructions until the first UART output, for the input `7777 .`
(source: `forth-from-forth/docs/kernel-sizes.md`, "Image boot"):

| Kernel | How the core arrives | First output at |
|---|---|---:|
| forth.s | all assembly | 80,000 |
| forth-from-forth | compiled into the image | 710,000 |
| forth-in-forth | 4 tiers over the UART | 87,440,000 |
| forth-on-forthish | 5 tiers over the UART | 149,560,000 |

In the web app, through the same UART pump the browser uses: tab 4 is ready
after 1 pump tick, tab 3 after 74 (`web-sw-cor24-forth/tests/led_switch_demo.rs`,
`image_kernel_boots_far_faster_than_streaming_the_core`).

Sizes (source: `kernel-sizes.md`, "Dead code removed (step 7)"):

| | asm lines | assembled bytes |
|---|---:|---:|
| forth-on-forthish/kernel.s (primitives + bootstrap) | 2,659 | 4,001 |
| forth-from-forth/kernel.s, image with bootstrap still in | 5,087 | 9,450 |
| forth-from-forth/kernel.s, bootstrap stripped | 4,060 | 8,168 |

- Compiled core: 83 definitions (82 from the shared tiers plus a Forth
  `[']`), 2,427 lines of emitted assembly. The compiled dictionary alone
  assembles to about 5.4 KB.
- Hand-written source: `xcomp.fth` 495 lines of Forth; `core/prims.fth`
  40 lines (one `PRIM: name label` line per primitive, 32 primitives);
  `scripts/build-image.sh` 124 lines; `scripts/dead-code.py` 61 lines.
- Build: compiling the five tiers takes about 38 s of wall time (the
  compiler itself runs on the phase-3 kernel inside the emulator).
- Removed by the reachability pass: 85 blocks, 1,043 lines, including the
  assembly `INTERPRET`, `QUIT`, `NUMBER`, `WORD`, `FIND`, `:`, `;` and `[']`.
- Tests: 91 golden-output tests (reg-rs) in sw-cor24-forth, all passing;
  6 headless kernel/demo tests in the web app covering all four kernels.

Earlier figures for context (from the April posts and status docs):
Fibonacci needs ~40 M instructions on forth.s, ~120 M on forth-in-forth and
an 800 M budget on forth-on-forthish.

## 3. What the April posts predicted versus what happened

Posts: Embedded #3 (2026-04-20) and Down the Rabbit-Hole parts 2-5
(2026-04-23 to 04-26) on blog.softwarewrighter.com.

- **Embedded #3 estimated 2-3 weeks from phase 3 to phase 4.** The first
  phase-4 saga (steps 001-014, 2026-04-22 to 04-26) built the compiler for
  the runtime tier and then stalled for six months on a parser bug. The
  finishing saga ran 2026-10-23 to 10-24.
- **The April blocker was not in the compiler.** Compiling a definition from
  source died right after the begin marker. Two sessions in April could not
  find why. Cause: the phase-3 Forth `NUMBER` read the minus sign from the
  string's length byte instead of its first character, so every negative
  literal failed. `XC-READ-TOKEN` contains `-1`; that `-1` became a `?` and a
  missing stack item. The same bug had silently broken five tab-3 demos
  (CONSTANT, DO LOOP, IF THEN, IF ELSE, Self Test). Fix: commit `6e0aa5c`.
- **Part 2: "phase 4 deletes the hashing subsystem."** Mostly true. The
  assembly `FIND` that used the hash is gone from the image, because a Forth
  `[']` replaced the last assembly caller (`8ab0170`). The hash table itself
  is still there, unused: the assembly `CREATE` maintains it and `_start`
  fills it. It goes when the primitives move into Forth.
- **Part 3: replacement caches (numeric fast path, recent-hit, hot-token).**
  None were built. Boot no longer runs `FIND` over the core at all, which was
  the cost those caches targeted. Interactive `FIND` speed was not measured.
- **Part 4: dictionary compaction and specialised runtime images.** Not done.
  The image keeps every core word, including development words such as `SEE`
  and `DUMP-ALL`. The relocation problem the post described did not arise,
  because the image is assembled from text with labels, not relocated.
- **Part 5: forward references as linker-style fixups.** Not needed for the
  core: every definition is registered before its body is read, so later
  definitions and self-reference resolve by name, and the core has no
  mutual recursion. Branch offsets (`IF`, `BEGIN`, `WHILE`) are computed from
  a per-definition body buffer. The retargeting backend Part 5 proposed was
  not built.
- **`IMMEDIATE` follows `;`, but the header byte comes first.** The COR24
  assembler has no equates to patch it later, so the compiler buffers each
  body, reads one token past `;` to see whether it is `IMMEDIATE`, and only
  then emits the entry.

## 4. Code excerpts

Primitive registry, `forth-from-forth/core/prims.fth` (excerpt):

```forth
PRIM: LIT     do_lit
PRIM: @       do_fetch
PRIM: !       do_store
PRIM: +       do_plus
PRIM: NAND    do_nand
```

What the compiler emits for `: R@ RP@ 3 + @ ;` (from the generated
`forth-from-forth/kernel.s`):

```asm
fff_e5_R_64:            ; header: link, length, "R@"
.word fff_e4_SWAP
.byte 2
.byte 82
.byte 64
fff_c5_R_64:            ; push r0; la r0,do_docol_far; jmp (r0)
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_rp_fetch
.word do_lit
.word 3
.word do_plus
.word do_fetch
.word do_exit
```

Boot: `_start` points `LATEST` at the newest compiled entry, then the start
thread runs the Forth `QUIT` (from the generated kernel.s):

```asm
    la r2, fff_latest         ; LATEST init: newest compiled entry
    lw r2, 0(r2)
...
test_thread:
    .word do_lit
    .word fff_c82_QUIT
    .word do_quit_vector
    .word do_store
    .word fff_c82_QUIT
```

The one Forth definition that retired the assembly `WORD` and `FIND`:

```forth
: [']  ' ['] LIT , , ; IMMEDIATE
```

Build:

```sh
forth-from-forth/scripts/build-image.sh            # regenerate kernel.s
forth-from-forth/scripts/build-image.sh --check    # fail if it is stale
```

## 5. The web demo

- Live: https://sw-embed.github.io/web-sw-cor24-forth/ (web commit `e1f11ba`;
  footer shows build `a2caefd`). Tab 4, forth-from-forth, opens by default.
- Try: watch the status line say Ready at once (switch to tab 3 for
  contrast); `SEE IF`, `SEE QUIT`, `WORDS` (every word shown was compiled by
  the Forth cross-compiler); the Loop Switch LED demo (click S2 while it
  runs); the tab's `?` bubble.
- Also live since 2026-10-22: forth.s inside the SWTOS microkernel as a pane,
  https://swtos.softwarewrighter.com/forth/ (type `bg forth` at the shell).
  Same `forth-core.s`, different I/O layer.

## 6. Found along the way, and open items

Bugs found while building this (state as of 2026-10-24):

- Fixed: forth-on-forthish `NUMBER` and negative literals (above).
- Fixed: tab 1 in the web app would not accept input. After forth.s was split
  into `forth-core.s` + `forth-uart.s`, every UART read goes through
  `io_key_poll`, a label the web pump did not know (web `2fc2518`). A new
  test watchdog turned a silent 9-minute spin into a 60-second failure
  naming the kernel and program counter.
- Fixed: the web build replayed a boot one byte per 200,000 instructions
  (1.75 G instructions); now 46 M, Pages build 2:07 to 0:10 (web `63b3e1a`).
- Fixed in tests: six golden tests kept only the first 100-250 lines of
  output, so the Fibonacci tests never compared the Fibonacci result; and
  the emulator's default 10 s wall-clock limit truncated runs under load.
- Not fixed: `2SWAP` and `2OVER` in the layered kernels' `lowlevel.fth` are
  wrong (`1 2 3 4 2SWAP` leaves `2 1 4 3`).
- Not fixed: `.` prints -8388608 (0x800000) as `-0`.
- Not fixed: tab 3 starts each session with a stray value on its data stack,
  left by errors its assembly bootstrap prints while loading the core.

Open work:

- Done 2026-10-24: the primitives are written in a Forth assembler
  vocabulary (`core/prims-asm.fth`); kernel.s is byte-identical to the
  hand-written version it replaced. Next: drop the unused FIND hash table
  (now a Forth edit), and an instruction encoder so the image needs no
  external assembler.
- `DO ?DO LOOP` and `CONSTANT`/`VARIABLE` in the cross-compiler: deferred,
  because no core tier uses them.
- Part 5's thin second backend (one Forth source, two targets) and the
  "Forth-builder kit" from Saw #8 are still plans.

## 7. Title options and series slot

Fits as **Down the Rabbit-Hole, FORTH part 6** (it closes the arc parts 2-5
opened), or as **Embedded #4**, the follow-up to Embedded #3's
self-hosting-spectrum post.

Title options:

1. "FORTH — The Dictionary Is a Build Artifact (Part 6)"
2. "FORTH — Six Months Stuck on a Minus Sign (Part 6)"
3. "Embedded #4: forth-from-forth, the Kernel That Boots Already Compiled"
4. "FORTH — 150 Million Instructions to Zero: Compiling the Core Ahead of Time"

## Sources

- `forth-from-forth/docs/status.md`, `kernel-sizes.md`,
  `parser-debug-notes.md` ("Resolution"), `compiler/README.md`.
- sw-cor24-forth commits: `6e0aa5c` (NUMBER fix), `5d28683` (compile from
  source), `058017a` (control flow), `3339c91` (all five tiers run),
  `24968e9` (image boot), `61102b1` and `8ab0170` (bootstrap removed).
- web-sw-cor24-forth commits: `2fc2518` (tab 4, tab-1 fix, watchdog),
  `e1f11ba` (deployed pages), `63b3e1a` (build replay).
- Saga records: `.agentrail/` (phase-4-tab-4) and
  `.agentrail-archive/phase-4-forth-from-forth-*` (the April saga).
- Presentation: `docs/presentation/forth-on-cor24.pptx` (slides 9, 14, 15).
