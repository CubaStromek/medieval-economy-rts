#!/usr/bin/env node
'use strict';

// Terrain data only: never load or evaluate a KaM mission/script or game assets.
// Format reference: KaM Remake a3b3e526, KM_Utils.LoadMapHeader and
// KM_TerrainUtils.ReadTileFromStream. See docs/mountainous-region.md.
const fs = require('node:fs');
const crypto = require('node:crypto');
const path = require('node:path');

const HEIGHT_SCALE = 0.15;
const KIND_NAMES = ['tkCustom', 'tkGrass', 'tkMoss', 'tkPaleGrass', 'tkCoastSand',
  'tkGrassSand1', 'tkGrassSand2', 'tkGrassSand3', 'tkSand', 'tkGrassDirt',
  'tkDirt', 'tkCobbleStone', 'tkGrassyWater', 'tkSwamp', 'tkIce',
  'tkSnowOnGrass', 'tkSnowOnDirt', 'tkSnow', 'tkDeepSnow', 'tkStone',
  'tkGoldMount', 'tkIronMount', 'tkAbyss', 'tkGravel', 'tkCoal', 'tkGold',
  'tkIron', 'tkWater', 'tkFastWater', 'tkLava'];
// KM_ResTilesetTypes.BASE_TERRAIN: used for the source's layered passability rule.
const BASE_TERRAIN = [0, 0, 8, 17, 32, 26, 27, 28, 29, 34, 35, 215, 48, 40,
  44, 315, 47, 46, 45, 132, 159, 164, 245, 20, 155, 147, 151, 192, 209, 7];
const WATER_KINDS = new Set(['tkGrassyWater', 'tkSwamp', 'tkWater', 'tkFastWater']);
const EARTH_KINDS = new Set(['tkCoastSand', 'tkGrassSand1', 'tkGrassSand2',
  'tkGrassSand3', 'tkSand', 'tkGrassDirt', 'tkDirt', 'tkCobbleStone',
  'tkGravel', 'tkCoal', 'tkSnowOnDirt']);
// Only the first four (living) age columns of CHOPABLE_TREES. Falling trees and
// stumps must not accidentally become a new living forest on import.
const TREE_AGES = [
  [88, 89, 90, 90], [97, 98, 99, 100], [102, 103, 104, 105],
  [107, 108, 109, 110], [112, 113, 114, 114], [116, 117, 118, 119],
  [92, 93, 94, 95], [121, 122, 123, 124], [149, 150, 151, 151],
  [153, 154, 155, 155], [157, 158, 159, 160], [162, 163, 164, 165],
  [167, 168, 169, 170],
];
const TREE_STAGE = new Map();
for (const ages of TREE_AGES) ages.forEach((id, age) => TREE_STAGE.set(id, Math.min(age, 2)));

function insist(ok, reason) {
  if (!ok) throw new Error(`KaM terrain: ${reason}`);
}

function decodeMap(input) {
  insist(Buffer.isBuffer(input) || input instanceof Uint8Array, 'input must be binary data');
  const bytes = Buffer.from(input);
  insist(bytes.length <= 16 * 1024 * 1024, 'file exceeds the 16 MiB terrain limit');
  let cursor = 0;
  let limit = bytes.length;
  function take(length) {
    insist(Number.isSafeInteger(length) && length >= 0 && cursor + length <= limit,
      `truncated data at byte ${cursor}`);
    const offset = cursor;
    cursor += length;
    return offset;
  }
  const u8 = () => bytes.readUInt8(take(1));
  const u16 = () => bytes.readUInt16LE(take(2));
  const u32 = () => bytes.readUInt32LE(take(4));
  const i32 = () => bytes.readInt32LE(take(4));
  let width = i32();
  let revision = 0;
  let declaredPayload = null;
  if (width === 0) {
    const length = u16();
    insist(length >= 2 && length <= 16, 'invalid revision string length');
    const offset = take(length * 2);
    const label = bytes.toString('utf16le', offset, offset + length * 2);
    insist(/^r[0-9]+$/.test(label), 'invalid revision marker');
    revision = Number(label.slice(1));
    insist(revision >= 10969 && revision <= 11222,
      `unsupported revision ${label}; supported modern range is r10969..r11222`);
    declaredPayload = u32();
    width = i32();
  }
  const height = i32();
  insist(width >= 2 && width <= 256 && height >= 2 && height <= 256,
    'vertex dimensions must each be 2..256');
  const recordCount = width * height;
  const payloadStart = cursor;
  const minimumPayload = recordCount * (revision === 0 ? 23 : 9);
  if (declaredPayload !== null) {
    insist(declaredPayload >= minimumPayload, 'declared payload is smaller than its tile records');
    insist(declaredPayload <= recordCount * 20, 'declared payload is larger than supported records');
    insist(cursor + declaredPayload <= bytes.length, 'declared payload exceeds file size');
    limit = cursor + declaredPayload;
  } else {
    insist(cursor + minimumPayload <= bytes.length, 'truncated original tile records');
    limit = cursor + minimumPayload;
  }
  const tiles = [];
  for (let index = 0; index < recordCount; index += 1) {
    let terrain, rotation, vertexHeight, object, custom = false, overlay = 0;
    let cornerOwners = [0, 0, 0, 0], blending = 0;
    const layers = [];
    if (revision === 0) {
      const offset = take(23);
      terrain = bytes[offset];
      vertexHeight = bytes[offset + 2];
      rotation = bytes[offset + 3] % 4;
      object = bytes[offset + 5];
    } else {
      terrain = u16();
      rotation = u8() % 4;
      vertexHeight = u8();
      object = u16();
      const customByte = u8();
      insist(customByte <= 1, `invalid custom flag in tile ${index}`);
      custom = customByte === 1;
      overlay = u8();
      insist(overlay <= 5, `invalid overlay in tile ${index}`);
      const count = u8();
      insist(count <= 3, `too many layers in tile ${index}`);
      if (count > 0) {
        const corners = u8();
        cornerOwners = [0, 1, 2, 3].map(corner => (corners >> (corner * 2)) & 3);
        insist(cornerOwners.every(owner => owner <= count), `invalid corner owner in tile ${index}`);
        blending = u8();
        for (let layer = 0; layer < count; layer += 1) {
          const packed = u16();
          const kind = (packed >> 10) & 63;
          insist(kind < KIND_NAMES.length, `unknown layer terrain kind in tile ${index}`);
          layers.push({kind: KIND_NAMES[kind], rotation: u8() % 4,
            mask_subtype: (packed >> 8) & 3, mask_kind: (packed >> 4) & 15,
            mask_type: packed & 15});
        }
      }
    }
    insist(object <= 255, `unsupported object ID ${object} in tile ${index}`);
    tiles.push({terrain, rotation, height: vertexHeight, object, custom,
      overlay, corner_owners: cornerOwners, blending, layers});
  }
  insist(cursor === limit, 'declared payload does not equal decoded tile data');
  return {revision, vertex_size: [width, height], tiles,
    payload_bytes: cursor - payloadStart, trailing_bytes: bytes.length - cursor};
}

function definitionsById(json) {
  insist(json && Array.isArray(json.Tiles), 'tiles definitions require a Tiles array');
  const byId = new Map();
  for (const entry of json.Tiles) {
    insist(entry && Number.isInteger(entry.ID) && entry.ID >= 0 && entry.ID <= 65535,
      'invalid tile definition ID');
    insist(!byId.has(entry.ID), `duplicate tile definition ${entry.ID}`);
    insist(typeof entry.Walkable === 'boolean', `tile ${entry.ID} lacks explicit walkability`);
    insist(Array.isArray(entry.CornersTerKinds) && entry.CornersTerKinds.length === 4 &&
      entry.CornersTerKinds.every(kind => KIND_NAMES.includes(kind)),
    `tile ${entry.ID} has unsupported corner terrain kinds`);
    byId.set(entry.ID, entry);
  }
  return byId;
}

function resolvedSurface(tile, definitions) {
  const base = definitions.get(tile.terrain);
  insist(base, `missing tile definition ${tile.terrain}`);
  const corners = tile.corner_owners.map((owner, corner) => owner === 0 ?
    base.CornersTerKinds[(corner + 4 - tile.rotation) % 4] : tile.layers[owner - 1].kind);
  let walkable = base.Walkable;
  if (tile.layers.length > 0) {
    // Match TKMTerrain.TileHasParameter/TileIsWalkable, not a guessed majority
    // of base textures; abyss/lava veto even a single owned corner.
    let count = 0;
    for (const kind of corners) {
      const definition = definitions.get(BASE_TERRAIN[KIND_NAMES.indexOf(kind)]);
      insist(definition, `missing canonical definition for ${kind}`);
      if (definition.Walkable) count += 1;
    }
    walkable = !corners.some(kind => kind === 'tkLava' || kind === 'tkAbyss') &&
      (count >= 3 || (count === 2 && base.Walkable));
  }
  const water = corners.filter(kind => WATER_KINDS.has(kind)).length;
  if (!walkable) return {code: water >= 2 || base.Water === true ||
    (base.HasWater === true && water > 0) ? 'w' : 'r', walkable, corners};
  const earth = corners.filter(kind => EARTH_KINDS.has(kind)).length;
  // Walkable mixed shore tiles stay land, preserving the original crossings.
  return {code: earth >= 2 || base.Sand === true ? 'd' : 'g', walkable, corners};
}

