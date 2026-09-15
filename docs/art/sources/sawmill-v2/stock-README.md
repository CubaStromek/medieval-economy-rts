# Stock layer source record — sawmill v2

2026-09-12. `export-stock.cjs` reads `stock-layout.json` and the unchanged
own source assets referenced there. It writes only
`game/art/buildings/sawmill/v2/operation/stock/`, `stock-fields.json` and
isolated stock QA images. It does not edit the house, main manifest,
simulation, work poses or v1 files.

The log is the exact same own painted log used by the lumber hut, extracted
with its original polygon at its original world scale. The plank is an
unchanged full-resolution crop from the own v1 RGBA master, with new uniform
registration. No new image generation was performed for either v2 stock
prop. The new foreground copies only measured pixels of concept04's final
800² house; base and both artwork source SHA256 checks must pass before
re-export.

The production geometry contains the source crops, per-piece rectangles,
cap anchors, prop contact semantics, actual alpha bounds, asset hashes,
foreground polygons and world-space support checks. `stock-fields.json`
is the fragment for the root-owned operation manifest: merge its `stock`
and `work.foreground` without changing the other working-person fields.

Reproduce with the project Node runtime and Sharp:

```sh
NODE_PATH=/Users/openclaw/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules node docs/art/sources/sawmill-v2/export-stock.cjs
```

See [final stock QA](../../qa/sawmill-v2/stock/README.md) and its complete
0–4 / 0–6 contact sheets. The earlier
`docs/art/qa/sawmill-v2-stock-preflight/` files document the pre-master
proposal and subsequent measurement; the production `stock/geometry.json`
is authoritative for delivered geometry.
