: BEGIN  HERE @ ; IMMEDIATE
: UNTIL  ['] 0BRANCH , HERE @ - , ; IMMEDIATE
: IF     ['] 0BRANCH , HERE @ 0 , ; IMMEDIATE
: THEN   HERE @ OVER - SWAP ! ; IMMEDIATE
: ELSE   ['] BRANCH , HERE @ 0 , SWAP HERE @ OVER - SWAP ! ; IMMEDIATE
: (      BEGIN KEY 41 = UNTIL ; IMMEDIATE
: \      BEGIN KEY DUP 10 = SWAP 13 = OR UNTIL EOL! ; IMMEDIATE
\ Comments work from here on. minimal.fth provides the bootstrap layer:
\ BEGIN/UNTIL/IF/THEN/ELSE as IMMEDIATE words built on 0BRANCH/BRANCH
\ plus the ['] helper, and line/paren comment parsers built on KEY.
\ Note: HERE/LATEST/STATE/BASE push the *address* of the variable, not
\ the value. Use HERE @ for the current dictionary pointer.
