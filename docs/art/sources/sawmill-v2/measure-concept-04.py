"""Read-only source-image geometry QA; outputs annotated copies and JSON, no alpha export."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
SRC = ROOT / "docs/art/sources/sawmill-v2/concept-04-key.png"
QA = ROOT / "docs/art/qa/sawmill-v2"
RAW_SCALE = 0.1195
THRESHOLD = (400, 1032)
BOUNDS = (-60 / RAW_SCALE + 400, -80 / RAW_SCALE + 1032,
          100 / RAW_SCALE + 400, 1032)
DOOR = [(316, 646), (438, 619), (438, 913), (316, 942)]
CONTACTS = {
    "left masonry": (35, 841),
    "south masonry": (259, 1029),
    "east masonry": (1228, 800),
    "middle post": (735, 937),
    "entry step": (391, 1007),
    "log cradle": (522, 909),
    "bench left foot": (830, 875),
    "bench right foot": (981, 832),
    "board rack foot": (1108, 808),
}

im = Image.open(SRC).convert("RGB")
pix = im.load()
extents = {}
for cutoff in (20, 60, 100):
    pts = [(x, y) for y in range(740, im.height) for x in range(im.width)
           if min(pix[x, y][0], pix[x, y][2]) - pix[x, y][1] < cutoff]
    xs, ys = zip(*pts)
    extents[str(cutoff)] = {"inclusive_bbox": [min(xs), min(ys), max(xs), max(ys)],
                            "pixel_count": len(pts)}
box = extents["100"]["inclusive_bbox"]
report = {
    "date": "2026-09-12",
    "source": str(SRC.relative_to(ROOT)),
    "source_sha256": hashlib.sha256(SRC.read_bytes()).hexdigest(),
    "canvas": list(im.size),
    "status": "Source geometry only; final alpha and native game contacts not yet verified",
    "raw_source_to_world": RAW_SCALE,
    "uniform_export_canvas": [800, 800],
    "source_to_world_for_800_canvas": RAW_SCALE * 1254 / 800,
    "navigation_threshold_raw": list(THRESHOLD),
    "occupied_world_size": [160, 80],
    "occupied_raw_bounds": list(BOUNDS),
    "external_approach_raw_bounds": [400 - 20 / RAW_SCALE, 1032,
                                      400 + 20 / RAW_SCALE, 1032 + 40 / RAW_SCALE],
    "manual_visible_ground_contacts": CONTACTS,
    "manual_contact_uncertainty_raw_px": 5,
    "manual_contacts_inside": all(BOUNDS[0] <= x <= BOUNDS[2] and BOUNDS[1] <= y <= BOUNDS[3]
                                  for x, y in CONTACTS.values()),
    "lower_image_non_key_extents": extents,
    "extent_method": "Rows y>=740, classify min(R,B)-G below20/60/100. Diagnostic only; no final alpha created. Bbox maxima are inclusive pixel indices.",
    "lower_image_south_margin_world_using_pixel_lower_edge": (1032 - box[3] - 1) * RAW_SCALE,
    "lower_image_east_margin_world_using_pixel_right_edge": (BOUNDS[2] - box[2] - 1) * RAW_SCALE,
    "door_clear_opening_manual_quad": DOOR,
    "door_height_raw": [DOOR[3][1] - DOOR[0][1], DOOR[2][1] - DOOR[1][1]],
    "door_height_world": [(DOOR[3][1] - DOOR[0][1]) * RAW_SCALE,
                           (DOOR[2][1] - DOOR[1][1]) * RAW_SCALE],
    "door_clear_width_world": (DOOR[1][0] - DOOR[0][0]) * RAW_SCALE,
    "door_measurement_uncertainty_raw_px": 5,
    "human_body_height_world": 33,
    "door_target_note": "Actual measured clear field has adult height and width. Native walking/open-door clearance remains to be verified.",
    "navigation_note": "Nav is25rawpx (~2.99world) south of the manually observed central lower step edge; final actual entry may need a small registration adjustment. Navigation is not registered at the painted door leaf.",
    "limitations": ["Only visible ground contacts are measured; obscured rear contact is bounded conservatively by the house.",
                    "This does not establish roof contact, slope support, final alpha fringe or animation registration.",
                    "The south margin is less than a world pixel; test actual raised platform before deriving dynamic artwork."]
}
QA.mkdir(parents=True, exist_ok=True)
(QA / "concept-04-geometry.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")

# Technical annotation of an existing image, never a painted/generated building.
canvas = Image.new("RGB", (1490, 1400), "#162329")
offset = (160, 80)
canvas.paste(im, offset)
d = ImageDraw.Draw(canvas)
font_path = "/System/Library/Fonts/Supplemental/Arial.ttf"
font = ImageFont.truetype(font_path, 18)
small = ImageFont.truetype(font_path, 15)
def xy(p):
    return (p[0] + offset[0], p[1] + offset[1])
d.text((20, 20), "SAWMILL V2 / CONCEPT04 — measured source contacts, raw scale0.1195", fill="white", font=font)
d.rectangle((xy(BOUNDS[:2]), xy(BOUNDS[2:])), outline="#4ad8ff", width=3)
for x in (400 - 20 / RAW_SCALE, 400 + 20 / RAW_SCALE, 400 + 60 / RAW_SCALE):
    d.line((xy((x, BOUNDS[1])), xy((x, 1032))), fill="#377a91", width=1)
d.line((xy((BOUNDS[0], BOUNDS[1] + 40 / RAW_SCALE)), xy((BOUNDS[2], BOUNDS[1] + 40 / RAW_SCALE))), fill="#377a91", width=1)
d.line([xy(p) for p in DOOR + DOOR[:1]], fill="#84ff8d", width=3)
for label, p in CONTACTS.items():
    a, b = xy(p)
    d.ellipse((a-4, b-4, a+4, b+4), fill="#fff170", outline="#302514", width=1)
    if label in ("left masonry", "south masonry", "east masonry"):
        dx = -140 if label == "east masonry" else 10
        d.text((a+dx, b+8), f"{label} {p}", fill="#fff170", font=small)
a,b=xy(THRESHOLD)
d.line((a-12,b,a+12,b),fill="white",width=3)
d.line((a,b-12,a,b+12),fill="white",width=3)
d.text((a+16,b+10), "nav (400,1032)", fill="white", font=font)
d.text((20, 1308), "Blue: unchanged4×2 ground boundary; roof/height may project above it. Green: measured door clear field.", fill="white", font=font)
d.text((20, 1338), "Visible feet fit. Native raised-platform/entry QA verifies the narrow south and east margins.", fill="white", font=font)
d.text((20, 1368), "Technical annotation only. Magenta source is not a production alpha export; no worker or stock anchor is accepted here.", fill="white", font=small)
canvas.save(QA / "concept-04-contact-guide.png")
print(json.dumps({"source_sha256": report["source_sha256"], "lower_extent": box,
                  "door_world": report["door_height_world"],
                  "south_margin_world": report["lower_image_south_margin_world_using_pixel_lower_edge"],
                  "east_margin_world": report["lower_image_east_margin_world_using_pixel_right_edge"]}, indent=2))
