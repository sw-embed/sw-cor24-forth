; selftest-scaffold.s — minimal asm kernel for exercising the
; forth-from-forth cross-compiler's emitted dict.
;
; test-kernel.sh concatenates this file with
; compiler/out/runtime-dict.s (emitted by build-kernel.sh in step
; 005) to produce compiler/out/runtime-selftest.s — a complete
; runnable .s that cor24-run can assemble and execute.
;
; Provides:
;   - _start: init RSP + DSP, enter test_thread
;   - 14 asm primitives (do_docol_far, do_exit, do_lit,
;     do_sp_fetch, do_sp_store, do_rp_fetch, do_tor, do_rfrom,
;     do_fetch, do_store, do_plus, do_nand, do_emit, do_bye)
;   - test_thread: threaded-code test that invokes each of the
;     10 Forth colon defs (fff_cfa_DUP ... fff_cfa_NEGATE) with
;     known inputs and EMITs single bytes so UART output is
;     unambiguous.
;
; Expected UART output (full):
;   AA                  DUP: push A, DUP → AA
;   A                   DROP: push AB, DROP → A
;   ABA                 OVER: push AB, OVER → ABA
;   BA                  SWAP: push AB, SWAP → BA
;   1                   AND: '5'&'3' = '1'
;   7                   OR:  '5'|'3' = '7'
;   @                   XOR: 'A'^1   = '@'
;   X                   INVERT then 0xFF AND: low byte of ~0 masked
;   Y                   NEGATE low-byte test
;   R                   R@: push 'R', >R, R@, R>, DROP → 'R'
;   DONE                halt marker before BYE
; (Line breaks between each 3-char test section via EMIT of 10.)

_start:
    la r1, 983040            ; RSP base
    ; snapshot sp_base (not used here, but keep for compatibility)
    mov fp, sp
    push fp
    pop r0
    la r2, var_sp_base
    sw r0, 0(r2)
    ; enter test thread
    la r2, test_thread
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Far DOCOL — entry for all Forth colon defs (6-byte CFA)
; ============================================================
do_docol_far:
    add r1, -3
    sw r2, 0(r1)
    pop r2                   ; CFA (push'd by the CFA prelude)
    add r2, 6                ; PFA = CFA + 6
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; EXIT — pop caller's IP, NEXT
; ============================================================
do_exit:
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; LIT — push inline literal from thread
; ============================================================
do_lit:
    lw r0, 0(r2)
    add r2, 3
    push r0
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; EMIT — write byte to UART (TX busy-wait)
; ============================================================
do_emit:
    pop r0
    add r1, -3
    sw r2, 0(r1)
    add r1, -3
    sw r0, 0(r1)
    la r2, -65280
emit_poll:
    lb r0, 1(r2)
    cls r0, z
    brt emit_poll
    lw r0, 0(r1)
    add r1, 3
    sb r0, 0(r2)
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Stack primitives: SP@, SP!
; ============================================================
do_sp_fetch:
    add r1, -3
    sw r2, 0(r1)
    mov fp, sp
    push fp
    pop r0
    push r0
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

do_sp_store:
    pop r0
    mov sp, r0
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Return stack: RP@, >R, R>
; ============================================================
do_rp_fetch:
    push r1
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

do_tor:
    pop r0
    add r1, -3
    sw r0, 0(r1)
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

do_rfrom:
    lw r0, 0(r1)
    add r1, 3
    push r0
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Memory: @, !
; ============================================================
do_fetch:
    pop r0
    lw r0, 0(r0)
    push r0
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

do_store:
    add r1, -3
    sw r2, 0(r1)             ; save IP (r2) to RS before clobbering
    pop r2                    ; addr
    pop r0                    ; value
    sw r0, 0(r2)              ; mem[addr] = value
    lw r2, 0(r1)             ; restore IP
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Arithmetic: +
; ============================================================
do_plus:
    pop fp
    pop r0
    add r0, fp
    push r0
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; NAND — bitwise n1 NAND n2
; ============================================================
do_nand:
    add r1, -3
    sw r2, 0(r1)
    pop r2
    pop r0
    and r0, r2
    la r2, -1
    xor r0, r2
    push r0
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; BYE — halt
; ============================================================
do_bye:
    bra do_bye

; ============================================================
; Stubs for primitives referenced by emitted COLON/SEMI defs.
; These paths aren't exercised by the self-test (which only
; touches runtime arithmetic/stack defs, not the colon-compiler
; machinery); we define them as bra-self halts so assembly
; resolves. If any of them IS reached accidentally, we see a
; self-branch halt and know which one via --dump.
; ============================================================
do_create:
    bra do_create
do_comma_docol:
    bra do_comma_docol
do_latest:
    bra do_latest
do_rbrac:
    bra do_rbrac
do_state:
    bra do_state
do_cfetch:
    bra do_cfetch
do_cstore:
    bra do_cstore
do_comma:
    bra do_comma

; ============================================================
; System variable storage (needed for sp_base snapshot)
; ============================================================
var_sp_base:
    .word 0

