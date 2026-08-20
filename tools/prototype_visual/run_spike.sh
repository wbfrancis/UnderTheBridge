#!/usr/bin/env bash
# macOS/Linux equivalent of prototype_visual/run_spike.ps1
# Points Godot at Blender, imports assets, and renders the visual-spike frame.
# Usage: tools/prototype_visual/run_spike.sh [--godot-bin PATH] [--blender-bin PATH]
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-}"
BLENDER_BIN="${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot-bin) GODOT_BIN="${2:?--godot-bin needs a path}"; shift 2 ;;
    --blender-bin) BLENDER_BIN="${2:?--blender-bin needs a path}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_godot_lib.sh"

GODOT_BIN="$(require_godot)"
if [[ ! -x "$BLENDER_BIN" ]]; then
  echo "Blender executable not found: $BLENDER_BIN (pass --blender-bin <path> or set \$BLENDER_BIN)." >&2
  exit 1
fi

isolate_profile "$PROJECT_ROOT/.godot/visual_spike_profile"
export VISUAL_SPIKE_BLENDER_PATH="$BLENDER_BIN"

"$GODOT_BIN" --headless --editor --path "$PROJECT_ROOT" \
  --script res://tools/prototype_visual/set_blender_path.gd
"$GODOT_BIN" --editor --import --headless --path "$PROJECT_ROOT"
"$GODOT_BIN" --path "$PROJECT_ROOT" --rendering-method forward_plus -- \
  --capture=res://artifacts/prototype_visual/final_render.png

echo "Visual spike complete: $PROJECT_ROOT/artifacts/prototype_visual/final_render.png"
