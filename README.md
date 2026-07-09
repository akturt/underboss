---
schema: 1
id: readme-runtime
type: guide
kind: index
status: active
date: 2026-07-09
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer, schema-v1, canonical-frontmatter]
touches: []
docs: [INSTALL.md, playbook/playbook-v2.md, playbook/migrate-legacy.md]
refs: []
depends_on: []
tags: [runtime, index, landing]
priority: P0
---

# naprolom-docs — Documentation System Runtime

**Turns documentation into infrastructure**, not a dump of `.md` files. Canonical Schema v1, lifecycle from path, 5-layer architecture, CI guard. Runtime v1.7 architecture: **Runtime Core** (infrastructure layer: runtime/, bootstrap/, engine/) + **Documentation Module** (documentation layer: documentation/, knowledge/, agents/, sops/, playbook/). Connected as a Git Submodule — one runtime for the whole ecosystem.

> **Proof:** the Kordon/MegaDelta project — 141 chaotic files → 40 canonical in 30 minutes and one prompt. Onboarding reduced from 2–5 days to 5 minutes, LLM context 73% lighter, prompt cost 80% lower. See `docs/audits/`.

> **To install in your project:** copy the prompt from [`bootstrap/DEPLOY-PROMPT.md`](bootstrap/DEPLOY-PROMPT.md) and give it to an AI agent (opencode, Claude Code, Cursor). The agent will automatically detect the project type, connect the submodule, and deploy the system. Or use the one-liner: `bash <(curl -s https://raw.githubusercontent.com/akturt/naprolom-docs/master/bootstrap/install.sh)`

---

## What this is

`naprolom-docs` is a **Documentation System Runtime**: not a set of prompts and not a README template. It is a versioned engine that any of your projects connects as a Git Submodule and gets:

- **Canonical Schema v1** — a single frontmatter format for all `.md` in `docs/` (6 required fields, zero legacy fields).
- **Lifecycle from path** — spec/api status is determined by the directory (`drafts/` → `draft`, `approved/` → `approved`), not an editable field. AI distinguishes current from stale programmatically.
- **5-layer architecture** — Entry (`.context/`) → Architecture → ADR → Spec → Operations. Navigation by structure, not by `grep`.
- **CI guard** — no `.md` without canonical frontmatter will enter the repository.
- **Runnable migration** — for brownfield repositories: `engine/scripts/migrate-legacy.mjs` converts legacy FM to Schema v1 with `TODO_ENTITY_REF` markers for manual review.
- **SOPs** — declarative descriptions of standard development processes in `sops/*.yaml` (New Feature, Bugfix, Release, Incident, etc.). The `sops/planner.mjs` planner prints an execution DAG by input entity type. Roles are referenced by name (from `agents/`) or `human`.
- **Reality Engine** — engine for reconstructing project state and detecting drift (`engine/reality-engine/`). Used by the `reality-audit.yaml` SOP.
- **Registry** — single source of truth for all Runtime Core components (`runtime/registry.yaml`).

---

## How to connect

### Quick way (one-liner)

```bash
bash <(curl -s https://raw.githubusercontent.com/akturt/naprolom-docs/master/bootstrap/install.sh)
```

### Manual way

> **v1.5:** The Runtime connects **inside `docs/`**, not in `.context/runtime/`. Only `docs/` remains at the consumer repo root — no utility directories `agents/`, `knowledge/`, `sops/`, `engine/`, `bootstrap/`. See the Two-repo model in `docs/specs/approved/2026-07-08-agentic-layer.md`.

```bash
# 1. Connect the submodule INSIDE docs/
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master

# 2. Run bootstrap (creates docs/ skeleton, .context/, CLAUDE.md snippet, CI workflow)
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh

# 3. Fill in .context/project.yml and .context/boundaries.yml for your project

# 4. Create the first document from a template
cp docs/.runtime/naprolom-docs/documentation/templates/adr.md docs/adr/001-orchestrator-choice.md
```

**Full instructions with troubleshooting and edge-cases** → [`bootstrap/DEPLOY-PROMPT.md`](bootstrap/DEPLOY-PROMPT.md).

**Brownfield?** If the repo already has `docs/` with `.md` files, follow the agent prompt [`playbook/migrate-legacy.md`](playbook/migrate-legacy.md), not `bootstrap.sh`.

---

## What is included (Runtime layout)

