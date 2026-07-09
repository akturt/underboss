---
schema: 1
id: install-remote-prompt
type: guide
kind: onboarding
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter]
touches: [docs, .context, .gitmodules, CLAUDE.md, .github/workflows]
docs: [../INSTALL.md, playbook-v2.md, migrate-legacy.md]
refs: []
depends_on: []
tags: [install, remote, agent-prompt, ubuntu]
priority: P0
---

# Universal prompt for installing naprolom-docs as a Git Submodule on a remote host

> **Self-contained prompt** for an AI agent on a Linux server (Ubuntu) to connect the naprolom-docs Runtime into an existing project repository. Run this prompt as-is.

---

## Agent role

You are a DevOps agent with access to the project's git repository on a remote Linux server. Your task is to connect the Documentation System Runtime `naprolom-docs` as a Git Submodule and prepare the project structure for working with Documentation Schema v1.

Report at every checkpoint, and do not proceed to the next step without confirmation (if the specific step requires it). Copy bash commands verbatim, do not "rephrase" them.

## Preconditions

- The server has `git >= 2.20` and `node >= 18` installed (for `engine/scripts/migrate-legacy.mjs` and `sops/planner.mjs`).
- You have SSH access to the project repository (via `git@github.com:akturt/<project>.git` or equivalent) or an HTTPS PAT key.
- The working directory is the root of the project clone.

## Project variables

| Variable | Example | Replace with |
|---|---|---|
| `PROJECT_NAME` | `kordon` | Consumer project name (slug, lowercase) |
| `PROJECT_REPO_URL` | `git@github.com:akturt/kordon.git` | SSH or HTTPS URL of the repository |
| `PROJECT_REPOS_REMOTE` | `origin` | Standard remote name (usually `origin`) |
| `PROJECT_BRANCH` | `main` or `master` | Working branch on which we do the integration |
| `AI_PLATFORM` | `opencode` or `claude-code` | What is installed on the server (if both — `opencode` for Linux) |
| `TEAM_NAME` | `naprolom-team` | Who will be the owner of documents in the frontmatter |

## Context URL (use for instructions inside SOPs and prompts)

The Runtime submodule is mounted at `docs/.runtime/naprolom-docs/`. All further consumer-side paths are relative to it.

---

## Step 1 — Clone the project (if not yet cloned on the server)

```bash
cd ~                                          # or /opt / /srv — where the project should live
git clone <PROJECT_REPO_URL> <PROJECT_NAME>
cd <PROJECT_NAME>
git checkout <PROJECT_BRANCH>
git status                                     # confirm the branch is clean, no uncommitted
```

**Checkpoint 1:** report:
- path to the clone
- current branch
- presence of `docs/`, `.context/`, `CLAUDE.md`, `.github/workflows/` via `ls -la`

---

## Step 2 — Check brownfield vs greenfield

The installation system differs depending on whether `docs/` with `.md` already exists:

```bash
ls docs/ 2>/dev/null && echo "DOCS_EXISTS" || echo "NO_DOCS"
find docs/ -name "*.md" 2>/dev/null | wc -l
```

**Rule:**
- `NO_DOCS` or `0 .md files` → **Greenfield path** → go to Step 3.
- There are `.md` files in `docs/` → **Brownfield path** → go to Step 4.

Do not proceed further without operator confirmation if the `.md` count > 30 — there, most likely, is legacy documentation; migration is needed.

---

## Step 3 — Greenfield path: attach the submodule

Only if in Step 2 — `NO_DOCS` (no existing documentation).

```bash
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
git submodule update --init --recursive
ls -la docs/.runtime/naprolom-docs/        # should show Runtime contents
```

Bootstrap will create the skeleton + CLAUDE.md snippet + workflow:

```bash
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
```
**What should appear:**

- `docs/{architecture,adr,specs:{drafts,review,approved,implemented,superseded},audits,backlog,api}/` — the 5-layer structure.
- `.context/{project.yml,boundaries.yml,agent-entry.md}` — stubs.
- `CLAUDE.md` — a 6-line snippet about the Documentation Runtime (appended to existing or created).
- `.github/workflows/docs-validate.yml` — the CI guard.

Proceed to Step 5.

---

## Step 4 — Brownfield path: attach the submodule without overwriting

Only if in Step 2 — an existing `docs/` with `.md`.

### 4a — Attach the submodule

```bash
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
git submodule update --init --recursive
```

### 4b — Generate only the .context/ stubs (DO NOT touch the existing docs/)

