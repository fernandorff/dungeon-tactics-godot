// Exports the 3D combat bar's numbers from the web game's own code (src/client/bar3d/bar-layout.ts and plates.ts) to
// tests/golden/bar.json, which tests/bar_tests.gd replays against the GDScript port (src/ui/hud/bar_layout.gd).
// Run from the Godot repo: node tools/export-bar.mjs ../dungeon-tactics
import { writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const source = resolve(process.argv[2] ?? '../dungeon-tactics');
const { sheetLayout, PLATE, hang } = await import(pathToFileURL(join(source, 'src/client/bar3d/bar-layout.ts')).href);
const sheets = [sheetLayout(false), sheetLayout(true)];
const hangs = [];
for (const sp of [...Object.values(PLATE).filter((v) => typeof v === 'object'), sheets[0].name, sheets[1].hpValue, sheets[0].tag])
  for (const w of [20, 140, 300, 900])
    for (const s of [0.6, 1, 1.333]) hangs.push({ sp, w, s, pad: 3, out: hang(sp, w, s, 3) });
writeFileSync(resolve('tests/golden/bar.json'), `${JSON.stringify({ sheets, plate: PLATE, hangs })}\n`);
