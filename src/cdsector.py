"""Mode 2 Form 1 sector EDC/ECC encoder (CD-ROM XA)."""

def _build_tables():
    ecc_f = [0] * 256
    ecc_b = [0] * 256
    edc = [0] * 256
    for i in range(256):
        j = (i << 1) ^ (0x11D if i & 0x80 else 0)
        ecc_f[i] = j & 0xFF
        ecc_b[i ^ j & 0xFF] = i
        e = i
        for _ in range(8):
            e = (e >> 1) ^ (0xD8018001 if e & 1 else 0)
        edc[i] = e
    return ecc_f, ecc_b, edc

ECC_F, ECC_B, EDC_T = _build_tables()


def edc_compute(data):
    e = 0
    for b in data:
        e = (e >> 8) ^ EDC_T[(e ^ b) & 0xFF]
    return e


def _ecc_pq(sector, major_count, minor_count, major_mult, minor_inc, out_off):
    size = major_count * minor_count
    for major in range(major_count):
        index = (major >> 1) * major_mult + (major & 1)
        ecc_a = 0
        ecc_b = 0
        for _ in range(minor_count):
            temp = sector[0xC + index]
            index += minor_inc
            if index >= size:
                index -= size
            ecc_a ^= temp
            ecc_b ^= temp
            ecc_a = ECC_F[ecc_a]
        ecc_a = ECC_B[ECC_F[ecc_a] ^ ecc_b]
        sector[out_off + major] = ecc_a
        sector[out_off + major + major_count] = ecc_a ^ ecc_b


def encode_mode2_form1(sector):
    """sector: bytearray(2352) with sync/header/subheader/user data filled."""
    edc = edc_compute(sector[0x10:0x818])
    sector[0x818:0x81C] = edc.to_bytes(4, 'little')
    saved = bytes(sector[0xC:0x10])
    sector[0xC:0x10] = b'\0\0\0\0'
    _ecc_pq(sector, 86, 24, 2, 86, 0x81C)
    _ecc_pq(sector, 52, 43, 86, 88, 0x8C8)
    sector[0xC:0x10] = saved
    return sector
