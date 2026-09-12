#!/usr/bin/env python3
"""Package v3: shared cap-to-sole resampling for A/B; C–F integer shifts only."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image, ImageChops

OUT = Path(__file__).resolve().parent
GEN = Path('/Users/openclaw/.codex/generated_images/01a087a4-bf3d-7f70-b463-afa4f5165f3c')
SOURCES = {
    'AB': GEN / 'exec-d832e8c3-8471-4b88-acf2-597c84683311.png',
    'CDEF': GEN / 'exec-43ac83c4-80e4-486a-9d36-06319ad678fa.png',
}
SEQUENCE = list('ABACDDDECF')
IDS = [1614, 1613, 1614, 1616, 2826, 1618, 1618, 1617, 1616, 1615]
CANVAS, ANCHOR = (640, 480), (256, 440)
CAP_ROIS = {'A': (580,90,655,230), 'B': (317,90,392,230),
            'C': (212,35,272,130), 'D': (268,35,328,130),
            'E': (251,35,311,130), 'F': (251,35,311,130)}
sha = lambda b: hashlib.sha256(b).hexdigest()
file_info = lambda p: {'path': str(p), 'sha256': sha(p.read_bytes()), 'sizeBytes': p.stat().st_size}


def diagnostic_mask(im):
    r,g,b = im.split()
    return ImageChops.darker(ImageChops.darker(r,g),b).point(lambda v: 255 if v < 245 else 0)


def sole_anchor(mask):
    bottom = mask.getbbox()[3] - 1
    band = mask.crop((0,bottom-3,mask.width,bottom+1)).getbbox()
    return ((band[0]+band[2]-1)//2,bottom)


prompts = {p.name: sha(p.read_bytes()) for p in sorted(OUT.glob('prompt-*.txt'))}
assert len(prompts) == 4
source_info = {k: file_info(p) for k,p in SOURCES.items()}
sources = {k: Image.open(p) for k,p in SOURCES.items()}
assert sources['AB'].size == (2092,752) and sources['CDEF'].size == (1808,870)
for k,im in sources.items():
    assert im.mode == 'RGB' and 'transparency' not in im.info
    name = f'source-final-{k}.png'
    shutil.copyfile(SOURCES[k],OUT/name)
    assert sha((OUT/name).read_bytes()) == source_info[k]['sha256']
    source_info[k].update({'copiedFile':name,'size':list(im.size),'mode':'RGB','hasAlpha':False})
for folder in ('raw-keyposes','unique-frames','frames'):
    (OUT/folder).mkdir(exist_ok=True)

raws, poses = {}, []
for label in 'ABCDEF':
    group = 'AB' if label in 'AB' else 'CDEF'
    index = 'AB'.index(label) if group == 'AB' else 'ABCDEF'.index(label)
    cols,rows = (2,1) if group == 'AB' else (3,2)
    im=sources[group]; col,row=index%cols,index//cols
    rect=(col*im.width//cols,row*im.height//rows,(col+1)*im.width//cols,(row+1)*im.height//rows)
    raw=im.crop(rect); raws[label]=raw
    raw_path=OUT/'raw-keyposes'/f'{label}.png'; raw.save(raw_path)
    with Image.open(raw_path) as check: assert check.tobytes()==raw.tobytes()
    mask=diagnostic_mask(raw); sole=sole_anchor(mask)
    roi=CAP_ROIS[label]; cap_top=mask.crop(roi).getbbox()[1]+roi[1]
    poses.append({'id':label,'sourceGroup':group,'sourceCellIndex0Based':index,
                  'rawCellRect':[rect[0],rect[1],raw.width,raw.height],
                  'rawFile':f'raw-keyposes/{label}.png','rawSha256':sha(raw_path.read_bytes()),
                  'rawPixelsSha256':sha(raw.tobytes()),'rawSize':list(raw.size),
                  'rawFrontSoleAnchor':list(sole),'capCrownMeasurementROI':list(roi),
                  'rawCapTopY':cap_top,'rawCapToSoleHeight':sole[1]-cap_top+1})
source_height=sum(p['rawCapToSoleHeight'] for p in poses[:2])/2
target_height=sum(p['rawCapToSoleHeight'] for p in poses[2:])/4
factor=target_height/source_height
registered={}
for p in poses:
    label=p['id']; raw=raws[label]
    if label in 'AB':
        working=raw.resize((round(raw.width*factor),round(raw.height*factor)),Image.Resampling.LANCZOS)
    else:
        working=raw.copy()
    mask=diagnostic_mask(working); sole=sole_anchor(mask)
    offset=(ANCHOR[0]-sole[0],ANCHOR[1]-sole[1])
    bounds=mask.getbbox(); dest_bounds=tuple(bounds[k]+offset[k%2] for k in range(4))
    assert 0<=dest_bounds[0]<dest_bounds[2]<=CANVAS[0]
    assert 0<=dest_bounds[1]<dest_bounds[3]<=CANVAS[1]
    image=Image.new('RGB',CANVAS,(255,255,255)); image.paste(working,offset)
    retained=(max(0,-offset[0]),max(0,-offset[1]),min(working.width,CANVAS[0]-offset[0]),min(working.height,CANVAS[1]-offset[1]))
    dest=tuple(retained[k]+offset[k%2] for k in range(4))
    assert image.crop(dest).tobytes()==working.crop(retained).tobytes()
    assert bounds[0]>=retained[0] and bounds[1]>=retained[1] and bounds[2]<=retained[2] and bounds[3]<=retained[3]
    path=OUT/'unique-frames'/f'{label}.png'; image.save(path)
    with Image.open(path) as check: assert check.tobytes()==image.tobytes()
    registered[label]=image
    p.update({'file':f'unique-frames/{label}.png','size':list(CANVAS),'mode':'RGB','hasAlpha':False,
              'sha256':sha(path.read_bytes()),'pixelsSha256':sha(image.tobytes()),
              'resampled':label in 'AB','nominalScale':factor if label in 'AB' else 1,
              'resampling':'Lanczos' if label in 'AB' else 'none',
              'workingSize':list(working.size),'workingPixelsSha256':sha(working.tobytes()),
              'workingSoleAnchor':list(sole),'integerOffset':list(offset),'registeredSoleAnchor':list(ANCHOR),
              'retainedWorkingRectExclusive':list(retained),'registeredFigureBoundsExclusive':list(dest_bounds),
              'silhouetteUnclipped':True,'retainedWorkingPixelsUnchangedByTranslation':True,
              'originalRawRGBPreservedWithoutResampling':label not in 'AB'})
assert len({p['pixelsSha256'] for p in poses})==6
frames=[]
atlas=Image.new('RGB',(3200,960),(255,255,255))
for i,label in enumerate(SEQUENCE):
    path=OUT/'frames'/f'{i:02d}.png'; shutil.copyfile(OUT/'unique-frames'/f'{label}.png',path)
    assert path.read_bytes()==(OUT/'unique-frames'/f'{label}.png').read_bytes()
    atlas.paste(registered[label],((i%5)*640,(i//5)*480))
    frames.append({'index':i,'pose':label,'file':f'frames/{i:02d}.png','originalKaMSpriteId1Based':IDS[i],'sha256':sha(path.read_bytes())})
atlas.save(OUT/'sprite-sheet.png')
keyposes=Image.new('RGB',(1920,960),(255,255,255))
for i,label in enumerate('ABCDEF'): keyposes.paste(registered[label],((i%3)*640,(i//3)*480))
keyposes.save(OUT/'keyposes-sheet.png')

shared=atlas.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
palette=shared.getpalette()
q={k:im.quantize(palette=shared,dither=Image.Dither.NONE) for k,im in registered.items()}
qframes=[q[k] for k in SEQUENCE]
background=min(range(256),key=lambda j:sum((palette[j*3+k]-255)**2 for k in range(3)))
reviews=[]
for fps in (10,5):
    duration=1000//fps; name=f'review-{fps}fps.gif'; path=OUT/name
    qframes[0].save(path,save_all=True,append_images=qframes[1:],duration=duration,loop=0,disposal=2,optimize=False,background=background,palette=palette)
    delays=[]; timeline=[]
    with Image.open(path) as gif:
        assert gif.size==CANVAS and 'transparency' not in gif.info
        for i in range(gif.n_frames):
            gif.seek(i); delay=gif.info['duration']; delays.append(delay)
            assert delay%duration==0
            timeline.extend([gif.convert('RGB').tobytes()]*(delay//duration))
    assert timeline==[im.convert('RGB').tobytes() for im in qframes]
    reviews.append({'file':name,'fps':fps,'logicalFrameCount':10,'encodedFrameCount':len(delays),
                    'encodedDurationsMs':delays,'totalDurationMs':sum(delays),'sha256':sha(path.read_bytes()),'hasTransparency':False})

calls=[('exec-c388c19b-c33d-494a-a94f-d918544791d7.png','Rejected A/B grip; not used in final frames.'),
       ('exec-43ac83c4-80e4-486a-9d36-06319ad678fa.png','Final C/D/E/F only, source cell indices 2/3/4/5.'),
       ('exec-b8725075-032f-4475-8a0a-f8f4ca0ab92b.png','Rejected A/B grip; not used in final frames.'),
       ('exec-d832e8c3-8471-4b88-acf2-597c84683311.png','Final A/B only, source cell indices 0/1.')]
assert all(sha(SOURCES[k].read_bytes())==v['sha256'] for k,v in source_info.items())
assert all(sha((OUT/k).read_bytes())==v for k,v in prompts.items())
manifest={
    'version':1,'revision':'v3','createdDate':'2026-09-10','direction':'SE','frameCount':10,'uniquePoseCount':6,
    'sequence':SEQUENCE,'originalKaMSpriteIds1Based':IDS,'repeatedPhaseGroups0Based':[[0,2],[3,8],[4,5,6]],
    'canvas':{'size':list(CANVAS),'anchor':list(ANCHOR)},'sourceSheets':source_info,
    'scaleCalibration':{'method':'Cap-crown-to-front-sole height, narrow manually selected cap ROIs excluding the axe.',
                        'ABMeanHeight':source_height,'CDEFMeanHeight':target_height,'sharedABFactor':factor,
                        'ABResizeDimensions':poses[0]['workingSize'],'ABSameScale':True,'rounding':'Both output dimensions rounded to integer pixels.'},
    'uniquePoses':poses,'frames':frames,
    'keyposesSheet':{'file':'keyposes-sheet.png','grid':[3,2],'size':[1920,960],'sha256':sha((OUT/'keyposes-sheet.png').read_bytes())},
    'spriteSheet':{'file':'sprite-sheet.png','grid':[5,2],'size':[3200,960],'sha256':sha((OUT/'sprite-sheet.png').read_bytes())},
    'reviews':reviews,'gifEncoding':{'palette':'One shared 256-colour median-cut palette; no dithering. PNGs remain RGB.'},
    'provenance':{'generationTool':'OpenAI built-in image_gen','imageGenerationCalls':4,
                   'passes':[{'call':i+1,**file_info(GEN/name),'use':use} for i,(name,use) in enumerate(calls)],
                   'prompts':[{'file':k,'sha256':v} for k,v in prompts.items()],
                   'originalPoseReference':'original_game_data/kam-reference-export/lumberjack-full-set/chop-SE-six-unique-guide.png',
                   'grip':'Both hands visibly hold one axe handle in all six selected final poses.',
                   'poseFidelity':'Source-based generative redraw; approximate, not exact pose tracing or approved geometry.'},
    'status':{'statusDate':'2026-09-10','reviewStatus':'awaiting-user-review','supersedes':'v2 rejected for incorrect one-handed grip',
              'userApproved':False,'gameIntegrated':False,'inGameValidated':False,'trueAlphaAchieved':False,
              'background':'RGB near-white, opaque; no background removal. Added padding is pure white.',
              'groundShadow':'No separate ground/contact/cast shadow observed in selected source images.'},
    'validation':{'sourceCopiesByteExact':True,'rawCropsPixelExact':True,'ABResampled':True,'CDEFRawRGBRetained':True,
                  'translationPreservesWorkingPixels':True,'allMeasuredSilhouettesUnclipped':True,'frontBootAnchorsEqual':True,
                  'sixUniquePoses':True,'repeatedFilesBitwiseIdentical':True,'gifTimelineVerifiedAfterDecode':True,'sourceAndPromptsUnchanged':True},
    'notes':['A/B use shared Lanczos resampling; it would be incorrect to call all output pixels source-exact or claim no rescaling.',
             'Only the front plantar anchor is aligned; generated differences in body and boot shapes are preserved.',
             'Preview FPS is a review choice, not original game timing or game QA.']}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(OUT/'README.md').write_text(f'''# Dřevorubec — sekání SE, v3

Varianta z 2026-09-10 používá **obě ruce na jednom topůrku** ve všech šesti vybraných pózách. Nahrazuje v2 zamítnutou pro chybný jednoruční úchop. Jde o přibližné generativní překreslení původních póz KaM, nikoli přesné trasování. **Není schválená ani zapojená či ověřená ve hře.**

Finální A/B pocházejí ze čtvrtého průchodu (2 × 1, 2092 × 752 px), C/D/E/F ze druhého průchodu (buňky 2/3/4/5 mřížky 3 × 2, 1808 × 870 px). První a třetí průchod měly vadné úchopy A/B a ve finálních snímcích se nepoužívají. Všechna čtyři původní zadání jsou zachovaná.

- `source-final-AB.png`, `source-final-CDEF.png`: obě zdrojové sheets zkopírované beze změn.
- `raw-keyposes/A.png` až `F.png`: přesné původní výřezy.
- `unique-frames/A.png` až `F.png`: šest finálních póz na plátně 640 × 480 px, kotva přední podrážky **[256,440]**.
- `frames/00.png` až `09.png`: pořadí **A,B,A,C,D,D,D,E,C,F**. Opakované fáze jsou bitově totožné PNG.
- `keyposes-sheet.png`: šest registrovaných póz 3 × 2; `sprite-sheet.png`: deset fází 5 × 2.
- `review-10fps.gif`, `review-5fps.gif`: přesná tříslotová výdrž D; společná 256barevná paleta.
- `manifest.json`: původ, měření, posuny, převzorkování a SHA-256; `pack.py`: opakovatelný převod.

**A/B jsou převzorkované, nikoli pixelově totožné se zdrojem.** Výška od vrcholu čepice k podrážce je u obou 580 px; průměr C–F je 351,25 px. Jediný společný faktor **{factor:.9f}** převádí oba výřezy 1046 × 752 na **633 × 455 px** filtrem Lanczos. Měřilo se v úzkém výřezu koruny čepice, bez sekery. C–F se nezvětšovaly ani nezmenšovaly; používají pouze celočíselné posuny. Zachované pixely C–F i pracovní pixely A/B po převzorkování jsou posunuty beze změny. Ořez se týká jen prázdného pozadí, siluety jsou celé.

**RGB, neprůhledné téměř bílé pozadí, žádný skutečný alfa kanál.** Samostatný zemní stín není na vybraných zdrojích patrný. Pozadí se neodstraňovalo ani nepřebarvovalo; doplněné okraje jsou #FFFFFF. Kontroly potvrdily společné kotvy, šest unikátních póz, nezměněné zdrojové kopie a výřezy, bezpečné okraje a správnou časovou osu dekódovaných GIFů. Náhledové FPS nejsou potvrzením původního herního časování.
''')
print(json.dumps({'output':str(OUT),'factorAB':factor,'canvas':manifest['canvas'],
                  'poses':[{k:p[k] for k in ('id','workingSize','workingSoleAnchor','integerOffset','registeredFigureBoundsExclusive')} for p in poses],
                  'validation':manifest['validation']},ensure_ascii=False,indent=2))
