'use strict';
// Author-defined parts only: fixed lower body/support arm from frame0,
// registered original six near-arm/upper-body poses, one rigid steel blade.
// No generated/interpolated motion, no per-frame foot normalization.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),sharp=require('sharp');
const root=path.resolve(__dirname,'../../../..'),source=path.join(__dirname,'carpenter-cycle-key.png');
const out=path.join(root,'game/art/buildings/sawmill/v1/operation/work'),qa=path.join(root,'docs/art/qa/sawmill-operation-v1');
const sha=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const registrations=[[0,0],[32,0],[35,0],[0,34],[32,33],[33,33]];
const waistY=282;
const nearArmMask=[[369,140],[385,135],[512,135],[512,282],[256,282],[256,229],[322,214],[350,193],[369,190]];
const supportMask=[[110,225],[161,207],[206,175],[248,149],[281,142],[294,157],[309,177],[290,203],[276,218],[245,227],[232,251],[195,267],[110,267]];
const bladeMasks=[[[89,262],[259,233],[269,279],[91,280]],[[87,259],[252,225],[263,275],[89,278]],[[120,259],[253,232],[265,276],[122,278]],[[152,228],[305,199],[316,244],[155,246]],[[83,227],[240,199],[250,244],[85,246]],[[63,227],[224,199],[235,244],[65,246]]];
const bladeJoins=[[259,234],[251,229],[252,233],[304,200],[239,200],[223,200]];
const fixedBladeMask=[[89,262],[259,233],[268,278],[91,280]];
function inside(x,y,ps){let yes=false;for(let i=0,j=ps.length-1;i<ps.length;j=i++){const a=ps[i],b=ps[j];if((a[1]>y)!=(b[1]>y)&&x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])yes=!yes;}return yes;}
function edgeDistance(x,y,ps){let d=Infinity;for(let i=0;i<ps.length;i++){const a=ps[i],b=ps[(i+1)%ps.length],vx=b[0]-a[0],vy=b[1]-a[1],t=Math.max(0,Math.min(1,((x-a[0])*vx+(y-a[1])*vy)/(vx*vx+vy*vy)));d=Math.min(d,Math.hypot(x-a[0]-t*vx,y-a[1]-t*vy));}return d;}
function bounds(data,filter=()=>true){let b=[512,512,-1,-1],n=0;for(let y=0;y<512;y++)for(let x=0;x<512;x++){const p=(y*512+x)*4;if(data[p+3]>127&&filter(x,y)){n++;b=[Math.min(b[0],x),Math.min(b[1],y),Math.max(b[2],x+1),Math.max(b[3],y+1)];}}return{bounds:b,pixels:n};}
function overlay(dst,src){for(let p=0;p<dst.length;p+=4){const sa=src[p+3]/255,da=dst[p+3]/255,a=sa+da*(1-sa);if(!a)continue;for(let c=0;c<3;c++)dst[p+c]=Math.round((src[p+c]*sa+dst[p+c]*da*(1-sa))/a);dst[p+3]=Math.round(a*255);}return dst;}
function translate(data,dx,dy){const d=Buffer.alloc(data.length);for(let y=0;y<512;y++)for(let x=0;x<512;x++){const xx=x+dx,yy=y+dy;if(xx>=0&&xx<512&&yy>=0&&yy<512)data.copy(d,(yy*512+xx)*4,(y*512+x)*4,(y*512+x+1)*4);}return d;}
function clearDetachedFragments(data){const seen=new Uint8Array(512*512),removed=[];for(let y=0;y<512;y++)for(let x=0;x<512;x++){const q=y*512+x;if(seen[q]||data[q*4+3]<25)continue;const part=[q];seen[q]=1;for(let k=0;k<part.length;k++){const j=part[k],px=j%512,py=Math.floor(j/512);for(const [xx,yy]of[[px-1,py],[px+1,py],[px,py-1],[px,py+1]])if(xx>=0&&xx<512&&yy>=0&&yy<512){const t=yy*512+xx;if(!seen[t]&&data[t*4+4-1]>=25){seen[t]=1;part.push(t);}}}if(part.length<200){let b=[512,512,0,0];for(const j of part){const px=j%512,py=Math.floor(j/512);b=[Math.min(b[0],px),Math.min(b[1],py),Math.max(b[2],px+1),Math.max(b[3],py+1)];data.fill(0,j*4,j*4+4);}removed.push({pixels:part.length,bounds:b});}}return removed;}
(async()=>{
 fs.mkdirSync(out,{recursive:true});const{data,info}=await sharp(source).removeAlpha().raw().toBuffer({resolveWithObject:true});if(info.width!==1536||info.height!==1024)throw Error('Unexpected sheet dimensions');
 const frames=[];for(let n=0;n<6;n++){const d=Buffer.alloc(512*512*4);for(let y=0;y<512;y++)for(let x=0;x<512;x++){const s=(((Math.floor(n/3)*512+y)*1536)+(n%3)*512+x)*3,p=(y*512+x)*4,k=Math.min(data[s],data[s+2])-data[s+1],a=k>=190?0:Math.max(0,Math.min(1,(247-k)/247));d[p+3]=Math.round(a*255);if(a)for(let c=0;c<3;c++)d[p+c]=Math.round(Math.max(0,Math.min(255,(data[s+c]-(1-a)*[251,3,250][c])/a)));}frames.push(d);}
 const blade=Buffer.alloc(frames[0].length);for(let y=0;y<512;y++)for(let x=0;x<512;x++){const p=(y*512+x)*4,d=frames[0];if(inside(x+.5,y+.5,fixedBladeMask)&&Math.max(d[p],d[p+1],d[p+2])-Math.min(d[p],d[p+1],d[p+2])<65&&d[p+2]>=d[p]-24)d.copy(blade,p,p,p+4);}
 await sharp(blade,{raw:{width:512,height:512,channels:4}}).png().toFile(path.join(__dirname,'worker-rigid-blade.png'));
 const cleared=frames.map((src,i)=>{const d=Buffer.from(src);for(let y=0;y<512;y++)for(let x=0;x<512;x++)if(inside(x+.5,y+.5,bladeMasks[i])){const p=(y*512+x)*4;
  if(Math.max(d[p],d[p+1],d[p+2])-Math.min(d[p],d[p+1],d[p+2])<80&&d[p+2]>=d[p]-35)d.fill(0,p,p+4);}
  return d;});
 const support=Buffer.alloc(frames[0].length);for(let y=0;y<512;y++)for(let x=0;x<512;x++)if(inside(x+.5,y+.5,supportMask))cleared[0].copy(support,(y*512+x)*4,(y*512+x)*4,(y*512+x+1)*4);
 await sharp(support,{raw:{width:512,height:512,channels:4}}).png().toFile(path.join(__dirname,'worker-fixed-support-arm.png'));
 const baseBody=cleared[0],delivered=[],measurements=[];
 const baseExtent=bounds(frames[0],(x,y)=>x>200);const hairTop=baseExtent.bounds[1];
 const leftFoot=bounds(frames[0],(x,y)=>x>=270&&x<370&&y>400),rightFoot=bounds(frames[0],(x,y)=>x>=370&&y>400);
 const foot=[((leftFoot.bounds[0]+leftFoot.bounds[2])/2+(rightFoot.bounds[0]+rightFoot.bounds[2])/2)/2,Math.max(leftFoot.bounds[3],rightFoot.bounds[3])];
 const bodyHeight=foot[1]-hairTop;
 for(let n=0;n<6;n++){
  const[dx,dy]=registrations[n],donor=translate(cleared[n],dx,dy),body=Buffer.from(baseBody);
  // Keep source0 head, torso, support arm and hips. Copy only authored near-arm
  // envelope plus its apron underpaint so no invisible torso holes are invented.
  for(let y=0;y<waistY;y++)for(let x=0;x<512;x++)if(inside(x+.5,y+.5,nearArmMask)){const p=(y*512+x)*4,t=body[p+3]>240&&donor[p+3]>240?Math.min(1,edgeDistance(x+.5,y+.5,nearArmMask)/10):1;for(let c=0;c<4;c++)body[p+c]=Math.round(body[p+c]*(1-t)+donor[p+c]*t);}
  const join=[bladeJoins[n][0]+dx,bladeJoins[n][1]+dy],toolOffset=[join[0]-bladeJoins[0][0],join[1]-bladeJoins[0][1]],rigid=translate(blade,...toolOffset);
  const removedFragments=clearDetachedFragments(body),final=overlay(rigid,body);const file=path.join(out,'worker-'+n+'.png');await sharp(final,{raw:{width:512,height:512,channels:4}}).png().toFile(file);delivered.push(final);
  let lowerDiff=0,supportDiff=0,headDiff=0,magenta=0;for(let y=0;y<512;y++)for(let x=0;x<512;x++){const p=(y*512+x)*4;if(final[p+3]>25&&Math.min(final[p],final[p+2])-final[p+1]>45)magenta++;if(n&&!final.subarray(p,p+4).equals(delivered[0].subarray(p,p+4))){if(y>=waistY)lowerDiff++;if(x>=250&&x<350&&y>=70&&y<181)headDiff++;if(support[p+3]===255)supportDiff++;}}
  if(lowerDiff||supportDiff||headDiff||magenta)throw Error('Frame invariant failed '+n+': '+[lowerDiff,supportDiff,headDiff,magenta]);
  measurements.push({frame:n,path:'worker-'+n+'.png',sha256:sha(file),source_cell:[(n%3)*512,Math.floor(n/3)*512,512,512],registration:[dx,dy],registered_handle_blade_join:join,rigid_blade_translation:toolOffset,detached_composition_fragments_removed:removedFragments,body_lower_different_pixels_y_ge_282:lowerDiff,fixed_head_different_pixels:headDiff,opaque_support_different_pixels:supportDiff,residual_magenta_pixels:magenta,alpha_gt127:bounds(final)});
 }
 const metadata={schema_version:1,date:'2026-09-12',frames:measurements.map(m=>m.path),canvas:[512,512],body_height_px:bodyHeight,ground_contact:foot,hair_top_y:hairTop,desired_world_body_height:33,source_to_world:33/bodyHeight,source_sheet:'docs/art/sources/sawmill-operation-v1/carpenter-cycle-key.png',source_sha256:sha(source),source_cells:'3 columns × 2 rows; original six authored poses, no interpolated morph frames',registration_policy:'Integer translations from fixed apron-waist patch comparison (x307..419,y281..334 in source0), not foot/bounding-box alignment. Exact source0 base outside authored near-arm envelope; source0 head, support arm, torso, hips and feet are retained. The donor near-arm region includes its apron underpaint.',waist_y:waistY,authored_near_arm_mask:nearArmMask,fixed_support_mask:supportMask,fixed_support_source:0,fixed_support_layer_sha256:sha(path.join(__dirname,'worker-fixed-support-arm.png')),rigid_blade_source:0,rigid_blade_mask:fixedBladeMask,removed_blade_masks:bladeMasks,rigid_blade_layer_sha256:sha(path.join(__dirname,'worker-rigid-blade.png')),rigid_blade_policy:'Same steel pixels/orientation and dimensions in every frame, only integer translation to the measured original wooden-handle join. Authored near forearm/hand/handle retained.',body_foot_extents_frame0:{left:leftFoot,right:rightFoot},measurements,normal_game_qa:'Not performed by this export; root renderer must inspect arm/log contact and occlusion at33worldpx.'};
 metadata.alpha_key={measured_modal_rgb:[251,3,250],dominance_definition:'min(R,B)-G',transparent_cutoff:190,unmatte_denominator:247,method:'Measured solid-key removal, fractional alpha and RGB unmatting; no printed checkerboard and no shadow generated under feet.'};
 metadata.authored_layer_edge_blend={width_source_px:10,world_width_px:10*33/bodyHeight,policy:'Only the inside edge of near-arm selection where both source0 and donor alpha exceed240; source RGB colors are blended across this registration seam. No motion frames, pose morphing, retiming, foot normalization or tool scaling are synthesized.'};
 metadata.fixed_head_region=[250,70,350,181];
 metadata.fragment_cleanup={policy:'Before placing rigid steel, remove disconnected body-composition components smaller than200pixels (4-connected,alpha>=25). Measured removals per frame; this removes stray original far-arm fragments and original steel-key edge islands, not any rigid-blade teeth.'};
 fs.writeFileSync(path.join(out,'worker-geometry.json'),JSON.stringify(metadata,null,2)+'\n');
 const tiles=[];for(let n=0;n<6;n++)tiles.push({input:await sharp(delivered[n],{raw:{width:512,height:512,channels:4}}).flatten({background:'#65734d'}).png().toBuffer(),left:n%3*512,top:Math.floor(n/3)*512});await sharp({create:{width:1536,height:1024,channels:4,background:'#65734d'}}).composite(tiles).png().toFile(path.join(qa,'worker-cycle-registered-sheet.png'));
 const detail=[];for(let n=0;n<6;n++)detail.push({input:await sharp(delivered[n],{raw:{width:512,height:512,channels:4}}).extract({left:70,top:140,width:375,height:170}).resize(750,340,{kernel:'nearest'}).flatten({background:'#65734d'}).png().toBuffer(),left:n%3*750,top:Math.floor(n/3)*340});await sharp({create:{width:2250,height:680,channels:4,background:'#65734d'}}).composite(detail).png().toFile(path.join(qa,'worker-cycle-hands-2x.png'));
 console.log(JSON.stringify(metadata));
})().catch(e=>{console.error(e);process.exit(1)});