Bootstrap is idempotent: it does not overwrite existing files. But it is safer to explicitly copy the stubs separately, and then — if needed — edit them.

```bash
# Creating .context/ without calling bootstrap (to avoid touching existing .github/workflows/docs-validate.yml)
mkdir -p .context

# Creating stubs, not overwriting existing ones
[ -f .context/project.yml ] || cat > .context/project.yml << 'YML'
project:
  name: <PROJECT_NAME>
  description: "TODO: 1-sentence project description"
  domain: example.com
  maintainer: <TEAM_NAME>
  repository: <PROJECT_REPO_URL>

stack:
  backend: []
  database: []
  infrastructure: []

directories:
  key: {}
YML

[ -f .context/boundaries.yml ] || cat > .context/boundaries.yml << 'YML'
boundaries:
  pristine:
    - path: docs/.runtime/naprolom-docs/
      reason: "submodule, NEVER edit in-place"
  editable:
    - path: docs/
      reason: "documentation"
  generated: []
  secret: []
YML

[ -f .context/agent-entry.md ] || cp docs/.runtime/naprolom-docs/bootstrap/.context-agent-entry-template 2>/dev/null || cat > .context/agent-entry.md << 'MD'
# Agent Entry Protocol

Read in order:
1. .context/project.yml - what project this is
2. .context/boundaries.yml - what is editable / pristine / secret
3. docs/architecture/README.md - topology, invariants (create if missing)
4. CLAUDE.md - rules

Before creating any .md in docs/:
1. Identify `type` (spec|adr|audit|runbook|guide|api|architecture|backlog|prompt)
2. Copy template from runtime: docs/.runtime/naprolom-docs/documentation/templates/<type>.md
3. Fill the 6 mandatory fields: schema, id, type, status, date, owners
4. Never add `lifecycle:` to frontmatter (computed from path for specs/api)
5. Never add legacy fields: author, title, created, referenced_by, supersedes_adr, excludes-from-scope
MD
```

### 4c — Check the legacy frontmatter state (without writing)

```bash
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --dry-run --owner <TEAM_NAME> 2>&1 | head -40
```

Save the output for the operator's report: how many `.md` would be changed, how many have `TODO_ENTITY_REF` (require manual review).

### 4d — Run the migration (only if the operator confirmed)

**Do not run without explicit confirmation.** The migration overwrites all `.md` in `docs/` to canonical Schema v1.

```bash
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --owner <TEAM_NAME>
```

**Exit codes:**
- `0` — migration completed cleanly.
- `1` — there are `TODO_ENTITY_REF` markers. Non-blocking, but requires manual review.
- `2` — `docs/` root not found (something is wrong).

### 4e — Set the CI guard in warn-only mode (migration period)

```bash
mkdir -p .github/workflows
[ -f .github/workflows/docs-validate.yml ] || cat > .github/workflows/docs-validate.yml << 'YML'
name: docs-validate
on:
  pull_request:
    paths: ["docs/**"]
jobs:
  schema-v1:
    runs-on: ubuntu-latest
    env:
      WARN_ONLY: "true"   # brownfield rollout: WARNING instead of FAIL
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
      - name: Validate Canonical Schema v1 frontmatter
        run: |
          bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh
YML
```

**Checkpoint 4:** report:
- how many files migrated
- how many `TODO_ENTITY_REF` markers remain
- that the warn-only CI configuration was created

---

## Step 5 — Fill in project.yml and boundaries.yml for the project

Edit `.context/project.yml` manually or via heredoc, substituting the real project stack:

```bash
cat > .context/project.yml << 'YML'
project:
  name: <PROJECT_NAME>
  description: "<read project README, write 1 sentence>"
  domain: example.com
  maintainer: <TEAM_NAME>
  repository: <PROJECT_REPO_URL>

stack:
  backend: [<read package.json / requirements.txt / go.mod — write languages and frameworks>]
  database: [<read migration configs / docker-compose / .env.example>]
  infrastructure: [<Docker Compose / Kubernetes / Terraform / Ansible>]

directories:
  key:
    src/: "Main source code"
    docs/: "Documentation"
    infra/: "Infrastructure"
YML
```

Expand `.context/boundaries.yml` to match the real project structure:

```bash
# Find directories with code, configs, secrets
ls -la
find . -maxdepth 2 -type d -not -path "./.git*" -not -path "./node_modules*"
```

Fill in `.context/boundaries.yml`:
- `pristine` — what NOT to touch (vendor/, third-party, docs/.runtime/naprolom-docs/).
- `editable` — where changes are allowed (src/, docs/, infra/).
- `generated` — what scripts create.
- `secret` — files containing secrets (.env, *.key, *.pem).

