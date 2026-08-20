#!/usr/bin/env bash
# macOS/Linux equivalent of service_slice/run_slice.ps1
# Imports, runs tests (unless --skip-tests), writes the validation report,
# and captures the four service stages (unless --skip-capture).
# Usage: tools/service_slice/run_slice.sh [--godot-bin PATH] [--skip-tests] [--skip-capture]
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
isolate_profile "$PROJECT_ROOT/.godot/service_slice_profile"

"$GODOT_BIN" --headless --editor --import --path "$PROJECT_ROOT"

if [[ "$SKIP_TESTS" -eq 0 ]]; then
  "$GODOT_BIN" --headless --path "$PROJECT_ROOT" \
    -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
fi

SCENE="res://scenes/slices/service_action_queue_slice.tscn"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" "$SCENE" -- \
  "--stage=served" "--report=res://artifacts/service_action_queue/validation.json"

if [[ "$SKIP_CAPTURE" -eq 0 ]]; then
  for STAGE in queued carried served failed; do
    "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
      --rendering-method gl_compatibility "$SCENE" -- \
      "--stage=$STAGE" "--capture=res://artifacts/service_action_queue/service_${STAGE}.png"
  done
fi

echo "Service Action Queue slice complete. Evidence: $PROJECT_ROOT/artifacts/service_action_queue"