function convertTerrain(input, tilesJson, options = {}) {
  const decoded = decodeMap(input);
  const definitions = definitionsById(tilesJson);
  const [width, height] = decoded.vertex_size;
  const name = options.name === undefined ? 'Imported KaM terrain' : options.name;
  const url = options.url === undefined ? '' : options.url;
  insist(typeof name === 'string' && name.trim().length > 0 && name.length <= 100, 'invalid map name');
  insist(typeof url === 'string' && url.length <= 2048 && (url === '' || /^https:\/\//.test(url)),
    'source URL must be empty or HTTPS');
  let minimum = 255, maximum = 0;
  for (const tile of decoded.tiles) {
    minimum = Math.min(minimum, tile.height);
    maximum = Math.max(maximum, tile.height);
    insist(definitions.has(tile.terrain), `missing tile definition ${tile.terrain}`);
  }
  const heights = Array.from({length: height}, (_, y) =>
    Array.from({length: width}, (_, x) => {
      const value = Math.round((decoded.tiles[y * width + x].height - minimum) * HEIGHT_SCALE);
      insist(value >= 0 && value <= 64, 'scaled height exceeds the game height range');
      return value;
    }));
  const terrain = [];
  const trees = [];
  const report = {playable_cells: (width - 1) * (height - 1),
    material_counts: {g: 0, d: 0, w: 0, r: 0},
    source_living_trees: 0, imported_trees: 0,
    omitted_trees: {border: 0, material: 0, slope: 0},
    omitted_other_objects: 0, omitted_overlays: 0,
    layered_cells: 0, custom_cells: 0, walkable_source_cells: 0,
    walkable_shore_cells: 0, source_resource_cells: 0};
  for (let y = 0; y < height; y += 1) {
    let row = '';
    for (let x = 0; x < width; x += 1) {
      const tile = decoded.tiles[y * width + x];
      const isTree = TREE_STAGE.has(tile.object);
      if (isTree) report.source_living_trees += 1;
      if (x === width - 1 || y === height - 1) {
        if (isTree) report.omitted_trees.border += 1;
        continue;
      }
      const base = definitions.get(tile.terrain);
      const surface = resolvedSurface(tile, definitions);
      row += surface.code;
      report.material_counts[surface.code] += 1;
      if (surface.walkable) report.walkable_source_cells += 1;
      if (surface.walkable && surface.corners.some(kind => WATER_KINDS.has(kind)))
        report.walkable_shore_cells += 1;
      if (tile.layers.length) report.layered_cells += 1;
      if (tile.custom) report.custom_cells += 1;
      if (tile.overlay) report.omitted_overlays += 1;
      if (['Stone', 'Coal', 'Iron', 'Gold'].some(resource => Number(base[resource] || 0) > 0))
        report.source_resource_cells += 1;
      if (!isTree) {
        if (tile.object !== 255) report.omitted_other_objects += 1;
        continue;
      }
      if (surface.code !== 'g' && surface.code !== 'd') {
        report.omitted_trees.material += 1;
        continue;
      }
      const corners = [heights[y][x], heights[y][x + 1], heights[y + 1][x], heights[y + 1][x + 1]];
      if (Math.max(...corners) - Math.min(...corners) > 3) {
        report.omitted_trees.slope += 1;
        continue;
      }
      trees.push([x, y, TREE_STAGE.get(tile.object)]);
    }
    if (y < height - 1) terrain.push(row);
  }
  report.imported_trees = trees.length;
  return {format: 'medieval-terrain-v1', name,
    source: {url, sha256: crypto.createHash('sha256').update(input).digest('hex'),
      revision: decoded.revision, vertex_size: [width, height],
      height_scale: HEIGHT_SCALE, height_offset: minimum, raw_height_range: [minimum, maximum],
      payload_bytes: decoded.payload_bytes, ignored_trailing_bytes: decoded.trailing_bytes,
      tiles_sha256: crypto.createHash('sha256').update(JSON.stringify(tilesJson)).digest('hex'),
      adaptations: [
        'Full playable extent; final source row and column supply boundary vertices only.',
        'Source heights rescaled to integer game heights; no smoothing or terrain redesign.',
        'Terrain textures and transitions reduced to grass, dirt, water and impassable rock.',
        'Walkable shore and mountain-edge cells remain land; slope rules use game heights.',
        'Living tree positions retained when allowed by game terrain; species use our tree sprites.',
        'Decorations, stumps, source road overlays, resource yields, buildings, units and mission logic omitted.',
      ]},
    map_size: [width - 1, height - 1], heights, terrain, trees, report};
}

function cli(argv) {
  const allowed = new Set(['--map', '--tiles', '--out', '--name', '--source-url']);
  const args = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    insist(allowed.has(key) && typeof argv[index + 1] === 'string' && !argv[index + 1].startsWith('--'),
      'usage: --map MAP --tiles TILES_JSON --out OUTPUT [--name NAME] [--source-url HTTPS_URL]');
    insist(args[key] === undefined, `duplicate argument ${key}`);
    args[key] = argv[index + 1];
  }
  for (const key of ['--map', '--tiles', '--out']) insist(args[key], `missing ${key}`);
  const inputPath = path.resolve(args['--map']);
  const tilesPath = path.resolve(args['--tiles']);
  const outputPath = path.resolve(args['--out']);
  insist(outputPath !== inputPath && outputPath !== tilesPath, 'output must not overwrite an input');
  insist(fs.statSync(inputPath).size <= 16 * 1024 * 1024, 'map input exceeds 16 MiB');
  insist(fs.statSync(tilesPath).size <= 8 * 1024 * 1024, 'tile definitions exceed 8 MiB');
  const converted = convertTerrain(fs.readFileSync(inputPath),
    JSON.parse(fs.readFileSync(tilesPath, 'utf8')), {name: args['--name'], url: args['--source-url']});
  // Exclusive creation makes an accidental rerun non-destructive. Pick a new
  // output path or explicitly manage an existing generated artifact yourself.
  fs.writeFileSync(outputPath, JSON.stringify(converted) + '\n', {flag: 'wx'});
  process.stdout.write(JSON.stringify({output: outputPath, map_size: converted.map_size,
    source_sha256: converted.source.sha256, report: converted.report}, null, 2) + '\n');
}

module.exports = {decodeMap, convertTerrain};
if (require.main === module) {
  try { cli(process.argv.slice(2)); }
  catch (error) { process.stderr.write(String(error.message) + '\n'); process.exitCode = 1; }
}
