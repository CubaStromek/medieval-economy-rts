'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const {decodeMap, convertTerrain} = require('./import-kam-terrain.cjs');

const kinds = (kind) => [kind, kind, kind, kind];
const DEFINITIONS = {Tiles: [
  {ID: 0, Walkable: true, Soil: true, CornersTerKinds: kinds('tkGrass')},
  {ID: 35, Walkable: true, Soil: true, CornersTerKinds: kinds('tkDirt')},
  {ID: 192, Walkable: false, Water: true, HasWater: true, CornersTerKinds: kinds('tkWater')},
  {ID: 159, Walkable: false, CornersTerKinds: kinds('tkGoldMount')},
  {ID: 245, Walkable: false, CornersTerKinds: kinds('tkAbyss')},
  {ID: 106, Walkable: true, HasWater: true,
    CornersTerKinds: ['tkDirt', 'tkDirt', 'tkWater', 'tkWater']},
]};

// Independent explicit fixture writer. Records are assembled before header
// sizing; these helpers never use the production decoder or converter.
function modern({width = 3, height = 3, revision = 'r11222', tiles = [], footer = Buffer.alloc(0)} = {}) {
  const records = [];
  for (let index = 0; index < width * height; index += 1) {
    const tile = tiles[index] || {};
    const layers = tile.layers || [];
    const record = Buffer.alloc(9 + (layers.length ? 2 + 3 * layers.length : 0));
    record.writeUInt16LE(tile.terrain || 0, 0);
    record[2] = tile.rotation || 0;
    record[3] = tile.height === undefined ? 20 : tile.height;
    record.writeUInt16LE(tile.object === undefined ? 255 : tile.object, 4);
    record[6] = tile.custom || 0;
    record[7] = tile.overlay || 0;
    record[8] = layers.length;
    if (layers.length) {
      record[9] = tile.owners || 0;
      record[10] = 4;
      layers.forEach((kind, layer) => {
        record.writeUInt16LE(kind << 10, 11 + layer * 3);
        record[13 + layer * 3] = layer;
      });
    }
    records.push(record);
  }
  const label = Buffer.from(revision, 'utf16le');
  const header = Buffer.alloc(4 + 2 + label.length + 12);
  header.writeUInt16LE(revision.length, 4);
  label.copy(header, 6);
  header.writeUInt32LE(records.reduce((total, record) => total + record.length, 0), 6 + label.length);
  header.writeInt32LE(width, 10 + label.length);
  header.writeInt32LE(height, 14 + label.length);
  return Buffer.concat([header, ...records, footer]);
}

function original() {
  const data = Buffer.alloc(8 + 3 * 2 * 23);
  data.writeInt32LE(3, 0);
  data.writeInt32LE(2, 4);
  for (let i = 0; i < 6; i += 1) {
    const offset = 8 + i * 23;
    data[offset] = i;
    data[offset + 1] = 240;
    data[offset + 2] = 10 + i;
    data[offset + 3] = 7;
    data[offset + 4] = 241;
    data[offset + 5] = i === 0 ? 90 : 255;
    data.fill(199, offset + 6, offset + 23);
  }
  return data;
}

test('modern header and row-major records decode without a fake border', () => {
  const decoded = decodeMap(modern({tiles: [{terrain: 35, height: 24, object: 90, rotation: 7}]}));
  assert.equal(decoded.revision, 11222);
  assert.deepEqual(decoded.vertex_size, [3, 3]);
  assert.equal(decoded.tiles.length, 9);
  assert.equal(decoded.payload_bytes, 81);
  assert.equal(decoded.tiles[0].terrain, 35);
  assert.equal(decoded.tiles[0].rotation, 3);
  assert.equal(decoded.tiles[0].height, 24);
  assert.equal(decoded.tiles[0].object, 90);
});

test('original format uses fixed 23-byte stride and designated offsets', () => {
  const decoded = decodeMap(original());
  assert.deepEqual(decoded.vertex_size, [3, 2]);
  assert.equal(decoded.revision, 0);
  assert.deepEqual(decoded.tiles.map(tile => tile.terrain), [0, 1, 2, 3, 4, 5]);
  assert.deepEqual(decoded.tiles.map(tile => tile.height), [10, 11, 12, 13, 14, 15]);
  assert.ok(decoded.tiles.every(tile => tile.rotation === 3 && tile.layers.length === 0));
  assert.equal(decoded.tiles[0].object, 90);
  assert.equal(decoded.payload_bytes, 138);
});

test('bounded trailing editor data is ignored, not parsed or executed', () => {
  const footer = Buffer.from('ADDNTILE arbitrary .script text is inert');
  const decoded = decodeMap(modern({footer}));
  assert.equal(decoded.trailing_bytes, footer.length);
  assert.equal(decoded.tiles.length, 9);
  assert.equal(decodeMap(Buffer.concat([original(), footer])).trailing_bytes, footer.length);
});

test('every truncated header/payload prefix fails closed', () => {
  const complete = modern({tiles: [{layers: [27], owners: 85}]});
  for (let bytes = 0; bytes < complete.length; bytes += 1)
    assert.throws(() => decodeMap(complete.subarray(0, bytes)), /KaM terrain:/);
  assert.throws(() => decodeMap(original().subarray(0, -1)), /truncated/);
});

test('invalid dimensions, oversized inputs and unsupported formats are rejected', () => {
  for (const dimension of [-1, 0, 1, 257, 2147483647]) {
    const bytes = modern();
    bytes.writeInt32LE(dimension, 22);
    assert.throws(() => decodeMap(bytes), /dimensions/);
  }
  assert.throws(() => decodeMap(Buffer.alloc(16 * 1024 * 1024 + 1)), /16 MiB/);
  assert.throws(() => decodeMap('not bytes'), /binary data/);
});

test('unknown modern revisions are rejected rather than guessed', () => {
  for (const revision of ['r10968', 'r11223', 'r99999', 'x11222', 'r00000'])
    assert.throws(() => decodeMap(modern({revision})), /revision/);
  assert.equal(decodeMap(modern({revision: 'r10969'})).revision, 10969);
  const bytes = modern();
  bytes.writeUInt16LE(1000, 4);
  assert.throws(() => decodeMap(bytes), /revision string length/);
});

test('declared payload length must match both available and consumed bytes', () => {
  for (const size of [80, 82, 9999999]) {
    const bytes = modern({footer: Buffer.alloc(5)});
    bytes.writeUInt32LE(size, 18);
    assert.throws(() => decodeMap(bytes), /payload/);
  }
});

test('corrupt custom flags, overlays, object IDs and layer counts are rejected', () => {
  for (const [offset, value, expected] of [[36, 2, /custom/], [37, 6, /overlay/],
    [35, 1, /object/], [38, 4, /layers/]]) {
    const bytes = modern();
    bytes[offset] = value;
    assert.throws(() => decodeMap(bytes), expected);
  }
});

test('layer corner ownership and generated terrain kinds are checked', () => {
  assert.throws(() => decodeMap(modern({tiles: [{layers: [27], owners: 2}]})), /corner owner/);
  assert.throws(() => decodeMap(modern({tiles: [{layers: [63], owners: 1}]})), /terrain kind/);
  const decoded = decodeMap(modern({tiles: [{layers: [27, 10], owners: 0b10010001}]}));
  assert.deepEqual(decoded.tiles[0].corner_owners, [1, 0, 1, 2]);
  assert.deepEqual(decoded.tiles[0].layers.map(layer => layer.kind), ['tkWater', 'tkDirt']);
});

test('conversion preserves orientation and all boundary heights', () => {
  const tiles = Array.from({length: 9}, (_, index) => ({height: 10 + index * 10}));
  tiles[0].terrain = 35;
  tiles[1].terrain = 192;
  tiles[3].terrain = 159;
  const data = convertTerrain(modern({tiles}), DEFINITIONS, {name: 'Fixture'});
  assert.deepEqual(data.map_size, [2, 2]);
  assert.deepEqual(data.heights, [[0, 2, 3], [5, 6, 8], [9, 11, 12]]);
  assert.deepEqual(data.terrain, ['dw', 'rg']);
  assert.equal(data.source.height_offset, 10);
  assert.deepEqual(data.source.vertex_size, [3, 3]);
  assert.equal(data.report.playable_cells, 4);
});

