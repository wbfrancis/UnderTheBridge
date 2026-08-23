#!/usr/bin/env bash
# Opens the dedicated ticket #16 presentation review scene.
# Add --capture to write four focused PNGs and a validation report. Add --validate
# to run the lean suite before that evidence pass.
# Usage: tools/ticket16_presentation/run_review.sh [--godot-bin /path/to/Godot] [--capture|--validate]
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-}"
CAPTURE=false
VALIDATE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot-bin) GODOT_BIN="${2:?--godot-bin needs a path}"; shift 2 ;;
    --capture) CAPTURE=true; shift ;;
    --validate) CAPTURE=true; VALIDATE=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_godot_lib.sh"

GODOT_BIN="$(require_godot)"
SCENE="res://scenes/prototypes/ticket16_presentation_review.tscn"

if [[ "$CAPTURE" == true ]]; then
	ARTIFACT_DIR="$PROJECT_ROOT/artifacts/ticket16_presentation"
	mkdir -p "$ARTIFACT_DIR"
	if [[ "$VALIDATE" == true ]]; then
		"$PROJECT_ROOT/tools/test_headless.sh" --godot-bin "$GODOT_BIN"
	fi
	for STAGE in full_cast service_wing front_exit cultist_states; do
		"$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
			--rendering-method gl_compatibility "$SCENE" -- \
			"--stage=$STAGE" "--capture=res://artifacts/ticket16_presentation/${STAGE}.png"
	done
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" "$SCENE" -- \
		"--stage=full_cast" "--report=res://artifacts/ticket16_presentation/validation.json"
	REPORT="$ARTIFACT_DIR/validation.json"
	passed=""
	if command -v python3 >/dev/null 2>&1; then
		passed="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1])).get("passed", False)).lower())' "$REPORT" 2>/dev/null || echo "")"
	fi
	if [[ -z "$passed" ]]; then
		if grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' "$REPORT"; then passed="true"; else passed="false"; fi
	fi
	if [[ "$passed" != "true" ]]; then
		echo "Ticket #16 presentation validation reported a failure." >&2
		exit 1
	fi
	echo "Ticket #16 presentation evidence written to $ARTIFACT_DIR"
else
  "$GODOT_BIN" --path "$PROJECT_ROOT" --rendering-method gl_compatibility "$SCENE"
fi
