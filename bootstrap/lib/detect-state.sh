#!/bin/bash
# bootstrap/lib/detect-state.sh — State + version detection
#
# Reads filesystem to determine installation state.
# Output: "state version" (e.g., "installed 1.5")

detect_install_state() {
  local state="fresh"
  local version="none"

  if [ -d "$TARGET/.context/runtime/naprolom-docs" ] || [ -d "$TARGET/.context/runtime" ]; then
    state="legacy"
    version="1.0"
  elif [ -d "$TARGET/docs/.runtime/naprolom-docs" ]; then
    local runtime_dir="$TARGET/docs/.runtime/naprolom-docs"
    local missing=0

    # Check all composition.core directories exist
    for dir in documentation bootstrap agents knowledge sops; do
      if [ ! -d "$runtime_dir/$dir" ]; then
        missing=1
        break
      fi
    done

    if [ "$missing" -eq 1 ]; then
      state="partial"
    else
      state="installed"
    fi

    # Detect version from registry
    if [ -f "$runtime_dir/runtime/registry.yaml" ]; then
      version=$(grep 'version:' "$runtime_dir/runtime/registry.yaml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
      [ -z "$version" ] && version="1.5"
    else
      version="1.1"
    fi
  fi

  echo "$state $version"
}

# get_state_message — user-facing message for current state
get_state_message() {
  local state="$1" version="$2"
  case "$state" in
    legacy)
      echo "⚠ Legacy layout detected (.context/runtime/)."
      echo "  To migrate: git mv .context/runtime docs/.runtime && git submodule absorbgitdirs"
      ;;
    broken)
      echo "⚠ Runtime integrity compromised. Re-bootstrapping."
      ;;
    partial)
      echo "⚠ Some Runtime components missing. Re-bootstrapping."
      ;;
    installed)
      echo "→ Runtime v${version} already installed. Running idempotent re-bootstrap."
      ;;
  esac
}
