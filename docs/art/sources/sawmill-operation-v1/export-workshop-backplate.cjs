const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '../../../..');
const target = path.join(root, 'game/art/buildings/sawmill/v1/operation/work');
const qa = path.join(root, 'docs/art/qa/sawmill-operation-v1');
const polygon = [[409,402], [538,393], [540,473], [412,482]];
function inside(x,y) {
  let hit=false;
  for(let i=0,j=polygon.length-1;i<polygon.length;j=i++) {
    const a=polygon[i],b=polygon[j];
    if(((a[1]>y)!=(b[1]>y)) && x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]) hit=!hit;
  }
  return hit;
}
function edgeDistance(x,y) {
  let d=Infinity;
  for(let i=0;i<polygon.length;i++) {
    const a=polygon[i],b=polygon[(i+1)%polygon.length];
    const dx=b[0]-a[0],dy=b[1]-a[1];
    const t=Math.max(0,Math.min(1,((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy)));
    d=Math.min(d,Math.hypot(x-a[0]-t*dx,y-a[1]-t*dy));
  }
  return d;
}
(async()=>{
  fs.mkdirSync(target,{recursive:true});fs.mkdirSync(qa,{recursive:true});
  const raw=await sharp(path.join(__dirname,'workshop-without-saw-raw.png')).resize(800,800).ensureAlpha().raw().toBuffer();
  for(let y=0;y<800;y++) for(let x=0;x<800;x++) {
    const p=(y*800+x)*4;
    raw[p+3]=inside(x+.5,y+.5)?Math.round(255*Math.min(1,edgeDistance(x+.5,y+.5)/2)):0;
    if(raw[p+3]===0)raw.fill(0,p,p+4);
  }
  const output=path.join(target,'backplate.png');
  await sharp(raw,{raw:{width:800,height:800,channels:4}}).png().toFile(output);
  await sharp(path.join(root,'game/art/buildings/sawmill/v1/finished.png')).composite([{input:output}]).png().toFile(path.join(qa,'backplate-check.png'));
  await sharp(path.join(__dirname,'log-rgba-master.png')).trim()
    .rotate(-30,{background:{r:0,g:0,b:0,alpha:0}}).trim()
    .resize({width:352,height:88,fit:'fill'}).png().toFile(path.join(target,'processing-log.png'));
  fs.writeFileSync(path.join(target,'processing-log.json'),JSON.stringify({
    source:'docs/art/sources/sawmill-operation-v1/log-rgba-master.png',
    operation:'Trim real alpha, rotate -30 degrees to bench direction, resample to 352x88',
    draw_rect_house:[429,467,88,22],
    state:'One committed recipe input when process_remaining > 0, independent of stored input quantity'
  },null,2)+'\n');
  fs.writeFileSync(path.join(target,'backplate.json'),JSON.stringify({canvas:[800,800],polygon,edge_feather_px:2,source:'docs/art/sources/sawmill-operation-v1/workshop-without-saw-raw.png',note:'Only generated dark wall patch is composited; original structure, bench, ground and all outer alpha remain exact.'},null,2)+'\n');
  console.log(output);
})();
