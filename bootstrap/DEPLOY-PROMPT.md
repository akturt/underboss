---
schema: 1
id: bootstrap-deploy-prompt
type: guide
kind: onboarding
status: active
date: 2026-07-10
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer]
tags: [bootstrap, deploy, prompt, agent, onboarding]
priority: P0
---

# Deploy Prompt for AI Agent

> Give this entire document to an AI agent (opencode, Claude Code, Cursor, etc.)
> and say: **"Установи Documentation System Runtime на этот проект."**
> The agent auto-detects the current state, runs the correct migration or install,
> verifies everything, and reports back. No questions asked.

---

## Prompt

```
You are installing Documentation System Runtime (naprolom-docs v1.9) on this project.
Work autonomously — detect the current state, choose the correct path, execute it,
verify the result, commit locally, and report. Do NOT ask the user clarifying questions;
if something is ambiguous, pick the safest path and note it in the report.

══════════════════════════════════════════════════════════════
STEP 0 — Detect current state
══════════════════════════════════════════════════════════════

Run these commands from the current working directory:

    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "NOT_A_GIT_REPO")
    echo "Project root: $PROJECT_ROOT"

    echo "=== .gitmodules ==="
    cat "$PROJECT_ROOT/.gitmodules" 2>/dev/null || echo "none"

    echo "=== existing docs/ ==="
    ls "$PROJECT_ROOT/docs/" 2>/dev/null | head -10 || echo "no docs/"

    echo "=== existing .context/runtime ==="
    ls "$PROJECT_ROOT/.context/runtime/" 2>/dev/null | head -5 || echo "none"

    echo "=== Runtime version ==="
    if [ -f "$PROJECT_ROOT/docs/.runtime/naprolom-docs/runtime/registry.yaml" ]; then
      grep -E '^version:' "$PROJECT_ROOT/docs/.runtime/naprolom-docs/runtime/registry.yaml" | head -1
    else
      echo "v1.1 or earlier / not installed"
    fi

    echo "=== empty dirs in docs/ (pre-existing check) ==="
    find "$PROJECT_ROOT/docs/" -type d -empty 2>/dev/null | grep -v "^$PROJECT_ROOT/docs/$" | head -20 || echo "none"

Based on the results, automatically choose ONE path:

  ┌─ What you found ──────────────────────────────┬─ Path ──────────────────────────────────────┐
  │ Nothing — no Runtime at all                   │ Fresh install (Step A)                     │
  │ .context/runtime/ exists (v1.0 layout)        │ Migrate v1.0 (Step B)                      │
  │ docs/.runtime/naprolom-docs/ exists,          │ Migrate v1.1 (Step C)                      │
  │   no runtime/registry.yaml                     │                                             │
  │ registry.yaml exists, version < 1.9           │ Auto-upgrade (Step C)                      │
  │ registry.yaml exists, version >= 1.9          │ Update in-place (Step D)                   │
  └───────────────────────────────────────────────┴─────────────────────────────────────────────┘

Do NOT ask the user which path to take. Decide and proceed.

══════════════════════════════════════════════════════════════
STEP A — Fresh install (no prior Runtime)
══════════════════════════════════════════════════════════════

    cd "$PROJECT_ROOT"
    mkdir -p docs/.runtime
    git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
    git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
    git commit -m "chore: add Documentation System Runtime v1.9 via submodule"

══════════════════════════════════════════════════════════════
STEP B — Migrate from v1.0 (.context/runtime/)
══════════════════════════════════════════════════════════════

    cd "$PROJECT_ROOT"
    git submodule deinit -f .context/runtime/naprolom-docs 2>/dev/null
    git rm -f .context/runtime/naprolom-docs 2>/dev/null
    rm -rf .git/modules/.context/runtime/naprolom-docs 2>/dev/null
    rm -rf .context/runtime 2>/dev/null
    mkdir -p docs/.runtime
    git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
    git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
    git commit -m "chore: migrate naprolom-docs v1.0→v1.9 (docs/.runtime/ path)"

══════════════════════════════════════════════════════════════
STEP C — Auto-upgrade (v1.1–v1.8 → v1.9)
══════════════════════════════════════════════════════════════

Pull the latest submodule and run bootstrap. v1.9 fixes a known v1.8 bug
where empty directories were created in docs/ from non-path YAML fields —
no new empty dirs should appear after bootstrap.

    cd "$PROJECT_ROOT"
    git submodule update --remote --merge

    # If the submodule is absent or the update failed, do a fresh add instead:
    # mkdir -p docs/.runtime && git submodule add ... (same as Step A)

    bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh

══════════════════════════════════════════════════════════════
STEP D — Update existing v1.9 installation
══════════════════════════════════════════════════════════════

Do NOT reinstall. Pull the latest and re-run idempotent bootstrap:

    cd "$PROJECT_ROOT"
    git submodule update --remote --merge
    bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh

If bootstrap reports DEGRADED mode — stop and surface this as an error.
Do not continue silently in DEGRADED mode.

══════════════════════════════════════════════════════════════
STEP 4 — Post-install verification (ALL paths)
══════════════════════════════════════════════════════════════

── 4.1  CRITICAL: Runtime directories must NOT leak to project root ──

These directories live ONLY inside docs/.runtime/naprolom-docs/.
If any of them exists at the repo root, the previous install was broken — remove them.

    FAIL=0
    for d in agents knowledge sops engine documentation bootstrap playbook runtime; do
      [ -d "$PROJECT_ROOT/$d" ] && echo "FAIL: $PROJECT_ROOT/$d leaked to root" && FAIL=1 || echo "OK: no $PROJECT_ROOT/$d"
    done
    [ $FAIL -eq 1 ] && echo "ABORT: fix root leakage before continuing" || echo "PASS"

── 4.2  Required structure ─────────────────────────────────────────

    [ -f "$PROJECT_ROOT/docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh" ] || { echo "FAIL"; exit 1; }
    [ -f "$PROJECT_ROOT/docs/.runtime/naprolom-docs/runtime/registry.yaml" ] || { echo "FAIL"; exit 1; }

── 4.3  Empty-dir check after bootstrap ────────────────────────────

    find "$PROJECT_ROOT/docs/" -type d -empty | grep -v "^$PROJECT_ROOT/docs/$$"
    # Any output here means there are empty directories in docs/.
    # v1.9 has a fix for the registry_list_directories bug (v1.8),
    # so no new empty dirs should be created. Pre-existing empty dirs
    # are legitimate — do not delete them without verifying against
    # docs/.runtime/naprolom-docs/runtime/registry.yaml.

── 4.4  Validators ────────────────────────────────────────────────

    cd "$PROJECT_ROOT"
    bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh
    bash docs/.runtime/naprolom-docs/documentation/validation/validate-runtime.sh

Both must pass. If validate-runtime.sh reports errors — stop and report.

── 4.5  Reality Engine report (post-install drift check) ───────────

Run the Reality Engine to find architecture breakage points:

    cd "$PROJECT_ROOT"
    bash docs/.runtime/naprolom-docs/engine/reality-engine/reporters/reality-report.sh "$PROJECT_ROOT"

python3 is preferred for full drift parsing; without it the report falls back
to a limited grep view but still produces useful output.

Read the report. Report these to the user explicitly:

  * ADR drift        — docs reference an ADR id that does not exist
  * Documentation drift — docs missing required frontmatter (schema/id/type)
  * Spec drift       — spec status does not match its directory
  * Structure drift  — expected top-level dirs (docs/, .context/) missing

List each item as "architecture breakage point" with the file path and issue.
Do NOT silently fix drift items — surface them so the user decides.

══════════════════════════════════════════════════════════════
STEP 5 — Commit and report
══════════════════════════════════════════════════════════════

    cd "$PROJECT_ROOT"
    git add -A
    git status --short
    git diff --cached --stat
    git commit -m "docs: Documentation System Runtime v1.9 installed" || echo "nothing to commit"

Do NOT push.

Report to the user:
  1. Project path and git remote
  2. Action taken (fresh install / migrated v1.0 / auto-upgraded v1.1–v1.8 / updated v1.9+)
  3. Verification results (4.1 root check, 4.2 structure, 4.4 validators)
  4. Post-install drift findings (ADR / documentation / spec / structure breakage points)
  5. Next steps for the user:
     - Fill in .context/project.yml (project metadata)
     - Fill in .context/boundaries.yml (boundary definitions)
     - Create the first ADR from documentation/templates/adr.md
     - Resolve any reported drift items

══════════════════════════════════════════════════════════════
RULES (hard — do not violate)
══════════════════════════════════════════════════════════════

  · NEVER create agents/, knowledge/, sops/, engine/, documentation/,
    bootstrap/, playbook/, runtime/ at the project root.
    They live ONLY inside docs/.runtime/naprolom-docs/.

  · NEVER edit files inside docs/.runtime/naprolom-docs/.
    It is a git submodule (pristine zone). Update it only via
    `git submodule update --remote --merge` as a whole.

  · NEVER copy templates from documentation/templates/ into the consumer
    project and keep local duplicates. Use `cp` to create a new file
    from the template once — the template itself is the source of truth
    and lives in the submodule.

  · The docs/ directory at the project root is for the CONSUMER'S content.
    The only system-owned subdirectory is docs/.runtime/naprolom-docs/.
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
