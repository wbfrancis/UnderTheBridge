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

# The Patrons need time to walk in, so every frame runs the same settle budget.
FRAMES=720

capture() {
  local name="$1"; shift
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    "--stage=full_cast" "--capture-frames=$FRAMES" "--identify-patron=patron_june" \
    "$@" "--capture=res://artifacts/green_folio_hud/${name}.png"
}

capture night
capture inspected --inspect-patron=patron_june
capture action_queue --hud-preview=queue
capture settings_menu --hud-preview=settings
capture developer_menu --hud-preview=developer
capture pause_menu --hud-preview=pause
capture outcome_success --hud-preview=outcome_victory
capture outcome_failed --hud-preview=outcome_failed
capture outcome_exposed --hud-preview=outcome_exposed

echo "Green Folio HUD approval frames written to $ARTIFACT_DIR"
