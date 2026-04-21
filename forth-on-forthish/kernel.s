; forth.s — sw-cor24-forth DTC Forth: Phases 1-4 (bootstrap, threading, dictionary, interpreter)
; COR24 DTC Forth kernel
;
; Register allocation (frozen):
;   r0 = W (work/scratch)
;   r1 = RSP (return stack pointer, grows down from 0x0F0000)
;   r2 = IP (instruction pointer for threaded code)
;   sp = DSP (data stack, hardware push/pop in EBR)
;   fp = limited scratch (only pop/push/add-as-source work)
;
; UART: data at 0xFF0100 (-65280), status at 0xFF0101 (-65279)
;   TX busy = status bit 7, RX ready = status bit 0
;
; DTC NEXT (inlined at tail of every primitive, 5 bytes):
;   lw r0, 0(r2)    ; W = mem[IP] — fetch code address from thread
;   add r2, 3       ; IP += cell
;   jmp (r0)        ; execute code
;
; Colon word CFA formats:
;   Near (hand-assembled, within 127B of do_docol):
;     bra do_docol     ; 2 bytes
;     .byte 0          ; 1 byte pad — PFA at CFA+3
;   Far (runtime-compiled or distant):
;     push r0          ; 1 byte — save CFA on data stack
;     la r0, do_docol_far ; 4 bytes
;     jmp (r0)         ; 1 byte — PFA at CFA+6
;
; Dictionary header layout:
;   .word link    ; 3 bytes — link to previous entry (0 = end)
;   .byte flags   ; 1 byte — bit7=IMMEDIATE, bit6=HIDDEN, bits0-5=namelen
;   .byte c1..cN  ; N bytes — name characters
;   (CFA follows immediately: CFA = entry + 4 + namelen)

; ============================================================
; Entry point (address 0)
; ============================================================
_start:
    la r1, 983040       ; r1 = 0x0F0000 return stack base

    ; Snapshot hardware-reset sp into var_sp_base for underflow checks
    mov fp, sp
    push fp
    pop r0               ; r0 = initial sp (push/pop is net-zero on sp)
    la r2, var_sp_base
    sw r0, 0(r2)

    ; Initialize system variables (r0, r2 free before Phase 1)
    la r2, entry_bye    ; LATEST init (was entry_ver before VER moved to Forth)
    la r0, var_latest_val
    sw r2, 0(r0)        ; LATEST = last dictionary entry
    la r2, dict_end
    la r0, var_here_val
    sw r2, 0(r0)        ; HERE = first free byte

    ; ============================================================
    ; Populate the FIND hash table (256 buckets, indexed by first
    ; char of name). Each bucket holds the most-recent entry whose
    ; name starts with that byte. See do_find / do_create for use.
    ; ============================================================
    ; Zero table (256 × 3 bytes = 768 bytes).
    ; Stash end-address on RS; r0 = ptr, r2 = value (0) each iter.
    la r2, dict_hash_table_end
    add r1, -3
    sw r2, 0(r1)         ; RS: [end_addr]
    la r0, dict_hash_table
ht_zero_loop:
    lc r2, 0
    sw r2, 0(r0)         ; slot = 0
    add r0, 3
    lw r2, 0(r1)         ; r2 = end_addr
    clu r0, r2
    brt ht_zero_loop
    add r1, 3            ; pop end_addr

    ; Walk LATEST chain (newest→oldest). Set each bucket to the
    ; NEWEST entry that hashes to it — only set a bucket if empty
    ; (since we walk newest first). Uses compute_hash (len-seeded mult33).
    la r0, var_latest_val
    lw r0, 0(r0)        ; r0 = newest entry
ht_pop_loop:
    ceq r0, z
    brt ht_pop_done
    push r0              ; save entry on DS
    ; hash_arg_ptr = entry + 4 (name start)
    add r0, 4
    la r2, hash_arg_ptr
    sw r0, 0(r2)
    ; hash_arg_len = (entry+3)[0] & 63 (mask flags bits)
    pop r0               ; r0 = entry
    push r0              ; put back on DS for later
    lbu r0, 3(r0)        ; flags_len
    lcu r2, 63
    and r0, r2           ; length
    la r2, hash_arg_len
    sw r0, 0(r2)
    ; return addr
    la r2, hash_ret_addr
    la r0, ht_pop_after_hash
    sw r0, 0(r2)
    la r0, compute_hash
    jmp (r0)
ht_pop_after_hash:
    ; DS: [entry]. hash_result holds the bucket.
    la r0, hash_result
    lw r0, 0(r0)         ; r0 = bucket
    lc r2, 3
    mul r0, r2           ; r0 = bucket * 3
    add r1, -3
    sw r0, 0(r1)         ; stash offset on RS
    la r0, dict_hash_table
    lw r2, 0(r1)
    add r1, 3
    add r0, r2           ; r0 = slot addr
    lw r2, 0(r0)         ; r2 = current slot
    ceq r2, z
    brt ht_pop_set
    ; Slot already has a (newer-than-current) entry; skip.
    pop r0               ; restore entry
    lw r0, 0(r0)         ; follow link
    bra ht_pop_loop
ht_pop_set:
    pop r2               ; r2 = entry (from push r0)
    sw r2, 0(r0)         ; *slot = entry
    lw r0, 0(r2)         ; follow link
    bra ht_pop_loop
ht_pop_done:

    ; ============================================================
    ; Launch threaded code tests (Phase 2 + Phase 3)
    ; ============================================================
    la r2, test_thread  ; IP = start of test thread
    ; NEXT — bootstrap into threaded execution
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; DOCOL — shared entry for colon definitions
; ============================================================

