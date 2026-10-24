#!/usr/bin/env bash
# compare-see.sh SOURCE.fth — compile core/runtime.fth + SOURCE with the
# cross-compiler and with the phase-3 kernel, then compare every definition in SEE form (names,
# LIT n, BRANCH/0BRANCH offsets). Prints one line per definition and exits
# non-zero on any mismatch. Both runs go in parallel.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
FFF="$ROOT/forth-from-forth"
SRC="$1"
WORK="$(mktemp -d -t compare-see)"; trap 'rm -rf "$WORK"' EXIT
cat "$FFF/core/runtime.fth" "$SRC" > "$WORK/src.fth"
cd "$ROOT"
NAMES=$(grep -oE '^: +[^ ]+' "$SRC" | awk '{print $2}')
SEE_LINES=$(for n in $NAMES; do echo "SEE $n"; done)
( XC_SOURCE="$WORK/src.fth" XC_OUT="$WORK/xc.s" "$FFF/scripts/build-kernel.sh" >/dev/null 2>&1 ) &
( INPUT="$(cat $FFF/core/runtime.fth $FFF/core/minimal.fth $FFF/core/lowlevel.fth $FFF/core/midlevel.fth $FFF/core/highlevel.fth "$SRC")
65 EMIT
$SEE_LINES
66 EMIT
"
  scripts/run-kernel.sh forth-on-forthish/kernel.s -u "$INPUT" --speed 0 -n 3000000000 2>&1 \
    | sed -n '/^UART output:/,$p' | sed -n '/^A/,/^B/p' | sed '1d;$d' | grep -v '^ ok$' > "$WORK/see.txt" ) &
wait
python3 - "$WORK/xc.s" "$WORK/see.txt" "$FFF/core/prims.fth" $NAMES <<'PY'
import re,sys
xc,see,prims,names=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4:]
lab={'do_lit':'LIT','do_branch':'BRANCH','do_zbranch':'0BRANCH'}
for l in open(prims):
    m=re.match(r'PRIM:\s+(\S+)\s+(\S+)',l)
    if m: lab[m.group(2)]=m.group(1)
def demangle(x): return re.sub(r'_(\d+)',lambda m:chr(int(m.group(1))),x)
defs={};cur=None;body=None
for l in open(xc).read().split('\n'):
    m=re.match(r'fff_c\d+_(\S+):$',l)
    if m: cur=demangle(m.group(1)); body=defs.setdefault(cur,[]); continue
    if re.match(r'fff_e\d+_',l): cur=None; continue
    if cur is None: continue
    m=re.match(r'\.word (\S+)$',l)
    if m:
        w=m.group(1)
        if re.match(r'-?\d+$',w): body.append(w)
        elif w=='do_docol_far': pass
        else:
            mm=re.match(r'fff_c\d+_(\S+)$',w)
            body.append(demangle(mm.group(1)) if mm else lab.get(w,w))
    elif l.startswith('; ?'): body.append('?'+l[4:])
seel=[l.strip() for l in open(see) if l.strip()]
bad=0
for i,n in enumerate(names):
    toks=defs.get(n) or ['<missing>']
    # SEE stops at the first EXIT and prints it as ;
    if 'EXIT' in toks: toks=toks[:toks.index('EXIT')]+[';']
    got=' '.join(toks)
    want=seel[i] if i<len(seel) else '<no SEE line>'
    ok=got==want; bad+=not ok
    print(('ok   ' if ok else 'DIFF ')+n+': '+got+('' if ok else '\n     phase-3: '+want))
sys.exit(1 if bad else 0)
PY
