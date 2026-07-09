#!/bin/bash
# bootstrap/detectors/go.sh — Go stack detector

detect() {
  local backend="" database="" infrastructure=""
  [ -f "$TARGET/go.mod" ] && backend="Go"
  echo "$backend|$database|$infrastructure"
}
