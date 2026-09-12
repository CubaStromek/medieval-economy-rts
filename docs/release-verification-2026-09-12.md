# Publication verification — 2026-09-12

Scope: publish the accumulated project work and refresh the handover. No new
gameplay, artwork generation, paid service use or player-save migration was
performed as part of this publication pass.

## Environment and baseline

- Repository: `CubaStromek/medieval-economy-rts`, branch `main`.
- Baseline before publication: `7af2a48`.
- `git fetch origin` and `git rev-list --left-right --count HEAD...origin/main`
  returned `0 0` before changes were committed.
- Engine: `4.7.2.stable.official.ed1daf0bf`, macOS, Apple M4,
  OpenGL 4.1 Compatibility for native checks.
- Current snapshot format: v21; map projection: 40 × 40 world pixels.

## Fresh checks of the working project

| Check | Result |
|---|---|
| Complete scene-based headless suite | **762/762 passed**, exit 0 |
| Focused native refactor/rendering suite | **81 cases, 0 failures**, exit 0 |
| Painted-terrain sidecar exporter | **6/6 passed**, exit 0 |
| Terrain binary importer | **17 passed, 1 optional real-map test skipped**, exit 0 |
| PixelLab client, local mocked tests with Pillow | **16/16 passed**, no skipped cases, exit 0 |
| Diff whitespace validation | Passed |

Commands from the repository root:

```sh
./tests/run-headless.sh
godot --path game --audio-driver Dummy --windowed --resolution 1440x900 res://tests/refactor_runner.tscn
node --test tools/export-painted-visual.test.cjs
node --test tools/import-kam-terrain.test.cjs
python3 -m unittest discover -s tools -p test_pixellab_client.py
git diff --check
```

The system Python initially skipped the one Pillow-dependent test. The full
16-case suite was then rerun with the local bundled Python 3.12/Pillow runtime
and passed without skips. The tests mock service communication: they do not
submit animations, consume credits or require an API key.

The importer's optional real-map check requires explicit external fixture
configuration; it was skipped rather than counted as a pass. The independent
17 synthetic importer tests do not require original game data.

Local logs are under `/private/tmp/kam-handover-20260912-*.log` and are not
published. The native run completed its own assertions; this publication pass
does not claim a new manual art approval or a repeat of every historical
directional screenshot. Prior screenshot-level QA remains in the dated
`docs/art/qa/` records, with its original scope and limitations.

## Public-checkout verification

A separate temporary copy was populated using `git checkout-index --all`
from the proposed commit's index. It contained no original game data, imported
external assets, local reference clone or pre-existing `.godot` cache.

The fresh import completed without script/import errors, followed by the
complete **762/762 passing scene-based tests**, exit 0:

```sh
godot --headless --editor --path /path/to/clean-copy/game --import
godot --headless --path /path/to/clean-copy/game --scene res://tests/test_runner.tscn
```

All 1,352 staged game files matched the tested copy byte-for-byte, apart from
removing one redundant trailing blank line in a GDScript file; no semantic
game changes followed the clean-copy test. Remaining edits were documentation.
This verifies the public-file copy rather than relying on the workstation's
existing imports or original-game assets. Optional imported map availability
is not promised by this result.

## Publication hygiene

The payload includes runtime code/data/assets, tests, tools, object workflows,
own-character production sources and archived experiments, and QA evidence.
`HANDOVER.md` is the current summary; the previous content is preserved in
`docs/handover-archive/2026-09-09.md`.

The existing proprietary-data exclusions remain in force. Added exclusions
cover Python/browser caches, `.env` secrets, raw PixelLab requests/responses,
polls and account balances, the pilot's machine-specific symlink and a
reproducible 95 MB Blender QA scene. The source GLB and its QA images remain
part of the preserved static experiment; it is not runtime content.

No local excluded files were deleted. Existing ZIP exclusions remain unchanged.
Some historical QA and cost-audit records therefore refer to local-only files;
they are evidence summaries, not a claim that the entire original workstation
or API transport archive is distributed with the game.

Before staging, text files were checked for private-key/token patterns and
credential-bearing or signed download URLs without printing possible values.
No matches were found. This is a bounded publication check, not a formal
security or licensing certification.

An additional SHA-256 comparison of 2,954 candidate image/model/data assets
against the 1,302 local external reference assets found no byte-identical
original-asset copies. This detects exact copies, not all possible derived
images; the recorded input provenance and external-directory exclusions remain
necessary. No staged file exceeds GitHub's 100 MiB per-file limit; the largest
is the preserved static GLB (61,905,824 bytes).
