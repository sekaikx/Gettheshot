#!/bin/bash
# usage: tools/dev/test_all.sh [project_dir]
# Headless: compiles every script, then plays the autotest, the tutorial test and the favor test.
# Prints one line per check and exits non-zero if any failed. Run it before every commit.
P=$(cd "${1:-$(dirname "$0")/../..}" && pwd)
T=${TMPDIR:-/tmp}/famiglia_test_$$
fail=0
run() {  # name, pass-pattern, args...
  local name=$1 pat=$2; shift 2
  timeout 180 godot --headless --path "$P" "$@" > "$T.$name.log" 2>&1
  local errs=$(grep -c -E "SCRIPT ERROR|Parse Error" "$T.$name.log")
  if grep -q -E "$pat" "$T.$name.log" && [ "$errs" = "0" ]; then
    echo "PASS $name"
  else
    echo "FAIL $name ($errs script errors) -> $T.$name.log"
    grep -E "SCRIPT ERROR|Parse Error|at: res|FAIL" "$T.$name.log" | head -8
    fail=1
  fi
}
run scripts "CHECK OK" res://tools/dev/check_scripts.tscn
run autotest "AUTOTEST OK" res://scenes/main.tscn -- --autotest
run tutorial "TUTTEST OK" res://scenes/main.tscn -- --autotest --tuttest
run favors "FAVORTEST OK" res://scenes/main.tscn -- --autotest --favortest
exit $fail
