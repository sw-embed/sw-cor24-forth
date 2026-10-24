#!/usr/bin/env python3
"""dead-code.py KERNEL.s [--strip OUT.s]

Reachability over a COR24 assembly file, at label granularity.

A block is a label plus the lines up to the next label. A block is live if
it is a root, if a live block names its label (.word, la, bra/brt/brf,
jal), or if the live block just before it can fall through into it (its
last instruction is not an unconditional jmp or bra). Roots: the first
block (the CPU starts at address 0) and fff_latest, whose .word starts the
dictionary chain; every entry's link .word then reaches the next.

Prints the dead labels. With --strip, writes OUT.s without the dead blocks.
Comment-only and blank lines before the first label are kept.
"""
import re,sys
src=open(sys.argv[1]).read().split('\n')
blocks=[]   # (label or None, [lines])
cur=(None,[])
for l in src:
    m=re.match(r'([A-Za-z_]\w*):\s*(;.*)?$',l)
    if m:
        blocks.append(cur); cur=(m.group(1),[l]); continue
    cur[1].append(l)
blocks.append(cur)
labels=[b[0] for b in blocks]
idx={n:i for i,n in enumerate(labels) if n}
def code(l): return l.split(';',1)[0].strip()
def refs(lines):
    out=set()
    for l in lines[1:] if lines and re.match(r'[A-Za-z_]\w*:',lines[0]) else lines:
        c=code(l)
        if not c: continue
        for tok in re.findall(r'[A-Za-z_]\w*',c.split(None,1)[1] if ' ' in c else ''):
            if tok in idx: out.add(tok)
    return out
def falls(lines):
    body=[code(l) for l in lines[1:] if code(l)] if lines and lines[0] and re.match(r'[A-Za-z_]\w*:',lines[0]) else [code(l) for l in lines if code(l)]
    if not body: return True
    last=body[-1].split()
    return not (last[0] in ('jmp','bra'))
live=set(); work=[]
def mark(i):
    if i not in live: live.add(i); work.append(i)
first=next(i for i,b in enumerate(blocks) if b[0])
mark(first)
if 'fff_latest' in idx: mark(idx['fff_latest'])
while work:
    i=work.pop()
    for r in refs(blocks[i][1]): mark(idx[r])
    if falls(blocks[i][1]) and i+1<len(blocks): mark(i+1)
dead=[b[0] for i,b in enumerate(blocks) if b[0] and i not in live]
lines_dead=sum(len(b[1]) for i,b in enumerate(blocks) if b[0] and i not in live)
print('blocks %d, live %d, dead %d (%d lines)'%(sum(1 for b in blocks if b[0]),len(live),len(dead),lines_dead))
for d in dead: print('  dead', d)
if '--strip' in sys.argv:
    out=sys.argv[sys.argv.index('--strip')+1]
    keep=[]
    for i,b in enumerate(blocks):
        if b[0] is None or i in live: keep+=b[1]
    open(out,'w').write('\n'.join(keep))
