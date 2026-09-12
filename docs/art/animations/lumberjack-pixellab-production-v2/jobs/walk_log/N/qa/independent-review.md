# Independent review — walk_log N, 2026-09-10

**Repair the frame selection: use 1–11 at 13.75 fps.** The artwork passes the
carrying and anatomy review, but raw 1–16 does not contain a whole number of
double steps. No new generation is needed for the recommended repair. All 17
returned frames should remain in the source archive.

All 17 native 256×256 frames were visually inspected in `contact.png`. One log
runs lengthwise over the anatomical right shoulder, supported by the raised
right arm. The left arm is free and swings. The shaft at the left hip remains
attached; the axe head is mostly occluded in this rear view, so its complete
shape cannot be verified here. There is no second log, duplicated tool,
detached cargo, or new obvious body/log intersection. Clothing and cap remain
consistent. The torso and log bob together while the legs alternate.

The actual gait period is 11 phases: the screen-right boot extends furthest
back in 03, the screen-left boot in 08–09, and the feet pass the neutral pose
at 06 and 11. Frames 12–16 repeat the first half of this gait; 12 matches the
foot positions of 01 and 14 those of 03. Looping all 16 would repeat that
same-leg half-step twice at each wrap. A low numerical seam difference alone
does not fix that cadence problem.

Frames 1–11 provide one complete double step in the original order, without
resampling, interpolation or extra images. At 13.75 fps they take exactly
0.8 seconds. The 11→01 seam has composited RGB mean absolute difference
2.081970/255, within ordinary transitions of 0.905116–3.183482. The foot
sequence continues from the neutral pose into the next right-leg phase.

Every frame has genuine transparency and visible opaque content; no nonzero
alpha reaches a canvas edge. Source hashes remain unchanged. Physical ground
contact, runtime registration and user acceptance require their separate
checks. See `statistics.json` and `loop-selection-analysis.json` for the
measured foot positions, repeated phases and seam evidence.
