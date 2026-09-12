#!/usr/bin/env node
'use strict';

// Data-only companion to import-kam-terrain.cjs. No source pixels, texture
// masks, mission scripts, or object artwork are loaded or copied.
const fs = require('node:fs');
const path = require('node:path');
const {decodeMap, convertTerrain} = require('./import-kam-terrain.cjs');

// Art interpretations use the same eight approved V1 slots as the sandbox.
// Moss is a vegetated soil blend; the rare old cobblestone corners use our
// limestone. Unsupported source categories fail explicitly, never guess grass.
const MODERN_KINDS = Object.freeze({
  tkGrass: 'G', tkPaleGrass: 'P', tkGrassDirt: 'M', tkMoss: 'M',
  tkDirt: 'D', tkStone: 'R', tkGoldMount: 'R', tkIronMount: 'R',
  tkCobbleStone: 'R', tkCoal: 'C', tkGold: 'O', tkIron: 'O',
  tkWater: 'W', tkFastWater: 'W', tkGrassyWater: 'W', tkSwamp: 'W',
});

function insist(condition, message) {
  if (!condition) throw new Error(`Painted terrain: ${message}`);
}

function exportVisual(input, definitionsJson) {
  // The existing importer performs the binary/schema validation and produces
  // the authoritative gameplay baseline. Presentation does not redesign it.
  const baseline = convertTerrain(input, definitionsJson);
  const decoded = decodeMap(input);
  const definitions = new Map(definitionsJson.Tiles.map(entry => [entry.ID, entry]));
  const [vertexWidth, vertexHeight] = decoded.vertex_size;
  const width = vertexWidth - 1;
  const height = vertexHeight - 1;
  const cornerKinds = [];
  for (let y = 0; y < height; y += 1) {
    const row = [];
    for (let x = 0; x < width; x += 1) {
      const tile = decoded.tiles[y * vertexWidth + x];
      const base = definitions.get(tile.terrain);
      const kinds = tile.corner_owners.map((owner, corner) => owner === 0
        ? base.CornersTerKinds[(corner + 4 - tile.rotation) % 4]
        : tile.layers[owner - 1].kind);
      row.push(kinds.map(kind => {
        insist(Object.hasOwn(MODERN_KINDS, kind),
          `unsupported visual kind ${kind} at ${x},${y}; add an explicit art interpretation`);
        return MODERN_KINDS[kind];
      }).join(''));
    }
    cornerKinds.push(row);
  }
  const rawHeights = Array.from({length: vertexHeight}, (_, y) =>
    Array.from({length: vertexWidth}, (_, x) => decoded.tiles[y * vertexWidth + x].height));
  // KM_Terrain.UpdateLighting checks the vertex's base tile Water flag,
  // not cell passability, HasWater, the nearest shore, or a kind majority.
  const waterVertices = Array.from({length: vertexHeight}, (_, y) =>
    Array.from({length: vertexWidth}, (_, x) =>
      definitions.get(decoded.tiles[y * vertexWidth + x].terrain).Water === true));
  const rawHeightHalo = Array.from({length: vertexHeight + 2}, (_, y) =>
    Array.from({length: vertexWidth + 2}, (_, x) =>
      rawHeights[Math.max(0, Math.min(vertexHeight - 1, y - 1))]
        [Math.max(0, Math.min(vertexWidth - 1, x - 1))]));
  return {
    format: 'painted-visual-terrain-v1', size: [width, height],
    source_sha256: baseline.source.sha256, origin: [0, 0],
    height_scale: baseline.source.height_scale,
    corner_kinds: cornerKinds, raw_heights: rawHeights,
    raw_height_halo: rawHeightHalo, water_vertices: waterVertices,
    base_terrain: baseline.terrain, base_heights: baseline.heights,
  };
}

function cli(argv) {
  const allowed = new Set(['--map', '--tiles', '--out']);
  const args = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    insist(allowed.has(key) && typeof argv[index + 1] === 'string' && !argv[index + 1].startsWith('--'),
      'usage: --map MAP --tiles TILES_JSON --out OUTPUT');
    insist(args[key] === undefined, `duplicate argument ${key}`);
    args[key] = argv[index + 1];
  }
  for (const key of allowed) insist(args[key], `missing ${key}`);
  const mapPath = path.resolve(args['--map']);
  const tilesPath = path.resolve(args['--tiles']);
  const outPath = path.resolve(args['--out']);
  insist(outPath !== mapPath && outPath !== tilesPath, 'output must not overwrite an input');
  insist(fs.statSync(mapPath).size <= 16 * 1024 * 1024, 'map exceeds 16 MiB');
  insist(fs.statSync(tilesPath).size <= 8 * 1024 * 1024, 'tile definitions exceed 8 MiB');
  const result = exportVisual(fs.readFileSync(mapPath), JSON.parse(fs.readFileSync(tilesPath, 'utf8')));
  fs.writeFileSync(outPath, JSON.stringify(result) + '\n', {flag: 'wx'});
  process.stdout.write(JSON.stringify({output: outPath, size: result.size,
    source_sha256: result.source_sha256, format: result.format}) + '\n');
}

module.exports = {exportVisual, MODERN_KINDS};
if (require.main === module) {
  try { cli(process.argv.slice(2)); }
  catch (error) { process.stderr.write(String(error.message) + '\n'); process.exitCode = 1; }
}
