#!/usr/bin/env bash
# build-image.sh — generate forth-from-forth/kernel.s: a kernel that boots
# straight into the Forth QUIT with the whole core already in its
# dictionary, so nothing is streamed over the UART at boot.
#
#   scripts/build-image.sh            regenerate kernel.s
#   scripts/build-image.sh --check    fail if kernel.s is stale
#
# Inputs: the five core tiers (cross-compiled by build-kernel.sh, minus the
# QUIT-VECTOR hand-off at the end of highlevel.fth) and an assembly template
# for the primitives, ../forth-on-forthish/kernel.s. The template is never
# this script's own output. Four changes are made to it:
#   1. the compiled dictionary goes in just before test_thread/dict_end,
#      so HERE (= dict_end) starts after it;
#   2. the first compiled entry links to entry_quit_vector, the newest
#      assembly entry;
#   3. _start sets LATEST to the newest compiled entry (via fff_latest),
#      so the FIND hash table it builds covers the whole dictionary;
#   4. the start-up thread stores the Forth QUIT in QUIT-VECTOR and runs it,
#      instead of running the assembly bootstrap loop do_quit;
#   5. assembly entries the compiled core redefines are unlinked;
#   6. the underflow handler loses its fallback to the bootstrap QUIT;
#   7. blocks nothing can reach are dropped (scripts/dead-code.py).
set -euo pipefail
set -f
HERE="$(cd "$(dirname "$0")" && pwd)"
FFF="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$FFF/.." && pwd)"
TEMPLATE="$ROOT/forth-on-forthish/kernel.s"
OUT="$FFF/kernel.s"
WORK="$(mktemp -d -t build-image)"; trap 'rm -rf "$WORK"' EXIT

cat "$FFF"/core/{runtime,minimal,lowlevel,midlevel,highlevel}.fth \
  | grep -v -x -e "' QUIT QUIT-VECTOR !" -e "QUIT" > "$WORK/core.fth"
XC_SOURCE="$WORK/core.fth" XC_OUT="$WORK/dict.s" "$HERE/build-kernel.sh" >/dev/null 2>&1
if grep -q '^; ?' "$WORK/dict.s"; then
  echo "build-image: unresolved tokens:" >&2; grep '^; ?' "$WORK/dict.s" >&2; exit 1
fi

python3 - "$TEMPLATE" "$WORK/dict.s" "$WORK/kernel.s" <<'PY'
import re,sys
tpl,dictf,out=sys.argv[1:4]
t=open(tpl).read(); d=open(dictf).read().rstrip('\n').split('\n')
entries=[l[:-1] for l in d if re.match(r'fff_e\d+_\S+:$',l)]
quits=[l[:-1] for l in d if re.match(r'fff_c\d+_QUIT:$',l)]
if not entries or not quits: sys.exit('build-image: no entries or no QUIT in the dictionary')
# 2. first entry links to the newest assembly entry
first=d.index(entries[0]+':')
assert d[first+1]=='.word 0', d[first+1]
d[first+1]='.word entry_quit_vector'
dict_block='\n'.join(
 ['; ============================================================',
  '; Core dictionary, cross-compiled from core/*.fth by',
  '; compiler/xcomp.fth (scripts/build-image.sh). %d definitions.'%len(entries),
  '; ============================================================']
 + d + ['fff_latest:','    .word '+entries[-1],''])
# 3. LATEST init
a='    la r2, entry_quit_vector  ; LATEST init (newest dict entry)\n'
assert t.count(a)==1
t=t.replace(a,'    la r2, fff_latest         ; LATEST init: newest compiled entry\n    lw r2, 0(r2)\n')
# 1 + 4. dictionary before test_thread; boot thread runs the Forth QUIT
a='test_thread:\n    .word do_quit\n'
assert t.count(a)==1
q=quits[-1]
boot=('test_thread:\n'
      '    ; QUIT-VECTOR = Forth QUIT (the stack-underflow handler restarts\n'
      '    ; through it), then run it. No assembly bootstrap loop.\n'
      '    .word do_lit\n    .word %s\n    .word do_quit_vector\n    .word do_store\n'
      '    .word %s\n'%(q,q))
t=t.replace(a,dict_block+'\n'+boot)
# 5. unlink assembly entries the compiled core redefines: FIND reaches the
#    compiled definition first, so the old entry is dead weight in the chain.
dem = lambda x: re.sub(r'_(\d+)', lambda m: chr(int(m.group(1))), x)
core_names = {dem(n) for n in re.findall(r'^fff_e\d+_(\S+):$', '\n'.join(d), re.M)}
num = lambda x: int(x, 0)
lines = t.split('\n'); entries_asm = {}
for i, l in enumerate(lines):
    m = re.match(r'(entry_\S+):$', l.strip())
    if not m: continue
    link = None; b = []; j = i + 1
    while j < i + 8 and len(b) < 2:
        mm = re.match(r'\s*\.word\s+(\S+)', lines[j])
        if mm and link is None: link = mm.group(1)
        mm = re.match(r'\s*\.byte\s+([^;]*)', lines[j])
        if mm: b.append(mm.group(1))
        j += 1
    try:
        fl = num(b[0].split(',')[0])
        nm = ''.join(chr(num(x)) for x in b[1].split(',')[:fl & 63])
    except Exception:
        continue
    entries_asm[m.group(1)] = (nm, link)
shadowed = {e for e, (nm, _) in entries_asm.items() if nm in core_names}
def target(e):
    while e in shadowed: e = entries_asm[e][1]
    return e
for i, l in enumerate(lines):
    m = re.match(r'(\s*\.word\s+)(entry_\S+)(.*)$', l)
    if m and m.group(2) in shadowed:
        lines[i] = m.group(1) + target(m.group(2)) + m.group(3)
t = '\n'.join(lines)
# 6. the underflow handler's fallback to the asm bootstrap QUIT can never be
#    taken: QUIT-VECTOR is set before any code runs. A zero vector restarts.
a = 'sue_asm_fallback:\n    la r0, do_quit\n    jmp (r0)\n'
assert t.count(a) == 1
t = t.replace(a, 'sue_asm_fallback:            ; QUIT-VECTOR is never 0 in the image;\n'
                 '    jmp (r0)                 ; if it were, r0 = 0 restarts the kernel\n')
sys.stderr.write('build-image: unlinked shadowed entries: %s\n'
                 % ' '.join(sorted(entries_asm[e][0] for e in shadowed)))
head=('; GENERATED by forth-from-forth/scripts/build-image.sh -- do not edit.\n'
      '; Template: forth-on-forthish/kernel.s (primitives); dictionary:\n'
      '; core/*.fth cross-compiled by compiler/xcomp.fth.\n;\n')
open(out,'w').write(head+t)
PY
# 7. drop blocks nothing can reach (scripts/dead-code.py)
python3 "$HERE/dead-code.py" "$WORK/kernel.s" --strip "$WORK/kernel.stripped.s" > "$WORK/dead.txt"
mv "$WORK/kernel.stripped.s" "$WORK/kernel.s"
head -1 "$WORK/dead.txt" | sed 's/^/build-image: /' >&2
if [ "${1:-}" = "--check" ]; then
  if cmp -s "$WORK/kernel.s" "$OUT"; then echo "kernel.s is current"; else echo "kernel.s is stale: run scripts/build-image.sh" >&2; exit 1; fi
else
  cp "$WORK/kernel.s" "$OUT"
  echo "build-image: wrote $OUT ($(wc -l < "$OUT") lines, $(grep -c '^fff_e' "$OUT") compiled definitions)" >&2
fi
