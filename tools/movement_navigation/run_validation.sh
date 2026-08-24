#!/usr/bin/env bash
# Runs the movement contracts and the production-scene navigation check.
# Usage: tools/movement_navigation/run_validation.sh [--godot-bin /path/to/Godot]
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
"$GODOT_BIN" --headless --fixed-fps=60 --path "$PROJECT_ROOT" \
  res://scenes/prototypes/ticket16_presentation_review.tscn -- \
  --stage=full_cast \
  --movement-report=res://artifacts/movement_navigation/validation.json

if ! grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' \
  "$PROJECT_ROOT/artifacts/movement_navigation/validation.json"; then
  echo "Movement navigation validation failed." >&2
  exit 1
fi

echo "Movement navigation validation passed."
