"""Find the addresses of the FR executable in another version of the game.

usage: python tools/re/port.py <SLES_009.70> <other exe> [addr ...]

1. every function of the FR image (jal targets) is searched in the other
   image by signature: instructions with absolute addresses masked (jal
   targets, lui immediates, offsets of loads/stores/addiu not based on sp);
2. matched function pairs are aligned instruction by instruction: each
   lui + offset pair gives a FR data address -> other data address vote;
3. code addresses inside matched functions map by their offset.
Prints the mapping of the requested addresses (default: the ones of src/game.h
and the hard-coded ones of the .S files)."""
import collections, re, struct, sys

BASE = 0x80010000


def load(path):
    d = open(path, 'rb').read()
    ta, ts = struct.unpack_from('<II', d, 0x18)
    img = d[0x800:0x800 + ts]
    return ta, list(struct.unpack('<%dI' % (len(img) // 4), img))


def mask(w):
    op = w >> 26
    rs = (w >> 21) & 31
    if op in (2, 3):
        return op << 26
    if op == 0x0F:                                   # lui
        return w & 0xFFFF0000
    if op in (0x09, 0x0D) or 0x20 <= op <= 0x2E:     # addiu, ori, loads, stores
        if rs != 29:
            return w & 0xFFFF0000
    return w


def functions(words, base):
    t = set()
    for w in words:
        if w >> 26 == 3:
            a = ((w & 0x3FFFFFF) << 2) | 0x80000000
            if base <= a < base + 4 * len(words):
                t.add(a)
    return sorted(t)


def resolve_refs(words, i0, n, base):
    """[(index, address)] of lui + offset references in words[i0:i0+n]"""
    lui = {}
    out = []
    for k in range(i0, i0 + n):
        w = words[k]
        op, rs, rt, imm = w >> 26, (w >> 21) & 31, (w >> 16) & 31, w & 0xFFFF
        simm = imm - 0x10000 if imm & 0x8000 else imm
        if op == 0x0F:
            lui[rt] = imm << 16
            continue
        if op in (0x09, 0x0D) or 0x20 <= op <= 0x2E:
            if rs in lui:
                a = (lui[rs] | imm) if op == 0x0D else (lui[rs] + simm) & 0xFFFFFFFF
                out.append((k - i0, a))
            if op in (0x09, 0x0D) and rt != rs or 0x20 <= op <= 0x26:
                lui.pop(rt, None)
        elif op == 0 and (w >> 11) & 31:
            lui.pop((w >> 11) & 31, None)
    return out


def main():
    fr_base, fr = load(sys.argv[1])
    tg_base, tg = load(sys.argv[2])
    want = [int(a, 16) for a in sys.argv[3:]]
    fr_funcs = functions(fr, fr_base)
    mt = [mask(w) for w in tg]
    index = collections.defaultdict(list)
    K = 6
    for i in range(len(mt) - K):
        index[tuple(mt[i:i + K])].append(i)
    code_map = {}                                    # FR function -> target function
    pairs = []
    for j, f in enumerate(fr_funcs):
        i0 = (f - fr_base) // 4
        end = (fr_funcs[j + 1] - fr_base) // 4 if j + 1 < len(fr_funcs) else len(fr)
        full = min(end - i0, 400)
        if full < K:
            continue
        # shortest window that matches exactly once, then as long as it still matches
        for n in sorted(set([min(24, full), min(48, full), min(96, full), full])):
            sig = [mask(w) for w in fr[i0:i0 + n]]
            cands = [c for c in index.get(tuple(sig[:K]), []) if mt[c:c + n] == sig]
            if len(cands) <= 1:
                break
        if len(cands) == 1:
            c = cands[0]
            while n < full and mask(fr[i0 + n]) == mt[c + n]:
                n += 1
            code_map[f] = (c * 4 + tg_base, n)
            pairs.append((i0, c, n))
    votes = collections.defaultdict(collections.Counter)
    for i0, c0, n in pairs:
        a = resolve_refs(fr, i0, n, fr_base)
        b = dict(resolve_refs(tg, c0, n, tg_base))
        for k, addr in a:
            if k in b:
                votes[addr][b[k]] += 1
    print('functions: %d FR, %d matched uniquely' % (len(fr_funcs), len(code_map)), file=sys.stderr)

    def local(a):
        """code address: unique match of a window of instructions around it"""
        i = (a - fr_base) // 4
        if not 0 <= i < len(fr):
            return None
        for h in (4, 8, 12, 16, 24, 32):
            lo, hi = max(0, i - h), min(len(fr), i + h)
            sig = [mask(w) for w in fr[lo:hi]]
            if len(sig) < K:
                continue
            cands = [c for c in index.get(tuple(sig[:K]), []) if mt[c:c + len(sig)] == sig]
            if len(cands) == 1:
                c = cands[0] + i - lo
                # how far the match extends on each side (confidence)
                b = 0
                while i - b - 1 >= 0 and c - b - 1 >= 0 and mask(fr[i - b - 1]) == mt[c - b - 1]:
                    b += 1
                f = 0
                while i + f < len(fr) and c + f < len(mt) and mask(fr[i + f]) == mt[c + f]:
                    f += 1
                return c * 4 + tg_base, 'code, %d instr. before / %d after match' % (b, f)
            if not cands:
                return None
        return None

    def map_addr(a):
        if a < 0x8009_0000:
            r = local(a)
            if r:
                return r
        if a in votes:
            v, c = votes[a].most_common(1)[0]
            tot = sum(votes[a].values())
            return v, 'data %d/%d' % (c, tot)
        # inside a matched function?
        for f, (t, n) in code_map.items():
            if f <= a < f + 4 * n:
                return t + (a - f), 'code +0x%x in 0x%08x' % (a - f, f)
        # nearest data neighbour with a consistent delta
        near = sorted(votes, key=lambda x: abs(x - a))[:6]
        deltas = collections.Counter(votes[x].most_common(1)[0][0] - x for x in near)
        d, c = deltas.most_common(1)[0]
        return a + d, 'guess (delta of %d/6 neighbours: %s)' % (c, ', '.join('0x%08x' % x for x in near[:3]))

    for a in want:
        v, how = map_addr(a)
        print('0x%08x -> 0x%08x  %s' % (a, v, how))


if __name__ == '__main__':
    main()
