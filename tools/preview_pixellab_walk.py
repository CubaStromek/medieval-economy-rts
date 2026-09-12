#!/usr/bin/env python3
"""Pack and inspect eight-direction PixelLab PNG frames without editing their pixels.

Input: OUTPUT/frames/{N,NE,E,SE,S,SW,W,NW}/00.png, 01.png, ...
Output: OUTPUT/preview.html, atlas.png, contact-sheet.png, gifs/, qa.json, qa-summary.md.
The HTML embeds original PNG bytes; it also works offline. The atlas retains
whole source canvases at native resolution, with no trim or foot registration.
Pillow is only used for lossless packing, measurements, and labeled previews.
"""

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import html
import json
from pathlib import Path
import statistics

from PIL import Image, ImageChops, ImageDraw, ImageStat


DIRECTIONS = ("N", "NE", "E", "SE", "S", "SW", "W", "NW")
LABELS = {"N": "Sever ↑", "NE": "Severovýchod ↗", "E": "Východ →",
          "SE": "Jihovýchod ↘", "S": "Jih ↓", "SW": "Jihozápad ↙",
          "W": "Západ ←", "NW": "Severozápad ↖"}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def bounds(alpha, threshold):
    """Pillow bounds: left/top inclusive, right/bottom exclusive."""
    return alpha.point(lambda value: 255 if value >= threshold else 0).getbbox()


