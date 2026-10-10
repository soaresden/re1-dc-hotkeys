"""Create a PPF 3.0 patch (BIN image, no blockcheck, no undo) from two raw images."""
import struct, sys
a = open(sys.argv[1], 'rb').read()
b = open(sys.argv[2], 'rb').read()
assert len(a) == len(b)
desc = sys.argv[4].encode('ascii')[:50].ljust(50, b' ')
out = bytearray(b'PPF30' + bytes([2]) + desc + bytes([0, 0, 0, 0]))
# only the executable sectors can differ; scan them quickly with numpy-free chunk compare
i, n, recs = 0, len(a), 0
CH = 2352 * 64
pos = 0
while pos < n:
    if a[pos:pos + CH] == b[pos:pos + CH]:
        pos += CH
        continue
    end = min(pos + CH, n)
    i = pos
    while i < end:
        if a[i] != b[i]:
            j = i
            while j < end and j - i < 255 and a[j] != b[j]:
                j += 1
            # extend over short equal gaps to keep records few
            while j < end and j - i < 255:
                k = j
                while k < end and a[k] == b[k] and k - j < 8:
                    k += 1
                if k < end and a[k] != b[k] and k - i < 255:
                    j = k
                    while j < end and j - i < 255 and a[j] != b[j]:
                        j += 1
                else:
                    break
            out += struct.pack('<QB', i, j - i) + b[i:j]
            recs += 1
            i = j
        else:
            i += 1
    pos = end
open(sys.argv[3], 'wb').write(out)
print('records', recs, 'size', len(out))
