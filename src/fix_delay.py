"""R3000 load delay slot: the instruction right after a load still sees the
old register value. Insert a nop after a load when the next instruction
names the loaded register (or is not a plain instruction: directive, end).
A load in a branch delay slot is refused (the branch target would follow it).
Statements joined with ';' (cpp macro expansions) are split first.
usage: fix_delay.py in.s out.s"""
import re, sys

LOAD = re.compile(r'^\s*(?:\w+:)?\s*(lw|lh|lhu|lb|lbu)\s+\$(\w+),')
BRANCH = re.compile(r'^\s*(?:\w+:)?\s*(b\w*|j|jal|jr|jalr)\s')
LABEL_ONLY = re.compile(r'^\s*\w+:\s*$')
NOP = '        nop                                /* load delay */'

stmts = []
for line in open(sys.argv[1]).read().splitlines():
    stmts.extend(s for s in line.split(';'))


def code(s):
    s = s.strip()
    return bool(s) and not LABEL_ONLY.match(s) and not s.startswith('.') and not s.startswith('#')


out = []
prev_branch = False
for i, s in enumerate(stmts):
    out.append(s)
    if not code(s):
        continue
    m = LOAD.match(s)
    if m:
        if prev_branch:
            sys.exit('load in a branch delay slot: ' + s.strip())
        reg = m.group(2)
        # next statement, skipping labels and the assembly-time checks (SAMEHI)
        nxt = next((t for t in stmts[i + 1:] if t.strip() and not LABEL_ONLY.match(t.strip())
                    and not re.match(r'\s*\.(if|error|endif|else)\b', t)), '')
        if not code(nxt) or re.search(r'\$' + reg + r'\b', nxt):
            out.append(NOP)
    prev_branch = bool(BRANCH.match(s))
open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
