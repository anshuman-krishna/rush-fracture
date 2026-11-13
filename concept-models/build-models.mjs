// Builds model GLBs straight from the builder modules, no browser needed.
//
//   npm install
//   node build-models.mjs            build only models that have no .glb yet
//   node build-models.mjs --all      rebuild every model
//   node build-models.mjs titan core rebuild the named models
//
// Output: ../game-client/assets/models/grafted-brood-<key>.glb

import { mkdir, writeFile, access } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { buildEntity, ENTITIES } from './bio-lane-models.js';
import './bio-lane-models-ext.js';

// GLTFExporter's binary path reads Blobs through FileReader, which Node lacks.
if (typeof globalThis.FileReader === 'undefined') {
  globalThis.FileReader = class {
    readAsArrayBuffer(blob) {
      blob.arrayBuffer().then((buf) => { this.result = buf; if (this.onloadend) this.onloadend(); });
    }
    readAsDataURL(blob) {
      blob.arrayBuffer().then((buf) => {
        this.result = `data:${blob.type || 'application/octet-stream'};base64,${Buffer.from(buf).toString('base64')}`;
        if (this.onloadend) this.onloadend();
      });
    }
  };
}

const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.resolve(here, '../game-client/assets/models');
const args = process.argv.slice(2);
const all = args.includes('--all');
const named = args.filter((a) => !a.startsWith('--'));

const exists = (p) => access(p).then(() => true, () => false);

await mkdir(outDir, { recursive: true });
const exporter = new GLTFExporter();
let built = 0;

for (const key of ENTITIES) {
  const file = path.join(outDir, `grafted-brood-${key}.glb`);
  if (named.length ? !named.includes(key) : (!all && await exists(file))) continue;
  const model = buildEntity(THREE, key);
  const buf = await exporter.parseAsync(model, { binary: true });
  await writeFile(file, Buffer.from(buf));
  built++;
  console.log(`${key.padEnd(16)} ${String(model.userData.meshes).padStart(4)} meshes  size ${model.userData.size.join(' x ')}  ${(buf.byteLength / 1024).toFixed(0)} kB`);
}
for (const key of named) if (!ENTITIES.includes(key)) console.error(`unknown model: ${key}`);
console.log(built ? `built ${built} model(s) into ${outDir}` : 'nothing to build (use --all to rebuild)');
