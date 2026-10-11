/* RE1 DC FR mod patcher, core (browser and Node).
   Same steps as src/build_patch.py, from the code block built by src/build.py
   (DATA, generated): no game data is embedded, the executable comes from the
   user's own disc image.

   Exported: RE1Patch.{DATA, crc32, readExe, patchExe, versionForSize, encodeSectors, makePPF} */
(function (root) {
  'use strict';

  const SECTOR = 2352;

  /* ---- CRC32 (to recognise the original executable) ---- */
  const CRC_T = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    CRC_T[i] = c >>> 0;
  }
  function crc32(u8) {
    let c = 0xFFFFFFFF;
    for (let i = 0; i < u8.length; i++) c = CRC_T[(c ^ u8[i]) & 0xFF] ^ (c >>> 8);
    return (c ^ 0xFFFFFFFF) >>> 0;
  }

  /* ---- Mode 2 Form 1 EDC / ECC (port of src/cdsector.py) ---- */
  const ECC_F = new Uint8Array(256), ECC_B = new Uint8Array(256), EDC_T = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    const j = ((i << 1) ^ (i & 0x80 ? 0x11D : 0)) & 0xFF;
    ECC_F[i] = j;
    ECC_B[i ^ j] = i;
    let e = i;
    for (let k = 0; k < 8; k++) e = (e >>> 1) ^ (e & 1 ? 0xD8018001 : 0);
    EDC_T[i] = e >>> 0;
  }
  function edc(s, from, to) {
    let e = 0;
    for (let i = from; i < to; i++) e = (e >>> 8) ^ EDC_T[(e ^ s[i]) & 0xFF];
    return e >>> 0;
  }
  function eccPQ(s, majorCount, minorCount, majorMult, minorInc, out) {
    const size = majorCount * minorCount;
    for (let major = 0; major < majorCount; major++) {
      let index = (major >> 1) * majorMult + (major & 1);
      let a = 0, b = 0;
      for (let m = 0; m < minorCount; m++) {
        const t = s[0xC + index];
        index += minorInc;
        if (index >= size) index -= size;
        a ^= t; b ^= t;
        a = ECC_F[a];
      }
      a = ECC_B[ECC_F[a] ^ b];
      s[out + major] = a;
      s[out + major + majorCount] = a ^ b;
    }
  }
  /* s: Uint8Array view of one 2352-byte sector, user data already in place */
  function encodeMode2Form1(s) {
    const e = edc(s, 0x10, 0x818);
    s[0x818] = e & 0xFF; s[0x819] = (e >>> 8) & 0xFF; s[0x81A] = (e >>> 16) & 0xFF; s[0x81B] = e >>> 24;
    const saved = s.slice(0xC, 0x10);
    s.fill(0, 0xC, 0x10);
    eccPQ(s, 86, 24, 2, 86, 0x81C);
    eccPQ(s, 52, 43, 86, 88, 0x8C8);
    s.set(saved, 0xC);
  }

  /* ---- executable ---- */
  const rd32 = (u8, o) => (u8[o] | (u8[o + 1] << 8) | (u8[o + 2] << 16) | (u8[o + 3] << 24)) >>> 0;
  function wr32(u8, o, v) { u8[o] = v & 0xFF; u8[o + 1] = (v >>> 8) & 0xFF; u8[o + 2] = (v >>> 16) & 0xFF; u8[o + 3] = v >>> 24; }

  /* sectors: the executable's raw sectors (DATA.exeSectors * 2352 bytes) */
  function readExe(sectors) {
    const n = sectors.length / SECTOR, exe = new Uint8Array(n * 2048);
    for (let i = 0; i < n; i++) exe.set(sectors.subarray(i * SECTOR + 24, i * SECTOR + 24 + 2048), i * 2048);
    return exe;
  }

  /* last `drop` bytes of the image as (addr, len, data) segments (src/make_tail.py) */
  const GAP = 8;
  function makeTail(exe, drop) {
    const D = rd32(exe, 0x1C), tail = exe.subarray(0x800 + D - drop, 0x800 + D);
    const base = 0x80010000 + D - drop, out = [];
    const push32 = v => out.push(v & 0xFF, (v >>> 8) & 0xFF, (v >>> 16) & 0xFF, v >>> 24);
    let i = 0;
    const n = tail.length;
    while (i < n) {
      if (tail[i]) {
        let j = i, last = i;
        while (j < n && (tail[j] || j - last < GAP)) { if (tail[j]) last = j; j++; }
        const s0 = i & ~3, e0 = (last + 4) & ~3;
        push32(base + s0); push32(e0 - s0);
        for (let k = s0; k < e0; k++) out.push(tail[k]);
        i = e0;
      } else i++;
    }
    push32(0); push32(0);
    return Uint8Array.from(out);
  }

  /* exe: original executable of version vid (DATA.versions key);
     config: array of 0/1 per feature -> patched exe */
  function patchExe(vid, exe, config) {
    const D = root.RE1Patch.DATA, V = D.versions[vid];
    const pc0 = rd32(exe, 0x10), tAddr = rd32(exe, 0x18), tSize = rd32(exe, 0x1C);
    if (pc0 !== V.pc0 || tAddr !== D.origBase || tSize !== V.tSize) throw new Error('unexpected executable');
    const code = b64(V.code);
    const tail = makeTail(exe, D.block);
    if (code.length + tail.length > D.block) throw new Error('block too big');
    const out = new Uint8Array(exe.length);
    out.set(exe.subarray(0, 0x800));
    wr32(out, 0x10, D.base);                      /* pc0 */
    wr32(out, 0x18, D.base);                      /* t_addr */
    out.set(code, 0x800);
    out.set(tail, 0x800 + code.length);
    out.set(exe.subarray(0x800, 0x800 + tSize - D.block), 0x800 + D.block);
    if (V.code2) {                                /* options menu, in unreachable game code */
      const code2 = b64(V.code2);
      out.set(code2, 0x800 + V.code2Addr - D.base);
    }
    for (let i = 0; i < config.length; i++) out[0x800 + D.configOffset + i] = config[i] ? 1 : 0;
    for (const [site, orig, jal] of V.hooks) {
      const o = 0x800 + site - D.base;
      if (rd32(out, o) !== orig) throw new Error('unexpected code at 0x' + site.toString(16));
      wr32(out, o, jal);
    }
    return out;
  }

  /* version whose disc image has this size, or null */
  function versionForSize(size) {
    const vs = root.RE1Patch.DATA.versions;
    return Object.keys(vs).find(k => vs[k].binSizes.includes(size)) || null;
  }

  /* original raw sectors + patched exe -> patched raw sectors */
  function encodeSectors(sectors, exe) {
    const out = sectors.slice();
    const n = out.length / SECTOR;
    for (let i = 0; i < n; i++) {
      const s = out.subarray(i * SECTOR, (i + 1) * SECTOR);
      s.set(exe.subarray(i * 2048, (i + 1) * 2048), 24);
      encodeMode2Form1(s);
    }
    return out;
  }

  /* PPF 3.0 (BIN image, no block check, no undo), as src/make_ppf.py;
     a, b: original / patched bytes located at `offset` in the image */
  function makePPF(a, b, offset, desc) {
    const out = [];
    const head = 'PPF30';
    for (const ch of head) out.push(ch.charCodeAt(0));
    out.push(2);
    const d = (desc + ' '.repeat(50)).slice(0, 50);
    for (const ch of d) out.push(ch.charCodeAt(0) & 0x7F);
    out.push(0, 0, 0, 0);
    /* records never cross a 64-sector boundary of the image (make_ppf.py
       compares the images in such chunks): same output byte for byte */
    const CH = SECTOR * 64;
    let i = 0;
    while (i < a.length) {
      if (a[i] === b[i]) { i++; continue; }
      const n = Math.min(a.length, (Math.floor((offset + i) / CH) + 1) * CH - offset);
      let j = i;
      while (j < n && j - i < 255 && a[j] !== b[j]) j++;
      /* extend over short equal gaps to keep records few */
      while (j < n && j - i < 255) {
        let k = j;
        while (k < n && a[k] === b[k] && k - j < 8) k++;
        if (k < n && a[k] !== b[k] && k - i < 255) {
          j = k;
          while (j < n && j - i < 255 && a[j] !== b[j]) j++;
        } else break;
      }
      let off = offset + i;
      for (let k = 0; k < 8; k++) { out.push(off % 256); off = Math.floor(off / 256); }
      out.push(j - i);
      for (let k = i; k < j; k++) out.push(b[k]);
      i = j;
    }
    return Uint8Array.from(out);
  }

  function b64(s) {
    if (typeof atob === 'function') return Uint8Array.from(atob(s), c => c.charCodeAt(0));
    return new Uint8Array(Buffer.from(s, 'base64'));
  }

  root.RE1Patch = Object.assign(root.RE1Patch || {}, { SECTOR, crc32, readExe, makeTail, patchExe, versionForSize, encodeSectors, makePPF });
})(typeof window !== 'undefined' ? window : globalThis);
