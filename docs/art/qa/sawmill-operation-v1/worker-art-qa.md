# Working carpenter asset QA

Date: 2026-09-12. Scope: six authored working poses, technical layer repair, actual alpha and measured registration. This is an asset review; normal gameplay capture, worker/log contact, routing, state privacy and foreground occlusion are recorded separately in [operation QA](README.md). The building-set style remains a draft and this record does not claim user approval.

## Delivered contract

- [Worker metadata](../../../../game/art/buildings/sawmill/v1/operation/work/worker-geometry.json) is authoritative: `worker-0.png` through `worker-5.png`, six 512² canvases, body height 412 source pixels, ground contact `[374.5,489]`, 33-world-pixel calibration.
- Original six ImageGen cells, registered by integer translation from the apron/waist region. No synthetic intermediate frames and no independent normalization of animated feet.
- Source0 head, support arm and every pixel at or below y=282 stay identical. The near arm and wooden handle retain each real source pose. The steel bitmap is the same source0 part translated to each measured handle join.
- Source prompts, SHA, exact masks, blend policy and cleanup coordinates are linked from the [source record](../../sources/sawmill-operation-v1/worker-README.md).

## Inspected images

- [Complete six-pose contact sheet](worker-cycle-registered-sheet.png): inspected all six at source scale; fixed stance and identity, same steel length, genuine near-arm motion.
- [Hands and handle detail](worker-cycle-hands-2x.png): inspected support hand, rigid blade, wooden join and sleeve seam in every pose.
- [Layer-mask diagram](worker-layer-masks.png): cyan is the fixed support selection, pink the steel, yellow the changing near-arm region, blue the fixed head check and green the fixed lower-body boundary. Red marks the measured common ground contact.
- [33-world-pixel strip](worker-cycle-33worldpx.png): six separately authored poses at intended human scale. The 41px canvas rounds body height to approximately 33px; runtime uses the exact scalar from metadata.

## Defects found and resolved

The raw sheet drifted horizontally and vertically between cells, changed the stance and moved the supposed supporting hand. It also shortened the saw blade in several poses. Fixed authored layers and a common rigid blade resolve these defects. The first composition showed an extra chin and fragments of the original far arm, so the final composition starts from the complete source0 body and replaces only the near-arm region.

A later review found a gap at the phase2 handle, a detached skin-colored fragment in phase3 and a sharp collar seam. The blade removal now preserves brown wood, detached body fragments are removed before adding steel, and the near-arm mask excludes the fixed collar. Its opaque internal edge receives a 10-source-pixel color blend (0.801 world px) to remove the stitching line. These repairs were inspected on the final whole sheet and detail sheet. They do not invent motion frames. Slight original variation in sleeve folds remains between the six authored poses.

## Independent verification

`verify-worker-assets.gd` ran successfully with Godot 4.7.2 on 2026-09-12. [Decoded PNG results](worker-asset-verification.json) record SHA256 for all six final frames:

- Six correctly decoded 512² PNGs and expected common registration.
- 208,041–208,475 fully transparent pixels per frame, 3,300–3,550 partially transparent edge pixels and 50,126–50,803 opaque pixels. This is genuine alpha, not an opaque key or checkerboard.
- Zero residual magenta pixels at the stated dominance/alpha threshold.
- Zero changed pixels in the fixed head region and entire lower body compared with frame0; opaque apron and both soles were checked as positive controls.
- The exporter separately verifies zero changed opaque support-arm pixels. The immutable source blade is placed after fragment cleanup and only integer-translated.

The isolated strip cannot establish hand-to-log contact, draw order or state behavior; those require the native operation captures linked above. The support hand is intentionally held at one point on the workshop log, so it can lie above the moving steel in pulled phases.
