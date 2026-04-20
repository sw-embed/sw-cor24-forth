# Future of the Forth kernel — approach comparison

How much of `forth.s` can be Forth instead of assembly? Four points
along that spectrum, from where we started to where a fully self-hosted
Forth could land.

## Why we can't just move every word today

Three reasons different parts of the kernel resist being moved to Forth:

1. **Threading-layer primitives are below Forth's level.** `NEXT`,
   `DOCOL`, `EXIT`, `LIT`, `BRANCH`, `0BRANCH`, `EXECUTE` define *how*
   threaded code runs. They cannot themselves be threaded code — they
   have to be machine code that the CPU jumps to.
2. **Some primitives need direct hardware/ALU/memory access.** `+`,
   `@`, `!`, `KEY`, `EMIT`, `LED!`, `SW?` ultimately have to compile
   to native instructions. Forth can wrap them, but something has to
   execute the actual `add`, `lw`, `sw`, or memory-mapped UART access.
3. **Bootstrap-phase primitives need to exist before any `.fth` source
   loads.** `WORD`, `FIND`, `NUMBER`, `:`, `;`, `INTERPRET`, `QUIT` are
   all *used* by the outer interpreter that reads `.fth` source. They
   could be Forth code in principle, but only if we have *another*
   bootstrap interpreter (smaller, asm) that runs first to load them.
   Today we sidestep the recursion by keeping them in asm.

What we moved today (subsets 3–11) was the third category for
non-essential cases — comments, control flow, base setting, number
print, dict diagnostics — words that have alternatives expressible
in plain Forth using primitives the bootstrap layer already provides.

## Four approaches

| # | Name | Where the kernel comes from |
|---|------|---|
| 1 | All-asm kernel | Hand-written `.s` |
| 2 | Tiered Forth on a slimmed kernel | Hand-written `.s` + hand-written `.fth` (today) |
| 3 | Minimal-primitive kernel | Smaller hand-written `.s` + larger hand-written `.fth` |
| 4 | Self-hosted via cross-compiler | Hand-written *Forth* compiler emits the `.s` |

### Approach 1 — what we had

