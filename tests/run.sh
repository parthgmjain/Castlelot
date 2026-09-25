#!/bin/bash
# Runs the whole test suite headlessly.
#   tests/run.sh                 everything
#   tests/run.sh pawn            only files whose name contains "pawn"
#   tests/run.sh --seed=1234     reproduce a run (the seed is printed at the top)
# Set GODOT to use a different Godot binary.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1

# A fresh checkout has no class cache yet; build it once.
if [ ! -f .godot/global_script_class_cache.cfg ]; then
	"$GODOT" --headless --editor --quit-after 3 . > /dev/null 2>&1
fi

exec "$GODOT" --headless --path . -s res://tests/run_tests.gd -- "$@"
