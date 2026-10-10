// node tools/test_patcher.js : the browser patcher (all options) must give the
// same sectors as src/build.py and the same .ppf as src/make_ppf.py
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..'), b = n => path.join(root, 'build', n);
require(path.join(root, 'src', 'patcher', 'core.js'));
require(b('patcher_data.js'));
const P = globalThis.RE1Patch, D = P.DATA;
const start = D.exeLba * P.SECTOR, len = D.exeSectors * P.SECTOR;
const read = (f) => { const fd = fs.openSync(f, 'r'), u = Buffer.alloc(len); fs.readSync(fd, u, 0, len, start); fs.closeSync(fd); return new Uint8Array(u); };
const orig = read(b('re1.bin')), ref = read(b('re1_hk.bin'));
const exe = P.readExe(orig);
console.log('exe crc ok', P.crc32(exe) === D.exeCrc);
const out = P.encodeSectors(orig, P.patchExe(exe, [1, 1, 1, 1, 1, 1]));
console.log('sectors identical', Buffer.compare(Buffer.from(out), Buffer.from(ref)) === 0);
const ppf = P.makePPF(orig, out, start, D.ppfDesc);
const refPpf = fs.readFileSync(path.join(root, 'patch', "Resident Evil - Director's Cut (France) [SLES_009.70].ppf"));
console.log('ppf identical', Buffer.compare(Buffer.from(ppf), refPpf) === 0, ppf.length, refPpf.length);
const off = P.encodeSectors(orig, P.patchExe(exe, [0, 0, 0, 0, 0, 0]));
const offExe = P.readExe(off);
console.log('config bytes (all off)', Array.from(offExe.subarray(0x800 + D.configOffset, 0x800 + D.configOffset + 8)));
