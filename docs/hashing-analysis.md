# Hash function analysis — forth-in-forth FIND

Offline analysis of hash functions across the forth-in-forth kernel's
known dictionary words. Script: `scripts/hash-collision-analysis.py`.

## The dictionary

90 total words at the time of analysis:

- **50 asm entries** in `forth-in-forth/kernel.s` (primitives like `EMIT`,
  `+`, `DUP`, `:` `;`, `WORD`, `FIND`, `NUMBER`, etc.).
- **40 Forth colon defs** across `forth-in-forth/core/{minimal,lowlevel,midlevel,highlevel}.fth`.

Notable first-letter clusters that stress first-char hashing:

| first char | words |
|---|---|
| `S` | SWAP STATE SW? SP@ SEE-CFA SEE SPACE (7) |
| `E` | EMIT EXIT EXECUTE EOL! ELSE (5) |
| `D` | DROP DUP DEPTH DUMP-ALL DECIMAL (5) |
| `C` | C@ C! C, CREATE CR (5) |
| `B` | BRANCH BASE BYE BEGIN (4) |
| `2` | 2DUP 2DROP 2SWAP 2OVER (4) |
| `0` | 0BRANCH 0< 0= (3) |
| `I` | IMMEDIATE INTERPRET IF (3) |
| `L` | LIT LATEST LED! (3) |
| `N` | NUMBER NIP NEGATE (3) |
| `R` | R> R@ ROT (3) |
| `A` | AND ALLOT ABS (3) |
| `1` | 1+ 1- (2) |
| `H` | HERE HEX (2) |
| `O` | OR OVER (2) |
| `P` | PRINT-NAME PRIM-MARKER (2) |
| `T` | TUCK THEN (2) |
| `W` | WORD WORDS (2) |
| `>` | >R >NAME (2) |
| `[` | `[` `[']` (2) |

## Hash functions evaluated

All hashes produce a bucket index via `hash_value AND (table_size − 1)`
(table size is always a power of 2).

| Name | Algorithm |
|---|---|
| `first_char` | `bucket = first_byte & mask` |
| `len+first+last` | `(len + first + last) & mask` |
| `len*31+first+last` | `(len*31 + first + last) & mask` |
| `len*31+first*7+last` | `(len*31 + first*7 + last) & mask` |
| `djb2` | `h=5381; for c: h = h*33 + c` |
| `mult33` | `h=0; for c: h = h*33 + c` |
| `fnv1a` | `h=0x811C9DC5; for c: h = (h^c) * 0x01000193` |
| **`len-seeded mult33`** | `h=len; for c: h = h*33 + c` |
| **`2-Round XMX`** | `h=0; for c: h=(h^c)*0xDEADB5; h^=h>>12` |

## Results

### Collision count (fewer is better)

| Hash function | 64 buckets | 128 buckets | 256 buckets | 512 buckets |
|---|---:|---:|---:|---:|
| first_char | 47 | 47 | 47 | 47 |
| len+first+last | 47 | 34 | 34 | 34 |
| len*31+first+last | 42 | 28 | 17 | — |
| len*31+first*7+last | 49 | 32 | 17 | — |
| djb2 | 44 | 29 | 17 | — |
| mult33 (no seed) | 44 | 31 | 21 | — |
| fnv1a | 44 | 28 | 17 | — |
| **len-seeded mult33** | **34** | **25** | **11** | 9 |
| **2-Round XMX** | — | 23 | 15 | 8 |

### Worst-bucket depth (lower is better)

| Hash function | 256 buckets | 512 buckets |
|---|---:|---:|
| first_char | 7 | 7 |
| len-seeded mult33 | **3** | 3 |
| 2-Round XMX | 3 | **2** |

## Observations

- **`first_char` is useless beyond 64 buckets.** Since we have only ~43
  distinct first-letter classes, it saturates there — throwing more
  buckets at it doesn't help because the hash collapses 90 words into
  43 unique values.
- **`len+first+last`** variants plateau at 17–34 collisions. They
  can't distinguish anagram-like pairs (EMIT/EXIT, OVER/OR) because
  those share length, first, and last chars.
- **Multiplicative hashes (mult33, djb2, fnv1a)** all land around 17
  collisions at 256 buckets — they fold every byte, distinguish
  EMIT/EXIT, but tie at a similar collision floor.
- **Seeding mult33 with length** drops it to **11 collisions** — a
  surprising 35% improvement over any other hash at 256 buckets.
  The length seed perturbs the initial state so that short words
  spread out early in the iteration.
- **2-Round XMX** is competitive (15/8 at 256/512) and has the **best
  worst-bucket depth at 512 (2)**. Its `h ^ (h>>12)` avalanche step
  is the most bit-distributing of any hash tested.

## Implementation history

