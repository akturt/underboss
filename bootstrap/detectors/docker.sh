#!/bin/bash
# bootstrap/detectors/docker.sh — Docker infrastructure detector

detect() {
  local backend="" database="" infrastructure=""

  if [ -f "$TARGET/docker-compose.yml" ] || [ -f "$TARGET/docker-compose.yaml" ]; then
    infrastructure="Docker Compose"
    local dc="$TARGET/docker-compose.yml"
    [ -f "$TARGET/docker-compose.yaml" ] && dc="$TARGET/docker-compose.yaml"

    # Database detection from docker-compose
    if grep -q "postgres" "$dc" 2>/dev/null; then database="PostgreSQL"
    elif grep -q "mysql" "$dc" 2>/dev/null; then database="MySQL"
    elif grep -q "mongo" "$dc" 2>/dev/null; then database="MongoDB"
    elif grep -q "redis" "$dc" 2>/dev/null; then database="Redis"
    fi
  elif [ -f "$TARGET/Dockerfile" ]; then
    infrastructure="Docker"
  fi

  echo "$backend|$database|$infrastructure"
}