; Near DOCOL: CFA is "bra do_docol; .byte 0" (3 bytes), r0 = CFA from NEXT
do_docol:
    add r1, -3
    sw r2, 0(r1)        ; push IP to return stack
    mov r2, r0           ; r2 = CFA (from NEXT's jmp)
    add r2, 3            ; r2 = PFA = CFA + 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; Far DOCOL: CFA is "push r0; la r0, do_docol_far; jmp (r0)" (6 bytes)
; CFA address was pushed to data stack by "push r0" in the CFA
do_docol_far:
    add r1, -3
    sw r2, 0(r1)        ; push IP to return stack
    pop r2               ; r2 = CFA (from data stack)
    add r2, 6            ; r2 = PFA = CFA + 6
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Primitives with Dictionary Headers
; ============================================================
; Chain: entry_emit(link=0) → entry_key → ... → entry_immediate(LATEST)

; ------------------------------------------------------------
; EMIT ( c -- ) : Write character to UART with TX busy-wait
; ------------------------------------------------------------
entry_emit:
    .word 0
    .byte 4
    .byte 69, 77, 73, 84
do_emit:
    pop r0              ; r0 = character
    add r1, -3
    sw r2, 0(r1)        ; save IP on return stack
    add r1, -3
    sw r0, 0(r1)        ; save byte on return stack
    la r2, -65280       ; r2 = UART base
emit_poll:
    lb r0, 1(r2)        ; status (sign-extended; bit 7 → negative)
    cls r0, z           ; C = (status < 0) = TX busy
    brt emit_poll
    lw r0, 0(r1)        ; restore byte
    add r1, 3
    sb r0, 0(r2)        ; write byte to UART TX
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; KEY ( -- c ) : Read character from UART with RX busy-wait
; ------------------------------------------------------------
entry_key:
    .word entry_emit
    .byte 3
    .byte 75, 69, 89
do_key:
    add r1, -3
    sw r2, 0(r1)        ; save IP on return stack
key_poll:
    la r0, -65280       ; UART base
    lbu r0, 1(r0)       ; status byte (zero-extended)
    lcu r2, 1           ; bit 0 mask
    and r0, r2          ; isolate RX ready bit
    ceq r0, z           ; C = (not ready)
    brt key_poll
    la r0, -65280       ; reload UART base
    lbu r0, 0(r0)       ; read byte
    push r0
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; EXIT ( -- ) : End colon definition, pop IP from return stack
; ------------------------------------------------------------
entry_exit:
    .word entry_key
    .byte 4
    .byte 69, 88, 73, 84
do_exit:
    lw r2, 0(r1)        ; restore IP from return stack
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; LIT ( -- x ) : Push inline literal from thread [HIDDEN]
; ------------------------------------------------------------
entry_lit:
    .word entry_exit
    .byte 3          ; unhidden (was 67 = HIDDEN|3) so Forth can ['] LIT
    .byte 76, 73, 84
do_lit:
    lw r0, 0(r2)        ; r0 = literal at IP
    add r2, 3           ; IP past literal
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; BRANCH ( -- ) : Unconditional relative branch [HIDDEN]
; BRANCH ( -- ) : Unconditional relative branch (visible, used by IMMEDIATE
; control-flow words defined in core.fth)
; ------------------------------------------------------------
entry_branch:
    .word entry_lit
    .byte 6
    .byte 66, 82, 65, 78, 67, 72
do_branch:
    lw r0, 0(r2)        ; r0 = signed offset
    add r2, r0           ; IP += offset
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; 0BRANCH ( flag -- ) : Branch if TOS is zero (visible, used by IMMEDIATE
; control-flow words defined in core.fth)
; ------------------------------------------------------------
entry_zbranch:
    .word entry_branch
    .byte 7
    .byte 48, 66, 82, 65, 78, 67, 72
do_zbranch:
    pop r0               ; r0 = flag
    ceq r0, z            ; C = (flag == 0)
    brt zbr_take         ; if zero, take branch
    add r2, 3            ; skip offset cell
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)
zbr_take:
    lw r0, 0(r2)        ; r0 = offset
    add r2, r0           ; IP += offset
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Arithmetic Primitives
; ============================================================

; + ( n1 n2 -- n1+n2 )
entry_plus:
    .word entry_zbranch
    .byte 1
    .byte 43
do_plus:
    pop fp               ; fp = n2
    pop r0               ; r0 = n1
    add r0, fp           ; r0 = n1 + n2
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; Subset 16: `*`, `-`, `/MOD` moved to Forth in core/lowlevel.fth
; (and `-` in core/runtime.fth since minimal.fth uses it for offset
; arithmetic). `+` stays asm — used everywhere and hardware `add` is
; cheap. The old `*` used `mul r0, r2` (single-cycle on COR24); the
; Forth version is a repeated-addition loop, asymptotically much
; slower but still tractable within the fib demo's instruction budget.

; NAND ( n1 n2 -- ~(n1&n2) )  — subset 15: replaces AND/OR/XOR.
; Forth-level AND/OR/XOR/INVERT live in core/runtime.fth, derived via
; classical NAND-gate identities (INVERT = a NAND a, AND = NAND then
; INVERT, OR = DeMorgan, XOR = 4-NAND form).
entry_nand:
    .word entry_plus                ; was entry_slashmod; */-/MOD now in Forth
    .byte 4
    .byte 78, 65, 78, 68    ; "NAND"
do_nand:
    add r1, -3
    sw r2, 0(r1)
    pop r2               ; r2 = n2
    pop r0               ; r0 = n1
    and r0, r2           ; r0 = n1 & n2
    la r2, -1
    xor r0, r2           ; r0 = ~(n1 & n2)
    push r0
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; = and 0= moved to core/lowlevel.fth (via XOR and IF/ELSE).
; Only < remains as a primitive (needs signed compare `cls`).

; < ( n1 n2 -- flag ) : -1 if n1 < n2 signed, 0 otherwise
entry_less:
    .word entry_nand                ; was entry_xor; AND/OR/XOR now in Forth
    .byte 1
    .byte 60
do_less:
    add r1, -3
    sw r2, 0(r1)
    pop r2               ; n2
    pop r0               ; n1
    cls r0, r2           ; C = (n1 < n2) signed
    lc r0, 0
    brf lt_done
    lc r0, -1
lt_done:
    push r0
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Stack Primitives — subset 14B moved DUP/DROP/SWAP/OVER/R@ to
; core/runtime.fth as Forth colon defs using SP@/SP!/RP@/@/!/>R/R>.
; What remains in asm:
;   do_drop  — body only, no dict entry; called from tick_word_cfa
;   >R, R>   — full primitives. `>R` must atomically decrement r1
;              and store; R> mirrors. A Forth version would have
;              to preserve the outer colon's saved-IP slot, which
;              needs asm-level r1/r2 control.
; ============================================================

; do_drop: kept as an internal helper for tick_word_cfa (['])
; — no dict entry, so the user-level DROP is the Forth version.
do_drop:
    pop r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; >R ( x -- ) ( R: -- x )
entry_tor:
    .word entry_less
    .byte 2
    .byte 62, 82
do_tor:
    pop r0
    add r1, -3
    sw r0, 0(r1)
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; R> ( -- x ) ( R: x -- )
entry_rfrom:
    .word entry_tor
    .byte 2
    .byte 82, 62
do_rfrom:
    lw r0, 0(r1)
    add r1, 3
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Memory Primitives
; ============================================================

; @ ( addr -- x ) : Fetch cell from address
entry_fetch:
    .word entry_rfrom           ; was entry_rfetch; R@ now in Forth
    .byte 1
    .byte 64
do_fetch:
    pop r0
    lw r0, 0(r0)
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ! ( x addr -- ) : Store cell at address
entry_store:
    .word entry_fetch
    .byte 1
    .byte 33
do_store:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    ; underflow check: need 2 cells
    mov fp, sp
    push fp
    pop r0
    add r0, 6            ; r0 = sp + 6 (post-pop sp)
    la r2, var_sp_base
    lw r2, 0(r2)
    clu r2, r0           ; C = (sp_base < sp+6) → underflow
    brt do_store_uflw
    pop r2               ; addr
    pop r0               ; value
    sw r0, 0(r2)
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)
do_store_uflw:
    la r0, stack_underflow_err
    jmp (r0)

; C@ ( addr -- c ) : Fetch byte from address
entry_cfetch:
    .word entry_store
    .byte 2
    .byte 67, 64
do_cfetch:
    pop r0
    lbu r0, 0(r0)
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; C! ( c addr -- ) : Store byte at address
entry_cstore:
    .word entry_cfetch
    .byte 2
    .byte 67, 33
do_cstore:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    ; underflow check: need 2 cells
    mov fp, sp
    push fp
    pop r0
    add r0, 6
    la r2, var_sp_base
    lw r2, 0(r2)
    clu r2, r0
    brt do_cstore_uflw
    pop r2               ; addr
    pop r0               ; byte value
    sb r0, 0(r2)
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)
do_cstore_uflw:
    la r0, stack_underflow_err
    jmp (r0)

; ============================================================
; HALT — infinite loop (not in dictionary, just a code target)
; ============================================================
do_halt:
halt_loop:
    bra halt_loop

; ============================================================
; Phase 3: New Primitives
; ============================================================

; ------------------------------------------------------------
; EXECUTE ( cfa -- ) : Execute word at cfa
; ------------------------------------------------------------
entry_execute:
    .word entry_cstore
    .byte 7
    .byte 69, 88, 69, 67, 85, 84, 69
do_execute:
    add r1, -3
    sw r2, 0(r1)        ; save IP temporarily for the underflow check
    ; underflow check: need 1 cell
    mov fp, sp
    push fp
    pop r0
    add r0, 3
    la r2, var_sp_base
    lw r2, 0(r2)
    clu r2, r0
    brt do_execute_uflw
    lw r2, 0(r1)        ; restore IP (the executed word expects r2=IP)
    add r1, 3
    pop r0
    jmp (r0)
do_execute_uflw:
    la r0, stack_underflow_err
    jmp (r0)

; ------------------------------------------------------------
; HERE ( -- addr ) : Push address of HERE variable
; ------------------------------------------------------------
entry_here:
    .word entry_execute
    .byte 4
    .byte 72, 69, 82, 69
do_here:
    la r0, var_here_val
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; LATEST ( -- addr ) : Push address of LATEST variable
; ------------------------------------------------------------
entry_latest:
    .word entry_here
    .byte 6
    .byte 76, 65, 84, 69, 83, 84
do_latest:
    la r0, var_latest_val
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; STATE ( -- addr ) : Push address of STATE variable
; ------------------------------------------------------------
entry_state:
    .word entry_latest
    .byte 5
    .byte 83, 84, 65, 84, 69
do_state:
    la r0, var_state_val
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; BASE ( -- addr ) : Push address of BASE variable
; ------------------------------------------------------------
entry_base:
    .word entry_state
    .byte 4
    .byte 66, 65, 83, 69
do_base:
    la r0, var_base_val
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; , ( x -- ) : Store cell at HERE, advance HERE by 3
; ------------------------------------------------------------
entry_comma:
    .word entry_base
    .byte 1
    .byte 44
do_comma:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    ; underflow check: need 1 cell
    mov fp, sp
    push fp
    pop r0
    add r0, 3
    la r2, var_sp_base
    lw r2, 0(r2)
    clu r2, r0
    brt do_comma_uflw
    la r0, var_here_val
    lw r2, 0(r0)        ; r2 = HERE
    pop r0               ; r0 = value
    sw r0, 0(r2)        ; mem[HERE] = x
    add r2, 3            ; HERE += 3
    la r0, var_here_val
    sw r2, 0(r0)        ; update HERE
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)
do_comma_uflw:
    la r0, stack_underflow_err
    jmp (r0)

; ------------------------------------------------------------
; C, ( c -- ) : Store byte at HERE, advance HERE by 1
; ------------------------------------------------------------
entry_ccomma:
    .word entry_comma
    .byte 2
    .byte 67, 44
do_ccomma:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    ; underflow check: need 1 cell
    mov fp, sp
    push fp
    pop r0
    add r0, 3
    la r2, var_sp_base
    lw r2, 0(r2)
    clu r2, r0
    brt do_ccomma_uflw
    la r0, var_here_val
    lw r2, 0(r0)        ; r2 = HERE
    pop r0               ; r0 = byte
    sb r0, 0(r2)        ; mem[HERE] = c
    add r2, 1            ; HERE += 1
    la r0, var_here_val
    sw r2, 0(r0)        ; update HERE
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)
do_ccomma_uflw:
    la r0, stack_underflow_err
    jmp (r0)

; ------------------------------------------------------------
; ALLOT ( n -- ) : Advance HERE by n bytes
; ------------------------------------------------------------
entry_allot:
    .word entry_ccomma
    .byte 5
    .byte 65, 76, 76, 79, 84
do_allot:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    ; underflow check: need 1 cell
    mov fp, sp
    push fp
    pop r0
    add r0, 3
    la r2, var_sp_base
    lw r2, 0(r2)
    clu r2, r0
    brt do_allot_uflw
    la r0, var_here_val
    lw r2, 0(r0)        ; r2 = HERE
    pop r0               ; r0 = n
    add r2, r0           ; HERE += n
    la r0, var_here_val
    sw r2, 0(r0)        ; update HERE
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)
do_allot_uflw:
    la r0, stack_underflow_err
    jmp (r0)

