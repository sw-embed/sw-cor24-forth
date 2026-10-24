# Blog brief: forth-from-forth ships as tab 4

Input for the blog-writing agent. Facts, numbers, sources and excerpts only;
the agent supplies voice and structure. Everything here is checkable in
`sw-embed/sw-cor24-forth` and `sw-embed/web-sw-cor24-forth` at the commits
cited. Written 2026-10-24.

## 1. Thesis

The fourth COR24 Forth kernel, forth-from-forth, no longer streams its core
Forth source at boot. A cross-compiler written in Forth (`compiler/xcomp.fth`)
reads the five core tiers as source and emits their dictionary as COR24
assembly, after printing the primitives from `core/prims-asm.fth`; the
resulting kernel.s boots straight into the Forth `QUIT`. The assembly bootstrap
interpreter that phases 2 and 3 could not get rid of is gone from the image.
Since 2026-10-24 the primitives are Forth too: `core/prims-asm.fth`
writes them in a small COR24 assembler vocabulary (`r0 r2 add,`), so the
generated kernel.s has no assembly template behind it. That vocabulary
prints assembler text that cor24-asm still assembles; there is no Forth
instruction encoder yet.

**Fixed point (2026-10-24).** The compiler normally runs on forth-on-forthish's
hand-written kernel. Run instead on forth-from-forth's own kernel, it
reproduces forth-from-forth's kernel.s exactly, byte for byte of the text.
The hand-written kernel was only needed to start the chain. Since then
the build runs on forth-from-forth's own kernel by default
(`forth-from-forth/scripts/build-image.sh --check`, reg-rs
`tf24a_fff_image_current`); `tf24a_fff_bootstrap_root` checks that starting
again from the hand-written kernel (`XC_HOST=forth-on-forthish/kernel.s`)
gives the same kernel.s.

## 2. Numbers

All measured on the COR24 emulator (`cor24-emu`), not estimated.

Real work, in instructions, with every input byte handed over the moment
the kernel polls for it, so time spent waiting for input is not counted
(source: `web-sw-cor24-forth/tests/boot_cost.rs`, run with
`cargo test --release --test boot_cost -- --ignored --nocapture`; counts
are within 50 instructions):

| Kernel | Boot to the prompt | then the line `7777 .` |
|---|---:|---:|
| forth.s | ~100 | 13,750 |
| forth-in-forth | 1,743,700 | 13,150 |
| forth-on-forthish | 10,177,150 | 638,100 |
| forth-from-forth | ~100 | 634,200 |

Why each tab costs more than the last, and where tab 4's time goes:

- Boot: tabs 2 and 3 compile their core from text at every start (4 and 5
  tiers); tab 4 starts with it compiled, so boot is just `_start`.
- Per line: tabs 3 and 4 run the same Forth, where `FIND` is a Forth walk
  of the whole dictionary chain (~127 entries, Forth string compare) and
  `/MOD` is a Forth repeated-subtraction loop (COR24 has no divide). A
  number is first looked up and fails: about 140,000 instructions for `7`.
  Printing 7777 with `.` takes about 860 trips round the `/MOD` loop:
  about 475,000 of the 634,200. Tab 2 still has the hashed assembly `FIND`
  and an assembly `/MOD`, hence 13,150.

Earlier drafts quoted instructions to first output under `cor24-emu -u`
(80 k, 0.71 M, 87 M, 150 M). Those are dominated by the emulator's input
pacing: it hands over at most one byte per 10,000-instruction batch. Tab
3's core is 14,924 bytes (x 10,000 = 149.2 M, measured 149.56 M) and tab
2's 8,748 (87.5 M, measured 87.44 M): those figures were almost entirely
waiting for input.

In the web app, through the same UART pump the browser uses: tab 4 is ready
after 1 pump tick, tab 3 after 74 (`web-sw-cor24-forth/tests/led_switch_demo.rs`,
`image_kernel_boots_far_faster_than_streaming_the_core`).

Sizes (source: `kernel-sizes.md`, "Dead code removed (step 7)"):

| | asm lines | assembled bytes |
|---|---:|---:|
| forth-on-forthish/kernel.s (primitives + bootstrap) | 2,659 | 4,001 |
| forth-from-forth/kernel.s, image with bootstrap still in | 5,087 | 9,450 |
| forth-from-forth/kernel.s, bootstrap stripped | 4,060 | 8,168 |
| forth-from-forth/kernel.s, primitives from Forth (no template, no comments) | 3,917 | 8,168 |
| forth-from-forth/kernel.s, FIND hash table and its upkeep removed | 3,508 | 7,098 |

