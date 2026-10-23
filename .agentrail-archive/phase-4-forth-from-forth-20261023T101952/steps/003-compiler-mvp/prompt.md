Build the minimum viable cross-compiler that can digest
`forth-from-forth/core/runtime.fth` (13 lines) and emit a binary
dict image.

Scope for this step — runtime.fth ONLY:
- `: DUP SP@ @ ;` ... through `: NEGATE INVERT 1 + ;` — 10
  colon defs using primitives from the kernel.
- Forth `:` and `;` bootstrapping: the compiler must resolve
  the old asm `:` / `;` for compiling the Forth `:` / `;` defs
  themselves (lines 12-13 of runtime.fth).
- Output: a single binary blob in `forth-from-forth/compiler/
  out/runtime.bin` with the dict entries + hash-table updates.

Build in the chosen language (Python 3 if step 1 chose Python).
Structure:

```
compiler/
  fforth.py           -- main cross-compiler entry point
  fforth/
    kernel_syms.py    -- parses kernel.s for primitive CFAs
    parser.py         -- .fth → token stream
    dict_builder.py   -- emits dict entries + CFA bodies
    image.py          -- packs to final binary format
  tests/
    test_runtime.py   -- roundtrip test for runtime.fth
```

Deliverables:
1. Tool runs via `python3 compiler/fforth.py core/runtime.fth
   --out compiler/out/runtime.bin` (or equivalent).
2. Emitted dict structure matches byte-for-byte what phase-3
   `forth-on-forthish/kernel.s` produces at runtime when it
   INTERPRETs the same .fth source. (Verify by dumping both
   and comparing.)
3. Unit test in `compiler/tests/test_runtime.py` asserts the
   expected dict layout for at least one colon def (e.g., DUP).
4. Do NOT modify kernel.s yet — step 4 handles boot integration.

If byte-for-byte match is too ambitious for the first pass,
document the divergence in a diff and settle for functional
equivalence (same words findable, same CFAs callable).
