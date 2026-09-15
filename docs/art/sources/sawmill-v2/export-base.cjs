'use strict';
// Technical alpha export and measured uniform registration; no artwork synthesis.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),sharp=require('sharp');
const root=path.resolve(__dirname,'../../../..'),out=path.join(root,'game/art/buildings/sawmill/v2'),qa=path.join(root,'docs/art/qa/sawmill-v2');
const rawScale=0.1195,ratio=800/1254,nav=[400,1032],key=[248,4,247];
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function bounds(b,w,h,t){let x0=w,y0=h,x1=-1,y1=-1,n=0;for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(b[(y*w+x)*4+3]>t){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);n++;}return {bbox:[x0,y0,x1-x0+1,y1-y0+1],pixels:n};}
(async()=>{
 fs.mkdirSync(out,{recursive:true});fs.mkdirSync(qa,{recursive:true});
 const source=path.join(__dirname,'concept-04-key.png');
 const {data,info}=await sharp(source).removeAlpha().raw().toBuffer({resolveWithObject:true});
 if(info.width!==1254||info.height!==1254)throw Error('Source changed: remeasure');
 const rgba=Buffer.alloc(1254*1254*4);
 for(let i=0,p=0;i<data.length;i+=3,p+=4){const d=Math.min(data[i],data[i+2])-data[i+1];const a=d>=180?0:Math.max(0,Math.min(1,1-d/243));rgba[p+3]=Math.round(a*255);if(!a)continue;for(let c=0;c<3;c++)rgba[p+c]=Math.round(Math.max(0,Math.min(255,(data[i+c]-(1-a)*key[c])/a)));}
 await sharp(rgba,{raw:{width:1254,height:1254,channels:4}}).png().toFile(path.join(__dirname,'finished-rgba-master.png'));
 const file=path.join(out,'finished.png');await sharp(rgba,{raw:{width:1254,height:1254,channels:4}}).resize(800,800,{kernel:'lanczos3'}).png().toFile(file);
 const px=await sharp(file).raw().toBuffer(),b=bounds(px,800,800,25);
 const manifest={schema_version:1,building_id:'sawmill',asset_version:'v2',canvas:[800,800],finished_image:'finished.png',finished_sha256:hash(fs.readFileSync(file)),finished_rgba_sha256:hash(px),alpha_bbox:b.bbox,door_threshold:nav.map(v=>v*ratio),sort_foot:nav.map(v=>v*ratio),label_anchor:[630,28].map(v=>v*ratio),source_to_world:rawScale/ratio};
 const manifestPath=path.join(out,'manifest.json');if(fs.existsSync(manifestPath)){const prev=JSON.parse(fs.readFileSync(manifestPath));for(const k of ['life','operation'])if(prev[k])manifest[k]=prev[k];}
 fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+'\n');
 const sample=[];const histogram={};for(let y=0;y<1254;y++)for(let x=0;x<1254;x++){if(y>35&&y<1100&&x>10&&x<1244)continue;const i=(y*1254+x)*3,v=[data[i],data[i+1],data[i+2]];sample.push(Math.min(v[0],v[2])-v[1]);histogram[v.join(',')]=(histogram[v.join(',')]||0)+1;}sample.sort((a,b)=>a-b);
 fs.writeFileSync(path.join(qa,'base-export.json'),JSON.stringify({date:'2026-09-12',source:'docs/art/sources/sawmill-v2/concept-04-key.png',source_sha256:hash(fs.readFileSync(source)),finished_sha256:manifest.finished_sha256,finished_rgba_sha256:manifest.finished_rgba_sha256,source_canvas:[1254,1254],canvas:[800,800],raw_to_world:rawScale,source_to_production:ratio,production_to_world:manifest.source_to_world,navigation_contact_source:nav,background_sample:{pixels:sample.length,minimum_dominance:sample[0],p001_dominance:sample[Math.floor(sample.length*.001)],maximum_dominance:sample.at(-1),modal_rgb:Object.entries(histogram).sort((a,b)=>b[1]-a[1])[0],unmatte_key:key,cutoff:180,unmatte:'a=clamp(1-d/243); pure key d>=180 removed'},alpha_gt_0:bounds(px,800,800,0),alpha_gt_25:b,geometry_review:'First concept corrected for adult door height and width before any state layers; source contacts and native ground review recorded separately; nav extends 2 raw pixels past source03 bottom for uniform resize edge coverage',runtime_qa:'Not proven by export'},null,2)+'\n');
 console.log(JSON.stringify({manifest,alpha:b}));
})();
