#!/bin/bash
# engine/reality-engine/lib/frontmatter.sh
#
# Shared, dependency-free helpers for reading YAML frontmatter in the
# Reality Engine. Sourced by collectors and analyzers.
#
# collect_field <file> <field>  -> prints list items (inline [a, b] or block "- a")
# get_field    <file> <field>   -> prints the scalar value of a frontmatter field

collect_field() {
  local file="$1" field="$2"
  [ -f "$file" ] || return 0
  awk -v f="$field" '
    NR==1 && $0!="---" {exit}
    $0=="---" { if (fm==0) { fm=1; next } else { exit } }
    fm==1 {
      if ($0 ~ "^" f ":") {
        if ($0 ~ /\[.*\]/) {
          line=$0; sub(/^[^[]*\[/, "", line); sub(/\].*/, "", line)
          n=split(line, parts, ",")
          for (i=1; i<=n; i++) { v=parts[i]; gsub(/^[ "\047]+/, "", v); gsub(/[ "\047]+$/, "", v); if (v!="") print v }
          infm=0
        } else { infm=1 }
        next
      }
      if (infm==1) {
        if ($0 ~ /^  - /) { sub(/^  - /,""); gsub(/^["\047]|["\047]$/,""); print }
        else if ($0 ~ /^[^ ]/ && $0 !~ /^  /) { infm=0 }
      }
    }
  ' "$file"
}

get_field() {
  local file="$1" field="$2"
  [ -f "$file" ] || return 0
  awk -v f="$field" '
    NR==1 && $0!="---" {exit}
    $0=="---" { if (fm==0) { fm=1; next } else { exit } }
    fm==1 && $0 ~ "^" f ":" { sub(/^[^:]*:[[:space:]]*/, ""); gsub(/^["\047]|["\047]$/, ""); print; exit }
  ' "$file"
}
