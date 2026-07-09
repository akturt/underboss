#!/bin/bash
set -euo pipefail
trap 'echo "Error on line $LINENO" >&2' ERR

# bootstrap.sh — naprolom Documentation System Runtime bootstrap orchestrator
# v1.8 — Uses Runtime API (runtime/lib/) for all operations.
#         No hardcoded paths, no awk/grep/sed parsing.
#
# Usage: ./bootstrap.sh [--target <path>]

RUNTIME_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done
TARGET="${TARGET:-$RUNTIME_ROOT}"

# --- Source Runtime API (unified internal SDK) ---
source "${RUNTIME_ROOT}/runtime/lib/api.sh"

# --- Detect state ---
read -r STATE VERSION <<< "$(detect_state)"

# --- Determine runtime mode (NORMAL when registry.yaml is present) ---
if registry_exists; then MODE="NORMAL"; else MODE="DEGRADED"; fi

# --- Print header ---
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  naprolom Documentation System Runtime           ║"
echo "║  Runtime API — Bootstrap v1.8                    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Target: ${TARGET}"
echo "Runtime version: ${VERSION}"
echo "Bootstrap Engine: $(yaml_get "${RUNTIME_ROOT}/runtime/registry.yaml" "bootstrap.engine_version" 2>/dev/null || echo unknown)"
echo "Runtime mode: ${MODE:-unknown}"
echo ""

# --- State messages ---
state_message "$STATE" "$VERSION"

# --- Auto-upgrade ---
if [ "$STATE" = "legacy" ]; then
  echo "→ Auto-upgrading from legacy layout..."
  if [ -d "$TARGET/.context/runtime" ]; then
    mkdir -p "$TARGET/docs/.runtime"
    git -C "$TARGET" mv .context/runtime/* docs/.runtime/ && git -C "$TARGET" rm -rf .context/runtime
    git -C "$TARGET" submodule absorbgitdirs 2>/dev/null || true
    echo "  ✓ Layout upgraded."
  fi
fi

# --- Create directories from registry ---
echo "  → Creating directories from registry..."
if [ "$MODE" = "NORMAL" ]; then
  # Read directory paths from registrydirectories.docs
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    mkdir -p "$TARGET/docs/$dir"
  done < <(registry_list_directories "docs")

  # .context stubs
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    mkdir -p "$TARGET/.context"
    [ -f "$TARGET/.context/$file" ] || touch "$TARGET/.context/$file"
  done < <(registry_list_directories "context")
else
  # DEGRADED mode: registry.yaml absent — use built-in fallback layout.
  echo "  ⚠ Runtime mode: DEGRADED (registry.yaml not found — using built-in fallback layout)"
  mkdir -p "$TARGET/docs/architecture" "$TARGET/docs/adr" "$TARGET/docs/specs/drafts" \
           "$TARGET/docs/specs/review" "$TARGET/docs/specs/approved" "$TARGET/docs/specs/implemented" \
           "$TARGET/docs/specs/superseded" "$TARGET/docs/audits" "$TARGET/docs/backlog" "$TARGET/docs/api"
fi

# --- Detect stack ---
detect_all "$TARGET"

# --- Run generators from registry ---
echo ""
echo "=== Generating from registry ==="
run_all_generators "$TARGET"

# --- Registry summary ---
echo ""
echo "=== Registry ==="
echo "  Agents:          $(registry_list_agents | wc -l | tr -d ' ') roles"
echo "  Contracts:       $(registry_list_contracts runtime | wc -l | tr -d ' ') runtime + $(registry_list_contracts consumer | wc -l | tr -d ' ') consumer"
echo "  Generators:      $(registry_list_generators | wc -l | tr -d ' ')"
echo "  Detectors:       $(registry_list_detectors | wc -l | tr -d ' ')"
echo "  Schemas:         documentation/schemas/frontmatter.schema.json"

# --- Verify ---
echo ""
echo "=== Checking components ==="
components_verify || true
