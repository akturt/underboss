#!/bin/bash
# engine/reality-engine/collectors/entity-inventory.sh
#
# Maps domain entities to code artifacts.
# Scans for entity references in docs/architecture/ and cross-references with code.
#
# Usage:
#   bash engine/reality-engine/collectors/entity-inventory.sh [project-root]
#
# Output: entity-inventory.json (stdout)

set -eu

PROJECT_ROOT="${1:-.}"

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "ERROR: project root '$PROJECT_ROOT' not found" >&2
  exit 1
fi

echo "{"
echo '  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",'
echo '  "project_root": "'"$PROJECT_ROOT"'",'

# Collect entity_refs from docs/
echo '  "entity_refs_from_docs": ['
if [ -d "$PROJECT_ROOT/docs" ]; then
  find "$PROJECT_ROOT/docs" -name "*.md" -type f | while read -r f; do
    # Extract entity_refs from frontmatter
    awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f && /^entity_refs:/{gsub(/^entity_refs:[[:space:]]*\[/, ""); gsub(/\].*/, ""); gsub(/,/,"\n"); while(getline line){gsub(/^[[:space:]]+/,"",line); if(line!="") print "    \""line"\""}; exit}' "$f"
  done | sort -u
fi
echo "  ],"

echo '  "status": "stub"'
echo "}"
