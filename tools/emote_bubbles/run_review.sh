#!/usr/bin/env bash
# Writes the rendered Emote Bubble review PNGs in icon-only and accessible-text
# modes at 1x, 4x, and pause.
# Usage: tools/emote_bubbles/run_review.sh [--godot-bin /path/to/Godot]
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
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/emote_bubbles"
mkdir -p "$ARTIFACT_DIR"

capture() {
  local name="$1"; shift
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    --stage=full_cast --capture-frames=1800 "$@" \
    "--capture=res://artifacts/emote_bubbles/${name}.png"
}

capture icons_1x --emote-play=1
capture icons_paused --emote-play=0
capture labels_1x --emote-play=1 --emote-labels
capture labels_4x --emote-play=4 --emote-labels
capture labels_scaled --emote-play=1 --emote-labels --emote-scale=1.5

echo "Emote Bubble review captures written to $ARTIFACT_DIR"
