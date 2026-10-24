# Status — forth-from-forth

Last updated: 2026-10-23.

Authoritative step state: `agentrail status` (saga `phase-4-tab-4`).
The first phase-4 saga, `phase-4-forth-from-forth`, is archived in
`.agentrail-archive/`; its steps 016-020 were never started and are
superseded by the current saga.

## Where it stands

| Piece | State |
|---|---|
| Cross-compiler `compiler/xcomp.fth` | Emits the whole `runtime.fth` tier from a hand-listed sequence (`COMPILE-RUNTIME`); self-test image runs it (`scripts/test-kernel.sh`). |
| Source-driven parser | Works for one colon definition (`XC-COMPILE-TEST`) since the phase-3 NUMBER fix of 2026-10-23. See `parser-debug-notes.md`, "Resolution". |
| Other four core tiers | Not compiled yet (saga step 003). |
| `core/prims.fth` primitive declarations | Stub (saga step 004). |
| Image boot, no UART bootstrap | Not started (saga step 004). |
| `kernel.s` | Still a copy of `../forth-on-forthish/kernel.s`. |
| Web tab 4 | Not started (saga step 006). |

## Saga phase-4-tab-4

1. parser-integration-fix — done 2026-10-23 (negative-literal NUMBER bug)
2. compile-runtime-from-source
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
