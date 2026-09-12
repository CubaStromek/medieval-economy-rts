# Installed delivery audit — 2026-09-10

**PASS.** This was a read-only mechanical audit after the production builder
installed the package. It did not modify delivery files, raw jobs or game code.

- All **498 files** in the delivery ledger match their recorded SHA-256 and
  sizes; package and preview contain **zero symlinks**.
- All **24 clip/direction records** exactly match the reviewed selection,
  including repair-job paths, frame order and individual playback rates.
- **439 selected frames** match the originals byte for byte. Their decoded
  RGBA pixels also match both atlas cells and APNG image regions.
- All selected frames have actual transparent and opaque pixels. Every APNG
  retains the selected frame count and decodes to the exact configured frame
  duration for its direction.
- All **24 archived raw frame_00 references** are exact source copies with
  recorded SHA-256. They are identified as input references, not a new idle
  animation.
- All **472 raw frames** in the chosen source jobs match their declared
  per-job counts. The packer reports **zero warnings**.

The shared 256×256 canvas, anchor `[128,205]`, source body height 163 and world
body height 33 match the explicit delivery configuration. Physical ground
contact, native runtime rendering and user acceptance have separate evidence.
See `final-delivery-audit.json` for measured counts, durations and file-ledger
hash.
