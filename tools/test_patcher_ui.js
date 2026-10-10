// node tools/test_patcher_ui.js : runs the patcher page scripts on a tiny fake DOM
// with build/re1.bin as the chosen file, clicks "PPF" and checks the result.
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'patcher', 'RE1-Hotkeys-Patcher.html'), 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
const els = {}, saved = [];
function el(id) {
  return els[id] || (els[id] = { id, textContent: '', innerHTML: '', className: '', disabled: false, checked: true,
    listeners: {}, children: [], addEventListener(t, f) { this.listeners[t] = f; },
    appendChild(c) { this.children.push(c); }, querySelector() { return this.input || (this.input = el(this.id + '_in' + Math.random())); },
    click() { saved.push(this.download); }, remove() {} });
}
global.window = globalThis;
global.document = { getElementById: el, createElement: () => el('x' + Math.random()), body: el('body') };
global.localStorage = { getItem: () => null, setItem() {} };
global.URL = { createObjectURL: () => 'blob:', revokeObjectURL() {} };
const blobs = [];
global.Blob = class { constructor(parts) { this.parts = parts; blobs.push(this); } };
global.atob = s => Buffer.from(s, 'base64').toString('binary');
for (const s of scripts) new Function(s)();
const binPath = path.join(root, 'build', 're1.bin'), size = fs.statSync(binPath).size;
const file = { name: 're1.bin', size, slice(a, b) { return { arrayBuffer: async () => { const fd = fs.openSync(binPath, 'r'); const u = Buffer.alloc(b - a); fs.readSync(fd, u, 0, b - a, a); fs.closeSync(fd); return u.buffer.slice(u.byteOffset, u.byteOffset + u.length); } }; } };
(async () => {
  await els.file.listeners.change({ target: { files: [file] } });
  console.log('status:', els.status.innerHTML.replace(/<[^>]+>/g, ''), '| buttons enabled:', !els.dlBin.disabled && !els.dlPpf.disabled);
  els.dlPpf.listeners.click();
  const ppf = blobs[blobs.length - 1].parts[0];
  const ref = fs.readFileSync(path.join(root, 'patch', "Resident Evil - Director's Cut (France) [SLES_009.70].ppf"));
  console.log('saved:', saved, '| ppf identical:', Buffer.compare(Buffer.from(ppf), ref) === 0);
})();
