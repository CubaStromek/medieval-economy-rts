#!/usr/bin/env python3
"""Measure one completed PixelLab job and make a native-size contact sheet.

Usage: python3 tools/review_pixellab_job.py JOB_DIR [--labels S SW W NW N NE E SE]
Reads JOB_DIR/images/frame_XX.png. Writes only JOB_DIR/qa/contact.png and
statistics.json. Original pixels, filenames, frame order and anchors stay intact.
Requires Pillow; reuses the existing preview's alpha/hash measurements.
"""

import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat

from preview_pixellab_walk import checker, measure, sha256


def adjacent_difference(first, second, from_index, to_index):
    result = {"from_index": from_index, "to_index": to_index}
    if first.size != second.size:
        return {**result, "comparable": False, "reason": "different canvas dimensions"}
    raw = ImageChops.difference(first.convert("RGB"), second.convert("RGB"))
    backdrop = Image.new("RGBA", first.size, (80, 85, 80, 255))
    first_visible = Image.alpha_composite(backdrop, first).convert("RGB")
    second_visible = Image.alpha_composite(backdrop, second).convert("RGB")
    visible = ImageChops.difference(first_visible, second_visible)
    alpha = ImageChops.difference(first.getchannel("A"), second.getchannel("A"))
    rgb_mean = ImageStat.Stat(raw).mean
    visible_mean = ImageStat.Stat(visible).mean
    channels = visible.split()
    maximum_channel = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])
    changed = first.width * first.height - maximum_channel.histogram()[0]
    return {**result, "comparable": True, "raw_rgb_mean_absolute_difference": round(sum(rgb_mean) / 3, 6),
            "composited_rgb_mean_absolute_difference": round(sum(visible_mean) / 3, 6),
            "alpha_mean_absolute_difference": round(ImageStat.Stat(alpha).mean[0], 6),
            "changed_composited_pixels": changed,
            "changed_composited_fraction": round(changed / (first.width * first.height), 6)}


def review(job_dir, labels=None, columns=4):
    job_dir = Path(job_dir).resolve()
    paths = sorted((job_dir / "images").glob("frame_*.png"))
    if not paths:
        raise ValueError(f"No downloaded job images in {job_dir / 'images'}")
    if columns < 1:
        raise ValueError("Column count must be positive.")
    if labels is not None and len(labels) != len(paths):
        raise ValueError(f"Provide exactly {len(paths)} labels or omit --labels.")
    expected_names = [f"frame_{i:02d}.png" for i in range(len(paths))]
    if [p.name for p in paths] != expected_names:
        raise ValueError("Expected consecutive frame_00.png, frame_01.png, ...; inspect job download.")
    images, measurements, warnings = [], [], []
    for index, path in enumerate(paths):
        image, info, _ = measure(path, job_dir)
        info.update(index=index, label=labels[index] if labels else path.stem)
        images.append(image)
        measurements.append(info)
        if not info["has_visible_content_and_transparency"]:
            warnings.append(f"{path.name}: missing visible content or fully transparent pixels.")
        if info["nonzero_alpha_border_pixels"]:
            warnings.append(f"{path.name}: nonzero alpha touches canvas edge; inspect clipping.")
    cell_width = max(frame.width for frame in images)
    image_height = max(frame.height for frame in images)
    label_height = 28
    columns = min(columns, len(images))
    rows = math.ceil(len(images) / columns)
    sheet = checker((columns * cell_width, rows * (image_height + label_height)))
    draw = ImageDraw.Draw(sheet)
    for index, image in enumerate(images):
        x = index % columns * cell_width
        y = index // columns * (image_height + label_height)
        draw.rectangle((x, y, x + cell_width - 1, y + label_height - 1), fill=(22, 29, 31, 255))
        draw.text((x + 8, y + 8), f"{index:02d}  {measurements[index]['label']}", fill=(240, 240, 235, 255))
        # Fixed top-left source-canvas registration, with no content-dependent trim.
        sheet.alpha_composite(image, (x, y + label_height))
    duplicates = [[i, j] for i in range(len(images)) for j in range(i + 1, len(images))
                  if measurements[i]["rgba_sha256"] == measurements[j]["rgba_sha256"]]
    output = job_dir / "qa"
    output.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output / "contact.png")
    stats = {"created_at": datetime.now(timezone.utc).isoformat(), "job_directory": str(job_dir),
             "frame_count": len(images), "contact_dimensions": list(sheet.size), "columns": columns,
             "native_pixel_scale": 1, "bbox_convention": "left/top inclusive, right/bottom exclusive",
             "frames": measurements, "identical_rgba_pairs": duplicates,
             "adjacent_differences": [adjacent_difference(images[i - 1], images[i], i - 1, i)
                                      for i in range(1, len(images))],
             "last_to_first_difference": adjacent_difference(images[-1], images[0], len(images) - 1, 0),
             "difference_units": "mean absolute channel difference in 0–255; RGB composite uses opaque #505550",
             "warnings": warnings,
             "not_verified": ["identity consistency", "tool grip", "motion and loop quality", "ground contact",
                              "game integration", "user acceptance"]}
    unchanged = all(sha256(path.read_bytes()) == info["sha256"] for path, info in zip(paths, measurements))
    stats["source_files_unchanged_after_review"] = unchanged
    (output / "statistics.json").write_text(json.dumps(stats, indent=2, ensure_ascii=False) + "\n")
    if not unchanged:
        raise ValueError("Source hashes changed during review; rerun after the job has finished writing.")
    return {"contact": str(output / "contact.png"), "statistics": str(output / "statistics.json"),
            "frame_count": len(images), "warnings": warnings, "identical_rgba_pairs": duplicates}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("job_dir", type=Path)
    parser.add_argument("--labels", nargs="+")
    parser.add_argument("--columns", type=int, default=4)
    args = parser.parse_args()
    print(json.dumps(review(args.job_dir, args.labels, args.columns), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