; ------------------------------------------------------------
; [ ( -- ) : Enter interpret mode [IMMEDIATE]
; ------------------------------------------------------------
entry_lbrac:
    .word entry_allot
    .byte 129
    .byte 91
do_lbrac:
    add r1, -3
    sw r2, 0(r1)
    la r2, var_state_val
    lc r0, 0
    sw r0, 0(r2)        ; STATE = 0
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; ] ( -- ) : Enter compile mode
; ------------------------------------------------------------
entry_rbrac:
    .word entry_lbrac
    .byte 1
    .byte 93
do_rbrac:
    add r1, -3
    sw r2, 0(r1)
    la r2, var_state_val
    lc r0, -1
    sw r0, 0(r2)        ; STATE = -1
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; FIND ( c-addr -- c-addr 0 | cfa 1 | cfa -1 )
; Search dictionary for counted string at c-addr.
; Returns cfa and flag (1=immediate, -1=normal) or 0 if not found.
;
; Uses data stack to pass entry pointer between iterations (avoids
; long backward branches). RS base frame:
;   r1+0  = search_start (c-addr + 1)
;   r1+3  = search_len
;   r1+6  = c-addr (for not-found return)
;   r1+9  = saved IP
; ============================================================
entry_find:
    .word entry_rbrac
    .byte 4
    .byte 70, 73, 78, 68
do_find:
    add r1, -3
    sw r2, 0(r1)        ; save IP          RS: [IP]

    pop r0               ; r0 = c-addr
    add r1, -3
    sw r0, 0(r1)        ; save c-addr      RS: [c-addr, IP]

    lbu r2, 0(r0)       ; r2 = search length
    add r1, -3
    sw r2, 0(r1)        ; save search_len  RS: [search_len, c-addr, IP]

    add r0, 1           ; r0 = search name start
    add r1, -3
    sw r0, 0(r1)        ; save search_start RS: [ss, sl, ca, IP]

    ; Load start entry via mult33 hash (fallback to LATEST on miss).
    ; RS holds [ss, sl, ca, IP]; ss = name start, sl = length.
    lw r0, 0(r1)         ; r0 = search_start
    la r2, hash_arg_ptr
    sw r0, 0(r2)
    lw r0, 3(r1)         ; r0 = search_len
    la r2, hash_arg_len
    sw r0, 0(r2)
    la r2, hash_ret_addr
    la r0, find_after_hash
    sw r0, 0(r2)
    la r0, compute_hash
    jmp (r0)
find_after_hash:
    ; Lookaside fast path: if full 24-bit hash matches last cached
    ; FIND result AND the cached cfa is non-zero, push (cfa, flag)
    ; and return immediately.
    la r0, hash_full
    lw r0, 0(r0)              ; r0 = current 24-bit hash
    la r2, lookaside_hash
    lw r2, 0(r2)
    ceq r0, r2
    brf la_miss
    la r0, lookaside_cfa
    lw r0, 0(r0)
    ceq r0, z
    brt la_miss               ; cfa=0 means cache empty
    push r0                   ; DS: [cfa]
    la r0, lookaside_flag
    lw r0, 0(r0)
    push r0                   ; DS: [flag, cfa]
    ; Clean up RS [ss, sl, ca, IP] — IP is at offset 9
    lw r2, 9(r1)
    add r1, 12                ; pop 4 cells
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

la_miss:
    la r0, hash_result
    lw r0, 0(r0)         ; r0 = bucket
    lc r2, 3
    mul r0, r2           ; r0 = bucket * 3
    add r1, -3
    sw r0, 0(r1)
    la r0, dict_hash_table
    lw r2, 0(r1)
    add r1, 3
    add r0, r2           ; r0 = slot addr
    lw r0, 0(r0)         ; r0 = bucket entry (or 0)
    ceq r0, z
    brf find_have_start
    la r2, var_latest_val
    lw r0, 0(r2)         ; fallback: start at LATEST
find_have_start:
    push r0              ; DS: [entry]

find_loop:
    ; Entry pointer is on data stack
    pop r0               ; r0 = entry (0 = end of chain)
    ceq r0, z
    brf find_have_entry

    ; === Not found (inline handler) ===
    lw r0, 6(r1)        ; c-addr (RS offset 6)
    add r1, 9           ; pop ss, sl, ca. RS: [IP]
    push r0              ; DS: [c-addr]
    lc r0, 0
    push r0              ; DS: [0, c-addr]
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

find_have_entry:
    ; r0 = entry pointer
    ; Save entry on RS
    add r1, -3
    sw r0, 0(r1)        ; RS: [entry, ss, sl, ca, IP]

    ; Load flags_len byte
    lbu r2, 3(r0)       ; r2 = flags_len
    add r1, -3
    sw r2, 0(r1)        ; RS: [fl, entry, ss, sl, ca, IP]

    ; Check HIDDEN (bit 6): if hidden, skip via la+jmp
    lcu r0, 64
    and r0, r2
    ceq r0, z
    brt find_not_hidden
    la r0, find_skip_entry
    jmp (r0)
find_not_hidden:

    ; Extract name_len = flags_len & 0x3F
    lw r0, 0(r1)        ; r0 = flags_len
    lcu r2, 63
    and r0, r2           ; r0 = name_len

    ; Compare with search_len
    lw r2, 9(r1)        ; r2 = search_len (RS offset 9)
    ceq r0, r2
    brt find_len_match
    la r0, find_skip_entry
    jmp (r0)
find_len_match:

    ; === Lengths match — compare characters ===
    ; r0 = name_len = counter

    ; Save counter
    add r1, -3
    sw r0, 0(r1)        ; RS: [ctr, fl, entry, ss, sl, ca, IP]

    ; ename_ptr = entry + 4
    lw r0, 6(r1)        ; entry (RS offset 6)
    add r0, 4
    add r1, -3
    sw r0, 0(r1)        ; RS: [ep, ctr, fl, entry, ss, sl, ca, IP]

    ; sname_ptr = search_start
    lw r0, 12(r1)       ; search_start (RS offset 12)
    add r1, -3
    sw r0, 0(r1)        ; RS: [sp, ep, ctr, fl, entry, ss, sl, ca, IP]

find_cmp_loop:
    lw r0, 6(r1)        ; counter (RS offset 6)
    ceq r0, z
    brt find_matched

    ; Load entry char
    lw r0, 3(r1)        ; ename_ptr (RS offset 3)
    lbu r2, 0(r0)       ; r2 = entry char

    ; Load search char
    lw r0, 0(r1)        ; sname_ptr (RS offset 0)
    lbu r0, 0(r0)       ; r0 = search char

    ceq r0, r2
    brf find_char_fail

    ; Advance ename_ptr
    lw r0, 3(r1)
    add r0, 1
    sw r0, 3(r1)
    ; Advance sname_ptr
    lw r0, 0(r1)
    add r0, 1
    sw r0, 0(r1)
    ; Decrement counter
    lw r0, 6(r1)
    add r0, -1
    sw r0, 6(r1)
    bra find_cmp_loop

find_char_fail:
    add r1, 9           ; pop sp, ep, ctr
    ; RS: [fl, entry, ss, sl, ca, IP]
    ; Fall through to find_skip_entry

find_skip_entry:
    ; RS: [fl, entry, ss, sl, ca, IP]
    add r1, 3           ; pop flags_len
    lw r0, 0(r1)        ; entry
    add r1, 3           ; pop entry. RS: [ss, sl, ca, IP]
    lw r0, 0(r0)        ; follow link
    push r0              ; push next entry on DS
    la r0, find_loop
    jmp (r0)             ; back to loop (too far for bra)

find_matched:
    add r1, 9           ; pop sp, ep, ctr
    ; RS: [fl, entry, ss, sl, ca, IP]

    ; Read flags_len and entry BEFORE cleaning RS
    lw r0, 0(r1)        ; r0 = flags_len
    push r0              ; save flags_len on DS
    lw r2, 3(r1)        ; r2 = entry
    add r1, 15          ; pop fl, entry, ss, sl, ca. RS: [IP]

    ; Compute name_len = flags_len & 0x3F
    pop r0               ; r0 = flags_len
    push r0              ; keep flags_len on DS for IMMEDIATE check
    push r2              ; save entry. DS: [entry, flags_len]
    lcu r2, 63
    and r0, r2           ; r0 = name_len
    pop r2               ; r2 = entry. DS: [flags_len]

    ; CFA = entry + 4 + name_len
    add r2, 4
    add r2, r0           ; r2 = CFA
    push r2              ; DS: [CFA, flags_len]

    ; Check IMMEDIATE (bit 7 of original flags_len)
    pop r2               ; r2 = CFA (save temporarily)
    pop r0               ; r0 = flags_len. DS: []
    push r2              ; CFA back on DS: [CFA]
    lcu r2, 128
    and r0, r2           ; r0 = flags_len & 128
    ceq r0, z
    brt find_normal
    lc r0, 1             ; IMMEDIATE → flag = 1
    bra find_push_flag
find_normal:
    lc r0, -1            ; normal → flag = -1
find_push_flag:
    push r0              ; DS: [flag, CFA]

    ; Update lookaside cache (peek DS via fp, no pops).
    mov fp, sp
    lw r0, 0(fp)         ; r0 = flag (top)
    la r2, lookaside_flag
    sw r0, 0(r2)
    lw r0, 3(fp)         ; r0 = CFA (second)
    la r2, lookaside_cfa
    sw r0, 0(r2)
    la r0, hash_full
    lw r0, 0(r0)
    la r2, lookaside_hash
    sw r0, 0(r2)

    ; Restore IP and NEXT
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; WORD, CREATE, COLON, SEMICOLON, IMMEDIATE
; ============================================================

