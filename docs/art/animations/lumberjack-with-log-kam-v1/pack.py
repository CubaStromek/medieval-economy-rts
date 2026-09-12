#!/usr/bin/env python3
"""Pack carry sheets; final-frame-overrides/DIR/NN.png replaces an already registered frame.
Requires Pillow and NumPy; --directions SE rebuilds only that direction and shared atlas.
"""
from pathlib import Path
import argparse, hashlib, json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
DIRS = 'N NE E SE S SW W NW'.split()
CELL, SHEET, ANCHOR = (448, 544), (1792, 1088), [216, 400]
CAP_HSV = {'N': (17,165), 'NE': (17,165), 'NW': (17,165)}  # Yellow-rust crowns; bark is less saturated.
WALK = json.loads((ROOT.parent/'lumberjack-without-log-kam-v2/registration.json').read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def save(im, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    return str(path.relative_to(ROOT))


def cells(sheet):
    return [sheet.crop((i%4*448, i//4*544, i%4*448+448, i//4*544+544)) for i in range(8)]


def cap(im, expected, hsv=(13,150)):
    """Diagnostic only: rust crown component near the known head; never changes pixels."""
    a = np.asarray(im.convert('HSV'))
    yy, xx = np.indices(a.shape[:2]); ex, ey = expected
    mask = ((a[:,:,0] >= 2) & (a[:,:,0] <= hsv[0]) & (a[:,:,1] > hsv[1]) & (a[:,:,2] > 75)
            & (abs(xx-ex) <= 75) & (yy >= ey-45) & (yy <= ey+65))
    unseen = mask.copy(); choices = []
    for sy, sx in zip(*np.where(mask)):
        if not unseen[sy, sx]: continue
        unseen[sy, sx] = False; stack = [(int(sx), int(sy))]; pts = []
        while stack:
            x, y = stack.pop(); pts.append((x, y))
            for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if 0 <= nx < im.width and 0 <= ny < im.height and unseen[ny,nx]:
                    unseen[ny,nx] = False; stack.append((nx,ny))
        if len(pts) >= 150: choices.append(np.asarray(pts))
    assert choices, ('cap not detected', expected)
    q = max(choices, key=len); lo, hi = q.min(0), q.max(0)+1
    top = int(lo[1]); center = float(q[q[:,1] < top+12, 0].mean())
    assert 24 <= hi[0]-lo[0] <= 125 and 15 <= hi[1]-lo[1] <= 95, ('cap component suspicious',lo,hi)
    assert abs(center-ex) < 70 and abs(top-ey) < 44, ('cap location suspicious', center,top,expected)
    return {'top':top,'centerX':center,'bounds':[int(v) for v in [*lo,*hi]],'componentPixels':len(q)}


def foreground(im):
    mask = np.asarray(im.convert('RGB')).min(2) < 230
    y, x = np.where(mask)
    assert len(x)
    return [int(x.min()), int(y.min()), int(x.max())+1, int(y.max())+1]


def override_cap_diagnostics(direction,index,baseline,override,measurement,hsv):
    dx,dy=measurement['integerOffset'];base=dict(measurement['scaledCap'])
    base['top']+=dy;base['centerX']+=dx;base['bounds']=[v+(dx,dy)[j%2] for j,v in enumerate(base['bounds'])]
    actual=cap(override,(base['centerX'],base['top']),hsv)
    diag=Image.new('RGB',(896,584),'white');draw=ImageDraw.Draw(diag)
    for col,(im,mark,label) in enumerate(((baseline,base,'BASELINE'),(override,actual,'FINAL OVERRIDE'))):
        x=col*448;diag.paste(im,(x,40));b=mark['bounds']
        draw.rectangle((x+b[0],40+b[1],x+b[2],40+b[3]),outline=(0,160,255),width=2)
        draw.line((x+mark['centerX']-10,40+mark['top'],x+mark['centerX']+10,40+mark['top']),fill=(255,0,180),width=2)
        draw.text((x+8,10),f'{label} {direction}/{index:02} cap top={mark["top"]}, x={mark["centerX"]:.2f}',fill='black')
    path=ROOT/'diagnostics'/f'{direction}-{index:02}-final-override.png';save(diag,path)
    return {'baselineCapOnFinalCanvas':base,'actualCapOnFinalCanvas':actual,
        'capDeltaPx':[actual['centerX']-base['centerX'],actual['top']-base['top']],
        'capDiagnosticFile':str(path.relative_to(ROOT)),'capMeasurementMeaning':'Measured visible rust crown after replacement; no registration correction applied.'}


def gifs(direction, frames, sheet):
    palette = sheet.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    colours = palette.getpalette()
    bg = min(range(256),key=lambda j:sum((colours[3*j+k]-255)**2 for k in range(3)))
    qs = [im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]; records=[]
    for fps in (5,10):
        p=ROOT/'reviews'/f'{direction}-{fps}fps.gif';p.parent.mkdir(exist_ok=True);duration=1000//fps
        qs[0].save(p,save_all=True,append_images=qs[1:],duration=duration,loop=0,disposal=2,
                   optimize=False,palette=colours,background=bg)
        timeline=[];delays=[]
        with Image.open(p) as gif:
            for i in range(gif.n_frames):
                gif.seek(i);delay=gif.info['duration'];assert delay % duration == 0
                delays.append(delay);timeline.extend([gif.convert('RGB').tobytes()]*(delay//duration))
        assert timeline == [im.convert('RGB').tobytes() for im in qs]
        records.append({'file':str(p.relative_to(ROOT)),'fps':fps,'durationsMs':delays,'sha256':sha(p)})
    return records


def feet_comparison(entries):
    """Reference-only lower-body comparison, labels outside figures; phases 3/7 = 02/06."""
    refs=ROOT.parents[3]/'original_game_data/kam-reference-export/lumberjack-full-set'
    out=Image.new('RGB',(1344,40+len(entries)*184),'white');draw=ImageDraw.Draw(out)
    for col,text in enumerate(['KaM phase 3 [02]','KaM phase 7 [06]','Walk target 3 [02]',
                               'Walk target 7 [06]','Carry final 3 [02]','Carry final 7 [06]']):
        draw.text((col*224+8,8),text,fill='black')
    for row,d in enumerate(x for x in DIRS if x in entries):
        originals=cells(Image.open(refs/'carry-guides-8x'/f'{d}.png'))
        targets=cells(Image.open(ROOT/'walk-targets'/f'{d}.png'))
        images=[originals[2],originals[6],targets[2],targets[6],
                Image.open(ROOT/entries[d]['frames'][2]['file']),Image.open(ROOT/entries[d]['frames'][6]['file'])]
        y=40+row*184;draw.text((8,y),d+' - lower body; same canvas origin, no foot alignment',fill='black')
        for col,im in enumerate(images):
            crop=im.crop((0,224,448,520)).resize((224,148),Image.Resampling.NEAREST if col<2 else Image.Resampling.LANCZOS)
            out.paste(crop,(col*224,y+24))
    path=refs/'carry-guides-8x/feet-phase-3-7-comparison.png';out.save(path)
    return str(path)


def pack(direction):
    source=ROOT/'sources'/f'{direction}.png';before=sha(source)
    original=Image.open(source);assert original.mode=='RGB', ('unexpected source mode',direction,original.mode)
    normalized=original.resize(SHEET,Image.Resampling.LANCZOS)
    raws=cells(normalized);target_path=ROOT/'walk-targets'/f'{direction}.png';targets=cells(Image.open(target_path))
    raw_caps=[];target_caps=[];raw_heights=[];target_heights=[];hsv=CAP_HSV.get(direction,(13,150))
    diag=normalized.copy();draw=ImageDraw.Draw(diag)
    for i,(raw,target) in enumerate(zip(raws,targets)):
        old=WALK['directions'][direction]['measurements'][i]
        expected=(old['ownScaled']['capCenterX']+old['integerOffset'][0]+32,
                  old['ownScaled']['capTop']+old['integerOffset'][1]+32)
        tc=cap(target,expected,hsv);rc=cap(raw,(tc['centerX'],tc['top']),hsv)
        raw_caps.append(rc);target_caps.append(tc)
        raw_heights.append(foreground(raw)[3]-rc['top']);target_heights.append(foreground(target)[3]-tc['top'])
        ox,oy=i%4*448,i//4*544;b=rc['bounds']
        draw.rectangle((ox+b[0],oy+b[1],ox+b[2],oy+b[3]),outline=(0,160,255),width=3)
        draw.line((ox+rc['centerX']-12,oy+rc['top'],ox+rc['centerX']+12,oy+rc['top']),fill=(255,0,180),width=3)
        draw.text((ox+8,oy+8),f'{direction} {i:02} cap {rc["top"]}, body {raw_heights[-1]}',fill='black')
    save(diag,ROOT/'diagnostics'/f'{direction}-cap-detection.png')
    factor=float(np.median(target_heights)/np.median(raw_heights));assert .7 < factor < 1.3, ('body scale suspicious',direction,factor)
    frames=[];measurements=[]
    for i,raw in enumerate(raws):
        scaled=raw.resize((round(448*factor),round(544*factor)),Image.Resampling.LANCZOS)
        rc,tc=raw_caps[i],target_caps[i];sc=cap(scaled,(rc['centerX']*factor,rc['top']*factor),hsv)
        dx,dy=round(tc['centerX']-sc['centerX']),tc['top']-sc['top'];bb=foreground(scaled)
        bounds=[bb[j]+(dx,dy)[j%2] for j in range(4)]
        assert 0<=bounds[0]<bounds[2]<=448 and 0<=bounds[1]<bounds[3]<=544, ('figure clipped',direction,i,bounds)
        frame=Image.new('RGB',CELL,'white');frame.paste(scaled,(dx,dy));frames.append(frame)
        measurements.append({'index':i,'targetCap':tc,'rawCap':rc,'scaledCap':sc,
            'rawBodyHeight':raw_heights[i],'targetBodyHeight':target_heights[i],
            'integerOffset':[dx,dy],'scaledCellSize':list(scaled.size),'figureBounds':bounds,
            'capCenterResidualPx':sc['centerX']+dx-tc['centerX'],'figureClipped':False})
    # Write deliverable PNGs immediately after all eight phases pass preflight.
    sheet=Image.new('RGB',SHEET,'white');records=[]
    for i,(raw,frame,measurement) in enumerate(zip(raws,frames,measurements)):
        rp=ROOT/'raw'/direction/f'{i:02}.png';fp=ROOT/'frames'/direction/f'{i:02}.png'
        override_path=ROOT/'final-frame-overrides'/direction/f'{i:02}.png'
        override=None;extra={};final_measurement=dict(measurement)
        if override_path.exists():
            with Image.open(override_path) as opened:
                assert opened.size==CELL and opened.mode=='RGB' and 'transparency' not in opened.info, ('invalid final override',override_path)
                override=opened.copy()
            bounds=foreground(override)
            assert 0<bounds[0]<bounds[2]<448 and 0<bounds[1]<bounds[3]<544, ('override touches canvas edge',override_path,bounds)
        save(raw,rp);save(frame,fp)
        if override is not None:
            extra={'finalOverride':{'file':str(override_path.relative_to(ROOT)),'sha256':sha(override_path),
                'baseSha256':sha(fp),'baselineMeasurement':measurement,
                **override_cap_diagnostics(direction,i,frame,override,measurement,hsv),
                'operation':'Exact final-canvas replacement; no additional scale or translation.'},
                'registrationMeasurementAppliesTo':'baseline-before-final-frame-override'}
            fp.write_bytes(override_path.read_bytes());frame=override;frames[i]=frame
            final_measurement['figureBounds']=bounds
        sheet.paste(frame,(i%4*448,i//4*544))
        assert Image.open(rp).tobytes()==raw.tobytes()
        records.append({'index':i,'rawFile':str(rp.relative_to(ROOT)),'file':str(fp.relative_to(ROOT)),
            'rawRect':[i%4*448,i//4*544,448,544],'size':list(CELL),'anchor':ANCHOR,
            'rawSha256':sha(rp),'sha256':sha(fp),'hasAlpha':False,**final_measurement,**extra})
    sp=ROOT/'sheets'/f'{direction}.png';save(sheet,sp)
    save(normalized,ROOT/'normalized-sheets'/f'{direction}.png')
    print(f'{direction}: PNG READY scale={factor:.9f}; body medians {np.median(raw_heights)} -> {np.median(target_heights)}; bounds safe',flush=True)
    reviews=gifs(direction,frames,sheet);assert sha(source)==before
    reg={'scale':factor,'offsets':[m['integerOffset'] for m in measurements],'anchor':ANCHOR,
         'diagnosticHSV':{'hueInclusive':[2,hsv[0]],'saturationMinExclusive':hsv[1],'valueMinExclusive':75,'range':255},
         'rawBodyHeightMedian':float(np.median(raw_heights)),'targetBodyHeightMedian':float(np.median(target_heights)),
         'measurements':measurements,'diagnosticFile':f'diagnostics/{direction}-cap-detection.png'}
    entry={'id':direction,'source':str(source.relative_to(ROOT)),'sourceSize':list(original.size),
           'sourceSha256':before,'sourceMode':original.mode,'normalizedSize':list(SHEET),
           'normalizationScaleXY':[1792/original.width,1088/original.height],
           'targetSha256':sha(target_path),'sharedBodyScale':factor,'anchor':ANCHOR,'frames':records,
           'sheet':str(sp.relative_to(ROOT)),'sheetSha256':sha(sp),'reviews':reviews,'allFiguresInsideCanvas':True}
    return reg,entry


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--directions',nargs='+',choices=DIRS);args=ap.parse_args()
    rp,mp=ROOT/'registration.json',ROOT/'manifest.json'
    reg=json.loads(rp.read_text()) if rp.exists() else {'directions':{}}
    manifest=json.loads(mp.read_text()) if mp.exists() else {'directions':[]}
    entries={d['id']:d for d in manifest['directions']}
    for d in args.directions or DIRS:
        if (ROOT/'sources'/f'{d}.png').exists():
            new_reg,entries[d]=pack(d);old_reg=reg['directions'].get(d)
            baseline_keys=('scale','offsets','anchor','rawBodyHeightMedian','targetBodyHeightMedian','measurements')
            unchanged=old_reg is not None and all(old_reg.get(k)==new_reg[k] for k in baseline_keys)
            if not unchanged:
                reg['directions'][d]=new_reg
                reg.update({'date':'2026-09-10','action':'uaWalkTool2','canvas':list(CELL),'anchor':ANCHOR,
                    'method':'Whole sheet Lanczos normalization; one median cap-to-boot body scale per direction; integer alignment of rust crown top/upper-12px center to each corresponding padded own walk frame. No foot locking or silhouette centering.',
                    'diagnosticHSV':'Per-direction thresholds; see directions. Values use 0-255 Pillow HSV.',
                    'limitation':'Visible cap crown calibration only; log excluded from body top. Does not guarantee skeletal, anatomical, or in-game contact accuracy.'})
                rp.write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n')
            manifest.update({'createdDate':'2026-09-10','action':'uaWalkTool2','directionOrder':DIRS,'frameCount':8,
                'canvas':list(CELL),'anchor':ANCHOR,'registrationFile':'registration.json',
                'directions':[entries[x] for x in DIRS if x in entries],
                'totalFrames':sum(len(x['frames']) for x in entries.values()),
                'status':('artwork-packed; no-game-integration; not-approved' if sum(len(x['frames']) for x in entries.values())==64 else 'artwork-and-preview-in-progress; no-game-integration; not-approved'),
                'notes':['RGB white background; packer does not extract alpha or repaint pixels. Explicit final-frame overrides are recorded individually.',
                         'Raw crops are exact crops of the normalized sheet, not pixel-exact original-size source crops.',
                         'Sources are preserved; sheet normalization and one shared body scale are Lanczos resampling.',
                         'Review 5/10 FPS is illustrative, not verified game timing.']})
            mp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    atlas=Image.new('RGB',(448*8,544*8),'white');overview=Image.new('RGB',(224*4,300*2),'white')
    draw=ImageDraw.Draw(overview)
    for j,d in enumerate(DIRS):
        if d not in entries:continue
        for i,f in enumerate(entries[d]['frames']):atlas.paste(Image.open(ROOT/f['file']),(i*448,j*544))
        thumb=Image.open(ROOT/entries[d]['frames'][0]['file']).resize((224,272),Image.Resampling.LANCZOS)
        overview.paste(thumb,(j%4*224,j//4*300+24));draw.text((j%4*224+8,j//4*300+5),d,fill='black')
    save(atlas,ROOT/'sprite-atlas.png');save(overview,ROOT/'directions-overview.png')
    manifest['spriteAtlas']={'file':'sprite-atlas.png','size':list(atlas.size),'rows':DIRS,'columns':'phase 00-07','sha256':sha(ROOT/'sprite-atlas.png')}
    mp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Reference comparison:',feet_comparison(entries),flush=True)
    print('Packed:', ', '.join(d for d in DIRS if d in entries),flush=True)


if __name__=='__main__':main()
