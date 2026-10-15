// Renders every frame of design/project/MediSave Board.dc.html to design/frames/fNN.png.
// Usage: serve design/project on http://localhost:8765, then
//   NODE_PATH=$(npm root -g) node design/render-frames.js design/frames <vendor-dir>
// <vendor-dir> holds npm-packed react@18.3.1, react-dom@18.3.1, lucide@0.460.0, @babel/standalone@7.29.0 (extracted as <name>-<version>/package).
const { chromium } = require('playwright');
const fs = require('fs');
const V = process.argv[3];
const map = {
  'https://unpkg.com/react@18.3.1/umd/react.production.min.js': V+'/react-18.3.1/package/umd/react.production.min.js',
  'https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js': V+'/react-dom-18.3.1/package/umd/react-dom.production.min.js',
  'https://unpkg.com/lucide@0.460.0/dist/umd/lucide.min.js': V+'/lucide-0.460.0/package/dist/umd/lucide.min.js',
  'https://unpkg.com/@babel/standalone@7.29.0/babel.min.js': V+'/babel-standalone-7.29.0/package/babel.min.js',
};
(async () => {
  const out = process.argv[2];
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1600, height: 1200 }, deviceScaleFactor: 2 });
  await p.addInitScript({ path: map['https://unpkg.com/lucide@0.460.0/dist/umd/lucide.min.js'] });
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.route('**/*', r => {
    const u = r.request().url(); if(!u.startsWith('http://localhost')) 
    if (map[u]) return r.fulfill({ body: fs.readFileSync(map[u]), contentType: 'application/javascript' });
    if (u.startsWith('http://localhost')) return r.continue();
    if (/fonts\.(googleapis|gstatic)\.com/.test(u)) { const body=require('child_process').execFileSync('curl',['-sSL','-A','Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36',u]); return r.fulfill({body, contentType: u.includes('css2')?'text/css':'font/woff2'}); }
    return r.abort();
  });
  await p.goto('http://localhost:8765/' + encodeURI(process.argv[4] || 'MediSave Board.dc.html'), { waitUntil: 'load' });
  await p.waitForTimeout(8000);
  for (let i = 1; i <= 38; i++) {
    const el = await p.$('#f' + i);
    if (!el) { console.log('missing f' + i); continue; }
    await el.scrollIntoViewIfNeeded(); await p.waitForTimeout(400);
    const id = 'f'+String(i).padStart(2,'0');
    await el.screenshot({ path: `${out}/${id}.png` });
    // capture below-the-fold content of the tallest scroll container
    const h = await el.evaluateHandle(e => { let best=null, d=0; e.querySelectorAll('*').forEach(n => { const cs=getComputedStyle(n); if (/(auto|scroll)/.test(cs.overflowY) && n.scrollHeight-n.clientHeight>d) { d=n.scrollHeight-n.clientHeight; best=n; } }); return best; });
    const sc = h.asElement();
    if (sc) { let k=2; while (k<8) { const more = await sc.evaluate(n => { const before=n.scrollTop; n.scrollTop += n.clientHeight-80; return n.scrollTop>before; }); if (!more) break; await p.waitForTimeout(250); await el.screenshot({ path: `${out}/${id}-${k}.png` }); k++; } }
  }
  await b.close();
})();
