from pathlib import Path
from PIL import Image,ImageDraw
from datetime import datetime,timezone
import json,hashlib,colorsys,math
R=Path(__file__).resolve().parents[2];Q=R/'rotations-log/qa';O=R/'registered-inputs/walk_log'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
protected=sha(O/'S.png');assert protected=='979e1a464722a1217a3531ccd89ac54976c2471b38d7efb9fbbd778fdc8a1fcd'
# Cap-only ROIs were individually inspected; Y is cap crown, never log alpha top.
selected={'SE':(1,(117,53,147,74)),'E':(2,(117,46,151,67)),'NE':(3,(114,44,146,65)),'N':(4,(114,40,141,61)),'NW':(5,(108,46,138,67)),'W':(6,(106,52,138,73)),'SW':(7,(112,51,142,72))}
records=[];pictures={'S':Image.open(O/'S.png').convert('RGBA')};diags={}
for direction,(index,roi) in selected.items():
 src=R/'rotations-log/images'/f'frame_{index:02d}.png';before=sha(src);im=Image.open(src).convert('RGBA');assert im.size==(256,256);l,t,r,b=roi;pts=[]
 for y in range(t,b):
  for x in range(l,r):
   red,g,blue,a=im.getpixel((x,y));h,s,v=colorsys.rgb_to_hsv(red/255,g/255,blue/255)
   if a>=32 and .025<=h<=.11 and s>=.35 and v>=.15:pts.append((x,y))
 cb=[min(x for x,y in pts),min(y for x,y in pts),max(x for x,y in pts)+1,max(y for x,y in pts)+1];center=(cb[0]+cb[2]-1)/2;dx=128-math.floor(center+.5);dy=52-t
 out=Image.new('RGBA',im.size);out.paste(im,(dx,dy));bb=im.getchannel('A').getbbox();ob=out.getchannel('A').getbbox();assert ob==tuple(a+b for a,b in zip(bb,(dx,dy,dx,dy)))
 n=0
 for y in range(256):
  for x in range(256):
   p=im.getpixel((x,y))
   if p[3]:n+=1;assert 0<=x+dx<256 and 0<=y+dy<256;assert p==out.getpixel((x+dx,y+dy))
 assert n==sum(p[3]>0 for p in out.get_flattened_data());dest=O/(direction+'.png')
 if dest.exists():assert Image.open(dest).convert('RGBA').tobytes()==out.tobytes()
 else:out.save(dest)
 assert Image.open(dest).convert('RGBA').tobytes()==out.tobytes();assert sha(src)==before;pictures[direction]=out
 diag=out.copy();draw=ImageDraw.Draw(diag);draw.rectangle((cb[0]+dx,cb[1]+dy,cb[2]-1+dx,cb[3]-1+dy),outline=(70,230,255,255));draw.line((128,40,128,82),fill=(255,80,130,255));draw.line((109,52,147,52),fill=(255,80,130,255));diags[direction]=diag
 records.append({'direction':direction,'source_index':index,'source':str(src.relative_to(R)),'source_sha256':before,'output':str(dest.relative_to(R)),'output_sha256':sha(dest),'canvas_px':[256,256],'cap_only_roi_exclusive':roi,'manual_cap_crown_top_y':t,'orange_cap_bounds_exclusive':cb,'source_cap_center_x':center,'translation_source_px':[dx,dy],'registered_cap_top_y':52,'registered_cap_center_x':center+dx,'registered_raster_center_x':128,'source_alpha_bbox_exclusive':bb,'output_alpha_bbox_exclusive':ob,'visible_pixel_count':n,'visible_pixels_clipped':0,'all_visible_source_rgba_pixels_preserved_at_exact_integer_translation':True,'source_unchanged':True,'resampling':'none'})
assert sha(O/'S.png')==protected
for filename,images in [('registered-log-contact.png',pictures),('registered-cap-diagnostic.png',diags)]:
 sheet=Image.new('RGB',(1024,576),(43,53,50));d=ImageDraw.Draw(sheet)
 for i,direction in enumerate(('S','SE','E','NE','N','NW','W','SW')):
  x=i%4*256;y=i//4*288;d.text((x+8,y+8),direction+(' (existing unchanged)' if direction=='S' else ''),fill='white')
  if direction in images:sheet.paste(images[direction],(x,y+32),images[direction])
 sheet.save(Q/filename)
report={'created_at':datetime.now(timezone.utc).isoformat(),'direction_mapping':{'00':'S (not selected; prior animated S protected)','01':'SE','02':'E','03':'NE','04':'N','05':'NW','06':'W','07':'SW'},'existing_S_preserved_sha256':protected,'method':'Individually visually inspected cap crown Y and explicit cap-only rectangular ROI, not whole-alpha or log top. Color mask H .025..11 S>=.35 V>=.15 alpha>=32 inside ROI determines practical cap X center; floor(center+.5). Approximate landmark uncertainty ~1 source px, no anatomical precision claim.','physical_ground_anchor':'not inferred; image registration only','all_eight_static_inputs_present':True,'production_accepted':False,'records':records}
(Q/'direction-registration.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'ready':{r['direction']:r['translation_source_px'] for r in records},'S_unchanged':True,'clipped':0}))
