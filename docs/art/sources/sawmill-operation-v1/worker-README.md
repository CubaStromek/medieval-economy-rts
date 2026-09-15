# Working carpenter source and export

Date: 2026-09-12. This is the sawmill's own working carpenter, derived from the six built-in ImageGen poses in `carpenter-cycle-key.png`. The exact initial and key-background repair prompts are `carpenter-saw-cycle-prompt.txt` and `carpenter-saw-cycle-repair-prompt.txt`. The first gradient-background attempt is retained as `carpenter-cycle-attempt-01.png`; production uses the repaired magenta source only. No KaM image was used as an image input.

Authoritative production registration, filenames, hashes, source-cell rectangles, selection polygons and per-frame cleanup measurements are in [`worker-geometry.json`](../../../../game/art/buildings/sawmill/v1/operation/work/worker-geometry.json). The renderer should read this record; its world placement belongs to the operation manifest and must not be inferred from canvas center.

The six generated cells had differing camera positions, feet, support-hand locations and blade lengths. The technical derivative uses the source0 head, supporting arm, torso and complete lower body as a fixed base. Only the registered, genuinely authored near-arm/wooden-handle region and its underlying apron from each original cell change. Registration translations came from the apron/waist patch, not from moving feet or bounding-box centers. A 10-source-pixel internal mask-edge blend combines source colors only where both layers are opaque; it removes the visible stitching edge at the sleeve. It creates no extra poses or motion interpolation.

`worker-rigid-blade.png` contains the actual steel pixels from source0. Every frame uses this bitmap translated to its original wooden-handle join, without rotation or scaling. The old blade is removed with recorded polygons and a neutral-color test that preserves the brown handle and skin. Body-composition fragments are removed before placing the rigid blade, so this cleanup does not alter its teeth. `worker-fixed-support-arm.png` records the retained support pixels. The exact detached original-arm fragment in pose3 and smaller key-edge fragments are listed in the metadata.

The source has RGB key background. The exporter measures magenta as `[251,3,250]`, removes key dominance `min(R,B)-G >= 190`, unmattes fractional edge colors and writes genuine RGBA. The deliverable is six separate 512² PNGs, measured hair top 77, common sole baseline 489 and ground contact `[374.5,489]`. Height is 412 source pixels, calibrated to 33 world pixels. No shadow is baked below the boots.

Reproduce with the project Node runtime and Sharp:

```sh
NODE_PATH=/Users/openclaw/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules node docs/art/sources/sawmill-operation-v1/export-worker-cycle.cjs
```

The exporter writes only the worker artwork, worker metadata and worker contact sheets. It does not edit the sawmill house, operation manifest, bench, stock props, game logic or runtime placement. See the separate [worker art QA](../../qa/sawmill-operation-v1/worker-art-qa.md) for actual asset checks and the operation QA record for native rendering.
