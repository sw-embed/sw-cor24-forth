# forth-from-forth compiler

A Forth-to-COR24-assembler cross-compiler, written in Forth.

## Usage

```
scripts/build-kernel.sh                     # core/runtime.fth -> compiler/out/runtime-dict.s
XC_SOURCE=file.fth XC_OUT=out.s scripts/build-kernel.sh   # any source, any output
XC_TRACE=1 scripts/build-kernel.sh          # also write each token and the stack
                                            # depth as ; comments in the output
scripts/test-kernel.sh                      # build, then run the emitted dict in
                                            # selftest-scaffold.s
```

## Pipeline

`build-kernel.sh` boots the phase-3 forth-on-forthish kernel in the emulator
and sends it, over the UART:

1. the five `core/*.fth` tiers, so the host Forth has its full vocabulary;
2. `compiler/xcomp.fth`, the compiler;
3. `core/prims.fth`, one `PRIM: <name> <asm-label>` line per primitive;
4. `XC-COMPILE-SOURCE`, the target source, and the sentinel `XC-END`.

`XC-COMPILE-SOURCE` reads the source a token at a time. For each `:` it reads
the name, registers it (so later definitions, and the definition itself, can
call it), collects the body up to `;`, reads one more token to see whether it
is `IMMEDIATE`, and only then emits the entry. The header byte is emitted last
because the assembler has no equates to patch it afterwards. `\` and `(`
comments are skipped, numbers (including negative ones) become `LIT n`, and
`['] X` becomes `LIT <X's label>`. `IF ELSE THEN BEGIN UNTIL AGAIN WHILE
REPEAT` lay down `BRANCH`/`0BRANCH` with byte offsets computed from the body
buffer, keeping open positions on the data stack as a running Forth does.
`RECURSE` compiles a call to the definition being compiled. A token it cannot resolve is emitted as a
`; ? TOKEN` comment so the build shows it.

Each entry looks like this, for `: R@ RP@ 3 + @ ;`:

```
fff_e5_R_64:            ; header: link, flags_len, name
.word fff_e4_SWAP
.byte 2
.byte 82
.byte 64
fff_c5_R_64:            ; CFA: push r0; la r0,do_docol_far; jmp (r0)
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_rp_fetch       ; body
.word do_lit
.word 3
.word do_plus
.word do_fetch
.word do_exit
```

Labels are `fff_c<n>_<NAME>` and `fff_e<n>_<NAME>`; letters and digits are
kept, anything else becomes `_<code>` (`R@` is `R_64`, `-` is `_45`).

## The primitives: an assembler vocabulary

`xcomp.fth` also defines postfix words that print one line of COR24
assembly each, and `core/prims-asm.fth` writes the kernel's primitive
section with them:

```forth
l: do_plus              \ do_plus:
  fp pop,               \ pop fp        ( n2 )
  r0 pop,               \ pop r0        ( n1 )
  r0 fp add,            \ add r0, fp
  r0 push,              \ push r0
  r0 0 r2 lw,           \ lw r0, 0(r2)  ( NEXT )
  r2 3 addi,            \ add r2, 3
  r0 jmp,               \ jmp (r0)
```

`scripts/build-image.sh` sends `XC-KERNEL-BEGIN`, then prims.fth and
prims-asm.fth (which prints the primitives), then `XC-COMPILE-SOURCE`
with the core; at `XC-END` the compiler adds `fff_latest`, the start-up
thread and `dict_end`. Test builds (`build-kernel.sh`) load only the
registry, prims.fth, so they skip the primitives.

prims-asm.fth was converted once (2026-10-24) from the hand-written
assembly; the generated kernel.s assembled to the same 8,168 bytes.

## Not yet

`DO ?DO LOOP` and `CONSTANT`/`VARIABLE` (no core tier uses them), and booting a kernel
from the emitted image. See `../docs/status.md`.

## Tests

- `reg-rs/tf24a_fff_selftest` — runs the emitted runtime.fth dictionary.
- `reg-rs/tf24a_fff_xc_compile_test` — compiles `tests/features.fth`.
- `reg-rs/tf24a_fff_xc_control_flow` — `tests/compare-see.sh tests/control.fth`:
  every definition must match, in `SEE` form, what the phase-3 kernel
  compiles from the same source. Use the same script for any new construct.
- `reg-rs/tf24a_fff_xc_full_core` — `tests/compare-core.sh`: the same check
  over all 68 definitions of the four upper tiers.
- `reg-rs/tf24a_fff_image_run` — `tests/image-test.sh`: the whole core,
  compiled, linked after kernel.s and run from a direct test thread.
  `SEE` comparison alone missed a wrong literal that this test caught.

Never put a backslash followed by n, r, t, x or 0 in any file sent through
`cor24-emu -u`, comments included: the emulator turns it into a control byte.
