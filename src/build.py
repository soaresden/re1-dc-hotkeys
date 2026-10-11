"""Full build, for every version of src/versions.py whose original disc is
available: original CHD -> code block -> patched BIN (+ CHD) -> xdelta / PPF,
then the patcher (all versions in one page).

usage: python src/build.py [--ver fr,us,usds] [--asm] [--chd] [--no-patches]
  --ver         versions to build (default: every version whose disc is found)
  --asm         only assemble the code blocks
  --chd         also make the patched CHDs (slow)
  --no-patches  skip the .xdelta / .ppf

Everything is relative to the project folder. Per version, build/<version>/
holds orig.bin / orig.cue (extracted from the CHD at the root, or put there by
hand), exe, version.h, tail.bin, hotkey.*, patched.bin / patched.cue.
Tools are looked up in tools/ first (Windows builds), then on the PATH:
  tools/mips/bin/mipsel-none-elf-*   or  mips-linux-gnu-*  (cpp, as, ld, objcopy, objdump, nm)
  tools/chdman/chdman.exe            or  chdman
  tools/xdelta/xdelta3-*.exe         or  xdelta3
"""
import base64, datetime, glob, hashlib, json, os, re, shutil, struct, subprocess, sys, zlib

SRC = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SRC)
BUILD = os.path.join(ROOT, 'build')
TOOLS = os.path.join(ROOT, 'tools')
PATCHER = os.path.join(ROOT, 'patcher', 'RE1-Hotkeys-Patcher.html')
sys.path.insert(0, SRC)
from versions import VERSIONS, header  # noqa: E402

PPF_DESC = 'RE1 DC - quick slots, HUD, quick turn'

# in-game options menu (feat_options.S), English in every version:
# title, the 6 options (config bytes 0..5), on / off, help ('[]' = Square)
MENU_TEXT = ['MOD OPTIONS', 'MENU - MOVE ITEMS WITH []', 'L2 - HOTKEYS', 'OVERLAY - L2 SHORTCUTS',
             'OVERLAY - HP', 'OVERLAY - GUN AND AMMO', 'QUICK TURN WITH DOWN+SQUARE',
             'QUICK RELOAD WITH R1+O', 'ON', 'OFF', 'X: SWITCH   START: BACK']
MENU_LINES = 7                    # = OPT_COUNT in feat_options.S


def menu_files(vid):
    """build/<vid>/font.inc and strings.inc, included by feat_options.S"""
    import font
    assert len(font.CHARS) == 42, 'FONT_GLYPHS in feat_options.S'
    for text in MENU_TEXT:
        assert all(c in font.CHARS for c in text), text
    open(vdir(vid, 'font.inc'), 'w', newline='\n').write(font.asm())
    t = MENU_TEXT
    enc = lambda s: ', '.join(str(g) for g in font.encode(s) + [0xff])
    out = ['opt_labels:'] + ['        .word str_opt%d' % i for i in range(MENU_LINES)]
    names = ['str_title'] + ['str_opt%d' % i for i in range(MENU_LINES)] + ['str_on', 'str_off', 'str_help']
    assert len(names) == len(t)
    for name, text in zip(names, t):
        out.append('%s: .byte %s   /* %s */' % (name, enc(text), text))
    out.append('str_cursor: .byte %s' % enc('>'))
    out.append('        .balign 4')
    open(vdir(vid, 'strings.inc'), 'w', newline='\n').write('\n'.join(out) + '\n')


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


def vdir(vid, name=''):
    return os.path.join(BUILD, vid, name)


def prepare(vid):
    """build/<vid>/orig.bin (from the CHD at the root if needed) and exe"""
    import build_patch
    v = VERSIONS[vid]
    os.makedirs(vdir(vid), exist_ok=True)
    b = lambda n: vdir(vid, n)
    if not os.path.exists(b('orig.bin')):
        chd = os.path.join(ROOT, v['chd'])
        if not os.path.exists(chd):
            return False
        print(vid, ': extraction de', v['chd'])
        run(exe_tool('chdman', 'chdman*.exe', 'chdman'), 'extractcd', '-i', chd, '-o', b('orig.cue'), '-ob', b('orig.bin'))
    if not os.path.exists(b('exe')):
        if sha1(b('orig.bin')) != v['bin_sha1']:
            sys.exit(vid + ' : orig.bin ne correspond pas au BIN Redump attendu')
        open(b('exe'), 'wb').write(build_patch.extract_exe(vid, b('orig.bin')))
    return True


