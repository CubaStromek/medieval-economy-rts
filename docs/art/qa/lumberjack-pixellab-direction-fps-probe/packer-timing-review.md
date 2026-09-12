# Packer: direction playback timing, 2026-09-10

PASS for the optional `--direction-fps CLIP/DIR=FLOAT` contract in
`tools/pack_pixellab_lumberjack.py`. This is a synthetic offline timing check;
actual asset and native Godot evidence are recorded separately in this folder.

- A synthetic 8-frame S sequence uses the fallback clip rate of 10 fps. A
  synthetic 12-frame SE sequence explicitly overrides it to 15 fps. Both APNGs
  decode to exactly 0.8 seconds per loop. The 15 fps APNG records rational
  1/15-second frame delays, avoiding millisecond rounding drift.
- The manifest writes `directions.SE.fps: 15`, leaves S without a direction
  override, and assigns each source frame duration from its effective rate.
  PNG copies are byte-identical and frame indices/order are unchanged.
- The actual generated HTML script ran with a simulated DOM and controlled
  animation callbacks. At 0.2 seconds it draws S frame 2 and SE frame 3; at
  0.4 seconds frames 4 and 6; both return to frame 0 at 0.8 seconds. It also
  draws the SE-only advance at 1/15 second, preserves elapsed time while
  paused, and handles 2× playback speed. This checks the renderer's timing
  code, not merely a duplicate calculation of expected indices.
- A separate run without direction flags retains the 12 fps clip fallback,
  has no direction-level fps properties, and yields APNG bytes identical to
  the original Pillow save settings. The no-override HTML frame clock also
  passed its unchanged shared-tick behavior.
- The runtime check found and fixed an existing HTML startup error:
  `textContent` was called as a function instead of read as a property.

Full measured evidence is in `packer-timing-validation.json`. Temporary
reproduction scripts and synthetic packages are under
`/private/tmp/pixellab-direction-fps-synthetic*`. No API calls, source art
mutation, frame resampling, extra frames, or asset registration occurred.
