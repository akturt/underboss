#!/bin/bash
# runtime/lib/registry.sh — Registry API (SSOT reader)
#
# All Runtime components read from registry through this API.
# No awk/grep/sed — uses yaml.sh for all parsing.
#
# Requires: runtime/lib/yaml.sh

# Lazy computation — RUNTIME_REGISTRY computed on first use
RUNTIME_REGISTRY=""

_registry_init() {
  if [ -z "$RUNTIME_REGISTRY" ]; then
    RUNTIME_REGISTRY="${RUNTIME_ROOT}/runtime/registry.yaml"
  fi
}

registry_exists() {
  _registry_init
  [ -n "$RUNTIME_REGISTRY" ] && [ -f "$RUNTIME_REGISTRY" ]
}

# --- Scalar accessors ---

registry_name() {
  _registry_init
  yaml_get "$RUNTIME_REGISTRY" "runtime.name"
}

registry_version() {
  _registry_init
  yaml_get "$RUNTIME_REGISTRY" "runtime.version"
}

registry_codename() {
  _registry_init
  yaml_get "$RUNTIME_REGISTRY" "runtime.codename"
}

registry_bootstrap_version() {
  _registry_init
  yaml_get "$RUNTIME_REGISTRY" "bootstrap.engine_version"
}

registry_schema_version() {
  _registry_init
  yaml_get "$RUNTIME_REGISTRY" "schema.version"
}

# --- Entrypoints ---

registry_entrypoint() {
  _registry_init
  local name="$1"
  yaml_get "$RUNTIME_REGISTRY" "entrypoints.${name}"
}

# --- Component lists ---

registry_list_agents() {
  _registry_init
  yaml_get_list "$RUNTIME_REGISTRY" "components.agents"
}

registry_list_knowledge() {
  _registry_init
  yaml_get_list "$RUNTIME_REGISTRY" "components.knowledge"
}

registry_list_sops() {
  _registry_init
  yaml_get_list "$RUNTIME_REGISTRY" "components.sops"
}

registry_list_contracts() {
  _registry_init
  local level="$1"
  yaml_get_deep_list "$RUNTIME_REGISTRY" "components.contracts.${level}"
}

registry_list_templates() {
  _registry_init
  yaml_get_list "$RUNTIME_REGISTRY" "templates"
}

registry_list_validators() {
  _registry_init
  yaml_get_list "$RUNTIME_REGISTRY" "validators"
}

registry_list_detectors() {
  _registry_init
  yaml_get_list "$RUNTIME_REGISTRY" "detectors"
}

registry_list_generators() {
  _registry_init
  yaml_get_list "$RUNTIME_REGISTRY" "generators"
}

# --- Path accessors ---

registry_get_template_path() {
  _registry_init
  local name="$1"
  yaml_get_map_field "$RUNTIME_REGISTRY" "templates" "$name" "path"
}

registry_get_detector_path() {
  _registry_init
  local name="$1"
  yaml_get_map_field "$RUNTIME_REGISTRY" "detectors" "$name" "path"
}

registry_get_generator_path() {
  _registry_init
  local name="$1"
  yaml_get_map_field "$RUNTIME_REGISTRY" "generators" "$name" "path"
}

registry_get_generator_entry() {
  _registry_init
  local name="$1"
  yaml_get_map_field "$RUNTIME_REGISTRY" "generators" "$name" "entry"
}

registry_get_validator_path() {
  _registry_init
  local name="$1"
  yaml_get_map_field "$RUNTIME_REGISTRY" "validators" "$name" "path"
}

# --- Directories ---

registry_list_directories() {
  _registry_init
  local scope="$1"
  awk -v scope="$scope" '
BEGIN { in_dirs=0; in_scope=0 }
/^[[:space:]]*directories:/ { in_dirs=1; next }
in_dirs && /^[a-z]/ { in_dirs=0; in_scope=0; next }
in_dirs && $0 ~ "^[[:space:]]*" scope ":" { in_scope=1; next }
in_scope && /^( [a-z]|[a-z])/ { in_scope=0; next }
in_scope && /^[[:space:]]*-[[:space:]]*path:[[:space:]]*/ {
  v=$0; sub(/^[[:space:]]*-[[:space:]]*path:[[:space:]]*/, "", v)
  gsub(/^"/, "", v); gsub(/"$/, "", v)
  print v; next
}
in_scope && /^[[:space:]]*-[[:space:]]*/ {
  v=$0; sub(/^[[:space:]]*-[[:space:]]*/, "", v)
  sub(/^path:[[:space:]]*/, "", v)
  gsub(/^"/, "", v); gsub(/"$/, "", v)
  print v
}
' "$RUNTIME_REGISTRY"
}

# --- Maps ---

registry_get_generators_map() {
  _registry_init
  yaml_get_map "$RUNTIME_REGISTRY" "generators"
}

registry_get_detectors_map() {
  _registry_init
  yaml_get_map "$RUNTIME_REGISTRY" "detectors"
}

# --- Engine components ---

registry_list_engine() {
  _registry_init
  local type="$1"
  yaml_get_deep_list "$RUNTIME_REGISTRY" "components.engine.${type}"
}

# --- Compatibility ---

registry_compatibility() {
  _registry_init
  local level="$1"
  yaml_get_list "$RUNTIME_REGISTRY" "compatibility.${level}"
}
