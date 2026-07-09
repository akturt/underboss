#!/bin/bash
# bootstrap/lib/verify.sh — Post-bootstrap component verification
#
# Reads expected directories from registry, checks existence in target.

verify_components() {
  local all_ok=1
  local docs_root="${TARGET}/docs"

  echo ""
  echo "=== Checking components ==="

  if registry_exists; then
    # Check directories from registry
    local dirs
    dirs=$(awk '/^directories:/,/^[a-z]/' "$REGISTRY" | grep "path:" | sed 's/.*path:[[:space:]]*//')

    for d in $dirs; do
      if [ -d "${docs_root}/${d}" ]; then
        echo "  ✓ ${d}"
      else
        echo "  ✗ ${d} (missing)"
        all_ok=0
      fi
    done

    # Check .context stubs
    local context_dirs
    context_dirs=$(awk '/^  context:/,/^[a-z]/' "$REGISTRY" | grep "path:" | sed 's/.*path:[[:space:]]*//')

    for f in $context_dirs; do
      if [ -f "${TARGET}/.context/${f}" ]; then
        echo "  ✓ .context/${f}"
      else
        echo "  ✗ .context/${f} (missing)"
        all_ok=0
      fi
    done
  else
    # Fallback checks
    for f in "${TARGET}/.context/project.yml" "${TARGET}/.context/boundaries.yml" \
             "${TARGET}/docs/backlog/" "${TARGET}/docs/audits/" "${TARGET}/docs/specs/review/"; do
      if [ -e "$f" ]; then
        echo "  ✓ $(basename "$f")"
      else
        echo "  ✗ $(basename "$f") (missing)"
        all_ok=0
      fi
    done
  fi

  echo ""
  if [ "$all_ok" -eq 1 ]; then
    echo "✓ All checks passed."
  else
    echo "⚠ Some checks failed."
  fi

  return $all_ok
}
