# Natural trail balance — 2026-09-05

Trails are a reward for sustained logistics, not a permanent record of every
historical footstep. All aging uses simulation time (10 ticks per game second),
so pause freezes it and speed controls affect travel and regrowth together.

## Initial tuning

| Rule | Current value |
|---|---:|
| Formation | 36 retained passes |
| Weak wear decay | 1 pass / 200 ticks (20 game seconds) |
| Established wear decay | 1 pass / 400 ticks (40 game seconds) |
| Minimum retained strength of an established trail | 16 passes |
| Periodic sparse aging scan | 20 ticks (2 game seconds) |

A carrier adds one pass to the destination cell and to the actual undirected
from/to connection, up to the formation cap. Ongoing decay means 36 is the
required **retained strength**, not a promise that exactly 36 arbitrarily spaced
visits will form a trail. Old fractional decay intervals are preserved when a
worker passes; frequent movement cannot continually reset the aging clock.

Sparse visits cannot accumulate forever. A three-pass abandoned trace disappears
in about one game minute. A full unused trail loses its established speed after
about fourteen game minutes, then its remaining weak trace fades over roughly
five more. Periodic scans may delay visible aging by up to two game seconds.
These are starting balance values for playtesting, not claims about the original
Knights and Merchants mechanics.

Maintaining a trail is easier than making it. Once wear falls below sixteen,
that cell/link must again reach thirty-six to be established; a single next pass
cannot flicker its movement bonus back on.

## What counts

- Normal carrier travel counts, including empty return journeys.
- Idle yielding does not count, even though the sidestep is visibly animated.
- Other professions, fields, deposits and player-built stone surfaces do not
  accumulate cell wear. A real approach from/to stone may retain a dirt link.
- Only the traversed connection gains directional wear. Adjacent muddy cells
  do not automatically create shortcuts, crosses or extra junctions.
- Stone-to-stone adjacency remains automatic, permanent and fastest.

Entering dirt receives the 4-tick cardinal / 6-tick diagonal speed only over an
established link. Unworn approaches retain base-terrain speed. Entering stone
remains 2/3 ticks; grass is 6/9. A step that forms a new trail keeps the duration
captured before its wear was recorded, so it never snaps forward mid-animation.

## Appearance and rendering

The first three passes produce no visible patch. Higher weak wear creates a
small, gently increasing trace without a speed bonus. Established dirt has
narrower shoulders than the previous artwork and gradually thins/fades as it
regrows. Connections follow the actual direction records while still conforming
to the shared-height terrain and clipped diagonal corners.

The system stores only touched cells and traversed links, capped by map size
and eight-way adjacency; empty records are removed. Aging runs only in simulation
updates, never in the renderer or save reads. Dirty surface neighborhoods remain
separate from retained base terrain; a normal step touches at most two overlapping
3×3 neighborhoods. Unchanged mature traffic does not redraw the map.

## Saves and migration

Version 11 stores cell wear, establishment flags, absolute decay timestamps and
canonical directional records. Loading validates all records transactionally,
including blocked corners and field/deposit endpoints, and restores the scan
phase so reloading cannot accelerate or postpone aging.

Versions 1–10 retain existing stone roads and mature dirt tiles. Mature trails
begin with the new full strength at the saved tick; partial wear stays partial.
Old saves did not record movement directions, so exact historical routes cannot
be recovered: the migration reconstructs only their already-visible legal joins
between mature trail/stone neighbors. Those inherited joins subsequently age
under the new rules. It does not grant goods, remove citizens or change homes.

`add_dirt_trail()` remains a deliberate scenario-authoring helper. It can author
connections to existing adjacent surfaces; real carrier movement uses
`record_carrier_traffic(destination, previous, tick)` instead. Controlled legacy
tests may tune formation thresholds explicitly without changing gameplay defaults.

## Verification

The native Godot 4.7.2 project suite passes 288/288 cases. Thirty-eight newly
registered cases cover trail rules, actual carrier movement, appearance and
save compatibility; existing economy, terrain and workplace regressions remain.
Native previews verified subtle early traces, actual U-shaped routes without
invented diagonals, slope joins and a fading unused branch between busy junctions.

A warmed-up Apple M4 headless probe with 128 touched cells and 128 links measured
about 0.293 ms per aging sweep (once per twenty ticks), essentially identical on
64×64 and 512×512 maps. This is a local diagnostic, not a frame-rate guarantee.
Fresh path searches remain a separate performance concern: a same-map probe
measured roughly 45 ms for an open-ground query both before and after the new
trail scoring; established-link checks added about 2 ms to its connected-trail
query. This update does not claim to remove all pre-existing routing stalls.
