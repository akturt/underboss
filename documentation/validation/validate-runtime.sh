#!/bin/bash
# documentation/validation/validate-runtime.sh
#
# Validates Runtime's own integrity as a complete dependency graph.
# Checks: Role→Capability, Capability→Knowledge, Knowledge exists, Registry consistency,
# Contract consistency, Bootstrap consistency, Workflow consistency, Template conformance,
# Internal links, Engine components.
#
# Exit codes:
#   0 — all OK
#   1 — at least one error
#
# Usage:
#   ./validation/validate-runtime.sh [runtime-root]
#   RUNTIME_ROOT=/path/to/naprolom-docs ./validation/validate-runtime.sh

set -u

RUNTIME_ROOT="${1:-${RUNTIME_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}}"
fail=0
checked=0

if [ ! -d "$RUNTIME_ROOT" ]; then
  echo "validate-runtime: runtime root '$RUNTIME_ROOT' not found"
  exit 0
fi

error() {
  echo "ERROR: $1"
  fail=1
}

ok() {
  checked=$((checked + 1))
}

# ─── 1. Registry exists ──────────────────────────────────────────────────────

REGISTRY="$RUNTIME_ROOT/runtime/registry.yaml"
if [ ! -f "$REGISTRY" ]; then
  error "runtime/registry.yaml not found"
  exit 1
fi
ok

echo "validate-runtime: checking $RUNTIME_ROOT"

# ─── 2. Registry consistency: every component has a matching file on disk ────

# extract_section <section_name> — extracts list items from registry section
# Sections are at 2-space indent under components:, items at 4-space indent
extract_section() {
  local section="$1"
  awk -v sec="  $section:" '
    $0 == sec { found=1; next }
    found && /^  [a-zA-Z]/ { exit }
    found && /^    - / { sub(/^    - /, ""); print }
  ' "$REGISTRY"
}

# Check agents (agents have name: field, not plain list)
while IFS= read -r agent; do
  found=0
  for platform in claude-code opencode; do
    if [ -f "$RUNTIME_ROOT/agents/$platform/$agent.md" ]; then
      found=1
      break
    fi
  done
  if [ "$found" -eq 0 ]; then
    error "Registry agent '$agent' has no matching file in agents/{claude-code,opencode}/"
  fi
