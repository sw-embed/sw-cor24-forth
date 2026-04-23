# Status — forth-from-forth

Last updated: 2026-04-23 (step 002 scaffold)

Authoritative step state: `agentrail status`.

## Progress

| Step | Description | State | Commit |
|------|-------------|-------|--------|
| 001 | design — pure-Forth cross-compiler, no hash initially | done | e1e4044 |
| 002 | scaffold — `forth-from-forth/` verbatim copy of phase 3 | done | *current* |
| 003 | compiler MVP (runtime.fth only) | pending | — |
| 004 | boot into runtime-only image | pending | — |
| 005 | compiler full core | pending | — |
| 006 | pure-image boot | pending | — |
| 007 | delete-validation | pending | — |
| 008 | re-baseline reg-rs | pending | — |
| 009 | phase-4 wrap | pending | — |

## Starting state (step 002)

`forth-from-forth/` is a verbatim copy of `forth-on-forthish/`:

- `kernel.s`: 2659 asm lines, byte-identical to
  `../forth-on-forthish/kernel.s`.
- `core/*.fth`: five tiers, byte-identical to
  `../forth-on-forthish/core/*.fth`.
- `scripts/*.sh`: four shell scripts with comments updated to
  mention `forth-from-forth` instead of `forth-on-forthish`;
  internal variable names unchanged.
- `compiler/xcomp.fth`: empty shell (one comment line).
- `core/prims.fth`: empty shell (one comment line).
- `docs/*.md`: design, prd, architecture, plan, this file.

`scripts/demo.sh examples/14-fib.fth` produces identical fib
output to the phase-3 demo: `1 1 2 3 5 8 13 21 34 55 89`.

`reg-rs/tf24a_fff_fib` baseline captured against this copy;
it will be re-baselined once the compiler starts modifying
kernel.s.

## Line counts

| File | Now (step 002) | Target (end phase 4) |
|------|---------------:|---------------------:|
| `kernel.s` (generated) | 2659 | ≤ 2000 |
| `core/*.fth` | 450 | 450 (unchanged) |
| `compiler/xcomp.fth` | 1 (stub) | ≤ 500 |
| `core/prims.fth` | 1 (stub) | ~400 |

## Next action

Step 003 — build compiler MVP targeting `runtime.fth` only.
Run `agentrail next` to start.
