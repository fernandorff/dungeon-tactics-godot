// Copies the web game's character models into assets/models without meshopt compression and quantization, which Godot's
// glTF importer does not read: same meshes, bones, clips and textures, only stored plainly.
// Run from the web repo, whose node_modules has gltf-transform:
//   node ../dgt-godot-visual/tools/unpack-models.mjs public/models ../dgt-godot-visual/assets/models
import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const [src, out] = process.argv.slice(2);
// the packages live in the web repo, the folder this runs from
const need = createRequire(join(process.cwd(), 'package.json'));
const load = async (name) => import(pathToFileURL(need.resolve(name)).href);
const { NodeIO } = await load('@gltf-transform/core');
const { ALL_EXTENSIONS } = await load('@gltf-transform/extensions');
const { dequantize } = await load('@gltf-transform/functions');
const { MeshoptDecoder } = await load('meshoptimizer');

await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.decoder': MeshoptDecoder });
for (const f of readdirSync(src).filter((f) => f.endsWith('.glb'))) {
  const doc = await io.read(join(src, f));
  await doc.transform(dequantize());
  for (const e of doc.getRoot().listExtensionsUsed())
    if (e.extensionName === 'EXT_meshopt_compression' || e.extensionName === 'KHR_mesh_quantization') e.dispose();
  await io.write(join(out, f), doc);
  console.log('unpacked', f);
}
