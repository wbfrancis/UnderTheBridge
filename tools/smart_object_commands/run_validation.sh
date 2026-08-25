#!/usr/bin/env bash
# Runs the command contracts and the production-scene smart-object command check.
# Usage: tools/smart_object_commands/run_validation.sh [--godot-bin /path/to/Godot]
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
isolate_profile "$PROJECT_ROOT/.godot/headless_profile"
"$PROJECT_ROOT/tools/test_headless.sh" --godot-bin "$GODOT_BIN"

for SCALE in 1 4; do
  REPORT="validation_${SCALE}x.json"
  "$GODOT_BIN" --headless --fixed-fps=60 --path "$PROJECT_ROOT" \
    res://scenes/prototypes/ticket16_presentation_review.tscn -- \
    --stage=full_cast \
    "--movement-scale=$SCALE" \
    "--command-report=res://artifacts/smart_object_commands/$REPORT"
  if ! grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' \
    "$PROJECT_ROOT/artifacts/smart_object_commands/$REPORT"; then
    echo "Smart-object command validation failed at ${SCALE}x." >&2
    exit 1
  fi
  if ! grep -Eq '"step_count"[[:space:]]*:[[:space:]]*7' \
    "$PROJECT_ROOT/artifacts/smart_object_commands/$REPORT"; then
    echo "Smart-object command validation ran the wrong step count at ${SCALE}x." >&2
    exit 1
  fi
done

echo "Smart-object command validation passed at 1x and 4x for all seven steps."
