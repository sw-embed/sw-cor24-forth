\ MIRROR: read switch S2 into LED D2 in a slow loop.
\ Click S2 quickly to see the LED change before the loop exits.
\ Each loop counts up from 0 with only the counter on the stack, so the
\ stack is balanced per call: a leaked cell per iteration would overflow
\ the 3 KB data stack after ~500 iterations and halt the CPU mid-demo.
: DELAY  0 BEGIN  1 +  DUP 100 =  UNTIL  DROP ;
: PAUSE  0 BEGIN  1 +  DUP 100 =  UNTIL  DROP ;
: MIRROR  0  BEGIN  SW? LED!  DELAY PAUSE  1 +  DUP 16000 =  UNTIL  DROP ;
MIRROR
