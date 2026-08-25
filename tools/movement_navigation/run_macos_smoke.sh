#!/usr/bin/env bash
# Exports the current main scene as a local unsigned macOS app and starts it headlessly.
# Usage: tools/movement_navigation/run_macos_smoke.sh [--godot-bin /path/to/Godot]
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
APP_PATH="$PROJECT_ROOT/builds/macos/UnderTheBridge.app"
EXECUTABLE="$APP_PATH/Contents/MacOS/Under the Bridge Prototype"

mkdir -p "$PROJECT_ROOT/builds/macos"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-debug macOS "$APP_PATH"
if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Packaged macOS executable is missing." >&2
  exit 1
fi

"$EXECUTABLE" --headless --quit-after 5
echo "Packaged macOS smoke check passed."
