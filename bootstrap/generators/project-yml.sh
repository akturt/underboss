#!/bin/bash
# bootstrap/generators/project-yml.sh — Auto-generate .context/project.yml
#
# Usage: generate_project_yml <target_dir> <stack> <domain> <name> <backend> <database> <infrastructure>

generate_project_yml() {
  local target_dir="$1" stack="$2" domain="$3" name="$4"
  local backend="${5:-}" database="${6:-}" infrastructure="${7:-}"

  mkdir -p "${target_dir}/.context"

  if [ -f "${target_dir}/.context/project.yml" ]; then
    echo "  → .context/project.yml already exists, skipping."
    return
  fi

  cat > "${target_dir}/.context/project.yml" << HEREDOC
---
name: ${name}
domain: ${domain}
stack: ${stack}
backend: ${backend:-}
database: ${database:-}
infrastructure: ${infrastructure:-}
maintainer: ${GIT_COMMITTER_NAME:-$(git -C "$target_dir" config user.name 2>/dev/null || echo "unknown")}

repository:
  owner: ${GIT_REPOSITORY_OWNER:-owner}
  name: ${name}
  branch: ${GIT_DEFAULT_BRANCH:-main}

boundaries:
  pristine:
    - ${target_dir}/
    - ${target_dir}/src/
    - ${target_dir}/tests/
    - ${target_dir}/docs/
  generated:
    - node_modules/
    - dist/
    - docs/.runtime/
  secrets:
    - .env
    - .env.*
    - *.key
    - *.pem
    - secrets/

reality:
  status: fresh
  lastCheck: null
  drift: []
HEREDOC

  echo "  → .context/project.yml created."
}
