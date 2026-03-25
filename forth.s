; forth.s — tf24a DTC Forth: Phases 1-3 (bootstrap, threading, dictionary)
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

    ; Initialize system variables (r0, r2 free before Phase 1)
    la r2, entry_immediate
    la r0, var_latest_val
    sw r2, 0(r0)        ; LATEST = last dictionary entry
    la r2, dict_end
    la r0, var_here_val
    sw r2, 0(r0)        ; HERE = first free byte

    ; ============================================================
    ; Phase 1: Inline Tests — print "OK\n*\n"
    ; ============================================================

    ; Test 1: Data stack + UART — print "OK\n"
    lc r0, 10           ; '\n'
    push r0
    lc r0, 75           ; 'K'
    push r0
    lc r0, 79           ; 'O'
    push r0

    la r2, -65280       ; r2 = UART base (IP not needed yet)

    ; Emit 'O'
    pop r0
    push r0
tx1:
    lb r0, 1(r2)
    cls r0, z
    brt tx1
    pop r0
    sb r0, 0(r2)

    ; Emit 'K'
    pop r0
    push r0
tx2:
    lb r0, 1(r2)
    cls r0, z
    brt tx2
    pop r0
    sb r0, 0(r2)

    ; Emit '\n'
    pop r0
    push r0
tx3:
    lb r0, 1(r2)
    cls r0, z
    brt tx3
    pop r0
    sb r0, 0(r2)

    ; Test 2: Return stack — push 42, clear, pop, emit '*'
    lc r0, 42
    add r1, -3
    sw r0, 0(r1)
    lc r0, 0
    lw r0, 0(r1)
    add r1, 3

    push r0
tx4:
    lb r0, 1(r2)
    cls r0, z
    brt tx4
    pop r0
    sb r0, 0(r2)

    ; Emit '\n'
    lc r0, 10
    push r0
tx5:
    lb r0, 1(r2)
    cls r0, z
    brt tx5
    pop r0
    sb r0, 0(r2)

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
    .byte 67
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
; ------------------------------------------------------------
entry_branch:
    .word entry_lit
    .byte 70
    .byte 66, 82, 65, 78, 67, 72
do_branch:
    lw r0, 0(r2)        ; r0 = signed offset
    add r2, r0           ; IP += offset
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ------------------------------------------------------------
; 0BRANCH ( flag -- ) : Branch if TOS is zero [HIDDEN]
; ------------------------------------------------------------
entry_zbranch:
    .word entry_branch
    .byte 71
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

; - ( n1 n2 -- n1-n2 )
entry_minus:
    .word entry_plus
    .byte 1
    .byte 45
do_minus:
    add r1, -3
    sw r2, 0(r1)        ; save IP
    pop r2               ; r2 = n2
    pop r0               ; r0 = n1
    sub r0, r2           ; r0 = n1 - n2
    push r0
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; AND ( n1 n2 -- n1&n2 )
entry_and:
    .word entry_minus
    .byte 3
    .byte 65, 78, 68
do_and:
    add r1, -3
    sw r2, 0(r1)
    pop r2
    pop r0
    and r0, r2
    push r0
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; OR ( n1 n2 -- n1|n2 )
entry_or:
    .word entry_and
    .byte 2
    .byte 79, 82
do_or:
    add r1, -3
    sw r2, 0(r1)
    pop r2
    pop r0
    or r0, r2
    push r0
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; XOR ( n1 n2 -- n1^n2 )
entry_xor:
    .word entry_or
    .byte 3
    .byte 88, 79, 82
do_xor:
    add r1, -3
    sw r2, 0(r1)
    pop r2
    pop r0
    xor r0, r2
    push r0
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; = ( n1 n2 -- flag ) : -1 if equal, 0 otherwise
entry_equal:
    .word entry_xor
    .byte 1
    .byte 61
do_equal:
    add r1, -3
    sw r2, 0(r1)
    pop r2
    pop r0
    ceq r0, r2           ; C = (n1 == n2)
    lc r0, 0
    brf eq_done
    lc r0, -1
eq_done:
    push r0
    lw r2, 0(r1)
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; < ( n1 n2 -- flag ) : -1 if n1 < n2 signed, 0 otherwise
entry_less:
    .word entry_equal
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

; 0= ( n -- flag ) : -1 if zero, 0 otherwise
entry_zequ:
    .word entry_less
    .byte 2
    .byte 48, 61
do_zequ:
    pop r0
    ceq r0, z
    lc r0, 0
    brf zeq_done
    lc r0, -1
zeq_done:
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; ============================================================
; Stack Primitives
; ============================================================

; DROP ( x -- )
entry_drop:
    .word entry_zequ
    .byte 4
    .byte 68, 82, 79, 80
do_drop:
    pop r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; DUP ( x -- x x )
entry_dup:
    .word entry_drop
    .byte 3
    .byte 68, 85, 80