```
naprolom-docs/                                  ← product repo (product layout; D-BR — in consumer repo everything is localized under docs/)
├── README.md                              ← this file (landing page)
├── INSTALL.md                             ← consumer integration (submodule + bootstrap)
├── playbook/
│   ├── playbook-v2.md                      ← target Greenfield model (Schema v1, lifecycle, CI)
│   └── migrate-legacy.md                   ← brownfield agent prompt (7 steps with checkpoints)
├── runtime/                                ← [Runtime Core — Infrastructure]
│   ├── registry.yaml                       ← v1.5: single source of truth for all Runtime Core components
│   ├── state-machine.yaml                  ← v1.5: installation states and transitions
│   └── contracts/                          ← v1.5: contracts (runtime/ + consumer/)
│       ├── runtime/{installation,migration,validation}.yaml
│       └── consumer/{boundaries,project-layout}.yaml
├── documentation/                          ← [Documentation Module]
│   ├── templates/                          ← canonical Schema v1 templates (NEVER copy into project)
│   │   ├── architecture.md  adr.md  spec.md
│   │   └── audit.md  runbook.md  backlog.md
│   ├── validation/
│   │   ├── validate-frontmatter.sh         ← frontmatter-only (awk), WARN_ONLY switch, path-status match
│   │   └── validate-runtime.sh             ← v1.5: Runtime dependency graph validation
│   └── schemas/
│       └── frontmatter.schema.json         ← JSON Schema (base + per-type extensions + forbidden legacy)
├── engine/                                 ← [Runtime Core — Infrastructure]
│   ├── reality-engine/                     ← v1.5: state reconstruction engine
│   │   ├── collectors/                     ← data collection (architecture, entity, module, dependency)
│   │   ├── analyzers/                      ← drift analysis (documentation, adr, spec)
│   │   ├── reporters/                      ← report generation
│   │   └── README.md
│   └── scripts/
│       └── migrate-legacy.mjs              ← runnable brownfield migration (no external dependencies)
├── bootstrap/                              ← [Runtime Core — Infrastructure]
│   ├── bootstrap.sh                        ← v1.5: registry-driven universal loader
│   ├── install.sh                          ← v1.5: one-liner installer
│   ├── templates/
│   │   └── entity-catalog.md               ← v1.5: entity catalog template
│   └── DEPLOY-PROMPT.md                    ← prompt for AI agent: auto-install on any project
├── knowledge/                              ← [Documentation Module] shared knowledge layer (roles connect by short-id)
│   ├── architecture-principles.md
│   ├── evidence-model.md
│   ├── audit-principles.md
│   ├── report-formats.md
│   └── capabilities.md                     ← capability catalog (without providers, D-CP)
├── agents/                                 ← [Documentation Module] AI agent roles for claude-code and opencode (4 roles, slim)
│   └── README.md                           ← capabilities overview, pointer to knowledge/capabilities.md
├── sops/                                   ← [Documentation Module] Standard Operating Procedures (YAML) + planner.mjs
│   ├── planner.mjs                         ← prints DAG (DAG-printer, not executor)
│   ├── reality-audit.yaml                  ← v1.5: SOP uses Reality Engine
│   └── *.yaml                              ← new-feature / bugfix / new-service / architecture-change / audit / release / incident / architecture-review / forensic-audit
├── docs/                                   ← dogfood: Runtime's own documentation
│   ├── adr/                                ← dogfood ADRs (001-agentic-layer-separation, 002-runtime-v1.2)
│   ├── audits/                             ← value-proof cases (e.g. Kordon/MegaDelta)
│   └── specs/approved/                     ← Runtime v1.x specs
└── .github/workflows/docs-validate.yml     ← CI guard + validate-runtime + knowledge/ validation
```

> **Note:** this layout describes the `naprolom-docs` product repository. In the consumer repository (after `bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh`) you will only see `docs/` at the root plus `docs/.runtime/naprolom-docs/...` where the submodule with all Runtime content lives. See the "Two-repo model" section in INSTALL.md.

---

## Quick Start

### Greenfield (new repo)

```bash
git clone your-new-repo && cd your-new-repo
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
# → docs/, .context/, CLAUDE.md, docs-validate.yml created
# → fill in .context/project.yml, create the first ADR from a template
git add -A && git commit -m "chore: bootstrap documentation runtime"
```

### Brownfield (repo with existing documentation)

