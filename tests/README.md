# Tests

Run `./tests/run-headless.sh` from the repository root. The launcher loads
`game/project.godot` and runs `res://tests/test_runner.tscn`; it does not execute
GDScript in isolated `--script` mode.

The runner reports 50 cases: the original 34 plus dedicated suites in
`game/tests/` for worker movement, save validation, shared grid configuration,
viewport input and economy invariants. Input tests dispatch real viewport
events; movement tests use full simulation ticks. The invariant suite advances
two economies for 3,000 ticks each and checks resumed JSON snapshots.

Validated with Godot 4.6.1. When inspecting a run, check for GDScript parse/runtime
errors as well as the final result; the Windows certificate-store warning in a
restricted environment is unrelated to these local tests.
