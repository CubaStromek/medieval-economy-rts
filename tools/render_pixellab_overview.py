#!/usr/bin/env python3
"""Render a timed 3 × 8 presentation excerpt from an existing PixelLab package.

Read only with respect to the package: no edits, frame alignment or generation.
The preview downsamples each complete source canvas to 128 × 128 pixels.
"""
import argparse
from datetime import datetime, timezone
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import struct
import zlib

from PIL import Image, ImageDraw, ImageFont

DIRECTIONS = ("N", "NE", "E", "SE", "S", "SW", "W", "NW")
DIRECTION_LABELS = ("Sever", "Severovýchod", "Východ", "Jihovýchod",
                    "Jih", "Jihozápad", "Západ", "Severozápad")
CLIPS = ("walk_axe", "chop", "walk_log")
CLIP_LABELS = {"walk_axe": "Chůze se\nsekerou", "chop": "Sekání\nobouruč",
               "walk_log": "Chůze s\nkládou"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def font(size, bold=False):
    candidates = (["/System/Library/Fonts/Supplemental/Arial Bold.ttf"] if bold else
                  ["/System/Library/Fonts/Supplemental/Arial.ttf"])
    candidates += ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
    for path in candidates:
        if Path(path).is_file():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)


def positive(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("Expected a finite positive number")
    return number


def frame_at_time(seconds, fps, count):
    # Integer arithmetic for sampling; each direction keeps its own FPS.
    return int(seconds * Fraction(str(fps))) % count


def exact_apng_delay(path, fps):
    """Pillow rounds milliseconds; write exact rational delay and valid CRCs."""
    delay = (1 / Fraction(str(fps))).limit_denominator(65535)
    if delay.numerator > 65535 or abs(float(delay) - 1 / fps) > 1e-9:
        raise ValueError("Preview FPS is not representable by APNG frame timing")
    data = path.read_bytes()
    output = bytearray(data[:8])
    position, frames = 8, 0
    while position < len(data):
        size = struct.unpack_from(">I", data, position)[0]
        kind = data[position + 4:position + 8]
        payload = bytearray(data[position + 8:position + 8 + size])
        if kind == b"fcTL":
            payload[20:24] = struct.pack(">HH", delay.numerator, delay.denominator)
            frames += 1
        output += struct.pack(">I", len(payload)) + kind + payload
        output += struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff)
        position += size + 12
    path.write_bytes(output)
    return frames, [delay.numerator, delay.denominator]


