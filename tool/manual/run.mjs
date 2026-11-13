#!/usr/bin/env node
// Runs the manual's flows on the simulator and writes what they photographed.
//
//   node tool/manual/run.mjs --only 01-getting-started            # one chapter
//   node tool/manual/run.mjs --only 01-getting-started --grep sign-in
//   node tool/manual/run.mjs                                      # every chapter, in order
//
// The driver must be running first (README.md). Flows write (they sign up, post, apply),
// so point the app and MANUAL_API at a private stack, never a shared database.
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { runManual } from './kit.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const arg = (name) => {
  const i = argv.indexOf(name);
  return i > -1 ? argv[i + 1] : null;
};
const only = arg('--only');
const grep = arg('--grep');

const files = fs
  .readdirSync(path.join(HERE, 'flows'))
  .filter((f) => /^\d\d-.*\.mjs$/.test(f) && (!only || f === `${only}.mjs`))
  .sort();
if (!files.length) {
  console.error(only ? `No tool/manual/flows/${only}.mjs` : 'No flows yet.');
  process.exit(1);
}
let failed = [];
for (const f of files) {
  const manual = (await import(pathToFileURL(path.join(HERE, 'flows', f)).href)).default;
  const bad = await runManual(manual, { grep });
  failed = failed.concat(bad.map((id) => `${manual.id} / ${id}`));
}
if (failed.length) {
  console.error(`\n${failed.length} flow(s) failed:\n  ${failed.join('\n  ')}`);
  process.exit(1);
}
console.log('\nAll flows photographed.');
