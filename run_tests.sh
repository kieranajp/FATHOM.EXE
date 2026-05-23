#!/usr/bin/env bash
# Convenience wrapper for the GUT suite. Exit code propagates from Godot,
# so `./run_tests.sh && echo OK` works as expected in CI/git hooks.
set -euo pipefail
exec godot --headless --path "$(dirname "$0")" --script addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
