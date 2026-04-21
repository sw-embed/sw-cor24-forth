# Project plan — sw-cor24-forth

Project-level roadmap. Per-approach plans live under each kernel's
`docs/plan.md`:

- `./forth-in-forth/docs/plan.md` — approach 2 (done, in maintenance).
- `./forth-on-forthish/docs/plan.md` — approach 3 (in progress).
- `./forth-from-forth/docs/plan.md` — approach 4 (future).

See [`future.md`](future.md) for the four-approach architectural
comparison.

## Optimization track (parallel to approach work)

Inspired by slow WASM boot times reported by the web UI. Broken into
sub-tracks (a)–(d).

### (a) Hashed FIND — DONE (forth-in-forth)

Replace linear-scan FIND with a 256-bucket hash table.

- Commit: `a3a63f0` (first-char hash — starting point).
- Iterations: a3a63f0 → 9bd4b10 (len-seeded mult33) → fdae7dd (2-Round XMX).
- Analysis: [`hashing-analysis.md`](hashing-analysis.md).

### (b) Better hash function — DONE (forth-in-forth)

Replace first-char with a full-name hash. Settled on 2-Round XMX
(commit `fdae7dd`) per [`hashing.txt`](hashing.txt) for 24-bit GPR ISAs.

### (c) FIND lookaside cache — DONE (forth-in-forth)

1-entry memento-pattern cache keyed by the full 24-bit XMX hash.
Short-circuits consecutive same-word lookups.

- Commit: `4ea2f79`.

### (d) Pre-compiled dictionary image — DEFERRED

**Goal**: boot the kernel with the full core dictionary (`core/*.fth`)
already compiled, skipping the ~60M-cycle bootstrap compile step.
Biggest single user-visible WASM speedup potentially available.

**Approach sketch**:
1. **Build-time**: run the normal `forth-in-forth` kernel through the
   core tier files, snapshot the final memory state (dict region +
   HERE/LATEST/STATE/BASE + hash table), emit a binary image.
2. **Runtime**: `cor24-run --load-binary image.bin@<addr> --run
   kernel.s` loads the image alongside the kernel. A sentinel/magic
   in the image tells `_start` to skip the normal init and use the
   preloaded state directly.
3. **Measure**: WASM boot time should drop from ~10s (current with
   core-over-UART) to ~100ms (just load + jump to QUIT).

**Why deferred**:
- Alignment with phase 4 (`forth-from-forth/`): a Forth-hosted cross-
  compiler emits the complete kernel binary including all of core as
  baked-in dict entries. Same deliverable as (d), arrived at from a
  different angle.
- Investment cost: ~200 lines of new asm (magic detection, image-
  load path) + a Python build tool + changes to scripts/. Similar
  effort to building the first pass of the cross-compiler, which
  covers more ground.
- Interim mitigation: the (a)+(b)+(c) hash stack is shipped and
  under WASM test. If it proves sufficient, (d) may never need to
  ship — WASM boot might be "fast enough" already.

**Revisit if**: WASM boot remains painfully slow after the hash
stack is deployed AND there's appetite to build the tool chain
before phase 4 starts in earnest.

## Phase track (kernel architectures)

### Phase 1 — original `forth.s` — DONE

Canonical all-asm kernel. Reference implementation.

### Phase 2 — `./forth-in-forth/` — DONE

Tiered Forth on a slimmed asm kernel (~2240 lines asm, ~160 lines
Forth). All 11 subsets (scaffold → move IF/THEN/BEGIN/UNTIL → move
comments → move `.S` → etc.) shipped.

### Phase 3 — `./forth-on-forthish/` — IN PROGRESS

Minimal-primitive kernel (~22 primitives target) with ~700 lines asm
and most code in Forth. Subset 12 (scaffold) done. Subsets 13–21
pending.

Per-subset status in [`../forth-on-forthish/docs/status.md`](../forth-on-forthish/docs/status.md).

### Phase 4 — `./forth-from-forth/` — FUTURE

Forth-hosted cross-compiler that emits the entire kernel binary.
No hand-written asm. Subsumes (d) pre-compiled dict image as a
byproduct.

Not started. See [`future.md`](future.md) for the architectural sketch.