done < <(awk '
  $0 == "  agents:" { found=1; next }
  found && /^  [a-zA-Z]/ { exit }
  found && /^    - name: / { sub(/^    - name: /, ""); print }
' "$REGISTRY")
ok

# Check knowledge
while IFS= read -r k; do
  if [ ! -f "$RUNTIME_ROOT/knowledge/$k.md" ]; then
    error "Registry knowledge '$k' has no matching file knowledge/$k.md"
  fi
done < <(extract_section "knowledge")
ok

# Check SOPs
while IFS= read -r sop; do
  if [ ! -f "$RUNTIME_ROOT/sops/$sop.yaml" ]; then
    error "Registry SOP '$sop' has no matching file sops/$sop.yaml"
  fi
done < <(extract_section "sops")
ok

# Check templates
while IFS= read -r tmpl; do
  if [ ! -f "$RUNTIME_ROOT/documentation/templates/$tmpl.md" ]; then
    error "Registry template '$tmpl' has no matching file documentation/templates/$tmpl.md"
  fi
done < <(extract_section "templates")
ok

# Check validators
while IFS= read -r val; do
  if [ ! -f "$RUNTIME_ROOT/documentation/validation/$val.sh" ]; then
    error "Registry validator '$val' has no matching file documentation/validation/$val.sh"
  fi
done < <(extract_section "validators")
ok

# Check engine components (collectors, analyzers, reporters)
for component_type in collectors analyzers reporters; do
  while IFS= read -r comp; do
    if [ ! -f "$RUNTIME_ROOT/engine/reality-engine/$component_type/$comp.sh" ]; then
      error "Registry engine $component_type '$comp' has no matching file engine/reality-engine/$component_type/$comp.sh"
    fi
  done < <(extract_section "$component_type")
done
ok

# ─── 3. Role → Capability: every capabilities: entry exists in capabilities.md ─

CAPABILITIES_FILE="$RUNTIME_ROOT/knowledge/capabilities.md"
if [ -f "$CAPABILITIES_FILE" ]; then
  for platform in claude-code opencode; do
    for agent_file in "$RUNTIME_ROOT/agents/$platform/"*.md; do
      [ -f "$agent_file" ] || continue
      agent_name=$(basename "$agent_file" .md)

      # Extract capabilities from frontmatter
      fm=$(awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$agent_file")
      caps=$(echo "$fm" | grep -E "^capabilities:" | sed -E 's/^capabilities:[[:space:]]*\[//' | sed -E 's/\].*//' | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

      for cap in $caps; do
        [ -z "$cap" ] && continue
        if ! grep -qE "^## ${cap}[[:space:]]" "$CAPABILITIES_FILE" 2>/dev/null && \
           ! grep -qE "^## ${cap}$" "$CAPABILITIES_FILE" 2>/dev/null; then
          error "Agent '$agent_name' capability '$cap' not found in knowledge/capabilities.md"
        fi
      done
    done
  done
fi
ok

# ─── 4. Knowledge exists: every knowledge: short-id resolves to file ─────────

for platform in claude-code opencode; do
  for agent_file in "$RUNTIME_ROOT/agents/$platform/"*.md; do
    [ -f "$agent_file" ] || continue
    agent_name=$(basename "$agent_file" .md)

    fm=$(awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$agent_file")
    knowledge=$(echo "$fm" | grep -E "^knowledge:" | sed -E 's/^knowledge:[[:space:]]*\[//' | sed -E 's/\].*//' | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    for k in $knowledge; do
      [ -z "$k" ] && continue
      if [ ! -f "$RUNTIME_ROOT/knowledge/$k.md" ]; then
        error "Agent '$agent_name' knowledge ref '$k' does not resolve to knowledge/$k.md"
      fi
    done
  done
done
ok

# ─── 5. Contract consistency: contracts referenced by registry exist ─────────

for level in runtime consumer; do
  while IFS= read -r contract; do
    [ -z "$contract" ] && continue
    if [ ! -f "$RUNTIME_ROOT/runtime/contracts/$level/$contract.yaml" ]; then
      error "Registry contract '$level/$contract' has no matching file runtime/contracts/$level/$contract.yaml"
    fi
  done < <(awk -v lvl="      $level:" '
    $0 == "  contracts:" { in_contracts=1; next }
    in_contracts && /^  [a-zA-Z]/ { exit }
    in_contracts && $0 == lvl { in_level=1; next }
    in_level && /^    [a-zA-Z]/ { exit }
    in_level && /^      - / { sub(/^      - /, "", $0); print }
  ' "$REGISTRY")
done
ok

# ─── 6. Workflow consistency: every SOP role: has matching agent ─────────────

for sop_file in "$RUNTIME_ROOT/sops/"*.yaml; do
  [ -f "$sop_file" ] || continue
  sop_name=$(basename "$sop_file" .yaml)

  # Extract role: references from steps
  roles=$(grep -E "^\s+role:" "$sop_file" | sed -E 's/^\s+role:[[:space:]]*//' | sort -u)

  for role in $roles; do
    [ -z "$role" ] && continue
    [ "$role" = "human" ] && continue  # human is not a role
    found=0
    for platform in claude-code opencode; do
      if [ -f "$RUNTIME_ROOT/agents/$platform/$role.md" ]; then
        found=1
        break
      fi
    done
    if [ "$found" -eq 0 ]; then
      error "SOP '$sop_name' references role '$role' but no matching agent found"
    fi
  done

  # Extract capability: references and check they exist in capabilities.md
  if [ -f "$CAPABILITIES_FILE" ]; then
    caps=$(grep -E "^\s+capability:" "$sop_file" | sed -E 's/^\s+capability:[[:space:]]*//' | sort -u)
    for cap in $caps; do
      [ -z "$cap" ] && continue
      if ! grep -qE "^## ${cap}[[:space:]]" "$CAPABILITIES_FILE" 2>/dev/null && \
         ! grep -qE "^## ${cap}$" "$CAPABILITIES_FILE" 2>/dev/null; then
        error "SOP '$sop_name' references capability '$cap' not found in knowledge/capabilities.md"
      fi
    done
  fi
done
ok

# ─── 7. Template conformance: every template has valid Schema v1 FM ──────────

for tmpl_file in "$RUNTIME_ROOT/documentation/templates/"*.md; do
  [ -f "$tmpl_file" ] || continue
  tmpl_name=$(basename "$tmpl_file")

  fm=$(awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$tmpl_file")
  if [ -z "$fm" ]; then
    error "Template '$tmpl_name' has no frontmatter"
    continue
  fi

  echo "$fm" | grep -qE "^schema:[[:space:]]*1[[:space:]]*$" || error "Template '$tmpl_name' schema != 1"
  for field in id type status date owners; do
    echo "$fm" | grep -qE "^${field}:" || error "Template '$tmpl_name' missing mandatory field '$field'"
  done
done
ok

# ─── 8. Internal links: entity_refs resolve to existing id: fields ───────────

# Collect all id: fields from FM (also collect registry component names, knowledge short-ids,
# agent names, validator names — these are implicit entities in the Runtime graph).
# Initialize with concept entities to avoid empty variable with set -u.
all_ids=$(printf '%s\n' "runtime-agentic-layer" "agent-role-separation" "sop-dag" "schema-v1" "canonical-frontmatter" "lifecycle-spec" "lifecycle-adr" "capabilities" "runtime" "registry" "state-machine" "reality-engine")

# a) Explicit id: fields from docs/ and knowledge/
all_ids="$all_ids
$(find "$RUNTIME_ROOT/docs" "$RUNTIME_ROOT/knowledge" "$RUNTIME_ROOT/documentation" -name "*.md" -type f 2>/dev/null | while read -r f; do
  awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f && /^id:/{gsub(/^id:[[:space:]]*/, ""); print}' "$f"
done)"

# b) Registry component names (agents, knowledge, sops, templates, validators, contracts)
if [ -f "$REGISTRY" ]; then
  # agent names
  all_ids="$all_ids
$(awk '
    $0 == "  agents:" { found=1; next }
    found && /^  [a-zA-Z]/ { exit }
    found && /^    - name: / { sub(/^    - name: /, ""); print }
  ' "$REGISTRY")"
  # knowledge, sops, templates, validators (flat lists)
  for key in knowledge sops templates validators; do
    all_ids="$all_ids
$(extract_section "$key")"
  done
  # contract names (runtime + consumer)
  for level in runtime consumer; do
    all_ids="$all_ids
$(awk -v lvl="      $level:" '
      $0 == "  contracts:" { in_contracts=1; next }
      in_contracts && /^  [a-zA-Z]/ { exit }
      in_contracts && $0 == lvl { in_level=1; next }
      in_level && /^    [a-zA-Z]/ { exit }
      in_level && /^      - / { sub(/^      - /, "", $0); print }
    ' "$REGISTRY")"
  done
  # engine component names (collectors, analyzers, reporters)
  for component_type in collectors analyzers reporters; do
    all_ids="$all_ids
$(awk "/^  ${component_type}:/,/^[^ ]/" "$REGISTRY" | grep "^    - " | sed 's/^    - //')"
  done
fi

all_ids=$(echo "$all_ids" | sort -u)

# Check entity_refs against collected ids
while IFS= read -r f; do
  [ -f "$f" ] || continue
  fm=$(awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$f")
  refs=$(echo "$fm" | grep -E "^entity_refs:" | sed -E 's/^entity_refs:[[:space:]]*\[//' | sed -E 's/\].*//' | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

  for ref in $refs; do
    [ -z "$ref" ] && continue
    if ! echo "$all_ids" | grep -qFx "$ref"; then
      rel_path="${f#$RUNTIME_ROOT/}"
      error "$rel_path: entity_ref '$ref' does not resolve to any id: field or registry component"
    fi
  done
done < <(find "$RUNTIME_ROOT/docs" "$RUNTIME_ROOT/knowledge" "$RUNTIME_ROOT/documentation" -name "*.md" -type f 2>/dev/null)
ok

# ─── 9. Engine components: collectors/analyzers/reporters referenced by SOP exist ─

for sop_file in "$RUNTIME_ROOT/sops/"*.yaml; do
  [ -f "$sop_file" ] || continue
  sop_name=$(basename "$sop_file" .yaml)

  # Check if SOP uses engine
  if grep -qE "^engine:" "$sop_file"; then
    engine=$(grep -E "^engine:" "$sop_file" | sed -E 's/^engine:[[:space:]]*//')

    # Check engine_step: references
    engine_steps=$(grep -E "^\s+engine_step:" "$sop_file" | sed -E 's/^\s+engine_step:[[:space:]]*//')
    for step_path in $engine_steps; do
      if [ ! -f "$RUNTIME_ROOT/engine/$engine/$step_path" ]; then
        error "SOP '$sop_name' references engine component '$engine/$step_path' but file not found"
      fi
    done
  fi
done
ok

# ─── Result ──────────────────────────────────────────────────────────────────

if [ "$fail" -ne 0 ]; then
  echo "::error::validate-runtime failed (see errors above)"
  exit 1
fi

echo "validate-runtime: OK ($checked checks passed)"
exit 0
