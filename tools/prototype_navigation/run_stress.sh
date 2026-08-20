#!/usr/bin/env bash
# macOS/Linux equivalent of prototype_navigation/run_stress.ps1
# Imports, runs the navigation stress sim at one or more scales, then captures evidence.
# Usage: tools/prototype_navigation/run_stress.sh [--godot-bin PATH]
#          [--duration SECONDS] [--scales "1 4"] [--capture-only] [--skip-capture]
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-}"; DURATION=600; SCALES="1 4"; CAPTURE_ONLY=0; SKIP_CAPTURE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot-bin) GODOT_BIN="${2:?--godot-bin needs a path}"; shift 2 ;;
    --duration) DURATION="${2:?--duration needs a number}"; shift 2 ;;
    --scales) SCALES="${2:?--scales needs a space-separated list}"; shift 2 ;;
    --capture-only) CAPTURE_ONLY=1; shift ;;
    --skip-capture) SKIP_CAPTURE=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_godot_lib.sh"

GODOT_BIN="$(require_godot)"
isolate_profile "$PROJECT_ROOT/.godot/navigation_spike_profile"

SCENE="res://scenes/prototypes/navigation_reservation_spike.tscn"

"$GODOT_BIN" --headless --editor --import --path "$PROJECT_ROOT"

if [[ "$CAPTURE_ONLY" -eq 0 ]]; then
  for SCALE in $SCALES; do
    "$GODOT_BIN" --headless --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync "$SCENE" -- \
      "--stress-scale=$SCALE" "--stress-duration=$DURATION" \
      "--report=res://artifacts/navigation_reservations/stress_${SCALE}x.json"
  done
fi

if [[ "$SKIP_CAPTURE" -eq 0 ]]; then
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    "--stress-scale=4" "--stress-duration=120" "--capture-at=75" \
    "--capture=res://artifacts/navigation_reservations/navigation_reservations.png"
fi

echo "Navigation stress spike complete. Evidence: $PROJECT_ROOT/artifacts/navigation_reservations"