- Compiled core: 83 definitions (82 from the shared tiers plus a Forth
  `[']`), 2,427 lines of emitted assembly. The compiled dictionary alone
  assembles to about 5.4 KB.
- Source, all Forth except two small scripts: `compiler/xcomp.fth` 621
  lines (compiler plus the assembler vocabulary); `core/prims-asm.fth`
  1,632 lines (the primitives, in that vocabulary); `core/prims.fth` 42
  lines (the `PRIM: name label` registry, 32 primitives);
  `scripts/build-image.sh` 75 lines (shell plumbing); `scripts/dead-code.py`
  61 lines (a reachability check, not a generator).
- Build: a full kernel build (primitives and dictionary) does 1.26 G
  instructions of real work (1.91 G under cor24-emu, whose -u feeds at most
  one byte per 10,000-instruction batch) and takes about 30 s of wall
  time; a dictionary-only compile for tests about 7 s.
- Removed by the reachability pass: 85 blocks, 1,043 lines, including the
  assembly `INTERPRET`, `QUIT`, `NUMBER`, `WORD`, `FIND`, `:`, `;` and `[']`.
- Tests: 92 golden-output tests (reg-rs) in sw-cor24-forth, all passing,
  including `tf24a_fff_fixed_point`;
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
- **Part 2: "phase 4 deletes the hashing subsystem."** True. The assembly
  `FIND` that used the hash left the image when a Forth `[']` replaced its
  last caller (`8ab0170`). The table itself, the loop in `_start` that filled
  it and the update in `CREATE` stayed until the primitives were Forth; then
  deleting them was a Forth edit (259 lines of prims-asm.fth, 1,070 bytes of
  kernel, and boot dropped from ~22,000 instructions to ~100).
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

A primitive in the Forth assembler vocabulary, `forth-from-forth/core/prims-asm.fth`:

```forth
l: do_plus
  fp pop,   \ fp = n2
  r0 pop,   \ r0 = n1
  r0 fp add,   \ r0 = n1 + n2
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,
```

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
  contrast); click **Rebuild kernel** (the running kernel compiles its own
  kernel.s, a minute or two in the browser, then reports whether the result
  is identical to itself, text and bytes); `SEE IF`, `SEE QUIT`, `WORDS` (every word shown was compiled by
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
  vocabulary (`core/prims-asm.fth`); kernel.s was byte-identical to the
  hand-written version it replaced. The unused FIND hash table and its
  upkeep are deleted. Tab 4 has a "Rebuild kernel" button: the running
  kernel compiles its own kernel.s in the browser (about 1.26 G
  instructions) and reports whether it is identical to itself.
- Stopping point (2026-10-24): the kernel is generated from Forth down to
  assembly text; `cor24-asm` turns the text into bytes. A Forth instruction
  encoder could replace it later; it is not planned now.
- `DO ?DO LOOP` and `CONSTANT`/`VARIABLE` in the cross-compiler: deferred,
  because no core tier uses them.
- Part 5's thin second backend (one Forth source, two targets) and the
  "Forth-builder kit" from Saw #8 are still plans.

## 7. Title options and series slot

Fits as **Down the Rabbit-Hole, FORTH part 6** (it closes the arc parts 2-5
opened), or as **Embedded #4**, the follow-up to Embedded #3's
self-hosting-spectrum post.

Title options:

1. "FORTH — A Kernel That Rebuilds Itself (Part 6)"
2. "FORTH — The Dictionary Is a Build Artifact (Part 6)"
3. "FORTH — Six Months Stuck on a Minus Sign (Part 6)"
4. "Embedded #4: forth-from-forth, the Kernel That Boots Already Compiled"
5. "FORTH — From Ten Million Instructions to a Hundred: Compiling the Core Ahead of Time"

## Sources

- `forth-from-forth/docs/status.md`, `kernel-sizes.md`,
  `parser-debug-notes.md` ("Resolution"), `compiler/README.md`.
- sw-cor24-forth commits: `5b874f5` (primitives in Forth), `0208844`
  (fixed point), `6e0aa5c` (NUMBER fix), `5d28683` (compile from
  source), `058017a` (control flow), `3339c91` (all five tiers run),
  `24968e9` (image boot), `61102b1` and `8ab0170` (bootstrap removed).
- web-sw-cor24-forth commits: `2fc2518` (tab 4, tab-1 fix, watchdog),
  `e1f11ba` (deployed pages), `63b3e1a` (build replay).
- Saga records: `.agentrail/` (phase-4-tab-4) and
  `.agentrail-archive/phase-4-forth-from-forth-*` (the April saga).
- Presentation: `docs/presentation/forth-on-cor24.pptx` (slides 9, 14, 15).
