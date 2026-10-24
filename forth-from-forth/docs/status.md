# Status — forth-from-forth

Last updated: 2026-10-23.

Authoritative step state: `agentrail status` (saga `phase-4-tab-4`).
The first phase-4 saga, `phase-4-forth-from-forth`, is archived in
`.agentrail-archive/`; its steps 016-020 were never started and are
superseded by the current saga.

## Where it stands

| Piece | State |
|---|---|
| Cross-compiler `compiler/xcomp.fth` | Compiles `runtime.fth` from source (`XC-COMPILE-SOURCE`): comments, literals, `[']`, `IMMEDIATE`. Output is byte-identical to the April hand-listed emitters, which are gone. Self-test image runs it. |
| Primitive registry `core/prims.fth` | Names and labels of the 20 primitives runtime.fth uses; no asm bodies yet. |
| Other four core tiers | Not compiled yet (saga step 003). |
| Image boot, no UART bootstrap | Not started (saga step 004). |
| `kernel.s` | Still a copy of `../forth-on-forthish/kernel.s`. |
| Web tab 4 | Not started (saga step 006). |

## Saga phase-4-tab-4

1. parser-integration-fix — done 2026-10-23 (negative-literal NUMBER bug)
2. compile-runtime-from-source — done 2026-10-23
3. compile-full-core
4. prims-and-image-boot
5. delete-bootstrap-and-rebaseline
6. web-tab-4 (web-sw-cor24-forth)
7. blog-brief
8. deck-update

## Done in the archived saga (2026-04-22 to 2026-04-26)

Design (pure-Forth cross-compiler, no hash), scaffold, compiler MVP,
emission of all runtime.fth definitions as COR24 asm, a runnable
self-test, the symbol table and dynamic-label machinery for the
parser, plus GH #3 words in the layered kernels (`:NONAME`, `?DUP`,
`MIN`, `MAX`, comparisons, `RECURSE`, `ROLL`, `J`).
