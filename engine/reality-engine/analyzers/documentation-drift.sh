#!/bin/bash
# engine/reality-engine/analyzers/documentation-drift.sh
#
# Real documentation drift: flags docs missing required frontmatter
# (schema / id / type) or using an unrecognized status value.
#
# Usage:
#   bash engine/reality-engine/analyzers/documentation-drift.sh [project-root] [architecture-inventory.json]
#
# Output: drift-report.json (stdout)

set -eu

PROJECT_ROOT="${1:-.}"
[ -d "$PROJECT_ROOT" ] || { echo "ERROR: project root '$PROJECT_ROOT' not found" >&2; exit 1; }
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# shellcheck disable=SC1090
source "$(dirname "${BASH_SOURCE[0]}")/../lib/frontmatter.sh"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

ALLOWED="active draft proposed accepted deprecated superseded completed planned obsolete rejected approved implemented review withdrawn archived declined"

drift_json=""
first=1
add_drift() {
  if [ "$first" -eq 1 ]; then first=0; else drift_json="$drift_json,"; fi
  drift_json="$drift_json$1"
}

while IFS= read -r f; do
  rel="${f#$PROJECT_ROOT/}"
  head -1 "$f" 2>/dev/null | grep -q '^---$' || continue

  schema=$(get_field "$f" "schema")
  id=$(get_field "$f" "id")
  dtype=$(get_field "$f" "type")
  status=$(get_field "$f" "status")

  [ -z "$schema" ] && add_drift "$(printf '    {"type": "missing_field", "file": "%s", "field": "schema"}' "$rel")"
  [ -z "$id" ]     && add_drift "$(printf '    {"type": "missing_field", "file": "%s", "field": "id"}' "$rel")"
  [ -z "$dtype" ]  && add_drift "$(printf '    {"type": "missing_field", "file": "%s", "field": "type"}' "$rel")"

  if [ -n "$status" ]; then
    found=0
    for a in $ALLOWED; do [ "$status" = "$a" ] && found=1 && break; done
    [ "$found" -eq 0 ] && add_drift "$(printf '    {"type": "unknown_status", "file": "%s", "status": "%s"}' "$rel" "$status")"
  fi
done < <(find "$PROJECT_ROOT" -type f -name "*.md" \
            -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.runtime/*" | sort)

cat <<EOF
{
  "timestamp": "$TS",
  "project_root": "$PROJECT_ROOT",
  "drift_items": [
$drift_json
  ],
  "status": "ok"
}
EOF
