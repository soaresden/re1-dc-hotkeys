"""Run a s_hk.lua scenario in PCSX-Redux (replaces runhk.sh, works on Windows and Linux).

usage: python tools/emu-tests/run.py <scenario> [last frame] [--ver fr|us|usds] [--state file.sstate]

Needs build/<ver>/hotkey.elf, hotkey.bin and patched.cue (python src/build.py) and a save
state build/dining_<ver>.sstate (fr: dining_jill.sstate, also in tools/emu-tests/*.gz).
The emulator is tools/redux/pcsx-redux(.exe), else pcsx-redux on the PATH.
Output: build/emu/<scenario>/ (log.txt, *.png screenshots, *.vram + *_vram.png)."""
import glob, gzip, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUILD = os.path.join(ROOT, 'build')
sys.path.insert(0, os.path.join(ROOT, 'src'))
from build import tool  # noqa: E402


VER = 'fr'


def symbols():
    out = subprocess.check_output([tool('nm'), os.path.join(BUILD, VER, 'hotkey.elf')]).decode()
    return {n: int(a, 16) & 0xffffffff for a, t, n in (l.split() for l in out.splitlines())}


def emulator():
    hits = glob.glob(os.path.join(ROOT, 'tools', 'redux', 'pcsx-redux*'))
    hits = [h for h in hits if h.endswith(('.exe', 'AppRun', 'pcsx-redux'))]
    return hits[0] if hits else (shutil.which('pcsx-redux') or sys.exit('PCSX-Redux introuvable'))


def to_png(outdir):
    try:
        from PIL import Image
    except ImportError:
        print('(Pillow absent : pas de PNG)')
        return
    import re
    for line in open(os.path.join(outdir, 'log.txt')):
        m = re.match(r'SHOT (\S+) (\d+)x(\d+) bpp=(\d)', line)
        if m:
            name, w, h, bpp = m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4))
            d = open(os.path.join(outdir, name + '.raw'), 'rb').read()
            try:                               # a shot overwritten while being read: skip it
                if bpp == 1:
                    im = Image.frombytes('RGB', (w, h), d[:w * h * 3])
                else:
                    im = rgb555(d, w, h)
                im.save(os.path.join(outdir, name + '.png'))
            except (ValueError, IndexError):
                pass
        m = re.match(r'VRAM (\S+)', line)
        if m:
            d = open(os.path.join(outdir, m.group(1) + '.vram'), 'rb').read()
            rgb555(d, 1024, 512).save(os.path.join(outdir, m.group(1) + '_vram.png'))


def rgb555(d, w, h):
    from PIL import Image
    out = bytearray(w * h * 3)
    for i in range(w * h):
        v = d[i * 2] | (d[i * 2 + 1] << 8)
        out[i * 3] = (v & 31) << 3
        out[i * 3 + 1] = ((v >> 5) & 31) << 3
        out[i * 3 + 2] = ((v >> 10) & 31) << 3
    return Image.frombytes('RGB', (w, h), bytes(out))


def main():
    global VER
    args = sys.argv[1:]
    if '--ver' in args:
        i = args.index('--ver'); VER = args[i + 1]; del args[i:i + 2]
    # made with tools/redux (launch.py + cmd.py 'save')
    state = os.path.join(BUILD, 'dining_jill.sstate' if VER == 'fr' else 'dining_%s.sstate' % VER)
    if '--state' in args:
        i = args.index('--state'); state = os.path.abspath(args[i + 1]); del args[i:i + 2]
    scen = args[0]
    last = args[1] if len(args) > 1 else '340'
    gz = os.path.join(HERE, os.path.basename(state) + '.gz')
    if not os.path.exists(state) and os.path.exists(gz):
        with gzip.open(gz, 'rb') as f:
            open(state, 'wb').write(f.read())
    s = symbols()
    jal = lambda a: '%08x' % (0x0C000000 | ((a >> 2) & 0x3FFFFFF))
    outdir = os.path.join(BUILD, 'emu', scen if VER == 'fr' else VER + '_' + scen)
    sys.path.insert(0, os.path.join(ROOT, 'src'))
    from versions import VERSIONS
    sites = VERSIONS[VER]['addr']
    os.makedirs(outdir, exist_ok=True)
    for f in os.listdir(outdir):               # emptied, not removed (may be a shell's cwd)
        os.remove(os.path.join(outdir, f))
    env = dict(os.environ,
               HK_SCEN=scen, HK_STATE=state, HK_LAST=last,
               HK_HOOK='%08x' % s['hook'], HK_JAL=jal(s['hook']),
               HK_DRAW='%08x' % s['draw_hook'], HK_DRAWJAL=jal(s['draw_hook']),
               HK_FRAMEJAL=jal(s['frame_hook']), HK_FRAMEHOOK='%08x' % s['frame_hook'], HK_HUD='%08x' % s['hud_draw'], HK_PUTTILE='%08x' % s['put_tile'],
               HK_PICK='%08x' % s['st'], HK_BASE='%08x' % s['_start'],
               HK_SITE_HOOK='%08x' % sites['SITE_HOOK'], HK_SITE_GRID='%08x' % sites['SITE_GRID'],
               HK_SITE_FRAME='%08x' % sites['SITE_FRAME'], HK_VER=VER,
               HK_INJECT=os.environ.get('HK_INJECT', os.path.join(BUILD, VER, 'hotkey.bin')),
               HK_INJECT2=os.path.join(BUILD, VER, 'hotkey2.bin'), HK_BASE2='%08x' % s['opt_start'],
               HARNESS_OUT_DIR=outdir, HARNESS_OUT=outdir,
               HARNESS_SCRIPT=os.path.join(HERE, 's_hk.lua'))
    cmd = [emulator(), '-cli', '-stdout', '-interpreter', '-run',
           '-iso', os.path.join(BUILD, VER, 'patched.cue'), '-dofile', os.path.join(HERE, 'harness.lua')]
    with open(outdir + '.emu.log', 'w') as log:
        try:
            r = subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=300, cwd=HERE)
            print('exit', r.returncode)
        except subprocess.TimeoutExpired:
            print('timeout')
    to_png(outdir)
    print(outdir)


if __name__ == '__main__':
    main()
