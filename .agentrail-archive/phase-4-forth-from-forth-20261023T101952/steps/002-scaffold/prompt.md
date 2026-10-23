Scaffold the `forth-from-forth/` directory as a sibling to
`forth-on-forthish/`, following the same structure:

```
forth-from-forth/
  kernel.s         -- initial copy of forth-on-forthish/kernel.s
  core/            -- copies of the 5 .fth tiers (verbatim)
  scripts/         -- demo.sh, dump.sh, etc. (paths adjusted)
  docs/
    design.md      -- already written in step 1 (move here if
                      it was placed at repo root)
    prd.md         -- copy from forth-on-forthish/, update text
    architecture.md
    plan.md        -- subset list for phase 4
    status.md      -- live tracker
    kernel-sizes.md
  compiler/        -- new directory for the cross-compiler tool
    README.md      -- placeholder, describes the compiler
```

Confirm `scripts/demo.sh examples/14-fib.fth` in the new
directory produces the same output as `forth-on-forthish/
scripts/demo.sh` — it should, because the kernel.s and .fth
files are verbatim copies.

Create `reg-rs/tf24a_fff_fib` baseline (mirrors the fof_fib
pattern) so future phase-4 work has a regression check from
day one. Commit both `~/.local/reg-rs/tf24a_fff_fib.{rgt,out}`
and the repo copy in `reg-rs/`.

This step creates NO new functionality beyond scaffolding;
the kernel is identical to phase 3.
