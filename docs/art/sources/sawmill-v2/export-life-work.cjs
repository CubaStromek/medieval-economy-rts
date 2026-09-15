const fs=require('fs'),path=require('path'),sharp=require('sharp'),crypto=require('crypto');
const root=path.resolve(__dirname,'../../../..'), r=800/1254;
const game=path.join(root,'game'), dst=path.join(game,'art/buildings/sawmill/v2');
const p=xy=>xy.map(n=>n*r), q=a=>a.map(p), sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
(async()=>{
 const house=JSON.parse(fs.readFileSync(path.join(dst,'manifest.json'))),old=JSON.parse(fs.readFileSync(path.join(game,'art/buildings/sawmill/v1/manifest.json')));
 house.life={door:q([[308,653],[439,619],[439,912],[308,947]]),window:q([[114,656],[170,680],[170,767],[114,743]]),chimney:p([245,147]),rest_foot:p([289,1023]),window_shutters:[],wood_uv:q([[320,711],[420,686],[420,872],[320,899]]),rest_sprite:old.life.rest_sprite};
 fs.writeFileSync(path.join(dst,'manifest.json'),JSON.stringify(house,null,2)+'\n');
 fs.mkdirSync(path.join(dst,'operation/work'),{recursive:true});
 await sharp(path.join(game,'art/buildings/sawmill/v1/operation/work/processing-log.png')).rotate(-15,{background:'#00000000'}).png().toFile(path.join(dst,'operation/work/processing-log.png'));
 const oldop=JSON.parse(fs.readFileSync(path.join(game,'art/buildings/sawmill/v1/operation/manifest.json')));
 const work={frames:oldop.work.frames,body_height_px:412,ground_contact:[374.5,489],foot:p([974,890]),cycles_per_batch:6,log:{texture:'res://art/buildings/sawmill/v2/operation/work/processing-log.png',rect:[...p([758,671]),...p([210,102])]},foreground:[]};
 const hashes={};for(const f of [...work.frames,work.log.texture])hashes[f]=sha(path.join(game,f.replace('res://','')));
 fs.writeFileSync(path.join(__dirname,'life-work-fields.json'),JSON.stringify({life:house.life,work,asset_hashes:hashes,source_raw_anchors:{rest_foot:[289,1023],work_foot:[974,890]},provenance:{worker:'Exact own six-pose v1 worker reuse, no resculpt/repaint',rest:'Exact own v1 resting carpenter and head turns',work_log:'Own v1 working log, rigid 15-degree technical rotation to follow new bench'}},null,2)+'\n');
 const wf=33/412/house.source_to_world;
 const layers=[];const log=work.log.rect;layers.push({input:await sharp(path.join(dst,'operation/work/processing-log.png')).resize(Math.round(log[2]),Math.round(log[3])).toBuffer(),left:Math.round(log[0]),top:Math.round(log[1])});
 layers.push({input:await sharp(path.join(game,work.frames[0].replace('res://',''))).resize(Math.round(512*wf),Math.round(512*wf)).toBuffer(),left:Math.round(work.foot[0]-374.5*wf),top:Math.round(work.foot[1]-489*wf)});
 await sharp(path.join(dst,'finished.png')).composite(layers).png().toFile('/private/tmp/sawmill-v2-work-preflight.png');
})();
