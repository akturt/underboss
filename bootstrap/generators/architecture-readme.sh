#!/bin/bash
# bootstrap/generators/architecture-readme.sh — Auto-generate docs/architecture/README.md
#
# Usage: generate_architecture_readme <target_dir> <stack> <domain> <name> <backend> <database> <infrastructure>

generate_architecture_readme() {
  local target_dir="$1" stack="$2" domain="$3" name="$4"
  local backend="${5:-}" database="${6:-}" infrastructure="${7:-}"

  mkdir -p "${target_dir}/docs/architecture"

  if [ -f "${target_dir}/docs/architecture/README.md" ]; then
    echo "  → docs/architecture/README.md already exists, skipping."
    return
  fi

  cat > "${target_dir}/docs/architecture/README.md" << HEREDOC
---
title: Architecture Overview
type: architecture
domain: ${domain}
created: $(date +%Y-%m-%d)
---

# Architecture Overview

## Project Identity

- Name: ${name}
- Domain: ${domain}
- Stack: ${stack}

## Stack

| Layer | Technology |
|-------|-----------|
| Backend | ${backend:-TBD} |
| Database | ${database:-TBD} |
| Infrastructure | ${infrastructure:-TBD} |

## Project Layout

\`\`\`
${name}/
  docs/
    architecture/     # topology, domain model, invariants
    adr/              # Architecture Decision Records
    specs/            # specifications (draft → review → approved → implemented)
    audits/           # audit reports, reality checks
    backlog/          # backlog, TODO, wishlist
    api/              # API documentation
  src/                # application source code
  tests/              # tests
  .context/           # runtime context
\`\`\`

## Boundaries

See \`.context/boundaries.yml\` for detailed boundary definitions.

- **Pristine**: ${name}/, src/, tests/, docs/, .context/
- **Editable**: docs/** (except runtime/)
- **Generated**: docs/.runtime/, node_modules/
- **Secret**: .env, *.key, *.pem

## See Also

- [ADR](../adr/) — Architecture Decision Records
- [Backlog](../backlog/) — TODO, Wishlist, Experiments
- [Boundaries](../../.context/boundaries.yml) — Boundary definitions
HEREDOC
  echo "  → docs/architecture/README.md created."
}
