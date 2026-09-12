#!/usr/bin/env node
'use strict';
// Production export: imagegen color-key sources -> registered RGBA textures
// and authored integer stage maps. Never reads proprietary KaM graphics.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sharp = require('sharp');
const ROOT = path.resolve(__dirname, '..');
const INPUT = path.join(ROOT, 'docs/art/sources/lumber-hut-construction-v1');
const OUT = path.join(ROOT, 'game/art/buildings/lumber_hut/v1');
const QA = path.join(ROOT, 'docs/art/qa/lumber-hut-construction-v1');
const SIZE = 640;
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function inside(x, y, polygon) {
  let yes = false;
  for (let i=0,j=polygon.length-1; i<polygon.length; j=i++) {
    const [xi,yi]=polygon[i], [xj,yj]=polygon[j];
    if ((yi>y)!==(yj>y) && x<(xj-xi)*(y-yi)/(yj-yi)+xi) yes=!yes;
  }
  return yes;
}
const lowerRoof = [[20,584],[86,524],[663,340],[830,627],[235,823]];
const upperRoof = [[594,293],[687,222],[1083,108],[1243,504],[824,633]];
const chimney = [[821,114],[901,86],[939,132],[931,242],[846,260],[817,193]];
const cradle = [[139,863],[390,849],[579,966],[609,1074],[381,1140],[253,1057]];
const horse = [[447,791],[636,757],[695,890],[562,950],[495,906]];
const tools = [[678,706],[749,685],[805,742],[789,875],[676,837]];
const feet = [
  [[42,799],[128,793],[144,886],[98,916],[39,878]],
  [[195,957],[264,943],[306,980],[313,1047],[250,1083],[192,1051]],
  [[779,835],[842,816],[871,846],[870,911],[816,928],[778,895]],
  [[848,832],[1034,775],[1074,847],[865,914]],
  [[1024,795],[1176,762],[1207,805],[1197,853],[1067,879]],
  [[1164,741],[1204,726],[1222,778],[1203,812],[1166,793]],
  [[626,763],[670,756],[688,789],[663,812],[627,794]],
];
function woodStep(x,y) {
  // Complete structural parts take precedence over the wall courses.
  if (feet.some(p=>inside(x,y,p))) return 1;
  if (inside(x,y,cradle)) return 2;
  if (inside(x,y,upperRoof)) return 12;
  if (inside(x,y,lowerRoof)) return x < 420 ? 10 : 11;
  const groundY = x < 330 ? 910 + (x-80)*.53 : 1075-(x-250)*.29;
  const height=groundY-y;
  if (height<60) return 2;
  if (height<80) return 3;
  if (height<112) return 4;
  if (height<146) return 5;
  if (height<180) return 6;
  if (height<214) return 7;
  if (height<248) return 8;
  return 9;
}
function finishedStep(x,y) {
  if (inside(x,y,chimney)) return 19;
  if (inside(x,y,cradle)||(x>=442&&x<=702&&y>=753&&y<=953)
      ||(x>=664&&x<=814&&y>=682&&y<=876)) return 20;
  if (x>1174 && y>561 && y<641) return 21; // Empty occupancy bracket.
  if (inside(x,y,upperRoof)) {
    const eave=633-.30*(x-824);
    const t=(eave-y)/394;
    if (t>.92) return 21; // High ridge caps are the final closure.
    return Math.max(14,Math.min(18,14+Math.floor(Math.max(0,t)*5)));
  }
  if (inside(x,y,lowerRoof)) {
    const eave=821-.322*(x-235);
    const t=(eave-y)/265;
    return Math.max(8,Math.min(13,8+Math.floor(Math.max(0,t)*6)));
  }
  if (feet.some(p=>inside(x,y,p))) return x<760 ? 1 : 2;
  if (y>830) return 3;
  if (y>775) return 4;
  if (y>715) return 5;
  if (y>650) return 6;
  return 7;
}
async function exportMatte(name) {
  const filename=path.join(INPUT,name+'-matte.png');
  const {data,info}=await sharp(filename).removeAlpha().raw().toBuffer({resolveWithObject:true});
  const rgba=Buffer.alloc(info.width*info.height*4);
  let removed=0,fringe=0,opaque=0;
  for(let i=0,p=0;i<data.length;i+=3,p+=4){
    const [r,g,b]=[data[i],data[i+1],data[i+2]];
    // Saturated magenta is a dedicated export channel absent from the art.
    const key=Math.min(r,b)-g;
    // Imagegen's apparently flat matte varies slightly (minimum sampled
    // background dominance219), so leave a margin before edge unmatting.
    let a=Math.max(0,Math.min(1,(200-key)/180));
    if(a<.025)a=0;
    if(a>.975)a=1;
    rgba[p+3]=Math.round(a*255);
    if(a===0){removed++;continue;}
    if(a===1){rgba[p]=r;rgba[p+1]=g;rgba[p+2]=b;opaque++;continue;}
    // Unmatte the antialiased boundary to avoid magenta fringes on terrain.
    rgba[p]=Math.round(Math.max(0,Math.min(255,(r-(1-a)*255)/a)));
    rgba[p+1]=Math.round(Math.max(0,Math.min(255,g/a)));
    rgba[p+2]=Math.round(Math.max(0,Math.min(255,(b-(1-a)*255)/a)));
    fringe++;
  }
  if(removed<info.width*info.height*.15) throw Error('No real color-key background found');
  await sharp(rgba,{raw:{width:info.width,height:info.height,channels:4}}).png().toFile(path.join(INPUT,name+'-rgba-master.png'));
  const raw=await sharp(rgba,{raw:{width:info.width,height:info.height,channels:4}}).resize(SIZE,SIZE,{kernel:'lanczos3'}).raw().toBuffer();
  await sharp(raw,{raw:{width:SIZE,height:SIZE,channels:4}}).png().toFile(path.join(OUT,name+'.png'));
  return {raw,source:{file:filename.slice(ROOT.length+1),sha256:sha(fs.readFileSync(filename)),size:[info.width,info.height],removed,fringe,opaque}};
}
async function main(){
  for(const dir of [OUT,QA])fs.mkdirSync(dir,{recursive:true});
  const wood=await exportMatte('wood'), finished=await exportMatte('finished');
  const wm=Buffer.alloc(SIZE*SIZE*4),fm=Buffer.alloc(SIZE*SIZE*4);
  const woodCounts=Array(13).fill(0),finishCounts=Array(22).fill(0);
  for(let y=0;y<SIZE;y++)for(let x=0;x<SIZE;x++){
    const p=(y*SIZE+x)*4, sx=(x+.5)*1254/SIZE,sy=(y+.5)*1254/SIZE;
    const w=wood.raw[p+3]>0?woodStep(sx,sy):0;
    // Include construction-only pixels, so final air gaps remove supports.
    const f=finished.raw[p+3]>0||wood.raw[p+3]>0?finishedStep(sx,sy):0;
    wm[p]=wm[p+1]=wm[p+2]=w;wm[p+3]=255;
    fm[p]=fm[p+1]=fm[p+2]=f;fm[p+3]=255;
    if(w)woodCounts[w]++;
    if(f)finishCounts[f]++;
  }
  if(woodCounts.slice(1).includes(0)||finishCounts.slice(1).includes(0)) throw Error('Missing authored stage');
  for(const [name,data] of [['wood-mask',wm],['finished-mask',fm]])await sharp(data,{raw:{width:SIZE,height:SIZE,channels:4}}).png().toFile(path.join(OUT,name+'.png'));
  const manifest={
    version:1,building_id:'lumber_hut',date:'2026-09-10',style_version:'0.2',
    status:'in-game pilot, not an approved building-set reference',
    source_to_world:0.225,door_threshold:[Math.round(1113*SIZE/1254),Math.round(803*SIZE/1254)],
    // Stable visual depth registration: union of both master bounds (alpha>0.1),
    // minus half a 40-world-pixel cell. This never moves the drawing or door.
    sort_foot:[568,577-20/.225],
    sort_foot_basis:'Both masters have exclusive visible bottom577 at alpha>0.1; subtract half cell in source pixels. Shared by all33 steps. See docs/art/kam-object-terrain-rendering-study.md.',
    label_anchor:[320,29],
    canvas:[SIZE,SIZE],wood_phase_fraction:.6,wood_steps:12,finished_steps:21,
    wood_image:'wood.png',finished_image:'finished.png',wood_mask:'wood-mask.png',finished_mask:'finished-mask.png',
    mask_format:'RGB integer byte1..count; zero never; finishing masks include transparent erasure areas',
    anchors:{stock_origin:{pixel:[Math.round(438*SIZE/1254),Math.round(1008*SIZE/1254)],status:'reserved, stock sprites not implemented'},occupancy_indicator:{pixel:[Math.round(1204*SIZE/1254),Math.round(606*SIZE/1254)],status:'empty bracket, no new runtime state'}},
    footprint_mask:['###','##E'],footprint_version:1,
    sources:[wood.source,finished.source],
    export:{tool:'tools/pack-lumber-hut-construction.cjs',method:'Generated magenta matte decoded to straight RGBA, shared Lanczos resize, own spatial integer masks; no source art redrawing in exporter.',master_to_export:SIZE/1254},
    validation:{wood_group_pixels:woodCounts.slice(1),finished_group_pixels:finishCounts.slice(1),alpha_background:true,ground_qa:'2026-09-10: native lower-pixel occlusion test passed; see docs/art/qa/lumber-hut-construction-v1/README.md and capture-manifest.json for matching asset hashes and remaining slope-contact art calibration.'},
  };
  for(const file of ['wood.png','finished.png','wood-mask.png','finished-mask.png'])manifest[file.replaceAll('.','_')+'_sha256']=sha(fs.readFileSync(path.join(OUT,file)));
  fs.writeFileSync(path.join(OUT,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  const stages=[];
  for(let stage=1;stage<=33;stage++){
    const frame=Buffer.alloc(SIZE*SIZE*4);
    for(let p=0;p<frame.length;p+=4){
      const src=stage===33?finished.raw:stage>12&&fm[p]>0&&fm[p]<=stage-12?finished.raw:wm[p]>0&&wm[p]<=Math.min(12,stage)?wood.raw:null;
      if(src)src.copy(frame,p,p,p+4);
    }
    stages.push(frame);
  }
  const hashes=stages.map(sha);if(new Set(hashes).size!==33)throw Error('Duplicate visual stage');
  // Exporter QA uses the exact same binary mask contract, game QA is separate.
  for(const stage of [1,3,6,9,12,15,19,23,27,30,32,33]) await sharp(stages[stage-1],{raw:{width:SIZE,height:SIZE,channels:4}}).resize(320,320).flatten({background:'#74815d'}).png().toFile(path.join(QA,`art-stage-${String(stage).padStart(2,'0')}.png`));
  fs.writeFileSync(path.join(QA,'asset-validation.json'),JSON.stringify({date:'2026-09-10',distinct_frames:new Set(hashes).size,stage_sha256:hashes,finished_exact:stages[32].equals(finished.raw),sources_unchanged:manifest.sources.every(s=>sha(fs.readFileSync(path.join(ROOT,s.file)))===s.sha256)},null,2)+'\n');
  console.log(JSON.stringify({canvas:manifest.canvas,threshold:manifest.door_threshold,woodCounts:woodCounts.slice(1),finishCounts:finishCounts.slice(1),distinct:new Set(hashes).size}));
}
main().catch(e=>{console.error(e);process.exit(1)});
