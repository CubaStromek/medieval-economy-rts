# Inns and military food deliveries

Implemented on **2026-09-05**. This extends the existing food economy: citizens
visit an Inn automatically; soldiers receive a physical ration from a Carrier
after the player requests supplies.

## Playing

- Build **Inn** in the **Food** construction category. It costs **6 planks and
  5 stone**, requires a Builder and actual material deliveries, and opens only
  after construction. It needs no permanent employee.
- Produce Bread, Sausages, Wine or Fish. Carriers deliver these to the Inn using
  the existing building logistics. The input buffer holds six of each food.
- Hungry civilians, including carriers, builders, production specialists and
  tower recruits, find a reachable supplied Inn with an available seat. They
  normally finish their existing work/delivery before taking a meal. Nightly
  rest can defer unfinished cargo: a resting civilian can still visit the Inn
  while retaining that cargo for its next work period.
- Click a soldier's visible sprite to select that particular unit, then choose
  **Supply food**. Alternatively open **Military → Supply army** to request food
  for all eligible soldiers. Requests are available strictly below **55%**
  condition and cannot be duplicated while a previous request is pending.
- A request remains pending when supplies or carriers are unavailable. When a
  route and food are available, a Carrier collects one physical ration from a
  Warehouse or a producer and delivers it beside the soldier. The soldier does
  not visit the Inn. Every food type restores the soldier to full condition.

The Inn has a visible table/food sign and its inspector shows current seating
and individual diners. Outdoor units have a colored satiety bar. Selecting a
unit shows its percentage, hunger state and estimated game time until hunger;
workplace details also expose the assigned worker's satiety while it is indoors.
During meals the inspector shows the current course and its progress. The
population display separates citizens from soldiers and reports food arriving.
Recruits posted in Watchtowers remain civilians: they eat at Inns and retain
their exclusive tower assignment.

## Civilian meals

There are **six simultaneous diners**, independently from inventory capacity.
Seats are acquired on arrival. A civilian whose target becomes full or empty
tries another Inn; failed searches retry after a short delay. Permanently
blocked routes release their selected food destination and allow another choice.

One visit consumes up to **three different food types**, in catalog order:
Bread → Wine → Sausages → Fish. This is a project extension of the KaM model
to support bread, wine and a protein course together. Restoration remains
**40% for bread, 30% for wine, 60% for sausage and 50% for fish**, capped at
maximum condition. Once a citizen reaches the 90% threshold, it does not take
another serving. A single available food provides only one serving per visit.

Each serving is withdrawn **when its course starts**. Its nutrition is applied
progressively over **116 simulation ticks** (11.6 seconds at 1× or 23.2 seconds
at the default 0.5×). Only then does the diner select a different available
food; later deliveries can therefore become its next course. A three-course
visit takes 34.8 seconds at 1× or 69.6 seconds at 0.5×. The unit disappears
inside the Inn and continuously occupies one seat throughout the visit.
Hunger is paused while eating. On completion it releases its seat and exits through
the door, and resumes work. A specialist retains the same workplace throughout;
its production does not operate without it. An idle person also leaves the Inn
when no work is available.

Nightly rest does not prevent hungry civilians from eating. They can leave
their sleeping place for food, then return to sleep until the workday resumes.

The implementation uses the existing indoor-unit system. Seating, temporary
indoor presence and permanent workplace ownership are three separate concepts.

## Military logistics and conservation

Food requests are manual, matching the original KaM control model. There is no
automatic replenishment toggle in this implementation. The current prototype's
soldiers do not yet have combat or formation commands; supplying their positions
does not imply those systems have been implemented.

Each pending soldier receives at most one carrier assignment. Before collection,
the carrier reserves a real available food unit at its source. Ordinary delivery
tasks cannot take that same reserved unit; existing ordinary pickups are also
considered when selecting a military offer. Requested hungry soldiers are
considered before less hungry ones, with stable ID ordering for ties.

The food is removed from the source **only at physical pickup**. It then exists
in the carrier's cargo until a valid adjacent handoff. Food is never taken from
an Inn's input inventory for the army. A road is helpful but not mandatory: a
valid walkable route and valid adjacent interaction are required.

