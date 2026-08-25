#!/usr/bin/env bash
# Writes the rendered context-menu review PNGs for the smart-object commands.
# Usage: tools/smart_object_commands/run_review.sh [--godot-bin /path/to/Godot]
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot-bin) GODOT_BIN="${2:?--godot-bin needs a path}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_godot_lib.sh"

GODOT_BIN="$(require_godot)"
SCENE="res://scenes/prototypes/ticket16_presentation_review.tscn"
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/smart_object_commands"
mkdir -p "$ARTIFACT_DIR"

for TARGET in patron_june bar_work_position trapdoor_control; do
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    --stage=full_cast \
    --capture-frames=1800 \
    "--context-menu=$TARGET" \
    "--capture=res://artifacts/smart_object_commands/menu_${TARGET}.png"
done

echo "Smart-object command review captures written to $ARTIFACT_DIR"
