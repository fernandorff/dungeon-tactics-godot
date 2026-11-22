// Exports the 3D speech box's layout from the web game's own code (src/client/window3d/talk-layout.ts) for a spread of
// pages and boxes: tests/golden/talk.json, which tests/talk_tests.gd replays against TalkLayout. `lines` is a fixed
// count per case (the web measures the words typed so far).
// Run from the Godot repo: node tools/export-talk.mjs ../dungeon-tactics
import { writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const source = resolve(process.argv[2] ?? '../dungeon-tactics');
const { talkLayout } = await import(pathToFileURL(join(source, 'src/client/window3d/talk-layout.ts')).href);
const pages = [[1920, 1080], [1280, 720], [2560, 1080], [844, 390], [390, 844]];
const safes = [{ top: 0, right: 0, bottom: 0, left: 0 }, { top: 20, right: 44, bottom: 30, left: 44 }];
const out = [];
for (const [pageW, pageH] of pages)
  for (const safe of safes)
    for (const [dark, face, name, title, skip, n] of [[false, true, 80, 0, 40, 1], [false, true, 120, 200, 40, 5], [false, false, 0, 0, 40, 2], [true, false, 0, 0, 40, 6], [true, false, 0, 0, 40, 1]]) {
      const spec = { pageW, pageH, safe, dark, face, name, title, skip, n };
      out.push({ spec, out: talkLayout({ ...spec, lines: () => n }) });
    }
writeFileSync(resolve('tests/golden/talk.json'), `${JSON.stringify(out)}\n`);
console.log('layouts', out.length);
