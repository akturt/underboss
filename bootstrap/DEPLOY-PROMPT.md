---
schema: 1
id: bootstrap-deploy-prompt
type: guide
kind: onboarding
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer]
tags: [bootstrap, deploy, prompt, agent, onboarding]
priority: P0
---

# Deploy Prompt for AI Agent

> Give this prompt to any AI agent (opencode, Claude Code, Cursor, etc.) to install
> Documentation System Runtime v1.1 on any project. The agent auto-detects the project
> context and handles both fresh install and v1.0→v1.1 migration.

---

## Prompt

```
You are deploying Documentation System Runtime (naprolom-docs v1.1) on the current project.

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
echo "=== CLAUDE.md ===" && [ -f "$PROJECT_ROOT/CLAUDE.md" ] && echo "exists" || echo "none"
echo "=== AGENTS.md ===" && [ -f "$PROJECT_ROOT/AGENTS.md" ] && echo "exists" || echo "none"
```

Report what you found:
- Fresh project (no Runtime) → go to Step 1A
- v1.0 installed (.context/runtime/) → go to Step 1B
- v1.1 already installed (docs/.runtime/naprolom-docs/) → skip to Step 3

## Step 1A — Fresh install

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"

mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master

git commit -m "chore: add Documentation System Runtime v1.1 via submodule"
```

## Step 1B — Migrate from v1.0

The old Runtime was mounted at `.context/runtime/naprolom-docs`. v1.1 mounts at `docs/.runtime/naprolom-docs`.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"

# Remove old submodule
git submodule deinit -f .context/runtime/naprolom-docs 2>/dev/null
git rm -f .context/runtime/naprolom-docs 2>/dev/null
rm -rf .git/modules/.context/runtime/naprolom-docs 2>/dev/null
rm -rf .context/runtime 2>/dev/null

# Add in v1.1 location
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master

git commit -m "chore: migrate naprolom-docs v1.0→v1.1 (docs/.runtime/ path)"
```

## Step 2 — Initialize submodule

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"
git submodule update --init --recursive

# Verify submodule is present
ls docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh || { echo "FAIL: submodule not initialized"; exit 1; }
```

## Step 3 — Run bootstrap

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
```

What bootstrap creates:
- `docs/{architecture,adr,specs/...,audits,backlog,api}/` — 5-layer documentation structure
- `.context/{project.yml,boundaries.yml,agent-entry.md}` — AI agent entry stubs
- `CLAUDE.md` — Runtime instructions (PREPEND to existing file, never overwrite)
- `AGENTS.md` — Runtime instructions (only if file already exists, never create)
- `.github/workflows/docs-validate.yml` — CI guard

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
for d in agents knowledge sops engine bootstrap playbook; do
  [ -d "$d" ] && echo "FAIL: $d/ exists at root" && FAIL=1 || echo "OK: no $d/"
done
[ $FAIL -eq 1 ] && echo "ABORT: Runtime directories leaked to root" || echo "PASS: all clean"
```

### 4.3 Frontmatter validation

```bash
cd "$(git rev-parse --show-toplevel)"
bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh
```

### 4.4 CLAUDE.md check

```bash
cd "$(git rev-parse --show-toplevel)"
grep -c "## Documentation Runtime" CLAUDE.md 2>/dev/null && echo "OK: snippet present" || echo "WARN: no Runtime snippet in CLAUDE.md"
head -10 CLAUDE.md 2>/dev/null || echo "no CLAUDE.md"
```

## Step 5 — Commit and report

```bash
cd "$(git rev-parse --show-toplevel)"
git add -A
git status --short
git diff --cached --stat
git commit -m "docs: Documentation System Runtime v1.1 installed" || echo "nothing to commit"
```

Do NOT push. Report to user:
1. Project path and repo
2. Install type (fresh / migrated from v1.0 / already v1.1)
3. Verification results (structure, root check, validation)
4. Next steps: fill `.context/project.yml`, create first ADR, create `docs/architecture/README.md`

## Rules

- NEVER edit files inside `docs/.runtime/naprolom-docs/` — it's a submodule, pristine zone
- NEVER create `agents/`, `knowledge/`, `sops/`, `engine/`, `bootstrap/`, `playbook/` at project root
- All `.md` files in `docs/` must have Canonical Schema v1 frontmatter (6 mandatory fields)
- Do NOT copy templates from engine/templates into the project — reference them via runtime path
- If anything fails — STOP and report, do not guess
```
