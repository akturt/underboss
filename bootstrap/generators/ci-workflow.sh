#!/bin/bash
# bootstrap/generators/ci-workflow.sh — Generate .github/workflows/docs-validate.yml
#
# API: generate TARGET REGISTRY

generate() {
  local target_dir="$1" registry="$2"

  local workflow_dir="${target_dir}/.github/workflows"
  mkdir -p "$workflow_dir"

  if [ -f "${workflow_dir}/docs-validate.yml" ]; then
    echo "  → .github/workflows/docs-validate.yml already exists, skipping."
    return
  fi

  cat > "${workflow_dir}/docs-validate.yml" << 'HEREDOC'
---
name: Documentation Validation

on:
  push:
    paths:
      - 'docs/**'
      - 'documentation/**'
      - 'agents/**'
      - 'knowledge/**'
      - 'sops/**'
      - 'bootstrap/**'
      - 'runtime/**'
      - 'engine/**'
  pull_request:
    paths:
      - 'docs/**'
      - 'documentation/**'
      - 'agents/**'
      - 'knowledge/**'
      - 'sops/**'
      - 'bootstrap/**'
      - 'runtime/**'
      - 'engine/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Validate frontmatter
        run: |
          if [ -f "docs/.runtime/documentation/validation/validate-frontmatter.sh" ]; then
            bash docs/.runtime/documentation/validation/validate-frontmatter.sh
          fi

      - name: Validate runtime integrity
        run: |
          if [ -f "docs/.runtime/documentation/validation/validate-runtime.sh" ]; then
            bash docs/.runtime/documentation/validation/validate-runtime.sh
          fi
HEREDOC
  echo "  → .github/workflows/docs-validate.yml created."
}
