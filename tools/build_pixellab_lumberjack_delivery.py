#!/usr/bin/env python3
"""Build the reviewed 3×8 lumberjack delivery; never alter raw jobs or game assets.

Usage: python3 tools/build_pixellab_lumberjack_delivery.py ROOT
Requires ROOT/delivery-selection.json with status "reviewed". Existing package,
preview and validation outputs are retained in ROOT/delivery-backups/. Only the
temporary staging tree contains symlinks; delivered outputs contain real files.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid

from pack_pixellab_lumberjack import CLIPS, DIRECTIONS


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def check_selection(root):
    path = root / "delivery-selection.json"
    selection = json.loads(path.read_text(encoding="utf-8"))
    if selection.get("status") != "reviewed":
        raise ValueError('delivery-selection.json must have status exactly "reviewed"; drafts cannot be built.')
    for key, required in (("anchor_source_px", [128, 205]), ("body_height_source_px", 163),
                          ("body_height_world_px", 33)):
        if selection.get(key) != required:
            raise ValueError(f"Reviewed {key} must equal the explicit lumberjack registration {required}.")
    records = selection.get("records")
    expected = {f"{clip}/{direction}" for clip in CLIPS for direction in DIRECTIONS}
    if not isinstance(records, dict) or set(records) != expected:
        raise ValueError("Reviewed selection must contain exactly all 24 clip/direction records.")
    source_hashes = {path: digest(path)}
    jobs = {}
    for key, record in records.items():
        relative = Path(record["job"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"{key}: source job must be a relative path inside ROOT.")
        job = (root / relative).resolve(strict=True)
        if not job.is_relative_to(root) or not job.is_dir():
            raise ValueError(f"{key}: source job is outside ROOT or not a directory.")
        indices = record.get("source_indices")
        if (not isinstance(indices, list) or not indices or
                any(type(i) is not int or i < 1 for i in indices) or indices != sorted(set(indices))):
            raise ValueError(f"{key}: generated source indices must be unique, increasing positive integers.")
        fps = record.get("fps")
        if type(fps) not in (int, float) or not math.isfinite(fps) or fps <= 0:
            raise ValueError(f"{key}: fps must be a finite positive number.")
        provenance_path, extraction_path = job / "provenance.json", job / "images.json"
        provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
        expected_count = provenance.get("output_contract", {}).get("expected_frames")
        if type(expected_count) is not int or expected_count <= 0:
            raise ValueError(f"{key}: missing valid declared raw count in source provenance.")
        paths = sorted((job / "images").glob("frame_*.png"))
        if [p.name for p in paths] != [f"frame_{i:02d}.png" for i in range(expected_count)]:
            raise ValueError(f"{key}: raw images do not match the declared consecutive count {expected_count}.")
        if indices[-1] >= expected_count:
            raise ValueError(f"{key}: selected index exceeds the declared raw count.")
        extraction = json.loads(extraction_path.read_text(encoding="utf-8"))
        frames = extraction.get("frames", [])
        if len(frames) != expected_count or [f.get("index") for f in frames] != list(range(expected_count)):
            raise ValueError(f"{key}: source client extraction ledger is incomplete.")
        for image, frame in zip(paths, frames):
            actual = digest(image)
            if actual != frame.get("sha256") or (frame.get("width"), frame.get("height")) != (256, 256):
                raise ValueError(f"{key}/{image.name}: source SHA or verified 256×256 dimensions disagree with client ledger.")
            source_hashes[image] = actual
        source_hashes[provenance_path] = digest(provenance_path)
        source_hashes[extraction_path] = digest(extraction_path)
        jobs[key] = {"path": job, "relative": str(job.relative_to(root)), "expected_count": expected_count,
                     "provenance_sha256": source_hashes[provenance_path],
                     "extraction_ledger_sha256": source_hashes[extraction_path]}
    return selection, jobs, source_hashes


def install_outputs(root, stage, names):
    """Keep previous outputs and roll back a failed multi-output installation."""
    tag = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
    backup = root / "delivery-backups" / tag
    replaced, installed = [], []
    try:
        for name in names:
            target = root / name
            if target.exists() or target.is_symlink():
                backup.mkdir(parents=True, exist_ok=True)
                shutil.move(str(target), str(backup / name))
                replaced.append(name)
            shutil.move(str(stage / name), str(target))
            installed.append(name)
    except Exception:
        for name in reversed(installed):
            shutil.move(str(root / name), str(stage / name))
        for name in reversed(replaced):
            shutil.move(str(backup / name), str(root / name))
        raise
    return str(backup) if replaced else None


def build(root):
    root = Path(root).resolve(strict=True)
    selection, jobs, source_hashes = check_selection(root)
    stage = Path(tempfile.mkdtemp(prefix="pixellab-delivery-"))
    try:
        packer_selection = {clip: {} for clip in CLIPS}
        for key, record in selection["records"].items():
            clip, direction = key.split("/")
            alias = stage / "jobs" / clip / direction
            alias.parent.mkdir(parents=True, exist_ok=True)
            alias.symlink_to(jobs[key]["path"], target_is_directory=True)
            packer_selection[clip][direction] = record["source_indices"]
        selection_path = stage / "selection.json"
        write_json(selection_path, packer_selection)
        packer = Path(__file__).with_name("pack_pixellab_lumberjack.py").resolve()
        args = ["--expected-frames", "0", "--anchor", "128", "205", "--body-height", "163",
                "--world-height", "33", "--selection", str(selection_path), "--review-note",
                "Výběr 24 směrů prošel obrazovým QA; herní integrace a přijetí uživatelem se ověřují samostatně."]
        for clip in CLIPS:
            for direction in DIRECTIONS:
                key = f"{clip}/{direction}"
                args += ["--direction-fps", f"{key}={selection['records'][key]['fps']}"]
        run = subprocess.run([sys.executable, str(packer), str(stage), *args],
                             check=True, capture_output=True, text=True)
        summary = json.loads(run.stdout)
        package = stage / "package"
        manifest = json.loads((package / "manifest.json").read_text())
        qa = json.loads((stage / "pack-validation.json").read_text())
        references, source_index = {}, {}
        for key, record in selection["records"].items():
            clip, direction = key.split("/")
            job = jobs[key]
            direction_record = manifest["clips"][clip]["directions"][direction]
            direction_record["source_job"] = job["relative"]
            for frame in direction_record["frames"]:
                frame["source_file"] = f"{job['relative']}/images/frame_{frame['source_index']:02d}.png"
            direction_qa = qa["clips"][clip][direction]
            if direction_qa["raw_frame_count_verification"] != "matched":
                raise ValueError(f"{key}: packer did not verify the source raw count.")
            direction_qa["selection_authority"] = "package/provenance/delivery-selection.json"
            direction_qa["expected_raw_frame_count_authority"] = job["relative"] + "/provenance.json:output_contract.expected_frames"
            for frame in direction_qa["frames"]:
                frame["file"] = job["relative"] + "/images/" + Path(frame["file"]).name
            reference_path = package / "references" / clip / f"{direction}.png"
            reference_path.parent.mkdir(parents=True, exist_ok=True)
            original = job["path"] / "images/frame_00.png"
            shutil.copyfile(original, reference_path)
            if digest(reference_path) != source_hashes[original]:
                raise ValueError(f"{key}: reference copy SHA mismatch.")
            references[key] = {"file": str(reference_path.relative_to(package)), "source_job": job["relative"],
                               "source_index": 0, "source_file": job["relative"] + "/images/frame_00.png",
                               "png_sha256": digest(reference_path), "role": "archived input reference; not an idle animation"}
            source_index[key] = {k: v for k, v in job.items() if k != "path"}
        manifest["delivery_provenance"] = "provenance/delivery-selection.json"
        manifest["reference_images"] = {"index": "provenance/reference-images.json",
                                        "count": 24, "role": "archived input references; not a new animation clip"}
        provenance_dir = package / "provenance"
        provenance_dir.mkdir(exist_ok=True)
        shutil.copyfile(root / "delivery-selection.json", provenance_dir / "delivery-selection.json")
        shutil.copyfile(selection_path, provenance_dir / "packer-selection.json")
        write_json(provenance_dir / "reference-images.json", references)
        write_json(provenance_dir / "source-jobs.json", source_index)
        write_json(provenance_dir / "build.json", {
            "created_at": datetime.now(timezone.utc).isoformat(),
            "selection_sha256": source_hashes[root / "delivery-selection.json"],
            "builder_sha256": digest(Path(__file__)), "packer_sha256": digest(packer),
            "python_version": sys.version, "source_images_unchanged": True,
            "all_24_directions_have_explicit_fps": True,
            "rebuild_command": [sys.executable, str(Path(__file__).resolve()), str(root)],
            "source_file_paths_relative_to": "original production ROOT; runtime uses copied package frames",
            "reference_note": "The 24 raw frame_00 PNGs are input references, not a generated idle animation."})
        write_json(package / "manifest.json", manifest)
        write_json(stage / "pack-validation.json", qa)
        for path, expected_hash in source_hashes.items():
            if digest(path) != expected_hash:
                raise ValueError(f"Source changed during build: {path.relative_to(root)}")
        names = ["package", "preview", "pack-validation.json"]
        files = {}
        for name in names:
            path = stage / name
            for item in ([path] if path.is_file() else sorted(path.rglob("*"))):
                if item.is_symlink():
                    raise ValueError(f"Delivery contains a symlink: {item.relative_to(stage)}")
                if item.is_file():
                    files[str(item.relative_to(stage))] = {"sha256": digest(item), "bytes": item.stat().st_size}
        write_json(stage / "delivery-files.json", {"files": files, "symlinks": 0,
                   "reference_count": 24, "source_selection_sha256": source_hashes[root / "delivery-selection.json"]})
        backup = install_outputs(root, stage, names + ["delivery-files.json"])
        shutil.rmtree(stage)  # rmtree unlinks staging job symlinks; it does not follow them.
        return {"package": str(root / "package"), "preview": str(root / "preview/index.html"),
                "validation": str(root / "pack-validation.json"), "backup": backup,
                "selected_frames": summary["selected_count"], "references": 24,
                "symlinks_in_delivery": 0, "warnings": summary["warnings"]}
    except Exception:
        print(f"Build failed; staging retained at {stage}. Active delivery was not replaced unless installation completed.", file=sys.stderr)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    print(json.dumps(build(args.root), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
