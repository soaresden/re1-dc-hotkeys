// node tools/test_patcher.js : for every built version, the browser patcher
// (all options) must give the same sectors as src/build.py and the same
// .ppf as src/make_ppf.py
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..'), b = (...n) => path.join(root, 'build', ...n);
require(path.join(root, 'src', 'patcher', 'core.js'));
require(b('patcher_data.js'));
const P = globalThis.RE1Patch, D = P.DATA;
let ok = true;
for (const [vid, V] of Object.entries(D.versions)) {
  const start = V.exeLba * P.SECTOR, len = V.exeSectors * P.SECTOR;
  const read = (f) => { const fd = fs.openSync(f, 'r'), u = Buffer.alloc(len); fs.readSync(fd, u, 0, len, start); fs.closeSync(fd); return new Uint8Array(u); };
  const orig = read(b(vid, 'orig.bin')), ref = read(b(vid, 'patched.bin'));
  const exe = P.readExe(orig);
  const size = fs.statSync(b(vid, 'orig.bin')).size;
  const out = P.encodeSectors(orig, P.patchExe(vid, exe, [1, 1, 1, 1, 1, 1, 1]));
  const ppf = P.makePPF(orig, out, start, D.ppfDesc);
  const refPpf = fs.readFileSync(b(vid, 'patched.ppf'));
  const off = P.readExe(P.encodeSectors(orig, P.patchExe(vid, exe, [0, 0, 0, 0, 0, 0, 0])));
  const r = {
    detected: P.versionForSize(size) === vid,
    crc: P.crc32(exe) === V.exeCrc,
    sectors: Buffer.compare(Buffer.from(out), Buffer.from(ref)) === 0,
    ppf: Buffer.compare(Buffer.from(ppf), refPpf) === 0,
    configOff: Array.from(off.subarray(0x800 + D.configOffset, 0x800 + D.configOffset + 7)).every(x => x === 0),
  };
  console.log(vid.padEnd(5), JSON.stringify(r));
  ok = ok && Object.values(r).every(Boolean);
}
console.log(ok ? 'OK' : 'ECHEC');
process.exit(ok ? 0 : 1);
