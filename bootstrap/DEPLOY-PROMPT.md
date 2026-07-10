---
schema: 1
id: bootstrap-deploy-prompt
type: guide
kind: onboarding
status: active
date: 2026-07-09
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer]
tags: [bootstrap, deploy, prompt, agent, onboarding]
priority: P0
---

# Deploy Prompt for AI Agent

> Give this prompt to any AI agent (opencode, Claude Code, Cursor, etc.) to install,
> **update**, or **migrate** Documentation System Runtime v1.9 on any project. The agent
> auto-detects the project context, handles fresh install, v1.0/v1.1→v1.9 migration, and
> re-running on an existing install (update). After install it runs a post-install
> architecture check (Reality Engine drift report) and reports where the architecture breaks.

---

## Prompt

```
You are deploying (or updating) Documentation System Runtime (naprolom-docs v1.9) on the
current project.

## Step 0 — Detect project context

Run from the current working directory:

```bash
pwd && git rev-parse --show-toplevel 2>/dev/null && git remote -v | head -2
```

This tells you:
- Project root path
- Which git repo you're in
- Remote URL

Then check for existing Runtime installation:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
echo "=== .gitmodules ===" && cat "$PROJECT_ROOT/.gitmodules" 2>/dev/null || echo "none"
echo "=== existing docs/ ===" && ls "$PROJECT_ROOT/docs/" 2>/dev/null | head -10 || echo "no docs/"
echo "=== existing .context/runtime ===" && ls "$PROJECT_ROOT/.context/runtime/" 2>/dev/null | head -5 || echo "none"
echo "=== Runtime version ===" && [ -f "$PROJECT_ROOT/docs/.runtime/naprolom-docs/runtime/registry.yaml" ] && (grep -E 'version:' "$PROJECT_ROOT/docs/.runtime/naprolom-docs/runtime/registry.yaml" | head -1) || echo "v1.1 or earlier"
echo "=== CLAUDE.md ===" && [ -f "$PROJECT_ROOT/CLAUDE.md" ] && echo "exists" || echo "none"
echo "=== AGENTS.md ===" && [ -f "$PROJECT_ROOT/AGENTS.md" ] && echo "exists" || echo "none"
```

Report what you found and pick the path:
- Fresh project (no Runtime) → go to Step 1A (Fresh install)
- v1.0 installed (.context/runtime/) → go to Step 1B (Migrate from v1.0)
- v1.1 installed (docs/.runtime/naprolom-docs/ but no runtime/registry.yaml) → go to Step 1C (Migrate v1.1→v1.9)
- v1.2–v1.5 installed (registry.yaml exists, older runtime version) → go to Step 1C (auto-upgrade; registry-driven)
- v1.9+ already installed (registry.yaml exists, runtime version >= 1.9) → go to Step 3B (UPDATE, no reinstall)

## Step 1A — Fresh install

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"

mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master

git commit -m "chore: add Documentation System Runtime v1.9 via submodule"
```

## Step 1B — Migrate from v1.0

The old Runtime was mounted at `.context/runtime/naprolom-docs`. v1.9 mounts at `docs/.runtime/naprolom-docs`.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"

# Remove old submodule
git submodule deinit -f .context/runtime/naprolom-docs 2>/dev/null
git rm -f .context/runtime/naprolom-docs 2>/dev/null
rm -rf .git/modules/.context/runtime/naprolom-docs 2>/dev/null
rm -rf .context/runtime 2>/dev/null

# Add in v1.8 location
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master

git commit -m "chore: migrate naprolom-docs v1.0→v1.9 (docs/.runtime/ path)"
```

## Step 1C — Upgrade / migrate v1.1–v1.5 to v1.9 (AUTO-UPGRADE)

Bootstrap auto-upgrades any older installed version (v1.1, v1.2, v1.3, v1.4, v1.5) to v1.9.
Just pull the latest submodule and run bootstrap — it detects the old version and upgrades.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"

git submodule update --remote --merge
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
```

If auto-upgrade fails or the submodule is missing:

```bash
cd "$PROJECT_ROOT"
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
git submodule update --init --recursive
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
```

## Step 2 — Initialize submodule

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"
git submodule update --init --recursive

# Verify submodule is present
ls docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh || { echo "FAIL: submodule not initialized"; exit 1; }
```

