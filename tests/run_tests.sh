#!/bin/sh
# Compiles the project's Structured Text with STruC++ (OpenPLC Editor v4's
# compiler) and runs the unit tests in tests/ on the host. The ESP32-C3
# C/C++ I/O blocks are replaced by the stubs in tests/host/.
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
  $root/datatypes/TESTER_STATE.dt
  $root/datatypes/TESTER_CONFIG.dt
  $root/tests/host/io_stubs.st
  $root/tests/host/cell_sim.st
  $root/pous/functions/nextSampleTime.st
  $root/pous/function-blocks/MS_CLOCK.st
  $root/pous/function-blocks/STATUS_LED.st
  $root/pous/function-blocks/CELL_CLASSIFIER.st
  $root/pous/function-blocks/CELL_TEST.st
  $root/pous/programs/main.st
"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# STruC++ takes .st files, so concatenate into one.
for f in $sources; do
  cat "$f"
  echo
done > "$work/project.st"

cd "$work"
$strucpp project.st --test "$root"/tests/test_*.st