```bash
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master

# Run the migration (dry-run first!)
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --dry-run
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --owner your-team
# → covered TODO_ENTITY_REF markers go to manual review

# Enable warn-only CI for 3–7 days → cleanup forgotten docs → strict
```

See [`playbook/migrate-legacy.md`](playbook/migrate-legacy.md) — 7 steps with checkpoints for the agent.

---

## Updating the Runtime

```bash
# Option A — manually (five seconds, recommended)
git submodule update --remote --merge
git add docs/.runtime/naprolom-docs
git commit -m "chore: update Documentation System Runtime"
```

```yaml
# Option B — Dependabot gitsubmodule (auto-PR)
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "gitsubmodule"
    directory: "/"
    schedule:
      interval: weekly
```

**Or via bootstrap** — run `bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh` and it will automatically detect the version and update the components.

Details: [`bootstrap/DEPLOY-PROMPT.md`](bootstrap/DEPLOY-PROMPT.md).

---

## Playbook

Target model (what "Documentation System is adopted" means):
- **[`playbook/playbook-v2.md`](playbook/playbook-v2.md)** — Greenfield model: Canonical Schema v1, 5-layer architecture, entity_refs workflow, lifecycle from path, CI guard, readiness metrics.
- **[`playbook/migrate-legacy.md`](playbook/migrate-legacy.md)** — Brownfield agent prompt: 7 steps, runnable migration script, warn-only → strict rollout.
- **[`bootstrap/DEPLOY-PROMPT.md`](bootstrap/DEPLOY-PROMPT.md)** — Prompt for the AI agent: auto-install on any project (fresh, v1.0 migration, v1.1 auto-upgrade).

---

## SOP (Standard Operating Procedures)

`sops/` — declarative descriptions of standard development processes as YAML. Not execution — description:
- `new-feature.yaml`, `bugfix.yaml`, `new-service.yaml`, `architecture-change.yaml`, `audit.yaml`, `release.yaml`, `incident.yaml`.
- `reality-audit.yaml` — v1.5: SOP uses the Reality Engine to reconstruct project state.
- Each is a DAG of steps with references to roles from `agents/{platform}/` or `human`.
- `sops/planner.mjs` — prints a sequence of steps with parallel groups by input type.

```bash
# List available SOPs
node sops/planner.mjs

# Execution plan for new-feature (shows role + parallelism)
node sops/planner.mjs new-feature --platform claude-code

# Only AI agent roles (without human steps) — to understand what to run
node sops/planner.mjs new-feature --hide-human
```

For now, execution is manual via slash commands (`/architecture-reviewer`, `/documentation-reviewer` in Claude Code; `@architecture-reviewer`, `@documentation-reviewer` in opencode). An SOP works as a checklist of "what and in what order to invoke for a given work type". Future Tier 2 — slash-command bindings, CI step integration.

---

## Why a Git Submodule, not npm/pip/git-release

- **Does not require a Node.js/Python/Go toolchain** in the project — works for FastAPI, Go, Rust, Terraform, Ansible.
- **Pinned to a commit SHA** — reproducibility, trivial rollback.
- **Updated at your discretion** — no automatic registry pull that could break the project.
- **Does not clutter the main repo** — Runtime lives in `docs/.runtime/`, and the consumer root contains only `docs/` (v1.1, D-BR; still valid in v1.5 — Runtime Core + Documentation Module localized inside the submodule). Before v1.0 it used `.context/runtime/`; in v1.1 this was deprecated in favor of localization inside `docs/`.
- **Matches your GitOps/IaC stack** — single source of truth, updates via PR review.

Alternatives (npm package, GitHub Releases + curl) were considered and rejected: coupling to a toolchain either breaks portability or loses reproducibility.

---

## Update strategy

- **`naprolom-docs`** — the single source of truth, developed independently in this repository.
- **Each consumer** connects it as a Git Submodule pinned to `branch = master` in `.gitmodules`.
- **Updates propagate only via PR:** the new submodule SHA arrives in the dependent repo (manually or via Dependabot) → review → merge. No direct commits to the consumer project's master.
- **Goal:** a single Documentation System across the whole ecosystem without version drift.

---

## Repository status

