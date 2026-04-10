\ --- Self Test: exercise all kernel words ---
\ Stack should be empty at end (DEPTH . = 0)
\ No '?' errors should appear
\

\ --- Arithmetic ---
1 . 2 3 + . 10 3 - . -7 . 3 4 * . 17 5 /MOD . . CR

\ --- Stack ops ---
DEPTH .
1 2 3 DEPTH . DROP DROP DROP
1 2 3 .S DROP DROP DROP
5 DUP + . 1 2 SWAP . . 1 2 OVER . . . 1 2 DROP . CR

\ --- Number base ---
HEX FF . HEX A . DECIMAL 255 . CR

\ --- LED ---
1 LED! 0 LED!

\ --- Per-word stack balance ---
CR SPACE 65 EMIT 99 >R R> . 99 >R R@ . R> DROP HERE @ HERE @ = . HERE @ 42 OVER C! C@ . CR

\ --- Logic ---
7 3 AND . 5 3 OR . 5 3 XOR . 3 3 = . 3 4 = . 2 5 < . 5 2 < . 0 0= . 7 0= . CR

\ --- Colon defs ---
: DOUBLE DUP + ;
5 DOUBLE . CR

\ --- IF THEN ---
: T -1 IF 65 EMIT THEN ;
: F 0 IF 66 EMIT THEN ;
T SPACE F CR

\ --- IF ELSE ---
: AE -1 IF 65 EMIT ELSE 66 EMIT THEN ;
: BE 0 IF 65 EMIT ELSE 66 EMIT THEN ;
AE SPACE BE CR

\ --- BEGIN UNTIL ---
: COUNT 1 BEGIN DUP . 1 + DUP 5 = UNTIL DROP ;
COUNT CR

\ --- Version ---
VER CR

\ --- Error handling ---
FOO BAR CR

\ --- WORDS ---
WORDS CR

\ --- Final check: stack must be empty ---
DEPTH . CR
