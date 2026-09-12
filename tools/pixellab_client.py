#!/usr/bin/env python3
"""Small, auditable PixelLab client; official OpenAPI checked 2026-09-10.

API reference: https://api.pixellab.ai/v2/openapi.json
Use PNG inputs at their actual pixel resolution (maximum 256 x 256).
Rotations require a SOUTH-facing reference. Output indices do not imply directions.
The edit command preserves canvas dimensions (free: 16–200px; subscription: 16–400px).
edit-pro is a narrow subscription-only text edit of one 256 x 256 PNG, with a
minimum 20-generation reserve. It uses /edit-images-v2 and requests transparency.

The default is free-only. --subscription-only explicitly uses an active paid
subscription's included generations, with a fresh live-balance budget capped at
800 generations. Both modes REQUIRE zero USD credits to prevent USD fallback.
No credit purchase or subscription change is implemented. Budget checks happen
BEFORE each new job, with a caller-selected generation reserve; the API does not
expose a hard per-request billing cap. Use sequential calls with one shared
--budget-file per production. Do not reuse a free-pilot budget for a subscription.

Examples (options can follow the command):
  python3 tools/pixellab_client.py balance --output /tmp/pixel-balance
  python3 tools/pixellab_client.py animate --input ref.png --action-file walk.txt \
      --frames 8 --output /tmp/pixel-walk --budget-file /tmp/pixel-budget.json
  python3 tools/pixellab_client.py poll --output /tmp/pixel-walk

Read a token from PIXELLAB_API_KEY or --token-file; never put it in arguments.
An authorized in-memory local proxy can instead use --local-relay
--api-base http://127.0.0.1:8769/v2. The client never sends tokens to a relay.
POST requests are NEVER retried. Resume a recorded job with `poll`.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import struct
import sys
import time
from datetime import datetime, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, HTTPRedirectHandler, build_opener


API_BASE = "https://api.pixellab.ai/v2"


class ClientError(RuntimeError):
    pass


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    temporary.replace(path)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class PixelLabClient:
    def __init__(self, api_base=API_BASE, token_file=None, local_relay=False):
        self.api_base = api_base.rstrip("/")
        parsed = urlsplit(self.api_base)
        if local_relay:
            if (parsed.scheme != "http" or parsed.hostname not in ("127.0.0.1", "localhost")
                    or parsed.username or parsed.password or parsed.path != "/v2"
                    or parsed.query or parsed.fragment):
                raise ClientError("Local relay must be literal http://127.0.0.1:PORT/v2 or localhost.")
            self.token = None
        else:
            if self.api_base != API_BASE:
                raise ClientError("Authenticated requests are restricted to the official API base.")
            self.token = (Path(token_file).read_text().strip() if token_file
                          else os.environ.get("PIXELLAB_API_KEY", "").strip())
            if not self.token:
                raise ClientError("Use PIXELLAB_API_KEY, --token-file, or an authorized --local-relay.")
        self.opener = build_opener(NoRedirect())

    def request(self, method, path, output_path, body=None):
        """One HTTP attempt. Preserve response without ever logging request headers."""
        headers = {"Accept": "application/json", "User-Agent": "medieval-rts-art-pilot/1"}
        if self.token:
            headers["Authorization"] = "Bearer " + self.token
        data = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body).encode()
        request = Request(self.api_base + path, headers=headers, data=data, method=method)
        retry_after = None
        try:
            with self.opener.open(request, timeout=120) as response:
                raw = response.read()
                status = response.status
        except HTTPError as exc:
            with exc:
                raw, status = exc.read(), exc.code
                retry_after = exc.headers.get("Retry-After")
        except (URLError, TimeoutError, OSError) as exc:
            write_json(output_path, {"transport_error": type(exc).__name__, "method": method,
                                     "at": utc_now(), "post_outcome_unknown": method == "POST"})
            raise ClientError(f"{method} transport failure. No retry was made; inspect the account before resubmitting.") from None
        text = raw.decode("utf-8", errors="replace")
        if self.token:
            text = text.replace(self.token, "[REDACTED]")
        try:
            result = json.loads(text)
        except ValueError:
            result = {"non_json_response": text}
        write_json(output_path, result)
        if not 200 <= status < 300:
            err = ClientError(f"HTTP {status}; response saved to {output_path}. No request retry was made."
                              + (f" Retry-After: {retry_after}" if retry_after else ""))
            err.status = status
            err.retry_after = retry_after
            raise err
        if not isinstance(result, dict):
            raise ClientError("Expected a JSON object; raw response was preserved.")
        return result

    def balance(self, output_path):
        return self.request("GET", "/balance", output_path)


def png_input(path, max_dimension=256):
    path = Path(path).resolve()
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ClientError("This bounded client takes PNG inputs only; provide an exported PNG.")
    width, height = struct.unpack(">II", data[16:24])
    if not (1 <= width <= max_dimension and 1 <= height <= max_dimension):
        raise ClientError(f"The reference must fit within {max_dimension} x {max_dimension} pixels.")
    return ({"type": "base64", "base64": base64.b64encode(data).decode(), "format": "png"},
            {"path": str(path), "sha256": hashlib.sha256(data).hexdigest(),
             "width": width, "height": height, "png_color_type": data[25]})


def generation_balance(balance):
    try:
        generations = float(balance["subscription"]["generations"])
        dollars = float(balance["credits"]["usd"])
    except (KeyError, ValueError, TypeError):
        raise ClientError("Unrecognized balance response; refusing submission.") from None
    if not math.isfinite(generations) or not math.isfinite(dollars):
        raise ClientError("Non-finite balance response; refusing submission.")
    return generations, dollars


def guard_budget(balance, args):
    remaining, dollars = generation_balance(balance)
    subscription_only = getattr(args, "subscription_only", False)
    mode = "subscription-only" if subscription_only else "free-only"
    if dollars != 0:
        raise ClientError("Included-generation guard: account has USD credits. Refusing potential USD fallback.")
    status = balance.get("subscription", {}).get("status")
    if subscription_only and status != "active":
        raise ClientError("--subscription-only requires an active subscription in the live balance response.")
    if not subscription_only and status == "active":
        raise ClientError("An active paid subscription requires explicit --subscription-only.")
    if remaining < args.reserve_generations:
        raise ClientError("Included generation balance is below the requested per-job reserve.")
    budget_path = Path(args.budget_file) if args.budget_file else Path(args.output) / "budget.json"
    if budget_path.exists():
        budget = json.loads(budget_path.read_text())
        if budget.get("mode", "free-only") != mode:
            raise ClientError("Budget mode differs. Use a new production budget file; do not reset this record.")
    else:
        budget = {"created_at": utc_now(), "initial_generations": remaining,
                  "max_generations": args.max_generations, "initial_usd": dollars,
                  "mode": mode, "subscription_plan": balance.get("subscription", {}).get("plan")}
        write_json(budget_path, budget)
    if remaining > float(budget["initial_generations"]):
        raise ClientError("Balance increased since this budget began. Use a new dated budget after reviewing its history.")
    spent = max(0.0, float(budget["initial_generations"]) - remaining)
    cap = min(float(budget["max_generations"]), args.max_generations)
    if spent + args.reserve_generations > cap:
        raise ClientError("Generation budget does not have enough room for this job's reserve.")
    return {"budget_file": str(budget_path.resolve()), "spent_before": spent,
            "remaining_before": remaining, "reserve_generations": args.reserve_generations,
            "max_generations": cap, "hard_per_job_cap_available": False, "mode": mode,
            "free_only": not subscription_only, "usd_fallback_allowed": False,
            "subscription_plan": balance.get("subscription", {}).get("plan")}


def strict_base64(value):
    """Allow transport line wrapping, while rejecting all other invalid bytes."""
    if value.startswith("data:"):
        value = value.split(",", 1)[1]
    compact = re.sub(r"[ \t\r\n\f\v]", "", value)
    return base64.b64decode(compact, validate=True), len(value) - len(compact)


def verified_edit_rgba(data, last_response, output):
    """Losslessly encode the observed edit service's raw RGBA transport.

    This wire encoding is absent from the public schema. Never infer it from
    byte length alone: corroborate with recorded dimensions, the service's
    quantized PNG, its reported original color count, and matching alpha/RGB.
    The quantized image is evidence only; it never replaces the full-color data.
    """
    try:
        from PIL import Image
    except ImportError:
        raise ClientError("Verifying raw edit RGBA requires Pillow. Resume extract with the bundled Python; do not resubmit.") from None
    output = Path(output)
    provenance = json.loads((output / "provenance.json").read_text())
    request = json.loads((output / "request.json").read_text())
    quantized = last_response.get("quantized_image", {})
    width, height = request.get("width"), request.get("height")
    if (provenance.get("endpoint") != "/edit-image" or last_response.get("type") != "message_done"
            or not isinstance(width, int) or not isinstance(height, int)
            or not 16 <= width <= 400 or not 16 <= height <= 400
            or quantized.get("width") != width or quantized.get("height") != height
            or not isinstance(quantized.get("base64"), str) or len(data) != width * height * 4):
        raise ClientError("Non-PNG edit bytes lack corroborating raw-RGBA dimensions/metadata; preserved JSON needs review.")
    quantized_bytes, _ = strict_base64(quantized["base64"])
    if quantized_bytes[:8] != b"\x89PNG\r\n\x1a\n":
        raise ClientError("Raw edit RGBA verification requires the service's quantized PNG.")
    with Image.open(io.BytesIO(quantized_bytes)) as image:
        if image.size != (width, height) or image.mode != "RGBA":
            raise ClientError("Quantized PNG dimensions or mode do not corroborate raw RGBA.")
        quantized_rgba = image.tobytes()
    pixels = [data[i:i + 4] for i in range(0, len(data), 4)]
    original_colors = len(set(pixels))
    if original_colors != last_response.get("original_image_n_colors"):
        raise ClientError("Raw RGBA unique colors do not match the provider's original_image_n_colors.")
    alpha_identical = data[3::4] == quantized_rgba[3::4]
    foreground_count, difference = 0, 0
    for offset, pixel in zip(range(0, len(data), 4), pixels):
        comparison = quantized_rgba[offset:offset + 4]
        if pixel[3] and (pixel[:3] != b"\xff\xff\xff" or comparison[:3] != b"\xff\xff\xff"):
            foreground_count += 1
            difference += sum(abs(pixel[channel] - comparison[channel]) for channel in range(3))
    mean_difference = difference / (3 * foreground_count) if foreground_count else 0
    if not alpha_identical or not foreground_count or mean_difference > 8:
        raise ClientError("Raw RGBA order/content not sufficiently corroborated by the service's quantized PNG.")
    image = Image.frombytes("RGBA", (width, height), data)
    encoded = io.BytesIO()
    image.save(encoded, format="PNG")
    with Image.open(io.BytesIO(encoded.getvalue())) as check:
        if check.mode != "RGBA" or check.tobytes() != data:
            raise ClientError("Raw RGBA to PNG roundtrip did not preserve every channel byte.")
    alpha = data[3::4]
    return encoded.getvalue(), {"source_encoding": "raw RGBA8, row-major, verified from actual response",
            "encoding_documented_in_public_schema": False, "raw_rgba_sha256": hashlib.sha256(data).hexdigest(),
            "source_byte_count": len(data), "original_color_count": original_colors,
            "provider_original_color_count_matches": True,
            "quantized_reference_sha256": hashlib.sha256(quantized_bytes).hexdigest(),
            "quantized_reference_used_as_output": False, "quantized_reference_alpha_identical": alpha_identical,
            "foreground_rgb_mean_difference_to_quantized": round(mean_difference, 6),
            "verification_foreground_pixels": foreground_count,
            "lossless_png_roundtrip_verified": True, "alpha_min_max": [min(alpha), max(alpha)],
            "transparent_pixels": alpha.count(0), "opaque_pixels": alpha.count(255),
            "background_removed_during_conversion": False}


def save_images(result, output):
    last_response = result.get("last_response") or {}
    container = "last_response"
    if not last_response and isinstance(result.get("image"), dict):
        # /remove-background returns the image synchronously at the top level.
        last_response = result
        container = "response"
    images = last_response.get("images")
    image_location = container + ".images"
    # /edit-image describes one image in last_response but leaves its container
    # untyped. Accept only actual Base64Image values, without guessing a URL.
    if images is None and isinstance(last_response.get("image"), dict):
        images = [last_response["image"]]
        image_location = container + ".image"
    elif images is None and isinstance(last_response.get("base64"), str):
        images = [last_response]
        image_location = container
    if not isinstance(images, list) or not images:
        raise ClientError("Completed job has no Base64Image result; inspect preserved JSON.")
    manifest = []
    for index, item in enumerate(images):
        # v3 documents Base64Image payloads, not URLs. Do not invent download endpoints.
        if not isinstance(item, dict) or not isinstance(item.get("base64"), str):
            raise ClientError(f"Frame {index} is not a Base64Image; inspect preserved JSON.")
        try:
            data, whitespace_removed = strict_base64(item["base64"])
        except ValueError:
            raise ClientError(f"Invalid base64 in frame {index}.") from None
        transport = {"source_encoding": "PNG", "base64_ascii_whitespace_removed": whitespace_removed,
                     "source_decoded_sha256": hashlib.sha256(data).hexdigest()}
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            data, conversion = verified_edit_rgba(data, last_response, output)
            transport.update(conversion)
        if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise ClientError(f"Frame {index} is not PNG; inspect preserved result format.")
        width, height = struct.unpack(">II", data[16:24])
        path = Path(output) / "images" / f"frame_{index:02d}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        manifest.append({"index": index, "path": str(path.resolve()), "width": width,
                         "height": height, "sha256": hashlib.sha256(data).hexdigest(),
                         "png_color_type": data[25], "transport": transport})
    provenance_path = Path(output) / "provenance.json"
    provenance = json.loads(provenance_path.read_text()) if provenance_path.exists() else {}
    contract = provenance.get("output_contract", {})
    expected = contract.get("expected_frames")
    count_matches = expected is None or len(manifest) == expected
    expected_dimensions = contract.get("expected_dimensions")
    dimensions_match = expected_dimensions is None or all(
        [frame["width"], frame["height"]] == expected_dimensions for frame in manifest)
    write_json(Path(output) / "images.json", {"frames": manifest, "response_image_location": image_location,
               "output_contract": contract, "frame_count_matches_contract": count_matches,
               "dimensions_match_contract": dimensions_match,
               "direction_order": "not_assumed; visually verify rotation indices",
               "alpha_note": "PNG color type is not proof of actual alpha coverage; measure pixels separately"})
    if not count_matches:
        raise ClientError(f"Returned {len(manifest)} frames; expected {expected}. All frames preserved; review the result.")
    if not dimensions_match:
        raise ClientError(f"Returned canvas differs from {expected_dimensions}. All images preserved; review the result.")
    return manifest


def poll(client, job_id, output, interval=5, timeout=900):
    if not re.fullmatch(r"[A-Za-z0-9_-]+", job_id):
        raise ClientError("Invalid job identifier.")
    output = Path(output)
    started = time.monotonic()
    count = len(list((output / "polls").glob("*.json"))) if (output / "polls").exists() else 0
    while time.monotonic() - started < timeout:
        count += 1
        try:
            result = client.request("GET", "/background-jobs/" + job_id,
                                    output / "polls" / f"{count:04d}.json")
        except ClientError as exc:
            if getattr(exc, "status", None) == 429:
                try:
                    wait = max(interval, min(60, float(exc.retry_after or interval * 2)))
                except ValueError:
                    wait = min(60, interval * 2)
                print(f"Polling rate limited; waiting {wait:g} seconds.", flush=True)
                time.sleep(wait)
                continue
            raise
        status = result.get("status")
        print(f"Job {job_id}: {status}", flush=True)
        if status in ("completed", "failed"):
            write_json(output / "result.json", result)
            after = client.balance(output / "balance-after.json")
            if status == "failed":
                raise ClientError(f"Generation failed; details preserved at {output / 'result.json'}.")
            frames = save_images(result, output)
            print(json.dumps({"output": str(output.resolve()), "frames": len(frames),
                              "balance_after": after}), flush=True)
            return result
        if status != "processing":
            raise ClientError(f"Unexpected job status {status!r}; refusing blind polling.")
        time.sleep(interval)
    raise ClientError(f"Polling timed out; resume with poll --output {output}. Do not submit again.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["balance", "rotate", "animate", "animate-pixminimax",
                        "edit", "edit-pro", "remove-background", "poll", "extract"])
    parser.add_argument("--output", required=True)
    parser.add_argument("--token-file")
    parser.add_argument("--api-base", default=API_BASE)
    parser.add_argument("--local-relay", action="store_true")
    parser.add_argument("--subscription-only", action="store_true",
                        help="Explicitly use active subscription generations; USD credits must remain zero.")
    parser.add_argument("--input")
    parser.add_argument("--last-frame")
    parser.add_argument("--action-file")
    parser.add_argument("--description-file")
    parser.add_argument("--text-guidance-scale", type=float, default=8,
                        help="Edit command only: strength of description, 1–10.")
    parser.add_argument("--frames", type=int, default=8)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--drift-threshold", type=float)
    parser.add_argument("--keep-background", action="store_true")
    parser.add_argument("--background-removal-task", default="remove_simple_background",
                        choices=["remove_simple_background", "remove_complex_background"])
    parser.add_argument("--submit-only", action="store_true")
    parser.add_argument("--job-id")
    parser.add_argument("--poll-interval", type=float, default=5)
    parser.add_argument("--poll-timeout", type=float, default=900)
    parser.add_argument("--budget-file", help="Share across sequential calls to limit the whole pilot.")
    parser.add_argument("--max-generations", type=float,
                        help="Whole production limit: default20 free / 800 subscription; subscription maximum800.")
    parser.add_argument("--reserve-generations", type=float,
                        help="Preflight room: default/min20 edit-pro, default12 PixMiniMax / 2 others; not a server cap.")
    args = parser.parse_args()
    if args.max_generations is None:
        args.max_generations = 800 if args.subscription_only else 20
    if args.reserve_generations is None:
        args.reserve_generations = {"animate-pixminimax": 12, "edit-pro": 20}.get(args.command, 2)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    if args.command == "extract":
        frames = save_images(json.loads((output / "result.json").read_text()), output)
        print(json.dumps({"frames": len(frames), "output": str(output.resolve())}))
        return
    if (not 2 <= args.poll_interval <= 60 or args.poll_timeout <= 0
            or not math.isfinite(args.poll_timeout)):
        raise ClientError("Polling requires a 2–60 second interval and positive finite timeout.")
    client = PixelLabClient(args.api_base, args.token_file, args.local_relay)
    if args.command == "balance":
        print(json.dumps(client.balance(output / "balance.json"), indent=2))
        return
    if args.command == "poll":
        job_id = args.job_id or json.loads((output / "submitted.json").read_text())["background_job_id"]
        poll(client, job_id, output, args.poll_interval, args.poll_timeout)
        return
    if (output / "request.json").exists():
        raise ClientError("A submission record already exists here. Resume with poll or use a new output folder.")
    if not args.input:
        raise ClientError("--input is required for generation.")
    if args.seed < 0:
        raise ClientError("Seed must be nonnegative.")
    if args.subscription_only and args.max_generations > 800:
        raise ClientError("This subscription production is limited to at most 800 included generations.")
    if args.command == "animate-pixminimax" and not args.subscription_only:
        raise ClientError("PixMiniMax requires an active Tier2+ subscription and explicit --subscription-only.")
    if args.command == "edit-pro":
        if not args.subscription_only:
            raise ClientError("Pro editing requires explicit --subscription-only.")
        if args.reserve_generations < 20:
            raise ClientError("A 256 x 256 Pro edit requires a minimum 20-generation reserve.")
        if args.keep_background:
            raise ClientError("This Pro edit command requires no_background=true; omit --keep-background.")
    for value in (args.max_generations, args.reserve_generations):
        if not math.isfinite(value) or value <= 0:
            raise ClientError("Budget values must be positive and finite.")
    max_dimension = 400 if args.command in ("edit", "remove-background") else 256
    first, meta = png_input(args.input, max_dimension)
    payload = {"first_frame": first, "seed": args.seed, "no_background": not args.keep_background}
    output_contract = {}
    if args.command == "edit-pro":
        endpoint = "/edit-images-v2"
        if (meta["width"], meta["height"]) != (256, 256):
            raise ClientError("This Pro edit command accepts exactly one original 256 x 256 PNG; it does not resize.")
        if not args.description_file:
            raise ClientError("--description-file is required for Pro image editing.")
        description = Path(args.description_file).read_text().strip()
        if not 1 <= len(description) <= 2000:
            raise ClientError("Pro edit description must contain 1–2000 characters.")
        size = {"width": 256, "height": 256}
        payload = {"method": "edit_with_text", "edit_images": [{"image": first, **size}],
                   "image_size": size, "description": description, "seed": args.seed,
                   "no_background": True}
        output_contract = {"expected_frames": 1, "synchronous": False,
                           "expected_dimensions": [256, 256], "method": "edit_with_text"}
    elif args.command == "remove-background":
        endpoint = "/remove-background"
        size = {dimension: meta[dimension] for dimension in ("width", "height")}
        payload = {"image": first, "image_size": size, "seed": args.seed,
                   "background_removal_task": args.background_removal_task}
        if args.description_file:
            description = Path(args.description_file).read_text().strip()
            if len(description) > 500:
                raise ClientError("Background-removal text hint must be at most 500 characters.")
            payload["text"] = description
        output_contract = {"expected_frames": 1, "synchronous": True}
    elif args.command == "edit":
        endpoint = "/edit-image"
        if not args.description_file:
            raise ClientError("--description-file is required for image editing.")
        description = Path(args.description_file).read_text().strip()
        if not 1 <= len(description) <= 500:
            raise ClientError("Edit description must contain 1–500 characters.")
        edit_max = 400 if args.subscription_only else 200
        if not all(16 <= meta[dimension] <= edit_max for dimension in ("width", "height")):
            raise ClientError(f"This mode supports same-canvas editing from 16 x 16 to {edit_max} x {edit_max}.")
        if not 1 <= args.text_guidance_scale <= 10:
            raise ClientError("Edit text guidance scale must be between 1 and 10.")
        size = {dimension: meta[dimension] for dimension in ("width", "height")}
        payload = {"image": first, "image_size": size, **size, "description": description,
                   "seed": args.seed, "no_background": not args.keep_background,
                   "text_guidance_scale": args.text_guidance_scale}
        output_contract = {"expected_frames": 1, "synchronous": False}
    elif args.command == "rotate":
        endpoint = "/generate-8-rotations-v3"
        if args.description_file:
            description = Path(args.description_file).read_text().strip()
            if len(description) > 2000:
                raise ClientError("Rotation description must be at most 2000 characters.")
            payload["description"] = description
    else:
        minimax = args.command == "animate-pixminimax"
        endpoint = "/animate-pixminimax" if minimax else "/animate-with-text-v3"
        if not args.action_file:
            raise ClientError("--action-file is required for animation.")
        action = Path(args.action_file).read_text().strip()
        if not 1 <= len(action) <= 1000:
            raise ClientError("Action must contain 1–1000 characters.")
        if minimax:
            if args.frames not in range(4, 41, 4):
                raise ClientError("PixMiniMax requires multiples of 4 from 4 to 40 generated frames.")
            payload.update(description=action, frame_count=args.frames)
            output_contract = {"expected_frames": args.frames + 1, "synchronous": False,
                               "index_zero": "input frame, followed by frame_count generated frames",
                               "opaque_input_note": "no_background may cut out an opaque first frame"}
        else:
            if args.frames not in range(4, 17, 2) or meta["width"] * meta["height"] * args.frames > 524288:
                raise ClientError("Animation needs 4–16 even frames and width × height × frames <= 524288.")
            payload.update(action=action, frame_count=args.frames, enhance_prompt=False)
        if args.last_frame:
            last, last_meta = png_input(args.last_frame)
            if (last_meta["width"], last_meta["height"]) != (meta["width"], meta["height"]):
                raise ClientError("First and last frames must have matching dimensions.")
            payload["last_frame"] = last
            meta["last_frame"] = last_meta
        if args.drift_threshold is not None:
            if not math.isfinite(args.drift_threshold) or args.drift_threshold < 0:
                raise ClientError("Drift threshold must be nonnegative and finite.")
            payload["drift_threshold"] = args.drift_threshold
    balance = client.balance(output / "balance-before.json")
    budget = guard_budget(balance, args)
    write_json(output / "request.json", payload)
    write_json(output / "provenance.json", {"created_at": utc_now(), "endpoint": endpoint,
               "api_schema": "https://api.pixellab.ai/v2/openapi.json", "schema_checked": "2026-09-10",
               "input": meta, "budget": budget, "output_contract": output_contract,
               "automatic_post_retries": 0})
    submitted = client.request("POST", endpoint, output / "submitted.json", payload)
    if args.command == "remove-background":
        write_json(output / "result.json", submitted)
        after = client.balance(output / "balance-after.json")
        frames = save_images(submitted, output)
        print(json.dumps({"output": str(output.resolve()), "frames": len(frames),
                          "usage": submitted.get("usage"), "balance_after": after}), flush=True)
        return
    job_id = submitted.get("background_job_id")
    if not job_id:
        raise ClientError("Submission response missing job ID. Inspect it before any new request.")
    print(json.dumps({"job_id": job_id, "output": str(output.resolve()),
                      "usage": submitted.get("usage")}), flush=True)
    if not args.submit_only:
        poll(client, job_id, output, args.poll_interval, args.poll_timeout)


if __name__ == "__main__":
    try:
        main()
    except (ClientError, OSError, ValueError, KeyError) as exc:
        print(f"PixelLab: {exc}", file=sys.stderr)
        sys.exit(1)