| Stage | State |
|------|-----------|
| Runtime v1.0 (bootstrap, documentation, engine, templates, schemas, validators) | ✅ implemented |
| Playbook v2 (greenfield model) | ✅ implemented |
| Migration Prompt (brownfield agent prompt) | ✅ implemented |
| Bootstrap (.sh + .ps1, idempotent) | ✅ implemented, tested on POSIX and Windows |
| agents/ (claude-code, opencode: 4 roles) | ✅ implemented |
| SOPs (8 protocols + planner.mjs) | ✅ implemented |
| knowledge/ (5 files, capability catalog) | ✅ implemented |
| **Runtime v1.2 — Operating Platform** | ✅ implemented |
| Reality Engine (collectors, analyzers, reporters) | ✅ stubs, architecture defined |
| CI guard (validate-frontmatter + validate-runtime) | ✅ implemented |
| install.sh (one-liner) | ✅ implemented |
| **Runtime v1.5 — Module Decomposition** | ✅ implemented |
| **Dogfooding on a real project** | ✅ first consumer updated to v1.5 |

---

## Changelog

- **2026-07-09** — **v1.7 — Architecture Invariants Support**. Added a unified architectural invariants document. Template `documentation/templates/invariants.md`; bootstrap creates `docs/architecture/invariants.md` on first run (like `entity-catalog.md`). Recommended architecture catalog contents: `README.md`, `entity-catalog.md`, `invariants.md`. The Reality Report gained an informational check for the presence of `invariants.md` (INFO, not ERROR/FAIL). No new architecture, modules, or registry sections — only template + generator + documentation.
- **2026-07-09** — **v1.6 — Runtime API & Orchestrator Maturity**. `bootstrap/lib/*` moved to `runtime/lib/*` — Runtime is now an internal SDK, not a set of scripts. Added `runtime/lib/api.sh` — a single entry point sourced by bootstrap/install/validators. `bootstrap.sh` became a pure orchestrator (~102 lines): `source api.sh`, then `detect_state` → `detect_all` → `run_all_generators` → `components_verify`; without business logic or hardcoded paths (structure is read from `registry.yaml`). `registry.yaml` finally became the Runtime API: `directories:`, `generators:`, `detectors:`, `entrypoints:`, versions. `bootstrap/install.sh` rewritten on the Runtime API (no grep/sed/head). Added DEGRADED mode: when `registry.yaml` is missing, bootstrap works via a built-in fallback layout with an explicit warning. Versions decoupled: Runtime 1.6 / Bootstrap Engine 2.0. All validators pass (16 checks).
- **2026-07-09** — **v1.5 — Bootstrap Decomposition + Registry SSOT**. Bootstrap.sh decomposed: from a monolith (637 lines) extracted `bootstrap/lib/` (registry.sh, detect-state.sh, detect-stack.sh, verify.sh) and `bootstrap/generators/` (5 scripts: architecture-readme, boundaries, project-yml, claude-md, ci-workflow). Stack detectors moved to `bootstrap/detectors/` as plugins (node, python, go, rust, php, docker) — adding a new stack = one file. Registry extended: `schema:`, `contracts:`, `directories:`, `templates:`, `validators:`, `generators:`, `scripts:`, `detectors:`, `components:` — bootstrap/install/validators read all paths from one SSOT. Bootstrap orchestrator reduced to ~90 lines. All validators pass (16 checks).
- **2026-07-09** — **v1.2.1 — Post-Deployment Fixes**. Fixed subshell bug in validate-runtime.sh (fail flag lost in pipe → CI always passed). Fixed CI: added `submodules: true` to checkout, added missing trigger paths (validators, bootstrap, sops, agents). Entity resolution extended: registry components + concept entities now resolve in entity_refs. Bootstrap: merged detect_state + detect_version, added auto-upgrade v1.1→v1.2. Added install.sh one-liner. Registry: removed duplication from agents, added engine section. Removed redundant state-machine contract. DEPLOY-PROMPT.md updated to v1.2.1.
- **2026-07-09** — **v1.5 — Module Decomposition**. Runtime split into Runtime Core and Documentation Module. `engine/templates/`, `engine/validators/`, `engine/schemas/` moved to `documentation/`. `engine/` contains only `reality-engine/` and `scripts/`. Registry: `modules:` → `composition:`, added `entrypoints:`. State machine: removed transient `updated` state (5 persistent states). Project layout: `no_root_level:` → `allowed_root:`. Migration: added `requires_bootstrap`, `requires_manual_actions`, `requires_consumer_changes`, `breaking` flags. Installation: `template_sources` removed, bootstrap reads from registry. All validators pass (14 checks).
- **2026-07-08** — **v1.2 — Operating Platform**. Registry as single source of truth (`runtime/registry.yaml`). State machine with 6 states. Contracts split into runtime/ and consumer/. Reality Engine extracted into a standalone engine (`engine/reality-engine/`). Self-validation: `validate-runtime.sh` checks 10 dependency-graph categories. CI workflow updated: +runtime/** paths, +validate-runtime step. ADR 002 documenting v1.2.
- **2026-07-08** — **v1.1 — Agentic Layer Separation**. Five first-class entities: **Knowledge** (`knowledge/` — 4 principle files + capabilities.md), **Role** (slim roles in `agents/`, +2 new: `reality-auditor`, `adversary-checker`), **Capability** (what it can do; one-way Role→Capability, catalog in `knowledge/capabilities.md` without `provided by:`), **SOP** (declarative DAG with artifact-contracts; gate:manual instead of role:human), **Artifact** (what travels between steps — reality-report, architecture-findings, validated-findings, forensic-report). Two new SOPs: `architecture-review.yaml` (sequential Reality→Arch→Doc→Adversary-optional→human) and `forensic-audit.yaml` (8-step pipeline, replaces the former forensic-orchestrator). `sops/planner.mjs` remains a DAG-printer (NOT executor), extended to read `capability:`/`consumes:`/`produces:`/`gate:`. **D-BR: bootstrap deploys the Runtime in `docs/.runtime/naprolom-docs/`, NOT in `.context/runtime/`** — the consumer root contains only `docs/`. See `docs/specs/approved/2026-07-08-agentic-layer.md` and `docs/adr/001-agentic-layer-separation.md` (dogfood).
- **2026-07-08** — **SOP layer (Tier 1.5)**: introduced the fourth layer `sops/` — declarative YAML descriptions of standard development processes. 7 protocols: `new-feature`, `bugfix`, `new-service`, `architecture-change`, `audit`, `release`, `incident`. `sops/planner.mjs` — a simple node script that prints an execution DAG by input type (parallel groups from `depends_on`). Roles in SOPs reference `agents/{claude-code,opencode}/` by name (`architecture-reviewer`, `documentation-reviewer`) or `human` for manual steps. No runtime/DB/Temporal/LangGraph — just YAML + planner. Execution is manual via slash commands for now; slash-command bindings — Tier 2 after dogfooding. README supplemented with an "SOP" section and mentioned in the four-layer model: Runtime → Documentation Module → AI Layer → SOP Layer.
- **2026-07-08** — **Documentation Module layering**: `templates/`, `schemas/`, `validation/` grouped under `documentation/` (Documentation Module layer). `engine/` contains `reality-engine/` and `scripts/` (engine and utilities). `bootstrap/` raised alongside at root (Runtime level). `agents/` remains as an independent AI layer. All consumer-facing paths in INSTALL, README, playbook, migrate-legacy, bootstrap.sh, bootstrap.ps1, workflow and agents updated to `documentation/...` and `engine/...` prefixes. Eliminated the visual drift of a "dump of directories at root"; the root now reads as a three-layer model: Runtime → Documentation Module → AI Layer.
- **2026-07-08** — **Runtime refactor v1.0**: repository turned from a set of prompts into a Documentation System Runtime. Structure `playbook/`, `bootstrap/`, `templates/`, `schemas/`, `validators/`, `scripts/`, `agents/`, `docs/`. Created `INSTALL.md` as consumer-integration document. Playbook moved out of root, §Bootstrap and §Result rewritten to current paths. CI guard now calls `documentation/validation/validate-frontmatter.sh` (single source of truth). Created runnable `scripts/migrate-legacy.mjs` for brownfield migration. Added `bootstrap/bootstrap.sh` and `bootstrap.ps1` (idempotent, minimal). Adoption Guide reformatted as agent prompt `playbook/migrate-legacy.md`.
- **2026-07-07** — v2 split: manual rewritten as Greenfield Playbook; Adoption Guide separated (brownfield); added Value Proof case Kordon/MegaDelta; README rewritten with index, Why-section and pitch. CI guard fixed (frontmatter-only, no false positives); `WARN_ONLY` switch for brownfield rollout.
- **2026-07-07** — initial commit: README + Playbook v2 (greenfield model).
