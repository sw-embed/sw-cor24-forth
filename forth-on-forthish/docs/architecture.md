# Architecture — forth-on-forthish

## Directory layout

```
forth-on-forthish/
  kernel.s              ≤ ~800 lines of asm; ~22 primitives.
  core/
    runtime.fth         loaded 1st (NEW tier): :, ;, WORD, FIND, NUMBER,
                          INTERPRET, QUIT, basic stack ops via SP@.
    minimal.fth         loaded 2nd: BEGIN/UNTIL/IF/THEN/ELSE/0=/=/`(`/`\`.
    lowlevel.fth        loaded 3rd: NIP TUCK ROT 2DUP 2OVER ABS / MOD
                          + AND OR XOR (now Forth, derived from NAND)
                          + * /MOD - (now Forth, as +-loops).
    midlevel.fth        loaded 4th: CR SPACE HEX DECIMAL `.`
    highlevel.fth       loaded 5th: DEPTH .S WORDS VER PRINT-NAME `'`
                          >NAME SEE-CFA SEE PRIM-MARKER DUMP-ALL
  scripts/
    demo.sh             run an example through the kernel.
    see-demo.sh         non-interactive SEE demonstration.
    dump.sh             dump every dictionary word (DUMP-ALL).
    repl.sh             interactive Forth REPL.
  docs/                 this directory.
```

## Bootstrap flow

1. `cor24-run --run kernel.s -u <input>` starts at `_start`.
2. `_start` initializes the threading registers, sets `LATEST` to the
   last asm dict entry (likely BYE), initializes `HERE`, snapshots
   `sp_base`, and enters the asm `QUIT-BOOT` (a tiny outer loop that
   only knows how to read one space-delimited token, look it up, and
   execute it — just enough to load `runtime.fth`).
3. `runtime.fth` loads. As soon as the Forth `:`/`;` are defined, all
   subsequent definitions in `runtime.fth` use them. By the end of
   `runtime.fth`, the Forth `INTERPRET` and `QUIT` are installed —
   `EXECUTE`d in place of the asm bootstrap loop.
4. The remaining tiers (`minimal.fth` … `highlevel.fth`) load through
   the Forth `INTERPRET`. From here on, the bootstrap looks identical
   to `./forth-in-forth/`.

## What stays in asm (the irreducible ~22)

| Group | Primitives |
|---|---|
| Threading | `NEXT` (inlined), `DOCOL`, `DOCOL_far`, `EXIT`, `LIT`, `BRANCH`, `0BRANCH`, `EXECUTE` |
| Memory | `@` `!` `C@` `C!` |
| Arithmetic | `+`, `NAND` |
| I/O | `KEY`, `EMIT`, `LED!`, `SW?` |
| Stack pointers | `SP@`, `SP!`, `RP@`, `RP!` |
| Compile state | `HERE`, `LATEST`, `STATE`, `BASE` (variables — push their address) |
| Compile actions | `,DOCOL` (NEW: emits the 6-byte far-CFA template at HERE) |
| Misc | `BYE`, `HALT` |

Total: ~22 dict entries. Compare 50 in `./forth-in-forth/`, 65 in
the original `forth.s`.

## What moves to Forth (compared to forth-in-forth)

| Word | Why it can move |
|---|---|
| `:` and `;` | `,DOCOL` lets Forth emit the CFA template; CREATE + STATE manipulation already work. |
| `WORD` | Forth-managed counted-string buffer at a known address; `KEY` loop. |
| `FIND` | Walks `LATEST @` chain with `@` and `C@` and `=`. |
| `NUMBER` | Digit-parsing on top of `*`, `+`, `<`, `BASE @`. |
| `INTERPRET` and `QUIT` | `BEGIN…UNTIL` over `WORD`/`FIND`/`EXECUTE`/`NUMBER`/`STATE` checks. |
| `*` and `/MOD` | `+`-loops and `-`-loops. |
| `-` | `NEGATE +` (NEGATE built from NAND or `0 SWAP -` once `-` exists, chicken-and-egg avoided by `0 SWAP NAND-derived-NEG +`). |
| `AND`/`OR`/`XOR` | Derived from `NAND` (NOT = `DUP NAND`; AND = `NAND DUP NAND`; etc.). |
| `DUP`/`SWAP`/`OVER`/`>R`/`R>`/`R@`/`DROP` | Implemented in Forth using `SP@`/`SP!`/`RP@`/`RP!` and `@`/`!` to manipulate stack memory directly. |

## Threading model and dict format

Unchanged from `./forth-in-forth/`:

- Direct-Threaded Code (DTC) with inlined NEXT.
- Dict header: `link(3) flags_len(1) name(N) CFA(...)`.
- Far CFA template: `push r0; la r0,DOCOL_far; jmp(r0)` (6 bytes),
  followed by threaded body cells.

## Register conventions

Unchanged: `r0`=W, `r1`=RSP, `r2`=IP, `sp`=DSP, `fp`=scratch.

## HERE / LATEST / STATE / BASE convention

Unchanged: variables push their **address**, not the value. Use `@`
to read, `!` to write.

## The `,DOCOL` helper

```
,DOCOL ( -- )       \ writes the 6-byte far-CFA template at HERE,
                     \ advances HERE by 6.
```

Used by Forth-level `:`:

```
: : CREATE ,DOCOL ] ;
: ; ['] EXIT , [ STATE OFF ; IMMEDIATE
```

Where `STATE OFF` writes 0 to STATE.

## Stack ops via `SP@`/`SP!`

Example Forth `DUP`:

```
: DUP  SP@ @ ;        \ SP@ pushes the sp value; @ reads what was on top
```

`SWAP`:

```
: SWAP   SP@ @          \ x2
         SP@ 3 + @       \ x1 (3 bytes below top)
         SP@ 3 + !       \ store x2 at the under slot
         SP@ ! ;         \ store x1 at the top slot
```

Slower than asm `push`/`pop` but irreducible: with only memory
primitives and stack-pointer access, this is what you get.
