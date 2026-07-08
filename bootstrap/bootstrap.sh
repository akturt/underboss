#!/bin/bash
# bootstrap/bootstrap.sh
#
# Minimal Documentation System Runtime bootstrap.
# Creates docs/ skeleton + .context/ stubs + drops a CLAUDE.md snippet into the
# consumer repository. No magic, no templates written into the project — the
# templates live inside the engine/ subdirectory (engine/templates/) and are referenced by path.
#
# Run from the ROOT of the consumer project, not from inside the submodule.
# It auto-detects the submodule path if invoked from inside it.
#
# v1.1 (D-BR): submodule resides inside docs/.runtime/naprolom-docs/, not .context/runtime/.
# v1.2: registry-driven universal loader. Reads runtime/registry.yaml for component discovery.
#       State detection via runtime/state-machine.yaml states (filesystem-based).
#
# Usage:
#   bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
#   bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh /path/to/project
#
# Idempotent: re-running is safe, existing files are preserved.

set -eu

# Resolve consumer project root:
#  - first positional arg, OR
#  - git toplevel of current cwd, OR
#  - 3 levels up from this script (default submodule path docs/.runtime/naprolom-docs)
TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  TARGET=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
fi
if [ -z "$TARGET" ]; then
  DIR="$(cd "$(dirname "$0")" && pwd)"
  TARGET="$(cd "$DIR/../../.." && pwd)"
fi

# Locate the runtime (submodule) root: directory that contains this script's parent.
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_ROOT="$(cd "$SELF_DIR/.." && pwd)"

echo "→ Target project:  $TARGET"
echo "→ Runtime root:    $RUNTIME_ROOT"
echo ""

# ─── v1.2: Read registry (minimal YAML key extraction) ───────────────────────

REGISTRY="$RUNTIME_ROOT/runtime/registry.yaml"
if [ ! -f "$REGISTRY" ]; then
  echo "⚠ WARNING: runtime/registry.yaml not found. Falling back to hardcoded paths." >&2
  REGISTRY=""
fi

# extract_registry_list <key>
# Extracts a flat list from registry.yaml under a given key.
# Works for: knowledge, sops, validators, templates (top-level lists).
# For nested keys like contracts.runtime, use extract_registry_nested.
extract_registry_list() {
  local key="$1"
  if [ -z "$REGISTRY" ] || [ ! -f "$REGISTRY" ]; then
    return
  fi
  awk "/^  ${key}:/,/^[^ ]/" "$REGISTRY" | grep "^    - " | sed 's/^    - //'
}

# extract_registry_nested <section> <subsection>
# Extracts list from nested YAML like contracts.runtime or contracts.consumer.
extract_registry_nested() {
  local section="$1"
  local subsection="$2"
  if [ -z "$REGISTRY" ] || [ ! -f "$REGISTRY" ]; then
    return
  fi
  awk "/^  ${section}:/,/^  [a-z]/" "$REGISTRY" | awk "/^    ${subsection}:/,/^    [a-z]/" | grep "^      - " | sed 's/^      - //'
}

# ─── v1.2: State + version detection (unified) ─────────────────────────────

# detect_install_state
# Returns: "fresh", "legacy", "partial", "installed"
# Side effect: sets GLOBAL_VERSION to "none", "1.0", "1.1", "1.2"
detect_install_state() {
  local state="fresh"
  GLOBAL_VERSION="none"

  # Check for legacy v1.0 layout
  if [ -d "$TARGET/.context/runtime/naprolom-docs" ] || [ -d "$TARGET/.context/runtime" ]; then
    state="legacy"
    GLOBAL_VERSION="1.0"
  # Check for v1.1+ layout
  elif [ -d "$TARGET/docs/.runtime/naprolom-docs" ]; then
    local runtime_dir="$TARGET/docs/.runtime/naprolom-docs"
    # Check if all expected components exist
    local missing=0
    for dir in engine bootstrap agents knowledge sops; do
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
    # Detect version
    if [ -f "$runtime_dir/runtime/registry.yaml" ]; then
      GLOBAL_VERSION="1.2"
    else
      GLOBAL_VERSION="1.1"
    fi
  fi

  echo "$state"
}

CURRENT_STATE=$(detect_install_state)
CURRENT_VERSION="$GLOBAL_VERSION"
echo "→ Current state:  $CURRENT_STATE"
echo "→ Current version: $CURRENT_VERSION"

