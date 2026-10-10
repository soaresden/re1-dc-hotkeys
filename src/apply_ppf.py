import struct, sys
img = bytearray(open(sys.argv[1], 'rb').read())
p = open(sys.argv[2], 'rb').read()
assert p[:5] == b'PPF30' and p[5] == 2
pos = 60 + (1024 if p[57] else 0)
while pos < len(p):
    off, ln = struct.unpack_from('<QB', p, pos); pos += 9
    img[off:off + ln] = p[pos:pos + ln]; pos += ln
open(sys.argv[3], 'wb').write(img)