If the recipient moves, the carrier can update its route after completing its
visible step. If the recipient disappears or becomes unreachable, the carrier
keeps the ration and returns it through ordinary physical logistics; there is
no remote refund. A missing source cancels a pickup, but cannot erase an already
collected ration. A pending order can subsequently obtain a different offer.

Existing starvation remains: a unit at zero condition dies. Reservations held
by a dead carrier disappear with its assignment, and a dead soldier's delivery
is released in the same world tick. As before, cargo carried by a unit that
itself dies is lost. A hungry carrier still completes an already committed
delivery before seeking its own meal.

## Timing and saves

Hunger now follows the **6000-tick game day**. The loss per ten ticks is derived
from a target of at most 0.8 days from full condition to hunger, rounded upward
to whole condition points. Current values give **five points per ten ticks**.
Maximum condition is 2700, new-unit condition is 1620, and food seeking begins
at 360 (13.3%). A warning appears at 50% and the critical state at 120 (4.4%).
The same hunger clock applies to civilians and soldiers; military supply
eligibility remains a separate threshold below 55%.

A full unit becomes hungry after **18 h 43 min of game time**. A new unit starts
seeking food after **10 h 05 min** (4.2 real minutes at 1×, 8.4 at 0.5×), plus
any remaining work, travel or queue. From the usual hunger threshold, wine alone
raises satiety to roughly 43% and buys 6 h 29 min until hunger; fish reaches 63%
and buys 10 h 48 min. Bread + wine + fish fills the unit. These durations exclude
the time spent eating, when hunger does not decrease. Pause and game speed affect
food and calendar together; no separate wall-clock timer advances either system.

Save **v14** introduced progressive courses; the current v15 sleep schema
retains these feeding fields:

- `meal_ticks_left`: remaining ticks of the current course;
- `meal_course`: current food, duration, nutrition, already applied nutrition
  and distinct foods eaten during this visit;
- `food_requested`: a soldier's pending order;
- `ration_delivery`: the carrier's recipient, source, food type and pickup/delivery phase.

Loading does not eat food, complete a handoff, or withdraw a reserved ration.
An active meal resumes its exact integer nutrition curve, and a carrier reconstructs
its route on the next simulation tick. V13 meals had already applied all nutrition:
they finish their old countdown without receiving or consuming anything again,
including after another v14 save. Older saves default the new fields without
granting food or inventing orders. Historical soldiers inside an Inn leave
through the existing door behavior.

Validation rejects invalid role/meal combinations, excess diners, impossible
source reservations, duplicate carrier claims, mismatched in-flight cargo,
duplicate courses and impossible partial nutrition.
Validation occurs in a staged world, preserving the live game on rejection.

## Implementation and verification

The behavior is split between [InnFeeding](../game/scripts/simulation/inn_feeding.gd)
and [SoldierFoodSupply](../game/scripts/simulation/soldier_food_supply.gd), integrated
through [SimulationWorld](../game/scripts/simulation/simulation_world.gd) and
[WorldSnapshot](../game/scripts/simulation/world_snapshot.gd). The existing Inn
catalog ID is preserved; a second overlapping building type is not introduced.

Dedicated regression suites cover meals and seats, physical military shipments,
save/load conservation and corruption, and actual HUD commands. The existing
production, workplace, indoor movement, rendering and save suites remain part
of the full verification. Daily hunger, visible satiety and progressive courses
have dedicated regression cases as well. Run the project test scene through
`./tests/run-headless.sh`; inspect both the final result and GDScript errors.
The food integration run on 2026-09-05 passed **401/401 cases**, before the
separate night-schedule suites were registered. Native previews verified the
[map bars](previews/hunger-map-satiety.png),
[ongoing meal](previews/hunger-eating-progress.png) and
[Inn diners](previews/hunger-inn-diners.png).

Reference behavior and alternative future directions remain documented in the
[earlier food-system analysis](unit-food-system-analysis.md). Its proposed
meal reservations before arrival, automatic army supply,
emergency eating with cargo, and field kitchens are not enabled by this change.
