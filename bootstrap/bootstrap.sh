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
# Usage:
#   bash .context/runtime/naprolom-docs/bootstrap/bootstrap.sh
#   bash .context/runtime/naprolom-docs/bootstrap/bootstrap.sh /path/to/project
#
# Idempotent: re-running is safe, existing files are preserved.

set -eu

# Resolve consumer project root:
#  - first positional arg, OR
#  - git toplevel of current cwd, OR
#  - 3 levels up from this script (default submodule path .context/runtime/naprolom-docs)
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

# 1. docs/ skeleton (5 layer model). .gitkeep for empty dirs.
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

# 2. .context/ — AI agent entry metadata (stubs; user fills them in).
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
  pristine: []
  editable:
    - path: docs/
      reason: "documentation"
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
2. Copy template from runtime: `.context/runtime/naprolom-docs/engine/templates/<type>.md`
3. Fill the 6 mandatory fields: schema, id, type, status, date, owners
4. Never add `lifecycle:` to frontmatter (computed from path for specs/api)
5. Never add legacy fields: author, title, created, referenced_by, supersedes_adr, excludes-from-scope
MD
fi

# 3. CLAUDE.md snippet — minimal pointer to the runtime (append if exists).
CLAUDE="$TARGET/CLAUDE.md"
SNIPPET=$(cat << 'MD'
## Documentation Runtime

Documentation System Runtime is connected as a Git Submodule:

    .context/runtime/naprolom-docs/

Before any change to `docs/`:
1. Study `playbook/playbook-v2.md` (target model)
2. Use `engine/templates/` — do NOT copy templates into the project
3. Follow `engine/schemas/frontmatter.schema.json`
4. Run `engine/validators/validate-frontmatter.sh` before commit
5. For brownfield migration, follow `playbook/migrate-legacy.md`
6. For typical processes, pick a SOP in `sops/` and run `sops/planner.mjs <name>` — call roles by name
MD
)

if [ -f "$CLAUDE" ]; then
  if ! grep -q "## Documentation Runtime" "$CLAUDE"; then
    printf "\n\n%s\n" "$SNIPPET" >> "$CLAUDE"
    echo "→ Appended 'Documentation Runtime' section to CLAUDE.md"
  else
    echo "→ CLAUDE.md already has 'Documentation Runtime' section, skipped"
  fi
else
  printf "%s\n" "$SNIPPET" > "$CLAUDE"
  echo "→ Created CLAUDE.md with Documentation Runtime snippet"
fi

# 4. GitHub Actions guard — copy the canonical workflow if missing.
mkdir -p "$TARGET/.github/workflows"
WF="$TARGET/.github/workflows/docs-validate.yml"
if [ ! -f "$WF" ]; then
  cat > "$WF" << 'YML'
name: docs-validate
on:
  pull_request:
    paths: ["docs/**"]
jobs:
  schema-v1:
    runs-on: ubuntu-latest
    env:
      WARN_ONLY: ""
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
      - name: Validate Canonical Schema v1 frontmatter
        run: |
          bash .context/runtime/naprolom-docs/engine/validators/validate-frontmatter.sh
YML
  echo "→ Created .github/workflows/docs-validate.yml"
else
  echo "→ .github/workflows/docs-validate.yml exists, skipped (review manually if needed)"
fi

echo ""
echo "✅ Bootstrap complete."
echo ""
echo "Next steps:"
echo "  1. Fill .context/project.yml with project-specific stack and metadata"
echo "  2. Edit .context/boundaries.yml for pristine/secret paths of THIS project"
echo "  3. Create your first ADR: cp .context/runtime/naprolom-docs/engine/templates/adr.md docs/adr/001-<slug>.md"
echo "  4. Create docs/architecture/README.md (topology + invariants)"
echo "  5. Commit the new structure"