do_dup:
    pop r0
    push r0
    push r0
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; SWAP ( x1 x2 -- x2 x1 )
entry_swap:
    .word entry_dup
    .byte 4
    .byte 83, 87, 65, 80
do_swap:
    pop r0               ; x2
    pop fp               ; x1
    push r0              ; x2
    push fp              ; x1
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; OVER ( x1 x2 -- x1 x2 x1 )
entry_over:
    .word entry_swap
    .byte 4
    .byte 79, 86, 69, 82
do_over:
    pop r0               ; x2
    pop fp               ; x1
    push fp              ; x1
    push r0              ; x2
    push fp              ; x1 copy
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; >R ( x -- ) ( R: -- x )
entry_tor:
    .word entry_over
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

; R@ ( -- x ) ( R: x -- x )
entry_rfetch:
    .word entry_rfrom
    .byte 2
    .byte 82, 64
do_rfetch:
    lw r0, 0(r1)
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
    .word entry_rfetch
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
    pop r2               ; addr
    pop r0               ; value
    sw r0, 0(r2)
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
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
    pop r2               ; addr
    pop r0               ; byte value
    sb r0, 0(r2)
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
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
    pop r0
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

    ; Load LATEST and push on DS for find_loop
    la r0, var_latest_val
    lw r0, 0(r0)
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

    ; Init buffer pointer (past count byte)
    la r0, word_buffer
    add r0, 1
    add r1, -3
    sw r0, 0(r1)        ; RS: [buf_ptr, IP]

    ; --- Skip leading spaces/control chars (char <= 32) ---
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
    lcu r2, 33
    clu r0, r2           ; C = (char < 33) = space/ctrl
    brt word_skip        ; skip, read another
    bra word_store       ; got a real char
word_skip_rx2:
    la r0, -65280
    bra word_skip_rx

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

; Helper thread for COLON: CREATE, then colon_write_cfa
colon_thread:
    .word do_create
    .word do_colon_cfa
    .word do_rbrac       ; enter compile mode
    .word do_exit        ; return to original IP (saved on RS by do_colon)

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
; IMMEDIATE ( -- ) : Toggle IMMEDIATE flag on most recent word
; ------------------------------------------------------------
entry_immediate:
    .word entry_semi
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

; ============================================================
; Phase 2 Test Colon Definitions (using far CFA format)
; ============================================================

; : TEST  42 EMIT 10 EMIT ;   — prints "*\n"
test_word_cfa:
    push r0
    la r0, do_docol_far
    jmp (r0)
    .word do_lit
    .word 42
    .word do_emit
    .word do_lit
    .word 10
    .word do_emit
    .word do_exit

; : DOUBLE  DUP + ;
double_word:
    push r0
    la r0, do_docol_far
    jmp (r0)
    .word do_dup
    .word do_plus
    .word do_exit

; : MAIN  3 DOUBLE 48 + EMIT 10 EMIT ;   — prints "6\n"
main_word:
    push r0
    la r0, do_docol_far
    jmp (r0)
    .word do_lit
    .word 3
    .word double_word
    .word do_lit
    .word 48
    .word do_plus
    .word do_emit
    .word do_lit
    .word 10
    .word do_emit
    .word do_exit

; ============================================================
; Test Data
; ============================================================

; Counted strings for FIND tests
cs_emit:
    .byte 4, 69, 77, 73, 84       ; "EMIT"
cs_plus:
    .byte 1, 43                     ; "+"

; Word input buffer (32 bytes)
word_buffer:
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 0, 0, 0, 0

; ============================================================
; Test Thread
; ============================================================
test_thread:
    ; --- Phase 2 regression: prints "6\n*\n" ---
    .word main_word
    .word test_word_cfa

    ; --- Phase 3 Test A: FIND "EMIT" + EXECUTE → prints 'H' ---
    .word do_lit
    .word 72             ; 'H'
    .word do_lit
    .word cs_emit        ; address of counted string "EMIT"
    .word do_find
    .word do_drop        ; drop flag (-1)
    .word do_execute     ; execute EMIT → prints 'H'

    ; --- Phase 3 Test B: FIND "+" + EXECUTE → prints 'A' ---
    .word do_lit
    .word 40
    .word do_lit
    .word 25
    .word do_lit
    .word cs_plus        ; address of counted string "+"
    .word do_find
    .word do_drop        ; drop flag
    .word do_execute     ; execute + → 40+25=65
    .word do_emit        ; emit 65 = 'A'

    ; --- Phase 3 Test C: COMMA → prints '\n' ---
    .word do_here        ; push &var_here_val
    .word do_fetch       ; get HERE value
    .word do_dup         ; save a copy
    .word do_lit
    .word 10             ; newline
    .word do_comma       ; store 10 at HERE, HERE += 3
    .word do_fetch       ; read back from saved address → 10
    .word do_emit        ; emit 10 = '\n'

    .word do_halt

; ============================================================
; End of dictionary — HERE initialized to this address
; ============================================================
dict_end:
