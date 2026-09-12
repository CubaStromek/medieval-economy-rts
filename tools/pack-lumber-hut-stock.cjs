#!/usr/bin/env node
'use strict';
// Technical reuse of one painted log from our existing concept. The house,
// masks, simulation geometry and original concept are never edited here.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sharp = require('sharp');
const ROOT = path.resolve(__dirname, '..');
const SOURCE = path.join(ROOT, 'docs/art/concepts/lumber-hut-v3-stock/logs-6.png');
const HOUSE = path.join(ROOT, 'game/art/buildings/lumber_hut/v1/finished.png');
const OUT = path.join(ROOT, 'game/art/buildings/lumber_hut/v1/stock');
const QA = path.join(ROOT, 'docs/art/qa/lumber-hut-stock-v1');
const SIZE = 640;
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function inside(x, y, polygon) {
  let result = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [xi, yi] = polygon[i], [xj, yj] = polygon[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) result = !result;
  }
  return result;
}
// The uppermost existing log includes both bark and its complete end grain.
// Vertices follow its visible silhouette in the unchanged 1254px concept.
const logPolygon = [[374,806],[398,826],[426,853],[452,877],[460,884],
  [465,892],[466,903],[462,914],[455,922],[445,926],[435,924],
  [426,919],[411,902],[386,878],[361,855],[345,839]];
const sourceCap = [445,900];
// Identical log dimensions in stable bottom 3, middle 2, top 1 slots.
const slots = [[397,1005],[447,991],[497,977],[422,952],[472,938],[447,899]];
// Existing permanent architecture stays in front. These are alpha cutouts in
// the overlay, not repainted house parts; coordinates belong to finished.png.
const foreground = [
  [[115,412],[142,406],[149,493],[142,503],[124,494]],
  [[140,441],[178,410],[190,412],[146,459]],
  [[174,526],[191,516],[207,525],[211,565],[195,577],[181,568]],
  [[207,548],[274,524],[278,536],[211,560]],
  [[273,497],[287,490],[299,498],[308,546],[293,552],[280,541]],
];
async function main() {
  fs.mkdirSync(OUT, {recursive:true}); fs.mkdirSync(QA, {recursive:true});
  const input = fs.readFileSync(SOURCE);
  const {data, info} = await sharp(input).removeAlpha().raw().toBuffer({resolveWithObject:true});
  if (info.width !== 1254 || info.height !== 1254) throw Error('Unexpected stock concept canvas');
  const layers = [];
  for (const [sx,sy] of slots) {
    const rgba = Buffer.alloc(info.width * info.height * 4);
    const dx = sx - sourceCap[0], dy = sy - sourceCap[1];
    for (let y=805;y<928;y++) for (let x=343;x<469;x++) {
      if (!inside(x+.5,y+.5,logPolygon)) continue;
      const from = (y*info.width+x)*3, to = ((y+dy)*info.width+x+dx)*4;
      rgba[to]=data[from]; rgba[to+1]=data[from+1]; rgba[to+2]=data[from+2]; rgba[to+3]=255;
    }
    const resized = await sharp(rgba,{raw:{width:info.width,height:info.height,channels:4}})
      .resize(SIZE,SIZE,{kernel:'lanczos3'}).raw().toBuffer();
    for (let y=0;y<SIZE;y++) for (let x=0;x<SIZE;x++)
      if (foreground.some(p=>inside(x+.5,y+.5,p))) resized[(y*SIZE+x)*4+3]=0;
    layers.push(await sharp(resized,{raw:{width:SIZE,height:SIZE,channels:4}}).png().toBuffer());
  }
  const manifest = {version:1,building_id:'lumber_hut',date:'2026-09-10',canvas:[SIZE,SIZE],
    authored_capacity:6,source_canvas:[1254,1254],source_cap:sourceCap,
    slots:slots.map((p,i)=>({id:'log_slot_'+(i+1),pixel:p.map(v=>v*SIZE/1254)})),
    stock_count_label:[310,535],unknown_label:[222,510],source:'docs/art/concepts/lumber-hut-v3-stock/logs-6.png',
    source_sha256:sha(input),house_sha256:sha(fs.readFileSync(HOUSE)),
    method:'Existing own painted top log extracted by silhouette, translated without per-state drift; common resize and foreground alpha exclusion. No image generation or house edits.',
    extraction_polygon:logPolygon,foreground_exclusion_polygons:foreground,states:[]};
  for(let count=0;count<=6;count++) {
    let frame = sharp({create:{width:SIZE,height:SIZE,channels:4,background:'#00000000'}});
    if(count) frame=frame.composite(layers.slice(0,count).map(input=>({input})));
    const png=await frame.png().toBuffer(), filename='logs-'+count+'.png';
    fs.writeFileSync(path.join(OUT,filename),png);
    const {data:raw}=await sharp(png).raw().toBuffer({resolveWithObject:true});
    let visible=0; const bounds=[SIZE,SIZE,0,0];
    for(let y=0;y<SIZE;y++) for(let x=0;x<SIZE;x++) if(raw[(y*SIZE+x)*4+3]>25) {
      visible++; bounds[0]=Math.min(bounds[0],x); bounds[1]=Math.min(bounds[1],y);
      bounds[2]=Math.max(bounds[2],x+1); bounds[3]=Math.max(bounds[3],y+1);
    }
    manifest.states.push({amount:count,image:filename,sha256:sha(png),alpha_pixels:visible,
      alpha_bounds:visible?bounds:null});
    await sharp(HOUSE).composite([{input:png}]).png().toFile(path.join(QA,'asset-composite-'+count+'.png'));
  }
  fs.writeFileSync(path.join(OUT,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  console.log(JSON.stringify({states:manifest.states,source_sha256:manifest.source_sha256},null,2));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
