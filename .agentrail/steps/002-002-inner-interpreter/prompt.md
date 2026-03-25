## Phase 2: Inner Interpreter and Arithmetic Primitives

Wire up DTC threading so EMIT and KEY run via NEXT. Build the colon-definition machinery.

### Deliverable
Extend forth.s with:

1. **NEXT macro** (inlined at tail of every primitive — already present in EMIT/KEY)

2. **DOCOL**: Code that a colon definition's CFA points to. Pushes IP to return stack, sets IP to the parameter field (CFA+3), then falls into NEXT.

3. **EXIT**: Pops IP from return stack, falls into NEXT. Ends every colon definition's thread.

4. **LIT**: Fetches inline literal from thread (cell at IP), pushes to data stack, advances IP by 3.

5. **BRANCH / 0BRANCH**: BRANCH adds inline offset to IP unconditionally. 0BRANCH pops TOS: if zero, adds offset; else skips offset cell.

6. **Arithmetic primitives**: Each pops operands from data stack, pushes result, ends with NEXT.
   - `+` `-` `AND` `OR` `XOR` `=` `<` `0=`
   - For `=` and `<`: push -1 (true) or 0 (false)

7. **Stack ops**: DROP DUP SWAP OVER >R R> R@

8. **Memory**: @ ! C@ C!

9. **Test**: Hand-assemble a colon definition that computes and prints a result:
   ```
   ; : TEST  42 EMIT 10 EMIT ;   (prints star-newline)
   ; : DOUBLE  DUP + ;
   ; : MAIN  3 DOUBLE 48 + EMIT 10 EMIT ;  (prints '6' then newline)
   ```
   Thread these as .word sequences, set IP, and verify output via cor24-run.

### Key constraints
- r2 = IP must be valid whenever NEXT runs
- Return stack operations via r1: add r1,-3/sw then lw/add r1,3
- fp is limited — avoid la/lcu/and with fp
- Cell size = 3 bytes everywhere