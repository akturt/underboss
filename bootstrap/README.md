---
schema: 1
id: bootstrap-readme
type: guide
status: active
date: 2026-07-09
owners: [naprolom-team]
entity_refs: [runtime, registry]
---

# Bootstrap — naprolom Documentation System Runtime

## Overview

Bootstrap installs and configures the Documentation System Runtime into a consumer project. As of v1.5, the bootstrap is decomposed into an orchestrator + lib modules + generator scripts + stack detector plugins.

## Architecture (v1.5)

```
bootstrap/
  bootstrap.sh          ← orchestrator (~96 lines): sources lib, runs generators
  bootstrap.ps1         ← Windows PowerShell mirror
  install.sh            ← one-liner installer (curl | bash)
  DEPLOY-PROMPT.md      ← agent deploy prompt
  lib/                  ← extracted modules
    registry.sh         ← SSOT reader (all paths from registry.yaml)
    detect-state.sh     ← state + version detection
    detect-stack.sh     ← plugin-based stack detection orchestrator
    verify.sh           ← post-bootstrap component verification
  generators/           ← standalone generator scripts
    architecture-readme.sh   ← generates docs/architecture/README.md
    boundaries.sh            ← generates .context/boundaries.yml
    project-yml.sh           ← generates .context/project.yml
    claude-md.sh             ← generates CLAUDE.md snippet
    ci-workflow.sh           ← generates .github/workflows/docs-validate.yml
  detectors/            ← stack detector plugins (one file per stack)
    node.sh, python.sh, go.sh, rust.sh, php.sh, docker.sh
  templates/
    entity-catalog.md   ← entity catalog template
```

## How It Works

1. **Parse arguments** — `--target <path>` (defaults to Runtime root)
2. **Source lib modules** — registry parser, state detector, stack detector, verifier
3. **Source generators** — all `generators/*.sh` scripts
4. **Detect state** — reads filesystem to determine fresh/installed/partial/legacy/broken
5. **Detect stack** — iterates detectors from registry, runs each, merges results
6. **Create docs/ skeleton** — architecture, adr, specs, audits, backlog, api
7. **Run generators** — architecture-readme, boundaries, project-yml, claude-md, ci-workflow
8. **Verify** — checks all expected components exist

All paths are read from `runtime/registry.yaml` — no hardcoded paths in the orchestrator.

## Adding a New Stack Detector

Create `bootstrap/detectors/<name>.sh`:

```bash
#!/bin/bash
detect() {
  local backend="" database="" infrastructure=""
  [ -f "$TARGET/your-lockfile" ] && backend="YourStack"
  echo "$backend|$database|$infrastructure"
}
```

Register in `runtime/registry.yaml` under `detectors:`.

## Adding a New Generator

Create `bootstrap/generators/<name>.sh` with a `generate_<name>()` function. The orchestrator auto-sources all `generators/*.sh` files.

## Related

- [Registry](../runtime/registry.yaml) — single source of truth
- [State Machine](../runtime/state-machine.yaml) — installation states
- [Installation Contract](../runtime/contracts/runtime/installation.yaml) — what bootstrap does
