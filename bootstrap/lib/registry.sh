#!/bin/bash
# bootstrap/lib/registry.sh — Registry parser (SSOT reader)
#
# Provides functions to extract data from runtime/registry.yaml.
# All bootstrap logic reads from registry — no hardcoded paths.
#
# Registry v1.5 structure:
#   components:
#     agents: [...]
#     knowledge: [...]
#   detectors: [...]
#   generators: [...]

REGISTRY="${RUNTIME_ROOT}/runtime/registry.yaml"

registry_exists() {
  [ -n "$REGISTRY" ] && [ -f "$REGISTRY" ]
}

# extract_section <section_name> <parent> — extract items from a section under parent
# e.g. extract_section agents components
# Works with nested components: and top-level sections (detectors:, generators:)
extract_section() {
  local section="$1" parent="${2:-}"
  registry_exists || return

  if [ -n "$parent" ]; then
    # Section is nested under parent (e.g. agents under components)
    awk -v sec="  ${section}:" -v par="^  ${parent}:" '
      BEGIN { in_sec=0 }
      $0 ~ par { next }
      $0 == sec { in_sec=1; next }
      in_sec && /^  [a-z]/ { exit }
      in_sec && /^    - name: / { sub(/^    - name: /, ""); print }
      in_sec && /^    - / { sub(/^    - /, ""); print }
    ' "$REGISTRY"
  else
    # Section is a top-level key (e.g. detectors:)
    awk -v sec="^${section}:" '
      BEGIN { in_sec=0 }
      $0 ~ sec { in_sec=1; next }
      in_sec && /^[a-z]/ { exit }
      in_sec && /^  - name: / { sub(/^  - name: /, ""); print }
      in_sec && /^  - / { sub(/^  - /, ""); print }
    ' "$REGISTRY"
  fi
}

# extract_list <key> — flat list under components:
extract_list() {
  local key="$1"
  registry_exists || return
  awk "/^  ${key}:/,/^[a-z]/" "$REGISTRY" | grep "^    - " | sed 's/^    - //'
}

# extract_nested <section> <subsection> — e.g. contracts.runtime
extract_nested() {
  local section="$1" subsection="$2"
  registry_exists || return
  awk -v sec="^  ${section}:" -v subsec="    ${subsection}:" '
    BEGIN { in_sec=0; in_sub=0 }
    $0 ~ sec { in_sec=1; next }
    in_sec && /^[a-z]/ { exit }
    in_sec && $0 ~ subsec { in_sub=1; next }
    in_sec && in_sub && /^    [a-z]/ { exit }
    in_sec && in_sub && /^      - / { sub(/^      - /, "", $0); print }
  ' "$REGISTRY"
}

# extract_value <yaml.path> — simple key: value extraction
# e.g. extract_value "runtime.version" → "1.5"
extract_value() {
  local path="$1"
  registry_exists || return
  local key
  key=$(echo "$path" | sed 's/.*\.//')
  grep "^${key}:" "$REGISTRY" | head -1 | sed 's/.*"[^"]*".*/\1/' | sed "s/.*'\([^']*\)'.*/\1/" | sed 's/^[[:space:]]*//'
}

# get_version — runtime version from registry
get_version() {
  extract_value "runtime.version"
}

# get_template_path <name> — path to template by name
get_template_path() {
  local name="$1"
  registry_exists || return
  awk -v nm="  - name: ${name}" '
    $0 == nm { found=1; next }
    found && /^  - name:/ { exit }
    found && /path:/ { sub(/.*path:[[:space:]]*/, ""); print; exit }
  ' "$REGISTRY"
}

# get_detector_path <name> — path to detector by name
get_detector_path() {
  local name="$1"
  registry_exists || return
  awk -v nm="  - name: ${name}" '
    $0 == nm { found=1; next }
    found && /^  - name:/ || found && /^[a-z]/ { exit }
    found && /path:/ { sub(/.*path:[[:space:]]*/, ""); print; exit }
  ' "$REGISTRY"
}

# get_entrypoint <name> — path to entrypoint by name
get_entrypoint() {
  local name="$1"
  registry_exists || return
  awk '/^entrypoints:/,/^[a-z]/' "$REGISTRY" | grep "${name}:" | head -1 | sed "s/.*${name}:[[:space:]]*//"
}

# list_detectors — all detector names
list_detectors() {
  registry_exists || return
  awk '/^detectors:/,/^components:/' "$REGISTRY" | grep "name:" | sed 's/.*name:[[:space:]]*//'
}

# list_generators — all generator names
list_generators() {
  registry_exists || return
  awk '/^generators:/,/^scripts:/' "$REGISTRY" | grep "name:" | sed 's/.*name:[[:space:]]*//'
}
