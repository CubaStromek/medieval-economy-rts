# Sawmill operation state checks — 2026-09-12

The focused `sawmill_operation_runner.tscn` passed **12/12** checks on Godot
4.7.2. The adjacent `state-adapter-tests.txt` is the actual clean headless log.
This suite is also registered in the required full test runner.

The checks exercise the unchanged simulation and the normal MainView:

- Every input 0–4/output 0–6 combination; catalog capacities and overflow remain
  separate from actual quantities. Carried cargo and unrelated storage do not
  populate these racks.
- A real carrier picks up and delivers a log, then collects an output plank.
  The input appears on delivery and the output disappears at pickup.
- A real resident consumes one input at batch start, keeps one separate
  workpiece for 60 productive ticks, then produces exactly two output planks.
- Personal pause, building pause and night retain the paid workpiece and batch
  progress, show no working pose, and resume without consuming another input.
- Repeated samples interpolate only an observed productive interval. A first
  observation, unseen gap, batch change, world replacement or rewind snaps to
  saved progress. Rendering leaves world data and nutritional effort unchanged.
- A real weakened worker advances 24 of 30 ticks; each of its six skipped ticks
  holds the same animation progress at every fractional sample.
- Foreign fog returns unknown before invalid sentinel inventory/batch values or
  the resident are read. An unattended legacy recipe cannot invent a carpenter.
- Frame boundaries map to the agreed six cycles per batch. Unknown or inactive
  operators have no working pose.
- The actual Main scene observes all five steps in a fast frame and interpolates
  only the last interval. Global pause preserves the fractional pose. Loading
  the same tick into the same World object resets stale interpolation through
  the normal save/load path.

These are state and integration checks. They do not by themselves verify the
new artwork's registration, alpha, occlusion or appearance in the native game.
