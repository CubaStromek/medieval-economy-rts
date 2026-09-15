'use strict';
// Technical alpha extraction and registration only; imagegen owns all artwork.
const fs=require('fs');
const path=require('path');
const crypto=require('crypto');
const sharp=require(process.env.SHARP_PATH || 'sharp');
const root=path.resolve(__dirname,'../../../..');
const out=path.join(root,'game/art/buildings/lumber_hut/v1/life');
const source=path.join(__dirname,'resting-lumberjack-key-v3-rgb.png');
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
function stats(data,w,h){
  const count={transparent:0,partial:0,opaque:0};const boxes={};
  for(const t of [0,25,127])boxes[t]=[w,h,-1,-1];
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const a=data[(y*w+x)*4+3];count[a===0?'transparent':a===255?'opaque':'partial']++;
    for(const t of [0,25,127])if(a>t){const b=boxes[t];b[0]=Math.min(b[0],x);b[1]=Math.min(b[1],y);b[2]=Math.max(b[2],x+1);b[3]=Math.max(b[3],y+1);}
  }
  return{canvas:[w,h],counts:count,alpha_bounds_exclusive:boxes};
}
(async()=>{
  fs.mkdirSync(out,{recursive:true});
  const {data,info}=await sharp(source).removeAlpha().raw().toBuffer({resolveWithObject:true});
  const rgba=Buffer.alloc(info.width*info.height*4);
  for(let i=0,p=0;i<data.length;i+=3,p+=4){
    const [r,g,b]=[data[i],data[i+1],data[i+2]],dominance=Math.min(r,b)-g;
    // Measured empty regions: dominance204..251; own foreground samples:-103..0.
    // Threshold196 leaves an8-byte safety margin from observed empty pixels.
    const a=dominance>=196?0:Math.max(0,Math.min(1,(247-dominance)/247));
    rgba[p+3]=Math.round(a*255);if(a===0)continue;
    if(a===1){rgba[p]=r;rgba[p+1]=g;rgba[p+2]=b;continue;}
    // Measured modal key is(251,3,250), not the requested ideal(255,0,255).
    rgba[p]=Math.round(Math.max(0,Math.min(255,(r-(1-a)*251)/a)));
    rgba[p+1]=Math.round(Math.max(0,Math.min(255,(g-(1-a)*3)/a)));
    rgba[p+2]=Math.round(Math.max(0,Math.min(255,(b-(1-a)*250)/a)));
  }
  const rawStats=stats(rgba,info.width,info.height);
  const master=path.join(__dirname,'resting-lumberjack-rgba-master.png');
  await sharp(rgba,{raw:{width:info.width,height:info.height,channels:4}}).png().toFile(master);
  // One whole-image registration, never independently moved body parts.
  const trim={left:346,top:45,width:451,height:1273};
  const resized={width:58,height:164};
  const placement={left:94,top:42};
  const layer=await sharp(rgba,{raw:{width:info.width,height:info.height,channels:4}}).extract(trim).resize(resized.width,resized.height,{kernel:'lanczos3'}).png().toBuffer();
  const production=path.join(out,'resting_lumberjack.png');
  await sharp({create:{width:256,height:256,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:layer,...placement}]).png().toFile(production);
  const prod=await sharp(production).raw().toBuffer();
  const prodStats=stats(prod,256,256);
  const registration={date:'2026-09-12',scope:'Single static leaning rest pose; no directions or motion',source:'docs/art/sources/lumber-hut-life-v1/resting-lumberjack-key-v3-rgb.png',master:'docs/art/sources/lumber-hut-life-v1/resting-lumberjack-rgba-master.png',production:'game/art/buildings/lumber_hut/v1/life/resting_lumberjack.png',source_sha256:sha(source),master_sha256:sha(master),production_sha256:sha(production),trim,resized,placement,source_ground_contact:[614,1312],production_ground_contact:[128.46563192904655,205.229379418696],source_cap_top:[542,50],source_body_height_px:1263,production_body_height_px:162.71,source_to_production:[58/451,164/1273],recommended_world_body_height_px:33,recommended_source_px_to_world:33/162.71,anatomy:'Folded empty hands; no axe/log; weight on straight anatomical right leg; anatomical left leg bent. Slight three-quarter facing screen-right.',technical_alpha:{observed_empty_dominance_range:[204,251],observed_foreground_region_dominance_range:[-103,0],measured_modal_background:[251,3,250],transparent_dominance_threshold:196,antialias_unmatte:'alpha=(247-min(r,b)+g)/247 below key threshold; straight-alpha unmatte with measured modal key'},asset_measurements:prodStats};
  fs.writeFileSync(path.join(out,'resting_lumberjack.json'),JSON.stringify(registration,null,2)+'\n');
  const tiles=[];for(const [i,color]of ['#f4eee2','#171d23','#526334'].entries())tiles.push({input:await sharp({create:{width:256,height:256,channels:4,background:color}}).composite([{input:fs.readFileSync(production)}]).png().toBuffer(),left:i*256,top:0});
  await sharp({create:{width:768,height:256,channels:4,background:'#ffffff'}}).composite(tiles).png().toFile(path.join(__dirname,'resting-lumberjack-alpha-qa.png'));
  fs.writeFileSync(path.join(__dirname,'resting-lumberjack-raw-measurements.json'),JSON.stringify({source_sha256:sha(source),master_sha256:sha(master),...rawStats},null,2)+'\n');
  console.log(JSON.stringify({raw:rawStats,production:prodStats,registration}));
})();
