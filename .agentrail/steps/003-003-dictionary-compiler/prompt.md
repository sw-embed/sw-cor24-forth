## Phase 3: Dictionary & Compiler

Build the dictionary structure and colon compiler so Forth can define new words.

### Deliverable
Extend forth.s with:

1. **Dictionary header layout**: Each word has:
   - Link field (3 bytes): points to previous word's link field (0 = end)
   - Flags+length (1 byte): bits 7=IMMEDIATE, 6=HIDDEN, 0-5=name length
   - Name (N bytes): padded to align CFA to cell boundary if needed
   - CFA (code field): for primitives, the executable code; for colon words, bra DOCOL + padding

2. **System variables** (stored in memory, accessed via dedicated words):
   - HERE: pointer to next free byte in dictionary space
   - LATEST: pointer to link field of most recent word
   - STATE: 0 = interpreting, non-zero = compiling
   - BASE: number base for parsing (initialize to 10)

3. **FIND**: Given a counted string (length byte + chars on stack or in buffer), walk dictionary from LATEST following link fields. Compare name lengths and characters. Return CFA and flags if found, 0 if not.

4. **Number parser (NUMBER)**: Parse a string as a number in current BASE. Handle optional leading '-' for negatives. Return the number and a success/fail flag.

5. **Compiler words**:
   - `,` (COMMA): Store cell at HERE, advance HERE by 3
   - `C,` (CCOMMA): Store byte at HERE, advance HERE by 1
   - `ALLOT`: Add n bytes to HERE
   - `[` (LBRAC): Set STATE=0 (immediate)
   - `]` (RBRAC): Set STATE=non-zero

6. **CREATE**: Build a dictionary header — read next word from input, lay down link/flags/name, update LATEST.

7. **:** (COLON) and **;** (SEMICOLON):
   - COLON: calls CREATE, writes DOCOL header (bra+padding) as CFA, enters compile mode (] )
   - SEMICOLON (IMMEDIATE): compiles EXIT into current definition, enters interpret mode ([)

8. **IMMEDIATE**: Toggle the IMMEDIATE flag on the most recently defined word.

9. **Word input (WORD)**: Read characters from UART input, skip leading spaces, collect until next space or newline. Store as counted string in a buffer. This is needed for FIND and CREATE.

10. **Test**: Hand-assemble dictionary headers for existing primitives so they can be found by FIND. Add a test that:
    - Defines dictionary headers for at least: DUP + EMIT EXIT
    - Calls FIND to look up a word
    - Verifies the compiler can lay down .word entries via COMMA
    - Test output validates via cor24-run

### Key constraints
- Cell size = 3 bytes for all pointers and .word entries
- Dictionary grows upward from after the kernel code
- HERE must be initialized to first free byte after all assembled code
- Names are case-sensitive, stored as raw ASCII bytes
- WORD needs a small input buffer (e.g., 32 bytes at a fixed address)