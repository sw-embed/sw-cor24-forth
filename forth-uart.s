
; ============================================================
; forth-uart.s — stand-alone hardware layer for forth-core.s
; ============================================================
; Concatenated after forth-core.s by scripts/build-forth.sh to make forth.s,
; the kernel the web demo and the FPGA build run. This layer is the COR24
; board as the emulator and the hardware present it:
;   UART data at 0xFF0100 (-65280), status at 0xFF0101 (-65279)
;   TX busy = status bit 7, RX ready = status bit 0
;   return stack grows down from 0x0F0000
;   the dictionary grows from the end of this file, unbounded
;   BYE halts; branches are plain branches
; The contract these routines satisfy is at the end of forth-core.s.

; Entered from address 0 (forth_entry) before anything is set up.
_start:
layer_init:
    la r0, 983040       ; 0x0F0000 return stack base
    la r2, var_rstack_top
    sw r0, 0(r2)
    la r0, core_start
    jmp (r0)

; io_emit ( c -- ) : write the byte on top of the data stack, TX busy-wait.
; Return address on top of RS; preserves r2.
io_emit:
    add r1, -3
    sw r2, 0(r1)        ; save r2
    la r2, -65280       ; r2 = UART base
io_emit_poll:
    lb r0, 1(r2)        ; status (sign-extended; bit 7 → negative)
    cls r0, z           ; C = (status < 0) = TX busy
    brt io_emit_poll
    pop r0              ; the byte
    sb r0, 0(r2)        ; write byte to UART TX
    lw r2, 0(r1)
    add r1, 3           ; restore r2
    lw r0, 0(r1)
    add r1, 3           ; return address
    jmp (r0)

; io_key ( -- c ) : push the next UART byte, RX busy-wait.
; Return address on top of RS; preserves r2.
io_key:
    add r1, -3
    sw r2, 0(r1)        ; save r2
io_key_poll:
    la r0, -65280       ; UART base
    lbu r0, 1(r0)       ; status byte (zero-extended)
    lcu r2, 1           ; bit 0 mask
    and r0, r2          ; isolate RX ready bit
    ceq r0, z           ; C = (not ready)
    brt io_key_poll
    la r0, -65280       ; reload UART base
    lbu r0, 0(r0)       ; read byte
    push r0
    lw r2, 0(r1)
    add r1, 3           ; restore r2
    lw r0, 0(r1)
    add r1, 3           ; return address
    jmp (r0)

; io_bye : halt the CPU.
io_bye:
    bra io_bye

; This layer adds no words: the dictionary ends where the core's does.
layer_latest:
        .word   entry_last_core

; io_branch : body of BRANCH. r2 = IP at the offset cell.
io_branch:
    lw r0, 0(r2)        ; r0 = signed offset
    add r2, r0           ; IP += offset
    ; NEXT
    lw r0, 0(r2)
    add r2, 3
    jmp (r0)

; io_zbranch : body of 0BRANCH ( flag -- ). r2 = IP at the offset cell.
io_zbranch:
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
; End of the image — HERE starts here and the dictionary grows upward.
; Nothing may follow this label.
; ============================================================
dict_start:
