// Forth on COR24 — presentation generator (pptxgenjs → .pptx → .odp via LibreOffice)
const pptxgen = require("pptxgenjs");
const { applyTheme } = require("/Users/mike/.claude/skills/synced/96fbada7-b7f7-4ddf-a84c-1ecacf227b8a_51a621de-812b-4c42-a1e7-2c9b01cf612b/pptx/scripts/apply_theme.js");

const THEME = {
  name: "COR24 Forth",
  headFontFace: "Cambria",
  bodyFontFace: "Calibri",
  colors: {
    dk1: "1E2228", // charcoal (terminal background)
    lt1: "FFFFFF",
    dk2: "2B6777", // teal slate
    lt2: "EEF3F5", // card tint
    accent1: "E07A1F", // amber (prompt / highlight)
    accent2: "2B6777",
    accent3: "C8102E", // LED red
    accent4: "6C8EAD",
    accent5: "8A949E",
    accent6: "3E7C4A",
    hlink: "2B6777",
    folHlink: "6C8EAD",
  },
};

const pres = new pptxgen();
pres.layout = "LAYOUT_16x9"; // 10 x 5.625 in
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.title = "Forth on COR24";
pres.author = "sw-embed";
const C = pres.SchemeColor;
const RR = pres.ShapeType.roundRect;
const EL = pres.ShapeType.ellipse;
const ARR = pres.ShapeType.rightArrow;
const MONO = "Courier New";
const FOOT = "Forth on COR24  ·  sw-embed";

// ---------- layouts ----------
pres.defineSlideMaster({
  title: "DARK_TITLE",
  background: { color: THEME.colors.dk1 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 1.55, w: 8.8, h: 1.1, fontSize: 40, bold: true, color: C.background1, margin: 0, valign: "bottom", align: "left" } } },
    { placeholder: { options: { name: "body", type: "body", x: 0.6, y: 2.75, w: 8.8, h: 0.9, fontSize: 18, color: C.accent1, margin: 0, valign: "top" } } },
  ],
});
pres.defineSlideMaster({
  title: "SECTION",
  background: { color: THEME.colors.dk2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 2.0, w: 8.8, h: 1.0, fontSize: 36, bold: true, color: C.background1, margin: 0, valign: "middle", align: "left" } } },
    { placeholder: { options: { name: "body", type: "body", x: 0.6, y: 3.05, w: 8.8, h: 0.6, fontSize: 16, color: C.background2, margin: 0, valign: "top" } } },
  ],
});
pres.defineSlideMaster({
  title: "CONTENT",
  background: { color: THEME.colors.lt1 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.5, y: 0.28, w: 9.0, h: 0.62, fontSize: 26, bold: true, color: C.text1, margin: 0, valign: "middle" } } },
    { text: { text: FOOT, options: { x: 0.5, y: 5.22, w: 5, h: 0.25, fontSize: 9, color: C.accent5, margin: 0 } } },
  ],
  slideNumber: { x: 9.0, y: 5.22, w: 0.5, h: 0.25, fontSize: 9, color: THEME.colors.accent5, align: "right" },
});

// ---------- helpers ----------
let n = 0;
const name = (s) => `${s} ${++n}`;

function codeBox(slide, x, y, w, h, lines, size = 11) {
  slide.addShape(RR, { x, y, w, h, fill: { color: C.text1 }, line: { color: C.text1, width: 0 }, rectRadius: 0.08, objectName: name("code background") });
  const runs = lines.map((t, i) => ({ text: t, options: { breakLine: i < lines.length - 1 } }));
  slide.addText(runs, { x: x + 0.14, y: y + 0.08, w: w - 0.28, h: h - 0.16, fontFace: MONO, fontSize: size, color: C.background1, margin: 0, valign: "top", isTextBox: true, objectName: name("code") });
}

function card(slide, x, y, w, h, glyph, head, body, accent = C.accent2, bodySize = 11.5) {
  slide.addShape(RR, { x, y, w, h, fill: { color: C.background2 }, line: { color: C.background2, width: 0 }, rectRadius: 0.1, objectName: name("card") });
  slide.addShape(EL, { x: x + 0.16, y: y + 0.15, w: 0.38, h: 0.38, fill: { color: accent }, line: { color: accent, width: 0 }, objectName: name("icon") });
  slide.addText(glyph, { x: x + 0.16, y: y + 0.15, w: 0.38, h: 0.38, fontSize: 12, bold: true, color: C.background1, align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: name("glyph") });
  slide.addText(head, { x: x + 0.64, y: y + 0.12, w: w - 0.78, h: 0.44, fontSize: 14, bold: true, color: C.text1, margin: 0, valign: "middle", isTextBox: true, objectName: name("card head") });
  slide.addText(body, { x: x + 0.16, y: y + 0.64, w: w - 0.32, h: h - 0.76, fontSize: bodySize, color: C.text1, margin: 0, valign: "top", isTextBox: true, objectName: name("card body") });
}

function bullets(slide, x, y, w, h, items, size = 13) {
  const runs = items.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < items.length - 1, paraSpaceAfter: 5 } }));
  slide.addText(runs, { x, y, w, h, fontSize: size, color: C.text1, margin: 0, valign: "top", isTextBox: true, objectName: name("bullets") });
}

function table(slide, rows, x, y, w, colW, fs = 10.5, rowH = 0.3) {
  const header = rows[0].map((t) => ({ text: t, options: { bold: true, color: C.background1, fill: { color: C.text2 }, fontSize: fs } }));
  const body = rows.slice(1).map((r) => r.map((t, ci) => ({ text: t, options: { fontSize: fs, color: C.text1, bold: ci === 0 } })));
  slide.addTable([header, ...body], { x, y, w, colW, border: { type: "solid", color: "D5DCE1", pt: 0.5 }, fontFace: THEME.bodyFontFace, margin: 0.05, rowH, valign: "middle", objectName: name("table") });
}

function stat(slide, x, y, w, big, label, color = C.accent1) {
  slide.addText(big, { x, y, w, h: 0.75, fontSize: 40, bold: true, color, margin: 0, valign: "bottom", isTextBox: true, objectName: name("stat") });
  slide.addText(label, { x, y: y + 0.78, w, h: 0.5, fontSize: 11, color: C.text1, margin: 0, valign: "top", isTextBox: true, objectName: name("stat label") });
}

function flowBox(slide, x, y, w, h, text, fill = C.background2, color = C.text1, size = 11) {
  slide.addShape(RR, { x, y, w, h, fill: { color: fill }, line: { color: fill, width: 0 }, rectRadius: 0.08, objectName: name("flow box") });
  slide.addText(text, { x: x + 0.06, y, w: w - 0.12, h, fontSize: size, color, align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: name("flow text") });
}
function arrow(slide, x, y, w = 0.3, h = 0.3) {
  slide.addShape(ARR, { x, y, w, h, fill: { color: C.accent1 }, line: { color: C.accent1, width: 0 }, objectName: name("arrow") });
}

function content(title, section) {
  const s = pres.addSlide({ masterName: "CONTENT", sectionTitle: section });
  s.addText(title, { placeholder: "title" });
  return s;
}
function section(title, sub, sec) {
  const s = pres.addSlide({ masterName: "SECTION", sectionTitle: sec });
  s.addText(title, { placeholder: "title" });
  s.addText(sub, { placeholder: "body" });
  return s;
}

// ============================================================
// 1. Title
// ============================================================
pres.addSection({ title: "Intro" });
{
  const s = pres.addSlide({ masterName: "DARK_TITLE", sectionTitle: "Intro" });
  s.addText("Forth on COR24", { placeholder: "title" });
  s.addText("Forth kernels for a 24-bit soft CPU: all assembly, Forth-in-Forth, Forth on a Forth-shaped substrate, and a fourth, compiled by Forth, in progress", { placeholder: "body" });
  codeBox(s, 0.6, 3.75, 5.2, 1.1, [": SQUARE  DUP * ;", "  ok", "5 SQUARE .", "25  ok"], 12);
  s.addText("Mike Wright", { x: 0.6, y: 4.95, w: 4.0, h: 0.3, fontSize: 14, bold: true, color: C.background1, margin: 0, isTextBox: true, objectName: "title author" });
  s.addText("2026 October 24  ·sw-embed.github.io/web-sw-cor24-forth", { x: 4.6, y: 4.95, w: 4.8, h: 0.3, fontSize: 11, color: C.accent5, margin: 0, align: "right", valign: "middle", isTextBox: true, objectName: "title footer" });
  s.addNotes("Deck covers the COR24 target and its ISA limits, the three Forth implementations in sw-cor24-forth, how they compare with other Forths, the demo set in the web UI, and the everyday workflow of defining, listing, running and redefining words.");
}

// ============================================================
// 2. Agenda
// ============================================================
{
  const s = content("What this deck covers", "Intro");
  const items = [
    ["1", "The target", "COR24 in one page, and what its ISA takes away from a Forth writer."],
    ["2", "Three implementations", "forth.s, forth-in-forth and forth-on-forthish: what each keeps in assembly and why. Plus forth.s hosted inside SWTOS."],
    ["3", "Choices vs. other Forths", "Threading, cell size, HERE semantics, division, dictionary search."],
    ["4", "The demos", "What each dropdown entry teaches, which tabs run it, and the hardware demos."],
    ["5", "Working with words", "Define, run, list, inspect, redefine and forget, in the web UI and on the CLI."],
  ];
  items.forEach((it, i) => {
    const y = 1.1 + i * 0.8;
    s.addShape(EL, { x: 0.6, y: y + 0.08, w: 0.46, h: 0.46, fill: { color: i % 2 ? C.accent2 : C.accent1 }, line: { color: C.background1, width: 0 }, objectName: name("agenda icon") });
    s.addText(it[0], { x: 0.6, y: y + 0.08, w: 0.46, h: 0.46, fontSize: 15, bold: true, color: C.background1, align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: name("agenda num") });
    s.addText(it[1], { x: 1.3, y, w: 8.0, h: 0.32, fontSize: 16, bold: true, color: C.text1, margin: 0, isTextBox: true, objectName: name("agenda head") });
    s.addText(it[2], { x: 1.3, y: y + 0.32, w: 8.0, h: 0.35, fontSize: 12.5, color: C.text1, margin: 0, isTextBox: true, objectName: name("agenda body") });
  });
}

// ============================================================
// 3. Section: target
// ============================================================
pres.addSection({ title: "The target" });
section("The target: COR24", "A 24-bit RISC soft CPU for Lattice MachXO FPGAs (makerlisp.com)", "The target");

// ============================================================
// 4. COR24 at a glance
// ============================================================
{
  const s = content("COR24 at a glance", "The target");
  stat(s, 0.5, 1.0, 2.0, "24-bit", "registers, addresses and cells; one cell is 3 bytes");
  stat(s, 0.5, 2.35, 2.0, "32", "opcodes in 211 forms; instructions are 1, 2 or 4 bytes", C.accent2);
  stat(s, 0.5, 3.7, 2.0, "1", "condition flag (C), set by ceq / clu / cls, tested by brt / brf", C.accent3);
  table(s, [
    ["Register", "Role in the Forth kernels"],
    ["r0", "W: work register, holds the fetched CFA"],
    ["r1", "RSP: return stack pointer, SRAM 0x0F0000 growing down"],
    ["r2", "IP: threaded-code instruction pointer"],
    ["sp", "DSP: data stack, hardware push / pop into 3 KB EBR, starts 0xFEEC00"],
    ["fp", "scratch; the only register that can index the EBR stack"],
    ["z, iv, ir", "hardwired zero; interrupt vector and return"],
  ], 3.0, 1.0, 6.5, [1.1, 5.4], 10.5, 0.3);
  table(s, [
    ["Address", "Device"],
    ["0x000000", "1 MB SRAM: kernel, dictionary, return stack"],
    ["0xFEE000", "3 KB EBR block RAM: the hardware data stack"],
    ["0xFF0000", "LED D2 (write) and switch S2 (read), same pin, active-low"],
    ["0xFF0100 / 01", "UART data and status (bit 0 RX ready, bit 7 TX busy)"],
  ], 3.0, 3.3, 6.5, [1.3, 5.2], 10.5, 0.3);
}

// ============================================================
// 5. ISA limitations
// ============================================================
{
  const s = content("What the ISA takes away from a Forth writer", "The target");
  const w = 2.95, h = 1.85;
  const xs = [0.5, 3.525, 6.55];
  const ys = [1.0, 3.05];
  card(s, xs[0], ys[0], w, h, "r", "Only r0, r1, r2 take results",
    "Loads and ALU results never land in fp or sp. There is no mov r0, sp: reading the stack pointer is mov fp, sp; push fp; pop r0. DEPTH and .S pay that dance.", C.accent1, 10.5);
  card(s, xs[1], ys[0], w, h, "±", "Branches reach ±127 bytes",
    "Anything farther is la r0, label; jmp (r0): 5 bytes and a clobbered W. The colon-word entry template therefore comes in a 3-byte near and a 6-byte far form.", C.accent2, 10.5);
  card(s, xs[2], ys[0], w, h, "r1", "jal links through r1",
    "r1 is the return stack pointer, so the kernels never use call / return. Every primitive ends in an inlined NEXT and all nesting goes through the Forth return stack.", C.accent3, 10.5);
  card(s, xs[0], ys[1], w, h, "÷", "mul, but no divide",
    "/MOD is repeated subtraction: assembly on forth.s, a Forth loop on forth-on-forthish. Printing a number with . is the most expensive thing a demo does.", C.accent6, 10.5);
  card(s, xs[1], ys[1], w, h, "8", "8-bit immediates, decimal only",
    "la costs 4 bytes and is the only way to reach I/O: la r0, -65280 for the UART. No string literals, no .align; names are .byte lists padded by hand.", C.accent4, 10.5);
  card(s, xs[2], ys[1], w, h, "!", "A 3 KB data stack that halts",
    "About 1,000 cells. The emulator stops the CPU on overflow, so a word that leaks one cell per loop turn kills a demo after ~500 turns. That exact bug shipped once (see Demos).", C.accent3, 10.5);
}

// ============================================================
// 6. Shared design
// ============================================================
{
  const s = content("Design shared by all three kernels", "The target");
  s.addText("Direct-threaded code: NEXT is 3 instructions, 5 bytes, inlined at the tail of every primitive", { x: 0.5, y: 1.0, w: 4.6, h: 0.5, fontSize: 12.5, bold: true, color: C.text1, margin: 0, isTextBox: true, objectName: "next caption" });
  codeBox(s, 0.5, 1.5, 4.6, 0.95, ["lw  r0, 0(r2)   ; W  = mem[IP]  (fetch CFA)", "add r2, 3       ; IP += one cell", "jmp (r0)        ; run the primitive"], 10.5);
  s.addText("Dictionary entry: a singly linked list, newest first", { x: 0.5, y: 2.6, w: 4.6, h: 0.4, fontSize: 12.5, bold: true, color: C.text1, margin: 0, isTextBox: true, objectName: "dict caption" });
  codeBox(s, 0.5, 3.0, 4.6, 1.25, ["link      3 bytes  previous entry, 0 ends the chain", "flags_len 1 byte   bit7 IMMEDIATE, bit6 HIDDEN, len", "name      N bytes  no terminator", "CFA       3 or 6 B near/far DOCOL template,", "                   or the primitive's own code"], 10);
  bullets(s, 5.5, 1.0, 4.0, 4.1, [
    "Registers are frozen across kernels: r0 = W, r1 = RSP in SRAM, r2 = IP, sp = DSP in EBR.",
    "HERE, LATEST, STATE and BASE push the variable's address, so Forth code writes HERE @. Unusual (JonesForth does it, ANS does not) but it keeps ! writes trivial.",
    "No loader: the kernel boots straight into QUIT and everything else, including core/*.fth, arrives as UART text, exactly as if typed.",
    "The outer loop echoes ok after every clean line and ? after an unknown token; a stack underflow prints a message and returns to the prompt.",
    "FIND walks the link chain on forth.s; tabs 2 and 3 add a 256-bucket first-character hash in front of the walk.",
  ], 12);
}

// ============================================================
// 7. Compared with other Forths
// ============================================================
{
  const s = content("Choices compared with other popular Forths", "The target");
  table(s, [
    ["Aspect", "COR24 Forth", "JonesForth", "eForth", "gforth"],
    ["Threading", "DTC, inlined NEXT", "ITC", "ITC or subroutine", "DTC / ITC / token"],
    ["Cell", "24-bit (3 bytes)", "32-bit", "16 / 32-bit", "32 / 64-bit"],
    ["Kernel source", "asm, down to ~22 prims + Forth", "x86 asm + Forth", "~30 prims + Forth", "C + Forth"],
    ["Standard", "pragmatic subset", "subset", "mostly ANS", "Forth-2012"],
    ["HERE", "variable (HERE @)", "variable (HERE @)", "value", "value"],
    ["Division", "repeated subtraction", "hardware idiv", "Forth-coded UM/MOD", "C / hardware"],
    ["Dictionary lookup", "link walk + first-char hash", "link walk", "link walk, vocabularies", "hashed"],
    ["I/O model", "memory-mapped UART, LED, switch", "Linux syscalls", "serial port", "host OS, files"],
    ["Numbers", "signed 24-bit, BASE; no floats", "32-bit, no floats", "16 / 32-bit", "floats, doubles"],
  ], 0.5, 1.0, 9.0, [1.4, 2.45, 1.6, 1.75, 1.8], 10, 0.36);
  s.addText("Deliberately missing: floating point, strings beyond EMIT, blocks, vocabularies, exceptions. Each would cost assembly the board does not need.", { x: 0.5, y: 4.8, w: 9.0, h: 0.3, fontSize: 11, italic: true, color: C.accent2, margin: 0, isTextBox: true, objectName: "missing note" });
}

// ============================================================
// 8. Section: implementations
// ============================================================
pres.addSection({ title: "Implementations" });
section("Three implementations", "in  ·  in-ish  ·  from: how much of the kernel is Forth", "Implementations");

// ============================================================
// 9. One language, three kernels
// ============================================================
{
  const s = content("One language, three kernels (and a fourth under way)", "Implementations");
  const cols = [
    ["1", "forth.s", "All-assembly kernel", C.accent1, ["3,498", "lines of asm"], ["0", "lines of Forth core"], ["~65", "primitives"], "Tab 1: the debugger. Canonical kernel for the FPGA board and the reg-rs golden tests."],
    ["2", "forth-in-forth", "Forth runs in a slimmed asm host", C.accent2, ["2,720", "lines of asm"], ["276", "lines in 4 core tiers"], ["50", "primitives, 61 colon words"], "Tab 2: self-hosting REPL. IF, ., WORDS, SEE are Forth."],
    ["3", "forth-on-forthish", "Forth on a Forth-ish substrate", C.accent3, ["2,659", "lines of asm (see note)"], ["497", "lines in 5 core tiers"], ["~22", "irreducible primitives, 82 colon words"], "Tab 3 (default): :, WORD, FIND, NUMBER, INTERPRET, QUIT are Forth."],
  ];
  cols.forEach((c, i) => {
    const x = 0.5 + i * 3.05, w = 2.9;
    s.addShape(RR, { x, y: 1.0, w, h: 3.55, fill: { color: C.background2 }, line: { color: C.background2, width: 0 }, rectRadius: 0.1, objectName: name("kernel card") });
    s.addShape(EL, { x: x + 0.16, y: 1.14, w: 0.4, h: 0.4, fill: { color: c[3] }, line: { color: c[3], width: 0 }, objectName: name("kernel icon") });
    s.addText(c[0], { x: x + 0.16, y: 1.14, w: 0.4, h: 0.4, fontSize: 14, bold: true, color: C.background1, align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: name("kernel num") });
    s.addText(c[1], { x: x + 0.66, y: 1.1, w: w - 0.8, h: 0.3, fontSize: 14, bold: true, fontFace: MONO, color: C.text1, margin: 0, isTextBox: true, objectName: name("kernel name") });
    s.addText(c[2], { x: x + 0.66, y: 1.38, w: w - 0.8, h: 0.3, fontSize: 10.5, italic: true, color: C.text1, margin: 0, isTextBox: true, objectName: name("kernel tag") });
    [c[4], c[5], c[6]].forEach((st, j) => {
      const y = 1.8 + j * 0.62;
      s.addText(st[0], { x: x + 0.16, y, w: 1.1, h: 0.5, fontSize: 20, bold: true, color: c[3], margin: 0, valign: "middle", isTextBox: true, objectName: name("kernel stat") });
      s.addText(st[1], { x: x + 1.28, y, w: w - 1.44, h: 0.5, fontSize: 10.5, color: C.text1, margin: 0, valign: "middle", isTextBox: true, objectName: name("kernel stat label") });
    });
    s.addText(c[7], { x: x + 0.16, y: 3.7, w: w - 0.32, h: 0.78, fontSize: 10.5, color: C.text1, margin: 0, valign: "top", isTextBox: true, objectName: name("kernel blurb") });
  });
  s.addText("4  forth-from-forth (phase 4, work in progress, two slides on): a cross-compiler written in Forth emits the kernel .s, so no hand-written assembly remains. Retargeting becomes a new asm-emit module.", { x: 0.5, y: 4.7, w: 9.0, h: 0.45, fontSize: 11, color: C.accent2, margin: 0, isTextBox: true, objectName: "phase 4 note" });
}

// ============================================================
// 10. forth.s
// ============================================================
{
  const s = content("forth.s: the all-assembly kernel (tab 1)", "Implementations");
  bullets(s, 0.5, 1.0, 5.1, 4.1, [
    "Generated: forth-core.s (target-independent DTC Forth) + forth-uart.s (UART at 0xFF0100, return stack at 0x0F0000, halting BYE). The layer contract is what lets SWTOS host the same core (next slide).",
    "Every word is assembly, including IF / THEN, ., WORDS, \\ and (. ~65 primitives, 3,879 bytes assembled.",
    "Richest vocabulary: FORGET, :NONAME, DO / ?DO / LOOP / I / UNLOOP, CONSTANT, VARIABLE, AGAIN / WHILE / REPEAT, DEPTH, .S.",
    "Fastest: the Fibonacci demo compiles and runs in about 40 M instructions.",
    "It is what runs on the physical board and what the reg-rs golden-output suite is baselined against, so it changes slowly.",
    "In the web UI it backs the debugger: step, step-over, breakpoints, registers, both stacks and memory, with the UART pump feeding input between steps.",
  ], 12);
  s.addText("A primitive, end to end: LED!", { x: 5.9, y: 1.0, w: 3.6, h: 0.35, fontSize: 12.5, bold: true, color: C.text1, margin: 0, isTextBox: true, objectName: "led caption" });
  codeBox(s, 5.9, 1.4, 3.6, 3.0, [
    "entry_led_store:",
    "  .word entry_immediate ; link",
    "  .byte 4               ; len",
    "  .byte 76, 69, 68, 33  ; \"LED!\"",
    "do_led_store:",
    "  add r1, -3",
    "  sw  r2, 0(r1)   ; save IP",
    "  pop r0          ; n",
    "  lcu r2, 1",
    "  and r0, r2      ; low bit",
    "  la  r2, -65536  ; 0xFF0000",
    "  sb  r0, 0(r2)",
    "  lw  r2, 0(r1)",
    "  add r1, 3",
    "  lw  r0, 0(r2)   ; NEXT",
    "  add r2, 3",
    "  jmp (r0)",
  ], 9.5);
  s.addText("Note the saved IP: even a leaf primitive spills r2 because pop and la need a second register.", { x: 5.9, y: 4.5, w: 3.6, h: 0.6, fontSize: 10.5, italic: true, color: C.accent2, margin: 0, isTextBox: true, objectName: "led note" });
}

// ============================================================
// 10b. forth.s inside SWTOS
// ============================================================
{
  const s = content("The same core inside SWTOS: Forth as a pane", "Implementations");
  // layer diagram, left
  s.addText("One core, two layers", { x: 0.5, y: 1.0, w: 4.3, h: 0.3, fontSize: 12.5, bold: true, color: C.text1, margin: 0, isTextBox: true, objectName: "layer caption" });
  flowBox(s, 0.5, 1.4, 4.3, 0.6, "forth-core.s   dictionary, inner + outer interpreter, every primitive; never touches hardware", C.text1, C.background1, 10);
  arrow(s, 1.35, 2.08, 0.3, 0.3);
  arrow(s, 3.35, 2.08, 0.3, 0.3);
  flowBox(s, 0.5, 2.45, 2.05, 1.15, "forth-uart.s\nUART at 0xFF0100, return stack at 0x0F0000, BYE halts\n= forth.s, tab 1 and the board", C.accent2, C.background1, 9.5);
  flowBox(s, 2.75, 2.45, 2.05, 1.15, "forth-swtos.s (sw-tos)\nI/O via kernel services into its own pane; 8 KB dictionary and 1 KB return stack in the module; BYE or Escape exits the process", C.accent1, C.background1, 9.5);
  codeBox(s, 0.5, 3.8, 4.3, 1.25, ["; the contract, end of forth-core.s", "layer_init  io_emit  io_key  io_bye", "io_branch  io_zbranch  dict_start  layer_latest", "; sw-tos vendors the core with", "scripts/vendor-forth-core.sh --check"], 9.5);
  bullets(s, 5.2, 1.0, 4.3, 4.1, [
    "Live: swtos.softwarewrighter.com/forth/ boots SWTOS's forth profile in the browser. At the shell type bg forth; the REPL opens in its own pane.",
    "Four layer words: MENU lists the 18 vendored examples, n LOAD runs one as if typed, n LIST prints it, RESET forgets everything. Words are case-insensitive.",
    "It is a resident program like any other: its data stack is the process stack (256 cells), and a Forth loop that never yields (example 21, HOG) is preempted by the clock and can be killed from the shell. On the bare kernel that loop needs a reset.",
    "Nothing in the core changed to make this work. The split into forth-core.s plus a layer was done so SWTOS could own I/O, stacks and exit while the Forth stays byte-identical.",
    "Same source commit as tab 1, so the three web tabs and the SWTOS pane run the same Forth; only the host differs.",
  ], 11);
}

// ============================================================
// 11. forth-in-forth
// ============================================================
{
  const s = content("forth-in-forth: Forth extends itself (tab 2)", "Implementations");
  const tiers = [
    ["minimal.fth", "IF THEN ELSE BEGIN UNTIL AGAIN WHILE REPEAT, = 0=, \\ and (, :NONAME"],
    ["lowlevel.fth", "NIP TUCK ROT PICK 2DUP 2SWAP 1+ 1- NEGATE ABS / MOD, CONSTANT VARIABLE, DO ?DO LOOP"],
    ["midlevel.fth", "CR SPACE HEX DECIMAL and the number printer ."],
    ["highlevel.fth", "DEPTH .S ' WORDS VER >NAME SEE SEE-CFA DUMP-ALL"],
  ];
  tiers.forEach((t, i) => {
    const x = 0.5 + i * 2.3;
    flowBox(s, x, 1.0, 2.05, 0.42, t[0], C.accent2, C.background1, 11.5);
    s.addText(t[1], { x, y: 1.5, w: 2.05, h: 0.9, fontSize: 10, color: C.text1, margin: 0, valign: "top", isTextBox: true, objectName: name("tier words") });
    if (i < 3) arrow(s, x + 2.08, 1.07, 0.19, 0.28);
  });
  s.addText("Each tier uses only primitives and the tiers before it. The kernel streams them in over UART at boot, so WORDS shows them as ordinary colon definitions.", { x: 0.5, y: 2.4, w: 9.0, h: 0.4, fontSize: 11, italic: true, color: C.accent2, margin: 0, isTextBox: true, objectName: "tier note" });
  s.addText("Control flow is four lines of Forth", { x: 0.5, y: 2.95, w: 4.4, h: 0.3, fontSize: 12.5, bold: true, color: C.text1, margin: 0, isTextBox: true, objectName: "cf caption" });
  codeBox(s, 0.5, 3.27, 4.4, 1.15, [
    ": IF    ['] 0BRANCH , HERE @ 0 , ; IMMEDIATE",
    ": THEN  HERE @ OVER - SWAP ! ; IMMEDIATE",
    ": BEGIN HERE @ ; IMMEDIATE",
    ": UNTIL ['] 0BRANCH , HERE @ - , ; IMMEDIATE",
  ], 9.5);
  bullets(s, 5.2, 2.95, 4.3, 2.2, [
    "Three new primitives made it possible: ['] (compile a named CFA), EOL! (let a Forth \\ end the line) and SP@ (for DEPTH and .S).",
    "18 words left assembly; 19 new ones appeared. Kernel 2,983 lines to 2,239 at the time, binary 28% smaller.",
    "SEE decompiles any colon word, including IF itself.",
    "Cost: compile-time words run as threaded code. Fibonacci needs ~120 M instructions instead of 40 M; runtime of compiled code is unchanged.",
  ], 11);
}

// ============================================================
// 12. forth-on-forthish
// ============================================================
{
  const s = content("forth-on-forthish: a Forth-shaped substrate (tab 3)", "Implementations");
  table(s, [
    ["Group", "What stays in assembly"],
    ["Threading", "NEXT, DOCOL, EXIT, LIT, BRANCH, 0BRANCH, EXECUTE"],
    ["Memory", "@  !  C@  C!"],
    ["Arithmetic", "+ and NAND (AND, OR, XOR, INVERT, NEGATE, - are derived)"],
    ["Stack pointers", "SP@  SP!  RP@  RP!  (DUP, SWAP, OVER become memory ops)"],
    ["I/O", "KEY  EMIT  LED!  SW?"],
    ["Compile", "HERE LATEST STATE BASE, ,DOCOL (emits the 6-byte CFA template)"],
    ["Hand-off", "QUIT-VECTOR: the CFA of the Forth QUIT once highlevel.fth has loaded"],
  ], 0.5, 1.0, 4.7, [1.2, 3.5], 10, 0.3);
  codeBox(s, 5.5, 1.0, 4.0, 1.55, [
    ": DUP     SP@ @ ;",
    ": DROP    SP@ 3 + SP! ;",
    ": INVERT  DUP NAND ;",
    ": AND     NAND INVERT ;",
    ": -       NEGATE + ;",
    ": :  CREATE ,DOCOL  ...  ] ;",
    ": ;  ['] EXIT ,  ...  0 STATE ! ; IMMEDIATE",
  ], 9.5);
  bullets(s, 5.5, 2.7, 4.0, 2.4, [
    "Even : and ; are colon definitions. The only help is ,DOCOL, which copies the COR24 opcode bytes Forth cannot encode itself.",
    "WORD, FIND, NUMBER, INTERPRET and QUIT are Forth. After the last core line installs QUIT-VECTOR, every prompt line runs through Forth code.",
    "Honest number: kernel.s is still 2,659 lines. The asm bootstrap must compile runtime.fth before Forth : exists, so the asm WORD / FIND / NUMBER bodies stay alive. Deleting them needs a precompiled image: that is phase 4.",
    "Cost: Fibonacci needs an 800 M instruction budget; stack ops via SP@ are several times slower than push / pop.",
  ], 10.5);
}

// ============================================================
// 12b. forth-from-forth: work in progress
// ============================================================
{
  const s = content("forth-from-forth: the kernel as a build artifact (WIP)", "Implementations");
  // pipeline
  const y = 1.05, h = 0.62;
  flowBox(s, 0.5, y, 1.9, h, "xcomp.fth + prims.fth\n(the compiler, in Forth)", C.accent1, C.background1, 9.5);
  arrow(s, 2.45, y + 0.16, 0.25, 0.3);
  flowBox(s, 2.75, y, 1.75, h, "core/*.fth\nread as source", C.accent2, C.background1, 9.5);
  arrow(s, 4.55, y + 0.16, 0.25, 0.3);
  flowBox(s, 4.85, y, 1.9, h, "runs on the phase-3 REPL,\nasm text out the UART", C.accent2, C.background1, 9.5);
  arrow(s, 6.8, y + 0.16, 0.25, 0.3);
  flowBox(s, 7.1, y, 2.4, h, "kernel.s → cor24-asm → image boot,\nno UART bootstrap", C.text1, C.background1, 9.5);
  codeBox(s, 0.5, 1.85, 4.4, 1.5, [
    "XC-COMPILE-TEST : FOO SP@ @ ;", "fff_e_1:", ".word 0", ".byte 3", ".byte 70   ; F O O ...", "fff_c_1:", ".word do_docol_far   ; far CFA prelude", ".word do_sp_fetch  .word do_fetch  .word do_exit",
  ], 9);
  s.addText("Status on 2026-10-23", { x: 5.2, y: 1.85, w: 4.3, h: 0.3, fontSize: 12.5, bold: true, color: C.text1, margin: 0, isTextBox: true, objectName: "fff status caption" });
  bullets(s, 5.2, 2.17, 4.3, 3.0, [
    "Works: the compiler emits the whole runtime.fth tier (DUP through :, ;) and a self-test image runs that dictionary.",
    "Was stuck since April: compiling a definition from source died right after the begin marker. Found today: the phase-3 Forth NUMBER read its sign byte from the wrong cell, so every -1 in the compiler became a ? and a missing stack item. With that fixed, : FOO SP@ @ ; compiles from source (left).",
    "Not yet: the other four tiers, the primitive declarations, an _start that boots from the image, deleting the asm bootstrap. kernel.s is still a copy of forth-on-forthish.",
    "Tracked as saga phase-4-tab-4: eight steps ending in a fourth web tab, a blog brief and this deck updated.",
  ], 10);
  s.addText("Why bother: no hand-written assembly left; retargeting to another CPU means a new asm-emit module, not a new kernel. The April blog posts (Rabbit-hole parts 2 to 5) planned this: FIND's hash goes away, forward references become linker-style fixups.", { x: 0.5, y: 3.5, w: 4.4, h: 1.6, fontSize: 10.5, italic: true, color: C.accent2, margin: 0, isTextBox: true, objectName: "fff why" });
}

// ============================================================
// 13. Boot flow
// ============================================================
{
  const s = content("Boot: one kernel binary, then a stream of text", "Implementations");
  const y = 1.15, h = 0.7;
  flowBox(s, 0.5, y, 1.55, h, "cor24-asm\nkernel.s → .lgo", C.text1, C.background1, 10.5);
  arrow(s, 2.1, y + 0.2);
  flowBox(s, 2.45, y, 1.55, h, "CPU resets,\n_start → QUIT", C.accent2, C.background1, 10.5);
  arrow(s, 4.05, y + 0.2);
  flowBox(s, 4.4, y, 1.75, h, "core/*.fth tiers\narrive over UART", C.accent2, C.background1, 10.5);
  arrow(s, 6.2, y + 0.2);
  flowBox(s, 6.55, y, 1.3, h, "“ok” prompt", C.accent1, C.background1, 11);
  arrow(s, 7.9, y + 0.2);
  flowBox(s, 8.25, y, 1.25, h, "demo, upload\nor typed line", C.accent6, C.background1, 10.5);
  s.addText("Tab 1 sends no core files and is interactive at once. Tab 2 streams four tiers, tab 3 five. The same bytes work on the CLI:", { x: 0.5, y: 2.05, w: 9.0, h: 0.35, fontSize: 11.5, color: C.text1, margin: 0, isTextBox: true, objectName: "boot note" });
  codeBox(s, 0.5, 2.42, 9.0, 0.75, [
    "cor24-asm forth-on-forthish/kernel.s -o kernel.lgo",
    "cor24-emu --lgo kernel.lgo --speed 0 -n 800000000 \\",
    "  -u \"$(cat forth-on-forthish/core/*.fth examples/14-fib.fth)\"",
  ], 10.5);
  bullets(s, 0.5, 3.35, 4.4, 1.8, [
    "In the browser a pump hands bytes to the UART only while the PC sits in one of the kernel's known poll loops, in sub-batches of 2 k instructions, then lets compile work run in 50 k batches.",
    "Those poll-loop labels are the one thing a new kernel must register; a headless test boots all three kernels through the pump to catch a missing one.",
  ], 10.5);
  table(s, [
    ["Fibonacci demo", "Instructions", "Why"],
    ["forth.s", "~40 M", "everything native"],
    ["forth-in-forth", "~120 M", "IF / UNTIL compile as threaded code"],
    ["forth-on-forthish", "~800 M budget", "WORD / FIND / NUMBER and stack ops in Forth"],
  ], 5.2, 3.35, 4.3, [1.5, 1.1, 1.7], 10, 0.3);
}

// ============================================================
// 14. Trade-offs
// ============================================================
{
  const s = content("Trade-offs between the three", "Implementations");
  table(s, [
    ["", "forth.s", "forth-in-forth", "forth-on-forthish"],
    ["Speed", "fastest; compile and run native", "runtime same; compile ~3× slower", "everything through Forth; ~20× the budget"],
    ["Assembly to maintain", "~3,500 lines, every word", "~2,700 lines, 50 primitives", "~2,650 lines, but only ~22 matter after boot"],
    ["What SEE can show", "no SEE", "IF, ., WORDS as Forth", "also :, WORD, FIND, INTERPRET"],
    ["Retarget to a new CPU", "rewrite everything", "rewrite 50 primitives + bootstrap", "rewrite ~22 primitives + bootstrap; outer interpreter is portable Forth"],
    ["Extra vocabulary", "FORGET, :NONAME", "SEE, DUMP-ALL, PICK, ROT", "NAND, SP!, RP@, RP!, WORD-BUFFER"],
    ["Bootstrap risk", "none", "tier order matters", "chicken-and-egg: asm loop must compile Forth : first"],
    ["Best for", "the board, debugging, golden tests", "learning how Forth defines itself", "porting; seeing the whole interpreter as Forth"],
  ], 0.5, 1.0, 9.0, [1.7, 2.3, 2.4, 2.6], 10, 0.42);
}

// ============================================================
// 15. Section: demos
// ============================================================
pres.addSection({ title: "Demos" });
section("The demos", "The dropdown in every tab, backed by sw-cor24-forth/examples/*.fth", "Demos");

// ============================================================
// 16. Language demos
// ============================================================
{
  const s = content("Language demos: what each one teaches", "Demos");
  table(s, [
    ["Demo", "File", "Teaches", "Tabs"],
    ["Smoke Test", "00", ".S, arithmetic, HEX, WORDS: interpret mode only", "1 2 3"],
    ["Colon Definitions", "01", "TWO, SQUARE, CUBE: compile mode and nesting", "1 2 3"],
    ["Math Words", "03", "NEGATE, DOUBLE, TRIPLE, *", "1 2 3"],
    ["ASCII Stars", "04", "EMIT patterns from composed words", "1 2 3"],
    ["Comments", "06", "\\ line comments and ( ) inline comments", "1 2 3"],
    ["Division & Modulo", "07", "/MOD, then / and MOD built from it", "1 2 3"],
    ["IF THEN  /  IF ELSE", "08 09", "conditional execution inside a definition", "1 2 3"],
    ["Loop", "10", "BEGIN UNTIL counting up and down", "1 2 3"],
    ["FizzBuzz", "11", "nested IF ELSE inside BEGIN UNTIL, 1 to 20", "1 2 3"],
    ["Fibonacci (manual / looped)", "14", "defines its own NIP TUCK 1+ 1-; FIB(0)..FIB(10) or ..FIB(20)", "1 2 3"],
    ["AGAIN  /  WHILE REPEAT", "15 16", "BEGIN AGAIN with IF EXIT; test-in-middle TRIANGLE sum", "2 3"],
    ["CONSTANT  /  VARIABLE", "17 18", "named values; a COUNTER cell with BUMP / RESET / SHOW", "2 3"],
    ["DO LOOP", "19", "DO ?DO I UNLOOP, factorial, early EXIT", "2 3"],
    ["SEE (all words)", "inline", "defines SQUARE and CUBE, then DUMP-ALL decompiles every word", "2 3"],
    ["Self Test", "12", "every kernel word; stack empty at the end; intentional ? ? errors", "1 2 3"],
  ], 0.5, 0.98, 9.0, [2.1, 0.7, 5.4, 0.8], 9, 0.235);
  s.addText("Also in examples/, upload as .fth: 20-redefine (shadowing, FORGET), 21-hog (never yields), 22-factorial (recursion), 23-bases.", { x: 0.5, y: 4.95, w: 9.0, h: 0.25, fontSize: 10, italic: true, color: C.accent2, margin: 0, isTextBox: true, objectName: "extra examples" });
}

// ============================================================
// 17. Hardware demos
// ============================================================
{
  const s = content("Hardware demos: S2 in, D2 out", "Demos");
  // the panel: switch + LED picture
  s.addShape(RR, { x: 0.5, y: 1.0, w: 2.6, h: 2.3, fill: { color: C.text1 }, line: { color: C.text1, width: 0 }, rectRadius: 0.1, objectName: "board panel" });
  s.addShape(RR, { x: 0.8, y: 1.3, w: 0.9, h: 0.5, fill: { color: C.accent5 }, line: { color: C.background1, width: 1 }, rectRadius: 0.06, objectName: "switch S2" });
  s.addText("S2", { x: 0.8, y: 1.3, w: 0.9, h: 0.5, fontSize: 12, bold: true, color: C.text1, align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: "switch label" });
  s.addShape(EL, { x: 2.1, y: 1.3, w: 0.5, h: 0.5, fill: { color: C.accent3 }, line: { color: C.accent3, width: 0 }, objectName: "LED D2" });
  s.addText("D2", { x: 2.0, y: 1.85, w: 0.7, h: 0.3, fontSize: 11, bold: true, color: C.background1, align: "center", margin: 0, isTextBox: true, objectName: "led label" });
  s.addText("0xFF0000 bit 0\nread: 0 = pressed\nwrite: 0 = LED on", { x: 0.7, y: 2.25, w: 2.2, h: 0.95, fontFace: MONO, fontSize: 10, color: C.background1, margin: 0, isTextBox: true, objectName: "panel text" });
  card(s, 3.4, 1.0, 2.95, 2.3, "1", "LED Control (02)", ": ON  1 LED! ;   : OFF 0 LED! ;\nThen ON, OFF, BLINK. Watch the red dot. Because the pin is active-low, 0 LED! is the one that lights it.", C.accent3, 10.5);
  card(s, 6.55, 1.0, 2.95, 2.3, "2", "Switch → LED (05)", "SW? LED!  one shot: click S2 first, then Run. The raw bit is copied straight through, so pressed (0) lights D2.", C.accent1, 10.5);
  card(s, 0.5, 3.45, 4.4, 1.65, "3", "Loop Switch LED (13)", "MIRROR polls SW? LED! 16,000 times with two delay loops between reads. Toggle S2 while it runs and D2 follows within a tick.", C.accent2, 10.5);
  s.addText("The regression, and the tests that now guard it", { x: 5.1, y: 3.45, w: 4.4, h: 0.3, fontSize: 12, bold: true, color: C.text1, margin: 0, isTextBox: true, objectName: "regression caption" });
  bullets(s, 5.1, 3.78, 4.4, 1.4, [
    "April 2026: the delay loops leaked two cells per turn; the 3 KB stack overflowed after ~500 turns and the halted CPU looked like a dead LED.",
    "Web: tests/led_switch_demo.rs boots each kernel headlessly, presses S2 mid-run and asserts D2 follows and the stack does not drift.",
    "CLI: cor24-emu --switch-at 6000000:on,8000000:off logs [S2 @ N] and [LED @ N] lines for reg-rs golden tests.",
  ], 10);
}

