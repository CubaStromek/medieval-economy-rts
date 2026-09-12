# Independent review — chop NE, 2026-09-10

**PASS for packaging source frames 1–16 as a loop.** All 17 returned 256×256
frames were inspected together at native scale in `contact.png`; frame 00
remains the archived reference. This review does not establish in-game contact
or user acceptance.

The lumberjack retains his cap, green tunic, belt and boots. Both hands remain
on one axe shaft; the near and far hand separate clearly during the low phase.
No duplicate axe, tree, target, swing trail, particles or other effect appears.
The shoulder preparation in 01–04 leads into a lateral downward stroke in
05–08, a low hold around 08–11, and a return through 12–16. This is a readable
waist-height chopping stroke; it is not an overhead swing. The torso rotates
with the action while both boots remain planted.

The selected loop seam 16→01 has composited RGB mean absolute difference
0.256826/255, within ordinary adjacent changes of 0.170675–3.303090. The final
pose closes naturally into the initial preparation; it is not pixel-identical.
No source frame needs reversing, duplication or interpolation.

All frames contain actual transparent and opaque pixels, and no visible alpha
touches a canvas edge. Across all 17 images the fixed lower-canvas region
`y >= 188` has the same alpha bounds `[85,188,158,206]`. Together with visual
inspection this supports stationary boots; these bounds are not a proposed
physical ground anchor. Original PNG hashes remained unchanged.

Mechanical evidence: `statistics.json` and `loop-selection-analysis.json`.
