#!/usr/bin/env python3
"""Run after source QA: python pack.py [--layout layout.json]. Requires Pillow.
Optional layout: {"SE":{"scale":0.6,"offset":[0,0]}} -> 384x512 canvas.
Supports registration.json with one scale and eight explicit offsets per direction.
Without layout, PNG frames retain their original cell sizes and pixels.
"""
from pathlib import Path
import argparse, hashlib, json
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent
DIRECTIONS = ['N','NE','E','SE','S','SW','W','NW']
sha = lambda b: hashlib.sha256(b).hexdigest()


def rgb_on_white(im, size):
    out = Image.new('RGB', size, 'white')
    out.paste(im, (0,0), im.getchannel('A') if 'A' in im.getbands() else None)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layout', type=Path, help='Explicit direction scale/offset JSON; no inferred values.')
    args = parser.parse_args()
    calibration = json.loads(args.layout.read_text()) if args.layout else {}
    layout = calibration.get('directions',calibration)
    anchor = calibration.get('anchor')
    manifest = {'action':'uaWalkBooty','directionOrder':DIRECTIONS,'frameCount':8,
                'anchor':anchor,'registrationFile':str(args.layout) if args.layout else None,'directions':[], 'notes':['No automatic centring or foot locking.',
                'GIFs use one shared palette per direction; review FPS is not game timing.', 'Registration follows original cap bob and lateral motion; it does not guarantee anatomical joint matching.']}
    for direction in DIRECTIONS:
        source = ROOT/'sources'/f'{direction}.png'
        if not source.exists():
            manifest['directions'].append({'id':direction,'status':'source-missing'}); continue
        before = sha(source.read_bytes())
        with Image.open(source) as opened: sheet = opened.copy()
        cfg = layout.get(direction)
        factor = float(cfg.get('scale',1)) if cfg is not None else 1
        offset = tuple(cfg.get('offset',[0,0])) if cfg is not None else (0,0)
        offsets = cfg.get('offsets') if cfg is not None else None
        if offsets is not None: assert len(offsets)==8
        assert factor > 0 and len(offset)==2 and all(type(v) is int for v in offset)
        raw_dir, frame_dir = ROOT/'raw'/direction, ROOT/'frames'/direction
        raw_dir.mkdir(parents=True,exist_ok=True); frame_dir.mkdir(parents=True,exist_ok=True)
        images, records = [], []
        for i in range(8):
            col,row = i%4,i//4
            if offsets is not None: offset = tuple(offsets[i])
            assert len(offset)==2 and all(type(v) is int for v in offset)
            box = (col*sheet.width//4,row*sheet.height//2,(col+1)*sheet.width//4,(row+1)*sheet.height//2)
            raw = sheet.crop(box); raw_path = raw_dir/f'{i:02d}.png'; raw.save(raw_path)
            with Image.open(raw_path) as check: assert check.tobytes()==raw.tobytes()
            frame = raw.copy(); cropped = False; figure_bounds = None
            if cfg is not None:
                if factor != 1:
                    frame = frame.resize((max(1,round(raw.width*factor)),max(1,round(raw.height*factor))),Image.Resampling.LANCZOS)
                cropped = offset[0]<0 or offset[1]<0 or offset[0]+frame.width>384 or offset[1]+frame.height>512
                r,g,b = frame.convert('RGB').split()
                mask = ImageChops.darker(ImageChops.darker(r,g),b).point(lambda v:255 if v<230 else 0)
                bb = mask.getbbox(); figure_bounds = [bb[j]+offset[j%2] for j in range(4)]
                assert 0<=figure_bounds[0]<figure_bounds[2]<=384 and 0<=figure_bounds[1]<figure_bounds[3]<=512, (direction,i,'figure clipped',figure_bounds)
                canvas = Image.new(frame.mode,(384,512),(255,255,255,255) if frame.mode=='RGBA' else 'white')
                canvas.paste(frame,offset); frame = canvas
            path = frame_dir/f'{i:02d}.png'; frame.save(path); images.append(frame)
            records.append({'index':i,'rawFile':str(raw_path.relative_to(ROOT)),
                'rawRect':[box[0],box[1],raw.width,raw.height],'rawSha256':sha(raw_path.read_bytes()),
                'file':str(path.relative_to(ROOT)),'size':list(frame.size),'mode':frame.mode,
                'anchor':anchor,'integerOffset':list(offset),'figureBounds':figure_bounds,'hasAlpha':'A' in frame.getbands(),'sha256':sha(path.read_bytes()),'cellEdgesCroppedByExplicitLayout':cropped})
        size = (max(im.width for im in images),max(im.height for im in images))
        rgb = [rgb_on_white(im,size) for im in images]
        palette_sheet = Image.new('RGB',(size[0]*4,size[1]*2),'white')
        for i,im in enumerate(rgb): palette_sheet.paste(im,((i%4)*size[0],(i//4)*size[1]))
        palette = palette_sheet.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
        colours = palette.getpalette()
        background = min(range(256),key=lambda j:sum((colours[j*3+k]-255)**2 for k in range(3)))
        quantized = [im.quantize(palette=palette,dither=Image.Dither.NONE) for im in rgb]
        review_dir = ROOT/'reviews'; review_dir.mkdir(exist_ok=True); reviews = []
        for fps in (5,10):
            path = review_dir/f'{direction}-{fps}fps.gif'; duration = 1000//fps
            quantized[0].save(path,save_all=True,append_images=quantized[1:],duration=duration,
                loop=0,disposal=2,optimize=False,palette=colours,background=background)
            timeline, delays = [], []
            with Image.open(path) as gif:
                for i in range(gif.n_frames):
                    gif.seek(i); delay=gif.info['duration']; assert delay%duration==0
                    delays.append(delay); timeline.extend([gif.convert('RGB').tobytes()]*(delay//duration))
            assert timeline==[im.convert('RGB').tobytes() for im in quantized]
            reviews.append({'file':str(path.relative_to(ROOT)),'fps':fps,'durationsMs':delays,'sha256':sha(path.read_bytes())})
        assert sha(source.read_bytes())==before
        manifest['directions'].append({'id':direction,'source':str(source.relative_to(ROOT)),
            'sourceSize':list(sheet.size),'sourceMode':sheet.mode,'sourceSha256':before,
            'layout':cfg,'sharedScale':factor,'sharedOffset':list(offset) if cfg is not None and offsets is None else None,'frameOffsets':offsets,
            'anchor':anchor,'resampled':factor!=1,'frames':records,'reviews':reviews,
            'gifCanvas':list(size),'gifPadding':'top-left, white; no recentering',
            'layoutClippingNeedsVisualQA':False,'allFiguresInsideCanvas':True})
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Packed directions:', ', '.join(d['id'] for d in manifest['directions'] if 'frames' in d))


if __name__ == '__main__':
    main()
