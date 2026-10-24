\ prims-asm.fth — the primitive section of forth-from-forth/kernel.s.
\
\ Written in the COR24 assembler vocabulary defined in
\ compiler/xcomp.fth (r0 r2 add,  r0 0 r2 lw,  r2 la: label,
\ l: label ...). scripts/build-image.sh loads it after XC-KERNEL-BEGIN,
\ so what it prints becomes the first part of kernel.s; the compiled
\ dictionary follows. Other compiler runs (tests) do not load it.
\ Converted once from the hand-written assembly on 2026-10-24; this
\ Forth is now the source.
\
\ Editing rules: keep KEY's busy-wait label key_poll (web-sw-cor24-forth
\ src/pump.rs POLL_LABELS must list it, or the web tab never feeds
\ input), and never write a backslash followed by n, r, t, x or 0
\ anywhere in this file: cor24-emu -u turns those into control bytes.
\ After editing, scripts/build-image.sh, then reg-rs.

\ ============================================================
\ Primitive section of kernel.s
\ ============================================================

\ forth.s — sw-cor24-forth DTC Forth: Phases 1-4 (bootstrap, threading, dictionary, interpreter)
\ COR24 DTC Forth kernel
\
\ Register allocation (frozen):
\ r0 = W (work/scratch)
\ r1 = RSP (return stack pointer, grows down from 0x0F0000)
\ r2 = IP (instruction pointer for threaded code)
\ sp = DSP (data stack, hardware push/pop in EBR)
\ fp = limited scratch (only pop/push/add-as-source work)
\
\ UART: data at 0xFF0100 (-65280), status at 0xFF0101 (-65279)
\ TX busy = status bit 7, RX ready = status bit 0
\
\ DTC NEXT (inlined at tail of every primitive, 5 bytes):
\ lw r0, 0(r2)    ; W = mem[IP] — fetch code address from thread
\ add r2, 3       ; IP += cell
\ jmp (r0)        ; execute code
\
\ Colon word CFA formats:
\ Near (hand-assembled, within 127B of do_docol):
\ bra do_docol     ; 2 bytes
\ .byte 0          ; 1 byte pad — PFA at CFA+3
\ Far (runtime-compiled or distant):
\ push r0          ; 1 byte — save CFA on data stack
\ la r0, do_docol_far ; 4 bytes
\ jmp (r0)         ; 1 byte — PFA at CFA+6
\
\ Dictionary header layout:
\ .word link    ; 3 bytes — link to previous entry (0 = end)
\ .byte flags   ; 1 byte — bit7=IMMEDIATE, bit6=HIDDEN, bits0-5=namelen
\ .byte c1..cN  ; N bytes — name characters
\ (CFA follows immediately: CFA = entry + 4 + namelen)

\ ============================================================
\ Entry point (address 0)
\ ============================================================
l: _start
  r1 983040 la#,   \ r1 = 0x0F0000 return stack base

\ Snapshot hardware-reset sp into var_sp_base for underflow checks
  fp sp mov,
  fp push,
  r0 pop,   \ r0 = initial sp (push/pop is net-zero on sp)
  r2 la: var_sp_base
  r0 0 r2 sw,

\ Initialize system variables (r0, r2 free before Phase 1)
  r2 la: fff_latest   \ LATEST init: newest compiled entry
  r2 0 r2 lw,
  r0 la: var_latest_val
  r2 0 r0 sw,   \ LATEST = last dictionary entry
  r2 la: dict_end
  r0 la: var_here_val
  r2 0 r0 sw,   \ HERE = first free byte

\ ============================================================
\ Populate the FIND hash table (256 buckets, indexed by first
\ char of name). Each bucket holds the most-recent entry whose
\ name starts with that byte. See do_find / do_create for use.
\ ============================================================
\ Zero table (256 × 3 bytes = 768 bytes).
\ Stash end-address on RS; r0 = ptr, r2 = value (0) each iter.
  r2 la: dict_hash_table_end
  r1 -3 addi,
  r2 0 r1 sw,   \ RS: [end_addr]
  r0 la: dict_hash_table
l: ht_zero_loop
  r2 0 lc,
  r2 0 r0 sw,   \ slot = 0
  r0 3 addi,
  r2 0 r1 lw,   \ r2 = end_addr
  r0 r2 clu,
  brt: ht_zero_loop
  r1 3 addi,   \ pop end_addr

\ Walk LATEST chain (newest→oldest). Set each bucket to the
\ NEWEST entry that hashes to it — only set a bucket if empty
\ (since we walk newest first). Uses compute_hash (len-seeded mult33).
  r0 la: var_latest_val
  r0 0 r0 lw,   \ r0 = newest entry
l: ht_pop_loop
  r0 z ceq,
  brt: ht_pop_done
  r0 push,   \ save entry on DS
\ hash_arg_ptr = entry + 4 (name start)
  r0 4 addi,
  r2 la: hash_arg_ptr
  r0 0 r2 sw,
\ hash_arg_len = (entry+3)[0] & 63 (mask flags bits)
  r0 pop,   \ r0 = entry
  r0 push,   \ put back on DS for later
  r0 3 r0 lbu,   \ flags_len
  r2 63 lcu,
  r0 r2 and,   \ length
  r2 la: hash_arg_len
  r0 0 r2 sw,
\ return addr
  r2 la: hash_ret_addr
  r0 la: ht_pop_after_hash
  r0 0 r2 sw,
  r0 la: compute_hash
  r0 jmp,
l: ht_pop_after_hash
\ DS: [entry]. hash_result holds the bucket.
  r0 la: hash_result
  r0 0 r0 lw,   \ r0 = bucket
  r2 3 lc,
  r0 r2 mul,   \ r0 = bucket * 3
  r1 -3 addi,
  r0 0 r1 sw,   \ stash offset on RS
  r0 la: dict_hash_table
  r2 0 r1 lw,
  r1 3 addi,
  r0 r2 add,   \ r0 = slot addr
  r2 0 r0 lw,   \ r2 = current slot
  r2 z ceq,
  brt: ht_pop_set
\ Slot already has a (newer-than-current) entry; skip.
  r0 pop,   \ restore entry
  r0 0 r0 lw,   \ follow link
  bra: ht_pop_loop
l: ht_pop_set
  r2 pop,   \ r2 = entry (from push r0)
  r2 0 r0 sw,   \ *slot = entry
  r0 0 r2 lw,   \ follow link
  bra: ht_pop_loop
