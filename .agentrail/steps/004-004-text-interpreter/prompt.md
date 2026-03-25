## Phase 4: Text Interpreter (QUIT Loop)

Build the interactive text interpreter so Forth can accept and execute commands from UART input.

### Deliverable
Extend forth.s with:

1. **WORD**: Read characters from UART input, skip leading spaces/newlines, collect until next space or newline. Store as counted string (length byte + chars) in a word buffer (~32 bytes at fixed address). Return address of counted string.

2. **NUMBER**: Parse a counted string as a number in current BASE. Handle optional leading "-" for negatives. Return the parsed number and success/fail flag (0 = success, non-zero = unconverted chars remaining).

3. **INTERPRET**: The inner interpret/compile dispatch loop:
   - Call WORD to get next token
   - If empty (end of line), return
   - Try FIND — if found:
     - If interpreting (STATE=0): EXECUTE the word
     - If compiling: check IMMEDIATE flag — if immediate, EXECUTE; otherwise COMMA the CFA
   - If not found, try NUMBER:
     - If interpreting: leave number on stack
     - If compiling: compile LIT followed by the number
   - If neither: print "? " error, reset STATE to 0

4. **QUIT**: The outer loop:
   - Reset return stack pointer
   - Loop forever: call INTERPRET for each line, print " ok" and newline when STATE=0

5. **COLON** (:) and **SEMICOLON** (;):
   - COLON: calls CREATE, writes DOCOL CFA sequence, enters compile mode (])
   - SEMICOLON (IMMEDIATE): compiles EXIT, enters interpret mode ([)

6. **CREATE**: Build dictionary header — call WORD for name, lay down link field (copy LATEST, update LATEST to HERE), write flags+length byte, write name bytes, advance HERE past name.

7. **Test**: 
   - Boot into QUIT loop, verify " ok" prompt appears
   - Interactive: type "1 2 + ." and verify "3" output
   - Define: ": SQUARE DUP * ; 5 SQUARE ." and verify "25" output
   - Use cor24-run -u flag to feed UART input for automated testing

### Key constraints
- WORD buffer at fixed address (e.g., 0x0F1000 or after dictionary space)
- QUIT resets return stack on each line (error recovery)
- NUMBER must handle BASE 10 at minimum (hex optional for now)
- Keep error handling minimal: just print "? " for unknown words
- All UART I/O uses existing KEY/EMIT with TX busy-wait polling