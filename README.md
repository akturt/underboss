---
schema: 1
id: readme-runtime
type: guide
kind: index
status: active
date: 2026-07-10
updated: 2026-07-10
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

**Turns documentation into infrastructure**, not a dump of `.md` files.
Canonical Schema v1, lifecycle from path, 5-layer architecture, CI guard.

Runtime v1.9 architecture: **Runtime Core** (runtime/, bootstrap/, engine/) +
**Documentation Module** (documentation/, knowledge/, agents/, sops/, playbook/).
Connected as a Git Submodule — one runtime for the whole ecosystem.

> **Proof:** the Kordon/MegaDelta project — 141 chaotic files → 40 canonical in 30
> minutes and one prompt. Onboarding reduced from 2–5 days to 5 minutes, LLM context
> 73% lighter, prompt cost 80% lower. See `docs/audits/`.
>
> **To install:** give your AI agent the link to this repo
> (`https://github.com/akturt/naprolom-docs`) and say:
> **"Установи Documentation System Runtime."**
> The agent reads `bootstrap/DEPLOY-PROMPT.md` and does everything automatically.
> Or run the one-liner:
> `bash <(curl -s https://raw.githubusercontent.com/akturt/naprolom-docs/master/bootstrap/install.sh)`

---

## What this is

`naprolom-docs` is a **Documentation System Runtime**: not a set of prompts and
not a README template. It is a versioned engine that any of your projects connects
as a Git Submodule and gets:

- **Canonical Schema v1** — a single frontmatter format for all `.md` in `docs/`
  (6 required fields, zero legacy fields).
- **Lifecycle from path** — spec/api status is determined by the directory
  (`drafts/` → `draft`, `approved/` → `approved`), not an editable field.
- **5-layer architecture** — Entry (`.context/`) → Architecture → ADR → Spec → Operations.
  Navigation by structure, not by `grep`.
- **CI guard** — no `.md` without canonical frontmatter will enter the repository.
- **Runnable migration** — `engine/scripts/migrate-legacy.mjs` converts legacy FM to
  Schema v1 with `TODO_ENTITY_REF` markers for manual review.
- **SOPs** — declarative descriptions of standard development processes in `sops/*.yaml`.
  `sops/planner.mjs` prints an execution DAG by input entity type.
- **Reality Engine** — reconstructs project state and detects drift (`engine/reality-engine/`).
- **Registry** — single source of truth for all Runtime components (`runtime/registry.yaml`).

---

## How to connect

### Option 1 — AI agent (recommended)

Give your AI agent the link to this repo and say:

> **"Установи Documentation System Runtime на этот проект."**

That's it. The agent reads [`bootstrap/DEPLOY-PROMPT.md`](bootstrap/DEPLOY-PROMPT.md),
detects the current state (fresh install / v1.0 migration / v1.1–v1.8 auto-upgrade /
v1.9 update), executes the correct path, runs all verifications, and reports back.
Works with opencode, Claude Code, Cursor, and any other agent that can run shell commands.

### Option 2 — One-liner

```bash
bash <(curl -s https://raw.githubusercontent.com/akturt/naprolom-docs/master/bootstrap/install.sh)
```

### Option 3 — Manual

```bash
# 1. Add submodule INSIDE docs/
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
git commit -m "chore: add Documentation System Runtime via submodule"

# 2. Run bootstrap
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh

# 3. Fill in .context/project.yml and .context/boundaries.yml
```

**Brownfield repo** (already has `docs/` with `.md` files)?
Follow [`playbook/migrate-legacy.md`](playbook/migrate-legacy.md) — 7-step agent prompt
with runnable migration script. Don't run `bootstrap.sh` directly on brownfield.

Full details: [`INSTALL.md`](INSTALL.md).

---

## What is included (Runtime layout)

```
naprolom-docs/ ← product repo
├── README.md              ← this file
├── INSTALL.md             ← consumer integration guide
├── bootstrap/             ← Runtime Core: loader, install one-liner, deploy prompt
├── runtime/               ← Runtime Core: registry, state machine, contracts, API
├── engine/                ← Runtime Core: Reality Engine + migration script
├── documentation/         ← Documentation Module: templates, validation, schemas
├── knowledge/             ← Documentation Module: principles, capabilities
├── agents/                ← Documentation Module: claude-code + opencode roles
├── sops/                  ← Documentation Module: YAML process descriptions
├── playbook/              ← Documentation Module: greenfield + brownfield guides
├── docs/                  ← dogfood: Runtime's own audits, ADRs, specs
└── .github/workflows/     ← CI guard
```

> **Note:** In consumer repos only `docs/` appears at the root.
> Everything else lives inside `docs/.runtime/naprolom-docs/` (git submodule).
> See the Two-repo model in [`INSTALL.md`](INSTALL.md).

---

## Updating

```bash
# Manually (five seconds, recommended)
git submodule update --remote --merge
git add docs/.runtime/naprolom-docs
git commit -m "chore: update Documentation System Runtime"
```

Or re-run bootstrap — it detects the current version and updates idempotently:

```bash
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
```

Details: [`bootstrap/DEPLOY-PROMPT.md`](bootstrap/DEPLOY-PROMPT.md).

---

## Changelog

- **2026-07-10** — **v1.9 — Bash prefix in reality-report.sh + registry bugfix**.
  Fixed `reality-report.sh` calling collectors/analyzers without `bash` prefix
  (Permission denied on Linux/macOS). Fixed `registry_list_directories` returning
  non-path YAML keys, which caused empty dirs in `docs/`. Bootstrap v1.9 creates
  no spurious empty directories.
- **2026-07-09** — **v1.8 — Architecture Invariants Support**.
  Unified architecture invariants document; template + bootstrap generator;
  informational Reality Report check for `docs/architecture/invariants.md`.
- **2026-07-09** — **v1.6 — Runtime API & Orchestrator Maturity**.
  `bootstrap/lib/*` → `runtime/lib/*`, unified `api.sh`, DEGRADED mode,
  versions decoupled (Runtime 1.6 / Bootstrap Engine 2.0).
- **2026-07-09** — **v1.5 — Module Decomposition + Registry SSOT**.
  Bootstrap decomposed into detectors/generators, Registry became the single
  source of truth for all paths, modules split into Runtime Core + Documentation Module.
- **2026-07-08** — **v1.2 — Operating Platform**.
  Registry, state machine, contracts, Reality Engine, self-validation.
- **2026-07-08** — **v1.1 — Agentic Layer Separation**.
  Knowledge, Roles, Capabilities, SOPs, Artifacts as first-class entities.
- **2026-07-07** — initial commit.

---

## Repository status

| Stage | State |
|------|-------|
| Runtime v1.0–v1.9 | ✅ implemented |
| Playbook v2 (greenfield model) | ✅ implemented |
| Migration Prompt (brownfield) | ✅ implemented |
| Bootstrap (idempotent, POSIX + Windows) | ✅ implemented |
| agents/ (claude-code, opencode: 4 roles) | ✅ implemented |
| SOPs (10 protocols + planner) | ✅ implemented |
| knowledge/ (5 files, capability catalog) | ✅ implemented |
| Reality Engine (collectors, analyzers, reporters) | ✅ implemented |
| CI guard (validate-frontmatter + validate-runtime) | ✅ implemented |
| Dogfooding on production projects | ✅ active |
