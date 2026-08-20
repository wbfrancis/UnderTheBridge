#!/usr/bin/env bash
# macOS/Linux equivalent of ordinary_visit/run_slice.ps1
# Runs focused tests, captures the four visit stages, and writes a validation report.
# Usage: tools/ordinary_visit/run_slice.sh [--godot-bin /path/to/Godot]
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
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/ordinary_arrival_group"
mkdir -p "$ARTIFACT_DIR"

"$PROJECT_ROOT/tools/test_headless.sh" --godot-bin "$GODOT_BIN"

isolate_profile "$PROJECT_ROOT/.godot/ordinary_visit_profile"

SCENE="res://scenes/slices/ordinary_visit_slice.tscn"
for STAGE in served bathroom debug departed; do
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    "--stage=$STAGE" "--capture=res://artifacts/ordinary_arrival_group/ordinary_${STAGE}.png"
done

"$GODOT_BIN" --headless --path "$PROJECT_ROOT" "$SCENE" -- \
  "--stage=departed" "--report=res://artifacts/ordinary_arrival_group/validation.json"

echo "Ordinary Arrival Group evidence written to $ARTIFACT_DIR"