---

## Step 6 — CLAUDE.md snippet (for the AI agent)

If `CLAUDE.md` already exists — check for the presence of the "## Documentation Runtime" section:

```bash
if [ -f CLAUDE.md ]; then
  grep -q "## Documentation Runtime" CLAUDE.md && echo "SNIPPET_EXISTS" || echo "NEED_APPEND"
else
  echo "NEED_CREATE"
fi
```

For `NEED_APPEND` or `NEED_CREATE` — call bootstrap (it is idempotent, will not overwrite) or copy the snippet manually:

```bash
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
```

If the stub files are created — `agent-entry.md` will be overwritten only if it does not already exist (verify idempotency via `bootstrap.sh`).

**Alternative for other AI entry-files:**

For opencode, create a symlink or a copy:
```bash
[ -f AGENTS.md ] || ln -s CLAUDE.md AGENTS.md 2>/dev/null || cp CLAUDE.md AGENTS.md
```

---

## Step 7 — Copy the agent roles for the server platform

Ignore if `<AI_PLATFORM>` is not set — skip this step.

### For `opencode`

```bash
mkdir -p .opencode/agents
cp docs/.runtime/naprolom-docs/agents/opencode/*.md .opencode/agents/
ls -la .opencode/agents/
# should show: architecture-reviewer.md, documentation-reviewer.md
```

### For `claude-code`

```bash
mkdir -p .claude/agents
cp docs/.runtime/naprolom-docs/agents/claude-code/*.md .claude/agents/
ls -la .claude/agents/
```

### For both platforms at once

Simply copy both sets. The `CLAUDE.md` snippet stays shared — both platforms read it.

---

## Step 8 — Create the first architecture document (optional, per operator instruction)

```bash
PROJECT_NAME_KEBAB=$(echo "<PROJECT_NAME>" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
cp docs/.runtime/naprolom-docs/documentation/templates/adr.md docs/adr/001-bootstrap-documentation-runtime.md
# Edit frontmatter (id, date, owners) and body (Context about integrating naprolom-docs, Decision regarding submodule+branch=master, Consequences)
$EDITOR docs/adr/001-bootstrap-documentation-runtime.md 2>/dev/null || true
```

Fill in the body minimally:
- **Context:** "Project <PROJECT_NAME> has no formalized documentation system. Documentation grows chaotically, and onboarding new agents and developers is hard."
- **Decision:** "Adopt naprolom-docs as the Documentation System Runtime, connected as a Git Submodule, pinned to the master branch in .gitmodules."
- **Consequences:** "All .md in docs/ must conform to Canonical Schema v1. The CI guard watches. Development processes follow the declarative SOPs in sops/."
- **Status:** accepted

---

## Step 9 — Run the validator before committing

```bash
# strict mode (greenfield)
bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh

# warn-only (if brownfield and migration not yet complete)
WARN_ONLY=true bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh
```

**Expected output:**
```
docs-validate: OK
```

If there are errors (`ERROR: <file>: ...`) — do not commit; report to the operator the list of files and exactly what is violated.

---

## Step 10 — Commit and push

```bash
git add -A
git status --short
git commit -m "chore: add naprolom-docs Documentation System Runtime as git submodule

Stage <PROJECT_NAME> for Canonical Schema v1 documentation:

- Add submodule docs/.runtime/naprolom-docs pinned to master branch
- Add .context/ stubs (project.yml, boundaries.yml, agent-entry.md)
- Add .github/workflows/docs-validate.yml calling documentation/validation/validate-frontmatter.sh
- Add CLAUDE.md snippet (6 rules: playbook→templates→schema→validator→migrate→sops)
- <GREENFIELD: 'Bootstrap created docs/ skeleton (5-layer architecture)'>
- <BROWNFIELD: 'Existing docs/ preserved; CI guard in WARN_ONLY=true period'>
- <IF ROLES COPIED: 'Add <AI_PLATFORM> reviewer roles from agents/<platform>/'>
- <IF FIRST ADR: 'Add ADR-001 recording this runtime adoption decision'>"
git push <PROJECT_REPOS_REMOTE> <PROJECT_BRANCH>
```

---

## Step 11 — Final report to the operator

After the push, provide a summary:

