#!/bin/bash
# runtime/lib/api.sh — Unified Runtime API (internal SDK)
#
# Single entrypoint that loads the entire Runtime API. Every tool inside
# Runtime (bootstrap, install, validators, future migrate) sources THIS file
# instead of the individual lib modules, so they all behave identically:
#
#   source "${RUNTIME_ROOT}/runtime/lib/api.sh"
#
# Provides: yaml, registry, state, detectors, generators, components.
#
# The caller may pre-set RUNTIME_ROOT; otherwise it is derived from this file.

RUNTIME_ROOT="${RUNTIME_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

source "${RUNTIME_ROOT}/runtime/lib/yaml.sh"
source "${RUNTIME_ROOT}/runtime/lib/registry.sh"
source "${RUNTIME_ROOT}/runtime/lib/state.sh"
source "${RUNTIME_ROOT}/runtime/lib/detectors.sh"
source "${RUNTIME_ROOT}/runtime/lib/generators.sh"
source "${RUNTIME_ROOT}/runtime/lib/components.sh"
