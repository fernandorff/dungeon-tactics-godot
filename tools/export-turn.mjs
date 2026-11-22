// Exports what the 3D turn list needs from the web game's own code (src/client/turn3d), so the port draws and lays out
// from the same numbers:
//   assets/ui/turn-paint.png   the cards' small painted texture (card.ts paintTexture, same seed);
//   assets/ui/turn-digits.png  the order numbers' digit atlas (card.ts digitTexture), drawn by its own canvas code in
//                              headless Chrome;
//   tests/golden/turn.json     queueLayout, statsLayout, statWidth, matchRows and repeats for a spread of inputs, which
//                              tests/turn_tests.gd replays against the GDScript ports.
// Run from the Godot repo: node tools/export-turn.mjs ../dungeon-tactics
import { readFileSync, writeFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const source = resolve(process.argv[2] ?? '../dungeon-tactics');
const web = (p) => import(pathToFileURL(join(source, p)).href);
const { openChrome } = await web('scripts/lib/browser.mjs');

// --- textures -----------------------------------------------------------------------------------------------------
const card = await web('src/client/turn3d/card.ts');
const paint = card.paintTexture().image;
const src = readFileSync(join(source, 'src/client/turn3d/card.ts'), 'utf8');
const digits = src.slice(src.indexOf('const DIGITS'), src.indexOf('  const tex = new Texture(canvas);'));
const chrome = await openChrome();
const page = await chrome.newPage();
const toPng = async (js) => Buffer.from((await page.evaluate(stripTypeScriptTypes(js))).split(',')[1], 'base64');
writeFileSync(resolve('assets/ui/turn-digits.png'), await toPng(`(() => {${digits.replace('export function digitTexture() {', '')}return canvas.toDataURL('image/png');})()`));
writeFileSync(
  resolve('assets/ui/turn-paint.png'),
  await toPng(`(() => { const d = ${JSON.stringify([...paint.data])}, cv = document.createElement('canvas');
  cv.width = cv.height = ${paint.width}; const g = cv.getContext('2d'); const im = g.createImageData(${paint.width}, ${paint.height});
  im.data.set(d); g.putImageData(im, 0, 0); return cv.toDataURL('image/png'); })()`),
);
await chrome.close();

// --- golden numbers -----------------------------------------------------------------------------------------------
const layout = await web('src/client/ui3d/layout.ts');
const { queueLayout } = await web('src/client/turn3d/queue-layout.ts');
const view = await web('src/client/turn3d/queue-view.ts');
const layouts = [];
for (const [w, h, coarse] of [[1280, 720], [1920, 1080], [2560, 1080], [1024, 768, true], [844, 390, true], [700, 1000]]) {
  layout.setPageFloor(w, h, !!coarse);
  const st = layout.stage(w, h, 'edges');
  const at = layout.place(layout.REGIONS.turn, st);
  for (const rows of [0, 1, 5, 12, 30])
    for (const [now, folded, stats] of [[true, false, 0], [false, false, 64], [false, true, 0]]) {
      const small = Array.from({ length: rows }, (_, i) => i > 6 && i % 2 === 0);
      for (const s of [st.s * 1.5, st.s * 1.5 * 0.65]) {
        const spec = { rows, now, s, at, pageH: h, sheet: 230 * st.s, stats, small, margin: 12, folded };
        layouts.push({ page: [w, h, !!coarse], spec, out: queueLayout(spec) });
      }
    }
}
const stats = [];
for (const [w, h, coarse] of [[1920, 1080], [1024, 768, true], [844, 390, true]]) {
  layout.setPageFloor(w, h, !!coarse);
  for (const s of [0.5, 0.9, 1, 1.5, 2.2])
    for (const n of [1, 3]) for (const hh of [30, 64, 96]) stats.push({ page: [w, h, !!coarse], h: hh, s, n, out: view.statsLayout(hh, s, n) });
}
const widths = [[[[60], [40, 50], [30, 70]], 1.5], [[[120], [40, 50]], 1], [[[20, 20]], 0.9], [[], 1]].map(([l, s]) => ({
  lines: l,
  s,
  out: view.statWidth(l, s, 3),
}));
const A = { unit: 'a' },
  B = { unit: 'b' },
  C = { unit: 'c', charge: 'fire' };
const matches = [
  [[A, B, A], [B, A, C], true],
  [[A, B, A], [A, B, A], false],
  [[A, B, C, A], [B, C, A, B], true],
  [[], [A], false],
].map(([p, n, passed]) => ({ prev: p, next: n, passed, out: view.matchRows(p, n, passed) }));
const repeats = [[A, B, A, C, B, C], []].map((rows) => ({ rows, out: view.repeats(rows) }));
writeFileSync(resolve('tests/golden/turn.json'), `${JSON.stringify({ layouts, stats, widths, matches, repeats })}\n`);
