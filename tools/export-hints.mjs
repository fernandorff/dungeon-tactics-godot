// Exports what the 3D banner, Height corner and key hints need from the web game's own code (src/client/hints3d and
// glyph-art.ts), so the port draws and lays out from the same numbers:
//   assets/ui/caps/<key>.png  each keyboard cap the port's hints show, drawn by glyph-art.ts' own drawKey in headless
//                             Chrome at 84 px tall (three times the 28 px row, so it stays sharp up to a dpr of 3);
//   tests/golden/hints.json   layRow and heightBox for a spread of pages, which tests/hints_tests.gd replays against
//                             the GDScript port (HintsLayout).
// Run from the Godot repo: node tools/export-hints.mjs ../dungeon-tactics
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const source = resolve(process.argv[2] ?? '../dungeon-tactics');
const web = (p) => import(pathToFileURL(join(source, p)).href);
const { openChrome } = await web('scripts/lib/browser.mjs');

// --- caps ---------------------------------------------------------------------------------------------------------
const KEYS = ['Enter', 'Esc', 'Q', 'E', 'I', 'P'];
const H = 84;
const art = readFileSync(join(source, 'src/client/glyph-art.json'), 'utf8');
const src = readFileSync(join(source, 'src/client/glyph-art.ts'), 'utf8');
const cut = (from, to) => src.slice(src.indexOf(from), src.indexOf(to, src.indexOf(from)));
const code = [cut('const grad', '// A raised piece'), cut('function word', 'function drawKey'), cut('function drawKey', '// the four symbols')].join('\n');
const font = '"Palatino Linotype", Palatino, "Book Antiqua", Georgia, serif, system-ui, sans-serif';
const chrome = await openChrome();
const page = await chrome.newPage();
mkdirSync(resolve('assets/ui/caps'), { recursive: true });
for (const key of KEYS) {
  // capCanvas' own sizing: the letters' width plus a pad each side, never narrower than square
  const js = `(() => { const ART = ${art}; ${code}
    const cv = document.createElement('canvas'), g = cv.getContext('2d'), h = ${H}, fonts = ${JSON.stringify(font)};
    g.font = '700 ' + ART.key.text * h + 'px ' + fonts;
    cv.width = Math.ceil(Math.max(1, g.measureText(${JSON.stringify(key)}).width / h + 2 * ART.key.pad) * h);
    cv.height = h;
    drawKey(g, { key: ${JSON.stringify(key)} }, cv.width, h, fonts);
    return cv.toDataURL('image/png'); })()`;
  const url = await page.evaluate(stripTypeScriptTypes(js));
  writeFileSync(resolve(`assets/ui/caps/${key.toLowerCase()}.png`), Buffer.from(url.split(',')[1], 'base64'));
}
await chrome.close();

// --- layouts ------------------------------------------------------------------------------------------------------
const layout = await web('src/client/ui3d/layout.ts');
const view = await web('src/client/hints3d/hints-view.ts');
const pages = [[1920, 1080], [1280, 720], [2560, 1080], [1024, 768], [844, 390]];
const rows = [
  [{ caps: [60], text: 90 }, { caps: [40], text: 70 }, { caps: [30, 30], text: 80 }],
  [{ caps: [30], text: 120 }],
  [{ caps: [40, 40, 40, 40], text: 300 }, { caps: [60], text: 260 }, { caps: [40], text: 200 }],
];
const out = { heights: [], rows: [] };
for (const [w, h] of pages) {
  const st = layout.stage(w, h, 'edges');
  out.heights.push({ w, h, top: 12, box: view.heightBox(st, 12) });
  for (const align of ['left', 'right']) {
    const box = layout.place(layout.REGIONS[align === 'right' ? 'hints' : 'hintsLeft'], st);
    for (const sizes of rows) out.rows.push({ sizes, box, align, s: st.s, xs: view.layRow(sizes, box, align, st.s) });
  }
}
out.messageScale = pages.map(([w, h]) => view.messageScale(w, h));
writeFileSync(resolve('tests/golden/hints.json'), `${JSON.stringify(out)}\n`);
console.log('caps', KEYS.length, 'heights', out.heights.length, 'rows', out.rows.length);
