"""Build patched SLES_009.70 with the hotkey hooks and inject it into a copy of the BIN.

usage: build_patch.py <re1.bin> <re1_hk.bin> [build dir]
The build dir (default: current dir) holds SLES_009.70, hotkey.bin and hotkey.elf."""
import os, struct, shutil, subprocess, sys
from cdsector import encode_mode2_form1

HOOK_BASE = 0x8000E800
BLOCK = 0x1800             # = make_tail.DROP
ORIG_BASE = 0x80010000
EXE_LBA = 287669
EXE_SECTORS = 320
# (call site, original instruction, our function)
HOOKS = [
    (0x80032084, 0x0C00CBB7, 'hook'),        # jal 0x80032EDC: main loop, after the pad read
    (0x80054C9C, 0x0C0153CF, 'draw_hook'),   # jal 0x80054F3C: inventory item grid
    (0x80032740, 0x0C005703, 'frame_hook'),  # jal 0x80015C0C: main loop, OT complete
]
NM = os.environ.get('NM', 'mips-linux-gnu-nm')


def sym(name, elf='hotkey.elf'):
    out = subprocess.check_output([NM, elf]).decode()
    for line in out.splitlines():
        a, t, n = line.split()
        if n == name:
            return int(a, 16) & 0xFFFFFFFF
    raise KeyError(name)


def extract_exe(bin_path):
    """SLES_009.70 straight from the BIN (LBA and size are fixed for this disc)."""
    out = bytearray()
    with open(bin_path, 'rb') as f:
        for i in range(EXE_SECTORS):
            f.seek((EXE_LBA + i) * 2352 + 24)
            out += f.read(2048)
    assert out[:8] == b'PS-X EXE'
    return bytes(out)


def jal(addr):
    return 0x0C000000 | ((addr >> 2) & 0x3FFFFFF)


def build_exe(d='.'):
    p = lambda n: os.path.join(d, n)
    exe = bytearray(open(p('SLES_009.70'), 'rb').read())
    hdr = exe[:0x800]
    pc0, gp0, t_addr, t_size = struct.unpack_from('<IIII', hdr, 0x10)
    assert (pc0, t_addr, t_size) == (0x800606A8, ORIG_BASE, 0x9F800), (hex(pc0), hex(t_addr), hex(t_size))
    image = exe[0x800:0x800 + t_size]
    hook = open(p('hotkey.bin'), 'rb').read()
    assert len(hook) <= BLOCK, hex(len(hook))
    hook = hook + b'\0' * (BLOCK - len(hook))
    new_image = bytearray(hook + image[:t_size - BLOCK])
    for site, orig, name in HOOKS:
        off = site - HOOK_BASE
        assert struct.unpack_from('<I', new_image, off)[0] == orig, hex(site)
        struct.pack_into('<I', new_image, off, jal(sym(name, p('hotkey.elf'))))
    new_hdr = bytearray(hdr)
    struct.pack_into('<IIII', new_hdr, 0x10, HOOK_BASE, gp0, HOOK_BASE, t_size)
    out = bytes(new_hdr) + bytes(new_image)
    assert len(out) == len(exe)
    return out


def inject(bin_in, bin_out, exe_bytes):
    shutil.copyfile(bin_in, bin_out)
    with open(bin_out, 'r+b') as f:
        for i in range(len(exe_bytes) // 2048):
            f.seek((EXE_LBA + i) * 2352)
            s = bytearray(f.read(2352))
            s[0x18:0x818] = exe_bytes[i * 2048:(i + 1) * 2048]
            encode_mode2_form1(s)
            f.seek((EXE_LBA + i) * 2352)
            f.write(s)


if __name__ == '__main__':
    d = sys.argv[3] if len(sys.argv) > 3 else '.'
    exe = build_exe(d)
    open(os.path.join(d, 'SLES_009.70.patched'), 'wb').write(exe)
    inject(sys.argv[1], sys.argv[2], exe)
    print('ok', len(exe))
