'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require(process.env.SHARP_PATH||'sharp');
const out=path.resolve(__dirname,'../../../../game/art/buildings/lumber_hut/v1/life/look');
const hash=data=>crypto.createHash('sha256').update(data).digest('hex');
(async()=>{
 const original=await sharp(path.join(out,'../resting_lumberjack.png')).ensureAlpha().raw().toBuffer();
 const originalFile=fs.readFileSync(path.join(out,'../resting_lumberjack.png'));
 const report={date:'2026-09-12',protected_collar_y:82,body_region_pixels:256*(256-82),original_body_sha256:hash(original.subarray(82*256*4)),frames:{}};
 for(const name of ['center','left','right']){
  const {data,info}=await sharp(path.join(out,name+'.png')).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  if(info.width!==256||info.height!==256||info.channels!==4)throw Error(name+' canvas');
  const body=data.subarray(82*256*4);if(!body.equals(original.subarray(82*256*4)))throw Error(name+' body changed');
  const feet=data.subarray(160*256*4);if(!feet.equals(original.subarray(160*256*4)))throw Error(name+' feet changed');
  let changed=0,outside=0,transparent=0,partial=0,opaque=0,magenta=0;
  for(let y=0;y<256;y++)for(let x=0;x<256;x++){
   const p=(y*256+x)*4,a=data[p+3];if(!a)transparent++;else if(a===255)opaque++;else partial++;
   if(!data.subarray(p,p+4).equals(original.subarray(p,p+4))){changed++;if(x<104||x>=136||y<42||y>=81)outside++;}
   if(x>=104&&x<136&&y>=42&&y<81&&a>127&&Math.min(data[p],data[p+2])-data[p+1]>80)magenta++;
  }
  if(outside)throw Error(name+' unexpected changed bounds');
  const samples={outer_corner:data[3],between_legs:data[(147*256+129)*4+3],sole:data[(204*256+128)*4+3],below_sole:data[(206*256+127)*4+3]};
  if(samples.outer_corner!==0||samples.between_legs!==0||samples.sole!==255||samples.below_sole!==0)throw Error(name+' alpha probes');
  report.frames[name]={canvas:[info.width,info.height],channels:info.channels,changed_pixels:changed,changed_outside_declared_bounds:outside,body_sha256:hash(body),feet_sha256:hash(feet),protected_body_pixels_equal:true,alpha_counts:{transparent,partial,opaque},alpha_samples:samples,head_pixels_with_strong_magenta_at_alpha_gt127:magenta,file_sha256:hash(fs.readFileSync(path.join(out,name+'.png')))};
 }
 report.center_exact_original_file=fs.readFileSync(path.join(out,'center.png')).equals(originalFile);
 if(!report.center_exact_original_file)throw Error('center not exact original');
 fs.writeFileSync(path.join(__dirname,'verification.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
})();
