\ MIRROR: read switch S2 into LED D2 in a slow loop.
\ Click S2 quickly to see the LED change before the loop exits.
: DELAY  100 0 BEGIN  1 +  DUP 100 =  UNTIL  DROP ;
: PAUSE  100 0 BEGIN  1 +  DUP 100 =  UNTIL  DROP ;
: MIRROR  16000 0  BEGIN  SW? LED!  DELAY PAUSE  1 +  DUP 16000 =  UNTIL  DROP ;
MIRROR
