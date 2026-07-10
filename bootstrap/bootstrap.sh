#!/bin/bash
set -euo pipefail
trap 'echo "Error on line $LINENO" >&2' ERR

# bootstrap.sh — Underboss Runtime bootstrap orchestrator
# Uses Runtime API (runtime/lib/) for all identity fields — no hardcoded names.
# v2.0.0

RUNTIME_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done
TARGET="${TARGET:-$RUNTIME_ROOT}"

source "${RUNTIME_ROOT}/runtime/lib/api.sh"

read -r STATE VERSION <<< "$(detect_state)"

if registry_exists; then MODE="NORMAL"; else MODE="DEGRADED"; fi

RUNTIME_NAME=$(registry_name 2>/dev/null || echo "Underboss")
RUNTIME_VERSION=$(registry_version 2>/dev/null || echo "2.0.0")
RUNTIME_CODENAME=$(registry_codename 2>/dev/null || echo "")
BOOTSTRAP_VERSION=$(registry_bootstrap_version 2>/dev/null || echo "2.0")

BANNER="$RUNTIME_NAME Runtime"
[ -n "$RUNTIME_CODENAME" ] && BANNER="$BANNER ($RUNTIME_CODENAME)"
BANNER="$BANNER $RUNTIME_VERSION"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║ ${BANNER}║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Target: ${TARGET}"
echo "Runtime version: ${VERSION:-$RUNTIME_VERSION}"
echo "Bootstrap Engine: $BOOTSTRAP_VERSION"
echo "Runtime mode: ${MODE:-unknown}"
echo ""

state_message "$STATE" "$VERSION"

if [ "$STATE" = "legacy" ]; then
  echo "→ Auto-upgrading from legacy layout..."
  if [ -d "$TARGET/.context/runtime" ]; then
    mkdir -p "$TARGET/docs/.runtime"
    git -C "$TARGET" mv .context/runtime/* docs/.runtime/ && git -C "$TARGET" rm -rf .context/runtime
    git -C "$TARGET" submodule absorbgitdirs 2>/dev/null || true
    echo " ✓ Layout upgraded."
  fi
fi

echo " → Creating directories from registry..."
if [ "$MODE" = "NORMAL" ]; then
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    mkdir -p "$TARGET/docs/$dir"
  done < <(registry_list_directories "docs")

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    mkdir -p "$TARGET/.context"
    [ -f "$TARGET/.context/$file" ] || touch "$TARGET/.context/$file"
  done < <(registry_list_directories "context")
else
  echo " ⚠ Runtime mode: DEGRADED (registry.yaml not found — using built-in fallback layout)"
  mkdir -p "$TARGET/docs/architecture" "$TARGET/docs/adr" "$TARGET/docs/specs/drafts" \
    "$TARGET/docs/specs/review" "$TARGET/docs/specs/approved" "$TARGET/docs/specs/implemented" \
    "$TARGET/docs/specs/superseded" "$TARGET/docs/audits" "$TARGET/docs/backlog" "$TARGET/docs/api"
fi

detect_all "$TARGET"

echo ""
echo "=== Generating from registry ==="
run_all_generators "$TARGET"

echo ""
echo "=== Registry ==="
echo " Agents: $(registry_list_agents | wc -l | tr -d ' ') roles"
echo " Contracts: $(registry_list_contracts runtime | wc -l | tr -d ' ') runtime + $(registry_list_contracts consumer | wc -l | tr -d ' ') consumer"
echo " Generators: $(registry_list_generators | wc -l | tr -d ' ')"
echo " Detectors: $(registry_list_detectors | wc -l | tr -d ' ')"
echo " Schemas: documentation/schemas/frontmatter.schema.json"

echo ""
echo "=== Checking components ==="
components_verify || true
