const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '../../../..');
const base = path.join(root, 'game/art/buildings/sawmill/v1');
const resource = 'res://art/buildings/sawmill/v1/operation/';
const read = p => JSON.parse(fs.readFileSync(p, 'utf8'));
const stock = read(path.join(base, 'operation/stock/geometry.json'));
const worker = read(path.join(base, 'operation/work/worker-geometry.json'));
const manifest = {
  schema_version: 1,
  building_id: 'sawmill',
  asset_version: 'operation-v1',
  date: '2026-09-12',
  canvas: [800, 800],
  stock: {},
  work: {
    backplate: resource + 'work/backplate.png',
    frames: worker.frames.map(f => typeof f === 'string' ? (f.startsWith('res://') ? f : resource + 'work/' + f) : resource + 'work/' + f.file),
    body_height_px: worker.body_height_px,
    ground_contact: worker.ground_contact,
    foot: [521, 549],
    cycles_per_batch: 6,
    log: {texture: resource + 'work/processing-log.png', rect: [429, 467, 88, 22]},
    foreground: [{texture: resource + 'stock/foreground.png', rect: [0, 0, 800, 800]}]
  },
  provenance: {
    stock: 'stock/geometry.json', worker: 'work/worker-geometry.json',
    brief: 'docs/art/briefs/sawmill-operation-v1.md',
    original_game_role: 'Observed behavior only; no original KaM pixels in any production file',
    backplate: 'Own imagegen edit; only masked wall region from that image is used',
    work_log: 'Own generated log, trimmed and resampled to an authored bench prop'
  }
};
for (const name of ['log', 'plank']) {
  const group = stock.groups[name];
  manifest.stock[name] = {
    texture: resource + 'stock/' + group.image,
    capacity: group.capacity,
    slots: group.slots.map(s => s.draw_rect),
    foreground: [],
    label: name === 'log' ? [372, 466] : [582, 425]
  };
}
const assets = new Set([
  manifest.work.backplate, ...manifest.work.frames, manifest.work.log.texture,
  ...manifest.work.foreground.map(f => f.texture),
  ...Object.values(manifest.stock).map(s => s.texture)
]);
manifest.asset_hashes = Object.fromEntries([...assets].map(p => [p, crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p.replace('res://','game/')))).digest('hex')]));
fs.writeFileSync(path.join(base,'operation/manifest.json'), JSON.stringify(manifest,null,2)+'\n');
const house = read(path.join(base,'manifest.json'));
house.operation = {manifest: resource + 'manifest.json'};
fs.writeFileSync(path.join(base,'manifest.json'), JSON.stringify(house,null,2)+'\n');
console.log('Assembled operation manifest with '+assets.size+' production images');
