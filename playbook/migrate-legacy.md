---
schema: 1
id: documentation-system-migration-legacy
type: guide
kind: legacy
status: active
date: 2026-07-07
updated: 2026-07-08
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter, lifecycle-spec]
touches: [docs, .github/workflows]
docs: [playbook-v2.md]
refs: []
depends_on: [documentation-system-playbook-v2]
tags: [documentation, adoption, brownfield, migration, agent-prompt]
priority: P1
---

# Migration Prompt: Brownfield Repository → Canonical Schema v1

> Agent-ready protocol for migrating an existing repository (brownfield) to the target Documentation System v2 model (Canonical Schema v1).
> The target model is described in [`playbook-v2.md`](playbook-v2.md) (Greenfield Playbook). This guide is not part of the model — it is a **way to get into it**.
>
> **When to use:** the existing repository already contains `.md` files (legacy frontmatter or none at all).
> **When NOT to use:** a new (greenfield) repository — use `bootstrap/bootstrap.sh` directly from `playbook-v2.md`.

---

## Agent role

This document is a **ready-made prompt** for an AI agent (Claude Code, opencode) tasked with migrating the documentation of an existing project to Canonical Schema v1. The agent performs the steps in order, reports at each checkpoint, and does not proceed to the next step without confirmation from the operator (or without the explicit `--auto` flag).

## Prerequisites

- The `naprolom-docs` submodule is already attached at `docs/.runtime/naprolom-docs/` (see `../../INSTALL.md`).
- The repository has already run `bootstrap/bootstrap.sh` (`.context/`, `docs/` skeleton, `CLAUDE.md` snippet created).
- Node.js 18+ is available for `engine/scripts/migrate-legacy.mjs`.

## Rollout strategy

```
Audit legacy → Run migration script → Manual review
            → Warn-only CI (several days)
            → Manual cleanup of forgotten documents
            → Strict CI
```

Greenfield — strict from the first PR. Brownfield goes through `Warn → Strict`. Never enable strict CI immediately on brownfield — forgotten `docs/archive/`, `docs/old/`, `docs/wiki/` would break every PR.

---

## Step 1 — Legacy audit (1–2 hours)

**Goal:** understand the scope of the migration before starting it.

```bash
# How many .md files in the project (outside submodule)?
find docs/ -name "*.md" -not -path "*/docs/.runtime/*" | wc -l

# What frontmatter fields are present?
grep -rE "^(schema:|author:|title:|created:|lifecycle:|type:|status:)" docs/ \
  | awk -F: '{print $3}' | sort | uniq -c

# What legacy fields are present in frontmatter (FM only, via awk)?
for f in $(find docs/ -name "*.md"); do
  awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$f" \
    | grep -E "^(author|title|created|lifecycle|referenced_by|supersedes_adr|excludes-from-scope):"
done

# What directories don't fit the 5-layer model?
find docs/ -type d -not -path "*/docs/.runtime/*" \
  | grep -E "archive|old|wiki|tmp|legacy|draft|misc" || true
```

**Checkpoint 1:** report to the operator:
- How many `.md` files total.
- What frontmatter types (canonical vs legacy vs none).
- What "forgotten" directories are present.
- Migration time estimate (1 file ≈ 30 seconds in the script + 1–2 minutes manual review per 10–20% of files).

**Do not proceed to Step 2 without operator confirmation.**

---

## Step 2 — Prioritization (5–10 minutes)

Split all `.md` files into 3 buckets:

| Bucket | Criterion | Action |
|---------|---------|----------|
| **Active** | Used right now, referenced from code / docs / issues | Migrate first |
| **Archive** | Old version, outdated, historical | Leave in `docs/archive/` **without** canonical FM, exclude from CI (the warn-only period will catch it) |
| **Orphan** | References nothing, > 1 year without updates | Delete or move to `docs/archive/` — operator decides |

