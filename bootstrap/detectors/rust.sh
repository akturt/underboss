#!/bin/bash
# bootstrap/detectors/rust.sh — Rust stack detector

detect() {
  local backend="" database="" infrastructure=""
  [ -f "$TARGET/Cargo.toml" ] && backend="Rust"
  echo "$backend|$database|$infrastructure"
}
