# Independent review — walk_log NE, 2026-09-10

**PASS for source frames 1–16 at 20 fps:** one complete double step lasting
0.8 seconds. All 17 returned 256×256 frames were inspected at native scale in
`contact.png`; 00 remains the archived source reference.

There is one lengthwise log supported on the anatomical right shoulder by
the raised right arm. Its screen projection extends from lower-left/back
toward upper-right/front. The left arm remains free, partly hidden by the
back and cargo at this angle; the left-hip tool shaft is intermittently
visible, while its head is occluded. No second log, floating cargo,
duplicated tool, new obvious penetration, target or added effect appears.
The log and supporting arm move together; cap and clothing retain identity.

The legs pass through both opposing stride positions, cross and return to
the initial phase once over the 16 generated frames. It is a single longer
cycle, not two repeated eight-frame cycles. The 16→01 composited RGB mean
absolute difference is 2.106588/255, within ordinary consecutive changes of
1.687398–2.957179. The final stance closes into the next step without needing
an extra reference hold or a reversed/duplicated frame.

Every frame has actual transparency and visible opaque content, with no
nonzero alpha touching the canvas boundary. The stride moves the boots and
includes a small body/cargo bob; this review does not infer a physical anchor
from the changing boot silhouette. PNG hashes remained unchanged. In-game
ground contact, registration and user acceptance remain separate checks.

Evidence: `statistics.json` and `loop-selection-analysis.json`.
