# shellcheck shell=bash
# Shared helpers for the macOS/Linux Godot runners.
# Mirrors the Godot-resolution and profile-isolation logic in the .ps1 runners.

# resolve_godot: prints the Godot executable path, or returns 1 if none found.
# Honors $GODOT_BIN, then PATH, then common macOS install locations.
resolve_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then printf '%s\n' "$GODOT_BIN"; return 0; fi
  local c p
  for c in godot godot4 Godot; do
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  for p in \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "/Applications/Godot_mono.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot_mono.app/Contents/MacOS/Godot"; do
    if [[ -x "$p" ]]; then printf '%s\n' "$p"; return 0; fi
  done
  return 1
}

# require_godot: resolve or exit 1 with a helpful message. Prints the path.
require_godot() {
  local bin
  if ! bin="$(resolve_godot)"; then
    echo "Godot was not found. Pass --godot-bin <path>, set \$GODOT_BIN, or add 'godot' to PATH." >&2
    exit 1
  fi
  printf '%s\n' "$bin"
}

# isolate_profile <dir>: redirect Godot editor data into an isolated profile
# directory so automated runs never touch the interactive editor profile.
# macOS Godot uses XDG_* when set, otherwise ~/Library/Application Support,
# so we set HOME and the XDG vars together for full isolation.
isolate_profile() {
  local root="$1"
  mkdir -p "$root/data" "$root/config" "$root/cache"
  export HOME="$root"
  export XDG_DATA_HOME="$root/data"
  export XDG_CONFIG_HOME="$root/config"
  export XDG_CACHE_HOME="$root/cache"
}
