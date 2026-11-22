// Exports what the 3D command menu needs from the web game's own code (src/client/menu3d, src/client/ui3d), so the port
// draws and moves from the same numbers instead of a copy by eye:
//   assets/ui/menu-models.glb  the low-poly models of menu3d/models.ts, with their part colours (sRGB bytes) in COLOR_0;
//   assets/ui/menu-paint.png   the panels' painted detail (ui3d/panel.ts paintTexture), drawn by its own canvas code in
//                              headless Chrome;
//   tests/golden/menu.json     menuLayout, cornerLayout, textPx, stepSpring and pageStep for a spread of inputs, which
//                              tests/menu_tests.gd replays against the GDScript ports.
// Run from the Godot repo: node tools/export-menu.mjs ../dungeon-tactics
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire, stripTypeScriptTypes } from 'node:module';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const source = resolve(process.argv[2] ?? '../dungeon-tactics');
const web = (p) => import(pathToFileURL(join(source, p)).href);
const requireWeb = createRequire(join(source, 'package.json'));

// --- models -------------------------------------------------------------------------------------------------------
const { Document, NodeIO } = await import(pathToFileURL(requireWeb.resolve('@gltf-transform/core')).href);
const { takeModel } = await web('src/client/menu3d/models.ts');
const doc = new Document();
const buffer = doc.createBuffer();
const scene = doc.createScene('MenuModels');
const material = doc.createMaterial().setMetallicFactor(0).setRoughnessFactor(1);
const names = ['boot', 'sword', 'hourglass', 'scroll', 'shield', 'axe', 'bow', 'dagger', 'potion', 'disc', 'tile', 'gem', 'glove'];
for (const element of ['none', 'fire', 'ice', 'lightning', 'shadow', 'wind', 'light']) names.push(`flame_${element}`);
for (const name of names) {
  const [kind, element] = name.split('_');
  const g = takeModel(kind, element);
  const primitive = doc.createPrimitive().setMaterial(material);
  for (const [attribute, semantic] of [['position', 'POSITION'], ['normal', 'NORMAL'], ['tint', 'COLOR_0']]) {
    const array = g.getAttribute(attribute).array;
    primitive.setAttribute(semantic, doc.createAccessor().setBuffer(buffer).setType('VEC3').setArray(array));
  }
  scene.addChild(doc.createNode(name).setMesh(doc.createMesh(name).addPrimitive(primitive)));
}
await new NodeIO().write(resolve('assets/ui/menu-models.glb'), doc);

// --- paint texture ------------------------------------------------------------------------------------------------
// the body of paintTexture up to the CanvasTexture, run as it is in a page: the canvas draws it, not a port of it
const panel = readFileSync(join(source, 'src/client/ui3d/panel.ts'), 'utf8');
const body = panel.slice(panel.indexOf('export function paintTexture'), panel.indexOf('const tex = new CanvasTexture(cv)'));
const js = `${body.replace(/^export function paintTexture\(\): CanvasTexture \{/, '')}return cv.toDataURL('image/png');`;
const { openChrome } = await import(pathToFileURL(join(source, 'scripts/lib/browser.mjs')).href);
const chrome = await openChrome();
const page = await chrome.newPage();
const png = await page.evaluate(stripTypeScriptTypes(`(() => {${js}})()`));
await chrome.close();
writeFileSync(resolve('assets/ui/menu-paint.png'), Buffer.from(png.split(',')[1], 'base64'));

// --- golden numbers -----------------------------------------------------------------------------------------------
const layout = await web('src/client/ui3d/layout.ts');
const menu = await web('src/client/menu3d/menu-layout.ts');
const spring = await web('src/client/ui3d/spring.ts');
const pages = [
  [1280, 720],
  [1920, 1080],
  [2560, 1080],
  [1024, 768],
  [844, 390],
  [250, 700],
];
const layouts = [];
for (const [w, h] of pages)
  for (const mode of ['edges', 'frame'])
    for (const [rows, subRows] of [[4, 0], [5, 7], [2, 3]])
      for (const touch of [false, true]) {
        const st = layout.stage(w, h, mode);
        layouts.push({ st, rows, subRows, touch, at: menu.menuLayout(st, rows, subRows, touch) });
        const bar = layout.place(layout.REGIONS.bar, st);
        layouts.push({ st, rows, subRows, touch, corner: bar.y + bar.h, at: menu.menuLayout(st, rows, subRows, touch, bar.y + bar.h) });
      }
const texts = [];
for (const [w, h, coarse] of [[1280, 720, false], [1024, 768, true], [844, 390, true], [1920, 1080, false]]) {
  layout.setPageFloor(w, h, coarse);
  for (const s of [1 / 3, 0.5, 0.6, 2 / 3, 1]) for (const size of [18, 20, 24, 30]) texts.push({ w, h, coarse, s, size, px: layout.textPx(size, s) });
}
// a spring stepped by uneven frames, one of them longer than the 0.1 s cap
const frames = [1 / 60, 1 / 60, 0.05, 1 / 144, 0.3, 1 / 30, 1 / 60, 1 / 60];
const springs = [];
for (const [k, c] of [[300, 19], [420, 30], [330, 25], [190, 21], [210, 21], [300, 30]]) {
  const sp = spring.spring(0);
  sp.to = 1;
  springs.push({ k, c, frames, trace: frames.map((dt) => (spring.stepSpring(sp, dt, k, c), [sp.x, sp.v])) });
}
const steps = [];
for (const count of [1, 2, 3, 4]) for (let from = 0; from < count; from++) for (let to = 0; to < count; to++) steps.push([from, to, count, spring.pageStep(from, to, count)]);
const golden = { ref: menu.REF, lead: menu.LEAD, layouts, texts, springs, steps };
writeFileSync(resolve('tests/golden/menu.json'), `${JSON.stringify(golden)}\n`);
console.log(`models ${names.length}, layouts ${layouts.length}, texts ${texts.length}, springs ${springs.length}, steps ${steps.length}`);
