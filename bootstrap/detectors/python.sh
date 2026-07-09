#!/bin/bash
# bootstrap/detectors/python.sh — Python stack detector

detect() {
  local backend="" database="" infrastructure=""

  if [ -f "$TARGET/pyproject.toml" ]; then
    if grep -q "fastapi" "$TARGET/pyproject.toml" 2>/dev/null; then backend="FastAPI"
    elif grep -q "django" "$TARGET/pyproject.toml" 2>/dev/null; then backend="Django"
    elif grep -q "flask" "$TARGET/pyproject.toml" 2>/dev/null; then backend="Flask"
    else backend="Python"; fi
  elif [ -f "$TARGET/requirements.txt" ]; then
    if grep -qi "fastapi" "$TARGET/requirements.txt" 2>/dev/null; then backend="FastAPI"
    elif grep -qi "django" "$TARGET/requirements.txt" 2>/dev/null; then backend="Django"
    elif grep -qi "flask" "$TARGET/requirements.txt" 2>/dev/null; then backend="Flask"
    else backend="Python"; fi
  fi

  echo "$backend|$database|$infrastructure"
}
