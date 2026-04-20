#!/usr/bin/env python3
"""Offline collision analysis over the known dict words of forth-in-forth.

Extracts word names from:
  - forth-in-forth/kernel.s asm entry_* definitions
  - forth-in-forth/core/*.fth colon definitions (`: NAME ...`)

Evaluates several hash functions at several bucket counts, reports
collision counts and worst-bucket depth.
"""
import pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
KERNEL = ROOT / "forth-in-forth" / "kernel.s"
CORE_DIR = ROOT / "forth-in-forth" / "core"

def extract_asm_words(path):
    """Pull word names from entry_* dict headers.

    Each entry has `.byte <flags_len>` then `.byte <ascii bytes>`.
    We parse the two lines after `entry_<name>:` to get the ASCII bytes.
    """
    names = []
    lines = path.read_text().splitlines()
    i = 0
    while i < len(lines):
        m = re.match(r'^entry_(\w+):', lines[i])
        if m:
            # Find the first .byte line after this (flags_len).
            j = i + 1
            # skip blank/comment lines, and the .word link line
            while j < len(lines) and '.byte' not in lines[j]:
                j += 1
            if j >= len(lines):
                break
            # The .byte after .word link is the flags_len.
            # Find the NEXT .byte line — it's the name chars.
            k = j + 1
            while k < len(lines) and '.byte' not in lines[k]:
                k += 1
            if k < len(lines):
                name_line = lines[k]
                # Extract numeric byte values (before any ; comment).
                body = name_line.split(';', 1)[0]
                nums = re.findall(r'\d+', body.replace('.byte', ''))
                chars = ''.join(chr(int(n)) for n in nums)
                if chars:
                    names.append(chars)
        i += 1
    return names

def extract_fth_words(core_dir):
    """Pull colon-defined names from core/*.fth."""
    names = []
    for f in sorted(core_dir.glob('*.fth')):
        for line in f.read_text().splitlines():
            m = re.match(r'^:\s+(\S+)', line)
            if m:
                names.append(m.group(1))
    return names

# ---- Hash functions ----
def h_first_char(name, buckets):
    return ord(name[0]) % buckets

def h_len_first_last(name, buckets):
    return (len(name) + ord(name[0]) + ord(name[-1])) % buckets

def h_len31_first_last(name, buckets):
    return (len(name) * 31 + ord(name[0]) + ord(name[-1])) % buckets

def h_len31_first7_last(name, buckets):
    return (len(name) * 31 + ord(name[0]) * 7 + ord(name[-1])) % buckets

def h_djb2(name, buckets):
    h = 5381
    for c in name:
        h = ((h << 5) + h + ord(c)) & 0xFFFFFF  # 24-bit wrap
    return h % buckets

def h_mult33(name, buckets):
    h = 0
    for c in name:
        h = (h * 33 + ord(c)) & 0xFFFFFF
    return h % buckets

def h_fnv1a(name, buckets):
    h = 2166136261
    for c in name:
        h ^= ord(c)
        h = (h * 16777619) & 0xFFFFFFFF
    return h % buckets

def h_len_mult33(name, buckets):
    """Include length as seed to distinguish anagrams of different lengths."""
    h = len(name)
    for c in name:
        h = (h * 33 + ord(c)) & 0xFFFFFF
    return h % buckets

HASHES = [
    ('first_char', h_first_char),
    ('len+first+last', h_len_first_last),
    ('len*31+first+last', h_len31_first_last),
    ('len*31+first*7+last', h_len31_first7_last),
    ('djb2', h_djb2),
    ('mult33 (no seed)', h_mult33),
    ('fnv1a', h_fnv1a),
    ('len-seeded mult33', h_len_mult33),
]

def analyze(names, hash_fn, buckets):
    from collections import Counter
    hits = Counter(hash_fn(n, buckets) for n in names)
    total_collisions = sum(c - 1 for c in hits.values() if c > 1)
    worst = max(hits.values()) if hits else 0
    used = len(hits)
    return total_collisions, worst, used

def main():
    asm = extract_asm_words(KERNEL)
    fth = extract_fth_words(CORE_DIR)
    words = asm + fth
    print(f"Dict words: {len(asm)} asm + {len(fth)} Forth = {len(words)} total")
    # Show word list sorted to spot obvious collisions
    print()
    print("Words starting with same letter:")
    from collections import defaultdict
    by_first = defaultdict(list)
    for w in words:
        by_first[w[0]].append(w)
    for c in sorted(by_first):
        if len(by_first[c]) > 1:
            print(f"  {c!r}: {by_first[c]}")
    print()

    for nb in [64, 128, 256]:
        print(f"=== {nb} buckets ===")
        print(f"{'hash':>25}  {'coll':>5}  {'worst':>5}  {'used':>5}  verdict")
        for name, fn in HASHES:
            c, w, u = analyze(words, fn, nb)
            verdict = 'PERFECT' if c == 0 else f'{c} coll (worst bucket has {w})'
            print(f"{name:>25}  {c:>5}  {w:>5}  {u:>5}  {verdict}")
        print()

if __name__ == '__main__':
    main()
