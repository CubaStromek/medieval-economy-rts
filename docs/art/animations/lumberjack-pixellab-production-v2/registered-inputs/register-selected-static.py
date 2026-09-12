from pathlib import Path
from PIL import Image, ImageDraw
from datetime import datetime,timezone
import colorsys,hashlib,json,math
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'registered-inputs';OUT.mkdir(exist_ok=True)
SOURCES={d:ROOT/('direction-inputs/walk_axe/'+d+'.png') if d in ('S','SW') else ROOT/('edits/axe-low-'+d+'-pro/images/frame_00.png') for d in ('S','SE','E','NE','N','SW')}
SOURCES['W']=ROOT/'edits/axe-low-W-pro-v2/images/frame_00.png'
SOURCES['NW']=ROOT/'edits/axe-low-NW-pro-v2/images/frame_00.png'
SOURCES['chop-S']=ROOT/'edits/chop-S-pro-v3/images/frame_00.png'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def landmark(im):
    alpha=im.getchannel('A');top=alpha.getbbox()[1]
    pts=[]
    for y in range(top,top+21):
        for x in range(65,190):
            r,g,b,a=im.getpixel((x,y));h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
            if a>=32 and .025<=h<=.11 and s>=.35 and v>=.15:pts.append((x,y))
    box=[min(x for x,y in pts),min(y for x,y in pts),max(x for x,y in pts)+1,max(y for x,y in pts)+1]
    center=(box[0]+box[2]-1)/2
    return {'cap_silhouette_top_y':top,'orange_cap_bounds_exclusive':box,'orange_cap_center_x':center,'raster_center_x':math.floor(center+.5),'mask_pixel_count':len(pts)},pts
base=Image.open(SOURCES['S']).convert('RGBA');target,_=landmark(base)
assert target['cap_silhouette_top_y']==52 and target['raster_center_x']==128
records=[];renders=[];diags=[]
for name,path in SOURCES.items():
    before=sha(path);im=Image.open(path).convert('RGBA');info,pts=landmark(im)
    dx=target['raster_center_x']-info['raster_center_x'];dy=target['cap_silhouette_top_y']-info['cap_silhouette_top_y']
    shifted=Image.new('RGBA',im.size);shifted.paste(im,(dx,dy))
    srcbox=im.getchannel('A').getbbox();dstbox=shifted.getchannel('A').getbbox()
    assert dstbox==(srcbox[0]+dx,srcbox[1]+dy,srcbox[2]+dx,srcbox[3]+dy)
    count=lambda image:sum(p[3]>0 for p in image.get_flattened_data())
    assert count(im)==count(shifted)
    for y in range(im.height):
        for x in range(im.width):
            p=im.getpixel((x,y));xx=x+dx;yy=y+dy
            if p[3]>0:
                assert 0<=xx<im.width and 0<=yy<im.height
                assert p==shifted.getpixel((xx,yy))
    directory=OUT/('chop' if name=='chop-S' else 'walk_axe');directory.mkdir(exist_ok=True)
    dest=directory/('S.png' if name=='chop-S' else name+'.png');shifted.save(dest)
    with Image.open(dest) as actual:
        assert actual.convert('RGBA').tobytes()==shifted.tobytes()
    assert sha(path)==before
    record={'id':name,'source':str(path.relative_to(ROOT)),'source_sha256':before,'output':str(dest.relative_to(ROOT)),'output_sha256':sha(dest),'canvas':[256,256],'source_cap_landmark':info,'translation_source_px':[dx,dy],'registered_cap_top_y':info['cap_silhouette_top_y']+dy,'registered_cap_center_x':info['orange_cap_center_x']+dx,'registered_raster_center_x':info['raster_center_x']+dx,'source_alpha_bbox_exclusive':srcbox,'output_alpha_bbox_exclusive':dstbox,'visible_pixel_count':count(im),'all_visible_source_rgba_pixels_preserved_at_exact_integer_translation':True,'visible_pixels_clipped':0,'source_unchanged':True,'resampling':'none'}
    records.append(record);renders.append((name,shifted))
    diag=shifted.copy();draw=ImageDraw.Draw(diag);b=info['orange_cap_bounds_exclusive'];b=[b[0]+dx,b[1]+dy,b[2]+dx,b[3]+dy]
    draw.rectangle((b[0],b[1],b[2]-1,b[3]-1),outline=(70,230,255,255));draw.line((128,40,128,86),fill=(255,80,130,255));draw.line((102,52,151,52),fill=(255,80,130,255));diags.append((name,diag))
for filename,items in [('registered-contact.png',renders),('cap-landmark-diagnostic.png',diags)]:
    sheet=Image.new('RGB',(4*256,math.ceil(len(items)/4)*284),(45,55,52));draw=ImageDraw.Draw(sheet)
    for i,(name,im) in enumerate(items):
        x=(i%4)*256;y=(i//4)*284;draw.text((x+8,y+8),name,fill='white');sheet.paste(im,(x,y+28),im)
    sheet.save(OUT/filename)
report={'created_at':datetime.now(timezone.utc).isoformat(),'scope':'All eight selected static axe references plus chop S; root authorized W/NW v2 inclusion before this registration','target_source':str(SOURCES['S'].relative_to(ROOT)),'target_landmark':target,'landmark_method':'Visually verified cap is highest visible object in each selected source. Cap top = full-alpha silhouette top. X center = midpoint of orange cap mask bounds inside first21px band, x65..189, alpha>=32, HSV hue .025..11 saturation>=.35 value>=.15; nearest raster x=floor(center+.5).','physical_ground_anchor':'not established; cap registration is image registration only','rotation_scale_and_per_frame_foot_adjustment':'none','records':records}
(OUT/'provenance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'target_top':52,'target_raster_center':128,'translations':{x['id']:x['translation_source_px'] for x in records},'visible_clipping':0},ensure_ascii=False))
