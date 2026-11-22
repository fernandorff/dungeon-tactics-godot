// Exports the 3D battle result's layout from the web game's own code (src/client/result3d/result-layout.ts) for a
// spread of pages and counts: tests/golden/result.json, which tests/result_tests.gd replays against ResultLayout.
// Run from the Godot repo: node tools/export-result.mjs ../dungeon-tactics
import { writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const source = resolve(process.argv[2] ?? '../dungeon-tactics');
const web = (p) => import(pathToFileURL(join(source, p)).href);
const layout = await web('src/client/ui3d/layout.ts');
const { resultLayout } = await web('src/client/result3d/result-layout.ts');
const pages = [[1920, 1080], [1280, 720], [2560, 1080], [1024, 768], [844, 390]];
const counts = [[3, 0, 1], [4, 5, 2], [0, 2, 1], [6, 0, 2], [2, 7, 1]];
const out = [];
for (const [w, h] of pages)
  for (const [heroes, spoils, actions] of counts)
    out.push({ w, h, heroes, spoils, actions, out: resultLayout(layout.stage(w, h, 'edges'), w, heroes, spoils, actions) });
writeFileSync(resolve('tests/golden/result.json'), `${JSON.stringify(out)}\n`);
console.log('layouts', out.length);