; ------------------------------------------------------------
; WORD ( -- c-addr ) : Read space-delimited word from UART
; Stores counted string at word_buffer, returns its address
; ------------------------------------------------------------
entry_word:
    .word entry_find
    .byte 4
    .byte 87, 79, 82, 68
do_word:
    add r1, -3
    sw r2, 0(r1)        ; save IP. RS: [IP]

    ; Check if previous call ended on newline
    la r0, word_eol_flag
    lbu r0, 0(r0)
    ceq r0, z
    brt word_no_eol
    ; Clear flag and return empty counted string (length=0)
    la r0, word_eol_flag
    lc r2, 0
    sb r2, 0(r0)
    la r0, word_buffer
    sb r2, 0(r0)        ; word_buffer[0] = 0 (length)
    push r0              ; push word_buffer address onto DS
    ; Restore IP from RS and NEXT (normal WORD return path)
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)
word_no_eol:

    ; Init buffer pointer (past count byte)
    la r0, word_buffer
    add r0, 1
    add r1, -3
    sw r0, 0(r1)        ; RS: [buf_ptr, IP]

    ; --- Skip leading spaces (NOT newlines) ---
    ; Spaces (32) are skipped. Newline (10, 13) → return empty.
    ; Any other char < 32 is skipped (control chars).
word_skip:
    la r0, -65280        ; UART base
word_skip_rx:
    lbu r2, 1(r0)       ; r2 = status
    lcu r0, 1
    and r2, r0           ; r2 = RX ready bit
    ceq r2, z
    brt word_skip_rx2    ; not ready, retry
    la r0, -65280
    lbu r0, 0(r0)       ; r0 = char
    ; Check for newline (10) → return empty
    lcu r2, 10
    ceq r0, r2
    brt word_empty       ; newline → empty token
    ; Check for CR (13) → return empty
    lcu r2, 13
    ceq r0, r2
    brt word_empty
    ; Skip spaces and other control chars
    lcu r2, 33
    clu r0, r2           ; C = (char < 33)
    brt word_skip        ; skip, read another
    bra word_store       ; got a real char
word_skip_rx2:
    la r0, -65280
    bra word_skip_rx

word_empty:
    ; Return empty counted string (length=0)
    la r0, word_buffer
    lc r2, 0
    sb r2, 0(r0)        ; store count=0
    add r1, 3           ; pop buf_ptr. RS: [IP]
    push r0              ; push word_buffer address
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

    ; --- Store char and read more ---
word_store:
    ; r0 = char to store
    lw r2, 0(r1)        ; r2 = buf_ptr
    sb r0, 0(r2)        ; store char
    add r2, 1
    sw r2, 0(r1)        ; update buf_ptr

word_read:
    la r0, -65280
word_read_rx:
    lbu r2, 1(r0)
    lcu r0, 1
    and r2, r0
    ceq r2, z
    brt word_read_rx2
    la r0, -65280
    lbu r0, 0(r0)       ; r0 = char
    lcu r2, 33
    clu r0, r2           ; C = (char < 33)
    brt word_end         ; delimiter found
    bra word_store       ; store and continue
word_read_rx2:
    la r0, -65280
    bra word_read_rx

word_end:
    ; r0 = delimiter char that ended the word
    ; Check if delimiter is newline → set eol flag
    push r0              ; save delimiter
    lcu r2, 10
    ceq r0, r2
    brt word_set_eol
    lcu r2, 13
    ceq r0, r2
    brt word_set_eol
    bra word_no_set_eol
word_set_eol:
    la r0, word_eol_flag
    lc r2, 1
    sb r2, 0(r0)
word_no_set_eol:
    pop r0               ; discard delimiter

    ; Compute length = buf_ptr - (word_buffer + 1)
    lw r2, 0(r1)        ; r2 = final buf_ptr
    add r1, 3           ; pop buf_ptr. RS: [IP]
    la r0, word_buffer
    add r0, 1           ; r0 = data start
    sub r2, r0           ; r2 = length
    la r0, word_buffer
    sb r2, 0(r0)        ; store count byte
    push r0              ; push word_buffer address

    ; Restore IP and NEXT
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; CREATE ( -- ) : Read name, build dictionary header at HERE
; Reads next word from UART input, builds link+flags+name at HERE.
; Updates LATEST. Does NOT write CFA — caller does that.
; ------------------------------------------------------------
entry_create:
    .word entry_word
    .byte 6
    .byte 67, 82, 69, 65, 84, 69
do_create:
    add r1, -3
    sw r2, 0(r1)        ; save IP. RS: [IP]

    ; --- Inline word reading (same as WORD) ---
    la r0, word_buffer
    add r0, 1
    add r1, -3
    sw r0, 0(r1)        ; RS: [buf_ptr, IP]

create_skip:
    la r0, -65280
create_skip_rx:
    lbu r2, 1(r0)
    lcu r0, 1
    and r2, r0
    ceq r2, z
    brt create_skip_rx2
    la r0, -65280
    lbu r0, 0(r0)
    lcu r2, 33
    clu r0, r2
    brt create_skip
    bra create_store
create_skip_rx2:
    la r0, -65280
    bra create_skip_rx

create_store:
    lw r2, 0(r1)
    sb r0, 0(r2)
    add r2, 1
    sw r2, 0(r1)

create_read:
    la r0, -65280
create_read_rx:
    lbu r2, 1(r0)
    lcu r0, 1
    and r2, r0
    ceq r2, z
    brt create_read_rx2
    la r0, -65280
    lbu r0, 0(r0)
    lcu r2, 33
    clu r0, r2
    brt create_read_done
    bra create_store
create_read_rx2:
    la r0, -65280
    bra create_read_rx

create_read_done:
    ; Compute name length
    lw r2, 0(r1)        ; r2 = final buf_ptr
    add r1, 3           ; pop buf_ptr. RS: [IP]
    la r0, word_buffer
    add r0, 1
    sub r2, r0           ; r2 = name length
    la r0, word_buffer
    sb r2, 0(r0)        ; store count

    ; --- Build header at HERE ---
    ; Save name length
    add r1, -3
    sw r2, 0(r1)        ; RS: [name_len, IP]

    ; Load HERE
    la r0, var_here_val
    lw r2, 0(r0)        ; r2 = HERE (destination)

    ; Save HERE (= new entry address) for LATEST update
    add r1, -3
    sw r2, 0(r1)        ; RS: [new_entry, name_len, IP]

    ; Write link field = current LATEST
    la r0, var_latest_val
    lw r0, 0(r0)        ; r0 = LATEST
    sw r0, 0(r2)        ; mem[HERE] = link
    add r2, 3           ; past link

    ; Write flags_len = name_len (no flags)
    lw r0, 3(r1)        ; r0 = name_len (at RS offset 3)
    sb r0, 0(r2)        ; mem[HERE+3] = flags_len
    add r2, 1           ; past flags_len

    ; Copy name chars from word_buffer+1 to HERE+4
    lw r0, 3(r1)        ; r0 = name_len (counter)
    add r1, -3
    sw r0, 0(r1)        ; RS: [counter, new_entry, name_len, IP]
    la r0, word_buffer
    add r0, 1           ; r0 = source
    add r1, -3
    sw r0, 0(r1)        ; RS: [src, counter, new_entry, name_len, IP]

create_copy:
    lw r0, 3(r1)        ; r0 = counter
    ceq r0, z
    brt create_copy_done
    lw r0, 0(r1)        ; r0 = src
    lbu r0, 0(r0)       ; r0 = char
    sb r0, 0(r2)        ; store at dest (r2)
    add r2, 1           ; dest++
    lw r0, 0(r1)        ; src
    add r0, 1
    sw r0, 0(r1)        ; src++
    lw r0, 3(r1)        ; counter
    add r0, -1
    sw r0, 3(r1)        ; counter--
    bra create_copy

create_copy_done:
    add r1, 6           ; pop src, counter. RS: [new_entry, name_len, IP]

    ; Update HERE (r2 = new position after name)
    la r0, var_here_val
    sw r2, 0(r0)

    ; Update LATEST = new_entry
    lw r0, 0(r1)        ; r0 = new_entry
    add r1, 6           ; pop new_entry, name_len. RS: [IP]
    add r1, -3
    sw r2, 0(r1)        ; save r2 on RS temporarily
    la r2, var_latest_val
    sw r0, 0(r2)        ; LATEST = new_entry
    lw r2, 0(r1)        ; restore r2
    add r1, 3           ; RS: [IP]

    ; Insert new_entry into FIND hash table (mult33 hash).
    ; r0 holds new_entry; flags_len at r0+3 (length in low 6 bits);
    ; name starts at r0+4.
    add r1, -3
    sw r0, 0(r1)        ; stash entry. RS: [entry, IP]
    ; hash_arg_ptr = entry + 4
    add r0, 4
    la r2, hash_arg_ptr
    sw r0, 0(r2)
    ; hash_arg_len = flags_len & 63
    lw r0, 0(r1)        ; r0 = entry
    lbu r0, 3(r0)       ; r0 = flags_len
    lcu r2, 63
    and r0, r2
    la r2, hash_arg_len
    sw r0, 0(r2)
    ; return addr
    la r2, hash_ret_addr
    la r0, create_after_hash
    sw r0, 0(r2)
    la r0, compute_hash
    jmp (r0)
