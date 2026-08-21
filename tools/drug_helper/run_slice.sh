#!/usr/bin/env bash
# macOS/Linux equivalent of drug_helper/run_slice.ps1
# Runs lean tests, captures the five drug/helper stages, writes a validation report,
# and fails if the report's "passed" flag is not true.
# Usage: tools/drug_helper/run_slice.sh [--godot-bin /path/to/Godot]
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
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/drug_helper"
mkdir -p "$ARTIFACT_DIR"

"$PROJECT_ROOT/tools/test_headless.sh" --godot-bin "$GODOT_BIN"

isolate_profile "$PROJECT_ROOT/.godot/drug_helper_profile"

SCENE="res://scenes/slices/drug_helper_slice.tscn"
for STAGE in prepare_and_collapse helper_carry rescue_chance rescue_success rescue_failure; do
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    "--stage=$STAGE" "--capture=res://artifacts/drug_helper/${STAGE}.png"
done

"$GODOT_BIN" --headless --path "$PROJECT_ROOT" "$SCENE" -- \
  "--stage=prepare_and_collapse" "--report=res://artifacts/drug_helper/validation.json"

REPORT="$ARTIFACT_DIR/validation.json"
passed=""
if command -v python3 >/dev/null 2>&1; then
  passed="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1])).get("passed", False)).lower())' "$REPORT" 2>/dev/null || echo "")"
fi
if [[ -z "$passed" ]]; then
  if grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' "$REPORT"; then passed="true"; else passed="false"; fi
fi
if [[ "$passed" != "true" ]]; then
  echo "Drug & Helper validation checks reported a failure." >&2
  exit 1
fi

echo "Drug & Helper evidence written to $ARTIFACT_DIR"
