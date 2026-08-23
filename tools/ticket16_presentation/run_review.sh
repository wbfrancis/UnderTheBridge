#!/usr/bin/env bash
# Opens the dedicated ticket #16 presentation review scene.
# Add --capture to write a PNG and exit instead of opening an interactive window.
# Usage: tools/ticket16_presentation/run_review.sh [--godot-bin /path/to/Godot] [--capture]
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-}"
CAPTURE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot-bin) GODOT_BIN="${2:?--godot-bin needs a path}"; shift 2 ;;
    --capture) CAPTURE=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_godot_lib.sh"

GODOT_BIN="$(require_godot)"
SCENE="res://scenes/prototypes/ticket16_presentation_review.tscn"

if [[ "$CAPTURE" == true ]]; then
  ARTIFACT_DIR="$PROJECT_ROOT/artifacts/ticket16_prototype"
  mkdir -p "$ARTIFACT_DIR"
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    "--capture=res://artifacts/ticket16_prototype/review_scene.png"
  echo "Ticket #16 review capture written to $ARTIFACT_DIR/review_scene.png"
else
  "$GODOT_BIN" --path "$PROJECT_ROOT" --rendering-method gl_compatibility "$SCENE"
fi
