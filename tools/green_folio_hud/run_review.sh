#!/usr/bin/env bash
# Writes the Green Folio Bottom HUD approval frames.
# Each frame opens one HUD state in the real presentation scene, so what the
# reviewer sees is the shipped HUD, not a mock-up.
# Usage: tools/green_folio_hud/run_review.sh [--godot-bin /path/to/Godot]
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
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_godot_lib.sh"

GODOT_BIN="$(require_godot)"
isolate_profile "$PROJECT_ROOT/.godot/headless_profile"
SCENE="res://scenes/prototypes/ticket16_presentation_review.tscn"
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/green_folio_hud"
mkdir -p "$ARTIFACT_DIR"

# Three seconds at the fixed rate lets the 4x review actors spread through the
# room without making the capture suite wait on a complete simulated visit.
FRAMES=180

capture() {
  local name="$1"; local frames="${2:-$FRAMES}"; shift 2
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility --resolution 1280x720 "$SCENE" -- \
    "--stage=full_cast" "--capture-frames=$frames" "--identify-patron=patron_june" \
    "$@" "--capture=res://artifacts/green_folio_hud/${name}.png"
}

capture night "$FRAMES"
capture running_1 60 --hud-preview=running_1
capture plain_pause_2 60 --hud-preview=plain_pause_2
capture escape_lock 60 --hud-preview=escape_lock
capture empty_queue 60 --hud-preview=empty_queue
capture long_queue 60 --hud-preview=long_queue
capture move_talk_chain 60 --hud-preview=move_talk_chain
capture chain_unrelated 60 --hud-preview=chain_unrelated
capture pause_from_plain 60 --hud-preview=pause_from_plain
capture inspected "$FRAMES" --inspect-patron=patron_june --hud-preview=quiet
capture action_queue "$FRAMES" --hud-preview=queue
capture settings_menu "$FRAMES" --hud-preview=settings
capture developer_menu "$FRAMES" --hud-preview=developer
capture clock_hover "$FRAMES" --hud-preview=clock_hover
capture speed_2 "$FRAMES" --hud-preview=speed_2
capture speed_4 "$FRAMES" --hud-preview=speed_4
capture offscreen_indicator "$FRAMES" --hud-preview=offscreen
capture pause_menu 60 --hud-preview=pause
capture outcome_success 60 --hud-preview=outcome_victory
capture outcome_failed 60 --hud-preview=outcome_failed
capture outcome_exposed 60 --hud-preview=outcome_exposed

capture_resolution() {
  local name="$1"; local resolution="$2"; shift 2
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility --resolution "$resolution" "$SCENE" -- \
    "--stage=full_cast" "--capture-frames=60" "--identify-patron=patron_june" \
    --inspect-patron=patron_june "$@" \
    "--capture=res://artifacts/green_folio_hud/${name}.png"
}

capture_resolution inspected_1024 1024x576 --hud-preview=quiet
capture_resolution inspected_1920 1920x1080 --hud-preview=quiet
capture_resolution plain_pause_2_1024 1024x576 --hud-preview=plain_pause_2
capture_resolution plain_pause_2_1920 1920x1080 --hud-preview=plain_pause_2
capture_resolution long_queue_1024 1024x576 --hud-preview=long_queue
capture_resolution long_queue_1920 1920x1080 --hud-preview=long_queue
capture_resolution move_talk_chain_1024 1024x576 --hud-preview=move_talk_chain
capture_resolution move_talk_chain_1920 1920x1080 --hud-preview=move_talk_chain

echo "Green Folio HUD approval frames written to $ARTIFACT_DIR"
