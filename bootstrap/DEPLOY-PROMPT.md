---
schema: 1
id: underboss-deploy-prompt
type: guide
kind: onboarding
status: active
date: 2026-07-10
owners: [underboss-team]

entity_refs: [runtime-agentic-layer]
tags: [bootstrap, deploy, prompt, agent, onboarding, underboss, v2.0]
priority: P0
---

# Deploy Prompt for AI Agent — Underboss v2.0

> Give this entire document to an AI agent (opencode, Claude Code, Cursor, etc.)
> and say: **"Установи Underboss ."**
> The agent auto-detects the current state, runs the correct migration or install,
> verifies everything, and reports back. No questions asked.

---

## Prompt

```
You are installing Underboss Runtime (v2.0.0 "Consigliere") on this project.
Underboss is a project conciergerie: it knows the architecture, rules, processes,
invariants, and full context of the project. Documentation is one of its modules —
not the whole system.

Work autonomously — detect the current state, choose the correct path, execute it,
verify the result, commit locally, and report. Do NOT ask the user clarifying
questions; if something is ambiguous, pick the safest path and note it in the report.

═════════════════════════════════════════════════════════════
STEP 0 — Detect current state
═════════════════════════════════════════════════════════════

Run these commands from the current working directory:

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "NOT_A_GIT_REPO")
echo "Project root: $PROJECT_ROOT"

echo "=== .gitmodules ==="
cat "$PROJECT_ROOT/.gitmodules" 2>/dev/null || echo "none"

echo "=== existing docs/ ==="
ls "$PROJECT_ROOT/docs/" 2>/dev/null | head -10 || echo "no docs/"

echo "=== existing .context/runtime ==="
ls "$PROJECT_ROOT/.context/runtime/" 2>/dev/null | head -5 || echo "none"

echo "=== Underboss version (if already installed) ==="
if [ -f "$PROJECT_ROOT/docs/.runtime/underboss/runtime/registry.yaml" ]; then
  grep -E '^  version:' "$PROJECT_ROOT/docs/.runtime/underboss/runtime/registry.yaml" | head -1
  grep -E '^  name:' "$PROJECT_ROOT/docs/.runtime/underboss/runtime/registry.yaml" | head -1
else
  echo "not installed"
fi

echo "=== empty dirs in docs/ (pre-existing check) ==="
find "$PROJECT_ROOT/docs/" -type d -empty 2>/dev/null | grep -v "^$PROJECT_ROOT/docs/$" | head -20 || echo "none"

Based on the results, automatically choose ONE path:

┌─ What you found ─────────────────────────────────────────┬─ Path ─────────────────────────┐
│ Nothing — no Underboss at all                              │ Fresh install (Step A)         │
│ .context/runtime/ exists (v1.0 layout, underboss)      │ Migrate v1.0 → v2.0 (Step B)  │
│ docs/.runtime/underboss/ exists, no registry.yaml      │ Migrate v1.1–v1.9 → v2.0 (Step C) │
│ registry.yaml exists, version < 2.0.0                      │ Auto-upgrade to v2.0 (Step C) │
│ registry.yaml exists, version >= 2.0.0                     │ Update in-place (Step D)      │
└───────────────────────────────────────────────────────────┴────────────────────────────────┘

Do NOT ask the user which path to take. Decide and proceed.

CRITICAL: Underboss v2.0 uses submodule path docs/.runtime/underboss/
(not underboss). If migrating from v1.x, rename the submodule path.

═════════════════════════════════════════════════════════════
STEP A — Fresh install (no prior Underboss / underboss)
═════════════════════════════════════════════════════════════

cd "$PROJECT_ROOT"
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/underboss.git docs/.runtime/underboss
git config -f .gitmodules submodule."docs/.runtime/underboss".branch master
git commit -m "chore: add Underboss Runtime v2.0.0 via submodule"

═════════════════════════════════════════════════════════════
STEP B — Migrate from v1.0 (.context/runtime/, underboss naming)
═════════════════════════════════════════════════════════════

cd "$PROJECT_ROOT"
# Remove old v1.0 layout
git submodule deinit -f .context/runtime/underboss 2>/dev/null || true
git rm -f .context/runtime/underboss 2>/dev/null || true
rm -rf .git/modules/.context/runtime/underboss 2>/dev/null || true
rm -rf .context/runtime 2>/dev/null || true

# Install Underboss v2.0 at the correct path
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/underboss.git docs/.runtime/underboss
git config -f .gitmodules submodule."docs/.runtime/underboss".branch master
git commit -m "chore: migrate underboss v1.0 → Underboss v2.0.0 (docs/.runtime/underboss/)"

═════════════════════════════════════════════════════════════
STEP C — Auto-upgrade (v1.1–v1.9 underboss → Underboss v2.0)
═════════════════════════════════════════════════════════════

This is a PATH + NAME migration: the submodule moves from
docs/.runtime/underboss/ to docs/.runtime/underboss/ and the URL
changes from akturt/underboss to akturt/underboss.

cd "$PROJECT_ROOT"

# 1. If old submodule still registered — remove it first
if grep -q 'underboss' .gitmodules 2>/dev/null; then
  OLD_PATH=$(grep 'path = ' .gitmodules | grep underboss | head -1 | sed 's/path = //' | tr -d ' ')
  if [ -n "$OLD_PATH" ] && [ -d "$OLD_PATH" ]; then
    git submodule deinit -f "$OLD_PATH" 2>/dev/null || true
    git rm -f "$OLD_PATH" 2>/dev/null || true
    rm -rf ".git/modules/$(echo "$OLD_PATH" | sed 's|/|\\|g')" 2>/dev/null || true
    rm -rf "$OLD_PATH" 2>/dev/null || true
  fi
fi

# 2. Add Underboss at the new canonical path
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/underboss.git docs/.runtime/underboss
git config -f .gitmodules submodule."docs/.runtime/underboss".branch master

# 3. Run bootstrap — it detects the existing docs/ structure and upgrades idempotently
bash docs/.runtime/underboss/bootstrap/bootstrap.sh "$PROJECT_ROOT"

git commit -m "chore: upgrade underboss v1.x → Underboss v2.0.0"

═════════════════════════════════════════════════════════════
STEP D — Update existing Underboss v2.0 installation
═════════════════════════════════════════════════════════════

Do NOT reinstall. Pull the latest and re-run idempotent bootstrap:

cd "$PROJECT_ROOT"
git submodule update --remote --merge docs/.runtime/underboss
bash docs/.runtime/underboss/bootstrap/bootstrap.sh "$PROJECT_ROOT"

If bootstrap reports DEGRADED mode — stop and surface this as an error.
Do not continue silently in DEGRADED mode.

═════════════════════════════════════════════════════════════
STEP 4 — Post-install verification (ALL paths)
═════════════════════════════════════════════════════════════

── 4.1 CRITICAL: Runtime directories must NOT leak to project root ──

These directories live ONLY inside docs/.runtime/underboss/.
If any of them exists at the repo root, the previous install was broken — remove them.

FAIL=0
for d in agents knowledge sops engine documentation bootstrap playbook runtime; do
  [ -d "$PROJECT_ROOT/$d" ] && echo "FAIL: $PROJECT_ROOT/$d leaked to root" && FAIL=1 || echo "OK: no $PROJECT_ROOT/$d"
done
[ $FAIL -eq 1 ] && echo "ABORT: fix root leakage before continuing" || echo "PASS"

── 4.2 Required structure ──────────────────────────────────────

[ -f "$PROJECT_ROOT/docs/.runtime/underboss/bootstrap/bootstrap.sh" ] || { echo "FAIL"; exit 1; }
[ -f "$PROJECT_ROOT/docs/.runtime/underboss/runtime/registry.yaml" ] || { echo "FAIL"; exit 1; }

── 4.3 Empty-dir check after bootstrap ──────────────────────────

find "$PROJECT_ROOT/docs/" -type d -empty | grep -v "^$PROJECT_ROOT/docs/$"
# Any output here means there are empty directories in docs/.
# Underboss v2.0 has a registry_list_directories fix — no new empty dirs
# should be created. Pre-existing empty dirs are legitimate — verify against
# docs/.runtime/underboss/runtime/registry.yaml before deleting.

── 4.4 Validators ───────────────────────────────────────────────

cd "$PROJECT_ROOT"
bash docs/.runtime/underboss/documentation/validation/validate-frontmatter.sh
bash docs/.runtime/underboss/documentation/validation/validate-runtime.sh

Both must pass. If validate-runtime.sh reports errors — stop and report.

── 4.5 Reality Engine report (post-install drift check) ─────────

Run the Reality Engine to find architecture breakage points:

cd "$PROJECT_ROOT"
bash docs/.runtime/underboss/engine/reality-engine/reporters/reality-report.sh "$PROJECT_ROOT"

python3 is preferred for full drift parsing; without it the report falls back
to a limited grep view but still produces useful output.

Read the report. Report these to the user explicitly:

* ADR drift — docs reference an ADR id that does not exist
* Documentation drift — docs missing required frontmatter (schema/id/type)
* Spec drift — spec status does not match its directory
* Structure drift — expected top-level dirs (docs/, .context/) missing

List each item as "architecture breakage point" with the file path and issue.
Do NOT silently fix drift items — surface them so the user decides.

═════════════════════════════════════════════════════════════
STEP 5 — Commit and report
═════════════════════════════════════════════════════════════

cd "$PROJECT_ROOT"
git add -A
git status --short
git diff --cached --stat
git commit -m "docs: Underboss Runtime v2.0.0 installed" || echo "nothing to commit"

Do NOT push.

Report to the user:
1. Project path and git remote
2. Action taken (fresh install / migrated v1.0 / migrated v1.1–v1.9 / auto-upgraded / updated v2.0+)
3. Verification results (4.1 root check, 4.2 structure, 4.4 validators)
4. Post-install drift findings (ADR / documentation / spec / structure breakage points)
5. Next steps for the user:
   - Fill in .context/project.yml (project metadata)
   - Fill in .context/boundaries.yml (boundary definitions)
   - Create the first ADR from documentation/templates/adr.md
   - Resolve any reported drift items

═════════════════════════════════════════════════════════════
RULES (hard — do not violate)
═════════════════════════════════════════════════════════════

· NEVER create agents/, knowledge/, sops/, engine/, documentation/,
bootstrap/, playbook/, runtime/ at the project root.
They live ONLY inside docs/.runtime/underboss/.

· NEVER edit files inside docs/.runtime/underboss/.
It is a git submodule (pristine zone). Update it only via
`git submodule update --remote --merge` as a whole.

· NEVER copy templates from documentation/templates/ into the consumer
project and keep local duplicates. Use `cp` to create a new file
from the template once — the template itself is the source of truth
and lives in the submodule.

· The docs/ directory at the project root is for the CONSUMER'S content.
The only system-owned subdirectory is docs/.runtime/underboss/.
Everything else in docs/ (architecture/, adr/, specs/, audits/, etc.)
belongs to the project and bootstrap / Reality Engine will never touch it.

· All .md files in docs/ must have Canonical Schema v1 frontmatter
(6 mandatory fields: schema, id, type, status, date, owners).

· If bootstrap reports DEGRADED mode — STOP immediately and report.
DEGRADED means registry.yaml is missing or unreadable; do not guess.

· If anything fails — STOP and report the exact error and the step
where it happened. Do not silently skip steps or continue in an
unknown state.

· After install, do NOT exit without committing the submodule pointer
bump locally. The user must review and push the commit themselves.

```
