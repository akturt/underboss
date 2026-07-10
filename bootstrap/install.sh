#!/bin/bash
# bootstrap/install.sh
#
# One-liner installer for Underboss Runtime.
# Uses the Runtime API (runtime/lib/api.sh) to read all paths and versions
# from registry.yaml — no grep/sed/awk parsing of the registry.
#
# Usage: bash <(curl -s https://raw.githubusercontent.com/akturt/underboss/master/bootstrap/install.sh)

set -eu

REPO_URL="https://github.com/akturt/underboss.git"

# Detect project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$PROJECT_ROOT" ]; then
  echo "ERROR: not inside a git repository. Run from your project root." >&2
  exit 1
fi

echo "→ Project: $PROJECT_ROOT"

# Candidate locations of the Runtime submodule
SUBMODULE_CANDIDATES=("docs/.runtime/underboss" ".context/runtime/underboss")

# Load the unified Runtime API for a given runtime root.
load_api() {
  RUNTIME_ROOT="$1"
  # shellcheck disable=SC1090
  source "${RUNTIME_ROOT}/runtime/lib/api.sh"
}

RUNTIME_DIR=""
for candidate in "${SUBMODULE_CANDIDATES[@]}"; do
  if [ -f "$PROJECT_ROOT/$candidate/runtime/registry.yaml" ]; then
    RUNTIME_DIR="$PROJECT_ROOT/$candidate"
    break
  fi
done

if [ -n "$RUNTIME_DIR" ]; then
  load_api "$RUNTIME_DIR"
  RUNTIME_NAME=$(registry_name 2>/dev/null || echo "Underboss")
  VERSION=$(registry_version 2>/dev/null || echo "unknown")
  BOOTSTRAP_PATH=$(registry_entrypoint "bootstrap")
  BOOTSTRAP_PATH="${BOOTSTRAP_PATH:-bootstrap/bootstrap.sh}"
  echo "→ ${RUNTIME_NAME} v${VERSION:-unknown} already installed. Running bootstrap..."
  bash "$RUNTIME_DIR/$BOOTSTRAP_PATH" "$PROJECT_ROOT"
  exit 0
fi

# Check for legacy v1.0 layout (old underboss path)
if [ -d "$PROJECT_ROOT/.context/runtime" ]; then
  echo "→ Legacy v1.0 layout detected. Upgrade to Underboss v2.0 first:"
  echo " See https://github.com/akturt/underboss/blob/master/bootstrap/DEPLOY-PROMPT.md (Step B or C)"
  exit 1
fi

# Fresh install
echo "→ Installing Underboss Runtime..."

# Ensure docs/.runtime exists
mkdir -p "$PROJECT_ROOT/docs/.runtime"

SUBMODULE_PATH="docs/.runtime/underboss"

if [ -d "$PROJECT_ROOT/$SUBMODULE_PATH" ]; then
  echo "→ Submodule directory exists. Updating..."
  cd "$PROJECT_ROOT"
  git submodule update --init --recursive
else
  echo "→ Adding submodule..."
  cd "$PROJECT_ROOT"
  git submodule add "$REPO_URL" "$SUBMODULE_PATH"
  git config -f .gitmodules submodule."$SUBMODULE_PATH".branch master
fi

# Read bootstrap entrypoint from the freshly installed registry via Runtime API
if [ -f "$PROJECT_ROOT/$SUBMODULE_PATH/runtime/registry.yaml" ]; then
  load_api "$PROJECT_ROOT/$SUBMODULE_PATH"
  RUNTIME_NAME=$(registry_name 2>/dev/null || echo "Underboss")
  VERSION=$(registry_version 2>/dev/null || echo "unknown")
  BOOTSTRAP_PATH=$(registry_entrypoint "bootstrap")
  BOOTSTRAP_PATH="${BOOTSTRAP_PATH:-bootstrap/bootstrap.sh}"
else
  BOOTSTRAP_PATH="bootstrap/bootstrap.sh"
fi

# Run bootstrap
echo "→ Running bootstrap..."
bash "$PROJECT_ROOT/$SUBMODULE_PATH/$BOOTSTRAP_PATH" "$PROJECT_ROOT"

echo ""
echo "✅ Installation complete."
echo ""
echo "Next steps:"
echo " 1. Fill .context/project.yml with your project metadata"
echo " 2. Complete docs/architecture/README.md"
echo " 3. Create your first ADR"
echo ""
echo "Commit with:"
echo " git add -A && git commit -m 'docs: install Underboss Runtime'"