# State machine transitions (from runtime/state-machine.yaml):
#   fresh     → bootstrap → installed
#   installed → git-submodule-update → updated
#   installed → manual-edit → broken
#   partial   → bootstrap → installed
#   legacy    → migration → installed
#   broken    → re-bootstrap → installed

# ─── v1.2: Auto-upgrade v1.1 → v1.2 ──────────────────────────────────────

if [ "$CURRENT_STATE" = "installed" ] && [ "$CURRENT_VERSION" = "1.1" ]; then
  echo "→ v1.1 detected. Attempting auto-upgrade to v1.2..." >&2

  RUNTIME_DIR="$TARGET/docs/.runtime/naprolom-docs"
  if [ -d "$RUNTIME_DIR/.git" ] || [ -f "$RUNTIME_DIR/.git" ]; then
    # Submodule exists — pull latest
    echo "  Pulling latest submodule..." >&2
    (
      cd "$RUNTIME_DIR" && git pull origin master 2>/dev/null
    )
    # Verify v1.2 components exist after pull
    if [ -f "$RUNTIME_DIR/runtime/registry.yaml" ]; then
      echo "  v1.2 components found. Upgrade complete." >&2
      CURRENT_VERSION="1.2"
      GLOBAL_VERSION="1.2"
    else
      echo "  WARNING: Submodule updated but v1.2 components still missing." >&2
      echo "  Manual intervention may be required:" >&2
      echo "    cd $TARGET" >&2
      echo "    git submodule update --remote --merge" >&2
      echo "    bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh" >&2
    fi
  else
    echo "  Submodule directory exists but is not a git repo." >&2
    echo "  To upgrade: re-add submodule at v1.2" >&2
  fi
  echo ""
fi

case "$CURRENT_STATE" in
  legacy)
    echo "⚠ Legacy layout detected (.context/runtime/)." >&2
    echo "  To migrate: git mv .context/runtime docs/.runtime && git submodule absorbgitdirs" >&2
    echo "  Bootstrap continues with advisory mode." >&2
    echo ""
    ;;
  broken)
    echo "⚠ Runtime integrity compromised. Re-bootstrapping." >&2
    echo ""
    ;;
  partial)
    echo "⚠ Some Runtime components missing. Re-bootstrapping." >&2
    echo ""
    ;;
  installed)
    if [ "$CURRENT_VERSION" = "1.2" ]; then
      echo "→ Runtime v1.2 already installed. Running idempotent re-bootstrap." >&2
      echo ""
    fi
    ;;
esac

# v1.1 (D-BR): advisory check — warn if .gitmodules still points to old v1.0 path.
if [ -f "$TARGET/.gitmodules" ]; then
  if grep -q "\.context/runtime/naprolom-docs" "$TARGET/.gitmodules" 2>/dev/null; then
    echo "⚠ WARNING: .gitmodules references legacy v1.0 path '.context/runtime/naprolom-docs'." >&2
    echo "  v1.1 expects submodule mounted at 'docs/.runtime/naprolom-docs'." >&2
    echo "  To migrate: git mv .context/runtime docs/.runtime && git submodule absorbgitdirs" >&2
    echo "  (Advisory only — bootstrap continues.)" >&2
    echo ""
  fi
fi

# ─── 1. docs/ skeleton (5 layer model). .gitkeep for empty dirs. ─────────────

mkdir -p "$TARGET/docs/architecture" \
         "$TARGET/docs/adr" \
         "$TARGET/docs/specs/drafts" \
         "$TARGET/docs/specs/review" \
         "$TARGET/docs/specs/approved" \
         "$TARGET/docs/specs/implemented" \
         "$TARGET/docs/specs/superseded" \
         "$TARGET/docs/audits" \
         "$TARGET/docs/backlog" \
         "$TARGET/docs/api"
touch "$TARGET/docs/architecture/.gitkeep" \
      "$TARGET/docs/adr/.gitkeep" \
      "$TARGET/docs/audits/.gitkeep" \
      "$TARGET/docs/backlog/.gitkeep" \
      "$TARGET/docs/api/.gitkeep"

# 1b. Entity catalog template (v1.2) — copy if missing, consumer completes it.
ENTITY_CATALOG="$TARGET/docs/architecture/entity-catalog.md"
ENTITY_CATALOG_TEMPLATE="$RUNTIME_ROOT/bootstrap/templates/entity-catalog.md"
if [ ! -f "$ENTITY_CATALOG" ] && [ -f "$ENTITY_CATALOG_TEMPLATE" ]; then
  cp "$ENTITY_CATALOG_TEMPLATE" "$ENTITY_CATALOG"
  echo "→ Created docs/architecture/entity-catalog.md (template — fill in your domain entities)"