l: ht_pop_done

\ ============================================================
\ Launch threaded code tests (Phase 2 + Phase 3)
\ ============================================================
  r2 la: test_thread   \ IP = start of test thread
\ NEXT — bootstrap into threaded execution
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ============================================================
\ DOCOL — shared entry for colon definitions
\ ============================================================

\ Near DOCOL: CFA is "bra do_docol; .byte 0" (3 bytes), r0 = CFA from NEXT
l: do_docol_far
  r1 -3 addi,
  r2 0 r1 sw,   \ push IP to return stack
  r2 pop,   \ r2 = CFA (from data stack)
  r2 6 addi,   \ r2 = PFA = CFA + 6
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ============================================================
\ Primitives with Dictionary Headers
\ ============================================================
\ Chain: entry_emit(link=0) → entry_key → ... → entry_immediate(LATEST)

\ ------------------------------------------------------------
\ EMIT ( c -- ) : Write character to UART with TX busy-wait
\ ------------------------------------------------------------
l: entry_emit
  0 w#
  4 b#
  69 b# 77 b# 73 b# 84 b#
l: do_emit
  r0 pop,   \ r0 = character
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP on return stack
  r1 -3 addi,
  r0 0 r1 sw,   \ save byte on return stack
  r2 -65280 la#,   \ r2 = UART base
l: emit_poll
  r0 1 r2 lb,   \ status (sign-extended; bit 7 → negative)
  r0 z cls,   \ C = (status < 0) = TX busy
  brt: emit_poll
  r0 0 r1 lw,   \ restore byte
  r1 3 addi,
  r0 0 r2 sb,   \ write byte to UART TX
  r2 0 r1 lw,   \ restore IP
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ KEY ( -- c ) : Read character from UART with RX busy-wait
\ ------------------------------------------------------------
l: entry_key
  w: entry_emit
  3 b#
  75 b# 69 b# 89 b#
l: do_key
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP on return stack
l: key_poll
  r0 -65280 la#,   \ UART base
  r0 1 r0 lbu,   \ status byte (zero-extended)
  r2 1 lcu,   \ bit 0 mask
  r0 r2 and,   \ isolate RX ready bit
  r0 z ceq,   \ C = (not ready)
  brt: key_poll
  r0 -65280 la#,   \ reload UART base
  r0 0 r0 lbu,   \ read byte
  r0 push,
  r2 0 r1 lw,   \ restore IP
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ EXIT ( -- ) : End colon definition, pop IP from return stack
\ ------------------------------------------------------------
l: entry_exit
  w: entry_key
  4 b#
  69 b# 88 b# 73 b# 84 b#
l: do_exit
  r2 0 r1 lw,   \ restore IP from return stack
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ LIT ( -- x ) : Push inline literal from thread [HIDDEN]
\ ------------------------------------------------------------
l: entry_lit
  w: entry_exit
  3 b#   \ unhidden (was 67 = HIDDEN|3) so Forth can ['] LIT
  76 b# 73 b# 84 b#
l: do_lit
  r0 0 r2 lw,   \ r0 = literal at IP
  r2 3 addi,   \ IP past literal
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ BRANCH ( -- ) : Unconditional relative branch [HIDDEN]
\ BRANCH ( -- ) : Unconditional relative branch (visible, used by IMMEDIATE
\ control-flow words defined in core.fth)
\ ------------------------------------------------------------
l: entry_branch
  w: entry_lit
  6 b#
  66 b# 82 b# 65 b# 78 b# 67 b# 72 b#
l: do_branch
  r0 0 r2 lw,   \ r0 = signed offset
  r2 r0 add,   \ IP += offset
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ 0BRANCH ( flag -- ) : Branch if TOS is zero (visible, used by IMMEDIATE
\ control-flow words defined in core.fth)
\ ------------------------------------------------------------
l: entry_zbranch
  w: entry_branch
  7 b#
  48 b# 66 b# 82 b# 65 b# 78 b# 67 b# 72 b#
l: do_zbranch
  r0 pop,   \ r0 = flag
  r0 z ceq,   \ C = (flag == 0)
  brt: zbr_take   \ if zero, take branch
  r2 3 addi,   \ skip offset cell
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,
l: zbr_take
  r0 0 r2 lw,   \ r0 = offset
  r2 r0 add,   \ IP += offset
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ============================================================
\ Arithmetic Primitives
\ ============================================================

\ + ( n1 n2 -- n1+n2 )
l: entry_plus
  w: entry_zbranch
  1 b#
  43 b#
l: do_plus
  fp pop,   \ fp = n2
  r0 pop,   \ r0 = n1
  r0 fp add,   \ r0 = n1 + n2
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ Subset 16: `*`, `-`, `/MOD` moved to Forth in core/lowlevel.fth
\ (and `-` in core/runtime.fth since minimal.fth uses it for offset
\ arithmetic). `+` stays asm — used everywhere and hardware `add` is
\ cheap. The old `*` used `mul r0, r2` (single-cycle on COR24); the
\ Forth version is a repeated-addition loop, asymptotically much
\ slower but still tractable within the fib demo's instruction budget.

\ NAND ( n1 n2 -- ~(n1&n2) )  — subset 15: replaces AND/OR/XOR.
\ Forth-level AND/OR/XOR/INVERT live in core/runtime.fth, derived via
\ classical NAND-gate identities (INVERT = a NAND a, AND = NAND then
\ INVERT, OR = DeMorgan, XOR = 4-NAND form).
l: entry_nand
  w: entry_plus   \ was entry_slashmod; */-/MOD now in Forth
  4 b#
  78 b# 65 b# 78 b# 68 b#   \ "NAND"
l: do_nand
  r1 -3 addi,
  r2 0 r1 sw,
  r2 pop,   \ r2 = n2
  r0 pop,   \ r0 = n1
  r0 r2 and,   \ r0 = n1 & n2
  r2 -1 la#,
  r0 r2 xor,   \ r0 = ~(n1 & n2)
  r0 push,
  r2 0 r1 lw,
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ = and 0= moved to core/lowlevel.fth (via XOR and IF/ELSE).
\ Only < remains as a primitive (needs signed compare `cls`).

\ < ( n1 n2 -- flag ) : -1 if n1 < n2 signed, 0 otherwise
l: entry_less
  w: entry_nand   \ was entry_xor; AND/OR/XOR now in Forth
  1 b#
  60 b#
