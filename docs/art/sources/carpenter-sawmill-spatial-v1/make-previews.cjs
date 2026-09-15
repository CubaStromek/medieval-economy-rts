// Technical crops of observed native frames, never replacement game artwork.
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const qa = path.resolve(__dirname, '../../qa/carpenter-sawmill-spatial-v1');
const caption = (text, width) => Buffer.from(`<svg width="${width}" height="32"><rect width="100%" height="100%" fill="#172019"/><text x="12" y="22" font-family="sans-serif" font-size="16" fill="#eee">${text}</text></svg>`);
async function crop(file) {
  return sharp(file).extract({left:360,top:240,width:245,height:185}).resize(490,370,{kernel:'nearest'}).png().toBuffer();
}
(async()=>{
  const comparison=[];
  for (const [i,version] of ['before','after'].entries()) {
    comparison.push({input:await crop(path.join(qa,version,'motion/work-000.png')),left:i*490,top:32});
    comparison.push({input:caption(i?'Po úpravě':'Před úpravou',490),left:i*490,top:0});
  }
  await sharp({create:{width:980,height:402,channels:4,background:'#172019'}}).composite(comparison).png().toFile(path.join(qa,'before-after.png'));
  const rows=[];
  for(const [i,frame] of [0,7,14,20,27,34].entries()) {
    const x=(i%3)*490,y=Math.floor(i/3)*402;
    rows.push({input:await crop(path.join(qa,'after/motion',`work-${String(frame).padStart(3,'0')}.png`)),left:x,top:y+32});
    rows.push({input:caption(`Pracovní fáze ${i}`,490),left:x,top:y});
  }
  await sharp({create:{width:1470,height:804,channels:4,background:'#172019'}}).composite(rows).png().toFile(path.join(qa,'all-work-poses.png'));
  fs.writeFileSync(path.join(qa,'preview-geometry.json'),JSON.stringify({date:'2026-09-13',kind:'Native screenshot crops only',crop:{left:360,top:240,width:245,height:185},scale:2,filter:'nearest',samples:[0,7,14,20,27,34],detail_video:{source_crop:[710,330,210,170],scale:3,filter:'nearest',timing:'same actual timestamps as full natural video'}},null,2)+'\n');
})().catch(error=>{console.error(error);process.exitCode=1;});
