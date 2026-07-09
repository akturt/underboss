#!/bin/bash
# bootstrap/lib/detect-stack.sh — Stack detection orchestrator
#
# Loads registry detectors, runs them, merges results.
# Falls back to simple lockfile scan if no detectors available.

detect_stack() {
  local has_backend=0 has_database=0 has_infra=0

  if registry_exists; then
    # Plugin-based detection: iterate detectors from registry
    local detector_names
    detector_names=$(list_detectors 2>/dev/null)

    for name in $detector_names; do
      local detector_path
      detector_path=$(get_detector_path "$name" 2>/dev/null)
      [ -z "$detector_path" ] && continue

      # Resolve relative to RUNTIME_ROOT
      local full_path="${RUNTIME_ROOT}/${detector_path}"
      [ -f "$full_path" ] || continue

      # Source the detector and capture output
      local result
      result=$( (
        source "$full_path"
        detect
      ) )

      local b d i
      IFS='|' read -r b d i <<< "$result"

      [ -n "$b" ] && { BACKEND="$b"; has_backend=1; }
      [ -n "$d" ] && { DATABASE="$d"; has_database=1; }
      [ -n "$i" ] && { INFRASTRUCTURE="$i"; has_infra=1; }
    done
  fi

  # Fallback: simple lockfile-based detection
  if [ "$has_backend" -eq 0 ]; then
    if [ -f "$TARGET/package.json" ]; then
      BACKEND="Node.js"
    elif [ -f "$TARGET/pyproject.toml" ] || [ -f "$TARGET/requirements.txt" ]; then
      BACKEND="Python"
    elif [ -f "$TARGET/go.mod" ]; then
      BACKEND="Go"
    elif [ -f "$TARGET/Cargo.toml" ]; then
      BACKEND="Rust"
    elif [ -f "$TARGET/composer.json" ]; then
      BACKEND="PHP"
    elif [ -f "$TARGET/package.json" ] && [ -f "$TARGET/vite.config.ts" -o -f "$TARGET/vite.config.js" ]; then
      BACKEND="Vite"
    fi
  fi
}