def export(manifest_path, output_dir, duration=4.0, preview_fps=30.0, start_seconds=0.0):
    manifest_path = manifest_path.resolve()
    package = manifest_path.parent
    manifest = json.loads(manifest_path.read_text())
    if manifest.get("schema_version") != 1:
        raise ValueError("Expected manifest schema_version 1")
    source_canvas = tuple(manifest["source_canvas_px"])
    if len(source_canvas) != 2 or min(source_canvas) <= 0:
        raise ValueError("Invalid source_canvas_px")
    if not math.isfinite(start_seconds) or start_seconds < 0:
        raise ValueError("start_seconds must be finite and nonnegative")
    tracked = {manifest_path: sha(manifest_path)}
    cells, missing, input_records = {}, [], []
    for clip_id in CLIPS:
        clip = manifest.get("clips", {}).get(clip_id)
        atlas = None
        for direction in DIRECTIONS:
            entry = clip.get("directions", {}).get(direction) if clip else None
            if not entry or not entry.get("frames"):
                missing.append(f"{clip_id}/{direction}")
                continue
            frames = entry["frames"]
            if entry.get("frame_count", len(frames)) != len(frames):
                raise ValueError(f"Frame count mismatch: {clip_id}/{direction}")
            effective_fps = float(entry.get("fps", clip["fps"]))
            positive(effective_fps)
            thumbnails = []
            for record in frames:
                source_path = package / record["file"] if record.get("file") else None
                if source_path and source_path.is_file():
                    digest = sha(source_path)
                    if record.get("png_sha256") and digest != record["png_sha256"]:
                        raise ValueError(f"PNG hash mismatch: {source_path}")
                    tracked[source_path] = digest
                    with Image.open(source_path) as decoded:
                        image = decoded.convert("RGBA")
                    origin = "source_png"
                else:
                    atlas_path = package / clip["atlas"]
                    if atlas is None:
                        digest = sha(atlas_path)
                        if clip.get("atlas_sha256") and digest != clip["atlas_sha256"]:
                            raise ValueError(f"Atlas hash mismatch: {atlas_path}")
                        tracked[atlas_path] = digest
                        with Image.open(atlas_path) as decoded:
                            atlas = decoded.convert("RGBA")
                    x, y, width, height = record["atlas_rect_px"]
                    if x < 0 or y < 0 or x + width > atlas.width or y + height > atlas.height:
                        raise ValueError("Atlas rectangle outside image")
                    image = atlas.crop((x, y, x + width, y + height))
                    origin = "atlas_rectangle"
                if image.size != source_canvas:
                    raise ValueError(f"Source dimensions differ: {clip_id}/{direction}")
                if record.get("rgba_sha256") and hashlib.sha256(image.tobytes()).hexdigest() != record["rgba_sha256"]:
                    raise ValueError(f"RGBA hash mismatch: {clip_id}/{direction}")
                thumbnails.append(image.resize((128, 128), Image.Resampling.LANCZOS))
                input_records.append({"clip": clip_id, "direction": direction,
                                      "index": record["index"], "origin": origin})
            cells[(clip_id, direction)] = {"images": thumbnails, "fps": effective_fps}
        if atlas is not None:
            atlas.close()

    # All image placement uses the unchanged full canvas, never equipment bounds.
    margin, label_width, card_width, card_gap = 24, 166, 140, 8
    header_height, row_height, footer_height = 126, 148, 42
    width = margin * 2 + label_width + 8 * card_width + 7 * card_gap
    height = header_height + 3 * row_height + footer_height
    base = Image.new("RGB", (width, height), "#e8ece6")
    draw = ImageDraw.Draw(base)
    title_font, body_font = font(27, True), font(15)
    row_font, direction_font, small_font = font(19, True), font(13, True), font(13)
    draw.text((margin, 18), "Dřevorubec · přehled animací", font=title_font, fill="#263a30")
    subtitle = f"{duration:g}sekundový výňatek"
    if missing:
        subtitle += f" · dílčí náhled: {len(cells)} z 24 kombinací"
    draw.text((margin, 56), subtitle, font=body_font, fill="#54645a")
    positions = {}
    for column, (direction, label) in enumerate(zip(DIRECTIONS, DIRECTION_LABELS)):
        x = margin + label_width + column * (card_width + card_gap)
        draw.text((x + card_width / 2, 102), label, anchor="mm", font=direction_font, fill="#344b3d")
        for row, clip_id in enumerate(CLIPS):
            y = header_height + row * row_height
            draw.rounded_rectangle((x, y, x + card_width, y + 138), radius=8, fill="#f3f5ef")
            positions[(clip_id, direction)] = (x + 6, y + 5)
            if (clip_id, direction) not in cells:
                draw.text((x + card_width / 2, y + 66), "Chybí", anchor="mm", font=body_font, fill="#907d67")
    for row, clip_id in enumerate(CLIPS):
        draw.multiline_text((margin, header_height + row * row_height + 43), CLIP_LABELS[clip_id],
                            font=row_font, fill="#344b3d", spacing=6)

    frame_count = math.ceil(duration * preview_fps - 1e-10)
    start = Fraction(str(start_seconds))
    tick = 1 / Fraction(str(preview_fps))
    rendered, samples = [], []
    for number in range(frame_count):
        seconds = start + number * tick
        frame = base.copy()
        sample = {"preview_frame": number, "seconds": float(seconds), "source_indices": {}}
        for key, cell in cells.items():
            index = frame_at_time(seconds, cell["fps"], len(cell["images"]))
            image = cell["images"][index]
            frame.paste(image, positions[key], image)
            sample["source_indices"]["/".join(key)] = index
        # A precise time label also prevents APNG encoders merging held frames.
        ImageDraw.Draw(frame).text((margin, height - 30),
            f"Čas ukázky {float(number * tick):.3f} s  ·  snímek výňatku {number + 1}/{frame_count}",
            font=small_font, fill="#647267")
        rendered.append(frame)
        samples.append(sample)

    output_dir = output_dir.resolve()
    if output_dir == package or package in output_dir.parents:
        raise ValueError("Preview output must remain outside source package")
    output_dir.mkdir(parents=True, exist_ok=True)
    still_path, animation_path = output_dir / "overview.png", output_dir / "overview.apng.png"
    rendered[0].save(still_path)
    rendered[0].save(animation_path, save_all=True, append_images=rendered[1:],
                     duration=1000 / preview_fps, loop=0, disposal=0, blend=0,
                     optimize=False, compress_level=6)
    encoded_count, delay = exact_apng_delay(animation_path, preview_fps)
    assert encoded_count == frame_count
    with Image.open(animation_path) as decoded:
        assert decoded.n_frames == frame_count and decoded.mode in ("RGB", "RGBA")
        for number, expected in enumerate(rendered):
            decoded.seek(number)
            assert decoded.convert("RGB").tobytes() == expected.tobytes(), "APNG changed presentation colors"
            assert abs(decoded.info["duration"] / 1000 - 1 / preview_fps) < 1e-9
    assert Image.open(still_path).convert("RGB").tobytes() == rendered[0].tobytes()
    assert all(sha(path) == digest for path, digest in tracked.items()), "Input changed during preview export"
    report = {"created_at": datetime.now(timezone.utc).isoformat(), "manifest": str(manifest_path),
              "manifest_sha256": tracked[manifest_path], "presentation_only": True,
              "excerpt_not_loop_acceptance": True, "duration_seconds": frame_count / preview_fps,
              "start_seconds": start_seconds, "preview_fps": preview_fps,
              "apng_delay_numerator_denominator": delay, "preview_frame_count": frame_count,
              "dimensions_px": [width, height], "source_canvas_px": source_canvas,
              "display_canvas_px": [128, 128], "display_resampling": "Pillow LANCZOS; full source canvas",
              "palette_quantization": False, "decoded_apng_exact_presentation_rgb": True,
              "missing_cells": missing, "available_cell_count": len(cells),
              "effective_direction_fps": {"/".join(key): cell["fps"] for key, cell in cells.items()},
              "native_inputs_unchanged": True, "input_hashes": {str(path): digest for path, digest in tracked.items()},
              "inputs": input_records, "sampling": samples,
              "outputs": {path.name: sha(path) for path in (still_path, animation_path)}}
    (output_dir / "overview-validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    return {"animation": str(animation_path), "still": str(still_path),
            "cells": len(cells), "missing": len(missing), "frames": frame_count,
            "duration_seconds": frame_count / preview_fps, "all_native_inputs_unchanged": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output", type=Path, help="Default: package parent/preview")
    parser.add_argument("--duration", type=positive, default=4.0)
    parser.add_argument("--preview-fps", type=positive, default=30.0)
    parser.add_argument("--start-seconds", type=float, default=0.0)
    args = parser.parse_args()
    output = args.output or args.manifest.resolve().parent.parent / "preview"
    print(json.dumps(export(args.manifest, output, args.duration, args.preview_fps, args.start_seconds), ensure_ascii=False))


if __name__ == "__main__":
    main()
