#!/bin/sh
# Runs the sandbox's logic test, but first loads the map once and stops at any
# script error (a parse error would make the test hang). For Linux / the cloud.
cd "$(dirname "$0")/../.."
errors=$(timeout 60 godot --headless --path . --quit-after 30 sandbox/sandbox.tscn 2>&1 | grep -E "SCRIPT ERROR|Parse Error")
if [ -n "$errors" ]; then
	echo "$errors"
	exit 1
fi
timeout 600 godot --headless --fixed-fps 60 --path . -s sandbox/tests/test_sandbox.gd 2>&1 | grep -E "PASS|FAIL|ALL|SCRIPT ERROR|^  "
