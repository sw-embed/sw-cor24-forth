fff_e1_DUP:
.word 0
.byte 3
.byte 68
.byte 85
.byte 80
fff_c1_DUP:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_sp_fetch
.word do_fetch
.word do_exit
fff_e2_DROP:
.word fff_e1_DUP
.byte 4
.byte 68
.byte 82
.byte 79
.byte 80
fff_c2_DROP:
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
fff_e3_OVER:
.word fff_e2_DROP
.byte 4
.byte 79
.byte 86
.byte 69
.byte 82
fff_c3_OVER:
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
fff_e4_SWAP:
.word fff_e3_OVER
.byte 4
.byte 83
.byte 87
.byte 65
.byte 80
fff_c4_SWAP:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_tor
.word fff_c1_DUP
.word do_rfrom
.word do_sp_fetch
.word do_lit
.word 6
.word do_plus
.word do_store
.word do_exit
fff_e5_R_64:
.word fff_e4_SWAP
.byte 2
.byte 82
.byte 64
fff_c5_R_64:
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
fff_e6_INVERT:
.word fff_e5_R_64
.byte 6
.byte 73
.byte 78
.byte 86
.byte 69
.byte 82
.byte 84
fff_c6_INVERT:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word fff_c1_DUP
.word do_nand
.word do_exit
fff_e7_AND:
.word fff_e6_INVERT
.byte 3
.byte 65
.byte 78
.byte 68
fff_c7_AND:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_nand
.word fff_c6_INVERT
.word do_exit
fff_e8_OR:
.word fff_e7_AND
.byte 2
.byte 79
.byte 82
fff_c8_OR:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word fff_c6_INVERT
.word fff_c4_SWAP
.word fff_c6_INVERT
.word do_nand
.word do_exit
fff_e9_XOR:
.word fff_e8_OR
.byte 3
.byte 88
.byte 79
.byte 82
fff_c9_XOR:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word fff_c3_OVER
.word fff_c3_OVER
.word do_nand
.word fff_c1_DUP
.word do_tor
.word do_nand
.word fff_c4_SWAP
.word do_rfrom
.word do_nand
.word do_nand
.word do_exit
fff_e10_NEGATE:
.word fff_e9_XOR
.byte 6
.byte 78
.byte 69
.byte 71
.byte 65
.byte 84
.byte 69
fff_c10_NEGATE:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word fff_c6_INVERT
.word do_lit
.word 1
.word do_plus
.word do_exit
fff_e11__45:
.word fff_e10_NEGATE
.byte 1
.byte 45
fff_c11__45:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word fff_c10_NEGATE
.word do_plus
.word do_exit
fff_e12__58:
.word fff_e11__45
.byte 1
.byte 58
fff_c12__58:
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
.word fff_c1_DUP
.word do_cfetch
.word do_lit
.word 64
.word fff_c8_OR
.word fff_c4_SWAP
.word do_cstore
.word do_rbrac
.word do_exit
fff_e13__59:
.word fff_e12__58
.byte 129
.byte 59
fff_c13__59:
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
.word fff_c1_DUP
.word do_cfetch
.word do_lit
.word 191
.word fff_c7_AND
.word fff_c4_SWAP
.word do_cstore
.word do_lit
.word 0
.word do_state
.word do_store
.word do_exit
fff_e14__58NONAME:
.word fff_e13__59
.byte 7
.byte 58
.byte 78
.byte 79
.byte 78
.byte 65
.byte 77
.byte 69
fff_c14__58NONAME:
.byte 125
.byte 41
.word do_docol_far
.byte 38
.word do_here
.word do_fetch
.word do_comma_docol
.word do_rbrac
.word do_exit
