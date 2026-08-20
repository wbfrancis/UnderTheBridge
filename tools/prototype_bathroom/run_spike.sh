#!/usr/bin/env bash
# macOS/Linux equivalent of prototype_bathroom/run_spike.ps1
# Imports, runs tests (unless --skip-tests), writes the validation report,
# and captures evidence (unless --skip-capture).
# Usage: tools/prototype_bathroom/run_spike.sh [--godot-bin PATH] [--skip-tests] [--skip-capture]
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-}"; SKIP_TESTS=0; SKIP_CAPTURE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot-bin) GODOT_BIN="${2:?--godot-bin needs a path}"; shift 2 ;;
    --skip-tests) SKIP_TESTS=1; shift ;;
    --skip-capture) SKIP_CAPTURE=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_godot_lib.sh"

GODOT_BIN="$(require_godot)"
isolate_profile "$PROJECT_ROOT/.godot/bathroom_spike_profile"

"$GODOT_BIN" --headless --editor --import --path "$PROJECT_ROOT"

if [[ "$SKIP_TESTS" -eq 0 ]]; then
  "$GODOT_BIN" --headless --path "$PROJECT_ROOT" \
    -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
fi

SCENE="res://scenes/prototypes/bathroom_danger_spike.tscn"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" "$SCENE" -- \
  "--stage=investigation" "--report=res://artifacts/bathroom_danger_chain/validation.json"

if [[ "$SKIP_CAPTURE" -eq 0 ]]; then
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    "--stage=investigation" "--capture=res://artifacts/bathroom_danger_chain/bathroom_danger_chain.png"
fi

echo "Bathroom danger-chain spike complete. Evidence: $PROJECT_ROOT/artifacts/bathroom_danger_chain"