create_after_hash:
    ; RS: [entry, IP]. Read hash_result, compute slot addr, store entry.
    la r0, hash_result
    lw r0, 0(r0)         ; r0 = bucket
    lc r2, 3
    mul r0, r2           ; r0 = bucket * 3
    add r1, -3
    sw r0, 0(r1)         ; RS: [offset, entry, IP]
    la r0, dict_hash_table
    lw r2, 0(r1)
    add r1, 3            ; pop offset
    add r0, r2           ; r0 = slot addr
    lw r2, 0(r1)         ; r2 = entry
    sw r2, 0(r0)         ; *slot = entry
    add r1, 3            ; pop entry. RS: [IP]

    ; Restore IP and NEXT
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; : ( -- ) : Start colon definition
; Calls CREATE, writes 6-byte far CFA, enters compile mode
; ------------------------------------------------------------
entry_colon:
    .word entry_create
    .byte 1
    .byte 58
do_colon:
    add r1, -3
    sw r2, 0(r1)        ; save IP. RS: [IP]

    ; --- Inline CREATE logic (read word, build header) ---
    ; This duplicates CREATE's word-reading and header-building.
    ; For code size, we CALL CREATE by jumping to it with a return trick.
    ; Push a return address on return stack, set IP to a thread that calls
    ; CREATE then returns. Actually, simpler: just copy CREATE's body.
    ;
    ; For now, use a colon-definition approach:
    ; We'll define do_colon as a hand-assembled colon word.
    ; This requires do_docol to be nearby... or use do_docol_far.
    ; Since we're IN a primitive, let's manually call CREATE.

    ; Save return info and call CREATE by setting up a mini thread
    ; Actually, the simplest approach: CREATE reads from UART and builds header.
    ; COLON does the same PLUS writes CFA + sets STATE.
    ; Rather than duplicating, let's store a return address and jump.

    ; Use data stack for return: push address of colon_after_create, jmp do_create
    ; But do_create uses NEXT to return, so it would follow IP, not our return addr.
    ;
    ; Alternative: set IP to point to a mini thread: [do_create, colon_continue]
    ; and let NEXT drive it.
    la r0, colon_thread
    lw r2, 0(r1)        ; restore original IP... wait, I already saved it.
    ; Actually, I want to save original IP, replace IP with colon_thread, do NEXT.
    ; Original IP is already on RS from the first sw.
    ; Set IP to colon_thread:
    la r2, colon_thread
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; Helper thread for COLON: CREATE header, write CFA template, set
; HIDDEN on new entry (SMUDGE bit — so `;` at end of the definition
; doesn't trip on the still-being-compiled entry), enter compile mode.
colon_thread:
    .word do_create
    .word do_colon_cfa
    .word do_hide_latest   ; set HIDDEN bit so FIND skips the in-progress entry
    .word do_rbrac         ; enter compile mode
    .word do_exit          ; return to original IP (saved on RS by do_colon)

; Set HIDDEN (bit 6) on LATEST's flags_len byte. Called from colon_thread.
; Also usable as a standalone primitive (entry_hide_latest below).
do_hide_latest:
    add r1, -3
    sw r2, 0(r1)         ; save IP
    la r0, var_latest_val
    lw r0, 0(r0)         ; r0 = latest entry addr
    add r0, 3            ; r0 = addr of flags_len
    lbu r2, 0(r0)        ; r2 = flags_len
    push r0              ; save addr
    lcu r0, 64
    or r2, r0            ; set bit 6
    pop r0
    sb r2, 0(r0)
    lw r2, 0(r1)         ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; Clear HIDDEN (bit 6) on LATEST's flags_len byte. Called by do_semi
; below and exposed as an UNHIDE-LATEST primitive for Forth `;`.
do_unhide_latest:
    add r1, -3
    sw r2, 0(r1)
    la r0, var_latest_val
    lw r0, 0(r0)
    add r0, 3
    lbu r2, 0(r0)
    push r0
    lcu r0, 191          ; 0xBF = ~0x40 in 8-bit
    and r2, r0
    pop r0
    sb r2, 0(r0)
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; Helper: write 6-byte CFA at HERE
; Writes: push r0 (0x7D), la r0 opcode (0x29), do_docol_far addr (3B), jmp r0 (0x26)
do_colon_cfa:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    ; Load HERE
    la r0, var_here_val
    lw r2, 0(r0)        ; r2 = HERE (dest)
    ; Copy 6 bytes from cfa_template
    la r0, cfa_template
    push r0              ; save template addr
    lw r0, 0(r0)        ; first 3 bytes
    sw r0, 0(r2)        ; store at HERE
    add r2, 3
    pop r0               ; template addr
    add r0, 3
    lw r0, 0(r0)        ; next 3 bytes
    sw r0, 0(r2)        ; store at HERE+3
    add r2, 3
    ; Update HERE (+6)
    la r0, var_here_val
    sw r2, 0(r0)
    ; Restore IP and NEXT
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; Template for far colon CFA (6 bytes):
; push r0 (0x7D), la r0 (0x29), addr_lo, addr_mid, addr_hi, jmp(r0) (0x26)
cfa_template:
    .byte 125            ; push r0
    .byte 41             ; la r0 opcode
    .word do_docol_far   ; 3-byte address of do_docol_far
    .byte 38             ; jmp (r0)

; ------------------------------------------------------------
; ; ( -- ) : End colon definition [IMMEDIATE]
; Compiles EXIT, enters interpret mode
; ------------------------------------------------------------
entry_semi:
    .word entry_colon
    .byte 129
    .byte 59
do_semi:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    ; Compile EXIT at HERE
    la r0, var_here_val
    lw r2, 0(r0)        ; r2 = HERE
    la r0, do_exit
    sw r0, 0(r2)        ; mem[HERE] = do_exit
    add r2, 3
    la r0, var_here_val
    sw r2, 0(r0)        ; update HERE
    ; Clear HIDDEN on LATEST (complementary to do_colon's HIDE)
    la r0, var_latest_val
    lw r0, 0(r0)
    add r0, 3
    lbu r2, 0(r0)
    push r0
    lcu r0, 191          ; ~0x40 in 8-bit
    and r2, r0
    pop r0
    sb r2, 0(r0)
    ; STATE = 0 (interpreting)
    la r0, var_state_val
    lc r2, 0
    sw r2, 0(r0)
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; ,DOCOL ( -- ) : Emit the 6-byte far-CFA template at HERE,
; advance HERE by 6. Exposes the colon-def CFA template that asm `:`
; uses internally (do_colon_cfa) so Forth-defined `:` in
; core/runtime.fth can build new colon headers without asm support.
; ------------------------------------------------------------
entry_comma_docol:
    .word entry_semi
    .byte 6
    .byte 44, 68, 79, 67, 79, 76    ; ",DOCOL"
do_comma_docol:
    la r0, do_colon_cfa
    jmp (r0)

; ------------------------------------------------------------
; IMMEDIATE ( -- ) : Toggle IMMEDIATE flag on most recent word
; ------------------------------------------------------------
entry_immediate:
    .word entry_comma_docol
    .byte 9
    .byte 73, 77, 77, 69, 68, 73, 65, 84, 69
do_immediate:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    la r0, var_latest_val
    lw r0, 0(r0)        ; r0 = latest entry
    add r0, 3           ; r0 = address of flags_len
    lbu r2, 0(r0)       ; r2 = flags_len
    push r0              ; save flags address
    lcu r0, 128
    xor r2, r0           ; toggle bit 7
    pop r0               ; r0 = flags address
    sb r2, 0(r0)        ; store updated flags
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Phase 4: LED!, DOT, interpret-only shell
; ============================================================

; ------------------------------------------------------------
; LED! ( n -- ) : Write low bit of n to LED register at 0xFF0000
; ------------------------------------------------------------
entry_led_store:
    .word entry_immediate
    .byte 4
    .byte 76, 69, 68, 33   ; "LED!"
do_led_store:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    pop r0               ; n
    lcu r2, 1
    and r0, r2           ; mask to low bit
    la r2, -65536        ; 0xFF0000 LED register
    sb r0, 0(r2)
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; SW? ( -- n ) : Read switch S2 (0=pressed, 1=released)
; Reads bit 0 of 0xFF0000 (same pin as LED, active-low pull-up)
; ------------------------------------------------------------
entry_sw_fetch:
    .word entry_led_store
    .byte 3
    .byte 83, 87, 63       ; "SW?"
do_sw_fetch:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    la r0, -65536        ; 0xFF0000
    lbu r0, 0(r0)       ; read byte
    lcu r2, 1
    and r0, r2           ; mask to bit 0
    push r0
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; NUMBER ( c-addr -- n flag ) : Parse counted string as number
; flag=0 success, flag=-1 failure. Handles leading '-'.
; Pure assembly, no sub-calls. Uses RS for locals.
; RS frame: [sign, acc, ptr, rem, saved_IP]
; (`.` is defined in Forth, see core/midlevel.fth.)
; ------------------------------------------------------------
entry_number:
    .word entry_sw_fetch
    .byte 6
    .byte 78, 85, 77, 66, 69, 82
do_number:
    add r1, -3
    sw r2, 0(r1)        ; RS: [IP]
    pop r0               ; r0 = c-addr
    lbu r2, 0(r0)       ; r2 = length
    ceq r2, z
    brf num_have_len
    ; Zero length = failure
    lc r0, 0
    push r0
    lc r0, -1
    push r0
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

num_have_len:
    ; Build RS frame: [sign, acc, ptr, rem, IP]
    ; Currently RS: [IP], r0=c-addr, r2=length
    add r0, 1           ; r0 = first data char
    add r1, -3
    sw r2, 0(r1)        ; rem. RS: [rem, IP]
    add r1, -3
    sw r0, 0(r1)        ; ptr. RS: [ptr, rem, IP]
    lc r0, 0
    add r1, -3
    sw r0, 0(r1)        ; acc=0. RS: [acc, ptr, rem, IP]

    ; Check leading '-'
    lw r0, 3(r1)        ; ptr
    lbu r0, 0(r0)       ; first char
    lcu r2, 45           ; '-'
    ceq r0, r2
    brf num_no_neg
    ; Negative sign
    lc r0, -1
    add r1, -3
    sw r0, 0(r1)        ; sign=-1. RS: [sign, acc, ptr, rem, IP]
    lw r0, 6(r1)        ; ptr
    add r0, 1
    sw r0, 6(r1)        ; ptr++
    lw r0, 9(r1)        ; rem
    add r0, -1
    sw r0, 9(r1)        ; rem--
    ceq r0, z
    brf num_digit_loop
    ; Bare '-' = fail
    la r0, num_fail
    jmp (r0)

num_no_neg:
    lc r0, 1
    add r1, -3
    sw r0, 0(r1)        ; sign=1. RS: [sign, acc, ptr, rem, IP]

num_digit_loop:
    ; RS: [sign(0), acc(3), ptr(6), rem(9), IP(12)]
    lw r0, 9(r1)        ; rem
    ceq r0, z
    brf num_not_done
    la r0, num_done
    jmp (r0)
num_not_done:
    lw r0, 6(r1)        ; ptr
    lbu r0, 0(r0)       ; char

    ; Convert ASCII to digit: '0'-'9' → 0-9
    lcu r2, 48           ; '0'
    clu r0, r2           ; C = (char < '0')
    brf num_ge_0
    la r0, num_fail
    jmp (r0)
num_ge_0:
    lcu r2, 58           ; '9'+1
    clu r0, r2           ; C = (char <= '9')
    brf num_try_hex
    ; Decimal digit 0-9
    lcu r2, 48
    sub r0, r2           ; digit = char - '0'
    bra num_is_digit
num_try_hex:
    ; Try A-F
    lcu r2, 65           ; 'A'
    clu r0, r2
    brt num_try_lower    ; char < 'A', try lowercase
    lcu r2, 71           ; 'F'+1
    clu r0, r2
    brf num_try_lower    ; char > 'F', try lowercase
    lcu r2, 55           ; 'A' - 10
    sub r0, r2           ; digit = char - 'A' + 10
    bra num_is_digit
num_try_lower:
    lcu r2, 97           ; 'a'
    clu r0, r2
    brt num_not_hex      ; char < 'a'
    lcu r2, 103          ; 'f'+1
    clu r0, r2
    brf num_not_hex      ; char > 'f'
    lcu r2, 87           ; 'a' - 10
    sub r0, r2           ; digit = char - 'a' + 10
    bra num_is_digit
num_not_hex:
    la r0, num_fail
    jmp (r0)

num_is_digit:
    ; r0 = digit value (0-9 for decimal, 10-15 for hex)

    ; acc = acc * BASE + digit
    ; Multiply acc by BASE using repeated addition
    ; Save digit
    add r1, -3
    sw r0, 0(r1)        ; RS: [digit, sign, acc, ptr, rem, IP]
    ; acc is at offset 6, BASE from var
    la r0, var_base_val
    lw r0, 0(r0)        ; r0 = BASE
    lw r2, 6(r1)        ; r2 = acc
    ; result = 0, add acc BASE times
    add r1, -3
    sw r0, 0(r1)        ; save BASE counter. RS: [basectr, digit, sign, acc, ...]
    lc r0, 0
    add r1, -3
    sw r0, 0(r1)        ; result=0. RS: [result, basectr, digit, sign, acc, ...]

num_mul_loop:
    lw r0, 3(r1)        ; basectr
    ceq r0, z
    brt num_mul_done
    lw r0, 0(r1)        ; result
    add r0, r2           ; result += acc
    sw r0, 0(r1)
    lw r0, 3(r1)        ; basectr
    add r0, -1
    sw r0, 3(r1)
    bra num_mul_loop

num_mul_done:
    lw r0, 0(r1)        ; result = acc * BASE
    lw r2, 6(r1)        ; digit
    add r0, r2           ; new_acc = result + digit
    add r1, 9           ; pop result, basectr, digit
    ; RS: [sign, acc, ptr, rem, IP]
    sw r0, 3(r1)        ; acc = new_acc

    ; Advance ptr, decrement rem
    lw r0, 6(r1)
    add r0, 1
    sw r0, 6(r1)
    lw r0, 9(r1)
    add r0, -1
    sw r0, 9(r1)
    la r0, num_digit_loop
    jmp (r0)

num_fail:
    ; RS: [sign, acc, ptr, rem, IP]
    lw r2, 12(r1)       ; IP
    add r1, 15
    lc r0, 0
    push r0              ; n=0
    lc r0, -1
    push r0              ; flag=-1 (fail)
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

num_done:
    ; RS: [sign(0), acc(3), ptr(6), rem(9), IP(12)]
    lw r0, 3(r1)        ; acc
    lw r2, 0(r1)        ; sign
    cls r2, z            ; C = (sign < 0)
    brf num_pos
    ; Negate
    push r0
    lc r0, 0
    pop r2
    sub r0, r2           ; r0 = -acc
num_pos:
    lw r2, 12(r1)       ; IP
    add r1, 15
    push r0              ; n
    lc r0, 0
    push r0              ; flag=0 (success)
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; INTERPRET ( -- ) : Interpret-only text interpreter
; Monolithic primitive. No compile mode.
; Reads tokens with WORD, tries FIND then NUMBER.
; Found → EXECUTE. Number → leave on stack. Else → print "? "
;
; Architecture: INTERPRET is a primitive that internally calls
; WORD, FIND, NUMBER by directly jumping to their code entries.
; Each sub-primitive returns via NEXT which follows IP.
; INTERPRET chains them using small thread fragments.
;
; The key rule: at each "continuation point" (the handler primitive
; that runs after WORD/FIND/NUMBER), RS contains exactly [caller_IP].
; No nested continuations.
; ------------------------------------------------------------
entry_interpret:
    .word entry_number
    .byte 9
    .byte 73, 78, 84, 69, 82, 80, 82, 69, 84

do_interpret:
    add r1, -3
    sw r2, 0(r1)        ; RS: [caller_IP]
    ; Start: call WORD
    la r2, i_word_thread
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

i_word_thread:
    .word do_word
    .word do_i_after_word

; After WORD: DS has [c-addr]. Check if empty.
do_i_after_word:
    ; IP points past this in i_word_thread — we ignore it.
    ; RS: [caller_IP] (WORD saved/restored its own IP on RS)
    pop r0               ; c-addr
    lbu r2, 0(r0)       ; length
    ceq r2, z
    brf i_have_token
    ; Empty token → end of input, return to caller
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

i_have_token:
    ; r0 = c-addr, push for FIND
    push r0
    la r2, i_find_thread
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

i_find_thread:
    .word do_find
    .word do_i_after_find

; After FIND: DS has (c-addr 0) or (cfa flag)
do_i_after_find:
    ; RS: [caller_IP]
    pop r0               ; flag (0=not found, 1=IMMEDIATE, -1=normal)
    ceq r0, z
    brt i_not_found

    ; Found: DS has [cfa], r0 = flag
    ; Check STATE
    add r1, -3
    sw r0, 0(r1)        ; save flag. RS: [flag, caller_IP]
    la r0, var_state_val
    lw r0, 0(r0)        ; r0 = STATE
    ceq r0, z
    brt i_found_exec_interp ; STATE=0 → interpreting → always execute

    ; Compiling (STATE != 0): check IMMEDIATE flag
    lw r0, 0(r1)        ; flag
    add r1, 3           ; pop flag. RS: [caller_IP]
    lcu r2, 1
    ceq r0, r2           ; C = (flag == 1 = IMMEDIATE)
    brt i_found_exec     ; IMMEDIATE → execute even in compile mode

    ; Normal word + compile mode → COMMA the CFA
    ; DS: [cfa]
    la r2, i_comma_continue
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

i_comma_continue:
    .word do_comma       ; compile the CFA
    .word do_word        ; get next token
    .word do_i_after_word

i_found_exec:
    ; Execute the word. DS: [cfa]
    ; Clean RS if flag is still there (STATE=0 path)
    ; STATE=0 path: RS = [flag, caller_IP], need to pop flag
    ; IMMEDIATE path: RS = [caller_IP], flag already popped
    ; To unify: check RS. Actually, let me use separate labels.
    ; The STATE=0 branch jumps here with RS: [flag, caller_IP]
    ; The IMMEDIATE branch jumps here with RS: [caller_IP]
    ; I need to know which path. Use a flag or separate labels.
    bra i_do_exec        ; IMMEDIATE path (flag already popped)

i_found_exec_interp:
    ; STATE=0 path: RS: [flag, caller_IP]
    add r1, 3           ; pop flag. RS: [caller_IP]

i_do_exec:
    la r2, i_continue
    pop r0               ; cfa
    jmp (r0)             ; execute — NEXT will use IP=i_continue

i_continue:
    .word do_word
    .word do_i_after_word

i_not_found:
    ; DS: [c-addr] (FIND returned it unchanged)
    ; Try NUMBER. Dup for error reporting.
    pop r0
    push r0
    push r0              ; DS: [c-addr, c-addr]
    la r2, i_num_thread
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

i_num_thread:
    .word do_number
    .word do_i_after_number

; After NUMBER: DS has [flag, n, c-addr]
do_i_after_number:
    ; RS: [caller_IP]
    pop r0               ; flag (0=ok)
    ceq r0, z
    brt i_num_ok
    ; Failed: print "? ", discard n and c-addr
    pop r0               ; discard n
    pop r0               ; discard c-addr
    ; Print "? "
    lc r0, 63
    push r0
    la r2, -65280
i_err1:
    lb r0, 1(r2)
    cls r0, z
    brt i_err1
    pop r0
    sb r0, 0(r2)
    lc r0, 32
    push r0
i_err2:
    lb r0, 1(r2)
    cls r0, z
    brt i_err2
    pop r0
    sb r0, 0(r2)
    ; Continue loop
    la r2, i_continue
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

i_num_ok:
    ; DS: [n, c-addr]. Keep n, discard c-addr
    pop r2               ; n
    pop r0               ; discard c-addr
    push r2              ; DS: [n]

    ; Check STATE
    la r0, var_state_val
    lw r0, 0(r0)
    ceq r0, z
    brt i_num_interp     ; STATE=0 → leave on stack, continue

    ; Compiling: compile LIT, n
    ; DS: [n]. Need to compile do_lit then n.
    ; First push do_lit address, comma it, then push n, comma it.
    pop r0               ; n
    add r1, -3
    sw r0, 0(r1)        ; save n on RS. RS: [n, caller_IP]
    la r0, do_lit
    push r0              ; DS: [do_lit_addr]
    la r2, i_compile_lit_thread
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

i_compile_lit_thread:
    .word do_comma       ; compile do_lit address
    .word do_i_compile_n

do_i_compile_n:
    ; RS: [n, caller_IP]
    lw r0, 0(r1)        ; n
    add r1, 3           ; pop n. RS: [caller_IP]
    push r0              ; DS: [n] for comma
    ; Comma n, then continue loop
    la r2, i_comma_continue
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

i_num_interp:
    ; Interpreting: n already on stack, continue loop
    la r2, i_continue
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; QUIT ( -- ) : Outer interpreter loop
; Resets RS, calls INTERPRET, prints " ok\n", loops.
; ------------------------------------------------------------
entry_quit:
    .word entry_interpret
    .byte 4
    .byte 81, 85, 73, 84

do_quit:
    la r1, 983040       ; reset RSP
    la r2, quit_thread
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

quit_thread:
    .word do_interpret
    .word do_quit_ok
    .word do_quit_restart

do_quit_ok:
    add r1, -3
    sw r2, 0(r1)
    ; Data stack underflow check: if sp > sp_base, stack went below empty
    mov fp, sp
    push fp
    pop r0               ; r0 = current sp
    la r2, var_sp_base
    lw r2, 0(r2)         ; r2 = sp_base
    clu r2, r0           ; C = (sp_base < sp) → underflow
    brf qok_no_underflow
    la r0, stack_underflow_err
    jmp (r0)
qok_no_underflow:
    la r0, var_state_val
    lw r0, 0(r0)
    ceq r0, z
    brf quit_no_ok
    ; Print " ok\n"
    la r2, -65280
    lc r0, 32
    push r0
quit_ok1:
    lb r0, 1(r2)
    cls r0, z
    brt quit_ok1
    pop r0
    sb r0, 0(r2)
    lc r0, 111
    push r0
quit_ok2:
    lb r0, 1(r2)
    cls r0, z
    brt quit_ok2
    pop r0
    sb r0, 0(r2)
    lc r0, 107
    push r0
quit_ok3:
    lb r0, 1(r2)
    cls r0, z
    brt quit_ok3
    pop r0
    sb r0, 0(r2)
    lc r0, 10
    push r0
quit_ok4:
    lb r0, 1(r2)
    cls r0, z
    brt quit_ok4
    pop r0
    sb r0, 0(r2)
quit_no_ok:
    lw r2, 0(r1)
    add r1, 3
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

do_quit_restart:
    la r1, 983040
    la r2, quit_thread
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; stack_underflow_err: shared handler for DS underflow.
; Resets DS (sp = sp_base), RS, STATE; prints "? "; restarts QUIT.
; Not a Forth word — jumped to from primitives and do_quit_ok.
; ------------------------------------------------------------
stack_underflow_err:
    ; Reset DS
    la r0, var_sp_base
    lw r0, 0(r0)
    push r0
    pop fp               ; fp = sp_base
    mov sp, fp           ; sp = sp_base
    ; Reset RS
    la r1, 983040
    ; Reset STATE to interpret (0), so a partial colon def is abandoned
    la r2, var_state_val
    lc r0, 0
    sw r0, 0(r2)
    ; Print "? "
    la r2, -65280
    lc r0, 63            ; '?'
    push r0
sue1:
    lb r0, 1(r2)
    cls r0, z
    brt sue1
    pop r0
    sb r0, 0(r2)
    lc r0, 32            ; ' '
    push r0
sue2:
    lb r0, 1(r2)
    cls r0, z
    brt sue2
    pop r0
    sb r0, 0(r2)
    ; Restart outer loop
    la r0, do_quit
    jmp (r0)

; ============================================================
; Phase 4b: Debugging and Convenience Words
; ============================================================

; CR / SPACE / HEX / DECIMAL / . / DEPTH / .S moved to core/*.fth.
; The data-stack pointer is exposed via SP@ below so DEPTH and .S can
; be implemented in Forth.

; ------------------------------------------------------------
; SP@ ( -- sp ) : Push the value of the data stack pointer that the
; caller saw at the moment SP@ was invoked. (The push itself decrements
; sp by 3; the value left on top is sp BEFORE the push.) Used by the
; Forth-level DEPTH and .S in core/highlevel.fth.
; ------------------------------------------------------------
entry_sp_fetch:
    .word entry_quit
    .byte 3
    .byte 83, 80, 64        ; "SP@"
do_sp_fetch:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    mov fp, sp
    push fp
    pop r0               ; r0 = sp value at primitive entry (push/pop net-zero)
    push r0              ; push sp value onto DS
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; SP! ( addr -- ) : Set data stack pointer to addr. `pop r0` reads
; addr first (from current TOS), then `mov sp, r0` installs it as
; the new sp. Anything between the old sp and the new sp is now
; "off stack"; the caller is responsible for having put addr
; somewhere sensible (typically computed from SP@).
; ------------------------------------------------------------
entry_sp_store:
    .word entry_sp_fetch
    .byte 3
    .byte 83, 80, 33        ; "SP!"
do_sp_store:
    pop r0               ; r0 = new sp
    mov sp, r0           ; sp := new sp
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; RP@ ( -- addr ) : Push current return stack pointer (r1). Inside
; a colon def, RP@ returns the address of the caller's saved IP
; (because do_colon_cfa already pushed it). User code that said
; `x >R` and then `RP@` will see r1 pointing at *that colon's*
; saved IP, with x one cell deeper — so a Forth-level R@
; is `: R@ RP@ 3 + @ ;` to skip past the nested-call's own IP.
; ------------------------------------------------------------
entry_rp_fetch:
    .word entry_sp_store
    .byte 3
    .byte 82, 80, 64        ; "RP@"
do_rp_fetch:
    push r1              ; push r1 onto DS
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; RP! ( addr -- ) : Set return stack pointer (r1). Extremely
; dangerous — next NEXT will read the IP of the current primitive
; correctly (it's still in r2), but once this primitive returns to
; a colon context, EXIT will read from the new r1 location. Use
; only in matched pairs around RP manipulation.
; ------------------------------------------------------------
entry_rp_store:
    .word entry_rp_fetch
    .byte 3
    .byte 82, 80, 33        ; "RP!"
do_rp_store:
    pop r0               ; r0 = new r1
    mov r1, r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; `\` / `(` / IF / THEN / ELSE / BEGIN / UNTIL — moved to core/minimal.fth
; ============================================================
; These IMMEDIATE words are now defined in Forth. The kernel only
; retains the helpers they need: BRANCH, 0BRANCH, KEY, EOL!, and [']
; (defined below).

; ------------------------------------------------------------
; EOL! ( -- ) : Force next WORD call to return an empty token.
; Used by Forth-defined `\` to signal end-of-line to QUIT after
; the newline has been consumed via KEY.
; ------------------------------------------------------------
entry_eol_store:
    .word entry_rp_store    ; was entry_sp_fetch before SP!/RP@/RP! added
    .byte 4
    .byte 69, 79, 76, 33     ; "EOL!"
do_eol_store:
    add r1, -3
    sw r2, 0(r1)         ; save IP (r2 clobbered below)
    la r0, word_eol_flag
    lc r2, 1
    sb r2, 0(r0)
    lw r2, 0(r1)         ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; ['] ( -- ) : At compile time, read next word, look up its CFA,
; and compile `LIT cfa` into the current definition [IMMEDIATE].
; Used by core.fth's IF/THEN/ELSE/UNTIL to embed BRANCH/0BRANCH CFAs.
; ------------------------------------------------------------
entry_tick:
    .word entry_eol_store
    .byte 0x83           ; length=3 + IMMEDIATE
    .byte 91, 39, 93     ; "[']"
tick_word_cfa:
    push r0
    la r0, do_docol_far
    jmp (r0)
    .word do_word        ; ( -- c-addr )
    .word do_find        ; ( c-addr -- cfa flag )  [assumes word is found]
    .word do_drop        ; drop flag, leaves cfa on DS
    .word do_lit
    .word do_lit         ; push address of do_lit itself
    .word do_comma       ; compile do_lit into current def
    .word do_comma       ; compile the CFA that was on DS
    .word do_exit

; ============================================================
; DO/LOOP runtime primitives (used by IMMEDIATE DO/LOOP/?DO in
; core/midlevel.fth). RS layout while inside a DO-loop body:
;   top:       [ index        ]
;              [ limit        ]
;   deeper:    [ caller's IP  ]
; So EXIT inside a loop corrupts the return unless UNLOOP runs
; first. That matches standard Forth.
; ============================================================

; (DO) ( limit start -- )  ( R: -- limit index )
entry_paren_do:
    .word entry_tick
    .byte 4
    .byte 40, 68, 79, 41        ; "(DO)"
do_paren_do:
    ; DS: ( limit start -- ). Reserve 2 RS cells, write index
    ; (from start) at 0(r1) and limit at 3(r1). We pop start first
    ; so it goes in as index; then pop limit above it. `sw fp` isn't
    ; available on this ISA, so we only write through r0.
    pop r0                   ; r0 = start
    add r1, -6               ; reserve limit+index on RS
    sw r0, 0(r1)             ; index (=start)
    pop r0                   ; r0 = limit
    sw r0, 3(r1)             ; limit
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; (LOOP) — thread: [do_paren_loop][offset]
; Increment index, compare against limit:
;   == → drop limit+index, skip offset, fall through
;   != → write new index, IP += offset (branch back)
entry_paren_loop:
    .word entry_paren_do
    .byte 6
    .byte 40, 76, 79, 79, 80, 41    ; "(LOOP)"
do_paren_loop:
    ; RS: [index][limit][caller IP]. Stash IP in fp via push/pop so
    ; r2 is free as a scratch compare register (ceq on this ISA needs
    ; both operands to be r0/r1/r2/z).
    push r2
    pop fp                   ; fp = saved IP
    lw r0, 0(r1)             ; r0 = index
    add r0, 1
    sw r0, 0(r1)             ; write new index back
    lw r2, 3(r1)             ; r2 = limit
    ceq r0, r2               ; C = (new index == limit)
    brt ploop_done
    push fp
    pop r2                   ; restore IP
    lw r0, 0(r2)             ; r0 = signed back-offset
    add r2, r0
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)
ploop_done:
    push fp
    pop r2                   ; restore IP
    add r1, 6                ; drop limit+index from RS
    add r2, 3                ; skip offset cell
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; (?DO) ( limit start -- )  ( R: -- [limit index] )
; Thread: [do_paren_qdo][fwd_offset]
; If start == limit: skip loop body (IP += fwd_offset).
; Else: push limit+index to RS, skip the fwd_offset cell, fall through.
entry_paren_qdo:
    .word entry_paren_loop
    .byte 5
    .byte 40, 63, 68, 79, 41    ; "(?DO)"
do_paren_qdo:
    ; DS: ( limit start -- ). Same ISA constraints as (LOOP): we stash
    ; IP in fp so r0 and r2 are both free for the compare.
    push r2
    pop fp                   ; fp = saved IP
    pop r0                   ; r0 = start
    pop r2                   ; r2 = limit
    ceq r0, r2
    brt qdo_skip
    add r1, -3
    sw r2, 0(r1)             ; push limit
    add r1, -3
    sw r0, 0(r1)             ; push index (=start)
    push fp
    pop r2                   ; restore IP
    add r2, 3                ; skip fwd_offset
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)
qdo_skip:
    push fp
    pop r2                   ; restore IP
    lw r0, 0(r2)             ; r0 = fwd_offset
    add r2, r0
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; I ( -- index )  push current loop index (RS top).
entry_i:
    .word entry_paren_qdo
    .byte 1
    .byte 73                 ; "I"
do_i:
    lw r0, 0(r1)
    push r0
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; UNLOOP ( -- )  ( R: limit index -- )  drop loop state from RS,
; restoring the caller's IP to RS top. Must precede EXIT inside
; a DO-loop.
entry_unloop:
    .word entry_i
    .byte 6
    .byte 85, 78, 76, 79, 79, 80    ; "UNLOOP"
do_unloop:
    add r1, 6
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; BYE ( -- ) : Halt the CPU
; ------------------------------------------------------------
entry_bye:
    .word entry_unloop
    .byte 3
    .byte 66, 89, 69        ; "BYE"
do_bye:
    bra do_bye

; ============================================================
; System Variable Storage
; ============================================================
var_here_val:
    .word 0
var_latest_val:
    .word 0
var_state_val:
    .word 0
var_base_val:
    .word 10
var_sp_base:
    .word 0             ; snapshot of initial sp taken at _start

; ============================================================
; compute_hash: 2-Round 24-bit XMX hash over a counted name.
;
; Per docs/hashing.txt's recommendation for 24-bit GPR ISAs.
; Per character:
;   h = h XOR char
;   h = h * MAGIC        ; 24-bit truncation is native (mul)
;   h = h XOR (h SRL 12) ; spread high bits into low
; bucket = h & 0xFF
;
; MAGIC = 0xDEADB5 = 14,592,437
;
; Inputs via fixed memory cells:
;   hash_arg_ptr — address of first name byte
;   hash_arg_len — length of name (0-63)
; Output:
;   hash_result  — bucket index (0-255)
; Control:
;   hash_ret_addr — caller sets; subroutine jumps to this on exit
;
; Collision count on our 90-word dict at 256 buckets: 15
; (vs 11 for len-seeded mult33, 47 for first_char).
; See scripts/hash-collision-analysis.py and docs/hashing-analysis.md.
; ============================================================
compute_hash:
    la r0, hash_arg_ptr
    lw r0, 0(r0)         ; r0 = ptr
    la r2, hash_arg_len
    lw r2, 0(r2)         ; r2 = length
    add r1, -3
    sw r0, 0(r1)         ; RS: [ptr]
    add r1, -3
    sw r2, 0(r1)         ; RS: [remlen, ptr]
    ; h = 0 (XMX starts with no seed)
    lc r0, 0
ch_loop:
    lw r2, 0(r1)         ; r2 = remlen
    ceq r2, z
    brt ch_done
    ; Save h, read char at ptr
    add r1, -3
    sw r0, 0(r1)         ; RS: [h, remlen, ptr]
    lw r0, 6(r1)         ; r0 = ptr (at RS offset 6)
    lbu r2, 0(r0)        ; r2 = char
    lw r0, 0(r1)         ; r0 = h
    add r1, 3            ; pop h. RS: [remlen, ptr]

    ; XMX round: h = (h ^ char) * MAGIC; h ^= h >> 12
    xor r0, r2           ; r0 = h ^ char
    la r2, 14592437      ; r2 = MAGIC = 0xDEADB5
    mul r0, r2           ; r0 = (h^char) * MAGIC, 24-bit truncated
    add r1, -3
    sw r0, 0(r1)         ; stash h on RS
    la r2, 12
    srl r0, r2           ; r0 = h >> 12
    lw r2, 0(r1)         ; r2 = h (pre-shift)
    add r1, 3            ; pop
    xor r0, r2           ; r0 = h ^ (h >> 12)

    ; Advance ptr, decrement remlen
    lw r2, 3(r1)
    add r2, 1
    sw r2, 3(r1)
    lw r2, 0(r1)
    add r2, -1
    sw r2, 0(r1)
    bra ch_loop
ch_done:
    ; Save 24-bit hash for lookaside cache (before masking)
    la r2, hash_full
    sw r0, 0(r2)
    ; Mask to 8-bit bucket index
    lcu r2, 255
    and r0, r2
    la r2, hash_result
    sw r0, 0(r2)
    add r1, 6            ; pop [remlen, ptr]
    la r2, hash_ret_addr
    lw r2, 0(r2)
    jmp (r2)

; compute_hash's argument / return cells
hash_arg_ptr:
    .word 0
hash_arg_len:
    .word 0
hash_ret_addr:
    .word 0
hash_result:
    .word 0
hash_full:
    .word 0            ; 24-bit pre-mask hash (for lookaside cache key)

; ============================================================
; FIND lookaside cache (single entry, memento-pattern).
; Avoids the bucket-lookup + name-compare path for repeated-word
; lookups common in colon-def compilation. Key is the full 24-bit
; XMX hash (effectively collision-free for our dict; worst case =
; false positive that returns wrong CFA, mitigated by the high
; entropy of XMX).
; ============================================================
lookaside_hash:
    .word 0            ; 24-bit hash of cached name
lookaside_cfa:
    .word 0            ; cfa of cached entry; 0 = cache empty / invalid
lookaside_flag:
    .word 0            ; 1 = IMMEDIATE, -1 = normal

; ============================================================
; FIND hash table: 256 buckets × 3 bytes = 768 bytes.
; Bucket[c] holds the most-recent dict entry whose name starts
; with byte c. Populated at _start; maintained by do_create.
; ============================================================
dict_hash_table:
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0
dict_hash_table_end:

    .word do_exit

; ============================================================
; Test Data
; ============================================================

; Counted strings for FIND tests
cs_emit:
    .byte 4, 69, 77, 73, 84       ; "EMIT"
cs_plus:
    .byte 1, 43                     ; "+"

; EOL flag for WORD (1 byte)
word_eol_flag:
    .byte 0

; Word input buffer (32 bytes)
word_buffer:
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 0, 0, 0, 0

; ============================================================
test_thread:
    .word do_quit

; ============================================================
; End of dictionary — HERE initialized to this address
; ============================================================
dict_end:
