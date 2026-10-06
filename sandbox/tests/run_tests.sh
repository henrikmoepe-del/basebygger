#!/bin/sh
# Runs the sandbox's logic test, but first loads the map once and stops at any
# script error (a parse error would make the test hang). For Linux / the cloud.
cd "$(dirname "$0")/../.."
errors=$(timeout 60 godot --headless --path . --quit-after 30 sandbox/sandbox.tscn 2>&1 | grep -E "SCRIPT ERROR|Parse Error")
if [ -n "$errors" ]; then
	echo "$errors"
	exit 1
fi
out=$(timeout 600 godot --headless --fixed-fps 60 --path . -s sandbox/tests/test_sandbox.gd 2>&1 | grep -E "PASS|FAIL|ALL|SCRIPT ERROR|^  ")
echo "$out"
# Exit 0 only when every check passed.
echo "$out" | grep -q "ALL PASSED"
status=$?
# The input test needs a window: with xvfb (the cloud) run it too.
if [ $status -eq 0 ] && command -v xvfb-run >/dev/null 2>&1; then
	inp=$(timeout 180 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s sandbox/tests/test_input.gd 2>&1 | grep -E "PASS|FAIL|ALL|SCRIPT ERROR")
	echo "$inp"
	echo "$inp" | grep -q "ALL PASSED" || status=1
fi
exit $status
