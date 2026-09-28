#!/bin/bash
# usage: tools/dev/autotest.sh [project_dir] [screenshot_prefix] [headless]
# Plays solo through scripts/world/autotest.gd. With "headless" it only runs the logic (fast);
# otherwise it renders on the software GPU and saves <prefix>_street.png, _dialog, _zoom, _night,
# _nation, _case, _paper (2-4 minutes on llvmpipe). Prints SCRIPT ERRORs and the autotest summary.
P=$(cd "${1:-$(dirname "$0")/../..}" && pwd)
OUT=${2:-/tmp/famiglia}
if [ "$3" = "headless" ]; then
  timeout 200 godot --headless --path "$P" res://scenes/main.tscn -- --autotest > "$OUT.log" 2>&1
else
  timeout 600 xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --resolution 1600x900 --path "$P" res://scenes/main.tscn -- --autotest --shot="$OUT" > "$OUT.log" 2>&1
fi
grep -E "SCRIPT ERROR|at: .*res://|shot |AUTOTEST|^  |heat=" "$OUT.log" | head -80
