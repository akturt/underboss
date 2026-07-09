#!/bin/bash
# bootstrap/install.sh
#
# One-liner installer for Documentation System Runtime v1.4.
# Usage: bash <(curl -s https://raw.githubusercontent.com/akturt/naprolom-docs/master/bootstrap/install.sh)
#
# Or clone + run:
#   git clone --depth 1 https://github.com/akturt/naprolom-docs.git /tmp/naprolom-docs
#   bash /tmp/naprolom-docs/bootstrap/install.sh

set -eu

REPO_URL="https://github.com/akturt/naprolom-docs.git"
SUBMODULE_PATH="docs/.runtime/naprolom-docs"

# Detect project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$PROJECT_ROOT" ]; then
  echo "ERROR: not inside a git repository. Run from your project root." >&2
  exit 1
fi

echo "→ Project: $PROJECT_ROOT"

# Check if Runtime already installed
if [ -f "$PROJECT_ROOT/$SUBMODULE_PATH/runtime/registry.yaml" ]; then
  echo "→ Runtime v1.4 already installed. Running bootstrap..."
  bash "$PROJECT_ROOT/$SUBMODULE_PATH/bootstrap/bootstrap.sh" "$PROJECT_ROOT"
  exit 0
fi

# Check for v1.0 layout
if [ -d "$PROJECT_ROOT/.context/runtime" ]; then
  echo "→ Legacy v1.0 layout detected. Run migration first:"
  echo "  bash <(curl -s ...)  # with migration flag"
  echo "  Or follow: https://github.com/akturt/naprolom-docs/blob/master/bootstrap/DEPLOY-PROMPT.md"
  exit 1
fi

# Fresh install
echo "→ Installing Runtime v1.4..."

# Ensure docs/.runtime exists
mkdir -p "$PROJECT_ROOT/docs/.runtime"

# Check if submodule already exists at path
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

# Run bootstrap
echo "→ Running bootstrap..."
bash "$PROJECT_ROOT/$SUBMODULE_PATH/bootstrap/bootstrap.sh" "$PROJECT_ROOT"

echo ""
echo "✅ Installation complete."
echo ""
echo "Next steps:"
echo "  1. Fill .context/project.yml with your project metadata"
echo "  2. Complete docs/architecture/entity-catalog.md"
echo "  3. Create your first ADR"
echo ""
echo "Commit with:"
echo "  git add -A && git commit -m 'docs: install Documentation System Runtime v1.4'"