// ============================================================
// 18. Working with words
// ============================================================
pres.addSection({ title: "Working with words" });
{
  const s = content("Define, run, list, redefine", "Working with words");
  const w = 4.4, h = 2.0;
  // Define
  s.addShape(RR, { x: 0.5, y: 1.0, w, h, fill: { color: C.background2 }, line: { color: C.background2, width: 0 }, rectRadius: 0.1, objectName: "define card" });
  s.addText("Define", { x: 0.66, y: 1.08, w: 2, h: 0.32, fontSize: 14, bold: true, color: C.accent2, margin: 0, isTextBox: true, objectName: "define head" });
  codeBox(s, 0.66, 1.42, 4.08, 0.72, [": SQUARE ( n -- n*n )  DUP * ;", "  ok"], 10.5);
  s.addText("Colon opens a definition, semicolon closes it. A word can call itself by name (recursion). Definitions live until Reset.", { x: 0.66, y: 2.2, w: 4.08, h: 0.72, fontSize: 10.5, color: C.text1, margin: 0, isTextBox: true, objectName: "define body" });
  // Run
  s.addShape(RR, { x: 5.1, y: 1.0, w, h, fill: { color: C.background2 }, line: { color: C.background2, width: 0 }, rectRadius: 0.1, objectName: "run card" });
  s.addText("Run", { x: 5.26, y: 1.08, w: 2, h: 0.32, fontSize: 14, bold: true, color: C.accent1, margin: 0, isTextBox: true, objectName: "run head" });
  codeBox(s, 5.26, 1.42, 4.08, 0.72, ["5 SQUARE .", "25  ok"], 10.5);
  s.addText("Type the word and press Enter; ↑ ↓ recall history. Demos: pick one, click Run. Your own file: Upload .fth. Stop pauses; Reset reboots and forgets everything.", { x: 5.26, y: 2.2, w: 4.08, h: 0.72, fontSize: 10.5, color: C.text1, margin: 0, isTextBox: true, objectName: "run body" });
  // List
  s.addShape(RR, { x: 0.5, y: 3.15, w, h, fill: { color: C.background2 }, line: { color: C.background2, width: 0 }, rectRadius: 0.1, objectName: "list card" });
  s.addText("List and inspect", { x: 0.66, y: 3.23, w: 3, h: 0.32, fontSize: 14, bold: true, color: C.accent6, margin: 0, isTextBox: true, objectName: "list head" });
  codeBox(s, 0.66, 3.57, 4.08, 0.95, ["WORDS          \\ newest first", "SEE SQUARE     \\ tabs 2 and 3: DUP * ;", "DUMP-ALL       \\ every word with address", "1 2 .S  DEPTH ."], 10);
  s.addText("WORDS on every tab; SEE, SEE-CFA, DUMP-ALL and ' need the Forth-defined kernels.", { x: 0.66, y: 4.56, w: 4.08, h: 0.5, fontSize: 10.5, color: C.text1, margin: 0, isTextBox: true, objectName: "list body" });
  // Redefine
  s.addShape(RR, { x: 5.1, y: 3.15, w, h, fill: { color: C.background2 }, line: { color: C.background2, width: 0 }, rectRadius: 0.1, objectName: "redefine card" });
  s.addText("Redefine, edit, forget", { x: 5.26, y: 3.23, w: 3.5, h: 0.32, fontSize: 14, bold: true, color: C.accent3, margin: 0, isTextBox: true, objectName: "redefine head" });
  codeBox(s, 5.26, 3.57, 4.08, 1.0, [": GREET  72 EMIT 105 EMIT ;", ": TWICE  GREET GREET ;", ": GREET  72 EMIT 101 EMIT 121 EMIT ; \\ shadows", "TWICE          \\ old GREET, twice", "FORGET GREET   \\ forth.s only"], 9.5);
  s.addText("A new definition sits in front of the old one; earlier callers keep the binding they compiled. To edit: fix the source, then FORGET (forth.s) or Reset and re-run the file.", { x: 5.26, y: 4.62, w: 4.08, h: 0.5, fontSize: 10, color: C.text1, margin: 0, isTextBox: true, objectName: "redefine body" });
}

// ============================================================
// 19. Known quirks
// ============================================================
{
  const s = content("Known quirks and open items", "Working with words");
  const rows = [
    ["!", "Fixed today: forth-on-forthish rejected negative literals", "Its Forth NUMBER read the minus sign from the wrong stack cell, so -1 printed ? and left the stack short. Fixed 2026-10-23 in core/highlevel.fth; the tab 3 demos it broke (CONSTANT, DO LOOP, IF THEN, IF ELSE, Self Test) return with the next web build.", C.accent6],
    ["0", "LED! and SW? are raw active-low bits", "0 LED! lights D2 and SW? returns 0 while pressed. The Help text still says non-zero on and -1 pressed; one of the two should change.", C.accent1],
    ["F", "FORGET exists only on forth.s", "Tabs 2 and 3 redefine by shadowing; reclaiming dictionary space means Reset.", C.accent2],
    ["T", "Test loose ends", "The 83-test reg-rs suite passes, but the 600 M-instruction stack-leak test can time out under --parallel and passes alone. The web help doc test lists 12 kernel words with no reference entry.", C.accent4],
  ];
  rows.forEach((r, i) => {
    const y = 1.0 + i * 1.02;
    s.addShape(EL, { x: 0.5, y: y + 0.1, w: 0.46, h: 0.46, fill: { color: r[3] }, line: { color: r[3], width: 0 }, objectName: name("quirk icon") });
    s.addText(r[0], { x: 0.5, y: y + 0.1, w: 0.46, h: 0.46, fontSize: 14, bold: true, color: C.background1, align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: name("quirk glyph") });
    s.addText(r[1], { x: 1.2, y, w: 8.3, h: 0.32, fontSize: 14, bold: true, color: C.text1, margin: 0, isTextBox: true, objectName: name("quirk head") });
    s.addText(r[2], { x: 1.2, y: y + 0.33, w: 8.3, h: 0.62, fontSize: 11, color: C.text1, margin: 0, isTextBox: true, objectName: name("quirk body") });
  });
}

// ============================================================
// 20. Closing / resources
// ============================================================
{
  const s = pres.addSlide({ masterName: "DARK_TITLE", sectionTitle: "Working with words" });
  s.addText("Try it", { placeholder: "title" });
  s.addText("sw-embed.github.io/web-sw-cor24-forth (three kernels, press ? for the guide)  ·  swtos.softwarewrighter.com/forth/ (forth.s as an SWTOS pane: bg forth)", { placeholder: "body" });
  s.addText("Repositories, all under github.com/sw-embed", { x: 0.6, y: 3.75, w: 8.8, h: 0.3, fontSize: 11, bold: true, color: C.accent5, margin: 0, isTextBox: true, objectName: "repos caption" });
  const links = [
    ["Web UI", "web-sw-cor24-forth"],
    ["Kernels and demos", "sw-cor24-forth"],
    ["Emulator and CLI", "sw-cor24-emulator"],
    ["Assembler", "sw-cor24-x-assembler"],
    ["SWTOS and its web demo", "sw-tos, web-sw-tos"],
    ["Board", "makerlisp.com"],
  ];
  links.forEach((l, i) => {
    const col = i % 2, row = Math.floor(i / 2);
    const x = 0.6 + col * 4.5, y = 4.1 + row * 0.36;
    s.addText(l[0], { x, y, w: 1.95, h: 0.32, fontSize: 11, bold: true, color: C.accent1, margin: 0, valign: "middle", isTextBox: true, objectName: name("link label") });
    s.addText(l[1], { x: x + 2.0, y, w: 2.45, h: 0.32, fontSize: 11, fontFace: MONO, color: C.background1, margin: 0, valign: "middle", isTextBox: true, objectName: name("link url") });
  });
}

(async () => {
  const out = "forth-on-cor24.pptx";
  await pres.writeFile({ fileName: out });
  await applyTheme(out, THEME);
  console.log("wrote", out);
})();
