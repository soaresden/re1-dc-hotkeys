"""Code that nothing can reach, in a PS-X EXE (candidate room for the mod).

usage: python tools/re/deadcode.py <exe> [min bytes]

Reachability from every possible reference, conservative (anything that
looks like a pointer into the code counts):
  - pc0, jal / j targets, branch targets, fall-through;
  - every aligned word of the image whose value points into the image
    (function pointer tables, switch tables);
  - every lui + addiu / ori pair that builds an address in the image.
A path ends after jr / j / break (+ its delay slot). The code part of the
image is taken as everything before the first long run of words that do
not decode as plausible instructions. Prints the unreached ranges."""
import struct, sys

BASE = 0x80010000


def main():
    d = open(sys.argv[1], 'rb').read()
    pc0, gp0, ta, ts = struct.unpack_from('<IIII', d, 0x10)
    img = d[0x800:0x800 + ts]
    n = len(img) // 4
    w = struct.unpack('<%dI' % n, img[:n * 4])
    end = ta + 4 * n
    inside = lambda a: ta <= a < end and a % 4 == 0
    refs = {pc0}
    for v in w:                                       # pointers anywhere in the image
        if inside(v):
            refs.add(v)
    lui = {}
    for i, x in enumerate(w):                         # lui + addiu / ori pairs
        op, rs, rt, imm = x >> 26, (x >> 21) & 31, (x >> 16) & 31, x & 0xFFFF
        if op == 0x0F:
            lui[rt] = imm << 16
        elif op in (0x09, 0x0D) and rs in lui:
            a = (lui[rs] | imm) if op == 0x0D else (lui[rs] + (imm - 0x10000 if imm & 0x8000 else imm)) & 0xFFFFFFFF
            if inside(a):
                refs.add(a)
    seen = bytearray(n)
    todo = [ (a - ta) // 4 for a in refs ]
    while todo:
        i = todo.pop()
        while 0 <= i < n and not seen[i]:
            seen[i] = 1
            x = w[i]
            op, rs, rt, funct = x >> 26, (x >> 21) & 31, (x >> 16) & 31, x & 0x3F
            stop = False
            if op in (2, 3):                          # j / jal
                t = ((x & 0x3FFFFFF) << 2) | (ta & 0xF0000000)
                if inside(t):
                    todo.append((t - ta) // 4)
                stop = op == 2
            elif op in (1, 4, 5, 6, 7, 0x14, 0x15, 0x16, 0x17):   # branches
                off = x & 0xFFFF
                off = off - 0x10000 if off & 0x8000 else off
                todo.append(i + 1 + off)
                if op == 4 and rs == 0 and rt == 0:   # b (beq zero, zero)
                    stop = True
            elif op == 0 and funct in (8, 0x0D):      # jr, break
                stop = True
            if stop:
                if i + 1 < n:
                    seen[i + 1] = 1                   # delay slot
                break
            i += 1
    # ranges not reached, inside the code part only
    out = []
    i = 0
    while i < n:
        if not seen[i]:
            j = i
            while j < n and not seen[j]:
                j += 1
            out.append((i, j))
            i = j
        else:
            i += 1
    last_code = max(i for i in range(n) if seen[i])
    mn = int(sys.argv[2]) if len(sys.argv) > 2 else 256
    tot = 0
    for i, j in out:
        if j > last_code:
            break
        size = 4 * (j - i)
        zeros = sum(1 for k in range(i, j) if w[k] == 0)
        if size >= mn and zeros * 4 < size // 2:
            prolog = sum(1 for k in range(i, j) if (w[k] & 0xFFFF0000) == 0x27BD0000 and w[k] & 0x8000)
            print('0x%08x-0x%08x %6d bytes, %d prologues' % (ta + 4 * i, ta + 4 * j, size, prolog))
            tot += size
    print('total', tot, 'bytes; code ends near 0x%08x' % (ta + 4 * last_code))


if __name__ == '__main__':
    main()
