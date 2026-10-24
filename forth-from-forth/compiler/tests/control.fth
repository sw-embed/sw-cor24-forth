\ Cross-compiler control-flow test. Compiled after core/runtime.fth (for
\ DUP, DROP, -). Each definition's body must match what the phase-3
\ kernel compiles for the same line, in SEE form:
\     forth-from-forth/compiler/tests/compare-see.sh control.fth
: C-IF       IF 1 THEN ;
: C-IFELSE   IF 1 ELSE 2 THEN ;
: C-UNTIL    BEGIN 1 - DUP UNTIL ;
: C-AGAIN    BEGIN DUP IF EXIT THEN 1 + AGAIN ;
: C-WHILE    BEGIN DUP WHILE 1 - REPEAT ;
: C-NESTED   BEGIN DUP IF 1 - ELSE 2 THEN DUP UNTIL ;
: C-IFIF     IF IF 1 ELSE 2 THEN ELSE 3 THEN ;
: C-BIG      ( n -- ) BEGIN DUP WHILE DUP IF 1 - ELSE 2 - THEN REPEAT DROP ;
: C-AFTER    1 IF 2 THEN 3 ;