def assemble(vid):
    from make_tail import make_tail
    import build_patch
    b = lambda n: vdir(vid, n)
    make_tail(b('exe'), b('tail.bin'))
    t_size = struct.unpack_from('<I', open(b('exe'), 'rb').read(), 0x1C)[0]
    tail_start = build_patch.ORIG_BASE + t_size - build_patch.BLOCK
    open(b('version.h'), 'w', newline='\n').write(
        header(vid) + '#define %-16s 0x%08x\n#define %-16s 0x%x\n' % ('TAIL_START', tail_start, 'BLOCK_SIZE', build_patch.BLOCK))
    menu_files(vid)
    a = VERSIONS[vid]['addr']
    open(b('link.ld'), 'w', newline='\n').write(
        'SECTIONS {\n  . = 0x%08X;\n  .text : { *(.text) *(.data) *(.tail) }\n'
        '  . = 0x%08X;\n  .text2 : { *(.text2) }\n'
        '  /DISCARD/ : { *(.MIPS.abiflags) *(.reginfo) *(.pdr) *(.gnu.attributes) }\n}\n'
        % (build_patch.HOOK_BASE, a['OPT_CODE']))
    pre = subprocess.check_output([tool('cpp'), '-P', '-undef', '-I', vdir(vid), os.path.join(SRC, 'hotkey.S')]).decode()
    open(b('hotkey.pre.s'), 'w', newline='\n').write(pre)
    run(sys.executable, os.path.join(SRC, 'fix_delay.py'), b('hotkey.pre.s'), b('hotkey.s'))
    run(tool('as'), '-march=r3000', '-mno-shared', '-EL', '-I', vdir(vid), '-o', b('hotkey.o'), b('hotkey.s'))
    run(tool('ld'), '-EL', '-T', b('link.ld'), '-o', b('hotkey.elf'), b('hotkey.o'))
    run(tool('objcopy'), '-O', 'binary', '-j', '.text', b('hotkey.elf'), b('hotkey.bin'))
    run(tool('objcopy'), '-O', 'binary', '-j', '.text2', b('hotkey.elf'), b('hotkey2.bin'))
    check_hazards(vid)


def check_hazards(vid):
    import build_patch
    b = lambda n: vdir(vid, n)
    syms = build_patch.symbols(b('hotkey.elf'))
    code_end = syms['code_end']
    data = (syms['config'], syms['config'] + 8)     # config: data, not code
    code2 = (syms['opt_start'], syms['opt_code_end'])
    d = subprocess.check_output([tool('objdump'), '-d', '-EL', b('hotkey.elf')]).decode().splitlines()
    ins = []
    for l in d:
        m = re.match(r'^\s*(?:ffffffff)?([0-9a-f]{8}):\s+([0-9a-f]{8})\s+(\S+)\s*(.*)$', l)
        a = int(m.group(1), 16) if m else 0
        if m and (a < code_end and not data[0] <= a < data[1] or code2[0] <= a < code2[1]):
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
    size2 = os.path.getsize(b('hotkey2.bin'))
    max2 = VERSIONS[vid]['addr']['OPT_CODE_SIZE']
    print('%-5s code %d octets, bloc %d / %d, menu %d / %d, hazards %d' % (
        vid, code_end - syms['_start'], size, build_patch.BLOCK, size2, max2, bad))
    if bad or size > build_patch.BLOCK or size2 > max2:
        sys.exit('construction refusée')


def patch_version(vid, args):
    import build_patch
    b = lambda n: vdir(vid, n)
    v = VERSIONS[vid]
    exe = build_patch.build_exe(vid, vdir(vid))
    open(b('exe.patched'), 'wb').write(exe)
    build_patch.inject(vid, b('orig.bin'), b('patched.bin'), exe)
    open(b('patched.cue'), 'w', newline='\n').write('FILE "patched.bin" BINARY\n' + v['cue_tracks'])
    print('%-5s patched.bin %s' % (vid, sha1(b('patched.bin'))))
    stem = v['name']
    if '--no-patches' not in args:
        os.makedirs(os.path.join(ROOT, 'patch'), exist_ok=True)
        xdelta = os.path.join(ROOT, 'patch', stem + ' [Hotkeys].xdelta')
        if os.path.exists(xdelta):
            os.remove(xdelta)
        # relative names: xdelta3 stores them in its header
        run(exe_tool('xdelta', 'xdelta3*.exe', 'xdelta3'), '-e', '-9', '-s', 'orig.bin', 'patched.bin', xdelta, cwd=vdir(vid))
        # the .ppf holds the shifted executable: local use only (not published)
        run(sys.executable, os.path.join(SRC, 'make_ppf.py'), b('orig.bin'), b('patched.bin'), b('hotkeys.ppf'), PPF_DESC)
        print('%-5s xdelta %s' % (vid, sha1(xdelta)))
    if '--chd' in args:
        chd = os.path.join(ROOT, stem + ' [Hotkeys].chd')
        if os.path.exists(chd):
            os.remove(chd)
        run(exe_tool('chdman', 'chdman*.exe', 'chdman'), 'createcd', '-i', b('patched.cue'), '-o', chd)
        print('%-5s chd %s' % (vid, sha1(chd)))


