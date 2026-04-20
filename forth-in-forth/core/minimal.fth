\ minimal.fth: IF THEN ELSE BEGIN UNTIL built on BRANCH 0BRANCH + ['] helper
\ Note: HERE pushes the address of the HERE variable (not the value);
\ HERE @ yields the current dictionary pointer. Same applies to LATEST, STATE, BASE.
: IF     ['] 0BRANCH , HERE @ 0 , ; IMMEDIATE
: THEN   HERE @ OVER - SWAP ! ; IMMEDIATE
: ELSE   ['] BRANCH , HERE @ 0 , SWAP HERE @ OVER - SWAP ! ; IMMEDIATE
: BEGIN  HERE @ ; IMMEDIATE
: UNTIL  ['] 0BRANCH , HERE @ - , ; IMMEDIATE
