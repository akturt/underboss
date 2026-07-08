#!/bin/bash
# validators/validate-frontmatter.sh
#
# Validates that every .md file under docs/ has Canonical Schema v1 frontmatter.
# Frontmatter-only checks (no false positives on prose/code blocks).
# Based on schemas/frontmatter.schema.json.
#
# Exit codes:
#   0 — all OK (or WARN_ONLY=1 with only warnings)
#   1 — at least one error (when WARN_ONLY unset/empty)
#
# Usage:
#   ./validators/validate-frontmatter.sh [docs-root]
#   WARN_ONLY=1 ./validators/validate-frontmatter.sh      # warn-only (brownfield rollout)
#   ROOT=docs ./validators/validate-frontmatter.sh        # override default docs/ root

set -u

DOCS_ROOT="${1:-${ROOT:-docs}}"
WARN_ONLY="${WARN_ONLY:-}"
fail=0
warning=0

if [ ! -d "$DOCS_ROOT" ]; then
  echo "docs-validate: docs root '$DOCS_ROOT' not found, nothing to validate"
  exit 0
fi

warn() {
  if [ -n "$WARN_ONLY" ]; then
    echo "WARNING: $1"
    warning=1
  else
    echo "ERROR: $1"
    fail=1
  fi
}

# extract_frontmatter <file>
# Prints only the YAML block between first and second '---' line. Empty if no FM.
extract_frontmatter() {
  awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$1"
}

# check_file <file>
check_file() {
  local f="$1"
  [ -f "$f" ] || return

  # FM present at all?
  local first
  first=$(awk 'NR==1{print; exit}' "$f")
  if [ "$first" != "---" ]; then
    warn "$f: no frontmatter at all"
    return
  fi

  local fm
  fm=$(extract_frontmatter "$f")
  [ -n "$fm" ] || { warn "$f: empty frontmatter"; return; }

  # 1. schema: 1 mandatory
  echo "$fm" | grep -qE "^schema:[[:space:]]*1[[:space:]]*$" || warn "$f: schema != 1"

  # 2. mandatory base fields
  for field in id type status date owners; do
    echo "$fm" | grep -qE "^${field}:" || warn "$f: missing mandatory field '$field'"
  done

  # 3. legacy fields FORBIDDEN in frontmatter only
  for pat in "^lifecycle:" "^author:" "^title:" "^created:" "^supersedes_adr:" "^referenced_by:" "^excludes-from-scope:"; do
    if echo "$fm" | grep -qE "$pat"; then
      warn "$f: legacy field '$pat' in frontmatter"
    fi
  done

  # 4. spec path-status match (status must equal parent directory, with 'drafts' → 'draft' normalization)
  case "$f" in
    */specs/drafts/*|*/specs/review/*|*/specs/approved/*|*/specs/implemented/*|*/specs/superseded/*)
      local dir
      dir=$(echo "$f" | awk -F/ '{print $(NF-1)}')
      local status
      status=$(echo "$fm" | grep -m1 -E "^status:" | sed -E 's/^status:[[:space:]]*//')
      # 'drafts' directory corresponds to 'draft' status (singular); others match 1:1
      local dir_normalized
      dir_normalized=$([ "$dir" = "drafts" ] && echo "draft" || echo "$dir")
      [ "$status" = "$dir_normalized" ] || warn "$f: status '$status' != path '$dir' (expected '$dir_normalized')"
      ;;
  esac

  # 5. runbook must have kind:
  local type
  type=$(echo "$fm" | grep -m1 -E "^type:" | sed -E 's/^type:[[:space:]]*//')
  if [ "$type" = "runbook" ]; then
    echo "$fm" | grep -qE "^kind:" || warn "$f: type runbook requires 'kind:'"
  fi

  # 6. spec/audit should have non-empty entity_refs (warn always)
  if [ "$type" = "spec" ] || [ "$type" = "audit" ]; then
    if echo "$fm" | grep -qE "^entity_refs:[[:space:]]*\[\]"; then
      echo "NOTE: $f: $type should define entity_refs (currently empty)"
    fi
  fi
}

# Iterate over tracked .md files (or all .md if not in git)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r f; do
    check_file "$f"
  done < <(git ls-files -- "$DOCS_ROOT/**/*.md" "$DOCS_ROOT/*.md" 2>/dev/null || find "$DOCS_ROOT" -name "*.md" -type f)
else
  while IFS= read -r f; do
    check_file "$f"
  done < <(find "$DOCS_ROOT" -name "*.md" -type f)
fi

if [ "$fail" -ne 0 ]; then
  echo "::error::docs-validate failed (see errors above)"
  exit 1
fi

if [ "$warning" -ne 0 ] && [ -z "$WARN_ONLY" ]; then
  # Should not happen, but defensive
  exit 1
fi

echo "docs-validate: OK"
exit 0
