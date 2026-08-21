#!/usr/bin/env bash
# macOS/Linux runner for the perception greybox 3-D view.
# Captures one PNG per scenario stage so the spatial view can be reviewed without
# opening the editor. Open the scene with F6 in Godot for the interactive version.
# Usage: tools/perception_greybox/run_scene.sh [--godot-bin /path/to/Godot]
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
ARTIFACT_DIR="$PROJECT_ROOT/artifacts/perception_greybox"
mkdir -p "$ARTIFACT_DIR"

isolate_profile "$PROJECT_ROOT/.godot/perception_greybox_profile"

SCENE="res://scenes/prototypes/perception_greybox.tscn"
for STAGE in line_of_sight room_hearing unattended_body companion debug_trace; do
  "$GODOT_BIN" --path "$PROJECT_ROOT" --fixed-fps=60 --disable-vsync \
    --rendering-method gl_compatibility "$SCENE" -- \
    "--stage=$STAGE" "--capture=res://artifacts/perception_greybox/${STAGE}.png"
done

echo "Perception greybox captures written to $ARTIFACT_DIR"
