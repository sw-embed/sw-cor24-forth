# One Interpreter Plan

## Goal

Consolidate all Forth features into `sw-cor24-forth/forth.s` (kernel) and
`examples/*.fth` (demo scripts). One binary runs identically at the CLI
and in the web UI (`web-sw-cor24-forth`). No forked copies.

## Current State (2026-04-10)

### CLI (`sw-cor24-forth`)
- **Kernel**: `forth.s` — 2801 lines, single-file DTC Forth interpreter
- **Tests**: `demo.sh test` — 40+ tests, all passing
- **Features in kernel**: EMIT, KEY, EXIT, LIT, BRANCH, 0BRANCH, +, *, -, /MOD,
  AND, OR, XOR, =, <, 0=, DROP, DUP, SWAP, OVER, >R, R>, R@, @, !, C@, C!,
  EXECUTE, HERE, LATEST, STATE, BASE, ,, C,, ALLOT, [, ], FIND, WORD, CREATE,
  :, ;, IMMEDIATE, LED!, ., NUMBER, INTERPRET, QUIT, CR, SPACE, DECIMAL, HEX,
  DEPTH, .S, WORDS, (, \, IF, THEN, BYE
- **Examples**: 00-smoke through 08-if-then

### Web UI (`web-sw-cor24-forth`)
- `config.rs` Interpreter tier already uses `include_str!("../../sw-cor24-forth/forth.s")`
- `asm/forth-interpreter.s` (73199 bytes) — **obsolete fork**, no longer compiled
- `asm/forth-bootstrap.s` — Bootstrap tier, still separate (fine, different tier)
- Demo registry references `examples/*.fth` from this repo

### Known Issues
- LED tests in `demo.sh test` hang (LED MMIO may not be wired in `cor24-run`)
- Web UI Reset is broken (stale tick callbacks) — **out of scope here**

## Phase 1: Verify Baseline

### 1a. Fix demo.sh LED tests
The LED tests use `--dump` and grep for `FF0000 LED`, but `cor24-run` may not
have an LED register. Either skip LED tests or verify the register exists.

**Action**: Run LED tests with `--dump` and inspect. If no LED register output,
mark tests as SKIP (like KEY).

### 1b. Confirm all kernel words work from CLI
Run each example `.fth` file via `cor24-run -u` and verify output.

**Checklist**:
```bash
# 00-smoke: just needs to boot and reach QUIT
cor24-run --run forth.s -u '\n' --speed 0 -n 5000000

# 01-colon: : DOUBLE DUP + ; 5 DOUBLE .
cor24-run --run forth.s -u ': DOUBLE DUP + ; 5 DOUBLE .\n' --speed 0 -n 5000000

# 03-math: 2 3 + . 10 3 - .
cor24-run --run forth.s -u '2 3 + . 10 3 - .\n' --speed 0 -n 5000000

# 06-comments: \ line comment  ( paren comment ) 42 .
cor24-run --run forth.s -u '\ hello\n( world ) 42 .\n' --speed 0 -n 5000000

# 07-divmod: 7 2 /MOD . .
cor24-run --run forth.s -u '7 2 /MOD . .\n' --speed 0 -n 5000000

# 08-if-then: : T -1 IF 65 EMIT THEN ; T
cor24-run --run forth.s -u ': T -1 IF 65 EMIT THEN ; T\n' --speed 0 -n 5000000
```

## Phase 2: Add ELSE to Kernel

### Target: `forth.s` — add `do_else` primitive + dictionary entry

**ELSE** compiles BRANCH + placeholder offset, then patches IF's placeholder
to point past the ELSE clause.

```
; do_else:
;   1. Compile do_branch at HERE
;   2. Compile placeholder (0) at HERE+3, save placeholder addr
;   3. Pop IF's patch_addr from DS
;   4. Compute offset = HERE - patch_addr
;   5. Store offset at patch_addr
;   6. Push new placeholder addr onto DS (for THEN)
```

**Test**:
```forth
: TEST -1 IF 65 EMIT ELSE 66 EMIT THEN ;
TEST   \ expect: A
: TEST2 0 IF 65 EMIT ELSE 66 EMIT THEN ;
TEST2  \ expect: B
```

**Stack balance test**: `DEPTH . TEST DEPTH .` — must show same depth before/after.

## Phase 3: Add BEGIN/UNTIL (do-while equivalent)

### Target: `forth.s` — add `do_begin` and `do_until` primitives

**BEGIN** is a compile-time marker — pushes current HERE onto DS.
**UNTIL** compiles 0BRANCH + backward offset = (BEGIN_addr - HERE).

```
; do_begin:
;   push HERE onto data stack (no code compiled)

; do_until:
;   1. Compile do_zbranch at HERE
;   2. Compile placeholder at HERE+3
;   3. Pop BEGIN's addr from DS
;   4. Compute offset = begin_addr - (HERE+3)
;   5. Store offset at placeholder
```

**Test**:
```forth
: COUNTDOWN 5 BEGIN DUP . 1 - DUP 0 = UNTIL DROP ;
COUNTDOWN  \ expect: 5 4 3 2 1
```

**Stack balance test**: `DEPTH . COUNTDOWN DEPTH .` — same depth.

## Phase 4: Add WHILE/REPEAT (do-while with early exit)

### Target: `forth.s` — add `do_while` and `do_repeat`

**WHILE** compiles 0BRANCH + forward placeholder, saves placeholder addr on DS.
**REPEAT** compiles BRANCH backward to BEGIN, patches WHILE's placeholder.

```
; do_while:
;   1. Compile do_zbranch at HERE
;   2. Compile placeholder at HERE+3
;   3. Push placeholder addr onto DS
;     (DS now has: [while_patch_addr, begin_addr])

; do_repeat:
;   1. Compile do_branch at HERE
;   2. Compile offset to BEGIN at HERE+3
;   3. Pop WHILE's patch_addr from DS
;   4. Pop BEGIN's addr from DS
;   5. Compute offset = HERE - while_patch_addr
;   6. Store offset at while_patch_addr
```

**Test**:
```forth
: COUNTDOWN2 5 BEGIN DUP 0 > WHILE DUP . 1 - REPEAT DROP ;
COUNTDOWN2  \ expect: 5 4 3 2 1
```

## Phase 5: Add DO/LOOP/I (counted loop)

### Target: `forth.s` — add `do_do`, `do_loop`, `do_i` primitives

Uses return stack for loop index and limit.

```
; do_do:  ( limit start -- ) ( R: -- start limit )
;   Pop start and limit, push to RS

; do_loop: ( R: start limit -- | start limit ) 
;   Increment start, compare with limit, branch back if not equal

; do_i: ( -- n ) ( R: start limit -- start limit )
;   Read loop index from RS
```

**Test**:
```forth
: FIVE 5 0 DO I . LOOP ;
FIVE  \ expect: 0 1 2 3 4
```

## Phase 6: Example Scripts + Fizzbuzz

### Update examples
- `09-if-else.fth` — IF/ELSE/THEN demo
- `10-loop.fth` — BEGIN/UNTIL, WHILE/REPEAT demo
- `11-fizzbuzz.fth` — full fizzbuzz using DO/LOOP/I + IF/THEN

### Verify web UI
After each phase, verify the web UI loads and runs the same kernel:
```bash
cd ~/github/sw-embed/web-sw-cor24-forth
trunk build
# open browser, run Interpreter tier, test
```

## Phase 7: Cleanup

1. Delete `web-sw-cor24-forth/asm/forth-interpreter.s` (obsolete)
2. Update `demo.sh` test suite to cover new words (ELSE, BEGIN/UNTIL, etc.)
3. Update `CHANGES.md`
4. Ensure `reg-rs` regression tests pass

## Dictionary Chain After All Phases

```
BYE → I → LOOP → DO → REPEAT → WHILE → UNTIL → BEGIN → ELSE → THEN → IF
→ \ → ( → WORDS → .S → DEPTH → HEX → DECIMAL → SPACE → CR → QUIT
→ INTERPRET → NUMBER → . → LED! → ; → : → CREATE → WORD → FIND
→ ] → [ → ALLOT → C, → , → BASE → STATE → LATEST → HERE → EXECUTE
→ C! → C@ → ! → @ → R@ → R> → >R → OVER → SWAP → DUP → DROP → 0=
→ < → = → XOR → OR → AND → /MOD → - → * → + → 0BRANCH → BRANCH
→ LIT → EXIT → KEY → EMIT
```

## Success Criteria

1. `./demo.sh test` — all tests pass (including new control-flow tests)
2. Every `.fth` example runs identically via CLI and web UI
3. No forked interpreter copies anywhere
4. `forth.s` is the single source of truth for both CLI and web
