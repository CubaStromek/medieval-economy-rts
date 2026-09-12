# Worker housing

The project adds a compact **Workers' Cottage** for Carriers and Builders. Each
cottage has two sleeping places. A residence assignment is separate from the
unit's workplace, so a resident can continue carrying goods or constructing
elsewhere during the working day and return to the cottage at night.

At the start of the 20:00–05:00 rest period, an eligible citizen chooses the
nearest reachable completed and enabled cottage owned by the same player. Bed
assignments reserve capacity immediately, so a third citizen cannot enter a
two-person cottage while its first two residents are still walking home. If no
bed is free, a completed owned Warehouse remains available as overflow shelter.
Closing an occupied cottage releases its assignments when the night schedule
next evaluates its residents and moves them to another valid cottage or the
Warehouse fallback.

The cottage uses an authored 2 × 2 project footprint with its occupied door in
the south row. It costs **3 Planks + 2 Stone** and takes the standard 120
construction ticks. These values are project balance choices; the building is
not presented as an original Knights and Merchants house.

Its warm windows, chimney, flower boxes and stacked firewood distinguish it
from production workshops. The inspector reports occupied beds against the
two-resident capacity.

Residence ownership is saved on each worker through the existing
`sleep_home_id` field. This keeps current save version 20 compatible while
validating role, ownership and the two-bed limit during loading.
