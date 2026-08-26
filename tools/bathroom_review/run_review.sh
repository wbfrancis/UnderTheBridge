#!/usr/bin/env bash
# Renders the Bathroom Visit and Trapdoor review: a Patron at each station with its
# Emote Progress fill, then a standing capture through the open panels, the close,
# and the empty room after removal. Frames land at 1280x720, 1024x576, and 1920x1080.
# Usage: tools/bathroom_review/run_review.sh [--godot-bin /path/to/Godot]
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
SCENE="res://scenes/prototypes/ticket16_presentation_review.tscn"
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/bathroom_review"
mkdir -p "$ARTIFACT_DIR"

# Each mode runs from a fresh Night so the two Companions never contaminate each
# other's frames through the missing-Companion Suspicion clock.
for MODE in capture visit; do
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    "--bathroom-mode=$MODE" \
    "--bathroom-report=res://artifacts/bathroom_review/validation_${MODE}.json"
  REPORT="$ARTIFACT_DIR/validation_${MODE}.json"
  if ! grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' "$REPORT"; then
    echo "Bathroom review validation ($MODE) reported a failure." >&2
    exit 1
  fi
done
echo "Bathroom review evidence written to $ARTIFACT_DIR"
