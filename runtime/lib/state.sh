#!/bin/bash
# runtime/lib/state.sh — Installation state detection
#
# Reads filesystem to determine state. Uses registry for version.
# Requires: runtime/lib/registry.sh

# detect_state → outputs "state version"
#   State: fresh | installed | partial | legacy | broken
#   Version: "x.y" from registry, or "none" if no registry
detect_state() {
  local state="fresh"
  local version="none"

  if [ -d "$TARGET/.context/runtime" ]; then
    state="legacy"
    version="1.0"
  elif registry_exists; then
    # Registry exists — check if all core directories are present
    state="installed"
    version=$(registry_version 2>/dev/null || echo "unknown")

    # Verify core directories from composition.core
    local runtime_dir
    runtime_dir=$(dirname "$RUNTIME_REGISTRY")
    for dir in bootstrap documentation agents knowledge sops; do
      if [ ! -d "$runtime_dir/$dir" ]; then
        state="partial"
        break
      fi
    done
  elif [ -d "$TARGET/docs/.runtime" ]; then
    # Has .runtime but no registry — partial v1.1 install
    state="partial"
    version="1.1"
  fi

  echo "$state $version"
}

# state_message <state> <version> — user-facing message
state_message() {
  local state="$1" version="$2"
  case "$state" in
    legacy)
      echo "  ⚠ Legacy layout detected (.context/runtime/)."
      echo "    To migrate: git mv .context/runtime docs/.runtime && git submodule absorbgitdirs"
      ;;
    broken)
      echo "  ⚠ Runtime integrity compromised. Re-bootstrapping."
      ;;
    partial)
      echo "  ⚠ Some Runtime components missing. Re-bootstrapping."
      ;;
    installed)
      echo "  → Runtime v${version} already installed. Running idempotent re-bootstrap."
      ;;
  esac
}
