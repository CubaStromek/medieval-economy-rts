#!/usr/bin/env node
'use strict';
// Format/registration only: fixed scale and explicit landmarks, no retouch/morph.
const fs=require('node:fs'), path=require('node:path'), crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../docs/art/animations/lumberjack-without-log-SE-v2');
const cap=[[530,110],[530,110],[530,132],[530,126],[526,115],[532,141],[534,147],[532,143]];
const bob=[0,2,-2,-3,0,2,-2,-3];
const labels=['Pravá došlapuje','Váha na pravé','Levá prochází','Levá dosahuje','Levá došlapuje','Váha na levé','Pravá prochází','Pravá dosahuje'];
const scale=.32, records=[];
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const info=file=>{const b=fs.readFileSync(file);return{width:b.readUInt32BE(16),height:b.readUInt32BE(20),colorType:b[25],sha256:sha(b)}};
function run(args){const r=spawnSync('ffmpeg',['-hide_banner','-loglevel','error','-y',...args],{encoding:'utf8'});if(r.status!==0)throw Error(r.stderr||String(r.error))}
fs.mkdirSync(path.join(root,'frames'),{recursive:true});
fs.mkdirSync(path.join(root,'previews'),{recursive:true});
for(let i=0;i<8;i++){
 const name=String(i).padStart(2,'0'),source=path.join(root,`keyframes/${name}.png`),meta=info(source);
 const w=Math.round(meta.width*scale),h=Math.round(meta.height*scale);
 const x=Math.round(192-cap[i][0]*scale),y=Math.round(50+bob[i]-cap[i][1]*scale);
 if(x<0||y<0||x+w>384||y+h>512)throw Error('Registration outside frame '+i);
 const target=path.join(root,`frames/${name}.png`);
 run(['-i',source,'-vf',`scale=${w}:${h}:flags=lanczos,pad=384:512:${x}:${y}:color=white,format=rgb24`,'-frames:v','1',target]);
 records.push({index:i,source:`keyframes/${name}.png`,sourceMetadata:meta,scale,capLandmark:cap[i],intendedBob:bob[i],placement:[x,y],file:`frames/${name}.png`,label:labels[i],outputMetadata:info(target)});
}
const manifest={date:'2026-09-09',direction:'SE',frameWidth:384,frameHeight:512,defaultFps:8,frames:records.map(({file,label})=>({file,label})),anchor:[192,440],bodyHeight:396,productionReady:false,alpha:false,status:'single-direction-motion-study'};
fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
fs.writeFileSync(path.join(root,'manifest.js'),'window.WALK_MANIFEST = '+JSON.stringify(manifest,null,2)+';\n');
fs.writeFileSync(path.join(root,'registration.json'),JSON.stringify({date:'2026-09-09',method:'Fixed 0.32 image scale; cap landmark registration plus small authored gait bob; white canvas; no pose deformation or mirrored limbs.',records},null,2)+'\n');
run(['-framerate','8','-i',path.join(root,'frames/%02d.png'),'-vf','tile=4x2:nb_frames=8','-frames:v','1',path.join(root,'previews/contact-sheet.png')]);
for(const fps of [4,8])run(['-framerate',String(fps),'-i',path.join(root,'frames/%02d.png'),'-filter_complex','[0:v]split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',path.join(root,`previews/SE-${fps}fps.gif`)]);
console.log('Packed eight SE frames, atlas and 4/8 fps previews.');
