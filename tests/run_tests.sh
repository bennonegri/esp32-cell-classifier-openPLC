#!/bin/sh
# Compiles the project's Structured Text with STruC++ (OpenPLC Editor v4's
# compiler) and runs the unit tests in tests/ on the host. The ESP32-C3
# C/C++ I/O blocks are replaced by the stubs in tests/host/.
#
# main is ladder logic, so its tests run against the ST the editor
# transpiles it to: build the project in the editor first (any target), and
# this picks up build/*/src/program.st. Without a build, test_main.st is
# skipped.
#
#   tests/run_tests.sh [strucpp command]   (default: strucpp)
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
strucpp=${1:-strucpp}

# Data types first, ordered so each is declared before it is used.
sources="
  $root/datatypes/RGB.dt
  $root/datatypes/CELL_PROFILE.dt
  $root/datatypes/TEST_STATUS.dt
  $root/datatypes/TESTER_CONFIG.dt
  $root/tests/host/io_stubs.st
  $root/tests/host/cell_sim.st
  $root/pous/functions/nextSampleTime.st
  $root/pous/function-blocks/MS_CLOCK.st
  $root/pous/function-blocks/STATUS_LED.st
  $root/pous/function-blocks/CELL_CLASSIFIER.st
  $root/pous/function-blocks/CELL_TEST.st
"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# STruC++ takes .st files, so concatenate into one.
for f in $sources; do
  cat "$f"
  echo
done > "$work/project.st"

tests=$(ls "$root"/tests/test_*.st)
program=$(ls -t "$root"/build/*/src/program.st 2>/dev/null | head -n 1 || true)
if [ -n "$program" ] && [ "$program" -nt "$root/pous/programs/main.ld" ]; then
  echo "main: transpiled ladder from ${program#"$root"/}"
  awk '/^PROGRAM main$/,/^END_PROGRAM$/' "$program" >> "$work/project.st"
else
  echo "main: no editor build newer than main.ld, skipping test_main.st" >&2
  tests=$(echo "$tests" | grep -v '/test_main\.st$')
fi

cd "$work"
# shellcheck disable=SC2086
$strucpp project.st --test $tests
