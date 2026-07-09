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

Bootstrap installs and configures the Documentation System Runtime into a consumer project. As of v1.6, the bootstrap is a thin orchestrator that drives the **Runtime API** (`runtime/lib/`) — it contains no business logic and no hardcoded paths. All structure and behaviour is read from `runtime/registry.yaml`.

## Architecture (v1.6)

```
bootstrap/
  bootstrap.sh          ← orchestrator (~100 lines): sources api.sh, runs generators/detectors
  bootstrap.ps1         ← Windows PowerShell frontend (reads registry.yaml, same structure)
  install.sh            ← one-liner installer (curl | bash); uses Runtime API, no grep
  DEPLOY-PROMPT.md      ← agent deploy prompt
  generators/           ← standalone generator scripts (one file per artifact)
    architecture-readme.sh
    boundaries.sh
    project-yml.sh
    claude-md.sh
    ci-workflow.sh
  detectors/            ← stack detector plugins (one file per stack)
    node.sh, python.sh, go.sh, rust.sh, php.sh, docker.sh

runtime/
  lib/                  ← Runtime API (internal SDK)
    api.sh              ← unified entrypoint: sources all modules below
    yaml.sh             ← minimal YAML reader
    registry.sh         ← SSOT reader (all paths from registry.yaml)
    state.sh            ← install-state + version detection
    detectors.sh        ← detector plugin runner
    generators.sh       ← generator plugin runner
    components.sh        ← component verification
```

Any tool inside Runtime (`bootstrap`, `install`, `validate-runtime`, future `migrate`) sources `runtime/lib/api.sh` and therefore works identically:

```
bootstrap      → api.sh → registry → components
install        → api.sh → registry → bootstrap
validators     → api.sh → registry
```

## How It Works

1. **Parse arguments** — `--target <path>` (defaults to Runtime root)
2. **Source Runtime API** — `source runtime/lib/api.sh`
3. **Detect state** — `detect_state` reads filesystem → fresh/partial/legacy/broken
4. **Detect runtime mode** — `NORMAL` when `registry.yaml` is present, else `DEGRADED` (built-in fallback layout, still works)
5. **Create docs/ + .context/** — directory lists come from `registry_list_directories` (registry `directories:` section)
6. **Detect stack** — `detect_all` iterates detectors from registry, merges results
7. **Run generators** — `run_all_generators` iterates generators from registry
8. **Verify** — `components_verify` checks expected components exist

All paths are read from `runtime/registry.yaml` — the orchestrator knows nothing about structure.

## Runtime vs Bootstrap versions

Versions are decoupled (per Runtime API design):

- **Runtime** — `runtime.version` in registry.yaml
- **Bootstrap Engine** — `bootstrap.engine_version` in registry.yaml
- **Registry Schema** / **Contract Schema** — `schema.version` / `contracts.version`

`bootstrap.sh` prints both Runtime and Bootstrap Engine versions in its header.

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

Create `bootstrap/generators/<name>.sh` with a `generate()` function (signature `generate <target_dir> <registry>`). Register in `runtime/registry.yaml` under `generators:`. The orchestrator auto-runs it via `run_all_generators`.

## Related

- [Registry](../runtime/registry.yaml) — single source of truth
- [State Machine](../runtime/state-machine.yaml) — installation states
- [Installation Contract](../runtime/contracts/runtime/installation.yaml) — what bootstrap does
