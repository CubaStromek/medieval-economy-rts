#!/usr/bin/env python3
"""Lossless APNG excerpt from actual native game captures and recorded timing."""
import argparse
import hashlib
import json
from pathlib import Path
from statistics import median

from PIL import Image


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--crop", type=int, nargs=4, metavar=("X", "Y", "W", "H"))
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    records = report.get("chop_burst", [])
    if len(records) < 2:
        parser.error("Need at least two actually captured frames.")
    times = [record["simulation_seconds"] for record in records]
    intervals = [b - a for a, b in zip(times, times[1:])]
    if not all(value > 0 for value in intervals):
        parser.error("Actual simulation timestamps must increase; no synthetic frames are added.")
    durations = [value * 1000 for value in intervals + [median(intervals)]]
    frames = []
    crop_box = None
    if args.crop:
        x, y, w, h = args.crop
        crop_box = (x, y, x + w, y + h)
    for record in records:
        source = args.report.parent / record["file"]
        if digest(source) != record["sha256"]:
            parser.error("Source PNG no longer matches native capture: " + str(source))
        with Image.open(source) as image:
            frame = image.convert("RGBA")
            if crop_box:
                if not (0 <= crop_box[0] < crop_box[2] <= frame.width and
                        0 <= crop_box[1] < crop_box[3] <= frame.height):
                    parser.error("Crop must remain inside every source canvas.")
                frame = frame.crop(crop_box)
            frames.append(frame)
    if len({frame.size for frame in frames}) != 1:
        parser.error("Source dimensions must be consistent.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(args.output, format="PNG", save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, disposal=0, blend=0)
    # APNG can coalesce identical adjacent frames; compare decoded presentation
    # against actual crop pixels and retain an explicit decoded frame count.
    expected_sequence = []
    for frame in frames:
        pixels = hashlib.sha256(frame.tobytes()).hexdigest()
        if not expected_sequence or expected_sequence[-1] != pixels:
            expected_sequence.append(pixels)
    with Image.open(args.output) as decoded:
        decoded_count = decoded.n_frames
        assert decoded_count == len(expected_sequence)
        decoded_duration = 0.0
        for index in range(decoded_count):
            decoded.seek(index)
            assert hashlib.sha256(decoded.convert("RGBA").tobytes()).hexdigest() == expected_sequence[index]
            decoded_duration += decoded.info["duration"]
        assert abs(decoded_duration - sum(durations)) < 1.0
    summary = {
        "source_report": str(args.report.resolve()), "source_report_sha256": digest(args.report),
        "source_frames": len(frames), "decoded_apng_frames": decoded_count,
        "output": str(args.output.resolve()), "sha256": digest(args.output),
        "size": list(frames[0].size), "crop_xywh": args.crop,
        "simulation_time_start": times[0], "simulation_time_end": times[-1],
        "preview_duration_seconds": decoded_duration / 1000,
        "timing": "Consecutive observed simulation timestamp differences; final frame uses median observed interval.",
        "interpretation": "Repeated native gameplay excerpt, not a newly authored animation loop.",
        "pixel_policy": "Lossless region extraction only, no resampling, recoloring, new pixels or source writes.",
    }
    args.output.with_suffix(".json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