**Checkpoint 2:** present the operator the list of files by bucket. Delete only with explicit confirmation (`Orphan → delete`).

**Do not proceed to Step 3 without operator confirmation.**

---

## Step 3 — Runnable migration (5–30 minutes)

Run the migration script from the Runtime:

```bash
# Dry-run: shows what would change, without writing
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --dry-run

# Real run
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --owner <team-name>

# Quiet mode (summary only)
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --quiet --owner <team-name>
```
**What the script does:**

- Adds `schema: 1`, `id` (from filename), `type` (from path), `status` (from path / lifecycle), `date` (from `created` or filename), `owners` (from `author` or `--owner`).
- Sets `updated: <today>` on all changed files.
- For `spec`/`audit`: if `entity_refs` is empty → sets a `TODO_ENTITY_REF` marker for manual review.
- Removes legacy fields: `author`, `title`, `created`, `lifecycle`, `referenced_by`, `supersedes_adr`, `excludes-from-scope`.
- If a legacy `title:` existed → turns it into `# <title>` in the body (H1, as Schema v1 requires).
- Idempotent. Re-running on already-canonical files is a no-op.

**Exit codes:**

- `0` — all files migrated cleanly.
- `1` — there are files with `TODO_ENTITY_REF` — manual review needed (Step 4).
- `2` — `docs/` root not found.

**Checkpoint 3:** after the run, report:
- How many files changed.
- How many files with `TODO_ENTITY_REF` (will go to Step 4).
- Which directories were untouched (Archive).

**Do not proceed to Step 4 without operator confirmation.**
---

## Step 4 — Manual review (10–20% of files, ~30 minutes per 50 files)

The script marks `TODO_ENTITY_REF` on those `spec`/`audit` files for which it could not infer the domain entity. Your task is to determine the real entity refs:

```bash
# List of all files requiring review
grep -rl "TODO_ENTITY_REF" docs/
```

For each:
1. Open the file, read the body.
2. Identify the domain entity (one or several) the document describes.
3. Check whether a corresponding `id:` exists in `docs/architecture/` (entity catalog).
4. Replace `TODO_ENTITY_REF` with the real entity `id` (kebab-case, ≥ 2 characters).
5. If the entity is not defined — create it (an architecture document or an ADR) and **then** reference it.

Additionally verify during manual review:
- Is the auto-derived `type:` correct? (For example, a file in `docs/adr/` — is it really an ADR, not a spec.)
- Is the derived `status:` correct? (For example, an ADR `proposed` may in fact be `accepted`.)
- Is there any information loss when removing `lifecycle:` — if the `lifecycle` value is non-standard, add it as a comment or in `tags:`.

**Checkpoint 4:** show the operator the list of all manual-review changes.

**Do not proceed to Step 5 without operator confirmation.**

---

## Step 5 — Warn-only CI (several days)

Enable the CI guard in warn-only mode for the rollout period. In `.github/workflows/docs-validate.yml` (created by bootstrap):

```yaml
jobs:
  schema-v1:
    env:
      WARN_ONLY: "true"   # brownfield rollout: WARNING instead of FAIL
```

Push the changes. CI will print warnings but will not fail. This is a "soft" period during which forgotten `docs/archive/`, `docs/old/`, `docs/wiki/`, `docs/tmp/` do not break PRs.

In this mode, local validation:

```bash
# What warn-only CI reports
WARN_ONLY=true bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh
```

Warn-only duration: 3–7 days, or until several PRs in a row show no warnings.

**Checkpoint 5:** confirm that warn-only is enabled and CI is green.

---

## Step 6 — Cleanup of forgotten directories

During the warn-only period, clean up non-standard documents:

- `docs/archive/` → either add canonical FM, or delete (operator decides).
- `docs/old/` → migrate with `engine/scripts/migrate-legacy.mjs` or delete.
- `docs/wiki/` → move what is relevant to `docs/architecture/` / `docs/adr/`, delete the rest.
- `docs/tmp/` → delete (these are usually session files, not documentation).
- `*.log`, `PHASE_*_REPORT.md`, `*_verification_*.md` → delete from `docs/`.

