// node tools/test_patcher_ui.js [version] : runs the patcher page scripts on a
// tiny fake DOM with build/<version>/orig.bin as the chosen file, switches the
// language, clicks "PPF" and checks the result against build/<version>/hotkeys.ppf
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..'), vid = process.argv[2] || 'us';
const html = fs.readFileSync(path.join(root, 'patcher', 'RE1-Hotkeys-Patcher.html'), 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
const els = {}, saved = [], all = [];
function el(id, data) {
  const e = { id, dataset: data || {}, textContent: '', innerHTML: '', className: '', disabled: false, checked: true,
    listeners: {}, attrs: {}, addEventListener(t, f) { this.listeners[t] = f; }, setAttribute(k, v) { this.attrs[k] = v; },
    appendChild() {}, querySelector() { return this.sub || (this.sub = el(this.id + '/sub')); },
    querySelectorAll() { return []; }, click() { saved.push(this.download); }, remove() {} };
  all.push(e);
  return e;
}
const get = id => els[id] || (els[id] = el(id));
const langButtons = [el('en', { lang: 'en' }), el('fr', { lang: 'fr' })];
const tagged = ['version', 's1', 's2', 's3', 'dlBin', 'dlPpf', 'note', 'footer'].map(t => el('t-' + t, { t }));
global.window = globalThis;
global.navigator = { language: 'fr-FR' };
global.document = {
  documentElement: {}, body: el('body'), getElementById: get, createElement: () => el('x'),
  querySelectorAll: sel => sel === '[data-lang]' ? langButtons : sel === '[data-t]' ? tagged : [],
};
global.localStorage = { getItem: () => null, setItem() {} };
global.URL = { createObjectURL: () => 'blob:', revokeObjectURL() {} };
const blobs = [];
global.Blob = class { constructor(parts) { this.parts = parts; blobs.push(this); } };
global.atob = s => Buffer.from(s, 'base64').toString('binary');
for (const s of scripts) new Function(s)();
console.log('lang fr:', tagged[1].innerHTML, '|', get('versions').textContent);
langButtons[0].listeners.click();
console.log('lang en:', tagged[1].innerHTML);
const binPath = path.join(root, 'build', vid, 'orig.bin'), size = fs.statSync(binPath).size;
const file = { name: 'game.bin', size, slice(a, b) { return { arrayBuffer: async () => { const fd = fs.openSync(binPath, 'r'); const u = Buffer.alloc(b - a); fs.readSync(fd, u, 0, b - a, a); fs.closeSync(fd); return u.buffer.slice(u.byteOffset, u.byteOffset + u.length); } }; } };
(async () => {
  await get('file').listeners.change({ target: { files: [file] } });
  console.log('status:', get('status').innerHTML.replace(/<[^>]+>/g, ''), '| enabled:', !get('dlBin').disabled);
  get('dlPpf').listeners.click();
  const ppf = blobs[blobs.length - 1].parts[0];
  const ref = fs.readFileSync(path.join(root, 'build', vid, 'hotkeys.ppf'));
  console.log('saved:', saved, '| ppf identical:', Buffer.compare(Buffer.from(ppf), ref) === 0);
})();
