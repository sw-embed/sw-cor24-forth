# Architecture — forth-in-forth

## Directory layout

```
forth-in-forth/
  kernel.s              asm kernel (copy-then-strip from forth.s)
  core/
    minimal.fth         loaded 1st: IF/THEN/ELSE/BEGIN/UNTIL, \ ( comments
    lowlevel.fth        loaded 2nd: stack helpers, 1+/1-, NEGATE, =, 0=, /, MOD
    midlevel.fth        loaded 3rd: CR SPACE HEX DECIMAL `.`
    highlevel.fth       loaded 4th: DEPTH .S WORDS VER SEE
  demo.sh               runs kernel + tiered core + one example file
  repl.sh               runs kernel + tiered core then hands off to cor24-run --terminal
  docs/                 this directory
```

## Bootstrap flow

1. `cor24-run --run kernel.s -u <input>` starts the CPU at `_start`.
2. `_start` sets `LATEST` to the kernel's top entry, snapshots `sp_base`,
   initializes `HERE`, then enters `QUIT` via the threaded `test_thread`.
3. `QUIT` reads lines over UART. For each line, `INTERPRET` runs
   `WORD`/`FIND`/`NUMBER` in a loop, executing or compiling each token,
   printing `ok` at end-of-line.
4. `demo.sh` pipes `core/minimal.fth core/lowlevel.fth …` followed by
   the example file as a single UART stream. The kernel processes it
   line by line exactly as if typed. Definitions accumulate in the
   dictionary; by the time the example runs, every word it needs is
   present.

## Kernel vs Core split

### Stays in asm (`kernel.s`)

- **Inner interpreter**: `DOCOL`, `DOCOL_far`, `EXIT`, `LIT`,
  `BRANCH`, `0BRANCH`, `EXECUTE`.
- **Stack primitives**: `DUP DROP SWAP OVER >R R> R@`.
- **Memory primitives**: `@ ! C@ C!`.
- **Arithmetic that touches the ALU directly**: `+ - * /MOD AND OR XOR < 0=`.
  (Candidates for later migration: `=`, `0=` via XOR; `*` via `+` loop.
  `/MOD` and `<` are easier to leave in asm.)
- **I/O primitives**: `KEY`, `EMIT`, `LED!`, `SW?`.
- **Compile machinery**: `HERE LATEST STATE BASE , C, ALLOT CREATE
  : ; IMMEDIATE [ ]`.
  `:` and `;` are left in asm because hand-written DOCOL-template
  emission is simpler in asm than in Forth.
- **Dictionary text ops**: `WORD FIND NUMBER` — these are
  ~400 lines of asm with tricky buffer/EOL handling; pragmatic to
  keep as primitives.
- **Outer interpreter**: `INTERPRET QUIT`. Needed in asm to bootstrap
  before any `.fth` source has been loaded.
- **The one added helper**: `[']` (IMMEDIATE) — reads next word,
  looks it up, compiles `LIT <cfa>` into the current definition.
  Needed so Forth-level `IF`/`THEN`/etc. can reference `BRANCH`/`0BRANCH`
  CFAs by name.

### Moves to Forth (`core/*.fth`)

- **Control flow** (minimal tier): `IF THEN ELSE BEGIN UNTIL`.
- **Comments** (minimal tier): `\ (` — both IMMEDIATE, both
  implemented as a `KEY`-until-delimiter loop.
- **Stack/arith helpers** (lowlevel tier): `ROT NIP TUCK 2DUP 2DROP
  2SWAP 1+ 1- NEGATE / MOD`, possibly `= 0=`.
- **I/O conveniences** (midlevel tier): `CR SPACE HEX DECIMAL .`.
  `.` is the biggest single asm win (~130 lines of repeated-subtraction
  division + digit emission becomes ~10 lines of Forth).
- **Diagnostics** (highlevel tier): `DEPTH .S WORDS VER SEE`.
  Requires adding one more primitive `SP@` to get the data-stack pointer.

## Threading model

Direct-Threaded Code (DTC). Each cell in a compiled body is the
**code address** of the primitive or sub-word's entry point. `NEXT`
is inlined (5 bytes) at the tail of every primitive:

```
lw r0, 0(r2)   ; W = mem[IP]   fetch CFA
add r2, 3      ; IP += cell
jmp (r0)       ; jump to primitive code
```

## Dictionary entry layout

```
offset  size  field
  0      3    link (address of previous entry, 0 = end of chain)
  3      1    flags_len (bit 7 = IMMEDIATE, bit 6 = HIDDEN, bits 0-5 = name length)
  4      N    name characters (no terminator; length carried in flags_len)
  4+N    ?    CFA — either a 3-byte near template (`bra do_docol; .byte 0`)
              or a 6-byte far template (`push r0; la r0,do_docol_far; jmp(r0)`).
              Primitives have no template — their CFA is the primitive's code label.
```

`:` at runtime writes the 6-byte far template.

## Register allocation (unchanged from forth.s)

- `r0` — W / scratch
- `r1` — RSP (return stack pointer, grows down from `0x0F0000`)
- `r2` — IP (threaded-code instruction pointer)
- `sp` — DSP (data stack; hardware push/pop in EBR)
- `fp` — limited scratch (pop/push/add-as-source work; direct load
  instructions do not target `fp`)

## HERE / LATEST / STATE / BASE convention

**This kernel's `HERE` pushes the *address* of the variable, not its
value.** To get the current dictionary pointer you write `HERE @`;
to update it you write `<new> HERE !`. Same for `LATEST`, `STATE`,
`BASE`.

This differs from most Forths (including ANS) where `HERE` yields the
value. All Forth code in `core/*.fth` must use `HERE @` when it wants
the pointer. Subset 3 originally tripped on this: the first version
of `IF`/`THEN` stored patch offsets into `&HERE` instead of the
placeholder cell, silently corrupting state after the first
compilation-time branch was laid down.

## `[']` helper (the one kernel addition)

```
: [']  ( compile-time, reads next input token )
        word                 \ read name from input
        find drop            \ dictionary lookup, discard flag
        lit do_lit , ,       \ compile `LIT cfa` into current definition
;  IMMEDIATE
```

Implemented in asm as a small far-CFA colon def (8 threaded cells)
rather than a monolithic primitive. This is the only way Forth-level
`IF`/`THEN`/etc. can embed `BRANCH`/`0BRANCH` CFAs into user-compiled
words.

## Branch offset semantics

`BRANCH` and `0BRANCH` each consume an inline offset cell:

```
IP_after_offset = IP_at_offset + offset_value
```

So an IMMEDIATE word computes `offset = target_addr - patch_addr`
where `patch_addr` is the address of the offset cell itself.
Forward branches yield positive offsets, backward branches negative.
24-bit two's complement wraps silently (the runtime `add r2, r0`
doesn't care about sign).
