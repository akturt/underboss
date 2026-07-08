#!/bin/bash
# engine/reality-engine/collectors/architecture-inventory.sh
#
# Extracts actual architecture from codebase.
# Read-only investigation: modules, services, dependencies, ownership.
#
# Usage:
#   bash engine/reality-engine/collectors/architecture-inventory.sh [project-root]
#
# Output: architecture-inventory.json (stdout)

set -eu

PROJECT_ROOT="${1:-.}"

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "ERROR: project root '$PROJECT_ROOT' not found" >&2
  exit 1
fi

# Collect directory structure (top 2 levels)
echo "{"
echo '  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",'
echo '  "project_root": "'"$PROJECT_ROOT"'",'
echo '  "directories": ['

first=true
find "$PROJECT_ROOT" -maxdepth 2 -type d -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.runtime/*" | sort | while read -r dir; do
  rel="${dir#$PROJECT_ROOT}"
  [ -z "$rel" ] && rel="/"
  if [ "$first" = true ]; then
    first=false
  else
    echo ","
  fi
  printf '    {"path": "%s"}' "$rel"
done

echo ""
echo "  ],"
echo '  "files_count": '$(find "$PROJECT_ROOT" -type f -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.runtime/*" | wc -l)','
echo '  "status": "stub"'
echo "}"
