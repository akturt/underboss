#!/bin/bash
# bootstrap/detectors/php.sh — PHP/Laravel stack detector

detect() {
  local backend="" database="" infrastructure=""
  if [ -f "$TARGET/composer.json" ] && grep -q "laravel" "$TARGET/composer.json" 2>/dev/null; then
    backend="Laravel"
  fi
  echo "$backend|$database|$infrastructure"
}
