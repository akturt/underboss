#!/bin/bash
set -euo pipefail
trap 'echo "Error on line $LINENO" >&2' ERR

# bootstrap.sh — naprolom Documentation System Runtime bootstrap orchestrator
# v1.5 — Decomposed: lib modules + generator scripts. Reads all paths from registry.
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

# --- Source lib modules ---
source "${RUNTIME_ROOT}/bootstrap/lib/registry.sh"
source "${RUNTIME_ROOT}/bootstrap/lib/detect-state.sh"
source "${RUNTIME_ROOT}/bootstrap/lib/detect-stack.sh"
source "${RUNTIME_ROOT}/bootstrap/lib/verify.sh"

# --- Source generators ---
for gen in "${RUNTIME_ROOT}"/bootstrap/generators/*.sh; do
  [ -f "$gen" ] && source "$gen"
done

# --- Detect state ---
read -r STATE VERSION <<< "$(detect_install_state)"

# --- Detect stack ---
BACKEND="" DATABASE="" INFRASTRUCTURE="" PROJECT_NAME="" STACK="" DOMAIN=""
detect_stack
STACK="${BACKEND:-unknown}"
DOMAIN="${DOMAIN:-unknown}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$TARGET")}"

# --- Print header ---
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  naprolom Documentation System Runtime           ║"
echo "║  Module Decomposition — Bootstrap v1.5           ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Target: ${TARGET}"
echo "Runtime version: ${VERSION}"
echo ""

# --- State messages ---
get_state_message "$STATE" "$VERSION"

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

# --- Create docs/ skeleton ---
echo "  → Ensuring docs/ skeleton..."
for dir in documentation agents knowledge sops; do
  mkdir -p "$TARGET/docs/$dir"
done
mkdir -p "$TARGET/docs/architecture" "$TARGET/docs/adr" "$TARGET/docs/specs/drafts" \
         "$TARGET/docs/specs/review" "$TARGET/docs/specs/approved" "$TARGET/docs/specs/implemented" \
         "$TARGET/docs/specs/superseded" "$TARGET/docs/audits" "$TARGET/docs/backlog" "$TARGET/docs/api"

# --- Generate components ---
echo ""
echo "=== Generating from registry ==="

generate_architecture_readme "$TARGET" "$STACK" "$DOMAIN" "$PROJECT_NAME" "$BACKEND" "$DATABASE" "$INFRASTRUCTURE"
generate_boundaries "$TARGET" "$DOMAIN" "$PROJECT_NAME"
generate_project_yml "$TARGET" "$STACK" "$DOMAIN" "$PROJECT_NAME" "$BACKEND" "$DATABASE" "$INFRASTRUCTURE"
generate_claude_md "$TARGET"
generate_ci_workflow "$TARGET"

# --- Registry summary ---
echo ""
echo "=== Registry ==="
echo "  Agents:          $(extract_section agents components | wc -w | tr -d ' ') roles"
echo "  Contracts:       $(extract_nested contracts runtime | wc -w | tr -d ' ') runtime + $(extract_nested contracts consumer | wc -w | tr -d ' ') consumer"
echo "  Validators:      $(list_generators | wc -w | tr -d ' ') validators"
echo "  Schemas:         documentation/schemas/frontmatter.schema.json"

# --- Verify ---
verify_components