`forth.s` as a single self-contained file. Every word is asm, including
`IF`/`THEN`, `.`, `WORDS`, `.S`, `\`, `(`, etc. ~3000 lines, ~3879
bytes assembled. Still the canonical kernel for the web frontend and
existing reg-rs tests.

### Approach 2 — what we did today

`forth-in-forth/kernel.s` plus `core/{minimal,lowlevel,midlevel,highlevel}.fth`.
The kernel keeps the threading layer, ALU primitives, hardware I/O,
the dict-text triplet (`WORD`/`FIND`/`NUMBER`), the outer loop
(`INTERPRET`/`QUIT`), and `:`/`;`. Everything else (control flow,
comments, equality, base, number print, stack helpers, dict
diagnostics) is Forth.

### Approach 3 — what we could do better

Refactor the kernel to replace high-level asm primitives with smaller,
more orthogonal ones, then move much more to Forth.

Specific moves enabled:
- `:` and `;` to Forth, by adding a primitive `,DOCOL` that emits the
  6-byte far-CFA template at HERE. Then `: : CREATE ,DOCOL ] ; IMMEDIATE`
  and a slightly tricky `;` that compiles `EXIT` and toggles `STATE`.
- `WORD` to Forth, by relying on `KEY` plus a Forth-managed
  `word_buffer`. Need a primitive `WORD-BUFFER` that pushes the buffer
  address (or just pick a known address).
- `FIND` to Forth, by walking `LATEST @` with `@`, `C@`, `=`, and `AND`.
  All those exist (or could).
- `NUMBER` to Forth, by digit-parsing on top of `*`, `+`, `<`, `BASE @`.
- `INTERPRET` and `QUIT` to Forth, as `BEGIN…UNTIL` loops over
  `WORD`/`FIND`/`EXECUTE`/`NUMBER`.
- `*`, `/MOD`, `-` to Forth, as `+`-loops or `NEGATE +`.
- `AND`/`OR`/`XOR` to Forth, as derivations from a single bit-primitive
  like `NAND`.
- `DUP`/`SWAP`/`OVER` to Forth, as `SP@`-based memory operations on
  the data stack.

After this refactor, the irreducible asm primitives are roughly:

```
NEXT  DOCOL  EXIT  LIT  BRANCH  0BRANCH  EXECUTE
+  NAND  @  !  C@  C!  KEY  EMIT  SP@  RP@  SP!  RP!
LED!  SW?  HALT
```

About 20 primitives, ~600–800 asm lines.

### Approach 4 — Forth-hosted cross-compiler

Write a Forth-to-COR24-asm compiler *in Forth*. Run it on a host Forth
(or on a previous-generation `forth-in-forth`) to emit the kernel.
After bootstrap, no hand-written `.s` exists; `kernel.s` is a build
artifact.

The cross-compiler is roughly:
- A COR24 instruction encoder (each opcode → bytes).
- A primitive table: each Forth primitive defined as a small Forth
  word that emits the asm body (e.g., `: prim-+ asm-pop-r2 asm-pop-r0
  asm-add-r0-r2 asm-push-r0 asm-next ;`).
- A linker that lays out the dict chain and writes the final `.s`.

Standard pattern; eForth, JonesForth, and several "ITSY"-style
projects use it. ~500–1000 lines of cross-compiler Forth + a runtime
specification.

## Comparison tables

### Source sizes

| Approach | asm lines | Forth lines | Hand-written total | Auto-generated |
|---|---:|---:|---:|---|
| 1: all-asm | ~2983 | 0 | 2983 | 0 |
| 2: today | 2239 | 161 | 2400 | 0 |
| 3: minimal-primitive | ~700 | ~600 | ~1300 | 0 |
| 4: cross-compiled | 0 | ~1000 | ~1000 | the entire `.s` |

### Asm primitive count

| Approach | Threading | Stack | Memory | Arith/Logic | I/O | Dict text | Compile state | Outer | Hardware | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1: all-asm | 7 | 7 | 4 | 9 | 2 | 3 | 17 | 2 | 3 | ~65 |
| 2: today | 7 | 7 | 4 | 8 | 2 | 3 | 14 | 2 | 3 | 50 |
| 3: minimal-primitive | 7 | 0 (SP@/!) | 4 | 2 (+, NAND) | 2 | 0 | 4 (HERE/LATEST/STATE/BASE) | 0 | 3 | ~22 |
| 4: cross-compiled | (same primitive set as 3, but emitted from Forth) | | | | | | | | | ~22 emitted |

### What lives in Forth

| Capability | 1: all-asm | 2: today | 3: minimal-prim | 4: cross-comp |
|---|---|---|---|---|
| Control flow (IF/BEGIN/...) | asm | **Forth** | Forth | Forth |
| Comments (`\`, `(`) | asm | **Forth** | Forth | Forth |
| Stack helpers (NIP, ROT, ...) | n/a | **new in Forth** | Forth | Forth |
| `=`, `0=` | asm | **Forth** | Forth | Forth |
| `CR`, `SPACE`, `HEX`, `DECIMAL` | asm | **Forth** | Forth | Forth |
| `.`, `.S`, `DEPTH` | asm | **Forth** | Forth | Forth |
| `WORDS`, `VER`, `SEE` | asm (no SEE) | **Forth + new SEE** | Forth | Forth |
| `*`, `/MOD`, `-` | asm | asm | **Forth** | Forth |
| `AND`/`OR`/`XOR` | asm | asm | **Forth (from NAND)** | Forth |
| `DUP`/`SWAP`/`OVER`/`>R`/`R>` | asm | asm | **Forth (via SP@)** | Forth |
| `:` and `;` | asm | asm | **Forth (with `,DOCOL` helper)** | Forth |
| `WORD`/`FIND`/`NUMBER` | asm | asm | **Forth (on KEY + @)** | Forth |
| `INTERPRET`/`QUIT` | asm | asm | **Forth** | Forth |
| The kernel `.s` itself | hand-written | hand-written | hand-written | **emitted by Forth** |

### Pros and cons

| Approach | Pros | Cons |
|---|---|---|
| 1: all-asm | Self-contained, fast, single file to debug. | Doesn't show Forth's self-extending nature. ~3000 lines of asm to maintain. |
| 2: today | Demonstrates the "Forth-extends-itself" story (`SEE FIB` works). Smaller asm. Tiered `.fth` makes the dependency layering explicit. | Compile-time IMMEDIATE words are slower (instruction budget grows from 5M to 200–400M). Still 50 asm primitives. |
| 3: minimal-primitive | Pushes asm down to the irreducible ~22 primitives — most of the kernel becomes Forth. The kernel becomes easy to retarget. | Significantly slower (every text-input call goes through Forth `WORD`/`FIND`/`NUMBER`). More tricky bootstrap ordering. Stack ops via `SP@` are noticeably slower than direct push/pop. |
| 4: cross-compiled | No hand-written asm in the source tree. Retargeting to a different ISA = swapping the asm-emit module. Cleanest pedagogical story: "here's Forth; here's the compiler that produces its own kernel." | Bootstrap chicken-and-egg: need *some* Forth to run the cross-compiler the first time. Build process becomes two-stage. The cross-compiler is itself a non-trivial piece of code (~1000 lines). |

### Engineering effort to reach each approach (from approach 2 today)

| Approach | Estimated work | Risk |
|---|---|---|
| 2 → 3 | ~1–2 weeks. Add `,DOCOL`, `SP@`/`RP@`/`SP!`/`RP!`, `NAND`. Rewrite `:`/`;`/`WORD`/`FIND`/`NUMBER`/`INTERPRET`/`QUIT` in Forth. Carefully reorder bootstrap. | Medium — bootstrap ordering is tricky and the Forth `FIND` will be ~10× slower than asm. |
| 2 → 4 | ~3–4 weeks. Build a COR24 instruction encoder in Forth, a primitive registry, dict-layout linker, and `.s` (or binary) emitter. Use today's `forth-in-forth` to host the first run. | High — many moving parts; instruction encoding bugs are silent. Pays back over time when retargeting or refactoring. |
| 3 → 4 | ~2–3 weeks (less, because primitives are already small and orthogonal). | Medium. |

### Self-hosting score

| Approach | Hand-written asm | Hand-written Forth | Auto-generated artifacts |
|---|---:|---:|---|
| 1: all-asm | 100% | 0% | none |
| 2: today | 93% (kernel) | 7% (core/*.fth) | none |
| 3: minimal-primitive | 54% | 46% | none |
| 4: cross-compiled | 0% | 100% | the kernel `.s` (or binary) |

## Recommendation

Approach 2 (today) is a great teaching artifact and stops at a natural
plateau: the words that *had* alternatives easy to express in plain
Forth all moved.

Approach 3 is the next sensible target if the goal is "minimal kernel".
The biggest single win is moving `:`/`;`/`WORD`/`FIND`/`NUMBER` to
Forth; that alone clears ~700 asm lines.

Approach 4 is the right move if there's appetite to retarget COR24
Forth to other ISAs (e.g., a different RISC variant or a software VM
like P24). The cross-compiler pays off across multiple targets.

A reasonable phased plan:

1. **Subset 12** (small): add `,DOCOL` and move `:`/`;` to Forth.
2. **Subset 13** (medium): add `SP@`/`SP!`/`RP@`/`RP!`, move stack
   primitives `DUP`/`SWAP`/`OVER`/`>R`/`R>` to Forth.
3. **Subset 14** (medium): move `*`/`/MOD`/`-` to Forth as loops; move
   `AND`/`OR`/`XOR` to Forth derived from a new `NAND` primitive.
4. **Subset 15** (large): move `WORD`/`FIND`/`NUMBER`/`INTERPRET`/`QUIT`
   to Forth. After this, kernel is approach 3.
5. **Subset 16** (separate project): build the cross-compiler in Forth.
   Use the approach-3 kernel to host its first run. Generate the
   approach-4 kernel as a build artifact.
