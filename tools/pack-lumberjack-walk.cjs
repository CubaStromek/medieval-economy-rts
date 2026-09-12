#!/usr/bin/env node
'use strict';
// Mechanical animation assembly only. All artwork is preserved in source sheets.
// No background removal, retouching, optical-flow invention, or mirrored limbs.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const dir = path.join(root, 'docs/art/animations/lumberjack-without-log-v1');
const config = JSON.parse(fs.readFileSync(path.join(dir, 'registration.json'), 'utf8'));
const output = path.join(dir, 'frames');
fs.mkdirSync(output, { recursive: true });
fs.mkdirSync(path.join(dir, 'previews'), { recursive: true });
function run(args) {
  const result = spawnSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(result.stderr || result.error || 'ffmpeg failed');
}
function metadata(file) {
  const b = fs.readFileSync(file);
  if (b.toString('hex', 0, 8) !== '89504e470d0a1a0a') throw new Error('Expected PNG: ' + file);
  return { width: b.readUInt32BE(16), height: b.readUInt32BE(20), pngColorType: b[25],
    sha256: crypto.createHash('sha256').update(b).digest('hex') };
}
const manifest = { date: '2026-09-09', fps: 10, frameCount: 8, cellSize: [384, 512],
  previewScale: 0.72, stage: 'animation-review', productionReady: false, alpha: false,
  notes: ['Bílé pozadí je neprůhledné. Produkční alfa ještě není připravená.',
    'Jde o první pohybovou studii; délka kroku, přesná registrace a pohyb vybavení vyžadují další doladění.'], directions: [] };
const evidence = [];
for (const entry of config.directions) {
  const sourceFrames = entry.frames;
  if (sourceFrames.length !== 8) throw new Error(entry.id + ': expected eight frames');
  const frameDir = path.join(output, entry.id);
  fs.mkdirSync(frameDir, { recursive: true });
  sourceFrames.forEach((f, index) => {
    const input = path.join(dir, f.sheet), info = metadata(input);
    const [x, y, w, h] = f.rect, [ax, ay] = f.anchor, s = f.scale;
    if (![x, y, w, h].every(Number.isInteger) || x < 0 || y < 0 || x + w > info.width || y + h > info.height)
      throw new Error(entry.id + ': crop exceeds source');
    const dw = Math.round(w * s), dh = Math.round(h * s);
    const dx = Math.round(192 - ax * dw / w), dy = Math.round(460 - ay * dh / h);
    if (dx < 0 || dy < 0 || dx + dw > 384 || dy + dh > 512)
      throw new Error(entry.id + ': registered frame exceeds canvas ' + index + ' ' + [dx, dy, dw, dh]);
    const target = path.join(frameDir, String(index).padStart(2, '0') + '.png');
    run(['-i', input, '-vf', `crop=${w}:${h}:${x}:${y},scale=${dw}:${dh}:flags=lanczos,pad=384:512:${dx}:${dy}:color=white,format=rgb24`, '-frames:v', '1', target]);
    evidence.push({ direction: entry.id, frame: index, source: f.sheet, sourceMetadata: info,
      sourceRect: f.rect, sourceAnchor: f.anchor, sourceScale: s,
      output: path.relative(dir, target), outputMetadata: metadata(target) });
  });
  const sheet = 'sheets/' + entry.id + '-walk.png';
  run(['-framerate', '10', '-i', path.join(frameDir, '%02d.png'), '-vf', 'tile=4x2:nb_frames=8:padding=0:margin=0', '-frames:v', '1', path.join(dir, sheet)]);
  run(['-framerate', '10', '-i', path.join(frameDir, '%02d.png'), '-filter_complex', '[0:v]scale=288:384:flags=lanczos,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a', '-loop', '0', path.join(dir, 'previews', entry.id + '.gif')]);
  manifest.directions.push({ id: entry.id, sheet, displayScale: 1, frames: sourceFrames.map((_, i) => ({ rect: [(i % 4) * 384, Math.floor(i / 4) * 512, 384, 512], anchor: [192, 460] })) });
}
fs.writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
fs.writeFileSync(path.join(dir, 'manifest.js'), 'window.WALK_MANIFEST = ' + JSON.stringify(manifest, null, 2) + ';\n');
fs.writeFileSync(path.join(dir, 'assembly-report.json'), JSON.stringify({ date: manifest.date, method: 'FFmpeg crop, fixed source scale, explicit source registration, RGB canvas, atlas/GIF packing', frames: evidence }, null, 2) + '\n');
console.log('Assembled ' + manifest.directions.length + ' directions; ' + evidence.length + ' frames.');
