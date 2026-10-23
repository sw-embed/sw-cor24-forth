Extend the cross-compiler to digest all five core tiers:
runtime, minimal, lowlevel, midlevel, highlevel.

Each tier depends on words defined in prior tiers — the compiler
must load them in order and resolve cross-tier references. By
the end of highlevel.fth, Forth INTERPRET + QUIT + the handoff
lines (`' QUIT QUIT-VECTOR !` and `QUIT`) must all be present
in the image.

Challenges to solve in this step:
- IMMEDIATE control flow: `BEGIN`/`AGAIN`/`IF`/`THEN`/`ELSE`/
  `UNTIL`/`WHILE`/`REPEAT`/`DO`/`LOOP`/`?DO` are IMMEDIATE words
  defined in minimal.fth and midlevel.fth. The compiler must
  execute them at compile time, which means the compiler needs
  to actually RUN their Forth bodies (or re-implement their
  host-side logic).
- `[']` compile-time tick: resolves to `LIT <cfa>` in the body.
- `CONSTANT` / `VARIABLE` / `DO` / `LOOP` / `?DO` / `I` /
  `UNLOOP` — defined in lowlevel.fth using IMMEDIATE runtime
  primitives. Compiler must handle the runtime primitives
  (`(DO)`, `(LOOP)`, `(?DO)`) as kernel CFAs.
- Numeric literals: compile as `LIT n`.
- Comments (`\` and `(`): skip at parse time, no emission.

Two implementation strategies (pick one, document the choice):

A. Host-side replication: reimplement the IMMEDIATE compile-time
   logic in the host language. Fast, but duplicates the logic
   that already exists in Forth.

B. Metacircular: the compiler itself EXECUTEs the Forth words by
   simulating the threaded-code inner interpreter on the host.
   More work upfront but aligns with "Forth is its own metalang".

Deliverable:
- `compiler/fforth.py core/*.fth --out kernel_image.bin` produces
  a blob containing all ~90 dict entries.
- `reg-rs/tf24a_fff_fib` (updated preprocess if needed) passes
  with the image-loaded kernel running 14-fib.fth.
