'use strict';
// Technical key removal, uniform export and measured registration. No artwork synthesis.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sharp = require('sharp');
const root = path.resolve(__dirname, '../../../..');
const out = path.join(root, 'game/art/buildings/sawmill/v1');
const qa = path.join(root, 'docs/art/qa/sawmill-v1');
const source = path.join(__dirname, 'finished-key.png');
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const ratio = 800 / 1254;
const scaled = xy => xy.map(v => v * ratio);
const quad = points => points.map(scaled);
function bounds(data, w, h, threshold) {
  let x0=w,y0=h,x1=-1,y1=-1,count=0;
  for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(data[(y*w+x)*4+3]>threshold){
    x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);count++;
  }
  return {bbox:[x0,y0,x1-x0+1,y1-y0+1], count};
}
(async()=>{
  fs.mkdirSync(out,{recursive:true});fs.mkdirSync(qa,{recursive:true});
  const {data,info} = await sharp(source).removeAlpha().raw().toBuffer({resolveWithObject:true});
  if(info.width!==1254||info.height!==1254)throw Error('Source changed: remeasure geometry');
  const rgba=Buffer.alloc(info.width*info.height*4);
  let minBg=255,maxBg=-255;
  for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){
    const i=(y*info.width+x)*3,p=(y*info.width+x)*4;
    const [r,g,b]=[data[i],data[i+1],data[i+2]],d=Math.min(r,b)-g;
    if(y<250){minBg=Math.min(minBg,d);maxBg=Math.max(maxBg,d);}
    // Actual empty-top sample dominance220..247; matte modal RGB247,4,250.
    const a=d>=200?0:Math.max(0,Math.min(1,1-d/243));
    rgba[p+3]=Math.round(a*255);
    if(a===0)continue;
    for(let c=0;c<3;c++)rgba[p+c]=Math.round(Math.max(0,Math.min(255,(data[i+c]-(1-a)*[247,4,250][c])/a)));
  }
  const master=path.join(__dirname,'finished-rgba-master.png');
  await sharp(rgba,{raw:{width:1254,height:1254,channels:4}}).png().toFile(master);
  const finished=path.join(out,'finished.png');
  await sharp(rgba,{raw:{width:1254,height:1254,channels:4}}).resize(800,800,{kernel:'lanczos3'}).png().toFile(finished);
  const pixels=await sharp(finished).ensureAlpha().raw().toBuffer();
  const measured=bounds(pixels,800,800,25);
  const life={
    door:quad([[440,686],[530,681],[530,879],[441,883]]),
    window:quad([[214,659],[290,688],[290,766],[214,737]]),
    chimney:scaled([338,316]),rest_foot:scaled([366,902]),
    window_shutters:[quad([[190,645],[214,659],[214,737],[190,724]]),quad([[290,688],[316,687],[316,767],[290,766]])],
    wood_uv:quad([[441,688],[529,684],[529,876],[441,881]])
  };
  const manifest={schema_version:1,building_id:'sawmill',asset_version:'v1',canvas:[800,800],
    finished_image:'finished.png',finished_sha256:sha(fs.readFileSync(finished)),finished_rgba_sha256:sha(pixels),
    alpha_bbox:measured.bbox,door_threshold:scaled([488,912]),sort_foot:scaled([488,912]),
    label_anchor:scaled([620,280]),source_to_world:0.16/ratio,life};
  // Preserve independently produced resting-character metadata on rerun.
  const manifestPath=path.join(out,'manifest.json');
  if(fs.existsSync(manifestPath)){
    const prev=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
    if(prev.life?.rest_sprite)manifest.life.rest_sprite=prev.life.rest_sprite;
    if(prev.operation)manifest.operation=prev.operation;
  }
  fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+'\n');
  const contacts={
    west_rear:[156,792],left_front:[337,911],door_sill:[488,907],front_left_jamb:[570,889],
    saw_left_leg:[685,842],saw_right_leg:[833,829],center_post:[885,867],far_right_post:[1094,847],
    empty_board_rack:[1020,843],empty_cradle:[620,846],paving_south:[595,885]
  };
  const groundRaw=[113,412,1113,912];
  const checked=Object.fromEntries(Object.entries(contacts).map(([name,xy])=>[name,{source:xy,
    relative_world:[(xy[0]-488)*0.16,(xy[1]-912)*0.16],
    inside:xy[0]>=113&&xy[0]<=1113&&xy[1]>=412&&xy[1]<=912}]));
  if(Object.values(checked).some(c=>!c.inside))throw Error('Ground contact outside4x2 footprint');
  const record={date:'2026-09-12',source_sha256:sha(fs.readFileSync(source)),master_sha256:sha(fs.readFileSync(master)),
    finished_sha256:manifest.finished_sha256,finished_rgba_sha256:manifest.finished_rgba_sha256,
    background:{modal_rgb:[247,4,250],top_region_dominance:[minBg,maxBg],cutoff:200,unmatte:'alpha=clamp(1-(min(r,b)-g)/243), measured modal key removal'},
    source_canvas:[1254,1254],production_canvas:[800,800],source_to_production:ratio,
    source_to_world:0.16,production_to_world:manifest.source_to_world,alpha_gt_0:bounds(pixels,800,800,0),alpha_gt_25:measured,
    no_alpha_source:true,real_alpha_export:true,ground_bounds_source:groundRaw,door_threshold_source:[488,912],
    contact_measurement:'Manual visible ground-contact landmarks, conservative southern registration at y912; tolerance ±3source px. Hidden rear contacts require native raised-ground QA.',
    measured_contacts:checked,door_clear_opening_source_height:202,door_clear_opening_world_height:32.32,
    roof_visual_bounds_source:[109,307,1134,680],roof_lateral_overhang_world:{west:0.64,east:3.36},
    conceptual_ground_width_world:160,conceptual_ground_depth_world:80,
    runtime_qa:'See README.md and natural/report.json for dated runtime results; this export record verifies source geometry only'};
  fs.writeFileSync(path.join(qa,'asset-validation.json'),JSON.stringify(record,null,2)+'\n');
  // QA panels preserve the exported pixels and add diagnostic backgrounds/geometry only.
  const cells=[];
  for(let x=113;x<=1113;x+=250)cells.push(`<path d="M${x} 412V912"/>`);
  for(let y=412;y<=912;y+=250)cells.push(`<path d="M113 ${y}H1113"/>`);
  const grid=Buffer.from(`<svg width="1254" height="1254"><g fill="none" stroke="#647364" stroke-width="3">${cells.join('')}<rect x="363" y="912" width="250" height="250" stroke="#279aab"/></g><circle cx="488" cy="912" r="7" fill="#279aab"/></svg>`);
  const contactOverlay=Buffer.from(`<svg width="1254" height="1254"><g fill="#f7c04f" stroke="#293029" stroke-width="2">${Object.values(contacts).map(([x,y])=>`<circle cx="${x}" cy="${y}" r="6"/>`).join('')}</g></svg>`);
  await sharp({create:{width:1254,height:1254,channels:4,background:'#f5f0e4'}}).composite([{input:grid},{input:fs.readFileSync(master)},{input:contactOverlay}]).png().toFile(path.join(qa,'footprint-check.png'));
  await sharp({create:{width:1254,height:1254,channels:4,background:'#f5f0e4'}}).composite([{input:fs.readFileSync(master)}]).png().toFile(path.join(root,'docs/art/concepts/sawmill-v1.png'));
  const panels=[];
  for(const [i,color]of ['#f5f0e4','#161c22','#556b39'].entries())panels.push({input:await sharp({create:{width:800,height:800,channels:4,background:color}}).composite([{input:fs.readFileSync(finished)}]).png().toBuffer(),left:800*i,top:0});
  await sharp({create:{width:2400,height:800,channels:4,background:'#ffffff'}}).composite(panels).png().toFile(path.join(qa,'alpha-check.png'));
  console.log(JSON.stringify({manifest,background:record.background,contacts:checked},null,2));
})();