fi

# ─── 2. .context/ — AI agent entry metadata (stubs; user fills them in). ─────

mkdir -p "$TARGET/.context"

if [ ! -f "$TARGET/.context/project.yml" ]; then
  cat > "$TARGET/.context/project.yml" << 'YML'
project:
  name: TODO-project-name
  description: "TODO: 1-sentence project description"
  domain: example.com
  maintainer: team-name
  repository: TODO

stack:
  backend: []
  database: []
  infrastructure: []

directories:
  key: {}
YML
fi

if [ ! -f "$TARGET/.context/boundaries.yml" ]; then
  cat > "$TARGET/.context/boundaries.yml" << 'YML'
boundaries:
  pristine:
    - path: docs/.runtime/
      reason: "Documentation System Runtime submodule (managed by git submodule update --remote)"
  editable:
    - path: docs/
      reason: "all user-authored documentation (architecture, adr, specs, audits, backlog, api)"
  generated: []
  secret: []
YML
fi

if [ ! -f "$TARGET/.context/agent-entry.md" ]; then
  cat > "$TARGET/.context/agent-entry.md" << 'MD'
# Agent Entry Protocol

Read in order:
1. `.context/project.yml` — what project this is
2. `.context/boundaries.yml` — what is editable / pristine / secret
3. `docs/architecture/README.md` — topology, invariants (create if missing)
4. `CLAUDE.md` — rules

Before creating any .md in docs/:
1. Identify `type` (spec|adr|audit|runbook|guide|api|architecture|backlog|prompt)
2. Copy template from runtime: `docs/.runtime/naprolom-docs/engine/templates/<type>.md`
3. Fill the 6 mandatory fields: schema, id, type, status, date, owners
4. Never add `lifecycle:` to frontmatter (computed from path for specs/api)
5. Never add legacy fields: author, title, created, referenced_by, supersedes_adr, excludes-from-scope
MD
fi

# ─── 3. CLAUDE.md snippet — minimal pointer to the runtime (PREPEND). ────────

CLAUDE="$TARGET/CLAUDE.md"
SNIPPET=$(cat << 'MD'
## Documentation Runtime

Documentation System Runtime is connected as a Git Submodule:

    docs/.runtime/naprolom-docs/

Before any change to `docs/`:
1. Study `docs/.runtime/naprolom-docs/playbook/playbook-v2.md` (target model)
2. Use `docs/.runtime/naprolom-docs/engine/templates/` — do NOT copy templates into the project
3. Follow `docs/.runtime/naprolom-docs/engine/schemas/frontmatter.schema.json`
4. Run `docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh` before commit
5. For brownfield migration, follow `docs/.runtime/naprolom-docs/playbook/migrate-legacy.md`
6. For typical processes, pick a SOP in `docs/.runtime/naprolom-docs/sops/` and run `node docs/.runtime/naprolom-docs/sops/planner.mjs <name>` — call roles by name
7. If task involves architectural review — see `docs/.runtime/naprolom-docs/sops/architecture-review.yaml`; foundation is `reality-auditor` BEFORE `architecture-reviewer`.
8. Common knowledge bases live in `docs/.runtime/naprolom-docs/knowledge/` (`architecture-principles`, `evidence-model`, `audit-principles`, `report-formats`, `capabilities`) — roles reference them by short-id, not inline.
MD
)

if [ -f "$CLAUDE" ]; then
  if ! grep -q "## Documentation Runtime" "$CLAUDE"; then
    EXISTING=$(cat "$CLAUDE")
    { printf "%s\n\n" "$SNIPPET"; printf "%s\n" "$EXISTING"; } > "$CLAUDE"
    echo "→ Prepended 'Documentation Runtime' section to existing CLAUDE.md"
  else
    echo "→ CLAUDE.md already has 'Documentation Runtime' section, skipped"
  fi
else
  printf "%s\n" "$SNIPPET" > "$CLAUDE"
  echo "→ Created CLAUDE.md with Documentation Runtime snippet"
fi

