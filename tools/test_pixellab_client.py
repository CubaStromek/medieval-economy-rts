"""Offline transport, budget and API-contract checks; never contact PixelLab.

Run: python3 -m unittest discover -s tools -p test_pixellab_client.py
"""

import base64
import contextlib
import io
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
import zlib

import pixellab_client as client


def png(width=128, height=128):
    def chunk(kind, value):
        return struct.pack(">I", len(value)) + kind + value + struct.pack(">I", zlib.crc32(kind + value))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    # One RGBA pixel repeated with a transparent backdrop, compressed losslessly.
    raw = (b"\x00" + bytes((70, 40, 20, 0)) * width) * height
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


def balance(generations=10000, status="active", usd=0):
    return {"credits": {"usd": usd}, "subscription": {"status": status,
            "plan": "Tier 2", "generations": generations, "total": 10000}}


class FakeAPI:
    def __init__(self, live_balance=None):
        self.live_balance = live_balance or balance()
        self.posts = []

    def balance(self, output):
        client.write_json(output, self.live_balance)
        return self.live_balance

    def request(self, method, endpoint, output, payload=None):
        assert method == "POST"
        self.posts.append((endpoint, payload))
        if endpoint == "/remove-background":
            result = {"image": {"base64": base64.b64encode(png()).decode(), "type": "base64"},
                      "usage": {"type": "generations", "generations": 0.2}}
        else:
            result = {"background_job_id": "offline-test-job", "status": "processing"}
        client.write_json(output, result)
        return result


class PixelLabClientTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.input = self.root / "source.png"
        self.input.write_bytes(png())
        self.prompt = self.root / "motion.txt"
        self.prompt.write_text("A looping walk with the tool held consistently in the right hand.")

    def tearDown(self):
        self.temporary.cleanup()

    def run_cli(self, command, extra=(), api=None):
        api = api or FakeAPI()
        output = self.root / ("output-" + str(len(list(self.root.glob("output-*")))))
        argv = ["pixellab_client.py", command, "--input", str(self.input), "--output", str(output),
                "--action-file", str(self.prompt), "--description-file", str(self.prompt),
                "--submit-only", *extra]
        with patch.object(client, "PixelLabClient", return_value=api), patch("sys.argv", argv):
            with contextlib.redirect_stdout(io.StringIO()):
                client.main()
        return api, output

    def test_subscription_budget_uses_live_baseline_and_stops_at_cap(self):
        args = SimpleNamespace(output=self.root, budget_file=str(self.root / "production.json"),
                               max_generations=800, reserve_generations=12, subscription_only=True)
        first = client.guard_budget(balance(3700), args)
        self.assertEqual(first["remaining_before"], 3700)
        self.assertFalse(first["usd_fallback_allowed"])
        self.assertEqual(client.guard_budget(balance(2912), args)["spent_before"], 788)
        with self.assertRaises(client.ClientError):
            client.guard_budget(balance(2911), args)
        with self.assertRaises(client.ClientError):
            client.guard_budget(balance(3701), args)

    def test_usd_credits_and_inactive_subscription_are_blocked(self):
        for live in (balance(10000, usd=0.01), balance(10000, status="trial"), balance(10000, status="expired")):
            with self.subTest(live=live), self.assertRaises(client.ClientError):
                self.run_cli("animate", ["--subscription-only"], FakeAPI(live))

    def test_paid_subscription_requires_explicit_flag_and_cap_cannot_expand(self):
        with self.assertRaises(client.ClientError):
            self.run_cli("animate")
        with self.assertRaises(client.ClientError):
            self.run_cli("animate", ["--subscription-only", "--max-generations", "801"])

    def test_free_budget_cannot_be_reused_as_paid_budget(self):
        budget_path = self.root / "old-free-budget.json"
        client.write_json(budget_path, {"initial_generations": 40, "max_generations": 20, "initial_usd": 0})
        with self.assertRaises(client.ClientError):
            self.run_cli("animate", ["--subscription-only", "--budget-file", str(budget_path)])

    def test_minimax_40_at_256_uses_its_own_schema_and_records_41_frames(self):
        self.input.write_bytes(png(256, 256))
        api, output = self.run_cli("animate-pixminimax", ["--subscription-only", "--frames", "40",
                                   "--last-frame", str(self.input), "--drift-threshold", "0"])
        endpoint, payload = api.posts[0]
        self.assertEqual(endpoint, "/animate-pixminimax")
        self.assertEqual(set(payload), {"first_frame", "last_frame", "description", "frame_count",
                                       "seed", "no_background", "drift_threshold"})
        self.assertTrue(payload["no_background"])
        self.assertEqual(payload["first_frame"], payload["last_frame"])
        provenance = json.loads((output / "provenance.json").read_text())
        self.assertEqual(provenance["output_contract"]["expected_frames"], 41)
        self.assertEqual(provenance["budget"]["reserve_generations"], 12)
        self.assertEqual(provenance["budget"]["max_generations"], 800)

    def test_invalid_minimax_count_and_old_v3_limit_fail_before_post(self):
        for command, frames in (("animate-pixminimax", "6"), ("animate", "40")):
            api = FakeAPI()
            with self.subTest(command=command), self.assertRaises(client.ClientError):
                self.run_cli(command, ["--subscription-only", "--frames", frames], api)
            self.assertFalse(api.posts)

    def test_256_edit_allowed_for_subscription_but_free_cap_preserved(self):
        self.input.write_bytes(png(256, 256))
        api, _ = self.run_cli("edit", ["--subscription-only"])
        self.assertEqual(api.posts[0][1]["image_size"], {"width": 256, "height": 256})
        with self.assertRaises(client.ClientError):
            self.run_cli("edit", api=FakeAPI(balance(40, status="trial")))

    def test_edit_pro_has_one_original_image_and_exact_documented_payload(self):
        self.input.write_bytes(png(256, 256))
        api, output = self.run_cli("edit-pro", ["--subscription-only"])
        endpoint, payload = api.posts[0]
        self.assertEqual(endpoint, "/edit-images-v2")
        self.assertEqual(set(payload), {"method", "edit_images", "image_size", "description", "seed", "no_background"})
        self.assertEqual(payload["method"], "edit_with_text")
        self.assertEqual(payload["image_size"], {"width": 256, "height": 256})
        self.assertEqual(len(payload["edit_images"]), 1)
        image = payload["edit_images"][0]
        self.assertEqual(set(image), {"image", "width", "height"})
        self.assertEqual(base64.b64decode(image["image"]["base64"]), self.input.read_bytes())
        self.assertTrue(payload["no_background"])
        provenance = json.loads((output / "provenance.json").read_text())
        self.assertEqual(provenance["budget"]["reserve_generations"], 20)

    def test_edit_pro_rejects_underreserve_wrong_size_and_opaque_flag_before_post(self):
        for extra in (["--subscription-only"], ["--subscription-only", "--reserve-generations", "19"],
                      ["--subscription-only", "--keep-background"], []):
            api = FakeAPI()
            with self.subTest(extra=extra), self.assertRaises(client.ClientError):
                self.run_cli("edit-pro", extra, api)
            self.assertFalse(api.posts)
        self.input.write_bytes(png(256, 256))
        self.prompt.write_text("a" * 2001)
        with self.assertRaises(client.ClientError):
            self.run_cli("edit-pro", ["--subscription-only"])

    def test_remove_background_synchronous_response_saved_exactly(self):
        api, output = self.run_cli("remove-background", ["--subscription-only"])
        endpoint, payload = api.posts[0]
        self.assertEqual(endpoint, "/remove-background")
        self.assertEqual(set(payload), {"image", "image_size", "seed", "background_removal_task", "text"})
        self.assertEqual((output / "result.json").read_bytes(), (output / "submitted.json").read_bytes())
        self.assertEqual((output / "images/frame_00.png").read_bytes(), png())
        self.assertTrue((output / "balance-after.json").exists())

    def test_frame_count_mismatch_is_reported_after_preserving_all_frames(self):
        output = self.root / "frames"
        client.write_json(output / "provenance.json", {"output_contract": {"expected_frames": 9}})
        result = {"last_response": {"images": [{"base64": base64.b64encode(png()).decode()}]}}
        with self.assertRaises(client.ClientError):
            client.save_images(result, output)
        self.assertTrue((output / "images/frame_00.png").exists())
        manifest = json.loads((output / "images.json").read_text())
        self.assertFalse(manifest["frame_count_matches_contract"])

    def test_pro_wrong_output_dimensions_are_reported_without_discarding_image(self):
        output = self.root / "pro-wrong-size"
        client.write_json(output / "provenance.json", {"output_contract": {"expected_frames": 1,
                                                                           "expected_dimensions": [256, 256]}})
        result = {"last_response": {"images": [{"base64": base64.b64encode(png(128, 128)).decode()}]}}
        with self.assertRaises(client.ClientError):
            client.save_images(result, output)
        self.assertTrue((output / "images/frame_00.png").exists())
        self.assertFalse(json.loads((output / "images.json").read_text())["dimensions_match_contract"])

    def test_relay_cannot_point_at_arbitrary_host(self):
        for origin in ("http://example.com/v2", "https://127.0.0.1/v2", "http://127.0.0.1@example.com/v2"):
            with self.subTest(origin=origin), self.assertRaises(client.ClientError):
                client.PixelLabClient(origin, local_relay=True)

    def test_rate_limited_post_is_attempted_once_without_relay_token(self):
        api = client.PixelLabClient("http://127.0.0.1:8769/v2", local_relay=True)
        calls = []
        def fail(request, timeout):
            calls.append(request)
            raise HTTPError(request.full_url, 429, "limit", {"Retry-After": "5"}, io.BytesIO(b'{"detail":"limit"}'))
        with patch.object(api.opener, "open", side_effect=fail), self.assertRaises(client.ClientError):
            api.request("POST", "/animate-pixminimax", self.root / "rejected.json", {"frame_count": 8})
        self.assertEqual(len(calls), 1)
        self.assertNotIn("Authorization", calls[0].headers)
        self.assertEqual(json.loads((self.root / "rejected.json").read_text())["detail"], "limit")

    def test_line_wrapped_png_base64_is_losslessly_extracted(self):
        wrapped = base64.encodebytes(png()).decode()
        frames = client.save_images({"last_response": {"image": {"base64": wrapped}}}, self.root)
        self.assertGreater(frames[0]["transport"]["base64_ascii_whitespace_removed"], 0)
        self.assertEqual((self.root / "images/frame_00.png").read_bytes(), png())

    @unittest.skipUnless(importlib.util.find_spec("PIL"), "Raw RGBA corroboration requires the bundled Pillow runtime")
    def test_raw_rgba_edit_is_verified_then_losslessly_encoded_without_alpha_fabrication(self):
        from PIL import Image
        width = height = 16
        data = b"".join(bytes((40 + x * 4, 100 + y * 5, 20 + x, 255))
                        for y in range(height) for x in range(width))
        reference = io.BytesIO()
        Image.frombytes("RGBA", (width, height), data).save(reference, format="PNG")
        client.write_json(self.root / "provenance.json", {"endpoint": "/edit-image"})
        client.write_json(self.root / "request.json", {"width": width, "height": height})
        response = {"type": "message_done", "image": {"type": "base64", "base64": base64.encodebytes(data).decode()},
                    "quantized_image": {"width": width, "height": height,
                                        "base64": base64.b64encode(reference.getvalue()).decode()},
                    "original_image_n_colors": width * height}
        frames = client.save_images({"last_response": response}, self.root)
        metadata = frames[0]["transport"]
        self.assertTrue(metadata["lossless_png_roundtrip_verified"])
        self.assertFalse(metadata["quantized_reference_used_as_output"])
        self.assertFalse(metadata["background_removed_during_conversion"])
        self.assertEqual(metadata["alpha_min_max"], [255, 255])
        with Image.open(self.root / "images/frame_00.png") as decoded:
            self.assertEqual(decoded.tobytes(), data)
        response["original_image_n_colors"] -= 1
        with self.assertRaises(client.ClientError):
            client.verified_edit_rgba(data, response, self.root)
        response["original_image_n_colors"] += 1
        swapped = b"".join(bytes((data[i + 2], data[i + 1], data[i], data[i + 3])) for i in range(0, len(data), 4))
        with self.assertRaises(client.ClientError):
            client.verified_edit_rgba(swapped, response, self.root)


if __name__ == "__main__":
    unittest.main()
