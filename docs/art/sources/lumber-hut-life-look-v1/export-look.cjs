'use strict';
// Technical color-key extraction, head registration, and immutable-body export.
// All drawn head anatomy comes from the archived built-in image_gen plates.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require(process.env.SHARP_PATH||'sharp');
const root=path.resolve(__dirname,'../../../..');
const out=path.join(root,'game/art/buildings/lumber_hut/v1/life/look');
const originalPath=path.join(out,'../resting_lumberjack.png');
const masterPath=path.join(__dirname,'../lumber-hut-life-v1/resting-lumberjack-rgba-master.png');
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const polygon=[[400,0],[690,0],[690,208],[635,208],[627,238],[621,277],[607,311],[590,351],[582,330],[554,320],[514,307],[486,283],[469,255],[465,229],[444,221],[400,221]];
function inside(x,y){let yes=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if((a[1]>y)!=(b[1]>y)&&x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])yes=!yes;}return yes;}
function bounds(data,predicate){let b=[256,256,0,0],count=0;for(let y=0;y<256;y++)for(let x=0;x<256;x++)if(predicate(data,(y*256+x)*4,x,y)){b=[Math.min(b[0],x),Math.min(b[1],y),Math.max(b[2],x+1),Math.max(b[3],y+1)];count++;}return{bounds:count?b:null,count};}
(async()=>{
 fs.mkdirSync(out,{recursive:true});
 const original=await sharp(originalPath).ensureAlpha().raw().toBuffer();
 const master=await sharp(masterPath).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 fs.copyFileSync(originalPath,path.join(out,'center.png'));
 const frames={center:'center.png',left:'left.png',right:'right.png'};
 const measurements={};
 for(const id of ['left','right']){
  const source=path.join(__dirname,id+'-key-raw.png');
  const {data,info}=await sharp(source).removeAlpha().raw().toBuffer({resolveWithObject:true});
  const rgba=Buffer.alloc(info.width*info.height*4);
  for(let i=0,p=0;i<data.length;i+=3,p+=4){
   const r=data[i],g=data[i+1],b=data[i+2],d=Math.min(r,b)-g;
   const alpha=d>=196?0:Math.max(0,Math.min(1,(244-d)/244));
   rgba[p+3]=Math.round(alpha*255);if(!alpha)continue;
   for(const [c,key] of [[0,248],[1,4],[2,249]])rgba[p+c]=Math.round(Math.max(0,Math.min(255,(data[i+c]-(1-alpha)*key)/alpha)));
  }
  const rgbaMaster=path.join(__dirname,id+'-rgba.png');
  await sharp(rgba,{raw:{width:info.width,height:info.height,channels:4}}).png().toFile(rgbaMaster);
  const normalized=await sharp(rgba,{raw:{width:info.width,height:info.height,channels:4}}).resize(500,430,{kernel:'lanczos3'}).raw().toBuffer();
  const combined=Buffer.from(master.data);
  for(let y=0;y<430;y++)for(let x=0;x<500;x++)if(inside(x+320,y))normalized.copy(combined,((y*master.info.width)+(x+320))*4,(y*500+x)*4,(y*500+x+1)*4);
  const headLayer=await sharp(combined,{raw:{width:master.info.width,height:master.info.height,channels:4}}).extract({left:346,top:45,width:451,height:1273}).resize(58,164,{kernel:'lanczos3'}).raw().toBuffer();
  const final=Buffer.from(original);
  for(let y=0;y<164;y++)for(let x=0;x<58;x++){
   // Explicit original-to-production mapping; never re-register body or boots.
   const px=x+94,py=y+42,mx=346+(x+.5)*451/58,my=45+(y+.5)*1273/164;
   if(py<82&&inside(mx,my))headLayer.copy(final,(py*256+px)*4,(y*58+x)*4,(y*58+x+1)*4);
  }
  const target=path.join(out,id+'.png');await sharp(final,{raw:{width:256,height:256,channels:4}}).png().toFile(target);
  const changed=bounds(final,(d,p)=>!d.subarray(p,p+4).equals(original.subarray(p,p+4)));
  const below=bounds(final,(d,p,x,y)=>y>=82&&!d.subarray(p,p+4).equals(original.subarray(p,p+4)));
  const feet=bounds(final,(d,p,x,y)=>y>=160&&!d.subarray(p,p+4).equals(original.subarray(p,p+4)));
  const alpha=bounds(final,(d,p)=>d[p+3]>25);
  measurements[id]={source_sha256:sha(source),production_sha256:sha(target),changed_bounds_exclusive:changed.bounds,changed_pixels:changed.count,body_different_pixels_below_collar:below.count,feet_different_pixels:feet.count,alpha_bounds_gt25_exclusive:alpha.bounds};
 }
 const registration=JSON.parse(fs.readFileSync(path.join(out,'../resting_lumberjack.json')));
 const boxes=Object.values(measurements).map(m=>m.changed_bounds_exclusive);
 const changedBounds=[Math.min(...boxes.map(b=>b[0])),Math.min(...boxes.map(b=>b[1])),Math.max(...boxes.map(b=>b[2])),Math.max(...boxes.map(b=>b[3]))];
 const manifest={date:'2026-09-12',scope:'Three head-yaw poses on exact original resting body',frames,size:[256,256],production_ground_contact:registration.production_ground_contact,production_body_height_px:registration.production_body_height_px,source_px_to_world:registration.recommended_source_px_to_world,collar_y:82,changed_bounds:changedBounds,changed_bounds_convention:'left,top,right-exclusive,bottom-exclusive',body_policy:'Every RGBA pixel at y>=collar_y and outside the head replacement polygon is byte-identical to resting_lumberjack.png; center is exact original file.',source_head_polygon_master:polygon,original_sha256:sha(originalPath),measurements};
 fs.writeFileSync(path.join(out,'look.json'),JSON.stringify(manifest,null,2)+'\n');
 const tiles=[];let row=0;for(const bg of ['#f4eee2','#171d23','#526334']){let col=0;for(const id of ['left','center','right']){const full=await sharp({create:{width:256,height:256,channels:4,background:bg}}).composite([{input:path.join(out,id+'.png')}]).png().toBuffer();tiles.push({input:full,left:col*256,top:row*256});col++;}row++;}
 await sharp({create:{width:768,height:768,channels:4,background:'#fff'}}).composite(tiles).png().toFile(path.join(__dirname,'alpha-qa.png'));
 const heads=[];for(const [i,id] of ['left','center','right'].entries())heads.push({input:await sharp(path.join(out,id+'.png')).extract({left:96,top:38,width:60,height:52}).resize(360,312,{kernel:'nearest'}).flatten({background:'#66724d'}).png().toBuffer(),left:i*360,top:0});
 await sharp({create:{width:1080,height:312,channels:4,background:'#fff'}}).composite(heads).png().toFile(path.join(__dirname,'head-qa-6x.png'));
 const small=[];for(const [i,id] of ['left','center','right'].entries())small.push({input:await sharp(path.join(out,id+'.png')).resize(52,52,{kernel:'lanczos3'}).png().toBuffer(),left:20+i*72,top:12});
 const normal=await sharp({create:{width:256,height:80,channels:4,background:'#526334'}}).composite(small).png().toBuffer();
 await sharp(normal).png().toFile(path.join(__dirname,'body33px-qa.png'));
 await sharp(normal).resize(1024,320,{kernel:'nearest'}).png().toFile(path.join(__dirname,'body33px-qa-4x.png'));
 console.log(JSON.stringify(manifest,null,2));
})();
