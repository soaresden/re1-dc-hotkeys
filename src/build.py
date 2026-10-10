"""Full build: original CHD -> hotkey block -> patched BIN/CHD -> PPF + xdelta.

usage: python src/build.py [--asm] [--no-chd] [--no-patches]
  --asm         only assemble hotkey.bin (needs build/SLES_009.70)
  --no-chd      skip the patched CHD (slow)
  --no-patches  skip the .ppf / .xdelta

Everything is relative to the project folder; intermediate files go to build/.
Tools are looked up in tools/ first (Windows builds), then on the PATH:
  tools/mips/bin/mipsel-none-elf-*   or  mips-linux-gnu-*  (cpp, as, ld, objcopy, objdump, nm)
  tools/chdman/chdman.exe            or  chdman
  tools/xdelta/xdelta3-*.exe         or  xdelta3
"""
import base64, datetime, glob, hashlib, json, os, re, shutil, subprocess, sys, zlib

SRC = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SRC)
BUILD = os.path.join(ROOT, 'build')
TOOLS = os.path.join(ROOT, 'tools')
NAME = "Resident Evil - Director's Cut (France) [SLES_009.70]"
ORIG_CHD = os.path.join(ROOT, NAME + '.chd')
HK_CHD = os.path.join(ROOT, NAME + ' [Hotkeys].chd')
PPF = os.path.join(ROOT, 'patch', NAME + '.ppf')
XDELTA = os.path.join(ROOT, 'patch', NAME + ' - Raccourcis.xdelta')
PPF_DESC = 'RE1 DC FR - raccourcis L2 + deplacement objets'
PATCHER = os.path.join(ROOT, 'patcher', 'RE1-Hotkeys-Patcher.html')
ORIG_BIN_SHA1 = '5d9d1ea07595ae468ba4183a73331f0dace2384e'


def tool(name):
    for pat in (os.path.join(TOOLS, 'mips', 'bin', 'mipsel-none-elf-' + name + '*'),):
        hits = [h for h in glob.glob(pat) if re.search(r'-' + name + r'(\.exe)?$', h)]
        if hits:
            return hits[0]
    for cand in ('mips-linux-gnu-' + name, 'mipsel-linux-gnu-' + name, 'mipsel-none-elf-' + name):
        if shutil.which(cand):
            return cand
    sys.exit('outil introuvable : ' + name)


def exe_tool(sub, pattern, fallback):
    hits = glob.glob(os.path.join(TOOLS, sub, pattern))
    if hits:
        return hits[0]
    if shutil.which(fallback):
        return fallback
    sys.exit('outil introuvable : ' + fallback)


def run(*cmd, **kw):
    subprocess.check_call(list(cmd), **kw)


def sha1(path):
    h = hashlib.sha1()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def b(name):
    return os.path.join(BUILD, name)


def assemble():
    sys.path.insert(0, SRC)
    from make_tail import make_tail
    make_tail(b('SLES_009.70'), b('tail.bin'))
    pre = subprocess.check_output([tool('cpp'), '-P', '-undef', os.path.join(SRC, 'hotkey.S')]).decode()
    open(b('hotkey.pre.s'), 'w', newline='\n').write(pre)
    run(sys.executable, os.path.join(SRC, 'fix_delay.py'), b('hotkey.pre.s'), b('hotkey.s'))
    run(tool('as'), '-march=r3000', '-mno-shared', '-EL', '-I', BUILD, '-o', b('hotkey.o'), b('hotkey.s'))
    run(tool('ld'), '-EL', '-T', os.path.join(SRC, 'link.ld'), '-o', b('hotkey.elf'), b('hotkey.o'))
    run(tool('objcopy'), '-O', 'binary', '-j', '.text', b('hotkey.elf'), b('hotkey.bin'))
    check_hazards()
    nm = subprocess.check_output([tool('nm'), b('hotkey.elf')]).decode()
    for line in nm.splitlines():
        if re.search(r' (_start|config|hook|draw_hook|frame_hook|swap_task|st|code_end|taildata|block_end)$', line):
            print('  ' + line)


def check_hazards():
    # only the code: data (config, .data, .tail) is skipped
    syms = {}
    for line in subprocess.check_output([tool('nm'), b('hotkey.elf')]).decode().splitlines():
        a, t, n = line.split()
        syms[n] = int(a, 16) & 0xffffffff
    code_end = syms['code_end']
    data = (syms['config'], syms['config'] + 8)
    d = subprocess.check_output([tool('objdump'), '-d', '-EL', b('hotkey.elf')]).decode().splitlines()
    ins = []
    for l in d:
        m = re.match(r'^\s*(?:ffffffff)?([0-9a-f]{8}):\s+([0-9a-f]{8})\s+(\S+)\s*(.*)$', l)
        if m and int(m.group(1), 16) < code_end and not data[0] <= int(m.group(1), 16) < data[1]:
            ins.append((m.group(1), m.group(3), m.group(4)))
    bad = 0
    jumps = ('j', 'jal', 'jr', 'jalr')
    for i in range(len(ins) - 1):
        a, op, args = ins[i]
        if op in ('lw', 'lh', 'lhu', 'lb', 'lbu'):
            rt = args.split(',')[0]
            if re.search(r'\b' + rt + r'\b', ins[i + 1][2]):
                print('HAZARD', a, op, args, '->', ins[i + 1]); bad += 1
        if op.startswith('b') or op in jumps:
            nxt = ins[i + 1][1]
            if nxt.startswith('b') or nxt in jumps:
                print('BRANCH IN DELAY SLOT', a); bad += 1
    size = os.path.getsize(b('hotkey.bin'))
    print('hotkey.bin', size, 'octets, hazards', bad)
    print('code', code_end - syms['_start'], 'octets, bloc', size, '/', 0x1800, 'octets')
    if bad or size > 0x1800:
        sys.exit('construction refusée')


