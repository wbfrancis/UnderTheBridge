#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCENE="res://scenes/prototypes/avatar_motion_review.tscn"
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/avatar_motion"
mkdir -p "$ARTIFACT_DIR"

for SCALE in 1 2 4; do
	"$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
		--rendering-method gl_compatibility "$SCENE" -- \
		"--scale=$SCALE" "--capture=$ARTIFACT_DIR/${SCALE}x.png" --frames=90
done

"$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
	--rendering-method gl_compatibility "$SCENE" -- \
	--scale=1 --paused "--capture=$ARTIFACT_DIR/paused.png" --frames=90

"$GODOT_BIN" --headless --path "$PROJECT_ROOT" "$SCENE" -- \
	--scale=1 "--report=$ARTIFACT_DIR/validation.json"

grep -Eq '"passed"[[:space:]]*:[[:space:]]*true' "$ARTIFACT_DIR/validation.json"
echo "Avatar motion review written to $ARTIFACT_DIR"
