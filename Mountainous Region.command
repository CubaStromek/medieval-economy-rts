#!/bin/zsh
set -eu

# Open only the optional landscape; never change the default project scene.
map_project_dir="${0:A:h}"
map_engine="$(command -v godot || true)"
if [[ -z "$map_engine" ]]; then
  for map_candidate in /opt/homebrew/bin/godot /usr/local/bin/godot /Applications/Godot.app/Contents/MacOS/Godot; do
    if [[ -x "$map_candidate" ]]; then
      map_engine="$map_candidate"
      break
    fi
  done
fi
if [[ -z "$map_engine" ]]; then
  print -u2 'Godot nebyl nalezen. Otevřete scénu game/scenes/mountainous_region.tscn v Godotu a spusťte ji klávesou F6.'
  exit 1
fi
exec "$map_engine" --path "$map_project_dir/game" res://scenes/mountainous_region.tscn
