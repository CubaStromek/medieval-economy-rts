#!/usr/bin/env python3
"""Package the six generated chopping poses using integer translation only.

Run with bundled Python/Pillow. All writes stay beside this helper.
The generated source and prompt files are read-only inputs.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json
import shutil

from PIL import Image, ImageChops

OUT = Path(__file__).resolve().parent
SOURCE = Path('/Users/openclaw/.codex/generated_images/01a087a4-bf3d-7f70-b463-afa4f5165f3c/exec-da040ec8-ce49-40af-bb3c-09b8d7566ad1.png')
FIRST_DRAFT = SOURCE.parent / 'exec-66317aa1-d10c-4673-bcf0-20df5e089997.png'
IDENTITY = OUT.parent / 'lumberjack-without-log-SE-kam-v1/frames/00.png'
SEQUENCE = list('ABACDDDECF')
SOURCE_IDS = [1614, 1613, 1614, 1616, 2826, 1618, 1618, 1617, 1616, 1615]
POSE_IDS = {'A': [1614], 'B': [1613], 'C': [1616], 'D': [2826, 1618], 'E': [1617], 'F': [1615]}
CANVAS = (640, 480)
TARGET_ANCHOR = (256, 440)
BACKGROUND_THRESHOLD = 245
SOLE_BAND_ROWS = 4
sha = lambda b: hashlib.sha256(b).hexdigest()


def file_data(path):
    return {'path': str(path), 'sha256': sha(path.read_bytes()), 'sizeBytes': path.stat().st_size}


def near_white_stats(images):
    samples = []
    for im in images:
        w, h = im.size
        for x, y in [(0, 0), (w - 16, 0), (0, h - 16), (w - 16, h - 16)]:
            b = im.crop((x, y, x + 16, y + 16)).tobytes()
            samples.extend(tuple(b[j:j + 3]) for j in range(0, len(b), 3))
    counts = Counter(samples)
    return {
        'method': 'Four 16x16 corner patches from each original full-cell pose crop.',
        'samplePixels': len(samples), 'exactWhitePixels': counts[(255, 255, 255)],
        'uniqueSampleColours': len(counts),
        'channelMin': [min(v[k] for v in samples) for k in range(3)],
        'channelMax': [max(v[k] for v in samples) for k in range(3)],
        'mostCommon': [{'rgb': list(rgb), 'pixels': n} for rgb, n in counts.most_common(8)],
        'perfectlyUniformWhite': len(counts) == 1 and (255, 255, 255) in counts,
        'sourceBackgroundModified': False,
    }


source_before = file_data(SOURCE)
prompt_before = {p.name: sha(p.read_bytes()) for p in sorted(OUT.glob('prompt-*.txt'))}
assert len(prompt_before) == 2
shutil.copyfile(SOURCE, OUT / 'keyposes-sheet.png')
assert sha((OUT / 'keyposes-sheet.png').read_bytes()) == source_before['sha256']
sheet = Image.open(OUT / 'keyposes-sheet.png')
assert sheet.size == (1809, 869) and sheet.mode == 'RGB'
assert 'transparency' not in sheet.info
xs = [i * sheet.width // 3 for i in range(4)]
ys = [i * sheet.height // 2 for i in range(3)]
for folder in ('raw-keyposes', 'unique-frames', 'frames'):
    (OUT / folder).mkdir(exist_ok=True)

raw_images, registered_images, poses = {}, {}, []
for index, label in enumerate('ABCDEF'):
    col, row = index % 3, index // 3
    rect = (xs[col], ys[row], xs[col + 1], ys[row + 1])
    raw = sheet.crop(rect)
    raw_path = OUT / 'raw-keyposes' / f'{label}.png'
    raw.save(raw_path)
    with Image.open(raw_path) as decoded:
        assert decoded.mode == 'RGB' and decoded.tobytes() == raw.tobytes()
    raw_images[label] = raw

    # Diagnostic foreground mask only; never applied to the image itself.
    # Background is near white. The lowest four foreground rows belong to
    # the front boot sole, as visually checked in all six original cells.
    r, g, b = raw.split()
    minimum = ImageChops.darker(ImageChops.darker(r, g), b)
    mask = minimum.point(lambda v: 255 if v < BACKGROUND_THRESHOLD else 0)
    foreground = mask.getbbox()
    assert foreground is not None
    bottom = foreground[3] - 1
    band = mask.crop((0, bottom - SOLE_BAND_ROWS + 1, raw.width, bottom + 1))
    sole = band.getbbox()
    assert sole is not None
    sole_left, sole_right = sole[0], sole[2] - 1
    anchor = ((sole_left + sole_right) // 2, bottom)
    offset = (TARGET_ANCHOR[0] - anchor[0], TARGET_ANCHOR[1] - anchor[1])

    # Whole-body/axe bounds are used ONLY for clipping verification, never
    # to centre, resize, or register the pose.
    registered_bounds = tuple(foreground[k] + offset[k % 2] for k in range(4))
    assert 0 <= registered_bounds[0] < registered_bounds[2] <= CANVAS[0]
    assert 0 <= registered_bounds[1] < registered_bounds[3] <= CANVAS[1]
    image = Image.new('RGB', CANVAS, (255, 255, 255))
    image.paste(raw, offset)

    # Verify every retained source pixel, including near-white background,
    # is an unchanged integer translation. Only background outside the
    # canvas is clipped. The entire original cell also survives in raw/.
    retained = (max(0, -offset[0]), max(0, -offset[1]),
                min(raw.width, CANVAS[0] - offset[0]),
                min(raw.height, CANVAS[1] - offset[1]))
    dest = (retained[0] + offset[0], retained[1] + offset[1],
            retained[2] + offset[0], retained[3] + offset[1])
    assert image.crop(dest).tobytes() == raw.crop(retained).tobytes()
    assert foreground[0] >= retained[0] and foreground[1] >= retained[1]
    assert foreground[2] <= retained[2] and foreground[3] <= retained[3]
    unique_path = OUT / 'unique-frames' / f'{label}.png'
    image.save(unique_path)
    with Image.open(unique_path) as decoded:
        assert decoded.size == CANVAS and decoded.mode == 'RGB'
        assert decoded.tobytes() == image.tobytes()
    registered_images[label] = image
    poses.append({
        'id': label, 'originalKaMSpriteIds1Based': POSE_IDS[label],
        'rawFile': f'raw-keyposes/{label}.png',
        'rawCellRect': [rect[0], rect[1], raw.width, raw.height],
        'rawSize': list(raw.size), 'rawSha256': sha(raw_path.read_bytes()),
        'rawPixelsSha256': sha(raw.tobytes()),
        'measuredFrontBootSoleAnchor': list(anchor),
        'measuredSoleBandBoundsInclusive': [sole_left, bottom - SOLE_BAND_ROWS + 1, sole_right, bottom],
        'sourceFigureBoundsExclusive': list(foreground),
        'integerOffset': list(offset),
        'retainedSourceRectExclusive': list(retained),
        'registeredFigureBoundsExclusive': list(registered_bounds),
        'registeredFrontBootAnchor': list(TARGET_ANCHOR),
        'file': f'unique-frames/{label}.png', 'size': list(CANVAS),
        'mode': 'RGB', 'hasAlpha': False,
        'sha256': sha(unique_path.read_bytes()), 'pixelsSha256': sha(image.tobytes()),
        'allFigurePixelsRetained': True, 'retainedSourcePixelsUnchanged': True,
    })

assert len({p['pixelsSha256'] for p in poses}) == 6
assert len({p['sha256'] for p in poses}) == 6
frames = []
for i, label in enumerate(SEQUENCE):
    path = OUT / 'frames' / f'{i:02d}.png'
    shutil.copyfile(OUT / 'unique-frames' / f'{label}.png', path)
    assert path.read_bytes() == (OUT / 'unique-frames' / f'{label}.png').read_bytes()
    frames.append({'index': i, 'pose': label, 'originalKaMSpriteId1Based': SOURCE_IDS[i],
                   'file': f'frames/{i:02d}.png', 'size': list(CANVAS),
                   'anchor': list(TARGET_ANCHOR), 'sha256': sha(path.read_bytes())})
atlas = Image.new('RGB', (CANVAS[0] * 5, CANVAS[1] * 2), (255, 255, 255))
for i, label in enumerate(SEQUENCE):
    xy = ((i % 5) * CANVAS[0], (i // 5) * CANVAS[1])
    atlas.paste(registered_images[label], xy)
    assert atlas.crop((xy[0], xy[1], xy[0] + CANVAS[0], xy[1] + CANVAS[1])).tobytes() == registered_images[label].tobytes()
atlas.save(OUT / 'sprite-sheet.png')

# A single global palette serves every GIF frame. PNGs stay full RGB.
shared = atlas.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
palette = shared.getpalette()
quantized = {label: image.quantize(palette=shared, dither=Image.Dither.NONE)
             for label, image in registered_images.items()}
qframes = [quantized[label] for label in SEQUENCE]
background_index = min(range(256), key=lambda j: sum((palette[j * 3 + k] - 255) ** 2 for k in range(3)))
gifs = []
for fps in (10, 5):
    duration = 1000 // fps
    filename = f'review-{fps}fps.gif'
    path = OUT / filename
    qframes[0].save(path, save_all=True, append_images=qframes[1:], duration=duration,
                    loop=0, disposal=2, optimize=False, background=background_index, palette=palette)
    actual_durations, logical = [], []
    with Image.open(path) as gif:
        assert gif.size == CANVAS and gif.info.get('loop') == 0
        assert 'transparency' not in gif.info
        encoded_count = gif.n_frames
        for i in range(encoded_count):
            gif.seek(i)
            delay = gif.info['duration']
            assert delay % duration == 0
            actual_durations.append(delay)
            logical.extend([gif.convert('RGB').tobytes()] * (delay // duration))
    assert len(logical) == 10 and sum(actual_durations) == duration * 10
    assert logical == [q.convert('RGB').tobytes() for q in qframes]
    gifs.append({'file': filename, 'fps': fps, 'logicalFrameCount': 10,
                 'encodedFrameCount': encoded_count, 'encodedDurationsMs': actual_durations,
                 'totalDurationMs': sum(actual_durations), 'size': list(CANVAS),
                 'repeatHoldTimingExact': True, 'hasTransparency': False,
                 'sha256': sha(path.read_bytes()), 'sizeBytes': path.stat().st_size})

assert file_data(SOURCE) == source_before
assert all(sha((OUT / name).read_bytes()) == value for name, value in prompt_before.items())
background = near_white_stats(list(raw_images.values()))
manifest = {
    'version': 1, 'createdDate': '2026-09-10', 'name': 'Dřevorubec — sekání SE, první pilot podle KaM póz',
    'direction': 'SE', 'frameCount': 10, 'uniquePoseCount': 6, 'sequence': SEQUENCE,
    'originalKaMSpriteIds1Based': SOURCE_IDS,
    'repeatedPhaseGroups0Based': [[0, 2], [3, 8], [4, 5, 6]],
    'originalKaMRepeatNote': 'Source IDs 2826 and 1618 render identically in the extracted SE sequence; slots 5–7 are the three-slot low-strike hold.',
    'sourceSheet': {'file': 'keyposes-sheet.png', 'size': list(sheet.size), 'mode': 'RGB', 'hasAlpha': False,
                    'grid': [3, 2], 'columnBoundaries': xs, 'rowBoundaries': ys,
                    'sha256': source_before['sha256'], 'copiedByteForByte': True},
    'canvas': {'size': list(CANVAS), 'anchor': list(TARGET_ANCHOR),
               'anchorMeaning': 'Measured plantar anchor of the static planted front boot; midpoint of the bottom four non-background rows.'},
    'registration': {'method': 'Integer translation of original full-cell RGB crops, with white canvas padding and empty-background-only clipping.',
                     'foregroundDiagnosticThreshold': {'test': 'min(R,G,B) < threshold', 'threshold': BACKGROUND_THRESHOLD},
                     'soleBandRows': SOLE_BAND_ROWS, 'usesAxeOrWholeBodyCentroid': False,
                     'perPoseRescale': False, 'recolour': False, 'cutout': False, 'alphaExtraction': False,
                     'repaint': False, 'bothBootShapesMadeIdentical': False,
                     'note': 'Only the measured front plantar anchor is aligned. Natural/generated differences in boot shape or rear-foot placement are preserved.'},
    'uniquePoses': poses, 'frames': frames,
    'spriteSheet': {'file': 'sprite-sheet.png', 'grid': [5, 2], 'size': list(atlas.size), 'mode': 'RGB', 'hasAlpha': False,
                    'sha256': sha((OUT / 'sprite-sheet.png').read_bytes())},
    'reviews': gifs,
    'gifEncoding': {'palette': 'One shared 256-colour median-cut palette; no dithering.',
                     'paletteSha256': sha(bytes(palette)),
                     'note': 'GIF necessarily uses palette reduction; all PNG source/crop/registration pixels retain original RGB values.'},
    'background': background,
    'provenance': {'generationTool': 'OpenAI built-in image_gen', 'imageGenerationCalls': 2,
                    'firstDraft': file_data(FIRST_DRAFT), 'finalGeneratedImage': source_before,
                    'characterIdentity': file_data(IDENTITY),
                    'originalPoseReference': 'original_game_data/kam-reference-export/lumberjack-full-set/frames/uaWork/SE',
                    'prompts': [{'file': k, 'sha256': v} for k, v in prompt_before.items()],
                    'grip': 'Two-handed grip is an artistic interpretation of this generated sheet, not a verified exact KaM hand pose.',
                    'poseFidelity': 'Approximate generative interpretation of the original six poses and ten-slot sequence.'},
    'status': {'pilot': True, 'userApproved': False, 'gameIntegrated': False, 'inGameValidated': False,
               'trueAlphaAchieved': False, 'groundShadow': 'No separate ground/contact/cast shadow apparent in source visual inspection; RGB near-white background remains opaque.'},
    'validation': {'rawCellsPixelExact': True, 'retainedRegisteredPixelsExact': True, 'allMeasuredSilhouettesUnclipped': True,
                   'frontBootAnchorsEqual': True, 'uniqueSix': True, 'repeatFilesBitwiseIdentical': True,
                   'spriteSheetCellsPixelExact': True, 'gifTimelineVerifiedAfterDecode': True,
                   'sourceAndPromptsUnchanged': True},
    'notes': ['Preview FPS is a review choice, not a claim of original KaM timing or in-game validation.',
              'Source RGB background is retained; padding alone is pure white. No background cleanup was applied.',
              'No HTML viewer or game-production files are created by this packer.'],
}
(OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
(OUT / 'README.md').write_text(f'''# Dřevorubec — sekání SE, první pilot

Vlastní malovaná postava podle šesti původních KaM póz, sestavená do desetifázové sekvence **A, B, A, C, D, D, D, E, C, F**. Fáze D se drží tři časové sloty. Jde o přibližnou výtvarnou interpretaci; obouruční úchop v této kresbě není ověřenou přesnou kopií KaM úchopu.

- `keyposes-sheet.png`: nezměněná kopie výsledku 1809 × 869 px, šest póz v mřížce 3 × 2.
- `raw-keyposes/A.png` až `F.png`: celé původní buňky; horní řada 603 × 434, dolní 603 × 435 px.
- `unique-frames/A.png` až `F.png`: šest póz na společném plátně 640 × 480 px.
- `frames/00.png` až `09.png`: deset fází v původním pořadí; opakované fáze jsou bitově totožné soubory.
- `sprite-sheet.png`: registrovaná sekvence 5 × 2, celkem 3200 × 960 px.
- `review-10fps.gif`, `review-5fps.gif`: náhledy s přesnou tříslotovou výdrží D. GIF používá jednu společnou 256barevnou paletu, PNG zůstávají plně RGB.
- `manifest.json`: všechny výřezy, měření podrážky, celočíselné posuny, hashe a kontrolní výsledky.
- `pack.py`: opakovatelný převod; vyžaduje Python s Pillow a původní uvedené vstupy.

Zarovnání používá střed nejnižších čtyř řádků přední podrážky. Tento bod leží ve všech pózách na **[256, 440]**. Měřené původní kotvy A–F jsou **[352,429], [339,429], [307,429], [352,399], [343,399], [312,399]**. Použily se pouze celočíselné posuny a doplnění bílého plátna; ořez odstranil jen prázdné pozadí vlevo. Nezměnilo se měřítko, kresba, barvy ani tvar bot. Případné rozdíly zadní boty zůstávají zachované. Nejvyšší část sekery má po registraci 22 px rezervu od horní hrany.

**Všechny PNG jsou RGB bez skutečné průhlednosti.** Nebyl přidán zemní stín. Původní téměř bílé pozadí se nečistilo; nové okraje plátna jsou #FFFFFF. V rohových vzorcích původních buněk je {{background['exactWhitePixels']}} z {{background['samplePixels']}} pixelů přesně bílých, hodnoty kanálů {{background['channelMin']}} až {{background['channelMax']}}.

Vytvořeno 10. 9. 2026 dvěma voláními vestavěného `image_gen`; `prompt-01.txt` a `prompt-02.txt` zůstaly nezměněné. Původní KaM pořadí RX ID: **1614, 1613, 1614, 1616, 2826, 1618, 1618, 1617, 1616, 1615**.

Kontroly ověřily nezměněné pixely původních výřezů i všech zachovaných oblastí po posunu, bezpečné okraje celé siluety, shodné plantární kotvy, šest unikátních póz, bitově totožné opakované soubory a správnou časovou osu dekódovaných GIFů.

Pilot není schválený ani zapojený do hry a neprošel herním QA. Rychlosti 10 a 5 fps jsou pouze náhledové; nepotvrzují původní herní časování.
'''.replace("{background['exactWhitePixels']}", str(background['exactWhitePixels']))
   .replace("{background['samplePixels']}", str(background['samplePixels']))
   .replace("{background['channelMin']}", str(background['channelMin']))
   .replace("{background['channelMax']}", str(background['channelMax'])))
print(json.dumps({'output': str(OUT), 'anchors': {p['id']: p['measuredFrontBootSoleAnchor'] for p in poses},
                  'sequence': SEQUENCE, 'canvas': manifest['canvas'], 'reviews': gifs,
                  'validation': manifest['validation']}, ensure_ascii=False, indent=2))
