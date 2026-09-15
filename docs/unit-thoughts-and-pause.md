# Unit thoughts and independent work pause

Implemented on **2026-09-07**. These controls pause an individual unit or
building, not the game clock or the entire settlement.

## Reading a person's thoughts

Select one of your units and open **Details → Co si myslím**. **Teď:** describes
its actual current activity; **Potom:** explains the committed next step or a
conditional intention when no job has yet been assigned. Both are short Czech
first-person sentences, for example “Nesu kládu do pily.” or “Spím ve skladu.”

The text is a read-only view of simulation state. It does not run another job
search, reserve resources, advance hunger, or invent a successful future route.
Blocked paths, unavailable ingredients, full output buffers, meals and
paused work have their own explanations. Refreshing the panel does not change
the unit. Its thoughts remain readable when it is inside a known owned building;
foreign units and hidden contacts do not reveal private thoughts or controls.

## Controls

- **Unit:** `Pozastavit práci` / `Pokračovat v práci` changes only that unit.
- **Completed building:** `Pozastavit provoz` / `Obnovit provoz` changes that
  building, including warehouses and service buildings.
- **Construction site:** `Pozastavit stavbu` / `Obnovit stavbu` pauses/resumes
  ground preparation or construction without cancelling the site.

Units and buildings have independent `enabled` flags. A specialist can work
only when both its own flag and its workplace's flag permit it. The inspector
explains a paused workplace separately: resuming its worker does **not** reopen
the building, and reopening the building does not override an individual pause.
Ownership, current selection and visibility are rechecked when an action runs;
a stale button callback cannot change a different newly selected object.

The buttons and thoughts share the existing inspector scroll area. Long
nutrition details remain accessible without widening the sidebar or covering
the bottom time controls.

## What a paused unit still does

An already-started visible step completes normally. A paused unit takes no new
productive task and performs no new pickup. Goods already in its hands remain
physical cargo: it can finish their delivery, including a carried soldier's
ration. If the destination is closed or unavailable, it redirects the load to
a valid destination or retains it while waiting; pausing does not erase cargo
or refund it remotely.

Without cargo or another personal need, a civilian walks back to its assigned
workplace; communal staff can use a completed Warehouse. It enters through the
real door and disappears only after going inside. A blocked route or doorway
causes waiting/retry, not teleportation. Without suitable accommodation it can
wait outdoors. Soldiers and unassigned guards do not gain a new civilian home.

Food seeking, an active meal and safe yielding remain possible.
Satiety and the long-term nutrition reserve continue to follow their normal
rules: **pausing work does not protect a unit from hunger or starvation**.
Workplace assignment is retained, and an idle paused citizen can still move
aside for someone whose route it blocks.

## What a paused building preserves

The building stops production, training, recruitment, trading and construction,
as applicable. It accepts no new input deliveries. Its existing output can
still be collected and carried elsewhere; closing a producer must not trap
already-produced goods inside it.

Inventories, order queues, assigned employee, construction/earthwork progress
and already-paid production or training are preserved. Resuming continues the
saved work without charging its ingredients or training cost twice. Pausing
does not remove a building, dismiss its employee, or make its workplace vacant.

A paused Inn admits no new diner and starts no additional course. Someone
already eating finishes **only the current paid course**, including its gradual
nutrition restoration, then leaves normally. Further courses require an open
supplied Inn. This differs from pausing just the diner's work, which does not
prevent that person from satisfying its food needs.

## Save compatibility

Save **v20** stores a strict boolean `enabled` on every worker and building.
Independent pauses survive loading alongside meals, cargo, needs and paid work.
Malformed flags are rejected transactionally without altering the live game.

Earlier save versions default both settings to `true`. The pause migration
does not refill satiety, consume stock or reset saved v19 nutrition debt and
fractional progress. Older nutrition migrations keep their existing rules;
introducing pause controls does not grant another food reserve.

## Implementation and verification

[ActivityControl](../game/scripts/simulation/activity_control.gd) owns pause
behavior; [UnitThoughts](../game/scripts/simulation/unit_thoughts.gd) provides
the read-only descriptions. [GameHud](../game/scripts/view/game_hud.gd) renders
the inspector, [MainView](../game/scripts/view/main_view.gd) validates targeted
commands, and [WorldSnapshot](../game/scripts/simulation/world_snapshot.gd)
preserves the new flags.

The feature adds **38 regression cases**: 12 activity-control, nine save,
ten thought-description and seven inspector/input cases. The last suite also
exercises actual mouse dispatch and the 900×720 scroll layout. Tests use
isolated worlds and temporary saves, never the player's current game.
Run `./tests/run-headless.sh` for the complete project scene; see the
[test record](../tests/README.md) for verification status.
