Emit the primitives from Forth too, so forth-from-forth/kernel.s contains no hand-written assembly (split out of step 6 on 2026-10-23; step 6a, image boot, is done).

Today scripts/build-image.sh splices the cross-compiled core into a template, ../forth-on-forthish/kernel.s, which supplies _start, NEXT/DOCOL, every primitive, the UART layer and the (now unused) bootstrap. Move that assembly into core/prims.fth: each `PRIM: name label` line grows the asm body it emits (a block the compiler copies through, e.g. between `PRIM:` and `;PRIM`), plus a non-word section for _start, DOCOL, NEXT and data. Do it in small gated increments: move a few primitives at a time and require the generated kernel.s to assemble to the same bytes as before (cor24-asm --bin, cmp) until the template is empty.

Hard requirement: KEY's busy-wait label stays `key_poll` (16-byte window), and any other UART busy-wait keeps a label listed in web-sw-cor24-forth/src/pump.rs POLL_LABELS, or the web tab never feeds input. Keep the emulator's `-u` escape rule in mind: no backslash followed by n, r, t, x or 0 anywhere in prims.fth.

Done when the template is gone, kernel.s is generated only from Forth sources, the byte comparison holds, and reg-rs is green.
