# Release 0.6.0 verification — 2026-09-15

Scope: release **0.6.0**, the accumulated work of 12–14 September 2026 plus the
new versioning documents. That work covers:

- the painted sawmill and warehouse;
- building presence layers;
- the Czech HUD;
- the day/night removal;
- the packed pathfinding index;
- retained building layers;
- real-time tick catch-up.

No artwork generation, paid service use or player-save migration was performed
as part of this pass. See the [changelog](../CHANGELOG.md#060--2026-09-15) and
the [release process](release-process.md).

## Environment and baseline

- Repository: `CubaStromek/medieval-economy-rts`, branch `main`.
- Baseline: `c965329`, the 0.5.0 milestone from 2026-09-12.
- `git fetch origin` and `git rev-list --left-right --count HEAD...origin/main`
  returned `0 0`. The remote had no tags.
- Engine: `4.7.2.stable.official.ed1daf0bf`, macOS, Apple M4, OpenGL 4.1
  Compatibility for native checks.
- Save format v23; `config/version="0.6.0"` in `game/project.godot`.

## Checks of the working project

| Check | Result |
|---|---|
| Complete scene-based headless suite | **787/787 passed**, exit 0 |
| Focused native refactor/rendering runner | **79 cases, 0 failures**, exit 0 |
| Painted-terrain sidecar exporter | **6/6 passed**, exit 0 |
| Terrain binary importer | **17 passed, 1 optional real-map test skipped**, exit 0 |
| PixelLab client, Python 3.12.14 with Pillow 12.3.0 | **16/16 passed**, exit 0 |
| Diff whitespace validation | Passed |

The commands are listed in the [release process](release-process.md#releasing).
The system `python3` has no Pillow and skipped one PixelLab case (15 passed).
The full run used a local Python with Pillow. These tests mock the service; they
submit nothing, consume no credits and need no API key.

The importer's optional real-map check requires an explicit external fixture
and was skipped rather than counted as a pass. Native checks ran their own
assertions. This pass does not claim a new manual art approval or a repeat of
earlier directional screenshots; those remain in the dated `docs/art/qa/`
records with their original scope.

## Clean-copy verification

A separate copy was created with `git checkout-index --all` from the staged
index of the feature work: 5,203 files. It contained no `.godot` cache, original
game data or local reference clone.

The fresh import finished without script or import errors. The complete
scene-based suite then passed **787/787**, exit 0.

After this check, only release documentation changed, plus the one-line
`config/version` in `game/project.godot`. That setting is metadata with no
runtime effect, and the working-project checks above ran with it.

## Publication hygiene

- **Payload.** The staged feature work has 958 paths and about 427 MB of added or
  modified content. The largest file is a 3,535,493-byte warehouse QA
  screenshot, far below GitHub's 100 MiB limit. The existing pack was 889 MiB.
- **QA frame sequences.** 1,288 sequence PNGs (977 MB) in `frames/`, `motion/`
  and `*-motion/` directories under `docs/art/qa/` stay local through new
  `.gitignore` rules, at the user's decision. The 33 frames referenced by
  documentation (28.8 MB) were added explicitly. MP4 captures, reports and
  READMEs stay published, so some QA READMEs describe sequences that a public
  clone does not contain. The 145 sequence files published in earlier releases
  remain tracked.
- **Original assets.** A SHA-256 comparison of all 2,097 new files against 1,069
  unique hashes of local image, map, data and audio files in
  `original_game_data/` and `reference/` found no byte-identical copies. This
  detects exact copies, not derived images.
- **Provenance.** The records for sawmill v2, warehouse v1, the sawmill stock and
  carpenter work poses, and the resting lumberjack state that no KaM image was an
  image input. The KaM sawmill study in `docs/art/references/` is text only.
- **Credentials.** Changed and new text files were scanned for API-key, token and
  password patterns without printing possible values. No matches were found.
  This is a bounded publication check, not a formal security or licensing
  certification.
- **Exclusions.** The existing proprietary-data exclusions remain in force.
  `original_game_data/`, `reference/` and `.godot` are ignored.
