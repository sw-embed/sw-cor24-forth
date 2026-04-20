: BEGIN  HERE @ ; IMMEDIATE
: UNTIL  ['] 0BRANCH , HERE @ - , ; IMMEDIATE
: IF     ['] 0BRANCH , HERE @ 0 , ; IMMEDIATE
: THEN   HERE @ OVER - SWAP ! ; IMMEDIATE
: ELSE   ['] BRANCH , HERE @ 0 , SWAP HERE @ OVER - SWAP ! ; IMMEDIATE
: 0=     IF 0 ELSE -1 THEN ;
: =      XOR 0= ;
: (      BEGIN KEY 41 = UNTIL ; IMMEDIATE
: \      BEGIN KEY DUP 10 = SWAP 13 = OR UNTIL EOL! ; IMMEDIATE
\ Comments and logic work from here on. minimal.fth provides bootstrap:
\ BEGIN/UNTIL/IF/THEN/ELSE (IMMEDIATE control flow built on 0BRANCH/BRANCH
\ plus [']), 0= and = (logic built on XOR + IF/ELSE), and \ ( comment
\ parsers (built on KEY/EOL!/=/OR).
\ Note: HERE/LATEST/STATE/BASE push the *address* of the variable, not
\ the value. Use HERE @ for the current dictionary pointer.
