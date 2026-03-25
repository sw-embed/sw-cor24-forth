# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL: AgentRail Session Protocol (MUST follow exactly)

This project uses AgentRail. Every session follows this exact sequence:

### 1. START (do this FIRST, before anything else)
```bash
agentrail next
```
Read the output carefully. It tells you your current step, prompt, skill docs, and past trajectories.

### 2. BEGIN (immediately after reading the next output)
```bash
agentrail begin
```

### 3. WORK (do what the step prompt says)
Do NOT ask the user "want me to proceed?" or "shall I start?". The step prompt IS your instruction. Execute it.

### 4. COMMIT (after the work is done)
Commit your code changes with git.

### 5. COMPLETE (LAST thing, after committing)
```bash
agentrail complete --summary "what you accomplished" \
  --reward 1 \
  --actions "tools and approach used"
```
If the step failed: `--reward -1 --failure-mode "what went wrong"`
If the saga is finished: add `--done`

### 6. STOP (after complete, DO NOT continue working)
Do NOT make any further code changes after running agentrail complete.
Any changes after complete are untracked and invisible to the next session.
If you see more work to do, it belongs in the NEXT step, not this session.

Do NOT skip any of these steps. The next session depends on your trajectory recording.

## Project: tf24a — Tiny Forth for COR24 in Assembler

Clean-room DTC Forth for the COR24 24-bit RISC ISA. Assembler kernel, self-extending in Forth.

### Tools
- `cor24-run --run file.s [opts]` — assemble and run COR24 assembly
- `cor24-run --run file.s --dump --speed 0 -n N` — run N instructions, dump state
- `cor24-run --run file.s --terminal --echo --speed 0` — interactive UART session
- `cor24-run --run file.s -u 'input' --speed 0 --dump` — feed UART input, dump state

### COR24 Assembly Syntax
- Labels on own line: `label:` (no inline `label: instr`)
- Comments: `;` only (not `#`)
- Decimal immediates (not hex): `la r0, -65280` not `la r0, 0xFF0100`
- `.word label` — emits 24-bit address (one label per directive)
- `.byte 72, 101, 108` — raw bytes (no string literals)
- No `.align` directive; manually pad with `.byte 0`

### Register Allocation (Frozen)
- r0 = W (work register) / scratch
- r1 = RSP (return stack pointer, SRAM ~0x0F0000 growing down)
- r2 = IP (instruction pointer for threaded code)
- sp = DSP (data stack, hardware push/pop in EBR)
- fp = available as extra scratch

### COR24 ISA — Register Capabilities (MUST follow)

**Load destinations:** only r0, r1, r2 (NOT fp, sp)
- `lc r0, imm8` / `lcu r0, imm8` / `la r0, imm24` — ✓ for r0, r1, r2
- `lw r0, off(base)` / `lb`, `lbu` — destination must be r0, r1, or r2
- `lc fp, ...` / `lw fp, ...` — **ILLEGAL**, will not assemble

**ALU destinations:** only r0, r1, r2
- `add r0, r2` / `sub r0, r2` / `and`, `or`, `xor` — ✓ for r0, r1, r2
- `add fp, ...` / `sub fp, ...` — **ILLEGAL**
- `add r0, imm8` — works for r0, r1, r2, sp (NOT fp)

**Comparisons:** `ceq ra, rb`, `clu ra, rb`, `cls ra, rb`
- ra and rb can be r0, r1, r2, fp, sp, z
- Use `ceq r0, z` to test zero

**Stack:** `push ra` / `pop ra` — ra can be r0, r1, r2, fp
- `push fp` and `pop fp` work (this is how to move fp ↔ r0)

**fp as base register:** `lw r0, off(fp)` / `sw r0, off(fp)` — ✓
- fp is the ONLY way to index into EBR stack memory

**Reading sp:** `mov fp, sp` copies sp to fp. Then `push fp; pop r0` gets the value into r0.
- There is NO `mov r0, sp` instruction
- `mov sp, fp` restores sp from fp

**Key constraints:**
- Branch offset ±127 bytes (signed 8-bit); use `la r0, label; jmp (r0)` for far jumps
- `jal r1,(r0)` conflicts with r1=RSP — do not use for subroutine calls
- Cell size = 3 bytes (24-bit words)
- sp inits at 0xFEEC00, grows down

See `docs/inspect-stack-impl.md` for full ISA reference.

### Development Rules — TDD Required

**Every new word or feature MUST have a test before implementation.**

1. Write the test first as a threaded-code sequence in the test_thread, or as a `cor24-run -u` command
2. Verify the test fails or produces wrong output
3. Implement the word
4. Verify the test passes
5. Run ALL previous tests to check for regressions

Test format for `cor24-run -u`:
```bash
# Test: WORD ( inputs -- expected-outputs )
cor24-run --run forth.s -u 'inputs\n' --speed 0 -n 5000000 2>&1 | grep "^UART output:"
# Expected: ... expected output ...
```

When adding threaded-code tests, add them to test_thread BEFORE the `do_quit` entry.

**Run the full test suite with:** `reg-rs run -p tf24a --parallel`

Regression tests use `reg-rs` (golden-output regression tool). Each test captures
the full cor24-run output and compares against baseline. Tests are in `~/.local/reg-rs/`.

To add a new test:
```bash
PP="grep -A 100 '^UART output:' || true"
reg-rs create -t tf24a_TESTNAME -P "$PP" --timeout 30 \
  -c "cor24-run --run forth.s -u 'INPUT\n' --speed 0 -n 5000000 2>&1" \
  --desc "description"
```

Legacy bash tests: `./demo.sh test`

**Stack leak tests are mandatory.** Every new word must be tested for stack balance:
```bash
# Before and after calling NEWWORD, DEPTH must not change
cor24-run --run forth.s -u 'DEPTH .\nNEWWORD\nDEPTH .\n' --speed 0 -n 10000000
```

**Common COR24 stack bugs:**
- Using `push r2` (DS) instead of `sw r2, 0(r1); add r1, -3` (RS) to save IP
- WORD's eol_flag path must pop exactly one RS entry (saved IP), not more
- Any `push`/`pop` inside a primitive changes sp — account for this in DEPTH/.S

### DTC Inner Interpreter
```
; NEXT (inline everywhere or as tail of each primitive):
;   lw r0, 0(r2)    ; W = mem[IP] — fetch CFA from thread
;   add r2, 3       ; IP += cell
;   jmp (r0)        ; execute code at CFA
```

### UART I/O
- Data register: address -65280 (0xFF0100)
- Status register: address -65279 (0xFF0101)
- TX busy: bit 7 of status
- RX ready: bit 0 of status
