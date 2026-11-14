#!/usr/bin/env node
// A contact sheet: several pictures side by side, for checking a run at a glance.
//   node tool/manual/sheet.mjs <out.jpg> <a.jpg> <b.jpg> …   (or a directory of pictures)
import * as fs from 'node:fs';
import * as path from 'node:path';
import sharp from 'sharp';

const [out, ...rest] = process.argv.slice(2);
const files = rest.filter((f) => fs.existsSync(f)).flatMap((f) =>
  fs.statSync(f).isDirectory()
    ? // A flow's folder gives its pictures; a chapter's folder gives what its failed flows left on screen.
      fs.readdirSync(f).filter((n) => /^[^.].*\.jpe?g$|^\..*-failed\.jpg$/.test(n)).sort().map((n) => path.join(f, n))
    : [f],
);
if (!files.length) {
  console.log('nothing to show');
  process.exit(0);
}
const W = Number(process.env.SHEET_W ?? 380);
const tiles = await Promise.all(files.map((f) => sharp(f).resize({ width: W }).toBuffer({ resolveWithObject: true })));
const H = Math.max(...tiles.map((t) => t.info.height));
const gap = 12;
await sharp({ create: { width: tiles.length * (W + gap) + gap, height: H + 2 * gap, channels: 3, background: '#8a94a3' } })
  .composite(tiles.map((t, i) => ({ input: t.data, left: gap + i * (W + gap), top: gap })))
  .jpeg({ quality: 80 })
  .toFile(out);
console.log(out);