l: do_less
  r1 -3 addi,
  r2 0 r1 sw,
  r2 pop,   \ n2
  r0 pop,   \ n1
  r0 r2 cls,   \ C = (n1 < n2) signed
  r0 0 lc,
  brf: lt_done
  r0 -1 lc,
l: lt_done
  r0 push,
  r2 0 r1 lw,
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ============================================================
\ Stack Primitives — subset 14B moved DUP/DROP/SWAP/OVER/R@ to
\ core/runtime.fth as Forth colon defs using SP@/SP!/RP@/@/!/>R/R>.
\ What remains in asm:
\ do_drop  — body only, no dict entry; called from tick_word_cfa
\ >R, R>   — full primitives. `>R` must atomically decrement r1
\ and store; R> mirrors. A Forth version would have
\ to preserve the outer colon's saved-IP slot, which
\ needs asm-level r1/r2 control.
\ ============================================================

\ do_drop: kept as an internal helper for tick_word_cfa (['])
\ — no dict entry, so the user-level DROP is the Forth version.
l: entry_tor
  w: entry_less
  2 b#
  62 b# 82 b#
l: do_tor
  r0 pop,
  r1 -3 addi,
  r0 0 r1 sw,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ R> ( -- x ) ( R: x -- )
l: entry_rfrom
  w: entry_tor
  2 b#
  82 b# 62 b#
l: do_rfrom
  r0 0 r1 lw,
  r1 3 addi,
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ============================================================
\ Memory Primitives
\ ============================================================

\ @ ( addr -- x ) : Fetch cell from address
l: entry_fetch
  w: entry_rfrom   \ was entry_rfetch; R@ now in Forth
  1 b#
  64 b#
l: do_fetch
  r0 pop,
  r0 0 r0 lw,
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ! ( x addr -- ) : Store cell at address
l: entry_store
  w: entry_fetch
  1 b#
  33 b#
l: do_store
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
\ underflow check: need 2 cells
  fp sp mov,
  fp push,
  r0 pop,
  r0 6 addi,   \ r0 = sp + 6 (post-pop sp)
  r2 la: var_sp_base
  r2 0 r2 lw,
  r2 r0 clu,   \ C = (sp_base < sp+6) → underflow
  brt: do_store_uflw
  r2 pop,   \ addr
  r0 pop,   \ value
  r0 0 r2 sw,
  r2 0 r1 lw,   \ restore IP
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,
l: do_store_uflw
  r0 la: stack_underflow_err
  r0 jmp,

\ C@ ( addr -- c ) : Fetch byte from address
l: entry_cfetch
  w: entry_store
  2 b#
  67 b# 64 b#
l: do_cfetch
  r0 pop,
  r0 0 r0 lbu,
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ C! ( c addr -- ) : Store byte at address
l: entry_cstore
  w: entry_cfetch
  2 b#
  67 b# 33 b#
l: do_cstore
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
\ underflow check: need 2 cells
  fp sp mov,
  fp push,
  r0 pop,
  r0 6 addi,
  r2 la: var_sp_base
  r2 0 r2 lw,
  r2 r0 clu,
  brt: do_cstore_uflw
  r2 pop,   \ addr
  r0 pop,   \ byte value
  r0 0 r2 sb,
  r2 0 r1 lw,   \ restore IP
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,
l: do_cstore_uflw
  r0 la: stack_underflow_err
  r0 jmp,

\ ============================================================
\ HALT — infinite loop (not in dictionary, just a code target)
\ ============================================================
l: entry_execute
  w: entry_cstore
  7 b#
  69 b# 88 b# 69 b# 67 b# 85 b# 84 b# 69 b#
l: do_execute
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP temporarily for the underflow check
\ underflow check: need 1 cell
  fp sp mov,
  fp push,
  r0 pop,
  r0 3 addi,
  r2 la: var_sp_base
  r2 0 r2 lw,
  r2 r0 clu,
  brt: do_execute_uflw
  r2 0 r1 lw,   \ restore IP (the executed word expects r2=IP)
  r1 3 addi,
  r0 pop,
  r0 jmp,
l: do_execute_uflw
  r0 la: stack_underflow_err
  r0 jmp,

\ ------------------------------------------------------------
\ HERE ( -- addr ) : Push address of HERE variable
\ ------------------------------------------------------------
l: entry_here
  w: entry_execute
  4 b#
  72 b# 69 b# 82 b# 69 b#
l: do_here
  r0 la: var_here_val
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ LATEST ( -- addr ) : Push address of LATEST variable
\ ------------------------------------------------------------
l: entry_latest
  w: entry_here
  6 b#
  76 b# 65 b# 84 b# 69 b# 83 b# 84 b#
l: do_latest
  r0 la: var_latest_val
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ STATE ( -- addr ) : Push address of STATE variable
\ ------------------------------------------------------------
l: entry_state
  w: entry_latest
  5 b#
  83 b# 84 b# 65 b# 84 b# 69 b#
l: do_state
  r0 la: var_state_val
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ BASE ( -- addr ) : Push address of BASE variable
\ ------------------------------------------------------------
l: entry_base
  w: entry_state
  4 b#
  66 b# 65 b# 83 b# 69 b#
l: do_base
  r0 la: var_base_val
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ , ( x -- ) : Store cell at HERE, advance HERE by 3
\ ------------------------------------------------------------
l: entry_comma
  w: entry_base
  1 b#
  44 b#
l: do_comma
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
\ underflow check: need 1 cell
  fp sp mov,
  fp push,
  r0 pop,
  r0 3 addi,
  r2 la: var_sp_base
  r2 0 r2 lw,
  r2 r0 clu,
  brt: do_comma_uflw
  r0 la: var_here_val
  r2 0 r0 lw,   \ r2 = HERE
  r0 pop,   \ r0 = value
  r0 0 r2 sw,   \ mem[HERE] = x
  r2 3 addi,   \ HERE += 3
  r0 la: var_here_val
  r2 0 r0 sw,   \ update HERE
  r2 0 r1 lw,   \ restore IP
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,
l: do_comma_uflw
  r0 la: stack_underflow_err
  r0 jmp,

\ ------------------------------------------------------------
\ C, ( c -- ) : Store byte at HERE, advance HERE by 1
\ ------------------------------------------------------------
l: entry_ccomma
  w: entry_comma
  2 b#
  67 b# 44 b#
l: do_ccomma
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
\ underflow check: need 1 cell
  fp sp mov,
  fp push,
  r0 pop,
  r0 3 addi,
  r2 la: var_sp_base
  r2 0 r2 lw,
  r2 r0 clu,
  brt: do_ccomma_uflw
  r0 la: var_here_val
  r2 0 r0 lw,   \ r2 = HERE
  r0 pop,   \ r0 = byte
  r0 0 r2 sb,   \ mem[HERE] = c
  r2 1 addi,   \ HERE += 1
  r0 la: var_here_val
  r2 0 r0 sw,   \ update HERE
  r2 0 r1 lw,   \ restore IP
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,
l: do_ccomma_uflw
  r0 la: stack_underflow_err
  r0 jmp,

\ ------------------------------------------------------------
\ ALLOT ( n -- ) : Advance HERE by n bytes
\ ------------------------------------------------------------
l: entry_allot
  w: entry_ccomma
  5 b#
  65 b# 76 b# 76 b# 79 b# 84 b#
l: do_allot
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
\ underflow check: need 1 cell
  fp sp mov,
  fp push,
  r0 pop,
  r0 3 addi,
  r2 la: var_sp_base
  r2 0 r2 lw,
  r2 r0 clu,
  brt: do_allot_uflw
  r0 la: var_here_val
  r2 0 r0 lw,   \ r2 = HERE
  r0 pop,   \ r0 = n
  r2 r0 add,   \ HERE += n
  r0 la: var_here_val
  r2 0 r0 sw,   \ update HERE
  r2 0 r1 lw,   \ restore IP
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,
l: do_allot_uflw
  r0 la: stack_underflow_err
  r0 jmp,

\ ------------------------------------------------------------
\ [ ( -- ) : Enter interpret mode [IMMEDIATE]
\ ------------------------------------------------------------
l: entry_lbrac
  w: entry_allot
  129 b#
  91 b#
l: do_lbrac
  r1 -3 addi,
  r2 0 r1 sw,
  r2 la: var_state_val
  r0 0 lc,
  r0 0 r2 sw,   \ STATE = 0
  r2 0 r1 lw,
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ ] ( -- ) : Enter compile mode
\ ------------------------------------------------------------
l: entry_rbrac
  w: entry_lbrac
  1 b#
  93 b#
l: do_rbrac
  r1 -3 addi,
  r2 0 r1 sw,
  r2 la: var_state_val
  r0 -1 lc,
  r0 0 r2 sw,   \ STATE = -1
  r2 0 r1 lw,
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ============================================================
\ FIND ( c-addr -- c-addr 0 | cfa 1 | cfa -1 )
\ Search dictionary for counted string at c-addr.
\ Returns cfa and flag (1=immediate, -1=normal) or 0 if not found.
\
\ Uses data stack to pass entry pointer between iterations (avoids
\ long backward branches). RS base frame:
\ r1+0  = search_start (c-addr + 1)
\ r1+3  = search_len
\ r1+6  = c-addr (for not-found return)
\ r1+9  = saved IP
\ ============================================================
\ Subset 18: user-visible FIND is now a Forth colon def in
\ core/highlevel.fth (simple linked-list walk; no hash or lookaside
\ fast path). The asm do_find body remains because INTERPRET and
\ tick_word_cfa reference `.word do_find` by address.
l: entry_create
  w: entry_rbrac   \ was entry_find; FIND is now in core/highlevel.fth
\ (asm do_find body stays — INTERPRET's thread + [']
\ reference `.word do_find` directly.)
  6 b#
  67 b# 82 b# 69 b# 65 b# 84 b# 69 b#
l: do_create
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP. RS: [IP]

\ --- Inline word reading (same as WORD) ---
  r0 la: word_buffer
  r0 1 addi,
  r1 -3 addi,
  r0 0 r1 sw,   \ RS: [buf_ptr, IP]

l: create_skip
  r0 -65280 la#,
l: create_skip_rx
  r2 1 r0 lbu,
  r0 1 lcu,
  r2 r0 and,
  r2 z ceq,
  brt: create_skip_rx2
  r0 -65280 la#,
  r0 0 r0 lbu,
  r2 33 lcu,
  r0 r2 clu,
  brt: create_skip
  bra: create_store
l: create_skip_rx2
  r0 -65280 la#,
  bra: create_skip_rx

l: create_store
  r2 0 r1 lw,
  r0 0 r2 sb,
  r2 1 addi,
  r2 0 r1 sw,

l: create_read
  r0 -65280 la#,
l: create_read_rx
  r2 1 r0 lbu,
  r0 1 lcu,
  r2 r0 and,
  r2 z ceq,
  brt: create_read_rx2
  r0 -65280 la#,
  r0 0 r0 lbu,
  r2 33 lcu,
  r0 r2 clu,
  brt: create_read_done
  bra: create_store
l: create_read_rx2
  r0 -65280 la#,
  bra: create_read_rx

l: create_read_done
\ Compute name length
  r2 0 r1 lw,   \ r2 = final buf_ptr
  r1 3 addi,   \ pop buf_ptr. RS: [IP]
  r0 la: word_buffer
  r0 1 addi,
  r2 r0 sub,   \ r2 = name length
  r0 la: word_buffer
  r2 0 r0 sb,   \ store count

\ --- Build header at HERE ---
\ Save name length
  r1 -3 addi,
  r2 0 r1 sw,   \ RS: [name_len, IP]

\ Load HERE
  r0 la: var_here_val
  r2 0 r0 lw,   \ r2 = HERE (destination)

\ Save HERE (= new entry address) for LATEST update
  r1 -3 addi,
  r2 0 r1 sw,   \ RS: [new_entry, name_len, IP]

\ Write link field = current LATEST
  r0 la: var_latest_val
  r0 0 r0 lw,   \ r0 = LATEST
  r0 0 r2 sw,   \ mem[HERE] = link
  r2 3 addi,   \ past link

\ Write flags_len = name_len (no flags)
  r0 3 r1 lw,   \ r0 = name_len (at RS offset 3)
  r0 0 r2 sb,   \ mem[HERE+3] = flags_len
  r2 1 addi,   \ past flags_len

\ Copy name chars from word_buffer+1 to HERE+4
  r0 3 r1 lw,   \ r0 = name_len (counter)
  r1 -3 addi,
  r0 0 r1 sw,   \ RS: [counter, new_entry, name_len, IP]
  r0 la: word_buffer
  r0 1 addi,   \ r0 = source
  r1 -3 addi,
  r0 0 r1 sw,   \ RS: [src, counter, new_entry, name_len, IP]

l: create_copy
  r0 3 r1 lw,   \ r0 = counter
  r0 z ceq,
  brt: create_copy_done
  r0 0 r1 lw,   \ r0 = src
  r0 0 r0 lbu,   \ r0 = char
  r0 0 r2 sb,   \ store at dest (r2)
  r2 1 addi,   \ dest++
  r0 0 r1 lw,   \ src
  r0 1 addi,
  r0 0 r1 sw,   \ src++
  r0 3 r1 lw,   \ counter
  r0 -1 addi,
  r0 3 r1 sw,   \ counter--
  bra: create_copy

l: create_copy_done
  r1 6 addi,   \ pop src, counter. RS: [new_entry, name_len, IP]

\ Update HERE (r2 = new position after name)
  r0 la: var_here_val
  r2 0 r0 sw,

\ Update LATEST = new_entry
  r0 0 r1 lw,   \ r0 = new_entry
  r1 6 addi,   \ pop new_entry, name_len. RS: [IP]
  r1 -3 addi,
  r2 0 r1 sw,   \ save r2 on RS temporarily
  r2 la: var_latest_val
  r0 0 r2 sw,   \ LATEST = new_entry
  r2 0 r1 lw,   \ restore r2
  r1 3 addi,   \ RS: [IP]

\ Insert new_entry into FIND hash table (mult33 hash).
\ r0 holds new_entry; flags_len at r0+3 (length in low 6 bits);
\ name starts at r0+4.
  r1 -3 addi,
  r0 0 r1 sw,   \ stash entry. RS: [entry, IP]
\ hash_arg_ptr = entry + 4
  r0 4 addi,
  r2 la: hash_arg_ptr
  r0 0 r2 sw,
\ hash_arg_len = flags_len & 63
  r0 0 r1 lw,   \ r0 = entry
  r0 3 r0 lbu,   \ r0 = flags_len
  r2 63 lcu,
  r0 r2 and,
  r2 la: hash_arg_len
  r0 0 r2 sw,
\ return addr
  r2 la: hash_ret_addr
  r0 la: create_after_hash
  r0 0 r2 sw,
  r0 la: compute_hash
  r0 jmp,
l: create_after_hash
\ RS: [entry, IP]. Read hash_result, compute slot addr, store entry.
  r0 la: hash_result
  r0 0 r0 lw,   \ r0 = bucket
  r2 3 lc,
  r0 r2 mul,   \ r0 = bucket * 3
  r1 -3 addi,
  r0 0 r1 sw,   \ RS: [offset, entry, IP]
  r0 la: dict_hash_table
  r2 0 r1 lw,
  r1 3 addi,   \ pop offset
  r0 r2 add,   \ r0 = slot addr
  r2 0 r1 lw,   \ r2 = entry
  r2 0 r0 sw,   \ *slot = entry
  r1 3 addi,   \ pop entry. RS: [IP]

\ Restore IP and NEXT
  r2 0 r1 lw,
  r1 3 addi,
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ : ( -- ) : Start colon definition
\ Calls CREATE, writes 6-byte far CFA, enters compile mode
\ ------------------------------------------------------------
l: do_colon_cfa
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
\ Load HERE
  r0 la: var_here_val
  r2 0 r0 lw,   \ r2 = HERE (dest)
\ Copy 6 bytes from cfa_template
  r0 la: cfa_template
  r0 push,   \ save template addr
  r0 0 r0 lw,   \ first 3 bytes
  r0 0 r2 sw,   \ store at HERE
  r2 3 addi,
  r0 pop,   \ template addr
  r0 3 addi,
  r0 0 r0 lw,   \ next 3 bytes
  r0 0 r2 sw,   \ store at HERE+3
  r2 3 addi,
\ Update HERE (+6)
  r0 la: var_here_val
  r2 0 r0 sw,
\ Restore IP and NEXT
  r2 0 r1 lw,
  r1 3 addi,
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ Template for far colon CFA (6 bytes):
\ push r0 (0x7D), la r0 (0x29), addr_lo, addr_mid, addr_hi, jmp(r0) (0x26)
l: cfa_template
  125 b#   \ push r0
  41 b#   \ la r0 opcode
  w: do_docol_far   \ 3-byte address of do_docol_far
  38 b#   \ jmp (r0)

\ ------------------------------------------------------------
\ ; ( -- ) : End colon definition [IMMEDIATE]
\ Compiles EXIT, enters interpret mode
\ ------------------------------------------------------------
l: entry_semi
  w: entry_create
  129 b#
  59 b#
l: do_semi
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
\ Compile EXIT at HERE
  r0 la: var_here_val
  r2 0 r0 lw,   \ r2 = HERE
  r0 la: do_exit
  r0 0 r2 sw,   \ mem[HERE] = do_exit
  r2 3 addi,
  r0 la: var_here_val
  r2 0 r0 sw,   \ update HERE
\ Clear HIDDEN on LATEST (complementary to do_colon's HIDE)
  r0 la: var_latest_val
  r0 0 r0 lw,
  r0 3 addi,
  r2 0 r0 lbu,
  r0 push,
  r0 191 lcu,   \ ~0x40 in 8-bit
  r2 r0 and,
  r0 pop,
  r2 0 r0 sb,
\ STATE = 0 (interpreting)
  r0 la: var_state_val
  r2 0 lc,
  r2 0 r0 sw,
  r2 0 r1 lw,
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ ,DOCOL ( -- ) : Emit the 6-byte far-CFA template at HERE,
\ advance HERE by 6. Exposes the colon-def CFA template that asm `:`
\ uses internally (do_colon_cfa) so Forth-defined `:` in
\ core/runtime.fth can build new colon headers without asm support.
\ ------------------------------------------------------------
l: entry_comma_docol
  w: entry_create
  6 b#
  44 b# 68 b# 79 b# 67 b# 79 b# 76 b#   \ ",DOCOL"
l: do_comma_docol
  r0 la: do_colon_cfa
  r0 jmp,

\ ------------------------------------------------------------
\ IMMEDIATE ( -- ) : Toggle IMMEDIATE flag on most recent word
\ ------------------------------------------------------------
l: entry_immediate
  w: entry_comma_docol
  9 b#
  73 b# 77 b# 77 b# 69 b# 68 b# 73 b# 65 b# 84 b# 69 b#
l: do_immediate
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
  r0 la: var_latest_val
  r0 0 r0 lw,   \ r0 = latest entry
  r0 3 addi,   \ r0 = address of flags_len
  r2 0 r0 lbu,   \ r2 = flags_len
  r0 push,   \ save flags address
  r0 128 lcu,
  r2 r0 xor,   \ toggle bit 7
  r0 pop,   \ r0 = flags address
  r2 0 r0 sb,   \ store updated flags
  r2 0 r1 lw,
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ============================================================
\ Phase 4: LED!, DOT, interpret-only shell
\ ============================================================

\ ------------------------------------------------------------
\ LED! ( n -- ) : Write low bit of n to LED register at 0xFF0000
\ ------------------------------------------------------------
l: entry_led_store
  w: entry_immediate
  4 b#
  76 b# 69 b# 68 b# 33 b#   \ "LED!"
l: do_led_store
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
  r0 pop,   \ n
  r2 1 lcu,
  r0 r2 and,   \ mask to low bit
  r2 -65536 la#,   \ 0xFF0000 LED register
  r0 0 r2 sb,
  r2 0 r1 lw,
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ SW? ( -- n ) : Read switch S2 (0=pressed, 1=released)
\ Reads bit 0 of 0xFF0000 (same pin as LED, active-low pull-up)
\ ------------------------------------------------------------
l: entry_sw_fetch
  w: entry_led_store
  3 b#
  83 b# 87 b# 63 b#   \ "SW?"
l: do_sw_fetch
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
  r0 -65536 la#,   \ 0xFF0000
  r0 0 r0 lbu,   \ read byte
  r2 1 lcu,
  r0 r2 and,   \ mask to bit 0
  r0 push,
  r2 0 r1 lw,
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ NUMBER ( c-addr -- n flag ) : Parse counted string as number
\ flag=0 success, flag=-1 failure. Handles leading '-'.
\ Pure assembly, no sub-calls. Uses RS for locals.
\ RS frame: [sign, acc, ptr, rem, saved_IP]
\ (`.` is defined in Forth, see core/midlevel.fth.)
\ ------------------------------------------------------------
\ Subset 19: user-visible NUMBER is now a Forth colon def in
\ core/highlevel.fth (digit-conversion loop in BASE). The asm
\ do_number body stays here because INTERPRET's thread
\ (`.word do_number`) references it by address.
l: stack_underflow_err
\ Reset DS
  r0 la: var_sp_base
  r0 0 r0 lw,
  r0 push,
  fp pop,   \ fp = sp_base
  sp fp mov,   \ sp = sp_base
\ Reset RS
  r1 983040 la#,
\ Reset STATE to interpret (0), so a partial colon def is abandoned
  r2 la: var_state_val
  r0 0 lc,
  r0 0 r2 sw,
\ Print "? "
  r2 -65280 la#,
  r0 63 lc,   \ '?'
  r0 push,
l: sue1
  r0 1 r2 lb,
  r0 z cls,
  brt: sue1
  r0 pop,
  r0 0 r2 sb,
  r0 32 lc,   \ ' '
  r0 push,
l: sue2
  r0 1 r2 lb,
  r0 z cls,
  brt: sue2
  r0 pop,
  r0 0 r2 sb,
\ Restart outer loop. Prefer Forth QUIT (installed in
\ var_quit_vector by end of core/highlevel.fth); fall back to
\ the asm bootstrap do_quit when the vector is still zero
\ (i.e., underflow during bootstrap, before QUIT is defined).
  r0 la: var_quit_vector
  r0 0 r0 lw,
  r0 z ceq,
  brt: sue_asm_fallback
  r0 jmp,   \ execute Forth QUIT (r0 = its CFA)
l: sue_asm_fallback   \ QUIT-VECTOR is never 0 in the image;
  r0 jmp,   \ if it were, r0 = 0 restarts the kernel

\ ============================================================
\ Phase 4b: Debugging and Convenience Words
\ ============================================================

\ CR / SPACE / HEX / DECIMAL / . / DEPTH / .S moved to core/*.fth.
\ The data-stack pointer is exposed via SP@ below so DEPTH and .S can
\ be implemented in Forth.

\ ------------------------------------------------------------
\ SP@ ( -- sp ) : Push the value of the data stack pointer that the
\ caller saw at the moment SP@ was invoked. (The push itself decrements
\ sp by 3; the value left on top is sp BEFORE the push.) Used by the
\ Forth-level DEPTH and .S in core/highlevel.fth.
\ ------------------------------------------------------------
l: entry_sp_fetch
  w: entry_sw_fetch
  3 b#
  83 b# 80 b# 64 b#   \ "SP@"
l: do_sp_fetch
  r1 -3 addi,
  r2 0 r1 sw,   \ save IP
  fp sp mov,
  fp push,
  r0 pop,   \ r0 = sp value at primitive entry (push/pop net-zero)
  r0 push,   \ push sp value onto DS
  r2 0 r1 lw,   \ restore IP
  r1 3 addi,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ SP! ( addr -- ) : Set data stack pointer to addr. `pop r0` reads
\ addr first (from current TOS), then `mov sp, r0` installs it as
\ the new sp. Anything between the old sp and the new sp is now
\ "off stack"; the caller is responsible for having put addr
\ somewhere sensible (typically computed from SP@).
\ ------------------------------------------------------------
l: entry_sp_store
  w: entry_sp_fetch
  3 b#
  83 b# 80 b# 33 b#   \ "SP!"
l: do_sp_store
  r0 pop,   \ r0 = new sp
  sp r0 mov,   \ sp := new sp
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ RP@ ( -- addr ) : Push current return stack pointer (r1). Inside
\ a colon def, RP@ returns the address of the caller's saved IP
\ (because do_colon_cfa already pushed it). User code that said
\ `x >R` and then `RP@` will see r1 pointing at *that colon's*
\ saved IP, with x one cell deeper — so a Forth-level R@
\ is `: R@ RP@ 3 + @ ;` to skip past the nested-call's own IP.
\ ------------------------------------------------------------
l: entry_rp_fetch
  w: entry_sp_store
  3 b#
  82 b# 80 b# 64 b#   \ "RP@"
l: do_rp_fetch
  r1 push,   \ push r1 onto DS
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ RP! ( addr -- ) : Set return stack pointer (r1). Extremely
\ dangerous — next NEXT will read the IP of the current primitive
\ correctly (it's still in r2), but once this primitive returns to
\ a colon context, EXIT will read from the new r1 location. Use
\ only in matched pairs around RP manipulation.
\ ------------------------------------------------------------
l: entry_rp_store
  w: entry_rp_fetch
  3 b#
  82 b# 80 b# 33 b#   \ "RP!"
l: do_rp_store
  r0 pop,   \ r0 = new r1
  r1 r0 mov,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ============================================================
\ `` / `(` / IF / THEN / ELSE / BEGIN / UNTIL — moved to core/minimal.fth
\ ============================================================
\ These IMMEDIATE words are now defined in Forth. The kernel only
\ retains the helpers they need: BRANCH, 0BRANCH, KEY, EOL!, and [']
\ (defined below).

\ ------------------------------------------------------------
\ WORD-BUFFER ( -- addr )  — push address of 32-byte counted-string
\ scratch used by WORD. First byte is length; next up to 31 bytes
\ are name chars. Exposed so the Forth-level WORD (core/lowlevel.fth)
\ can write to it.
\ EOL-FLAG    ( -- addr )  — push address of the 1-byte flag used to
\ signal "previous input ended at newline". minimal.fth's `` comment
\ parser writes 1; Forth WORD reads-and-clears. Replaces the old
\ EOL! primitive (which was just `1 EOL-FLAG C!`).
\ ------------------------------------------------------------
l: entry_word_buffer
  w: entry_rp_store
  11 b#
  87 b# 79 b# 82 b# 68 b# 45 b# 66 b# 85 b# 70 b# 70 b# 69 b# 82 b#   \ "WORD-BUFFER"
l: do_word_buffer
  r0 la: word_buffer
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

l: entry_eol_flag
  w: entry_word_buffer
  8 b#
  69 b# 79 b# 76 b# 45 b# 70 b# 76 b# 65 b# 71 b#   \ "EOL-FLAG"
l: do_eol_flag
  r0 la: word_eol_flag
  r0 push,
\ NEXT
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ ['] ( -- ) : At compile time, read next word, look up its CFA,
\ and compile `LIT cfa` into the current definition [IMMEDIATE].
\ Used by core.fth's IF/THEN/ELSE/UNTIL to embed BRANCH/0BRANCH CFAs.
\ ------------------------------------------------------------
l: entry_paren_do
  w: entry_eol_flag
  4 b#
  40 b# 68 b# 79 b# 41 b#   \ "(DO)"
l: do_paren_do
\ DS: ( limit start -- ). Reserve 2 RS cells, write index
\ (from start) at 0(r1) and limit at 3(r1). We pop start first
\ so it goes in as index; then pop limit above it. `sw fp` isn't
\ available on this ISA, so we only write through r0.
  r0 pop,   \ r0 = start
  r1 -6 addi,   \ reserve limit+index on RS
  r0 0 r1 sw,   \ index (=start)
  r0 pop,   \ r0 = limit
  r0 3 r1 sw,   \ limit
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ (LOOP) — thread: [do_paren_loop][offset]
\ Increment index, compare against limit:
\ == → drop limit+index, skip offset, fall through
\ != → write new index, IP += offset (branch back)
l: entry_paren_loop
  w: entry_paren_do
  6 b#
  40 b# 76 b# 79 b# 79 b# 80 b# 41 b#   \ "(LOOP)"
l: do_paren_loop
\ RS: [index][limit][caller IP]. Stash IP in fp via push/pop so
\ r2 is free as a scratch compare register (ceq on this ISA needs
\ both operands to be r0/r1/r2/z).
  r2 push,
  fp pop,   \ fp = saved IP
  r0 0 r1 lw,   \ r0 = index
  r0 1 addi,
  r0 0 r1 sw,   \ write new index back
  r2 3 r1 lw,   \ r2 = limit
  r0 r2 ceq,   \ C = (new index == limit)
  brt: ploop_done
  fp push,
  r2 pop,   \ restore IP
  r0 0 r2 lw,   \ r0 = signed back-offset
  r2 r0 add,
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,
l: ploop_done
  fp push,
  r2 pop,   \ restore IP
  r1 6 addi,   \ drop limit+index from RS
  r2 3 addi,   \ skip offset cell
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ (?DO) ( limit start -- )  ( R: -- [limit index] )
\ Thread: [do_paren_qdo][fwd_offset]
\ If start == limit: skip loop body (IP += fwd_offset).
\ Else: push limit+index to RS, skip the fwd_offset cell, fall through.
l: entry_paren_qdo
  w: entry_paren_loop
  5 b#
  40 b# 63 b# 68 b# 79 b# 41 b#   \ "(?DO)"
l: do_paren_qdo
\ DS: ( limit start -- ). Same ISA constraints as (LOOP): we stash
\ IP in fp so r0 and r2 are both free for the compare.
  r2 push,
  fp pop,   \ fp = saved IP
  r0 pop,   \ r0 = start
  r2 pop,   \ r2 = limit
  r0 r2 ceq,
  brt: qdo_skip
  r1 -3 addi,
  r2 0 r1 sw,   \ push limit
  r1 -3 addi,
  r0 0 r1 sw,   \ push index (=start)
  fp push,
  r2 pop,   \ restore IP
  r2 3 addi,   \ skip fwd_offset
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,
l: qdo_skip
  fp push,
  r2 pop,   \ restore IP
  r0 0 r2 lw,   \ r0 = fwd_offset
  r2 r0 add,
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ I ( -- index )  push current loop index (RS top).
l: entry_i
  w: entry_paren_qdo
  1 b#
  73 b#   \ "I"
l: do_i
  r0 0 r1 lw,
  r0 push,
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ UNLOOP ( -- )  ( R: limit index -- )  drop loop state from RS,
\ restoring the caller's IP to RS top. Must precede EXIT inside
\ a DO-loop.
l: entry_unloop
  w: entry_i
  6 b#
  85 b# 78 b# 76 b# 79 b# 79 b# 80 b#   \ "UNLOOP"
l: do_unloop
  r1 6 addi,
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ------------------------------------------------------------
\ BYE ( -- ) : Halt the CPU
\ ------------------------------------------------------------
l: entry_bye
  w: entry_unloop
  3 b#
  66 b# 89 b# 69 b#   \ "BYE"
l: do_bye
  bra: do_bye

\ ------------------------------------------------------------
\ QUIT-VECTOR ( -- addr ) : Push address of the quit vector cell.
\ The cell holds the CFA of the Forth-level QUIT installed at the
\ end of core/highlevel.fth. Read by stack_underflow_err to
\ re-enter Forth QUIT after a stack reset. Zero before install —
\ fallback path restarts the asm bootstrap do_quit in that case.
\ ------------------------------------------------------------
l: entry_quit_vector
  w: entry_bye
  11 b#
  81 b# 85 b# 73 b# 84 b# 45 b# 86 b# 69 b# 67 b# 84 b# 79 b# 82 b#   \ "QUIT-VECTOR"
l: do_quit_vector
  r0 la: var_quit_vector
  r0 push,
  r0 0 r2 lw,
  r2 3 addi,
  r0 jmp,

\ ============================================================
\ System Variable Storage
\ ============================================================
l: var_here_val
  0 w#
l: var_latest_val
  0 w#
l: var_state_val
  0 w#
l: var_base_val
  10 w#
l: var_sp_base
  0 w#   \ snapshot of initial sp taken at _start
l: var_quit_vector
  0 w#   \ CFA of Forth QUIT (installed at runtime)

\ ============================================================
\ compute_hash: 2-Round 24-bit XMX hash over a counted name.
\
\ Per docs/hashing.txt's recommendation for 24-bit GPR ISAs.
\ Per character:
\ h = h XOR char
\ h = h * MAGIC        ; 24-bit truncation is native (mul)
\ h = h XOR (h SRL 12) ; spread high bits into low
\ bucket = h & 0xFF
\
\ MAGIC = 0xDEADB5 = 14,592,437
\
\ Inputs via fixed memory cells:
\ hash_arg_ptr — address of first name byte
\ hash_arg_len — length of name (0-63)
\ Output:
\ hash_result  — bucket index (0-255)
\ Control:
\ hash_ret_addr — caller sets; subroutine jumps to this on exit
\
\ Collision count on our 90-word dict at 256 buckets: 15
\ (vs 11 for len-seeded mult33, 47 for first_char).
\ See scripts/hash-collision-analysis.py and docs/hashing-analysis.md.
\ ============================================================
l: compute_hash
  r0 la: hash_arg_ptr
  r0 0 r0 lw,   \ r0 = ptr
  r2 la: hash_arg_len
  r2 0 r2 lw,   \ r2 = length
  r1 -3 addi,
  r0 0 r1 sw,   \ RS: [ptr]
  r1 -3 addi,
  r2 0 r1 sw,   \ RS: [remlen, ptr]
\ h = 0 (XMX starts with no seed)
  r0 0 lc,
l: ch_loop
  r2 0 r1 lw,   \ r2 = remlen
  r2 z ceq,
  brt: ch_done
\ Save h, read char at ptr
  r1 -3 addi,
  r0 0 r1 sw,   \ RS: [h, remlen, ptr]
  r0 6 r1 lw,   \ r0 = ptr (at RS offset 6)
  r2 0 r0 lbu,   \ r2 = char
  r0 0 r1 lw,   \ r0 = h
  r1 3 addi,   \ pop h. RS: [remlen, ptr]

\ XMX round: h = (h ^ char) * MAGIC; h ^= h >> 12
  r0 r2 xor,   \ r0 = h ^ char
  r2 14592437 la#,   \ r2 = MAGIC = 0xDEADB5
  r0 r2 mul,   \ r0 = (h^char) * MAGIC, 24-bit truncated
  r1 -3 addi,
  r0 0 r1 sw,   \ stash h on RS
  r2 12 la#,
  r0 r2 srl,   \ r0 = h >> 12
  r2 0 r1 lw,   \ r2 = h (pre-shift)
  r1 3 addi,   \ pop
  r0 r2 xor,   \ r0 = h ^ (h >> 12)

\ Advance ptr, decrement remlen
  r2 3 r1 lw,
  r2 1 addi,
  r2 3 r1 sw,
  r2 0 r1 lw,
  r2 -1 addi,
  r2 0 r1 sw,
  bra: ch_loop
l: ch_done
\ Save 24-bit hash for lookaside cache (before masking)
  r2 la: hash_full
  r0 0 r2 sw,
\ Mask to 8-bit bucket index
  r2 255 lcu,
  r0 r2 and,
  r2 la: hash_result
  r0 0 r2 sw,
  r1 6 addi,   \ pop [remlen, ptr]
  r2 la: hash_ret_addr
  r2 0 r2 lw,
  r2 jmp,

\ compute_hash's argument / return cells
l: hash_arg_ptr
  0 w#
l: hash_arg_len
  0 w#
l: hash_ret_addr
  0 w#
l: hash_result
  0 w#
l: hash_full
  0 w#   \ 24-bit pre-mask hash (for lookaside cache key)

\ ============================================================
\ FIND lookaside cache (single entry, memento-pattern).
\ Avoids the bucket-lookup + name-compare path for repeated-word
\ lookups common in colon-def compilation. Key is the full 24-bit
\ XMX hash (effectively collision-free for our dict; worst case =
\ false positive that returns wrong CFA, mitigated by the high
\ entropy of XMX).
\ ============================================================
l: lookaside_hash
  0 w#   \ 24-bit hash of cached name
l: lookaside_cfa
  0 w#   \ cfa of cached entry; 0 = cache empty / invalid
l: lookaside_flag
  0 w#   \ 1 = IMMEDIATE, -1 = normal

\ ============================================================
\ FIND hash table: 256 buckets × 3 bytes = 768 bytes.
\ Bucket[c] holds the most-recent dict entry whose name starts
\ with byte c. Populated at _start; maintained by do_create.
\ ============================================================
l: dict_hash_table
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
  0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w# 0 w#
l: dict_hash_table_end

  w: do_exit

\ ============================================================
\ Test Data
\ ============================================================

\ Counted strings for FIND tests
l: cs_emit
  4 b# 69 b# 77 b# 73 b# 84 b#   \ "EMIT"
l: cs_plus
  1 b# 43 b#   \ "+"

\ EOL flag for WORD (1 byte)
l: word_eol_flag
  0 b#

\ Word input buffer (32 bytes)
l: word_buffer
  0 b# 0 b# 0 b# 0 b# 0 b# 0 b# 0 b# 0 b#
  0 b# 0 b# 0 b# 0 b# 0 b# 0 b# 0 b# 0 b#
  0 b# 0 b# 0 b# 0 b# 0 b# 0 b# 0 b# 0 b#
  0 b# 0 b# 0 b# 0 b# 0 b# 0 b# 0 b# 0 b#

\ ============================================================

\ The first compiled dictionary entry links to the newest entry above.
XC-LINK-FROM entry_quit_vector
