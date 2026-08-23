#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR="$SCRIPT_DIR/../game"

godot --headless --path "$PROJECT_DIR" --scene res://tests/test_runner.tscn
