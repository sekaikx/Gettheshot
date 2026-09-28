#!/bin/bash
# usage: tools/dev/mptest.sh [project_dir]  -- host + 2 clients on this machine, headless.
P=$(cd "${1:-$(dirname "$0")/../..}" && pwd)
T=/tmp/famiglia_mp_$$
(timeout 80 godot --headless --path "$P" res://scenes/main.tscn -- --autohost --players=3 --mptest --name=Alex --family=Vitale > $T.host 2>&1 &)
sleep 3
(timeout 75 godot --headless --path "$P" res://scenes/main.tscn -- --autojoin=127.0.0.1 --mptest --name=Jess --family=OHara > $T.c2 2>&1 &)
timeout 72 godot --headless --path "$P" res://scenes/main.tscn -- --autojoin=127.0.0.1 --mptest --name=Marco --family=Russo > $T.c1 2>&1
sleep 5
grep -h -E "MPTEST|SCRIPT ERROR" $T.host $T.c1 $T.c2