## Step 3 — Run bootstrap (fresh / migrated)

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
```

What bootstrap creates:
- `docs/{architecture,adr,specs/...,audits,backlog,api}/` — 5-layer documentation structure
- `docs/architecture/entity-catalog.md` — domain entity catalog template (consumer fills in)
- `docs/architecture/invariants.md` — architecture invariants template (created by bootstrap on first run)
- `.context/{project.yml,boundaries.yml,agent-entry.md}` — AI agent entry stubs
- `CLAUDE.md` — Runtime instructions (PREPEND to existing file, never overwrite)
- `AGENTS.md` — Runtime instructions (only if file already exists, never create)
- `.github/workflows/docs-validate.yml` — CI guard (includes Runtime dependency graph validation)

## Step 3B — UPDATE existing v1.9+ installation

When v1.9+ is already installed, do NOT reinstall. Updating means pulling the latest
Runtime submodule and re-running bootstrap (it is idempotent and regenerates stubs):

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"

# Pull latest Runtime (bugfixes, new generators/detectors, Registry changes)
git submodule update --remote --merge

# Re-run bootstrap — idempotent: recreates missing stubs, preserves consumer content
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
```

If the Registry schema changed in the new version, bootstrap logs the Runtime mode
(NORMAL/DEGRADED) — a DEGRADED warning means registry.yaml is missing or unreadable;
investigate before continuing. After update, always run the post-install architecture
check (Step 4.5) to catch drift introduced by the upgrade.

## Step 4 — Verify

### 4.1 Structure check

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"

echo "=== consumer root directories ==="
ls -d */ | head -15

echo "=== docs/ contents ==="
ls docs/

echo "=== Runtime submodule ==="
ls docs/.runtime/naprolom-docs/ | head -10
```

### 4.2 CRITICAL: no Runtime dirs at root

These directories must NOT exist at project root (they live inside `docs/.runtime/naprolom-docs/`):

```bash
cd "$(git rev-parse --show-toplevel)"
FAIL=0
for d in agents knowledge sops engine documentation bootstrap playbook; do
  [ -d "$d" ] && echo "FAIL: $d/ exists at root" && FAIL=1 || echo "OK: no $d/"
done
[ $FAIL -eq 1 ] && echo "ABORT: Runtime directories leaked to root" || echo "PASS: all clean"
```

### 4.3 Frontmatter + Runtime validation

```bash
cd "$(git rev-parse --show-toplevel)"
bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh
bash docs/.runtime/naprolom-docs/documentation/validation/validate-runtime.sh
```

### 4.4 CLAUDE.md check

```bash
cd "$(git rev-parse --show-toplevel)"
grep -c "## Documentation Runtime" CLAUDE.md 2>/dev/null && echo "OK: snippet present" || echo "WARN: no Runtime snippet in CLAUDE.md"
head -10 CLAUDE.md 2>/dev/null || echo "no CLAUDE.md"
```

### 4.5 POST-INSTALL ARCHITECTURE CHECK (Reality Engine drift)

After install/update, run the Reality Engine to find where the architecture actually breaks
(dangling ADR references, docs missing required frontmatter, specs referencing superseded
specs, structure drift vs the Registry SSOT):

```bash
cd "$(git rev-parse --show-toplevel)"
bash docs/.runtime/naprolom-docs/engine/reality-engine/reporters/reality-report.sh "$PROJECT_ROOT"
```

Read the report. Report these drift findings to the user explicitly:
- **ADR drift** — documentation references an ADR id that does not exist (broken `depends_on`).
- **Documentation drift** — docs missing required frontmatter (schema/id/type) or unknown status.
- **Spec drift** — a spec's status does not match its directory, or docs still reference a superseded spec.
- **Structure drift** — expected top-level dirs (docs/, .context/) missing.

If drift items are present, list them as "architecture breakage points" with the file and
the specific issue. Do not silently fix them — surface them so the user decides. (python3 is
required for full drift parsing; without it the report falls back to a limited grep view.)

## Step 5 — Commit and report

```bash
cd "$(git rev-parse --show-toplevel)"
git add -A
git status --short
git diff --cached --stat
git commit -m "docs: Documentation System Runtime v1.9 installed" || echo "nothing to commit"
```

Do NOT push. Report to user:
1. Project path and repo
2. Action taken (fresh install / migrated from v1.0 / upgraded v1.1–v1.5→v1.9 / updated v1.9+)
3. Verification results (structure, root check, validation)
4. Post-install architecture check results — drift items (ADR / documentation / spec / structure)
5. Next steps: fill `.context/project.yml`, create first ADR, create `docs/architecture/README.md`,
   resolve any reported drift

## Rules

- NEVER edit files inside `docs/.runtime/naprolom-docs/` — it's a submodule, pristine zone
- NEVER create `agents/`, `knowledge/`, `sops/`, `engine/`, `documentation/`, `bootstrap/`, `playbook/` at project root
- All `.md` files in `docs/` must have Canonical Schema v1 frontmatter (6 mandatory fields)
- Do NOT copy templates from documentation/templates into the project — reference them via runtime path
- If anything fails — STOP and report, do not guess
```