```bash
# Find forgotten directories
find docs/ -type d -not -path "*/docs/.runtime/*" \
  | grep -E "archive|old|wiki|tmp|misc"

# Find session files (usually not documentation)
find docs/ -name "*.log" -o -name "PHASE_*" -o -name "*_verification_*"
```

For each, clarify with the operator: migrate (canonical FM per Schema v1) or delete.

**Checkpoint 6:** warn-only CI emits no warnings.

---

## Step 7 — Switch to strict CI

When warn-only has produced no warnings for several days — switch the guard back to strict mode:

```yaml
jobs:
  schema-v1:
    env:
      WARN_ONLY: ""   # greenfield-strict
```

From this point the brownfield repository lives under the same strict rules as greenfield. Any new `.md` without canonical FM breaks the PR.

**Checkpoint 7:** strict CI is green, rollback is impossible.

---

## Readiness Checklist

Migration is complete when:

- [ ] `schema: 1` is present in all `.md` files in `docs/` (outside `docs/archive/`).
- [ ] `id`, `type`, `status`, `date`, `owners` are filled in on all `.md`.
- [ ] `owners` ≠ `unassigned` for active documents (only Archive may be `unassigned`).
- [ ] `updated` was set by the migrator.
- [ ] `entity_refs` is filled in (no `TODO_ENTITY_REF`) for `spec`/`audit` (min 1 ref).
- [ ] No legacy fields in frontmatter (CI forbids them).
- [ ] `.context/` bootstrapped (`project.yml`, `boundaries.yml`, `agent-entry.md`).
- [ ] `docs/architecture/entity-catalog.md` created.
- [ ] Warn-only CI passed, switched to strict.
- [ ] CI never fails on frontmatter in any PR.

---

## Edge Cases

### `title:` without an H1 in the body

The script will add `# <title>` to the body itself. Check that the body had no H1 — otherwise there would be a duplicate. The script is safe: it checks before inserting.

### Non-standard `lifecycle:`

For example, `lifecycle: rejected`. The script maps `rejected` → `status: deprecated` for ADRs, and → `status: active` for other types. If the non-standard value is critical — move it to `tags:`.

### `excludes-from-scope:` contained important information

The field is removed as an anti-pattern. If it is important to state explicitly "not about Z" — use `tags: [not-X]` or a `## Scope / Excluded` section in the body.

### Orphan spec without entity

The script sets `TODO_ENTITY_REF`. If the domain entity really cannot be identified — that is a signal that the document is too general or outdated. Split it into several specs or move it to `docs/archive/`.

### ADR with `status: proposed` in the body, but missing from the FM

The script does not parse the body. Check during manual review: if the body has `## Status: accepted` — set `status: accepted` in the FM.

---

## Anti-patterns

| Mistake | Why it is bad | Solution |
|--------|-------------|---------|
| Enable strict CI immediately on brownfield | Forgotten `docs/archive/` would break every PR | Warn-only period is mandatory |
| `entity_refs: []` on spec/audit | The model requires min 1 ref for spec/audit | The script sets `TODO_ENTITY_REF`, replace it in Step 4 |
| `updated` not set | The document really changed during migration → freshness not tracked | The script sets `updated = today` automatically |
| `excludes-from-scope:` left in place | CI forbids it; anti-pattern | The script removes it; replace with `tags: [not-X]` |
| Migrate an outdated archive | Wasting time on dead docs | Leave in `docs/archive/` without migration |
| Delete `docs/archive/` entirely | Losing decision history | Only add canonical FM or leave it |
| Manual review skipped | The script may have derived `type`/`status`/`id` imprecisely | Mandatory: review 10–20% of files manually |
