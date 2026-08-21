#!/usr/bin/env bash
# macOS/Linux equivalent of capture_chain/run_slice.ps1
# Runs lean tests, captures the five capture-chain stages, writes a validation report,
# and fails if the report's "passed" flag is not true.
# Usage: tools/capture_chain/run_slice.sh [--godot-bin /path/to/Godot]
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
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/capture_chain"
mkdir -p "$ARTIFACT_DIR"

"$PROJECT_ROOT/tools/test_headless.sh" --godot-bin "$GODOT_BIN"

isolate_profile "$PROJECT_ROOT/.godot/capture_chain_profile"

SCENE="res://scenes/slices/capture_chain_slice.tscn"
for STAGE in trapdoor_capture seated_witness missing_investigation escape_intercept front_exit_defeat; do
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    "--stage=$STAGE" "--capture=res://artifacts/capture_chain/${STAGE}.png"
done

"$GODOT_BIN" --headless --path "$PROJECT_ROOT" "$SCENE" -- \
  "--stage=trapdoor_capture" "--report=res://artifacts/capture_chain/validation.json"

REPORT="$ARTIFACT_DIR/validation.json"
passed=""
if command -v python3 >/dev/null 2>&1; then
  passed="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1])).get("passed", False)).lower())' "$REPORT" 2>/dev/null || echo "")"
fi
if [[ -z "$passed" ]]; then
  # Fallback: no python3 available, scan the raw JSON.
  if grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' "$REPORT"; then passed="true"; else passed="false"; fi
fi
if [[ "$passed" != "true" ]]; then
  echo "Capture-chain validation checks reported a failure." >&2
  exit 1
fi

echo "Capture-chain evidence written to $ARTIFACT_DIR"
