#!/usr/bin/env python3
"""Package PixelLab lumberjack clips without modifying or registering source pixels.

Input: ROOT/jobs/{walk_axe,chop,walk_log}/{N,NE,E,SE,S,SW,W,NW}/images/frame_XX.png
Output: ROOT/package (exact PNGs, per-clip RGBA atlases, explicit manifest),
ROOT/preview (full-color APNG and HTML), ROOT/pack-validation.json.
Coordinates and body height MUST be configured explicitly, never inferred from
an equipment-inclusive bounding box. A subset can be packaged as an honest pilot.
"""

import argparse
from datetime import datetime, timezone
from fractions import Fraction
import html
import json
import math
from pathlib import Path
import shutil
import struct
import zlib

from PIL import Image, ImageDraw

from preview_pixellab_walk import DIRECTIONS, LABELS, delta, measure, sha256


CLIPS = {"walk_axe": "Chůze se sekerou", "chop": "Obouruční kácení", "walk_log": "Chůze s kládou"}
VECTORS = {"N": [0, -1], "NE": [1, -1], "E": [1, 0], "SE": [1, 1],
           "S": [0, 1], "SW": [-1, 1], "W": [-1, 0], "NW": [-1, -1]}


def positive(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("must be a finite positive number")
    return number


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def exact_apng_frame_delay(path, fps):
    """Update APNG timing fields only; preserve every compressed image byte."""
    delay = (Fraction(1, 1) / Fraction(str(fps))).limit_denominator(65535)
    if not (1 <= delay.numerator <= 65535 and 1 <= delay.denominator <= 65535):
        raise ValueError(f"FPS {fps:g} cannot be represented by one APNG frame delay.")
    if abs(float(delay) - 1 / fps) > max(1e-9, 1e-7 / fps):
        raise ValueError(f"FPS {fps:g} cannot be represented accurately by APNG timing.")
    original = path.read_bytes()
    output = bytearray(original[:8])
    position = 8
    while position < len(original):
        length = struct.unpack(">I", original[position:position + 4])[0]
        kind = original[position + 4:position + 8]
        chunk = original[position + 8:position + 8 + length]
        if kind == b"fcTL":
            chunk = chunk[:20] + struct.pack(">HH", delay.numerator, delay.denominator) + chunk[24:]
            output.extend(struct.pack(">I", len(chunk)) + kind + chunk
                          + struct.pack(">I", zlib.crc32(kind + chunk)))
        else:
            output.extend(original[position:position + length + 12])
        position += length + 12
    path.write_bytes(output)
    return [delay.numerator, delay.denominator]


def apng(frames, path, fps, exact_timing=False):
    """Lossless true-color review with a frame label outside each source canvas.

    Labels prevent encoders from merging identical intentional hold frames.
    Each source canvas is pasted directly, preserving even invisible RGB bytes.
    """
    width, height = frames[0].size
    decorated = []
    for i, source in enumerate(frames):
        image = Image.new("RGBA", (width, height + 28))
        ImageDraw.Draw(image).text((8, 7), f"{i+1:02d}/{len(frames):02d}  {fps:g} fps", fill=(230, 235, 230, 255))
        image.paste(source, (0, 28))
        decorated.append(image)
    duration_ms = 1000 / fps
    decorated[0].save(path, format="PNG", save_all=True, append_images=decorated[1:],
                      duration=duration_ms, loop=0, disposal=1, blend=0, optimize=False)
    exact_delay = exact_apng_frame_delay(path, fps) if exact_timing else None
    with Image.open(path) as check:
        if check.n_frames != len(frames):
            raise ValueError(f"APNG count mismatch: {path}")
        actual_durations = []
        for i, source in enumerate(frames):
            check.seek(i)
            actual_durations.append(check.info.get("duration"))
            decoded = check.convert("RGBA").crop((0, 28, width, height + 28))
            if decoded.tobytes() != source.tobytes():
                raise ValueError(f"APNG source-pixel verification failed: {path}, frame {i}")
    timing_tolerance_ms = max(1e-6, duration_ms * 1e-7) if exact_timing else 0.5001
    if any(value is None or abs(value - duration_ms) > timing_tolerance_ms for value in actual_durations):
        raise ValueError(f"APNG duration verification failed: {path}")
    return {"file": str(path), "sha256": sha256(path.read_bytes()), "frame_count": len(frames),
            "fps": fps, "format": "APNG RGBA; no palette quantization", "source_rect_px": [0, 28, width, height],
            "decoded_duration_ms": actual_durations,
            "explicit_exact_frame_delay_seconds": exact_delay,
            "timing_verified_tolerance_ms": timing_tolerance_ms,
            "decoded_source_region_exact_rgba": True}


HTML = r'''<!doctype html><html lang="cs"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Dřevorubec · PixelLab v2</title><style>
:root{font:15px/1.5 system-ui,sans-serif;color:#e8efe7;background:#17201c;color-scheme:dark}*{box-sizing:border-box}body{max-width:1440px;margin:0 auto;padding:28px}h1{font-size:30px;margin:0}p{color:#b7c4b6;max-width:1050px}.status{padding:12px 16px;background:#344634;border:1px solid #5d7956;border-radius:8px}.controls{display:flex;flex-wrap:wrap;gap:12px;align-items:center;margin:20px 0;padding:14px;background:#26362b;border-radius:8px}button,select{font:inherit;padding:6px 12px;border:1px solid #687c64;background:#344c37;color:#edf5ea;border-radius:6px}button{cursor:pointer}label{display:flex;gap:8px;align-items:center}.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px}.card{border:1px solid #475f47;border-radius:10px;overflow:hidden;background:#24332a}.card h2{font-size:15px;margin:8px 12px}.large,.small{display:flex;justify-content:center;align-items:center;background:#303a38}.large{height:290px}.small{height:90px;border-top:1px solid #475448}body[data-bg=light] .large,body[data-bg=light] .small{background:#eee9db}body[data-bg=dark] .large,body[data-bg=dark] .small{background:#101416}body[data-bg=green] .large,body[data-bg=green] .small{background:#627546}canvas{display:block}.info{font-size:12px;margin:8px 12px;color:#b6c4b1}.range{flex:1;min-width:150px}input{width:100%;accent-color:#bbd89e}a{color:#c4e6a7}footer{margin-top:25px;font-size:13px}@media(max-width:950px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:580px){body{padding:14px}.large{height:220px}.controls{gap:8px}.grid{gap:8px}}
</style><h1>Dřevorubec · PixelLab v2</h1><p>Tři činnosti, společné tělesné měřítko a původní obrazová plátna. Detail používá celé zdrojové PNG; malý náhled slouží ke kontrole čitelnosti v přibližné herní velikosti.</p>
<div class="status" id="status"></div><div class="controls"><label>Činnost <select id="clip"></select></label><button id="play">Pozastavit</button><button id="prev">←</button><button id="next">→</button><label>Tempo <select id="speed"><option value="0.5">½</option><option value="1" selected>1×</option><option value="2">2×</option></select></label><label>Obraz <select id="filter"><option value="smooth">Vyhlazený</option><option value="nearest">Ostré pixely</option></select></label><label>Pozadí <select id="bg"><option value="default">Šedé</option><option value="light">Světlé</option><option value="dark">Tmavé</option><option value="green">Zelené</option></select></label><span id="frame"></span><label class="range"><input id="scrub" type="range" min="0" value="0" aria-label="Snímek"></label></div><div id="grid" class="grid"></div><footer><p id="scale"></p><p>Žádný individuální ořez, posun bot ani přizpůsobení velikosti podle sekery či klády. Tento přehrávač neprokazuje kontakt s terénem, herní integraci ani vizuální přijetí. Zdrojové PNG a atlasy mají plné RGBA; náhledy APNG nepoužívají 256barevnou paletu GIF.</p></footer>
<script id="data" type="application/json">__DATA__</script><script>
const data=JSON.parse(document.getElementById('data').textContent),$=id=>document.getElementById(id);let clipId=Object.keys(data.clips)[0],playing=true,tick=0,elapsed=0,hasDirectionFps=false,last=performance.now(),cards=[],ready=false;
$('status').textContent=data.status;$('scale').textContent=data.scale_note;
for(const [id,clip] of Object.entries(data.clips)){const option=document.createElement('option');option.value=id;option.textContent=clip.label;$('clip').append(option)}
async function build(){ready=false;cards=[];$('grid').replaceChildren();tick=0;elapsed=0;const clip=data.clips[clipId];hasDirectionFps=Object.values(clip.directions).some(d=>d.fps!==undefined);$('scrub').max=Math.max(...Object.values(clip.directions).map(d=>d.frames.length))-1;const loads=[];
for(const [name,dir] of Object.entries(clip.directions)){const card=document.createElement('article');card.className='card';const title=document.createElement('h2');title.textContent=dir.label+' · '+name;card.append(title);const canvases=[];
for(const mode of ['large','small']){const stage=document.createElement('div');stage.className=mode;const canvas=document.createElement('canvas');stage.append(canvas);card.append(stage);canvases.push({canvas,stage,mode})}const directionFps=dir.fps??clip.fps;const info=document.createElement('p');info.className='info';info.textContent=dir.frames.length+' snímků · '+directionFps+' fps · '+data.canvas.join(' × ')+' px';card.append(info);$('grid').append(card);
const images=dir.frames.map(url=>{const im=new Image();loads.push(new Promise((resolve,reject)=>{im.onload=resolve;im.onerror=reject}));im.src=url;return im});cards.push({images,canvases,fps:directionFps})}await Promise.all(loads);ready=true;last=performance.now();draw()}
function frameAtTime(seconds,fps,count){return Math.floor((seconds+1e-10)*fps)%count}
function draw(){if(!ready)return;const [w,h]=data.canvas;for(const card of cards)for(const {canvas,stage,mode} of card.canvases){const cw=stage.clientWidth,ch=stage.clientHeight,dpr=devicePixelRatio||1;canvas.width=Math.round(cw*dpr);canvas.height=Math.round(ch*dpr);canvas.style.width=cw+'px';canvas.style.height=ch+'px';const ctx=canvas.getContext('2d');ctx.scale(dpr,dpr);ctx.imageSmoothingEnabled=$('filter').value==='smooth';ctx.imageSmoothingQuality='high';const s=mode==='small'?data.world_per_source:Math.min((cw-12)/w,(ch-12)/h);const index=hasDirectionFps?frameAtTime(elapsed,card.fps,card.images.length):tick%card.images.length;ctx.drawImage(card.images[index],(cw-w*s)/2,(ch-h*s)/2,w*s,h*s)}$('frame').textContent=hasDirectionFps?'Čas '+elapsed.toFixed(2)+' s':'Snímek '+((tick%(Number($('scrub').max)+1))+1);$('scrub').value=tick%(Number($('scrub').max)+1)}
function pause(){playing=false;$('play').textContent='Přehrát'}function seekTick(value){tick=value;elapsed=tick/data.clips[clipId].fps;draw()}$('play').onclick=()=>{playing=!playing;$('play').textContent=playing?'Pozastavit':'Přehrát';last=performance.now()};$('prev').onclick=()=>{pause();seekTick(Math.max(0,tick-1))};$('next').onclick=()=>{pause();seekTick(tick+1)};$('scrub').oninput=()=>{pause();seekTick(Number($('scrub').value))};$('clip').onchange=()=>{clipId=$('clip').value;build().catch(error=>{$('status').textContent=error.message})};$('filter').onchange=draw;$('bg').onchange=()=>{document.body.dataset.bg=$('bg').value};$('speed').onchange=()=>{last=performance.now()};window.addEventListener('resize',draw);
function animate(now){if(ready&&playing){if(hasDirectionFps){elapsed+=(now-last)/1000*Number($('speed').value);last=now;tick=Math.floor((elapsed+1e-10)*data.clips[clipId].fps);draw()}else{const delay=1000/(data.clips[clipId].fps*Number($('speed').value));if(now-last>=delay){const n=Math.floor((now-last)/delay);tick+=n;last+=n*delay;draw()}}}requestAnimationFrame(animate)}build().catch(error=>{$('status').textContent='Náhled nelze načíst: '+error.message});requestAnimationFrame(animate);
</script></html>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--clips", nargs="+", choices=CLIPS, default=list(CLIPS))
    parser.add_argument("--directions", nargs="+", choices=DIRECTIONS, default=list(DIRECTIONS))
    parser.add_argument("--anchor", type=float, nargs=2, required=True, metavar=("X", "Y"))
    parser.add_argument("--body-height", type=positive, required=True, help="Explicit human height in source pixels, excluding equipment.")
    parser.add_argument("--world-height", type=positive, default=33)
    parser.add_argument("--fps", type=positive, default=12)
    parser.add_argument("--clip-fps", action="append", default=[], metavar="CLIP=FPS")
    parser.add_argument("--direction-fps", action="append", default=[], metavar="CLIP/DIR=FPS",
                        help="Explicit direction playback tempo; source frames and ordering remain unchanged.")
    parser.add_argument("--rest-frame", type=int, default=0, help="Explicit stationary presentation frame in the packaged sequence.")
    parser.add_argument("--clip-rest-frame", action="append", default=[], metavar="CLIP=INDEX")
    parser.add_argument("--expected-frames", type=int, default=24,
                        help="Expected raw count; 0 reads each job's provenance output_contract.expected_frames. Never truncates frames.")
    parser.add_argument("--drop-identical-loop-end", action="store_true", help="Omit final frame from package only if RGBA-identical to first; retain source and evidence.")
    parser.add_argument("--selection", type=Path, help="Root-authorized JSON {clip:{direction:[source indices]}}; no inferred curation.")
    parser.add_argument("--review-note", default="Vizuální kontrola a ověření ve hře zatím nejsou potvrzené.")
    args = parser.parse_args()
    if not all(math.isfinite(v) for v in args.anchor) or args.expected_frames < 0:
        parser.error("Anchor must be finite and expected frame count nonnegative (0 uses job provenance).")
    root = args.root.resolve()
    fps = {clip: args.fps for clip in args.clips}
    rest_frames = {clip: args.rest_frame for clip in args.clips}
    for option in args.clip_fps:
        key, value = option.split("=", 1)
        if key not in CLIPS:
            parser.error(f"Unknown clip: {key}")
        fps[key] = positive(value)
    direction_fps = {}
    for option in args.direction_fps:
        try:
            key, value = option.split("=", 1)
            clip_id, direction = key.split("/", 1)
        except ValueError:
            parser.error("--direction-fps requires CLIP/DIR=FPS.")
        if clip_id not in args.clips or direction not in args.directions:
            parser.error(f"Direction FPS target is not included in this package: {key}")
        direction_fps[(clip_id, direction)] = positive(value)
    for option in args.clip_rest_frame:
        key, value = option.split("=", 1)
        if key not in CLIPS:
            parser.error(f"Unknown clip: {key}")
        rest_frames[key] = int(value)
    selection = json.loads(args.selection.read_text()) if args.selection else {}
    directions = [d for d in DIRECTIONS if d in args.directions]
    pack = root / "package"
    preview = root / "preview"
    for directory in (pack / "atlases", pack / "frames", preview):
        directory.mkdir(parents=True, exist_ok=True)
    warnings, all_source_hashes, clips, qa_clips, canvas = [], {}, {}, {}, None
    preview_clips = {}
    for clip in args.clips:
        records, images_by_dir, clip_qa, preview_dirs = {}, {}, {}, {}
        clip_preview = preview / clip
        clip_preview.mkdir(exist_ok=True)
        for direction in directions:
            effective_fps = direction_fps.get((clip, direction), fps[clip])
            explicit_direction_fps = (clip, direction) in direction_fps
            folder = root / "jobs" / clip / direction / "images"
            paths = sorted(folder.glob("frame_*.png"))
            if not paths or [p.name for p in paths] != [f"frame_{i:02d}.png" for i in range(len(paths))]:
                raise SystemExit(f"Missing or nonconsecutive returned frames: {folder}")
            expected_frames = args.expected_frames or None
            expected_authority = "explicit packer --expected-frames"
            if args.expected_frames == 0:
                provenance_path = folder.parent / "provenance.json"
                expected_authority = str(provenance_path.relative_to(root)) + ":output_contract.expected_frames"
                try:
                    provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
                    contract = provenance.get("output_contract") if isinstance(provenance, dict) else None
                    declared = contract.get("expected_frames") if isinstance(contract, dict) else None
                    if type(declared) is int and declared > 0:
                        expected_frames = declared
                    else:
                        warnings.append(f"{clip}/{direction}: provenance lacks a valid positive integer output_contract.expected_frames; raw count {len(paths)} cannot be verified against a declared expectation. No expected count was inferred.")
                except (OSError, ValueError) as error:
                    warnings.append(f"{clip}/{direction}: cannot read provenance output_contract.expected_frames ({type(error).__name__}); raw count {len(paths)} cannot be verified against a declared expectation. No expected count was inferred.")
            images, measured = [], []
            for path in paths:
                image, info, _ = measure(path, root)
                if canvas is None:
                    canvas = image.size
                if image.size != canvas:
                    raise SystemExit(f"Canvas mismatch {path}: {image.size} versus {canvas}; do not silently normalize.")
                all_source_hashes[path] = info["sha256"]
                if not info["has_visible_content_and_transparency"]:
                    raise SystemExit(f"Missing real transparent background or visible content: {path}")
                if info["nonzero_alpha_border_pixels"]:
                    warnings.append(f"{clip}/{direction}/{path.name}: nonzero alpha reaches canvas edge; inspect clipping.")
                images.append(image); measured.append(info)
            indices = selection.get(clip, {}).get(direction, list(range(len(images))))
            if not isinstance(indices, list) or not indices or any(type(i) is not int or i < 0 or i >= len(images) for i in indices):
                raise SystemExit(f"Invalid explicit selection for {clip}/{direction}")
            excluded = sorted(set(range(len(images))) - set(indices))
            endpoint_removed = False
            if args.drop_identical_loop_end and len(indices) > 1 and images[indices[0]].tobytes() == images[indices[-1]].tobytes():
                excluded.append(indices[-1]); indices = indices[:-1]; endpoint_removed = True
            if expected_frames is not None and len(paths) != expected_frames:
                warnings.append(f"{clip}/{direction}: API returned {len(paths)}, requested expectation {expected_frames}; kept explicit sequence of {len(indices)}.")
            output_frames = []
            frame_dir = pack / "frames" / clip / direction
            frame_dir.mkdir(parents=True, exist_ok=True)
            for i, index in enumerate(indices):
                destination = frame_dir / f"{i:02d}.png"
                shutil.copyfile(paths[index], destination)
                if sha256(destination.read_bytes()) != measured[index]["sha256"]:
                    raise SystemExit(f"Copied PNG hash mismatch: {destination}")
                output_frames.append({"index": i, "file": str(destination.relative_to(pack)),
                                      "source_index": index, "source_file": str(paths[index].relative_to(root)),
                                      "png_sha256": measured[index]["sha256"], "rgba_sha256": measured[index]["rgba_sha256"],
                                      "duration_seconds": 1 / effective_fps})
            selected_images = [images[i] for i in indices]
            images_by_dir[direction] = selected_images
            records[direction] = {"frame_count": len(indices), "frames": output_frames}
            if explicit_direction_fps:
                records[direction]["fps"] = effective_fps
            animation = apng(selected_images, clip_preview / f"{direction}.apng.png", effective_fps,
                             exact_timing=explicit_direction_fps)
            animation["file"] = str(Path(animation["file"]).relative_to(root))
            apng_path = Path(animation["file"])
            preview_dirs[direction] = {"label": LABELS[direction], "frames": ["../package/"+f["file"] for f in output_frames],
                                       "apng": str(apng_path.relative_to("preview"))}
            if explicit_direction_fps:
                preview_dirs[direction]["fps"] = effective_fps
            clip_qa[direction] = {"returned_frame_count": len(paths), "expected_raw_frame_count": expected_frames,
                                  "expected_raw_frame_count_authority": expected_authority,
                                  "raw_frame_count_verification": "not_verified" if expected_frames is None else "matched" if len(paths) == expected_frames else "mismatch",
                                  "selected_source_indices": indices,
                                  "excluded_source_indices": excluded, "identical_terminal_frame_removed": endpoint_removed,
                                  "selection_authority": str(args.selection) if args.selection else "all returned frames; optional exact-RGBA endpoint rule only",
                                  "frames": measured, "review_apng": animation,
                                  "duplicate_rgba_pairs": [[i, j] for i in range(len(images)) for j in range(i+1, len(images)) if measured[i]["rgba_sha256"] == measured[j]["rgba_sha256"]],
                                  "adjacent_mean_rgba_delta_including_wrap": [delta(selected_images[i], selected_images[(i+1)%len(selected_images)]) for i in range(len(selected_images))]}
        width, height = canvas
        if not (0 <= args.anchor[0] <= width and 0 <= args.anchor[1] <= height):
            raise SystemExit(f"Anchor {args.anchor} outside {canvas}")
        max_frames = max(len(v) for v in images_by_dir.values())
        if any(not (0 <= rest_frames[clip] < len(v)) for v in images_by_dir.values()):
            raise SystemExit(f"Invalid rest_frame {rest_frames[clip]} for clip {clip}")
        atlas = Image.new("RGBA", (max_frames * width, len(directions) * height))
        for row, direction in enumerate(directions):
            for i, image in enumerate(images_by_dir[direction]):
                atlas.paste(image, (i * width, row * height))
                records[direction]["frames"][i]["atlas_rect_px"] = [i * width, row * height, width, height]
        atlas_path = pack / "atlases" / f"{clip}.png"
        atlas.save(atlas_path)
        with Image.open(atlas_path) as check:
            for direction, record in records.items():
                for frame in record["frames"]:
                    x, y, w, h = frame["atlas_rect_px"]
                    if sha256(check.crop((x, y, x+w, y+h)).tobytes()) != frame["rgba_sha256"]:
                        raise SystemExit(f"Atlas RGBA mismatch: {clip}/{direction}/{frame['index']}")
        clips[clip] = {"label": CLIPS[clip], "playback": "loop", "fps": fps[clip], "fps_authority": "explicit packer configuration; simulation timing not yet validated",
                       "rest_frame": rest_frames[clip],
                       "renders_cargo": "log" if clip == "walk_log" else None,
                       "tool_grip": "two_handed" if clip == "chop" else "right_hand" if clip == "walk_axe" else "axe_holstered_left_side",
                       "atlas": str(atlas_path.relative_to(pack)), "atlas_size_px": list(atlas.size),
                       "atlas_sha256": sha256(atlas_path.read_bytes()), "directions": records}
        qa_clips[clip] = clip_qa
        preview_clips[clip] = {"label": CLIPS[clip], "fps": fps[clip], "directions": preview_dirs}
    complete = set(args.clips) == set(CLIPS) and directions == list(DIRECTIONS)
    now = datetime.now(timezone.utc).isoformat()
    source_unchanged = all(sha256(path.read_bytes()) == digest for path, digest in all_source_hashes.items())
    if not source_unchanged:
        raise SystemExit("Source changed during packaging.")
    manifest = {"schema_version": 1, "asset_id": "lumberjack-pixellab-production-v2", "role": "lumberjack", "created_at": now,
                "scope_complete_3_clips_8_directions": complete, "visual_acceptance": "not established by packaging", "runtime_reader": "not implemented by this tool",
                "source_canvas_px": list(canvas), "anchor_source_px": args.anchor, "body_height_source_px": args.body_height,
                "body_height_world_px": args.world_height, "world_px_per_source_px": args.world_height / args.body_height,
                "registration": {"trim": "none", "frame_offsets": "none", "basis": "explicit common anchor and body height; equipment bounds do not affect scale",
                                 "placement_formula": "screen_top_left = projected_physical_foot - anchor_source_px * world_px_per_source_px"},
                "direction_order": directions, "direction_vectors_screen_y_down": {d: VECTORS[d] for d in directions},
                "clips": clips, "review_note": args.review_note}
    write_json(pack / "manifest.json", manifest)
    qa = {"created_at": now, "source_files_unchanged": True, "copied_pngs_exact_bytes": True, "atlas_cells_exact_rgba": True,
          "apng_decoded_source_regions_exact_rgba": True, "scope_complete_3_clips_8_directions": complete,
          "warnings": warnings, "clips": qa_clips, "visual_review_note": args.review_note,
          "not_verified": ["identity and anatomy", "tool/log stability", "gait and loop closure", "physical foot anchor", "simulation timing", "normal game path", "user acceptance"]}
    write_json(root / "pack-validation.json", qa)
    payload = {"canvas": list(canvas), "world_per_source": args.world_height / args.body_height, "clips": preview_clips,
               "status": ("Všechny tři klipy a osm směrů jsou zabalené. " if complete else "Dílčí pilot: zatím není dodána celá sada tří klipů v osmi směrech. ") + args.review_note,
               "scale_note": f"Společné měřítko: {args.body_height:g} zdrojových px těla → {args.world_height:g} world px. Výslovně zadaná kotva {args.anchor}; žádná automatická registrace podle klády či bot."}
    (preview / "index.html").write_text(HTML.replace("__DATA__", json.dumps(payload, ensure_ascii=False).replace("</", "<\\/")), encoding="utf-8")
    print(json.dumps({"package": str(pack), "preview": str(preview / "index.html"), "complete_scope": complete,
                      "source_count": len(all_source_hashes), "selected_count": sum(d["frame_count"] for c in clips.values() for d in c["directions"].values()),
                      "warnings": warnings}, ensure_ascii=False))


if __name__ == "__main__":
    main()
