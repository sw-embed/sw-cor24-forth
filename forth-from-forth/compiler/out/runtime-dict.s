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
