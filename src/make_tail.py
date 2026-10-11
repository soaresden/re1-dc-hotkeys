"""Encode the last DROP bytes of the original image as (addr, len, data) segments.

usage: make_tail.py [exe] [tail.bin]"""
import struct, sys

DROP = 0x1800          # = block size (src/build_patch.py BLOCK)
GAP = 8                # zero runs shorter than this stay inside a segment (8 = segment header)


def make_tail(exe_path='SLES_009.70', out_path='tail.bin'):
    exe = open(exe_path, 'rb').read()
    t_size = struct.unpack_from('<I', exe, 0x1C)[0]
    d = exe[0x800:0x800 + t_size]
    tail = d[len(d) - DROP:]
    base = 0x80010000 + len(d) - DROP
    out = b''
    i = 0
    n = len(tail)
    while i < n:
        if tail[i]:
            j = i; last = i
            while j < n and (tail[j] or j - last < GAP):
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
