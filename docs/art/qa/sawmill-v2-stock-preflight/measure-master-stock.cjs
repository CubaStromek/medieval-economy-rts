'use strict';
// Geometry QA only: technical extraction/registration of existing own art.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),sharp=require('sharp');
const root=path.resolve(__dirname,'../../../..'),read=p=>JSON.parse(fs.readFileSync(path.join(root,p))),sha=p=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex');
const scale=.18731625,rawHutScale=640/1254*.225,logScale=rawHutScale/scale;
const hut=read('game/art/buildings/lumber_hut/v1/stock/manifest.json');
const house='game/art/buildings/sawmill/v2/finished.png';
const cap0=[365,524],step=[50*logScale,-14*logScale],rise=53*logScale;
const caps=[cap0,[cap0[0]+step[0],cap0[1]+step[1]],[cap0[0],cap0[1]-rise],[cap0[0]+step[0],cap0[1]+step[1]-rise]];
const trim={left:343,top:804,width:126,height:124},capTrim=[445-trim.left,900-trim.top];
const plankTrim=read('docs/art/sources/sawmill-operation-v1/stock-source-measurements.json').sources.plank.trim;
const plankW=76,plankH=plankW*plankTrim.height/plankTrim.width;
const planks=[437,432.2,427.4,382,377.2,372.4].map(y=>[631,y,plankW,plankH]);
const polygons={
  left_room_jamb:[[296,387],[313,382],[313,568],[323,582],[325,594],[307,608],[292,595]],
  cradle_front_left_post:[[321,527],[336,523],[344,531],[350,575],[340,582],[328,577]],
  cradle_front_rail:[[344,539],[399,522],[409,524],[411,537],[349,558]],
  cradle_front_right_post:[[408,507],[423,501],[434,509],[436,551],[424,560],[415,555]],
  center_column:[[455,329],[481,322],[481,546],[458,550]],
  center_column_stone:[[449,548],[471,540],[490,548],[488,570],[499,579],[497,591],[466,599],[440,587],[441,570]],
  center_left_brace:[[388,348],[402,344],[464,413],[464,438]],
  center_right_brace:[[480,392],[532,319],[554,312],[480,426]],
  rack_front_upright:[[698,397],[710,395],[713,415],[718,417],[715,512],[705,519],[697,513]],
  right_column:[[746,255],[770,249],[769,468],[747,477]],
  right_column_stone:[[745,467],[768,462],[777,474],[776,492],[784,501],[779,518],[760,524],[736,513],[734,493],[740,482]],
};
function inside(x,y,ps){let r=false;for(let i=0,j=ps.length-1;i<ps.length;j=i++){const a=ps[i],b=ps[j];if((a[1]>y)!=(b[1]>y)&&x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])r=!r;}return r;}
(async()=>{
 const{data,info}=await sharp(path.join(root,hut.source)).removeAlpha().raw().toBuffer({resolveWithObject:true});
 const logRaw=Buffer.alloc(trim.width*trim.height*4);for(let y=0;y<trim.height;y++)for(let x=0;x<trim.width;x++){const sx=x+trim.left,sy=y+trim.top;if(inside(sx+.5,sy+.5,hut.extraction_polygon)){const p=(y*trim.width+x)*4,q=(sy*info.width+sx)*3;logRaw[p]=data[q];logRaw[p+1]=data[q+1];logRaw[p+2]=data[q+2];logRaw[p+3]=255;}}
 const log=await sharp(logRaw,{raw:{width:trim.width,height:trim.height,channels:4}}).png().toBuffer();fs.writeFileSync(path.join(__dirname,'hut-log-original-extraction.png'),log);
 const plank=await sharp(path.join(root,'docs/art/sources/sawmill-operation-v1/plank-rgba-master.png')).extract(plankTrim).png().toBuffer();
 const draws=[];for(const cap of caps)draws.push({kind:'log',rect:[cap[0]-capTrim[0]*logScale,cap[1]-capTrim[1]*logScale,trim.width*logScale,trim.height*logScale],cap});for(const rect of planks)draws.push({kind:'plank',rect});
 const factor=4,comps=[];for(const d of draws){const r=d.rect.map(v=>Math.round(v*factor));comps.push({input:await sharp(d.kind==='log'?log:plank).resize(r[2],r[3],{fit:'fill'}).png().toBuffer(),left:r[0],top:r[1]});}
 const polySvg='<svg width="800" height="800">'+Object.values(polygons).map(ps=>`<polygon points="${ps.map(p=>p.join(',')).join(' ')}" fill="white"/>`).join('')+'</svg>';
 const mask=await sharp(Buffer.from(polySvg)).png().toBuffer();fs.writeFileSync(path.join(__dirname,'master-stock-occlusion-probe.png'),mask);
 const fg=await sharp(path.join(root,house)).composite([{input:mask,blend:'dest-in'}]).png().toBuffer();
 const full=await sharp(path.join(root,house)).resize(3200,3200,{kernel:'nearest'}).composite(comps).png().toBuffer();
 const composed=await sharp(full).composite([{input:await sharp(fg).resize(3200,3200,{kernel:'nearest'}).png().toBuffer()}]).png().toBuffer();
 const image=await sharp(composed).resize(800,800).png().toBuffer();
 fs.writeFileSync(path.join(__dirname,'master-stock-probe.png'),image);
 await sharp(image).extract({left:280,top:330,width:500,height:290}).resize(1500,870,{kernel:'nearest'}).flatten({background:'#65714c'}).png().toFile(path.join(__dirname,'master-stock-probe-detail-3x.png'));
 const guideSvg='<svg width="800" height="800">'+Object.values(polygons).map(ps=>`<polygon points="${ps.map(p=>p.join(',')).join(' ')}" fill="cyan" fill-opacity=".1" stroke="cyan" stroke-width="1"/>`).join('')+caps.map(p=>`<circle cx="${p[0]}" cy="${p[1]}" r="3" fill="red"/>`).join('')+'</svg>';
 await sharp(path.join(root,house)).composite([{input:Buffer.from(guideSvg)}]).png().toFile(path.join(__dirname,'master-stock-mask-guide.png'));
 fs.writeFileSync(path.join(__dirname,'master-stock-geometry.json'),JSON.stringify({date:'2026-09-12',status:'Preflight against concept04; production blocked until native geometry green',house,house_sha256:sha(house),canvas:[800,800],house_to_world:scale,log_source:hut.source,log_source_sha256:hut.source_sha256,log_raw_to_world:rawHutScale,log_source_crop:trim,log_crop_cap:capTrim,log_source_to_house:logScale,log_cap_positions:caps,log_draws:draws.filter(x=>x.kind==='log'),plank_source:'docs/art/sources/sawmill-operation-v1/plank-rgba-master.png',plank_source_sha256:sha('docs/art/sources/sawmill-operation-v1/plank-rgba-master.png'),plank_source_trim:plankTrim,plank_draws:planks,occlusion_polygons:polygons,ground_contacts:'Existing cradle/rack support feet only; raw prop cap/bottom is not physical ground',notes:['Plank uniform aspect retained from own full-resolution source, no new view generation.','Stock projections must remain behind measured new posts.','No old v1 foreground mask or house samples used.','No production files changed by this QA script.']},null,2)+'\n');
 console.log(JSON.stringify({caps,logScale,plank:[plankW,plankH],plank_world:[plankW*scale,plankH*scale]}));
})().catch(e=>{console.error(e);process.exit(1)});
