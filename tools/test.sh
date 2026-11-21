#!/bin/sh
# Imports the project (class names) and runs the headless tests; an optional filter picks tests by name
G=${GODOT:-/c/Tools/godot/Godot_v4.7.2-stable_win64_console.exe}
timeout 300 "$G" --headless --path . --import >/dev/null 2>&1
timeout 3000 "$G" --headless --path . --script tests/run_tests.gd -- $1 2>&1 | grep -vE "^\s*$|^Godot Engine|main.tscn"
