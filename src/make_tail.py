"""Encode the last DROP bytes of the original image as (addr, len, data) segments.

usage: make_tail.py [SLES_009.70] [tail.bin]"""
import struct, sys

DROP = 0x1800          # = block size (src/build_patch.py BLOCK)


def make_tail(exe_path='SLES_009.70', out_path='tail.bin'):
    d = open(exe_path, 'rb').read()[0x800:0x800 + 0x9F800]
    tail = d[len(d) - DROP:]
    base = 0x80010000 + len(d) - DROP
    out = b''
    i = 0
    n = len(tail)
    while i < n:
        if tail[i]:
            j = i; last = i
            while j < n and (tail[j] or j - last < 32):
                if tail[j]:
                    last = j
                j += 1
            s = i & ~3; e = (last + 4) & ~3
            out += struct.pack('<II', base + s, e - s) + tail[s:e]
            i = e
        else:
            i += 1
    out += struct.pack('<II', 0, 0)
    open(out_path, 'wb').write(out)
    print('tail.bin', len(out))


if __name__ == '__main__':
    make_tail(*sys.argv[1:3])
