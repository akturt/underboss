#!/bin/bash
# bootstrap/detectors/node.sh — Node.js stack detector
#
# Output format: backend|database|infrastructure

detect() {
  local backend="" database="" infrastructure=""

  [ -f "$TARGET/package.json" ] || return 0

  # Project name
  PROJECT_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$TARGET/package.json" 2>/dev/null | head -1 | sed 's/.*: *"//; s/".*//')

  # Framework detection
  if grep -q '"next"' "$TARGET/package.json" 2>/dev/null; then
    backend="Next.js"
  elif grep -q '"nuxt"' "$TARGET/package.json" 2>/dev/null; then
    backend="Nuxt"
  elif grep -q '"@angular/core"' "$TARGET/package.json" 2>/dev/null; then
    backend="Angular"
  elif grep -q '"react"' "$TARGET/package.json" 2>/dev/null; then
    backend="React"
  elif grep -q '"vue"' "$TARGET/package.json" 2>/dev/null; then
    backend="Vue"
  elif grep -q '"svelte"' "$TARGET/package.json" 2>/dev/null; then
    backend="Svelte"
  else
    backend="Node.js"
  fi

  # Vite
  if [ -f "$TARGET/vite.config.ts" ] || [ -f "$TARGET/vite.config.js" ] || [ -f "$TARGET/vite.config.mjs" ]; then
    infrastructure="Vite"
  fi

  echo "$backend|$database|$infrastructure"
}
