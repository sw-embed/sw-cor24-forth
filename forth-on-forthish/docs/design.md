# Design notes — forth-on-forthish

Captures the key choices for approach 3.

## What "forth-ish substrate" means concretely

The asm kernel exposes only operations that are themselves
Forth-shaped: stack-machine ALU (`+`, `NAND`), stack-pointer
read/write (`SP@`/`SP!`/`RP@`/`RP!`), memory primitives (`@`/`!`/
`C@`/`C!`), and the threading hooks (`DOCOL`, `EXIT`, `LIT`,
`BRANCH`, `0BRANCH`, `EXECUTE`). Nothing in the asm kernel does
text processing, dictionary walking, number formatting, or even
high-level stack manipulation like `DUP`/`SWAP` — those are all Forth.

The result: every word visible to the user is a colon definition.
Every primitive in the kernel is something a CPU instruction can
execute in O(1) and that genuinely cannot be expressed in terms of
the others.

## Why move `:` and `;` to Forth?

Pedagogically the biggest win in approach 3. Showing `:` itself as a
Forth def (`: : CREATE ,DOCOL ] ;`) demonstrates that nothing about
defining new words is privileged — they all reduce to lower
operations.

The cost is one new primitive: `,DOCOL`. It's the smallest possible
helper — it just memcpies the 6-byte far-CFA template to HERE. It
exists because the byte sequence (`push r0; la r0,DOCOL_far; jmp(r0)`)
contains specific COR24 opcodes that Forth couldn't easily emit on
its own without an instruction encoder.

## Why move `WORD`/`FIND`/`NUMBER` to Forth?

These are the largest primitives in `forth.s` (~400 lines). They're
also the ones most Forths-as-Forth implementations get to rewrite.
After this move, the entire **text-processing pipeline** of the
interpreter is Forth code — the asm kernel knows nothing about
counted strings, dictionary search, digit parsing, or whitespace
handling.

## Why move `INTERPRET`/`QUIT` to Forth?

Once `WORD`/`FIND`/`NUMBER`/`EXECUTE` exist as Forth-callable words,
the outer interpreter is just a `BEGIN…UNTIL` loop over them. There's
no reason it has to be asm. Moving it makes the interpreter trivially
modifiable from Forth — e.g., adding a custom prompt or a
debugger-friendly mode becomes a Forth edit instead of an asm edit.

## Why `NAND` instead of `AND`/`OR`/`XOR`?

`NAND` is functionally complete on its own. From it:

```
: INVERT  DUP NAND ;
: AND     NAND INVERT ;
: OR      INVERT SWAP INVERT NAND ;
: XOR     2DUP NAND >R OR R> NAND ;     \ or any classical reduction
```

So one asm primitive replaces three. The runtime cost (~3-4× per
boolean op) is negligible because boolean ops are not on the hot
path of any example.

## Why `*` and `/MOD` as `+`-loops in Forth?

The COR24 ISA has `mul` but no `div`. The asm `/MOD` was already a
repeated-subtraction loop. Moving it to Forth is essentially
free — the loop just runs in threaded code instead of asm. `*` is
slightly worse (asm uses one `mul` instruction; Forth needs an
add-loop) but multiplication is rare in our examples.

## The bootstrap chicken-and-egg

`runtime.fth` defines `:` and `;`. But to load `runtime.fth` we need
to interpret Forth source — which requires `WORD`/`FIND`/`INTERPRET`.

Solution: keep a *minimal* asm bootstrap loop alive long enough to
load `runtime.fth`. The asm bootstrap reads one space-delimited
token via `KEY`, looks it up via a tiny inline `FIND`, and executes
it. It can handle the asm primitives plus things defined via the
existing colon-CFA primitives — that's enough to load Forth `:` and
`;` from `runtime.fth`. After `runtime.fth` finishes, the Forth
`INTERPRET` takes over and the asm bootstrap is never used again.

This means the asm kernel still contains a *tiny*, ~50-line outer
loop. It's not zero. We accept this as the irreducible bootstrap
cost — getting it to truly zero is what `./forth-from-forth/` does.

## The HERE-address pitfall (still applies)

`HERE`/`LATEST`/`STATE`/`BASE` push the address, not the value.
Forth code must `@` to read. This convention is preserved from
`./forth-in-forth/` — see `../forth-in-forth/docs/architecture.md`
for the historical context. (Phase 4 may change this.)

## Compatibility with `./forth-in-forth/`

The compiled output and dictionary layout are byte-compatible.
Any user code (`examples/*.fth`) that runs on `./forth-in-forth/`
runs on `./forth-on-forthish/` with the same UART output (modulo
larger instruction budgets).
