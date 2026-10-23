\ A loop that never ends and never yields. On the bare kernel there is no
\ way out but reset. Under SWTOS the kernel takes the CPU away from it on
\ every quantum: the shell keeps answering, Resources shows this process's
\ fp= count climbing, and `kill` ends it from the shell. Escape cannot
\ reach it, because it never reads a key.
: HOG  BEGIN AGAIN ;
72 EMIT 79 EMIT 71 EMIT 10 EMIT        \ says HOG, then spins
HOG