def make_patcher():
    """patcher/RE1-Hotkeys-Patcher.html: src/patcher/patcher.html with core.js and
    the code block inlined (no game data: the patcher reads the user's disc)."""
    sys.path.insert(0, SRC)
    import build_patch
    syms = {}
    for line in subprocess.check_output([tool('nm'), b('hotkey.elf')]).decode().splitlines():
        a, t, n = line.split()
        syms[n] = int(a, 16) & 0xffffffff
    code = open(b('hotkey.bin'), 'rb').read()[:syms['taildata'] - syms['_start']]
    exe = open(b('SLES_009.70'), 'rb').read()
    data = {
        'version': datetime.date.today().isoformat(),
        'base': build_patch.HOOK_BASE, 'block': build_patch.BLOCK,
        'configOffset': syms['config'] - syms['_start'],
        'code': base64.b64encode(code).decode(),
        'hooks': [[site, orig, build_patch.jal(syms[name])] for site, orig, name in build_patch.HOOKS],
        'pc0': 0x800606A8, 'origBase': build_patch.ORIG_BASE, 'tSize': 0x9F800,
        'exeLba': build_patch.EXE_LBA, 'exeSectors': build_patch.EXE_SECTORS,
        'exeCrc': zlib.crc32(exe), 'patchedCrc': zlib.crc32(open(b('SLES_009.70.patched'), 'rb').read()),
        'binSize': os.path.getsize(b('re1.bin')), 'ppfDesc': PPF_DESC,
    }
    js = 'window.RE1Patch = Object.assign(window.RE1Patch || {}, { DATA: ' + json.dumps(data) + ' });\n'
    open(b('patcher_data.js'), 'w', newline='\n').write(js.replace('window.', 'globalThis.'))
    html = open(os.path.join(SRC, 'patcher', 'patcher.html'), encoding='utf-8').read()
    core = open(os.path.join(SRC, 'patcher', 'core.js'), encoding='utf-8').read()
    html = html.replace('/*CORE*/', core).replace('/*DATA*/', js)
    os.makedirs(os.path.dirname(PATCHER), exist_ok=True)
    open(PATCHER, 'w', encoding='utf-8', newline='\n').write(html)
    # same page for GitHub Pages (served from docs/)
    open(os.path.join(ROOT, 'docs', 'index.html'), 'w', encoding='utf-8', newline='\n').write(html)
    print('patcher', os.path.relpath(PATCHER, ROOT), len(html), 'octets')


def main():
    args = set(sys.argv[1:])
    os.makedirs(BUILD, exist_ok=True)
    os.environ['NM'] = tool('nm')
    chdman = exe_tool('chdman', 'chdman*.exe', 'chdman')

    if not os.path.exists(b('re1.bin')):
        print('extraction du CHD d\'origine...')
        run(chdman, 'extractcd', '-i', ORIG_CHD, '-o', b('re1.cue'), '-ob', b('re1.bin'))
    if not os.path.exists(b('SLES_009.70')):
        if sha1(b('re1.bin')) != ORIG_BIN_SHA1:
            sys.exit('build/re1.bin ne correspond pas au BIN Redump FR')
        sys.path.insert(0, SRC)
        from build_patch import extract_exe
        open(b('SLES_009.70'), 'wb').write(extract_exe(b('re1.bin')))

    assemble()
    if '--asm' in args:
        return

    run(sys.executable, os.path.join(SRC, 'build_patch.py'), b('re1.bin'), b('re1_hk.bin'), BUILD, cwd=SRC)
    open(b('re1_hk.cue'), 'w', newline='\n').write(
        'FILE "re1_hk.bin" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n')
    print('re1_hk.bin', sha1(b('re1_hk.bin')))
    make_patcher()

    if '--no-patches' not in args:
        os.makedirs(os.path.dirname(PPF), exist_ok=True)
        run(sys.executable, os.path.join(SRC, 'make_ppf.py'), b('re1.bin'), b('re1_hk.bin'), PPF, PPF_DESC)
        xd = exe_tool('xdelta', 'xdelta3*.exe', 'xdelta3')
        if os.path.exists(XDELTA):
            os.remove(XDELTA)
        # relative names: xdelta3 stores them in its header
        run(xd, '-e', '-9', '-s', 're1.bin', 're1_hk.bin', XDELTA, cwd=BUILD)
        print('ppf   ', sha1(PPF))
        print('xdelta', sha1(XDELTA))

    if '--no-chd' not in args:
        if os.path.exists(HK_CHD):
            os.remove(HK_CHD)
        run(chdman, 'createcd', '-i', b('re1_hk.cue'), '-o', HK_CHD)
        print('chd   ', sha1(HK_CHD))


if __name__ == '__main__':
    main()