test('conversion is deterministic and does not mutate input bytes or definitions', () => {
  const bytes = modern();
  const beforeBytes = Buffer.from(bytes);
  const beforeDefinitions = JSON.stringify(DEFINITIONS);
  const options = {name: 'Fixture', url: 'https://example.com/reference.map'};
  const first = convertTerrain(bytes, DEFINITIONS, options);
  assert.deepEqual(convertTerrain(bytes, DEFINITIONS, options), first);
  assert.deepEqual(bytes, beforeBytes);
  assert.equal(JSON.stringify(DEFINITIONS), beforeDefinitions);
  assert.equal(first.source.sha256, crypto.createHash('sha256').update(bytes).digest('hex'));
});

test('walkable shoreline remains dirt instead of blocking the source crossing', () => {
  const output = convertTerrain(modern({tiles: [{terrain: 106}]}), DEFINITIONS);
  assert.equal(output.terrain[0][0], 'd');
  assert.equal(output.report.walkable_shore_cells, 1);
});

test('layered walkability follows owned corners and the source base tie rule', () => {
  // Two grass-owned corners + two water corners stay walkable when base is grass.
  const grassBase = convertTerrain(modern({tiles: [{layers: [27], owners: 0b01010000}]}), DEFINITIONS);
  assert.equal(grassBase.terrain[0][0], 'g');
  // The same two-and-two tie with a water base remains impassable.
  const waterBase = convertTerrain(modern({tiles: [{terrain: 192, layers: [1], owners: 0b01010000}]}), DEFINITIONS);
  assert.equal(waterBase.terrain[0][0], 'w');
  // Three grass corners on water are enough to restore land.
  const threeGrass = convertTerrain(modern({tiles: [{terrain: 192, layers: [1], owners: 0b01010100}]}), DEFINITIONS);
  assert.equal(threeGrass.terrain[0][0], 'g');
  const abyss = convertTerrain(modern({tiles: [{layers: [22], owners: 1}]}), DEFINITIONS);
  assert.equal(abyss.terrain[0][0], 'r');
});

test('living tree ages map to our three stages; falling trees and stumps are omitted', () => {
  const objects = [88, 89, 90, 91, 37, 255, 95, 100, 255];
  const output = convertTerrain(modern({width: 4, height: 3,
    tiles: objects.map(object => ({object}))}), DEFINITIONS);
  assert.deepEqual(output.trees.slice(0, 3), [[0, 0, 0], [1, 0, 1], [2, 0, 2]]);
  assert.equal(output.report.omitted_other_objects, 1); // stump; falling tree on the border
  assert.equal(output.report.source_living_trees, 5);
  assert.equal(output.report.omitted_trees.border, 1);
});

test('trees on unplayable final row/column are reported, not shifted inward', () => {
  const tiles = Array.from({length: 9}, () => ({object: 90}));
  const output = convertTerrain(modern({tiles}), DEFINITIONS);
  assert.deepEqual(output.trees, [[0, 0, 2], [1, 0, 2], [0, 1, 2], [1, 1, 2]]);
  assert.deepEqual(output.report.omitted_trees, {border: 5, material: 0, slope: 0});
});

test('tree omissions honor the real game material and maximum walk slope rules', () => {
  const material = convertTerrain(modern({tiles: [{object: 90, terrain: 192}]}), DEFINITIONS);
  assert.equal(material.trees.length, 0);
  assert.equal(material.report.omitted_trees.material, 1);
  const tiles = Array.from({length: 9}, () => ({height: 0}));
  tiles[0] = {object: 90, height: 0};
  tiles[4].height = 30;
  const slope = convertTerrain(modern({tiles}), DEFINITIONS);
  assert.equal(slope.trees.length, 0);
  assert.equal(slope.report.omitted_trees.slope, 1);
  tiles[4].height = 20;
  assert.equal(convertTerrain(modern({tiles}), DEFINITIONS).trees.length, 1);
});