def checker(size, tile=12):
    image = Image.new("RGBA", size, (40, 47, 50, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(53, 61, 63, 255))
    return image


def measure(path, root):
    original = path.read_bytes()
    with Image.open(path) as image:
        image.load()
        mode = image.mode
        has_alpha_storage = "A" in image.getbands() or "transparency" in image.info
        rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    histogram = alpha.histogram()
    width, height = rgba.size
    edge_alpha = ([alpha.getpixel((x, 0)) for x in range(width)]
                  + [alpha.getpixel((x, height - 1)) for x in range(width)]
                  + [alpha.getpixel((0, y)) for y in range(1, height - 1)]
                  + [alpha.getpixel((width - 1, y)) for y in range(1, height - 1)])
    info = {
        "file": str(path.relative_to(root)), "width": width, "height": height,
        "source_mode": mode, "sha256": sha256(original),
        "rgba_sha256": sha256(rgba.tobytes()), "has_alpha_storage": has_alpha_storage,
        "alpha_min_max": alpha.getextrema(),
        "transparent_pixels": histogram[0], "opaque_pixels": histogram[255],
        "partial_alpha_pixels": sum(histogram[1:255]),
        "has_visible_content_and_transparency": histogram[0] > 0 and sum(histogram[1:]) > 0,
        "nonzero_alpha_border_pixels": sum(value > 0 for value in edge_alpha),
        "bounds_alpha_ge_1": bounds(alpha, 1), "bounds_alpha_ge_16": bounds(alpha, 16),
        "bounds_alpha_ge_128": bounds(alpha, 128),
    }
    return rgba, info, "data:image/png;base64," + base64.b64encode(original).decode("ascii")


def delta(first, second):
    if first.size != second.size:
        return None
    return round(statistics.mean(ImageStat.Stat(ImageChops.difference(first, second)).mean), 5)


def save_preview_gif(frames, path, duration_ms=100):
    """Save flattened review GIF with one shared palette; original PNGs stay intact."""
    # A shared palette prevents avoidable palette shifts between GIF frames.
    sample = Image.new("RGB", (frames[0].width, frames[0].height * len(frames)))
    for index, frame in enumerate(frames):
        sample.paste(frame.convert("RGB"), (0, index * frames[0].height))
    palette = sample.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    indexed = [frame.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    indexed[0].save(path, save_all=True, append_images=indexed[1:], duration=duration_ms,
                    loop=0, disposal=2, optimize=False)
    with Image.open(path) as check:
        actual_count = check.n_frames
    if actual_count != len(frames):
        raise ValueError(f"GIF frame count mismatch: {path}: {actual_count} != {len(frames)}")
    return {"file": str(path), "frames": actual_count, "duration_ms_per_frame": duration_ms,
            "sha256": sha256(path.read_bytes()),
            "format_note": "Review only: background flattened and GIF shared 256-color palette; original RGBA PNGs remain authoritative."}


def gif_card(image, name, frame_index, frame_count, body_height):
    """A fixed-canvas, two-scale card; no content-dependent frame registration."""
    card = checker((280, 360)).convert("RGB")
    draw = ImageDraw.Draw(card)
    draw.text((12, 10), f"{name}  {frame_index+1:02d}/{frame_count:02d}", fill="white")
    scale = min(250 / image.width, 230 / image.height)
    large = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.NEAREST)
    card.paste(large, ((280-large.width)//2, 32+(230-large.height)//2), large)
    scale = 33 / body_height
    small = image.resize((round(image.width*scale), round(image.height*scale)), Image.Resampling.NEAREST)
    card.paste(small, ((280-small.width)//2, 284+(64-small.height)//2), small)
    return card


HTML = r'''<!doctype html>
<html lang="cs"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Dřevorubec · PixelLab · chůze</title>
<style>
:root{color-scheme:dark;font:15px/1.5 system-ui,sans-serif;background:#141b1b;color:#e9eee7}
*{box-sizing:border-box}body{margin:0;padding:30px;max-width:1440px;margin:auto}
h1{margin:0;font:600 30px/1.15 system-ui}p{color:#aebcb3;max-width:960px}a{color:#b6d999}
header{border-bottom:1px solid #34413b;margin-bottom:20px;padding-bottom:14px}
.eyebrow{font-size:12px;letter-spacing:.18em;color:#bad59e;margin-bottom:10px;text-transform:uppercase}
.controls{display:flex;flex-wrap:wrap;align-items:center;gap:12px;padding:15px;background:#22302a;border:1px solid #3b4c41;border-radius:10px;margin:20px 0}
button,select{font:inherit;border:1px solid #5a6e5e;border-radius:6px;color:#eaf0e6;background:#314637;padding:7px 12px;cursor:pointer}
label{display:flex;gap:8px;align-items:center}.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px}
.card{background:#1e2824;border:1px solid #3a473e;border-radius:10px;overflow:hidden}
.card h2{font-size:16px;font-weight:600;margin:10px 14px}.card h2 span{color:#aebcb3;font-weight:400}
.stage{display:flex;align-items:center;justify-content:center;background-color:#2b3335;background-image:linear-gradient(45deg,#353f41 25%,transparent 25%),linear-gradient(-45deg,#353f41 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#353f41 75%),linear-gradient(-45deg,transparent 75%,#353f41 75%);background-size:24px 24px;background-position:0 0,0 12px,12px -12px,-12px 0}
.stage.large{height:260px}.stage.small{height:100px;border-top:1px solid #475249}canvas{display:block}
body[data-bg="grass"] .stage{background:#627546;background-image:none}body[data-bg="light"] .stage{background:#eee9db;background-image:none}body[data-bg="dark"] .stage{background:#101416;background-image:none}
.caption{font-size:12px;color:#aebcb3;margin:7px 14px}.status{background:#26382b;border:1px solid #52694e;padding:12px 16px;border-radius:8px}.status.warn{background:#413622;border-color:#8a7041;color:#f0dbb7}
footer{color:#aebcb3;font-size:13px;margin-top:25px}#frame{min-width:94px;font-variant-numeric:tabular-nums}.range{flex:1;min-width:180px}input[type="range"]{width:100%;accent-color:#bedb8d}
@media(max-width:1050px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:580px){body{padding:16px}.grid{gap:9px}.stage.large{height:180px}.card h2{font-size:13px;margin:9px}.controls{gap:8px}h1{font-size:25px}}
</style>
<header><div class="eyebrow">PixelLab · animační zkouška</div><h1 id="title">Dřevorubec · chůze</h1>
<p>Chůze se sekerou. Nahoře detail, pod ním malý náhled. Všechny směry sdílejí čas. Pozastavením a krokováním lze zkontrolovat nohy, ruce i přechod posledního snímku na první.</p>
<div class="status" id="status"></div></header>
<div class="controls"><button id="toggle">Pozastavit</button><button id="prev" aria-label="Předchozí snímek">←</button><button id="next" aria-label="Další snímek">→</button>
<label>Tempo <select id="fps"><option value="5">5 fps</option><option value="10" selected>10 fps</option></select></label>
<label>Obraz <select id="filter"><option value="nearest">Ostré pixely</option><option value="smooth">Vyhlazený</option></select></label>
<label>Pozadí <select id="background"><option value="checker">Šachovnice</option><option value="grass">Zelené</option><option value="dark">Tmavé</option><option value="light">Světlé</option></select></label>
<span id="frame"></span><label class="range"><input id="scrub" type="range" min="0" value="0" aria-label="Snímek"></label></div>
<div class="grid" id="grid"></div>
<footer><p id="scale-note"></p><p>Samostatný náhled: původní snímky jsou vložené beze změn. Žádný snímek se individuálně neposouvá, neořezává ani nepřizpůsobuje podle nejnižší boty. Běžná hra, terénní kontakt, řazení a herní časování zde nejsou ověřeny. Zelené pozadí je plochá kontrolní barva.</p></footer>
<script id="asset-data" type="application/json">__DATA__</script>
<script>
const data=JSON.parse(document.getElementById('asset-data').textContent());
const $=id=>document.getElementById(id), cards=[];
let playing=true,current=0,fps=10,lastTick=performance.now(), ready=false;
const maxCount=Math.max(...data.directions.map(d=>d.frames.length)),smallScale=33/data.preview_body_height_source;
$('scrub').max=maxCount-1;
$('title').textContent=data.title;
$('scale-note').textContent=data.scale_note;
$('status').textContent=data.status;
if(data.warnings.length)$('status').classList.add('warn');
const pending=[];
for(const direction of data.directions){
 const card=document.createElement('article');card.className='card';
 const title=document.createElement('h2');title.textContent=direction.label+' · '+direction.name;card.append(title);
 const canvases=[];
 for(const mode of ['large','small']){
  const stage=document.createElement('div');stage.className='stage '+mode;
  const canvas=document.createElement('canvas');canvas.setAttribute('aria-label',direction.label+' '+(mode==='large'?'detail':'malý náhled'));stage.append(canvas);card.append(stage);canvases.push({canvas,stage,mode});
 }
 const caption=document.createElement('p');caption.className='caption';caption.textContent=direction.frames.length+' snímků · '+direction.width+' × '+direction.height+' px';card.append(caption);$('grid').append(card);
 const images=direction.frames.map(url=>{const image=new Image();pending.push(new Promise((resolve,reject)=>{image.onload=resolve;image.onerror=reject}));image.src=url;return image});
 cards.push({images,canvases,width:direction.width,height:direction.height});
}
function draw(){
 if(!ready)return;
 const smooth=$('filter').value==='smooth';
 for(const card of cards){
  for(const item of card.canvases){
   const cssWidth=item.stage.clientWidth,cssHeight=item.stage.clientHeight,dpr=window.devicePixelRatio||1;
   const canvas=item.canvas;canvas.style.width=cssWidth+'px';canvas.style.height=cssHeight+'px';canvas.width=Math.round(cssWidth*dpr);canvas.height=Math.round(cssHeight*dpr);
   const ctx=canvas.getContext('2d');ctx.setTransform(dpr,0,0,dpr,0,0);ctx.imageSmoothingEnabled=smooth;ctx.imageSmoothingQuality='high';
   const fit=Math.min((cssWidth-20)/card.width,(cssHeight-14)/card.height);
   const scale=item.mode==='small'?smallScale:fit;
   ctx.drawImage(card.images[current%card.images.length],(cssWidth-card.width*scale)/2,(cssHeight-card.height*scale)/2,card.width*scale,card.height*scale);
  }
 }
 $('frame').textContent='Snímek '+(current+1)+' / '+maxCount;$('scrub').value=current;
}
function setPlaying(value){playing=value;$('toggle').textContent=playing?'Pozastavit':'Přehrát';lastTick=performance.now()}
$('toggle').onclick=()=>setPlaying(!playing);
$('prev').onclick=()=>{setPlaying(false);current=(current-1+maxCount)%maxCount;draw()};
$('next').onclick=()=>{setPlaying(false);current=(current+1)%maxCount;draw()};
$('fps').onchange=()=>{fps=Number($('fps').value);lastTick=performance.now()};
$('scrub').oninput=()=>{setPlaying(false);current=Number($('scrub').value);draw()};
$('filter').onchange=draw;$('background').onchange=()=>{document.body.dataset.bg=$('background').value};
window.addEventListener('resize',draw);
function tick(now){if(playing&&ready&&now-lastTick>=1000/fps){const steps=Math.floor((now-lastTick)/(1000/fps));current=(current+steps)%maxCount;lastTick+=steps*1000/fps;draw()}requestAnimationFrame(tick)}
Promise.all(pending).then(()=>{ready=true;draw();requestAnimationFrame(tick)}).catch(()=>{$('status').textContent='Některý vložený snímek se nepodařilo načíst.';$('status').classList.add('warn')});
</script></html>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Directory containing frames/DIR/00.png etc.")
    parser.add_argument("--expected-frames", type=int, default=8)
    parser.add_argument("--directions", nargs="+", choices=DIRECTIONS, default=list(DIRECTIONS),
                        help="Deliver only actual available directions, e.g. --directions S for a partial pilot.")
    parser.add_argument("--input-layout", choices=("frames", "jobs"), default="frames",
                        help="frames reads frames/DIR/00.png; jobs reads jobs/DIR/images/frame_00.png.")
    parser.add_argument("--review-note", default="", help="Explicit known visual limitation displayed in the preview.")
    parser.add_argument("--body-height-source", type=float,
                        help="One explicitly measured source-pixel human height, excluding tool extent.")
    args = parser.parse_args()
    root = args.output.resolve()
    if args.expected_frames < 1 or (args.body_height_source is not None and args.body_height_source <= 0):
        parser.error("Frame count and body height must be positive.")
    all_frames, directions, warnings, sources = [], [], [], {}
    selected_directions = tuple(d for d in DIRECTIONS if d in args.directions)
    for direction in selected_directions:
        folder = root / "frames" / direction if args.input_layout == "frames" else root / "jobs" / direction / "images"
        paths = sorted(folder.glob("*.png"))
        if not paths:
            raise SystemExit(f"Missing frames: {folder}")
        prefix = "" if args.input_layout == "frames" else "frame_"
        expected_names = [f"{prefix}{index:02d}.png" for index in range(len(paths))]
        if [path.name for path in paths] != expected_names:
            raise SystemExit(f"{direction}: expected consecutive 00.png, 01.png, ...; found {[p.name for p in paths]}")
        if len(paths) != args.expected_frames:
            warnings.append(f"{direction}: {len(paths)} frames, expected {args.expected_frames}.")
        images, metadata, embedded = [], [], []
        for path in paths:
            image, info, url = measure(path, root)
            images.append(image); metadata.append(info); embedded.append(url)
            sources[path] = info["sha256"]
            if not info["has_visible_content_and_transparency"]:
                warnings.append(f"{info['file']}: missing visible content or true transparent pixels.")
            if info["nonzero_alpha_border_pixels"]:
                warnings.append(f"{info['file']}: visible alpha reaches canvas border; inspect possible clipping.")
        hashes = [info["rgba_sha256"] for info in metadata]
        duplicates = [[i, j] for i in range(len(hashes)) for j in range(i + 1, len(hashes)) if hashes[i] == hashes[j]]
        if duplicates:
            warnings.append(f"{direction}: identical RGBA frame pairs {duplicates}; verify intended holds.")
        directions.append({"name": direction, "label": LABELS[direction], "frames": embedded,
                           "width": images[0].width, "height": images[0].height})
        all_frames.append({"direction": direction, "images": images, "frames": metadata,
                           "duplicate_rgba_pairs": duplicates,
                           "adjacent_rgba_mean_differences_0_255": [delta(images[i], images[(i+1) % len(images)]) for i in range(len(images))]})
    sizes = {image.size for direction in all_frames for image in direction["images"]}
    if len(sizes) != 1:
        raise SystemExit(f"Different canvas sizes {sizes}; no implicit normalization is allowed.")
    width, height = next(iter(sizes))
    counts = {len(direction["frames"]) for direction in all_frames}
    if len(counts) != 1:
        raise SystemExit(f"Different directional frame counts {counts}; no implicit repeated frames or truncated cycles allowed.")
    frame_count = max(len(direction["frames"]) for direction in all_frames)
    atlas = Image.new("RGBA", (width * frame_count, height * len(selected_directions)))
    cells = []
    for row, direction in enumerate(all_frames):
        for col, image in enumerate(direction["images"]):
            atlas.paste(image, (col * width, row * height))
            cells.append({"direction": direction["direction"], "frame": col,
                          "rect_xywh": [col * width, row * height, width, height]})
    atlas_path = root / "atlas.png"
    atlas.save(atlas_path)
    with Image.open(atlas_path) as verify_atlas:
        for cell in cells:
            x, y, w, h = cell["rect_xywh"]
            expected = all_frames[selected_directions.index(cell["direction"])] ["frames"][cell["frame"]]["rgba_sha256"]
            actual = sha256(verify_atlas.crop((x, y, x+w, y+h)).tobytes())
            if expected != actual:
                raise SystemExit(f"Atlas pixel verification failed: {cell}")
    preview_scale = min(2, 192 / max(width, height))
    pw, ph = round(width * preview_scale), round(height * preview_scale)
    cell_width, cell_height, label_width = pw + 12, ph + 30, 52
    sheet = checker((label_width + cell_width * frame_count, cell_height * len(selected_directions)))
    draw = ImageDraw.Draw(sheet)
    for row, direction in enumerate(all_frames):
        draw.text((8, row * cell_height + 10), direction["direction"], fill="white")
        for col, image in enumerate(direction["images"]):
            x, y = label_width + col * cell_width + 6, row * cell_height + 24
            draw.text((x, y - 18), str(col + 1).zfill(2), fill=(224, 229, 221))
            sheet.alpha_composite(image.resize((pw, ph), Image.Resampling.NEAREST), (x, y))
    sheet.convert("RGB").save(root / "contact-sheet.png")
    heights = [frame["bounds_alpha_ge_16"][3] - frame["bounds_alpha_ge_16"][1]
               for direction in all_frames for frame in direction["frames"] if frame["bounds_alpha_ge_16"]]
    preview_body_height = args.body_height_source or statistics.median(heights or [height])
    if args.body_height_source:
        scale_note = f"Malý náhled: 33 px výšky člověka podle jediné zadané tělesné výšky {args.body_height_source:g} zdrojových px. Jde o náhledové měřítko; přesnou společnou kotvu nohou a skutečnou hru je ještě třeba ověřit."
    else:
        scale_note = f"Malý náhled je pouze orientační: 33 px mediánové výšky alfa obrysu ({preview_body_height:g} zdrojových px), který může zahrnovat sekeru. Tělesné měřítko zatím není kalibrované. Tento odhad se nepoužívá pro produkční registraci."
    status = f"{sum(len(d['frames']) for d in all_frames)} snímků · {width} × {height} px · "
    status += "technická kontrola vyžaduje pozornost" if warnings else "skutečná průhlednost ověřena · původní pixely zachovány"
    if args.review_note:
        status += ". " + args.review_note
    payload = {"directions": directions, "preview_body_height_source": preview_body_height,
               "title": "Dřevorubec v osmi směrech" if len(selected_directions) == 8 else "Dřevorubec · pilot " + ", ".join(selected_directions),
               "scale_note": scale_note, "status": status, "warnings": warnings, "review_note": args.review_note}
    (root / "preview.html").write_text(HTML.replace("__DATA__", json.dumps(payload, ensure_ascii=False).replace("</", "<\\/")), encoding="utf-8")
    gif_root = root / "gifs"
    gif_root.mkdir(exist_ok=True)
    gif_records, cards = [], {}
    for direction in all_frames:
        name = direction["direction"]
        cards[name] = [gif_card(im, name, i, frame_count, preview_body_height)
                       for i, im in enumerate(direction["images"])]
        record = save_preview_gif(cards[name], gif_root / f"{name}-10fps.gif")
        record["file"] = str(Path(record["file"]).relative_to(root))
        gif_records.append(record)
    overview_frames = []
    columns = min(4, len(selected_directions))
    rows = (len(selected_directions) + columns - 1) // columns
    for i in range(frame_count):
        overview = Image.new("RGB", (columns*280, rows*360))
        for j, name in enumerate(selected_directions):
            overview.paste(cards[name][i], ((j%columns)*280, (j//columns)*360))
        overview_frames.append(overview)
    record = save_preview_gif(overview_frames, gif_root / "overview-10fps.gif")
    record["file"] = str(Path(record["file"]).relative_to(root))
    gif_records.append(record)
    unchanged = all(sha256(path.read_bytes()) == digest for path, digest in sources.items())
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "tool": "tools/preview_pixellab_walk.py", "status": "warnings" if warnings else "technical_checks_passed",
        "expected_directions": selected_directions, "expected_frames_per_direction": args.expected_frames,
        "full_eight_direction_delivery": len(selected_directions) == 8, "review_note": args.review_note,
        "frame_count": sum(len(d["frames"]) for d in all_frames),
        "uniform_canvas": [width, height], "bbox_convention": "left/top inclusive; right/bottom exclusive",
        "source_files_unchanged": unchanged, "atlas_cells_exact_rgba_match": True,
        "registration": "whole source canvases, unchanged; no automatic trim, pivot, or foot alignment",
        "measured_human_height_source_px": args.body_height_source,
        "preview_only_scale_source_height": preview_body_height, "preview_scale_note": scale_note,
        "atlas": {"file": "atlas.png", "size": list(atlas.size), "sha256": sha256(atlas_path.read_bytes()), "cells": cells},
        "directions": [{k: v for k, v in direction.items() if k != "images"} for direction in all_frames],
        "review_gifs": gif_records,
        "warnings": warnings,
        "not_verified": ["visual identity and axe grip", "gait/loop quality", "common physical foot anchor", "ground contact in game", "normal game integration", "user acceptance"],
    }
    (root / "qa.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    rows = ["# Automatická technická kontrola PixelLab chůze", "", f"Datum: {report['generated_at']}", "",
            f"- Snímky: {report['frame_count']}; canvas: {width} × {height} px.",
            f"- Původní soubory beze změny: {unchanged}; přesná shoda RGBA atlasových buněk: ano.",
            "- Žádný ořez, změna velikosti zdrojů ani automatická registrace nohou.",
            f"- {scale_note}", "", "| Směr | Snímky | Skutečně průhledné | Odlišné RGBA |",
            "|---|---:|---:|---:|"]
    for direction in all_frames:
        rows.append(f"| {direction['direction']} | {len(direction['frames'])} | {sum(f['has_visible_content_and_transparency'] for f in direction['frames'])} | {len(set(f['rgba_sha256'] for f in direction['frames']))} |")
    rows.extend(["", "## Upozornění", "", *([f"- {w}" for w in warnings] or ["Žádné z automatických kontrol. To není vizuální přijetí animace."]),
                 "", "## Neověřeno", "", "Vzhled, úchop sekery, kvalita kroku, návaznost smyčky, společná fyzická kotva nohou, kontakt a nasazení v běžné hře, přijetí uživatelem.",
                 "", "Podrobné otisky, alpha histogramy a meze každého snímku: [qa.json](qa.json).", ""])
    (root / "qa-summary.md").write_text("\n".join(rows), encoding="utf-8")
    if not unchanged:
        raise SystemExit("Source files changed during preview generation.")
    print(json.dumps({"output": str(root), "frame_count": report["frame_count"], "canvas": [width, height],
                      "warnings": warnings, "source_files_unchanged": unchanged, "atlas_cells_exact_rgba_match": True}, ensure_ascii=False))


if __name__ == "__main__":
    main()