def make_patcher(vids):
    """patcher/RE1-Hotkeys-Patcher.html (and docs/index.html for GitHub Pages):
    src/patcher/patcher.html with core.js and the code blocks inlined. No game
    data: the patcher reads the executable from the user's disc."""
    import build_patch
    data = {'version': datetime.date.today().isoformat(), 'base': build_patch.HOOK_BASE,
            'block': build_patch.BLOCK, 'origBase': build_patch.ORIG_BASE, 'ppfDesc': PPF_DESC, 'versions': {}}
    for vid in vids:
        v = VERSIONS[vid]
        b = lambda n: vdir(vid, n)
        syms = build_patch.symbols(b('hotkey.elf'))
        exe = open(b('exe'), 'rb').read()
        data['configOffset'] = syms['config'] - syms['_start']
        data['versions'][vid] = {
            'name': v['name'], 'serial': v['serial'],
            'code': base64.b64encode(open(b('hotkey.bin'), 'rb').read()[:syms['taildata'] - syms['_start']]).decode(),
            'code2': base64.b64encode(open(b('hotkey2.bin'), 'rb').read()).decode(), 'code2Addr': v['addr']['OPT_CODE'],
            'hooks': [[site, orig, build_patch.jal(syms[name])] for site, orig, name in build_patch.hooks(vid)],
            'pc0': v['addr']['GAME_ENTRY'], 'tSize': struct.unpack_from('<I', exe, 0x1C)[0],
            'exeLba': v['exe_lba'], 'exeSectors': v['exe_sectors'],
            'exeCrc': zlib.crc32(exe), 'patchedCrc': zlib.crc32(open(b('exe.patched'), 'rb').read()),
            'binSizes': [v['bin_size']] + ([v['track1_size']] if 'track1_size' in v else []),
            'track1Size': v.get('track1_size', 0), 'cueTracks': v['cue_tracks'],
        }
    js = 'window.RE1Patch = Object.assign(window.RE1Patch || {}, { DATA: ' + json.dumps(data) + ' });\n'
    open(os.path.join(BUILD, 'patcher_data.js'), 'w', newline='\n').write(js.replace('window.', 'globalThis.'))
    html = open(os.path.join(SRC, 'patcher', 'patcher.html'), encoding='utf-8').read()
    core = open(os.path.join(SRC, 'patcher', 'core.js'), encoding='utf-8').read()
    html = html.replace('/*CORE*/', core).replace('/*DATA*/', js)
    os.makedirs(os.path.dirname(PATCHER), exist_ok=True)
    open(PATCHER, 'w', encoding='utf-8', newline='\n').write(html)
    open(os.path.join(ROOT, 'docs', 'index.html'), 'w', encoding='utf-8', newline='\n').write(html)
    print('patcher', os.path.relpath(PATCHER, ROOT), len(html), 'octets,', ', '.join(vids))


def main():
    args = sys.argv[1:]
    want = list(VERSIONS)
    if '--ver' in args:
        want = args[args.index('--ver') + 1].split(',')
    os.environ['NM'] = tool('nm')
    import build_patch
    build_patch.NM = os.environ['NM']
    vids = [vid for vid in want if prepare(vid)]
    if not vids:
        sys.exit('aucune image d\'origine trouvée (CHD à la racine ou build/<version>/orig.bin)')
    for vid in vids:
        assemble(vid)
    if '--asm' in args:
        return
    for vid in vids:
        patch_version(vid, args)
    make_patcher([vid for vid in VERSIONS if os.path.exists(vdir(vid, 'exe.patched'))])


if __name__ == '__main__':
    main()