test('unknown, duplicate, incomplete and misleading tile definitions fail closed', () => {
  assert.throws(() => convertTerrain(modern({tiles: [{terrain: 500}]}), DEFINITIONS), /missing tile/);
  assert.throws(() => convertTerrain(modern(), {}), /Tiles array/);
  assert.throws(() => convertTerrain(modern(), {Tiles: [DEFINITIONS.Tiles[0], DEFINITIONS.Tiles[0]]}), /duplicate/);
  assert.throws(() => convertTerrain(modern(), {Tiles: [{ID: 0, CornersTerKinds: kinds('tkGrass')}]}), /walkability/);
  assert.throws(() => convertTerrain(modern(), {Tiles: [{ID: 0, Walkable: true, CornersTerKinds: ['tkGrass']}]}), /corner terrain/);
  assert.throws(() => convertTerrain(modern(), DEFINITIONS, {url: 'file:///secret'}), /HTTPS/);
  assert.doesNotThrow(() => convertTerrain(modern(), DEFINITIONS, {name: 'x'.repeat(100)}));
  assert.throws(() => convertTerrain(modern(), DEFINITIONS, {name: 'x'.repeat(101)}), /map name/);
  assert.throws(() => convertTerrain(modern(), DEFINITIONS, {name: '   '}), /map name/);
});

const realMap = process.env.KAM_TEST_MAP;
const realTiles = process.env.KAM_TEST_TILES;
test('real Mountainous Region: independently verify every raw height, material and living tree',
  {skip: !(realMap && realTiles)}, () => {
    const bytes = fs.readFileSync(realMap);
    const definitions = JSON.parse(fs.readFileSync(realTiles, 'utf8'));
    assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),
      'cf70c8b222632e7281a10935125b325a0367b36a68f29aae3c4792777b397bb4');
    // This particular file has a known fixed r11222 header and no additional
    // layers. Access raw bytes independently, never decodeMap's tile list.
    assert.equal(bytes.toString('utf16le', 6, 18), 'r11222');
    assert.equal(bytes.readUInt32LE(18), 165888);
    assert.equal(bytes.readInt32LE(22), 144);
    assert.equal(bytes.readInt32LE(26), 128);
    assert.equal(bytes.length, 184366);
    const output = convertTerrain(bytes, definitions, {name: 'Mountainous Region'});
    assert.deepEqual(output.map_size, [143, 127]);
    const matureIds = new Set([90, 95, 100, 105, 110, 114, 119, 151, 155, 160, 165, 170]);
    const livingTrees = [];
    let sourceTrees = 0, blocked = 0, water = 0, land = 0, rawMin = 255, rawMax = 0;
    for (let y = 0; y < 128; y += 1) {
      assert.equal(output.heights[y].length, 144);
      for (let x = 0; x < 144; x += 1) {
        const offset = 30 + (y * 144 + x) * 9;
        assert.equal(bytes[offset + 8], 0);
        const rawHeight = bytes[offset + 3];
        rawMin = Math.min(rawMin, rawHeight);
        rawMax = Math.max(rawMax, rawHeight);
        assert.equal(output.heights[y][x], Math.round(rawHeight * 0.15));
        const object = bytes.readUInt16LE(offset + 4);
        if (matureIds.has(object)) sourceTrees += 1;
        if (x === 143 || y === 127) continue;
        const definition = definitions.Tiles.find(tile => tile.ID === bytes.readUInt16LE(offset));
        const code = output.terrain[y][x];
        if (definition.Walkable) {
          assert.ok(code === 'g' || code === 'd');
          land += 1;
        } else {
          assert.ok(code === 'w' || code === 'r');
          if (code === 'w') water += 1; else blocked += 1;
        }
        if (matureIds.has(object)) livingTrees.push([x, y, 2]);
      }
    }
    assert.deepEqual([rawMin, rawMax], [0, 100]);
    assert.deepEqual([land, water, blocked], [13434, 146, 4581]);
    assert.equal(sourceTrees, 342);
    assert.equal(livingTrees.length, 341);
    assert.deepEqual(output.trees, livingTrees);
    assert.equal(output.report.omitted_other_objects, 211);
    assert.deepEqual(output.report.omitted_trees, {border: 1, material: 0, slope: 0});
    assert.equal(output.terrain.length, 127);
    assert.ok(output.terrain.every(row => row.length === 143));
  });
