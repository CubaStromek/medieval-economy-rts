"""Mechanical static registration of the visually selected chop rotations.

This is a curated selection, not an automatic direction classifier.
The previously animated S reference is read only. E uses a separate repair.
"""
from pathlib import Path
from datetime import datetime, timezone
import colorsys
import hashlib
import json
import math
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).resolve().parent
OUT = ROOT / "registered-inputs" / "chop"
SELECTION = {
    # index, manually inspected horizontal cap ROI (right exclusive).
    # These ROIs exclude the orange axe handle next to the cap in 01–03.
    "SE": (None, 90, 165),
    "NE": (2, 120, 158),
    "N": (3, 114, 152),
    "NW": (4, 104, 145),
    "W": (5, 99, 143),
    "SW": (6, 98, 140),
    "E": (None, 90, 160),
}
PROTECTED_S_SHA = "6a3e84d8a534e618c5f4c73db9dc2b97daa39a7d6f44b9dce1e47a6a9718e497"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert sha(OUT / "S.png") == PROTECTED_S_SHA, "Existing S changed; review before registration"
records = []
images = {"S": Image.open(OUT / "S.png").convert("RGBA")}
for direction, (index, left, right) in SELECTION.items():
    source = (ROOT / "edits" / f"chop-{direction}-pro" / "images" / "frame_00.png" if index is None
              else ROOT / "rotations-chop" / "images" / f"frame_{index:02d}.png")
    source_sha = sha(source)
    im = Image.open(source).convert("RGBA")
    assert im.size == (256, 256)
    source_box = im.getchannel("A").getbbox()
    # Visually verified for these selected sources: cap silhouette is above tool.
    top = source_box[1]
    points = []
    for y in range(top, top + 21):
        for x in range(left, right):
            r, g, b, a = im.getpixel((x, y))
            hue, sat, value = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if a >= 32 and .025 <= hue <= .11 and sat >= .35 and value >= .15:
                points.append((x, y))
    cap_box = [min(x for x, y in points), min(y for x, y in points),
               max(x for x, y in points) + 1, max(y for x, y in points) + 1]
    center = (cap_box[0] + cap_box[2] - 1) / 2
    dx, dy = 128 - math.floor(center + .5), 52 - top
    registered = Image.new("RGBA", im.size)
    registered.paste(im, (dx, dy))
    output_box = registered.getchannel("A").getbbox()
    assert output_box == (source_box[0] + dx, source_box[1] + dy,
                          source_box[2] + dx, source_box[3] + dy)
    count = 0
    for y in range(256):
        for x in range(256):
            pixel = im.getpixel((x, y))
            if pixel[3]:
                count += 1
                assert 0 <= x + dx < 256 and 0 <= y + dy < 256
                assert registered.getpixel((x + dx, y + dy)) == pixel
    assert count == sum(p[3] > 0 for p in registered.get_flattened_data())
    dest = OUT / f"{direction}.png"
    if dest.exists():
        if Image.open(dest).convert("RGBA").tobytes() != registered.tobytes():
            assert direction == "SE" and sha(dest) == sha(QA / "history" / "chop-SE-rotation-01-registered.png"), "Different existing output; do not overwrite"
            # Root explicitly selected this replacement; previous registered pixels archived.
            registered.save(dest)
    else:
        registered.save(dest)
    assert Image.open(dest).convert("RGBA").tobytes() == registered.tobytes()
    assert source_sha == sha(source)
    images[direction] = registered
    records.append({
        "direction": direction, "source_index": index,
        "selection_status": "visually selected repair pilot" if index is None else "visually selected pilot",
        "source": str(source.relative_to(ROOT)), "source_sha256": source_sha,
        "output": str(dest.relative_to(ROOT)), "output_sha256": sha(dest),
        "canvas_px": [256, 256], "source_cap_silhouette_top_y": top,
        "cap_measurement_roi_exclusive": [left, top, right, top + 21],
        "orange_cap_bounds_exclusive": cap_box, "source_cap_center_x": center,
        "translation_source_px": [dx, dy], "registered_cap_top_y": 52,
        "registered_cap_center_x": center + dx, "registered_raster_center_x": 128,
        "source_alpha_bbox_exclusive": source_box, "output_alpha_bbox_exclusive": output_box,
        "visible_pixel_count": count, "visible_pixels_clipped": 0,
        "all_visible_source_rgba_pixels_preserved_at_exact_integer_translation": True,
        "source_unchanged": True, "resampling": "none",
    })
assert sha(OUT / "S.png") == PROTECTED_S_SHA

sheet = Image.new("RGB", (4 * 256, 2 * 288), (43, 53, 50))
draw = ImageDraw.Draw(sheet)
for i, direction in enumerate(("S", "SE", "E", "NE", "N", "NW", "W", "SW")):
    x, y = i % 4 * 256, i // 4 * 288
    label = direction + (" (existing S unchanged)" if direction == "S" else "")
    if direction in ("SE", "E"):
        label += " (separate Pro repair)"
    draw.text((x + 7, y + 7), label, fill="white")
    if direction in images:
        sheet.paste(images[direction], (x, y + 32), images[direction])
    else:
        draw.text((x + 24, y + 136), "MISSING - not synthesized", fill=(255, 190, 110))
sheet.save(QA / "registered-chop-contact.png")

report = {
    "created_at": datetime.now(timezone.utc).isoformat(),
    "job_id": "bba125f7-2220-472a-983d-f04203305500",
    "raw_direction_labels_in_response": False,
    "raw_visual_mapping": {"00": "S; not selected because existing S is protected",
                           "01": "SE, tending toward E", "02": "NE", "03": "N",
                           "04": "NW", "05": "W", "06": "SW",
                           "07": "near S / S-SW; unselected, not E"},
    "missing_direction_in_raw_rotations": "E",
    "E_repair_source": "edits/chop-E-pro/images/frame_00.png",
    "SE_repair_source": "edits/chop-SE-pro/images/frame_00.png",
    "superseded_SE_registered_pixels": "rotations-chop/qa/history/chop-SE-rotation-01-registered.png",
    "superseded_selection_provenance": "rotations-chop/qa/history/direction-registration-before-SE-repair.json",
    "raw_rotations_complete_eight_direction_set": False,
    "registered_all_eight_directions_present": True,
    "production_accepted": False,
    "existing_S_preserved_sha256": PROTECTED_S_SHA,
    "landmark_method": "Visually inspected cap is highest silhouette in selected sources. Cap top from actual alpha; center from orange HSV mask in top21px and manually inspected cap-only X ROI to exclude orange axe handle. H .025..11, S>=.35, V>=.15, alpha>=32. Raster center floor(center+.5). Approximate color landmark, not anatomical precision.",
    "physical_ground_anchor": "not inferred; cap registration only",
    "records": records,
}
(QA / "direction-registration.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"registered": {r["direction"]: r["translation_source_px"] for r in records},
                  "S_unchanged": True, "missing": [], "visible_pixels_clipped": 0}))
