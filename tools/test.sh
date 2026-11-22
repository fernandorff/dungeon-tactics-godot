#!/bin/sh
# Imports the project (class names) and runs the headless tests; an optional filter picks tests by name
G=${GODOT:-/c/Tools/godot/Godot_v4.7.2-stable_win64_console.exe}
log=$(mktemp) || exit 1
trap 'rm -f "$log"' EXIT

# Godot can log a broken script during import and still exit successfully.
run_godot() {
    seconds=$1
    shift
    timeout "$seconds" "$G" --headless --path . "$@" >"$log" 2>&1
    status=$?
    if [ "$status" -ne 0 ] || grep -Eq 'SCRIPT ERROR|Parse Error|ERROR:' "$log"; then
        cat "$log" >&2
        [ "$status" -ne 0 ] && return "$status"
        return 1
    fi
}

run_godot 300 --import || exit $?
run_godot 3000 --script tests/run_tests.gd -- "$@" || exit $?
grep -vE '^[[:space:]]*$|^Godot Engine' "$log"
