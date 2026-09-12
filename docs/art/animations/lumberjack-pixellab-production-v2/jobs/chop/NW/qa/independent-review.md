# Independent review — chop NW, 2026-09-10

**PASS for packaging source frames 1–16 as a loop.** All 17 returned 256×256
frames were inspected together at native scale in `contact.png`; frame 00
remains the archived reference. This review does not establish in-game contact
or user acceptance.

One axe remains attached to two hands throughout the sequence. The leftward
axe head and the raised far hand are readable during 02–06; the lower stroke
partly occludes the shaft against the body without generating another tool.
Cap, back of tunic, belt and boots remain consistent. No tree, target, duplicate
limb, swing trail or other effect is introduced.

Frames 01–04 lift the axe above the shoulders, 05–08 lower it into the stroke,
08–11 hold the low position, and 12–16 return to the starting preparation.
Both boots remain planted while the arms and shoulders provide the motion.
The selected seam 16→01 has composited RGB mean absolute difference
1.201309/255, within ordinary adjacent changes of 0.131063–2.377045. It is a
normal motion transition rather than an exact repeated still; the complete
1–16 order provides a usable loop without interpolation or extra frames.

All frames contain actual transparent and opaque pixels, and no visible alpha
touches a canvas edge. Across all 17 images the fixed lower-canvas region
`y >= 188` has identical alpha bounds `[109,188,158,216]`. This supports the
visual finding of stable boots but does not define a physical ground anchor.
Original PNG hashes remained unchanged.

Mechanical evidence: `statistics.json` and `loop-selection-analysis.json`.
