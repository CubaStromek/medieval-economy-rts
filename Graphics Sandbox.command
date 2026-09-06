#!/bin/zsh
set -eu
sample_project_dir="${0:A:h}"
sample_engine="$(command -v godot || true)"
if [[ -z "$sample_engine" ]]; then
  for sample_candidate in /opt/homebrew/bin/godot /usr/local/bin/godot /Applications/Godot.app/Contents/MacOS/Godot; do
    if [[ -x "$sample_candidate" ]]; then
      sample_engine="$sample_candidate"
      break
    fi
  done
fi
if [[ -z "$sample_engine" ]]; then
  print -u2 'Otevřete game/scenes/terrain_graphics_sandbox.tscn v Godotu a spusťte scénu klávesou F6.'
  exit 1
fi
exec "$sample_engine" --path "$sample_project_dir/game" res://scenes/terrain_graphics_sandbox.tscn
