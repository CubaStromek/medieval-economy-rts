# Terrain import tools

The ordinary prototype and its public tests need no original game data.
`import-kam-terrain.cjs` is an optional, local, **terrain-only** converter.
It reads binary map data and tile definitions; it never executes a mission,
downloads anything, imports graphics or modifies either input.

## Import Mountainous Region locally

Use Node.js 18 or newer. Obtain a source map with appropriate rights and the
matching KaM Remake `data/defines/tiles.json`. Create the external output
directory, then run from the project root:

```sh
mkdir -p game/external_assets/maps
node tools/import-kam-terrain.cjs \
  --map "/absolute/path/Mountainous Region.map" \
  --tiles "/absolute/path/kam_remake/data/defines/tiles.json" \
  --out game/external_assets/maps/mountainous-region.json \
  --name "Mountainous Region" \
  --source-url "https://github.com/reyandme/kam_remake_maps/blob/aed738dcaba06070a16ecfb73ca8977ad285b674/MapsMP/Mountainous%20Region/Mountainous%20Region.map"
```

Output creation is exclusive: an existing destination is never overwritten.
To compare another import, choose a new output filename. The JSON includes the
source hash, revision, dimensions, conversion parameters and omission report.
Store original inputs and converted outputs outside Git; the repository already
ignores `original_game_data/`, `reference/kam_remake/` and
`game/external_assets/`. Never force-add these directories.

Supported layouts are original 23-byte tile records and modern r10969–r11222
records. Later revisions and malformed/unrecognized data are rejected rather
than guessed. This tool does not promise general map/scenario compatibility.
See [exact provenance, conversion and limitations](../docs/mountainous-region.md).

## Tests

```sh
node --test tools/import-kam-terrain.test.cjs
```

This uses authored synthetic fixtures. To additionally run the independent
real-file comparison, provide both environment variables:

```sh
KAM_TEST_MAP="/absolute/path/Mountainous Region.map" \
KAM_TEST_TILES="/absolute/path/kam_remake/data/defines/tiles.json" \
node --test tools/import-kam-terrain.test.cjs
```

The game-side loader, scene, camera and persistence tests run through
`./tests/run-headless.sh` and never require the original map.