# 3b. AGENTS.md snippet — same content, only if file already exists (Cursor, Windsurf, etc.)
AGENTS="$TARGET/AGENTS.md"
if [ -f "$AGENTS" ]; then
  if ! grep -q "## Documentation Runtime" "$AGENTS"; then
    EXISTING=$(cat "$AGENTS")
    { printf "%s\n\n" "$SNIPPET"; printf "%s\n" "$EXISTING"; } > "$AGENTS"
    echo "→ Prepended 'Documentation Runtime' section to existing AGENTS.md"
  else
    echo "→ AGENTS.md already has 'Documentation Runtime' section, skipped"
  fi
fi

# ─── 4. GitHub Actions guard — copy the canonical workflow if missing. ────────

mkdir -p "$TARGET/.github/workflows"
WF="$TARGET/.github/workflows/docs-validate.yml"
if [ ! -f "$WF" ]; then
  cat > "$WF" << 'YML'
name: docs-validate
on:
  pull_request:
    paths:
      - "docs/**"
      - "knowledge/**"
      - "engine/templates/**"
      - "engine/schemas/**"
      - "engine/validators/**"
      - "engine/reality-engine/**"
      - "runtime/**"
      - "sops/**"
      - "agents/**"
      - "bootstrap/**"
      - "playbook/**"
jobs:
  schema-v1:
    runs-on: ubuntu-latest
    env:
      WARN_ONLY: ""
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
      - name: Validate Canonical Schema v1 frontmatter (docs/)
        run: |
          bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh
      - name: Validate knowledge/ frontmatter
        run: |
          ROOT=knowledge bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh knowledge
      - name: Validate Runtime dependency graph
        run: |
          bash docs/.runtime/naprolom-docs/engine/validators/validate-runtime.sh
YML
  echo "→ Created .github/workflows/docs-validate.yml"
else
  echo "→ .github/workflows/docs-validate.yml exists, skipped (review manually if needed)"
fi

# ─── 5. v1.2: Registry summary + upgrade verification ────────────────────────

if [ -n "$REGISTRY" ] && [ -f "$REGISTRY" ]; then
  echo ""
  echo "→ Registry components (v1.2):"
  echo "  Agents:     $(extract_registry_list 'agents' | tr '\n' ', ' | sed 's/,$//')"
  echo "  Knowledge:  $(extract_registry_list 'knowledge' | tr '\n' ', ' | sed 's/,$//')"
  echo "  SOPs:       $(extract_registry_list 'sops' | tr '\n' ', ' | sed 's/,$//')"
  echo "  Templates:  $(extract_registry_list 'templates' | tr '\n' ', ' | sed 's/,$//')"
fi

# ─── 6. v1.2: Verify new components exist ────────────────────────────────────

RUNTIME_DIR="$TARGET/docs/.runtime/naprolom-docs"
v12_ok=1

if [ ! -f "$RUNTIME_DIR/runtime/registry.yaml" ]; then
  echo "⚠ v1.2: runtime/registry.yaml not found — submodule may need update" >&2
  v12_ok=0
fi
if [ ! -f "$RUNTIME_DIR/runtime/state-machine.yaml" ]; then
  echo "⚠ v1.2: runtime/state-machine.yaml not found — submodule may need update" >&2
  v12_ok=0
fi
if [ ! -d "$RUNTIME_DIR/runtime/contracts" ]; then
  echo "⚠ v1.2: runtime/contracts/ not found — submodule may need update" >&2
  v12_ok=0
fi
if [ ! -d "$RUNTIME_DIR/engine/reality-engine" ]; then
  echo "⚠ v1.2: engine/reality-engine/ not found — submodule may need update" >&2
  v12_ok=0
fi
if [ ! -f "$RUNTIME_DIR/engine/validators/validate-runtime.sh" ]; then
  echo "⚠ v1.2: engine/validators/validate-runtime.sh not found — submodule may need update" >&2
  v12_ok=0
fi

if [ "$v12_ok" -eq 0 ]; then
  echo "" >&2
  echo "  Some v1.2 components are missing. Run:" >&2
  echo "    cd $TARGET && git submodule update --remote --merge" >&2
  echo "    bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh" >&2
  echo "" >&2
fi

echo ""
echo "✅ Bootstrap complete."
echo ""
echo "Next steps:"
echo "  1. Fill .context/project.yml with project-specific stack and metadata"
echo "  2. Edit .context/boundaries.yml for pristine/secret paths of THIS project"
echo "  3. Create your first ADR: cp docs/.runtime/naprolom-docs/engine/templates/adr.md docs/adr/001-<slug>.md"
echo "  4. Create docs/architecture/README.md (topology + invariants)"
echo "  5. Complete docs/architecture/entity-catalog.md with your domain entities"
echo "  6. Commit the new structure"
