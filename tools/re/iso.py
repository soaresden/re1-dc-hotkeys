"""Minimal ISO9660 reader for raw Mode 2 PS1 images (2352-byte sectors).

usage: python tools/re/iso.py <image.bin> [file to extract] [out]
  no file: prints SYSTEM.CNF and the executable's LBA / size
"""
import struct, sys

SECTOR = 2352


def sector(f, lba):
    f.seek(lba * SECTOR + 24)
    return f.read(2048)


def root(f):
    pvd = sector(f, 16)
    assert pvd[1:6] == b'CD001', 'not ISO9660'
    rec = pvd[156:156 + 34]
    return struct.unpack_from('<I', rec, 2)[0], struct.unpack_from('<I', rec, 10)[0]


def listdir(f, lba, size):
    out = {}
    for s in range((size + 2047) // 2048):
        d = sector(f, lba + s)
        i = 0
        while i < 2048 and d[i]:
            n = d[i]
            flba = struct.unpack_from('<I', d, i + 2)[0]
            fsize = struct.unpack_from('<I', d, i + 10)[0]
            flags = d[i + 25]
            name = d[i + 33:i + 33 + d[i + 32]].decode('latin-1').split(';')[0]
            out[name.upper()] = (flba, fsize, flags & 2)
            i += n
    return out


def find(f, path):
    lba, size = root(f)
    for part in path.strip('\\/').upper().replace('\\', '/').split('/'):
        lba, size, _ = listdir(f, lba, size)[part]
    return lba, size


def read(f, path):
    lba, size = find(f, path)
    data = b''.join(sector(f, lba + i) for i in range((size + 2047) // 2048))
    return data[:size], lba, size


if __name__ == '__main__':
    with open(sys.argv[1], 'rb') as f:
        if len(sys.argv) > 2:
            data, lba, size = read(f, sys.argv[2])
            open(sys.argv[3] if len(sys.argv) > 3 else sys.argv[2].split('/')[-1], 'wb').write(data)
            print(sys.argv[2], 'LBA', lba, 'size', size)
        else:
            cnf = read(f, 'SYSTEM.CNF')[0].decode('latin-1')
            print(cnf.strip())
            boot = cnf.split('cdrom:')[1].split(';')[0].strip('\\')
            lba, size = find(f, boot)
            print('exe', boot, 'LBA', lba, 'size', size, 'sectors', (size + 2047) // 2048)