; ============================================================
; Test thread — exercises the 10 Forth colon defs in the
; emitted dict (runtime-dict.s concatenated after this file).
; Each test emits a recognizable byte sequence.
; ============================================================

test_thread:
    ; --- DUP test: push 'A', DUP, emit twice, NL ---
    .word do_lit
    .word 65                 ; 'A'
    .word fff_cfa_DUP
    .word do_emit            ; emit 'A'
    .word do_emit            ; emit 'A' (from the DUP'd copy)
    .word do_lit
    .word 10
    .word do_emit            ; NL → "AA\n"

    ; --- DROP test: push 'A', push 'B', DROP, emit, NL ---
    .word do_lit
    .word 65                 ; 'A'
    .word do_lit
    .word 66                 ; 'B'
    .word fff_cfa_DROP
    .word do_emit            ; emit 'A'
    .word do_lit
    .word 10
    .word do_emit            ; NL → "A\n"

    ; --- OVER test: push 'A', push 'B', OVER, 3 emits, NL ---
    ; DS after OVER: (A B A). Emits pop top-first → "ABA".
    .word do_lit
    .word 65                 ; 'A'
    .word do_lit
    .word 66                 ; 'B'
    .word fff_cfa_OVER
    .word do_emit            ; pop top A → 'A'
    .word do_emit            ; pop B → 'B'
    .word do_emit            ; pop A → 'A'
    .word do_lit
    .word 10
    .word do_emit            ; NL → "ABA\n"

    ; --- SWAP test: push 'A', push 'B', SWAP, 2 emits, NL ---
    ; DS after SWAP: (B A). Emits pop top-first → "AB".
    .word do_lit
    .word 65                 ; 'A'
    .word do_lit
    .word 66                 ; 'B'
    .word fff_cfa_SWAP
    .word do_emit            ; pop top A
    .word do_emit            ; pop B
    .word do_lit
    .word 10
    .word do_emit            ; NL → "AB\n"

    ; --- AND test: '5' AND '3' = '1' ---
    ; 0x35 AND 0x33 = 0x31. ASCII '1'.
    .word do_lit
    .word 53                 ; '5'
    .word do_lit
    .word 51                 ; '3'
    .word fff_cfa_AND
    .word do_emit            ; emit '1'
    .word do_lit
    .word 10
    .word do_emit            ; NL → "1\n"

    ; --- OR test: '5' OR '3' = '7' ---
    ; 0x35 OR 0x33 = 0x37. ASCII '7'.
    .word do_lit
    .word 53                 ; '5'
    .word do_lit
    .word 51                 ; '3'
    .word fff_cfa_OR
    .word do_emit            ; emit '7'
    .word do_lit
    .word 10
    .word do_emit            ; NL → "7\n"

    ; --- XOR test: 'A' XOR 1 = '@' ---
    ; 0x41 XOR 0x01 = 0x40. ASCII '@'.
    .word do_lit
    .word 65                 ; 'A'
    .word do_lit
    .word 1
    .word fff_cfa_XOR
    .word do_emit            ; emit '@'
    .word do_lit
    .word 10
    .word do_emit            ; NL → "@\n"

    ; --- R@ test: push 'R', >R, R@, R>, DROP, emit, NL ---
    ; R@'s Forth body is `RP@ 3 + @` — the "3 + @" skips the R@
    ; CFA's own saved-IP on RS to fetch the caller's >R'd value.
    .word do_lit
    .word 82                 ; 'R'
    .word do_tor             ; >R. RS top: 82. DS: ()
    .word fff_cfa_R@         ; reads RS top non-destructively → DS: (82)
    .word do_rfrom           ; pops RS → DS: (82 82)
    .word fff_cfa_DROP       ; drop the original R>'d value → DS: (82)
    .word do_emit            ; emit 'R'
    .word do_lit
    .word 10
    .word do_emit            ; NL → "R\n"

    ; --- INVERT test: push 65, INVERT → 0xFFFFBE.
    ; Extract low byte with AND 0xFF = 0xBE (not printable, but
    ; detectable in UART hex logs). Instead we emit a derived
    ; printable result: add 1 to get 0xBF, then AND with 0x7F to
    ; get 0x3F = '?'. Skipping bit-manipulation tricks; just use
    ; `: INVERT DUP NAND ;` semantics: 0 INVERT = 0xFFFFFF.
    ; 0xFFFFFF AND 0x40 = 0x40 = '@'. But we don't have AND with
    ; a wide constant cheaply. Test a different identity:
    ; INVERT INVERT = identity. Push 'Z' (90), INVERT INVERT,
    ; emit → 'Z'.
    .word do_lit
    .word 90                 ; 'Z'
    .word fff_cfa_INVERT
    .word fff_cfa_INVERT
    .word do_emit            ; expect 'Z'
    .word do_lit
    .word 10
    .word do_emit            ; NL → "Z\n"

    ; --- NEGATE test: NEGATE NEGATE = identity.
    ; Push 'N' (78), NEGATE NEGATE, emit → 'N'.
    .word do_lit
    .word 78                 ; 'N'
    .word fff_cfa_NEGATE
    .word fff_cfa_NEGATE
    .word do_emit            ; expect 'N'
    .word do_lit
    .word 10
    .word do_emit            ; NL → "N\n"

    ; --- MINUS test: push 68 ('D'), push 3, - → 68-3 = 65 ('A'). ---
    ; `-` is `: - NEGATE + ;`, so 68 3 - = 68 + NEGATE(3) = 68 + (-3) = 65.
    .word do_lit
    .word 68                 ; 'D'
    .word do_lit
    .word 3
    .word fff_cfa_MINUS
    .word do_emit            ; expect 'A'
    .word do_lit
    .word 10
    .word do_emit            ; NL → "A\n"

    ; --- Halt ---
    ; Emit "DONE" marker, then BYE.
    .word do_lit
    .word 68                 ; 'D'
    .word do_emit
    .word do_lit
    .word 79                 ; 'O'
    .word do_emit
    .word do_lit
    .word 78                 ; 'N'
    .word do_emit
    .word do_lit
    .word 69                 ; 'E'
    .word do_emit
    .word do_lit
    .word 10
    .word do_emit
    .word do_bye

; === emitted dict (from build-kernel.sh) ===
fff_entry_DUP:
.word 0
.byte 3
.byte 68
.byte 85
.byte 80
fff_cfa_DUP:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_sp_fetch
.word do_fetch
.word do_exit
fff_entry_DROP:
.word fff_entry_DUP
.byte 4
.byte 68
.byte 82
.byte 79
.byte 80
fff_cfa_DROP:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_sp_fetch
.word do_lit
.word 3
.word do_plus
.word do_sp_store
.word do_exit
fff_entry_OVER:
.word fff_entry_DROP
.byte 4
.byte 79
.byte 86
.byte 69
.byte 82
fff_cfa_OVER:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_sp_fetch
.word do_lit
.word 3
.word do_plus
.word do_fetch
.word do_exit
fff_entry_SWAP:
.word fff_entry_OVER
.byte 4
.byte 83
.byte 87
.byte 65
.byte 80
fff_cfa_SWAP:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_tor
.word fff_cfa_DUP
.word do_rfrom
.word do_sp_fetch
.word do_lit
.word 6
.word do_plus
.word do_store
.word do_exit
fff_entry_R@:
.word fff_entry_SWAP
.byte 2
.byte 82
.byte 64
fff_cfa_R@:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_rp_fetch
.word do_lit
.word 3
.word do_plus
.word do_fetch
.word do_exit
fff_entry_INVERT:
.word fff_entry_R@
.byte 6
.byte 73
.byte 78
.byte 86
.byte 69
.byte 82
.byte 84
fff_cfa_INVERT:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word fff_cfa_DUP
.word do_nand
.word do_exit
fff_entry_AND:
.word fff_entry_INVERT
.byte 3
.byte 65
.byte 78
.byte 68
fff_cfa_AND:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_nand
.word fff_cfa_INVERT
.word do_exit
fff_entry_OR:
.word fff_entry_AND
.byte 2
.byte 79
.byte 82
fff_cfa_OR:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word fff_cfa_INVERT
.word fff_cfa_SWAP
.word fff_cfa_INVERT
.word do_nand
.word do_exit
fff_entry_XOR:
.word fff_entry_OR
.byte 3
.byte 88
.byte 79
.byte 82
fff_cfa_XOR:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word fff_cfa_OVER
.word fff_cfa_OVER
.word do_nand
.word fff_cfa_DUP
.word do_tor
.word do_nand
.word fff_cfa_SWAP
.word do_rfrom
.word do_nand
.word do_nand
.word do_exit
fff_entry_NEGATE:
.word fff_entry_XOR
.byte 6
.byte 78
.byte 69
.byte 71
.byte 65
.byte 84
.byte 69
fff_cfa_NEGATE:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word fff_cfa_INVERT
.word do_lit
.word 1
.word do_plus
.word do_exit
fff_entry_MINUS:
.word fff_entry_NEGATE
.byte 1
.byte 45
fff_cfa_MINUS:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word fff_cfa_NEGATE
.word do_plus
.word do_exit
fff_entry_COLON:
.word fff_entry_MINUS
.byte 1
.byte 58
fff_cfa_COLON:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_create
.word do_comma_docol
.word do_latest
.word do_fetch
.word do_lit
.word 3
.word do_plus
.word fff_cfa_DUP
.word do_cfetch
.word do_lit
.word 64
.word fff_cfa_OR
.word fff_cfa_SWAP
.word do_cstore
.word do_rbrac
.word do_exit
fff_entry_SEMI:
.word fff_entry_COLON
.byte 129
.byte 59
fff_cfa_SEMI:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_lit
.word do_exit
.word do_comma
.word do_latest
.word do_fetch
.word do_lit
.word 3
.word do_plus
.word fff_cfa_DUP
.word do_cfetch
.word do_lit
.word 191
.word fff_cfa_AND

; === end of emitted dict ===
dict_end:
