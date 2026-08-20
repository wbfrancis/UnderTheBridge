#!/usr/bin/env bash
# macOS/Linux equivalent of test_headless.ps1
# Imports the project headlessly, then runs the GUT contract suite.
# Usage: tools/test_headless.sh [--godot-bin /path/to/Godot]
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot-bin) GODOT_BIN="${2:?--godot-bin needs a path}"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_godot_lib.sh"

GODOT_BIN="$(require_godot)"
isolate_profile "$PROJECT_ROOT/.godot/headless_profile"

"$GODOT_BIN" --headless --editor --import --path "$PROJECT_ROOT"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
