# sw-cor24-forth — Tiny Forth for COR24

Clean-room DTC (Direct Threaded Code) Forth for the COR24 24-bit RISC soft-CPU ISA.
Assembler kernel (`forth.s`), self-extending in Forth.

Part of the [COR24 ecosystem](https://github.com/sw-embed/sw-cor24-project).

## Provenance

Forked from [sw-vibe-coding/tf24a](https://github.com/sw-vibe-coding/tf24a)
as part of the COR24 ecosystem consolidation under the `sw-embed` organization.

## Prerequisites

- `cor24-run` — build from [sw-cor24-emulator](https://github.com/sw-embed/sw-cor24-emulator)
- `sed-rs` — used by test scripts

## Quick Start

```bash
# Run demo
./demo.sh

# Interactive REPL
./demo.sh repl

# Run test suite
./demo.sh test

# Or via build script
scripts/build.sh
```

## Architecture

- **forth.s** — 2600+ line COR24 assembly implementing a complete DTC Forth
- **Register allocation**: r0=W, r1=RSP, r2=IP, sp=DSP
- **Cell size**: 3 bytes (24-bit words)
- **I/O**: UART at address -65280 (0xFF0100)

## Built-in Words

`+` `-` `*` `AND` `OR` `XOR` `=` `<` `0=` `DUP` `DROP` `SWAP` `OVER`
`>R` `R>` `R@` `@` `!` `C@` `C!` `EMIT` `KEY` `EXIT`
`HERE` `LATEST` `STATE` `BASE` `,` `C,` `ALLOT`
`WORD` `FIND` `CREATE` `:` `;` `IMMEDIATE` `[` `]`
`EXECUTE` `NUMBER` `.` `LED!` `INTERPRET` `QUIT`
`CR` `SPACE` `HEX` `DECIMAL` `DEPTH` `.S` `WORDS` `BYE`

## Examples

See `examples/` for `.fth` source files demonstrating colon definitions,
LED control, math, and more.

## Related Repositories

- [sw-cor24-emulator](https://github.com/sw-embed/sw-cor24-emulator) — COR24 emulator + ISA
- [sw-cor24-project](https://github.com/sw-embed/sw-cor24-project) — ecosystem hub

## Links

- Blog: [Software Wrighter Lab](https://software-wrighter-lab.github.io/)
- Discord: [Join the community](https://discord.com/invite/Ctzk5uHggZ)
- YouTube: [Software Wrighter](https://www.youtube.com/@SoftwareWrighter)

## Copyright

Copyright (c) 2026 Michael A. Wright

## License

MIT License. See [LICENSE](LICENSE) for the full text.
