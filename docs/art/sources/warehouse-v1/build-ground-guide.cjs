// Verified warehouse geometry, 2026-09-13. Technical diagram only.
// Re-run with the workspace's bundled Node packages on NODE_PATH.
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const sharp = require('sharp');
const root = path.resolve(__dirname, '../../../..');
const source = 'game/art/units/civilians-basic-v1.png';
const sha = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');

async function main() {
  const defs = JSON.parse(fs.readFileSync(path.join(root, 'game/data/buildings.json')));
  const def = defs.warehouse;
  if (JSON.stringify(def.footprint_mask) !== '["###","###","#E#"]') throw Error('Warehouse footprint changed; remeasure guide.');
  const {data,info} = await sharp(path.join(root, source)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const alpha = (x,y) => data[(y*info.width+x)*4+3];
  // Exactly the current UnitSpriteLibrary carrier cell, including its seam search
  // and alpha>=0.10 tight-region rule; source art is never redrawn or distorted.
  const left = Math.round(info.width/5), right = Math.round(info.width*2/5);
  const nominal = Math.round(info.height/3);
  let bottom = nominal, minimum = right-left+1;
  for(let y=Math.max(1,nominal-50);y<=Math.min(info.height-1,nominal+50);y++) {
    let count=0; for(let x=left;x<right;x++) if(alpha(x,y)>=25.5) count++;
    if(count<minimum || count===minimum && Math.abs(y-nominal)<Math.abs(bottom-nominal)) {minimum=count;bottom=y;}
  }
  let minX=right,minY=bottom,maxX=-1,maxY=-1;
  for(let y=0;y<bottom;y++)for(let x=left;x<right;x++)if(alpha(x,y)>=25.5){minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);}
  const region = {left:minX,top:minY,width:maxX-minX+1,height:maxY-minY+1};
  const person = await sharp(path.join(root,source)).extract(region).png().toBuffer();
  const nativeScale=Math.min(33/region.height,31/region.width), guideScale=nativeScale*4;
  const humanWidth=region.width*guideScale,humanHeight=region.height*guideScale;
  const humanFoot=[825,800];
  const geometry={
    schema_version:1,date:'2026-09-13',building_id:'warehouse',revision:'v1-ground-guide',
    status:'Verified gameplay mask and human scale; technical concept guide, not generated or implemented artwork',
    canvas:[1000,1000],source_to_world:0.25,cell_source_px:160,cell_world_px:40,
    authoritative_sources:{catalog:'game/data/buildings.json:2',footprint:'game/scripts/simulation/building_footprints.gd',projection:'game/scripts/view/map_projection.gd',entrance:'game/scripts/simulation/simulation_world.gd:428',human:'game/scripts/view/unit_sprite_library.gd:20'},
    footprint:{version:def.footprint_version||1,mask:def.footprint_mask,occupied_cells:9,world_size:[120,120],source_rect:[220,320,480,480],anchor_cell_relative:[0,0],anchor_cell_center_source:[300,720],door_cell_relative_to_anchor:[1,0],external_entrance_relative_to_anchor:[1,1],internal_free_cells:[],cell_rows_relative_to_anchor:[-2,-1,0]},
    grid_world_origin_source:[220,640],door_threshold:[460,800],door_threshold_formula:'terrain.project_grid_position(Vector2(door_cell) + Vector2(0,0.5))',
    door_threshold_meaning:'Physical navigation threshold; outer edge of an optional shallow step remains at this point',
    external_approach_source_rect:[380,800,160,160],external_approach_rule:'Clear exterior cell: no masonry, posts, stock, platform or permanent figures',
    door_size_cue:{status:'Proposed cargo-door scale only; measure both dimensions on first concept',source_rect:[400,638,120,152],world_width:30,world_height:38,base_center:[460,790],step_max_depth_source_px:10},
    human:{source,source_sha256:sha(path.join(root,source)),role:'carrier',atlas_canvas:[info.width,info.height],atlas_cell:[left,0,right-left,bottom],tight_atlas_region:region,alpha_threshold:0.10,source_to_world:nativeScale,guide_scale:guideScale,guide_foot:humanFoot,guide_body_size:[humanWidth,humanHeight],world_body_height_px:humanHeight/4,meaning:'Existing real-game carrier, exactly current native scale, outside building for size reference only; not an indoor figure'},
    roof_rule:'Building height and roof may project above occupied ground. Keep entire chimney and roof inside canvas. Roof overhangs are reviewed separately from wall bases.',
    ground_rule:'All ground-contact wall bases, feet and blocking fixtures must fit x220..700 y320..800. No ground envelope or visual camera angle is claimed by this orthogonal collision diagram.',
    terrain:{guide_height:0,world_px_per_height_level:8,source_px_per_height_level:32},
    validation:{catalog_mask_matches:true,external_approach_outside_mask:true,person_uses_uniform_runtime_scale:true},
    limitations:['Proposed door dimensions are a scale cue, not a measured generated doorway.','No runtime scene was launched for this technical guide.','Roof, chimney, windows and depth anchors require measurement on the chosen concept.']
  };
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1000" height="1000" viewBox="0 0 1000 1000">
<rect width="1000" height="1000" fill="#f3f2e9"/>
<g font-family="Arial,sans-serif" fill="#24382f">
<text x="30" y="40" font-size="25" font-weight="bold">WAREHOUSE · VERIFIED GROUND GUIDE</text>
<text x="30" y="70" font-size="18">3 × 3 occupied cells · 120 × 120 world px · 4 guide px = 1 world px</text>
<text x="30" y="98" font-size="16">Elevated front-left artwork; this axis-aligned grid is collision, not a camera diagram.</text>
<rect x="180" y="132" width="560" height="160" rx="8" fill="none" stroke="#c7cbbd" stroke-width="2" stroke-dasharray="8 6"/>
<g text-anchor="middle" fill="#75806c" font-size="17"><text x="460" y="188">ROOF + BUILDING HEIGHT MAY RISE HERE</text><text x="460" y="218">Keep the complete chimney and roof inside the canvas.</text><text x="460" y="248">No geometry change, no cropped silhouette.</text></g>
<rect x="220" y="320" width="480" height="480" fill="#e0ead6" stroke="#4a7d5c" stroke-width="4"/>
<path d="M380 320V800 M540 320V800 M220 480H700 M220 640H700" fill="none" stroke="#8ca486" stroke-width="2"/>
<g font-size="17" text-anchor="middle" fill="#607d5a"><text x="300" y="357">#</text><text x="460" y="357">#</text><text x="620" y="357">#</text><text x="300" y="517">#</text><text x="460" y="517">#</text><text x="620" y="517">#</text><text x="300" y="677">#</text><text x="620" y="677">#</text></g>
<g font-size="16" fill="#416448"><text x="228" y="309">NW (220,320)</text><text x="568" y="788">SE (700,800)</text></g>
<g text-anchor="middle" font-size="19"><text x="460" y="560">ALL WALL BASES + FOOTINGS</text><text x="460" y="588">STAY INSIDE OCCUPIED GROUND</text></g>
<rect x="400" y="638" width="120" height="152" fill="#e6d6ba" fill-opacity=".75" stroke="#a054a2" stroke-width="2" stroke-dasharray="7 5"/>
<path d="M460 638V790" fill="none" stroke="#a054a2" stroke-width="2" stroke-dasharray="7 5"/>
<text x="460" y="665" text-anchor="middle" font-size="16" fill="#8b468b">DOOR CUE</text>
<text x="460" y="690" text-anchor="middle" font-size="14" fill="#8b468b">30w × 38h</text>
<text x="460" y="712" text-anchor="middle" font-size="14" fill="#8b468b">world px</text>
<path d="M460 790V800" fill="none" stroke="#148c9b" stroke-width="4"/>
<rect x="380" y="800" width="160" height="160" fill="#d4ebe5" stroke="#148c9b" stroke-width="3" stroke-dasharray="8 5"/>
<circle cx="460" cy="800" r="7" fill="#148c9b"/>
<g text-anchor="middle" fill="#226b72"><text x="460" y="846" font-size="19" font-weight="bold">KEEP CLEAR</text><text x="460" y="874" font-size="16">Entrance (1,1)</text><text x="460" y="901" font-size="15">Threshold</text><text x="460" y="927" font-size="17">(460,800)</text></g>
<circle cx="300" cy="720" r="5" fill="#527545"/><text x="300" y="744" text-anchor="middle" font-size="14" fill="#527545">anchor (0,0)</text>
<image x="${humanFoot[0]-humanWidth/2}" y="${humanFoot[1]-humanHeight}" width="${humanWidth}" height="${humanHeight}" xlink:href="data:image/png;base64,${person.toString('base64')}"/>
<path d="M880 ${800-humanHeight}H898 M889 ${800-humanHeight}V800 M880 800H898" fill="none" stroke="#9c6335" stroke-width="2"/>
<g font-size="16" fill="#85552e" text-anchor="middle"><text x="831" y="837">ACTUAL GAME CARRIER</text><text x="831" y="864">33 world px tall</text><text x="831" y="890">132 guide px tall</text><text x="831" y="920">Scale reference only</text></g>
<g font-size="15" fill="#717566"><text x="30" y="980">2026-09-13 · Technical diagram only · Do not paint the grid, labels, door cue or carrier into the building.</text></g>
</g></svg>`;
  fs.writeFileSync(path.join(__dirname,'geometry.json'),JSON.stringify(geometry,null,2)+'\n');
  fs.writeFileSync(path.join(__dirname,'ground-guide.svg'),svg);
  await sharp(Buffer.from(svg)).png().toFile(path.join(__dirname,'ground-guide.png'));
  process.stdout.write(JSON.stringify({output:__dirname,carrier_world_height:humanHeight/4,carrier_atlas_region:region})+'\n');
}
main().catch(error=>{console.error(error);process.exit(1);});