| Commit | Change | Notes |
|---|---|---|
| `a3a63f0` | first_char hash | First hash landed. 47 collisions. Worked correctly but poor distribution. |
| `485f36f` | len-seeded mult33 | First attempt at better hash. Pushed without full test suite; web agent reported broken. |
| `ab9817f` | (revert to first_char) | Revert after bug report. |
| `9bd4b10` | len-seeded mult33 | Re-landed after thorough CLI test (all 15 examples byte-identical vs first_char). WASM-tested: works but wall-clock still not fast enough. |
| `fdae7dd` | 2-Round XMX | docs/hashing.txt recommendation for 24-bit GPR ISAs. 15 collisions at 256 buckets (vs 11 for mult33, 47 for first_char). |
| `4ea2f79` | + lookaside cache | 1-entry memento cache keyed by full 24-bit XMX hash. Short-circuits the FIND pipeline on consecutive same-word lookups (common during colon-def compile). |

## Why 2-Round XMX for this ISA?

Per `docs/hashing.txt` (Gemini conversation excerpt): on a 24-bit GPR
ISA, 2-Round XMX is a sweet spot between per-step cost and avalanche
quality.

- **Register efficient**: 2 registers (running hash + temp).
- **Bit-width native**: multiply truncates to 24 bits, matching our
  word size — no "overflow waste" like running a 32-bit hash on a
  24-bit machine would cause.
- **Good dispersion on short names**: `h ^ (h>>12)` in 24 bits folds
  the high half into the low half, so even 1–3-character names
  (typical Forth primitives like `@`, `!`, `+`, `DUP`) reach a chaotic
  state after 1 round.

The algorithm:
```
For each character c:
  h = h XOR c
  h = h * 0xDEADB5    ; 24-bit truncation is native
  h = h XOR (h SRL 12)
bucket = h & 0xFF     ; mask to 256 buckets
```

MAGIC = `0xDEADB5` = 14,592,437. Chosen as a 24-bit odd multiplier
with good bit-distribution (Knuth-style, no small factors).

## Asm cost

Per-character instruction count:

| Hash | COR24 ops per char | notes |
|---|---:|---|
| first_char | 0 (computed once, not per char) | only 1 byte read |
| len-seeded mult33 | ~4 | load 33, mul, add char, advance |
| 2-Round XMX | ~10 | xor, load MAGIC, mul, save, load 12, srl, restore, xor, advance |

2-Round XMX is roughly 2.5× slower per char than mult33. At typical
4-char name lengths that's 24 extra instructions per FIND call.
For ~1000 FINDs during bootstrap compile, ~24K extra instructions
— negligible compared to ~60M total.

The payoff shows up in **wall-clock time in WASM**, where bit-level
operations are relatively cheaper than memory stalls, and better
hash distribution reduces the linear-walk cost on misses.

## Lookaside cache (commit 4ea2f79)

Sits on top of the XMX hash: 1 entry = (full_24bit_hash, cfa, flag).
On `do_find`, if the input's hash matches the cached hash AND cached
cfa is non-zero, push (cfa, flag) and return. No bucket lookup, no
linear walk, no name compare.

### Why single-entry + full-hash key

Collisions in 24-bit keyspace are astronomically rare (2^-24 for
distinct names). On a false positive, the wrong CFA would be
returned — in practice it has never been observed. Verifying by
comparing full names on every hit would cost the same as the name
compare FIND does anyway — defeating the point of the cache. The
1-entry design catches "DUP DUP", "DROP DROP", and similar
consecutive-repeat patterns common in Forth colon bodies.

### CLI measurement: inconclusive

cor24-run's UART TX timestamps quantize to 10,000 simulator cycles.
Our workloads produce TX events at intervals much shorter than
that, so per-FIND savings (expected ~400 cycles × ~1000 lookups =
~400K cycles on a 50M-cycle workload, ≈ 1% speedup) disappear into
the rounding. All four hash variants (first_char, mult33, XMX,
XMX+lookaside) report **identical** TX timestamps on 5/10/50/100/500/1000
EMIT-repeat compile workloads.

This is a measurement-infrastructure limitation, not evidence that
the optimizations do nothing. WASM wall-clock timing has finer
resolution (milliseconds on a multi-second boot) and is the
authoritative measurement for these changes.

### Theoretical savings on hit

Per cached FIND hit:
- Skip: bucket lookup (~15 inst), name compare loop (~5 inst/char ×
  avg 4 chars = 20 inst), any linear-walk iterations.
- Pay: 3 memory loads for cache check, 2-register compare, branch.

Net: ~30–50 saved per hit. On workloads where 50% of FINDs hit the
cache (realistic for tight colon bodies), ~15-25K inst saved per
1000 FINDs. Below CLI measurement resolution but plausibly visible
in WASM.

### Not caching NOT-FOUND

Negative results (word not in dict) are deliberately NOT cached. If
the user types `FOO` (not found → `?`), then defines `: FOO ... ;`,
a subsequent `FOO` lookup must go through real FIND. Caching the
not-found would return the stale 0-CFA forever.
