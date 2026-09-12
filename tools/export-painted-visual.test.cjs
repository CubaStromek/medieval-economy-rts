'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {exportVisual} = require('./export-painted-visual.cjs');
const {convertTerrain} = require('./import-kam-terrain.cjs');

const DEFINITIONS = {Tiles: [
  {ID: 0, Walkable: true, CornersTerKinds: Array(4).fill('tkGrass')},
  {ID: 1, Walkable: true, CornersTerKinds: ['tkGrass', 'tkPaleGrass', 'tkStone', 'tkDirt']},
  {ID: 35, Walkable: true, CornersTerKinds: Array(4).fill('tkDirt')},
  {ID: 192, Walkable: false, Water: true, HasWater: true, CornersTerKinds: Array(4).fill('tkWater')},
  {ID: 105, Walkable: false, HasWater: true, CornersTerKinds: ['tkWater', 'tkDirt', 'tkWater', 'tkWater']},
  {ID: 8, Walkable: true, CornersTerKinds: Array(4).fill('tkMoss')},
  {ID: 215, Walkable: true, CornersTerKinds: Array(4).fill('tkCobbleStone')},
  {ID: 46, Walkable: true, CornersTerKinds: Array(4).fill('tkSnow')},
]};

function original(tiles = [], width = 3, height = 3) {
  const data = Buffer.alloc(8 + width * height * 23);
  data.writeInt32LE(width, 0);
  data.writeInt32LE(height, 4);
  for (let index = 0; index < width * height; index += 1) {
    const tile = tiles[index] || {};
    const offset = 8 + index * 23;
    data[offset] = tile.terrain || 0;
    data[offset + 2] = tile.height === undefined ? 20 + index : tile.height;
    data[offset + 3] = tile.rotation || 0;
    data[offset + 5] = 255;
  }
  return data;
}

test('visual sidecar preserves the importer baseline and raw vertex lattice', () => {
  const input = original();
  const before = Buffer.from(input);
  const baseline = convertTerrain(input, DEFINITIONS);
  const visual = exportVisual(input, DEFINITIONS);
  assert.equal(visual.format, 'painted-visual-terrain-v1');
  assert.equal(visual.source_sha256, baseline.source.sha256);
  assert.deepEqual(visual.size, [2, 2]);
  assert.deepEqual(visual.base_terrain, baseline.terrain);
  assert.deepEqual(visual.base_heights, baseline.heights);
  assert.deepEqual(visual.raw_heights, [[20, 21, 22], [23, 24, 25], [26, 27, 28]]);
  assert.deepEqual(input, before);
});

test('clockwise rotations preserve the TL TR BR BL corner convention', () => {
  const tiles = [0, 1, 2, 3].flatMap(rotation => [{terrain: 1, rotation}, {}, {}]);
  const visual = exportVisual(original(tiles, 3, 5), DEFINITIONS);
  assert.deepEqual(visual.corner_kinds.map(row => row[0]), ['GPRD', 'DGPR', 'RDGP', 'PRDG']);
});

test('water lighting follows the base Water flag, not HasWater or passability', () => {
  const visual = exportVisual(original([{terrain: 105}, {terrain: 192}]), DEFINITIONS);
  assert.equal(visual.water_vertices[0][0], false);
  assert.equal(visual.water_vertices[0][1], true);
  assert.equal(visual.base_terrain[0], 'ww');
});

test('height halo is one clamped vertex sample outside all four edges', () => {
  const visual = exportVisual(original(), DEFINITIONS);
  assert.equal(visual.raw_height_halo.length, 5);
  assert.equal(visual.raw_height_halo[0].length, 5);
  for (let y = 0; y < 5; y += 1) for (let x = 0; x < 5; x += 1) {
    assert.equal(visual.raw_height_halo[y][x], visual.raw_heights[Math.max(0, Math.min(2, y - 1))]
      [Math.max(0, Math.min(2, x - 1))]);
  }
});

test('full-map extra kinds have explicit approved art interpretations', () => {
  const visual = exportVisual(original([{terrain: 8}, {terrain: 215}]), DEFINITIONS);
  assert.deepEqual(visual.corner_kinds[0], ['MMMM', 'RRRR']);
});

test('unsupported art kinds and corrupt binary input fail explicitly', () => {
  assert.throws(() => exportVisual(original([{terrain: 46}]), DEFINITIONS), /unsupported visual kind tkSnow/);
  assert.throws(() => exportVisual(Buffer.alloc(4), DEFINITIONS), /truncated/);
});
