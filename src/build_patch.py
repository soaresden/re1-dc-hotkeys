"""Patched executable and BIN for one version (src/versions.py).

Used by src/build.py; build/<version>/ holds orig.bin, exe (the original
executable), hotkey.bin and hotkey.elf."""
import os, struct, shutil, subprocess
from cdsector import encode_mode2_form1
from versions import VERSIONS

HOOK_BASE = 0x8000E800
BLOCK = 0x1800             # = make_tail DROP
ORIG_BASE = 0x80010000
NM = os.environ.get('NM', 'mips-linux-gnu-nm')


def hooks(vid):
    """(call site, original instruction, our function) for a version"""
    a = VERSIONS[vid]['addr']
    return [
        (a['SITE_HOOK'], jal(a['LOOP_NEXT']), 'hook'),         # main loop, after the pad read
        (a['SITE_GRID'], jal(a['F_GRID_DRAW']), 'draw_hook'),  # inventory item grid
        (a['SITE_FRAME'], jal(a['F_PAL_ANIM']), 'frame_hook'), # main loop, OT complete
    ]


def symbols(elf):
    out = {}
    for line in subprocess.check_output([NM, elf]).decode().splitlines():
        a, t, n = line.split()
        out[n] = int(a, 16) & 0xFFFFFFFF
    return out


def extract_exe(vid, bin_path):
    """the executable straight from the BIN (LBA and size are fixed per disc)"""
    v = VERSIONS[vid]
    out = bytearray()
    with open(bin_path, 'rb') as f:
        for i in range(v['exe_sectors']):
            f.seek((v['exe_lba'] + i) * 2352 + 24)
            out += f.read(2048)
    assert out[:8] == b'PS-X EXE'
    return bytes(out)


def jal(addr):
    return 0x0C000000 | ((addr >> 2) & 0x3FFFFFF)


def build_exe(vid, d):
    p = lambda n: os.path.join(d, n)
    v = VERSIONS[vid]
    exe = bytearray(open(p('exe'), 'rb').read())
    hdr = exe[:0x800]
    pc0, gp0, t_addr, t_size = struct.unpack_from('<IIII', hdr, 0x10)
    assert (pc0, t_addr) == (v['addr']['GAME_ENTRY'], ORIG_BASE), (hex(pc0), hex(t_addr))
    image = exe[0x800:0x800 + t_size]
    hook = open(p('hotkey.bin'), 'rb').read()
    assert len(hook) <= BLOCK, hex(len(hook))
    hook = hook + b'\0' * (BLOCK - len(hook))
    new_image = bytearray(hook + image[:t_size - BLOCK])
    syms = symbols(p('hotkey.elf'))
    for site, orig, name in hooks(vid):
        off = site - HOOK_BASE
        assert struct.unpack_from('<I', new_image, off)[0] == orig, (vid, hex(site))
        struct.pack_into('<I', new_image, off, jal(syms[name]))
    new_hdr = bytearray(hdr)
    struct.pack_into('<IIII', new_hdr, 0x10, HOOK_BASE, gp0, HOOK_BASE, t_size)
    out = bytes(new_hdr) + bytes(new_image)
    assert len(out) == len(exe)
    return out


def inject(vid, bin_in, bin_out, exe_bytes):
    lba = VERSIONS[vid]['exe_lba']
    shutil.copyfile(bin_in, bin_out)
    with open(bin_out, 'r+b') as f:
        for i in range(len(exe_bytes) // 2048):
            f.seek((lba + i) * 2352)
            s = bytearray(f.read(2352))
            s[0x18:0x818] = exe_bytes[i * 2048:(i + 1) * 2048]
            encode_mode2_form1(s)
            f.seek((lba + i) * 2352)
            f.write(s)
