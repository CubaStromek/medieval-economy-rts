'use strict';
// Read-only production measurements; all generated files are isolated QA.
const fs = require('fs'), path = require('path'), crypto = require('crypto'), sharp = require('sharp');
const root = path.resolve(__dirname, '../../../..');
const read = p => JSON.parse(fs.readFileSync(path.join(root, p)));
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(path.join(root, p))).digest('hex');
function bounds(data, w, h, threshold) {
  let n=0, b=[w,h,0,0];
  for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(data[(y*w+x)*4+3]>threshold){n++;b=[Math.min(b[0],x),Math.min(b[1],y),Math.max(b[2],x+1),Math.max(b[3],y+1)];}
  return {threshold, pixels:n, bounds:b, size:[b[2]-b[0],b[3]-b[1]]};
}
(async()=>{
  const hut=read('game/art/buildings/lumber_hut/v1/stock/manifest.json');
  const specs=[
    ['hut-log','game/art/buildings/lumber_hut/v1/stock/logs-1.png',0.225],
    ['hut-four','game/art/buildings/lumber_hut/v1/stock/logs-4.png',0.225],
    ['hut-six','game/art/buildings/lumber_hut/v1/stock/logs-6.png',0.225],
    ['sawmill-v1-log','game/art/buildings/sawmill/v1/operation/stock/log.png',0.2508],
    ['sawmill-v1-plank','game/art/buildings/sawmill/v1/operation/stock/plank.png',0.2508],
  ], measures=[],crops={};
  for(const[id,file,scale]of specs){
    const {data,info}=await sharp(path.join(root,file)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    const alpha=[0,25,127].map(t=>bounds(data,info.width,info.height,t));
    const b=alpha[1].bounds;
    crops[id]=await sharp(path.join(root,file)).extract({left:b[0],top:b[1],width:b[2]-b[0],height:b[3]-b[1]}).png().toBuffer();
    fs.writeFileSync(path.join(__dirname,id+'-crop.png'),crops[id]);
    measures.push({id,file,sha256:hash(file),canvas:[info.width,info.height],source_to_world:scale,alpha:alpha.map(a=>({...a,world_size:a.size.map(v=>v*scale)}))});
  }
  const capStep=hut.slots[1].pixel.map((v,i)=>(v-hut.slots[0].pixel[i])*0.225);
  const layerRise=53*640/1254*0.225;
  const logSize=measures[0].alpha[1].world_size;
  const slots=[[0,0],capStep,[0,-layerRise],[capStep[0],capStep[1]-layerRise]];
  const union=[logSize[0]+capStep[0],logSize[1]-capStep[1]+layerRise];
  const proposed={
    status:'Preflight before sawmill-v2 master; no absolute stock anchor is final',
    house_canvas:[800,800],house_to_world:0.25,
    log:{source:hut.source,source_sha256:hut.source_sha256,extraction_polygon:hut.extraction_polygon,source_cap:hut.source_cap,method:'Reuse the exact own hut log through its existing high-resolution source extraction; no camera warp or new generation',single_alpha_gt25_world:logSize,cap_offset_world:slots,cap_offset_house:slots.map(p=>p.map(v=>v/0.25)),layout:'2 lower +2 upper; lower near-left, lower right, upper near-left, upper right',conservative_stack_world:union,reserved_rack_world:[26,27],reserved_rack_house:[104,108],foreground:'Measure new front posts/rail only after master; never copy v1 occlusion mask'},
    plank:{status:'Proposed size/orientation, not measured new artwork',single_target_world:[13.5,11],single_target_house:[54,44],front_edge_direction:[1,-0.28],length_direction:'Recede up-left, visually parallel to the reused hut log; expose the top plane',slot_y_world:[0,-0.9,-1.8,-9.2,-10.1,-11],stack_envelope_world:[13.5,22],reserved_rack_world:[22,28],reserved_rack_house:[88,112],export:'Prefer a new own plank matching finished v2 perspective; v1 full-resolution plank may be material reference, not a squeezed production texture'},
    worker:{height_world:33,current_source_height:412,ground_contact:[374.5,489],foot_spread_world:190*33/412,recommendation:'Try the current six-pose identity first at exactly33worldpx; reassess actual shoulder/top-plane view and hand/tool/bench contacts after v2 master. No independent camera regeneration is established by this preflight.'}
  };
  fs.writeFileSync(path.join(__dirname,'measurements.json'),JSON.stringify({date:'2026-09-12',scope:'Actual existing props plus labeled pre-master geometry proposal; no production mutations',measurements:measures,proposal:proposed},null,2)+'\n');
  // Comparison at common 8x world scale, independent of the houses' PNG size.
  const scale=8,comps=[];
  const draw=async(id,x,y)=>{const m=measures.find(m=>m.id===id),s=m.alpha[1].world_size;comps.push({input:await sharp(crops[id]).resize(Math.round(s[0]*scale),Math.round(s[1]*scale)).png().toBuffer(),left:x,top:y});};
  await draw('hut-log',42,82);await draw('sawmill-v1-log',240,82);await draw('sawmill-v1-plank',431,82);
  const origin=[64,348];for(const offset of slots){const s=logSize;comps.push({input:await sharp(crops['hut-log']).resize(Math.round(s[0]*scale),Math.round(s[1]*scale)).png().toBuffer(),left:Math.round(origin[0]+offset[0]*scale),top:Math.round(origin[1]+offset[1]*scale)});}
  const labelSvg=`<svg width="800" height="510"><style>text{font-family:Arial;fill:#f0ede3;font-size:17px}.small{font-size:14px;fill:#d7d7c7}</style><text x="24" y="29">Existing props at the same world scale (8x)</text><text x="42" y="64">Hut log</text><text x="240" y="64">Sawmill v1 log</text><text x="431" y="64">Sawmill v1 plank</text><text x="42" y="216" class="small">${logSize[0].toFixed(2)} x ${logSize[1].toFixed(2)} world px</text><text x="240" y="216" class="small">9.53 x 6.77 world px</text><text x="431" y="216" class="small">19.06 x 10.28 world px</text><text x="24" y="257">Proposed 2+2 reuse — no new building anchors yet</text><rect x="43" y="264" width="208" height="216" fill="none" stroke="#97b574"/><text x="303" y="321">4 logs: ~${union[0].toFixed(2)} x ${union[1].toFixed(2)} world px</text><text x="303" y="351">Reserve cradle: 26 x 27 world px</text><text x="303" y="380" class="small">New 800px house at 0.25: reserve104 x108px</text><text x="303" y="407" class="small">Six boards: reserve22 x28worldpx in two tiers</text><text x="303" y="434" class="small">New posts/rails must supply new occlusion masks</text><text x="303" y="474" class="small">Technical QA: actual own sprites; no image generation</text></svg>`;
  comps.push({input:Buffer.from(labelSvg)});
  await sharp({create:{width:800,height:510,channels:4,background:'#566147'}}).composite(comps).png().toFile(path.join(__dirname,'comparison.png'));
  console.log(JSON.stringify({measured:measures.map(m=>({id:m.id,alpha25:m.alpha[1]})),proposal:proposed}));
})().catch(e=>{console.error(e);process.exit(1)});
