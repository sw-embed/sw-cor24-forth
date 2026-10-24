# Status — forth-from-forth

Last updated: 2026-10-23.

Authoritative step state: `agentrail status` (saga `phase-4-tab-4`).
The first phase-4 saga, `phase-4-forth-from-forth`, is archived in
`.agentrail-archive/`; its steps 016-020 were never started and are
superseded by the current saga.

## Where it stands

| Piece | State |
|---|---|
| Cross-compiler `compiler/xcomp.fth` | Compiles `runtime.fth` from source (`XC-COMPILE-SOURCE`): comments, literals, `[']`, `IMMEDIATE`, and since step 3 `IF ELSE THEN BEGIN UNTIL AGAIN WHILE REPEAT` (matched against the phase-3 kernel with `compiler/tests/compare-see.sh`). Output is byte-identical to the April hand-listed emitters, which are gone. Self-test image runs it. |
| Primitive registry `core/prims.fth` | Names and labels of the 32 primitives the core uses; no asm bodies yet. |
| All five core tiers | Compiled from source: 82 definitions, 0 unresolved, 2,410 asm lines, 5,432 bytes. All match the phase-3 kernel in `SEE` form, and linked after kernel.s they run (`compiler/tests/image-test.sh`). |
| Image boot, no UART bootstrap | Not started (saga step 004). |
| `kernel.s` | Still a copy of `../forth-on-forthish/kernel.s`. |
| Web tab 4 | Not started (saga step 006). |

## Saga phase-4-tab-4

1. parser-integration-fix — done 2026-10-23 (negative-literal NUMBER bug)
2. compile-runtime-from-source — done 2026-10-23
3. compile-control-flow — done 2026-10-23
4. compile-loops-and-defining-words — deferred (no core tier uses DO/LOOP/CONSTANT/VARIABLE); re-added as step 11
5. compile-full-core — done 2026-10-23
6. prims-and-image-boot
7. delete-bootstrap-and-rebaseline
8. web-tab-4 (web-sw-cor24-forth)
9. blog-brief
10. deck-update
11. compile-loops-and-defining-words-deferred

## Done in the archived saga (2026-04-22 to 2026-04-26)

Design (pure-Forth cross-compiler, no hash), scaffold, compiler MVP,
emission of all runtime.fth definitions as COR24 asm, a runnable
self-test, the symbol table and dynamic-label machinery for the
parser, plus GH #3 words in the layered kernels (`:NONAME`, `?DUP`,
`MIN`, `MAX`, comparisons, `RECURSE`, `ROLL`, `J`).

## Found on the way (not fixed yet)

- `2SWAP` and `2OVER` in `core/lowlevel.fth` (forth-in-forth, forth-on-forthish,
  forth-from-forth, and `examples/14-fib.fth`) are wrong: `1 2 3 4 2SWAP`
  leaves `2 1 4 3`, not `3 4 1 2`. The compiler avoids `2SWAP`.
- `.` in `core/midlevel.fth` prints -8388608 (0x800000) as `-0`: the
  number negates to itself, so the digit loop sees zero. `SEE` shows it
  the same way. The cross-compiler's own number printer handles it, and
  `compiler/tests/compare-see.sh` translates the target's `-0` back.