```
## Connecting naprolom-docs Runtime to <PROJECT_NAME>

Repository: <PROJECT_REPO_URL>
Branch: <PROJECT_BRANCH>
Path: docs/.runtime/naprolom-docs/ (submodule pinned to master)
Mode: GREENFIELD | BROWNFIELD (warn-only period for ~3-7 days)
Commit SHA: <git rev-parse HEAD>
Submodule SHA: <git -C docs/.runtime/naprolom-docs rev-parse HEAD>

Files created/changed:
- .gitmodules (new submodule entry, branch=master)
- docs/.runtime/naprolom-docs/ (submodule)
- .context/project.yml
- .context/boundaries.yml
- .context/agent-entry.md
- CLAUDE.md (Documentation Runtime snippet)
- .github/workflows/docs-validate.yml
- <IF GREENFIELD: 'docs/ skeleton (5-layer architecture)'>
- <IF AI_PLATFORM: '.<platform>/agents/{architecture-reviewer,documentation-reviewer}.md'>
- <IF FIRST ADR: 'docs/adr/001-bootstrap-documentation-runtime.md'>

Validator result: docs-validate: OK (or WARN count: <N> if brownfield warn-only)
Next steps for operator:
  1. Review .context/project.yml — replace TODOs with real stack
  2. Review .context/boundaries.yml — classify project files
  3. First SOP run: node docs/.runtime/naprolom-docs/sops/planner.mjs --list
  4. <IF BROWNFIELD> outline cleanup: ~<N> docs with TODO_ENTITY_REF need manual entity_refs
  5. <IF BROWNFIELD> after cleanup switch CI to strict: WARN_ONLY="" in .github/workflows/docs-validate.yml
```

---

## Edge Cases

### Git-version < 2.20

`git submodule add --branch master <url> docs/.runtime/naprolom-docs` — supported, but if git is old, manually add `branch = master` to `.gitmodules` after `add`.

### Node.js not installed

Install via `apt-get install -y nodejs` or via nvm (`curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash && nvm install --lts`). Without node — `engine/scripts/migrate-legacy.mjs` and `sops/planner.mjs` do not work. The Validator (`validate-frontmatter.sh`) — works (POSIX awk).

### Submodule not included in other contributors' clones

Tell them to use `git clone --recurse-submodules <url>` or `git submodule update --init --recursive` in the existing clone. This is a fix in .gitmodules, not on your side.

### `git submodule update --remote` does not pull master

Check that `.gitmodules` contains:
```
[submodule "docs/.runtime/naprolom-docs"]
    path = docs/.runtime/naprolom-docs
    url = https://github.com/akturt/naprolom-docs.git
    branch = master
```

If the `branch = master` line is missing — add it:
```bash
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
git add .gitmodules && git commit -m "chore: pin submodule to master branch"
```

### `WARN_ONLY=true` — workflow fail

`WARN_ONLY` must be in the `env:` section of the job, not in `steps:`. Check:
```yaml
jobs:
  schema-v1:
    runs-on: ubuntu-latest
    env:                              # ← here, not in steps
      WARN_ONLY: "true"
```

### What NOT to do

- ❌ Do not edit files in `docs/.runtime/naprolom-docs/` in-place. It is a submodule.
- ❌ Do not run bootstrap twice on a brownfield with an existing `.github/workflows/docs-validate.yml` — bootstrap only creates it if the file is absent.
- ❌ Do not enable strict CI (`WARN_ONLY=""`) immediately on brownfield. First complete the full cleanup of forgotten archives, then switch.
- ❌ Do not create `.md` in `docs/` without `cp docs/.runtime/naprolom-docs/documentation/templates/<type>.md docs/<type>/...` — canonical frontmatter is hard to write "from memory".

---

## After connecting — how the operator will run the work

The connected consumer project starts using the Runtime like this:

```bash
# List of available SOPs
node docs/.runtime/naprolom-docs/sops/planner.mjs --list

# Execution plan for new-feature (specifying platform)
node docs/.runtime/naprolom-docs/sops/planner.mjs new-feature --platform opencode

# Only what needs to invoke the agents (without manual human steps)
node docs/.runtime/naprolom-docs/sops/planner.mjs new-feature --hide-human

# Create a new document from template
cp docs/.runtime/naprolom-docs/documentation/templates/adr.md docs/adr/002-<decision>.md

# Run validator before committing
bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh
```

Invoking agent roles (for opencode):
```
@architecture-reviewer review PR #123
@documentation-reviewer validate-PR #123
```

Invoking roles in Claude Code:
```
/architecture-reviewer
/documentation-reviewer
```

---

## Final note

If something goes wrong — stop and ask the operator. Do not improvise. It is better to leave something explicitly unfinished than to finish it incorrectly and leave drift behind.