const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'../../../..'),game=path.join(root,'game'),dst=path.join(game,'art/buildings/sawmill/v2');
const stock=JSON.parse(fs.readFileSync(path.join(__dirname,'stock-fields.json')));
const life=JSON.parse(fs.readFileSync(path.join(__dirname,'life-work-fields.json')));
const work={...life.work,foreground:stock.work?.foreground||stock.foreground||[]};
const operation={schema_version:1,building_id:'sawmill',asset_version:'operation-v2',date:'2026-09-12',canvas:[800,800],stock:stock.stock,work,provenance:{building:'docs/art/sources/sawmill-v2/README.md',stock:stock.provenance||'stock/geometry.json',worker:'docs/art/sources/sawmill-operation-v1/worker-README.md',rest:'docs/art/briefs/carpenter-rest-v1.md',work_log:life.provenance.work_log,backplate:'Not needed: v2 master has an empty workshop wall'},asset_hashes:{...life.asset_hashes,...stock.asset_hashes}};
const files=new Set();for(const kind of Object.values(operation.stock)){files.add(kind.texture);for(const f of kind.foreground||[])files.add(f.texture);}for(const f of work.frames)files.add(f);files.add(work.log.texture);for(const f of work.foreground)files.add(f.texture);
operation.asset_hashes={};for(const f of files){operation.asset_hashes[f]=crypto.createHash('sha256').update(fs.readFileSync(path.join(game,f.replace('res://','')))).digest('hex');}
fs.writeFileSync(path.join(dst,'operation/manifest.json'),JSON.stringify(operation,null,2)+'\n');
const house=JSON.parse(fs.readFileSync(path.join(dst,'manifest.json')));house.life=life.life;house.operation={manifest:'res://art/buildings/sawmill/v2/operation/manifest.json'};fs.writeFileSync(path.join(dst,'manifest.json'),JSON.stringify(house,null,2)+'\n');
