# Project instructions

## Game time held like KaM Remake — user direction, 2026-09-14

The user asked that game time follow real time like KaM Remake instead of the
game slowing down under load. `MainView._advance_simulation` replays owed ticks
(backlog capped at 100, 100 ms of catch-up per frame, the rest stays owed) and
restarts the clock after start, load and reset. Do not reintroduce a per-frame
tick cap that drops time.

## Day/night cycle removed — user direction, 2026-09-14

The user removed the complete day/night mechanic: calendar clock and sky
display, map tinting, night rest and sleeping places, the Workers' Cottage,
night wolves and moving sun shadows. Cast shadows are not drawn dynamically
for now. Do not reintroduce night lighting, night chimney smoke or window
light, sleep or wolves without a new user request. Older art guidance that
mentions night-time presence effects is historical for those states; chimneys
and windows remain ordinary architecture. Save v23 migrates older saves.

## Building design skill — user direction, 2026-09-13

For building concepts, artwork revisions, visual reviews and sprite integration,
use the personal `medieval-building-design` skill at
`/Users/openclaw/.codex/skills/medieval-building-design/SKILL.md` when available.
It preserves the common painted language, distinct silhouettes, measured ground
fit and state-ready architecture. Ordinary inhabited/workshop buildings include
a chimney and readable windows from the first concept; domestic night smoke
and warm window light follow actual presence, separately from production effects.
The skill preserves the requested scope and adds no approval gate.

On 2026-09-13 the user positively received sawmill v2 and requested this reusable
workflow. Use the own sawmill v2 / lumber hut comparison as the current working
visual reference, with its dated feedback in `docs/art/building-style-guide.md`.
This does not freeze every detail or authorize unrelated catalog production.

## Artwork must fit its footprint — user direction, 2026-09-10

For future generated objects, establish the actual footprint/collision, entrance
and human scale before generation. Fit the first concept to that ground guide
and measure its ground contacts before producing construction or other variants.
Walls, footings and blocking props must fit occupied ground; assess roof-only
overhangs separately and preserve usable free cells and the doorway approach.
Fix an oversized concept before deriving the set; do not enlarge gameplay
footprints merely to accommodate generated art. The user explicitly authorized
expanding the current lumberjack hut's footprint to preserve its existing art
and construction set; this is an object-specific exception, not a precedent
for future objects. This requirement adds no approval gate to authorized work.

## Directional unit production — user direction, 2026-09-10

For creating, repairing or integrating directional 2D unit sprites/animations,
use the personal `pixellab-godot-unit-pipeline` skill at
`/Users/openclaw/.codex/skills/pixellab-godot-unit-pipeline/SKILL.md` when available.
It captures the reference, equipment, cycle selection and real-game QA workflow;
each profession still needs its own state/tool contract and measured geometry.
The lumberjack's clips, frame counts, source anchors and contact offsets are
examples, not universal unit parameters. Reuse the object workflow and existing
briefs below; the skill adds no approval gate to already authorized work.

## Reusable object implementation workflow — user direction, 2026-09-10

Before implementing or revising rendered game objects (buildings, trees,
props or unit artwork/animation), read `docs/art/object-implementation-workflow.md`.
Use `docs/art/object-integration-template.md` for the object's implementation
record and `docs/art/object-qa-template.md` for actual verification. Reuse
existing object briefs and link their authoritative values instead of copying
them into competing records. Building artwork still follows the guide below.

Separate physical ground position, image registration, visual depth and shadow
receivers. Verify actual alpha, ground contact, all delivered states and the
normal game path. Counts, mask polygons, scale and sorting offsets from the
lumber hut are object-specific; its current loader/exporter are not generic.
Technical success does not make its remaining art defects or unapproved style
an accepted reference for the next object. These procedures add no approval
gate to already authorized implementation and do not apply to unrelated work.

## Building artwork — user direction, 2026-09-09

For any new or revised building artwork, concept, image-generation brief,
sprite integration or building-graphics review:

1. Read `docs/art/building-style-guide.md` completely before creating artwork.
2. Create/update the building's brief from
   `docs/art/building-brief-template.md`. Read its existing brief first.
3. Respect the current footprint, entrance, projection, unit scale, lighting,
   fog, selection and construction contracts. Art changes do not authorize
   gameplay, camera or save-format changes.
4. Use the guide's common direction and any explicitly approved **own** reference
   assets. KaM is a stylistic reference, not a building-by-building tracing target.
5. The process and the user's originality/consistency requirement apply now.
   The palette/architectural vocabulary remains a draft (currently v0.2) until
   the user approves a specific pilot in-game. Do not claim a pilot or style reference is
   approved when it is not. Do not mass-produce the catalog before calibration.
6. Keep a dated provenance/approval record and actual in-game QA images with
   every production asset. A prompt or isolated render alone is not acceptance.
7. A style change affecting the set must be explicit and versioned; do not
   silently introduce a new camera, scale, material treatment or detail level.

8. The user's latest camera correction (2026-09-09) applies to artwork: a mild
   elevated front-LEFT oblique/isometric view, showing a modest LEFT side.
   The user further requested more view from ABOVE: readable roof/work-area
   top planes, not a low eye-level view. Calibrate against inspected original
   KaM imagery, without claiming an exact numeric elevation or approval.
   Never infer a perfectly frontal facade from the engine's axis-aligned 40px
   square grid. Do not rotate that grid, alter footprints, or invent exact
   numeric KaM camera angles to satisfy an art brief.
9. Design status-ready zones, separate layers and shared anchors from the first
   concept: changing stock amounts, physical indoor presence and work activity
   are distinct states. Do not bake stock, workers or smoke-as-status into the
   static house. Follow the guide's state-source and fog-privacy contracts.

The user chose the lumberjack hut as the first actual concept:
`docs/art/briefs/lumber-hut-v3.md`. The forester hut brief remains a later,
unproduced sibling draft; it is not the first approved pilot.
On 2026-09-10 the user explicitly expanded the work to in-game construction:
`docs/art/briefs/lumber-hut-construction-v1.md` now records the own RGBA pilot,
12 timber + 21 finishing steps, and a separate stable visual depth anchor.
The source v3 concept remains RGB; its production derivative has genuine alpha.
This is not approval of the building-set style, slope contact/overhang calibration,
or a stock/presence status system. Read the pilot's QA record before extending it.
KaM's object/terrain ordering is documented in
`docs/art/kam-object-terrain-rendering-study.md`; visual depth is not physical height.
For non-visual changes, preserve the established art contracts; reading all art
documents is not required for unrelated tasks.

Current and more specific user instructions take precedence. Preserve unrelated
working-tree changes. Do not commit or push without a current user request.
