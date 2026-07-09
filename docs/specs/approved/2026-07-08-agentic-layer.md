---
schema: 1
id: agentic-layer
type: spec
status: approved
date: 2026-07-08
updated: 2026-07-08
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer, agent-role-separation, sop-dag, capabilities]
touches: [agents, sops, knowledge, engine/templates, bootstrap, README, INSTALL]
code: [.github/workflows/docs-validate.yml]
docs: [../../README.md, ../../INSTALL.md, ../../agents/README.md, ../../sops/README.md]
refs: []
depends_on: []
implements: []
supersedes: []
tags: [agentic, roles, sops, knowledge, capabilities, layered-runtime, v1.1, upgrade]
priority: P0
---

# Spec: Documentation System Runtime v1.1 — Agentic Layer

> Revised edition. Incorporates reviewer feedback across 5 passes:
> v1: removed output templates (merged into `knowledge/report-formats.md`), `planner.mjs` fixed as a DAG-printer (not executor), YAML SOP simplified (without `constraints:`), introduced the Capabilities layer.
> v2: **Artifact — first-class entity** (`artifact:` field with canonical names, see §Artifact model), **Capability Catalog moved to `knowledge/capabilities.md`** (not in `agents/README.md`).
> v3: Capability Catalog without providers (one-way Role→Capability). Knowledge refs via short-id (`knowledge: [architecture-principles]`). planner does not read knowledge (D-PL). `gate: manual` instead of `role: human` (D-HG).
> v4 (current): **Bootstrap deploys the Runtime into `docs/.runtime/`, NOT into the consumer repo root** (D-BR). Clear separation: (a) the `naprolom-docs` repo = the product (directories at root are OK); (b) the consumer repo = uses only `docs/`, everything else goes into `docs/.runtime/`. The submodule mounts at `docs/.runtime/naprolom-docs/`, NOT at `.context/runtime/`. Affects: bootstrap scripts, INSTALL, playbook, the CLAUDE.md snippet, and paths in all SOPs/roles.
> Other improvements (grouping knowledge by domain, loading knowledge from SOP not from role) — deferred to the **v1.2 roadmap** (§Out-of-scope follow-up).

## Goal
Split the monolithic AI agent-prompts of the previous iteration into **five orthogonal layers** — **Knowledge** (what the agent knows), **Role** (who it is), **Capability** (what it can do), **SOP** (when it is used), **Artifact** (what travels between roles in the DAG) — without introducing a separate kind of "output templates"; add two new roles to Runtime v1.1 (`reality-auditor`, `adversary-checker`) and turn the former `forensic-orchestrator` into a declarative SOP `sops/forensic-audit.yaml`, without breaking the stable Runtime v1.0 contracts.

## Context
Runtime v1.0 is frozen and ready for dogfooding on Kordon. Before the final release the user promised a "final upgrade" — integrating the agent work from `/home/dev/.opencode/agents/`. In raw form these works:

- mix **role**, **protocol**, **knowledge base**, and **output format** in a single 300–600 line file;
- `forensic-orchestrator.md` — this is a workflow engine (DAG, retries, validators), not an agent; the recursion `Agent → Orchestrator → Agents`;
- 14 architecture principles, 5-stage validation, 7-stage forensic protocol — baked into a specific prompt and unavailable for reuse.

This blocks scaling to new models (Gemini/GPT/Kimi/Qwen) and creates duplication. The solution: extract knowledge into a shared `knowledge/` layer, turn the workflow into a SOP, leave roles with only identity, and introduce **Capabilities** (what it can do) and **Artifacts** (what travels between DAG steps) — five first-class entities instead of the old "role-does-everything-in-one".

## Two-repo model (important v1.1 fix)

> This section fixes the fundamental separation of two **different** repositories — the product and the consumer. Before v1.1 this was mixed in INSTALL/playbook/bootstrap: the submodule was mounted at `.context/runtime/naprolom-docs/` (outside `docs/`), which polluted the consumer repo root with service directories. v1.1 establishes a clear model.

### The `naprolom-docs` repository (product)

Runtime sources. All directories at the root are **normal**:

```
naprolom-docs/
├── README.md INSTALL.md
├── playbook/  engine/  bootstrap/  agents/  knowledge/  sops/  docs/  .github/
```

Here docs/ is the project's own dogfood (audits, specs/drafts/this-spec.md).

### Consumer repository (Runtime user)

The user works **only** with `docs/`. The Runtime is **localized** inside `docs/.runtime/`, not scattered across the root:

```
consumer-project/
├── README.md  pyproject.toml ...   ← project code lives as usual
└── docs/
    ├── architecture/  adr/  specs/  audits/  backlog/  api/   ← user content
    └── .runtime/
        └── naprolom-docs/         ← submodule mounts here (NOT in .context/runtime/)
            ├── engine/  bootstrap/  agents/  knowledge/  sops/  playbook/  INSTALL.md  ...
```

Key invariant: **the consumer repo contains exactly one root directory — `docs/`**. All service directories of `naprolom-docs` (agents/, knowledge/, sops/, engine/, bootstrap/, playbook/, agents/, .github/) **do NOT appear in the consumer's root** — they are available **only** via the path `docs/.runtime/naprolom-docs/...`.

### Why this way

1. **User mental model:** "everything about the project is in `docs/`". No "and there is also `agents/`, `knowledge/`..." in the root.
2. **Clear boundary:** `docs/.runtime/` is System-owned (updated via `git submodule update --remote`); `docs/architecture|adr|specs|audits|backlog|api` is User-owned (created and edited by the user).
3. **Bootstrap idempotency:** the script creates/updates only the `docs/` subtree, leaving the root untouched.
4. **Lean .gitignore:** a single line `docs/.runtime/` (if the user chooses to ignore the submodule in the working tree) instead of 7.
5. **Single point for CI/CLI:** all paths are baked into `docs/.runtime/naprolom-docs/...` — compact in the workflow yml, runbooks, and CLAUDE.md snippet.

### What changes technically

| Aspect | What was (v1.0) | What becomes (v1.1) |
|--------|------------------|------------------------|
| Git submodule mount point | `.context/runtime/naprolom-docs/` (outside `docs/`) | `docs/.runtime/naprolom-docs/` (inside `docs/`) |
| `.gitmodules` path | `path = .context/runtime/naprolom-docs` | `path = docs/.runtime/naprolom-docs` |
| Bootstrap invocation | `bash .context/runtime/naprolom-docs/bootstrap/bootstrap.sh` | `bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh` |
| Validator path | `.context/runtime/naprolom-docs/engine/validators/...` | `docs/.runtime/naprolom-docs/engine/validators/...` |
| Templates `cp` | `cp .context/runtime/naprolom-docs/engine/templates/spec.md ...` | `cp docs/.runtime/naprolom-docs/engine/templates/spec.md ...` |
| Knowledge refs (Role → knowledge file) | `.context/runtime/naprolom-docs/knowledge/<id>.md` | `docs/.runtime/naprolom-docs/knowledge/<id>.md` (but roles use short-id — the Runtime resolves the path, D-KR) |
| CLAUDE.md snippet (paths) | references like `.context/runtime/naprolom-docs/...` | references like `docs/.runtime/naprolom-docs/...` |
| CI workflow git checkout | `with: submodules: true` | unchanged (only paths in run: steps) |
| Existing consumers v1.0 | n/a — migration for them is out-of-scope (see §Migration) | (migrate via a single `git mv` of the submodule + update paths in several files; it is so simple it is not worth formalizing as a SOP) |

### What does NOT change

- **The internal structure of the `naprolom-docs` repo** — the root directories remain (`agents/`, `knowledge/`, `sops/`, `engine/`, `bootstrap/`, `playbook/`, `docs/` dogfood). This is the **product**, its layout is our design.
- The **names** and purpose of the directories inside the Runtime stay the same.
- The **CLI interactions** (validate-frontmatter.sh, planner.mjs, migrate-legacy.mjs) stay the same; only the paths to them in the instructions change.
- **Schema v1** frontmatter — no changes.

### Migration for existing v1.0 consumers (optional, not a v1.1 deliverable)

The current dogfooding-target Kordon is not rolled out yet — no migration needed. For any hypothetical v1.0 → v1.1 consumer, the path is: `git mv .context docs/.runtime && git submodule absorbgitdirs` (see git docs). This is a **one-command migration**; we do not formalize it as a SOP (it is a sufficiently rare operation).

## Scope

### Included

1. **New `knowledge/` layer** at the Runtime root with **4** files (minimal set, do not proliferate):
    - `knowledge/README.md` — index, explaining the role of the knowledge ref-layer.
    - `knowledge/architecture-principles.md` — 14 principles (7 base + 7 operational) + 3 meta-patterns (time stratification / semantic density / asymptotic change complexity), extracted from the former `architecture-reviewer.md`.
    - `knowledge/evidence-model.md` — Trust Hierarchy (7 levels) + 4 evidence-classes (OBSERVED/EVIDENCED/INFERRED/CLAIMED) + behavioral rules, extracted from the former `reality-auditor.md`.
    - `knowledge/audit-principles.md` — 5-stage validation protocol + verdict-system (SUSTAINED/WEAKENED/REFUTED/INSUFFICIENT_EVIDENCE) + confidence-model, extracted from the former `adversary-checker.md`.

    > **`knowledge/report-formats.md` (merged)** — replaces both the former `knowledge/review-output-format.md` and the entire output-templates section (see §Decisions D-OT). A single file describing the output formats: architecture-review / reality-audit / adversary-report / forensic-report. **Do not** move them into `engine/templates/` as separate `.md` files — these are knowledge about format, not runtime infrastructure.

    Total: **5 knowledge files** (`README` + 4 substantive: `architecture-principles`, `evidence-model`, `audit-principles`, `report-formats`).
2. **Refactor `agents/{claude-code,opencode}/architecture-reviewer.md`** into a slim form:

    - System Prompt / When you run / Operating protocol → stays; add a **Knowledge refs** block referencing `knowledge/architecture-principles.md` and `knowledge/report-formats.md`.
    - The 14 inline principles and the inline output-format block are removed from the role.
    - Refusal protocol / What you do NOT do stay inline (these are role-specific, not general knowledge).
3. **New roles** in `agents/`:

    - `agents/{claude-code,opencode}/reality-auditor.md` — Project State Reconstruction Agent. Slim role + reference to `knowledge/evidence-model.md`, `knowledge/report-formats.md`. Permissions: `read: allow`, `bash: ask` (read-only investigation only: `git log/diff/show/status/blame`, `find`, `grep`, `tree`, `ls`, `wc`), `edit: deny`, `webfetch: allow`. Never runs tests/build/deploy.
    - `agents/{claude-code,opencode}/adversary-checker.md` — Claim Validation Agent. Slim role + reference to `knowledge/audit-principles.md`, `knowledge/report-formats.md`. Permissions: `read: allow`, `edit: deny`, `bash: deny`, `webfetch: allow`.
4. **The Capabilities concept** — explicitly introduced into the spec, implemented minimally:

    - Each role declares `capabilities:` (list) in the frontmatter (one-way Role→Capability).
    - A SOP step may reference either `role: <name>` (as before), or `capability: <name>` + `role: <name>` (more abstract).
    - The **Capability Catalog** lives in **`knowledge/capabilities.md`** (D-CC) — a separate contract document. It contains **only the Contract** (description / consumes / produces / artifacts), **without `provided by:`** (D-CP) — to avoid creating a two-way Role↔Capability dependency. "Role provides capability" is declared one-way in the Role's own FM (`capabilities: [...]`), and `agents/README.md` provides an overview table of 4-role × capability-list.

    Canonical capability list for v1.1 (brief repeat — definition in `knowledge/capabilities.md`, providers declared in `agents/README.md`):
   | Role | Capability |
   |------|------------|
   | architecture-reviewer | `review-spec`, `review-adr`, `review-domain-model`, `review-security-model` |
   | documentation-reviewer | `validate-frontmatter`, `validate-entity-refs` |
   | reality-auditor | `state-reconstruction`, `drift-analysis`, `architecture-extraction`, `attribution-analysis` |
   | adversary-checker | `claim-validation`, `assumption-analysis` |

5. **New SOP `sops/architecture-review.yaml`** — a formal DAG review pipeline. Sequential (Reality → Architecture, NOT parallel — see §Decisions D-5):
   ```
   reality-auditor             (state reconstruction against actual repo)
            ↓
   architecture-reviewer       (review spec against REAL state, not imagined)
            ↓
   documentation-reviewer      (Schema v1 + entity_refs validity)
            ↓
   adversary-checker            (optionally, manual condition; sm. §Decisions D-8)
            ↓
   human                        (decision gate)
   ```

6. **New SOP `sops/forensic-audit.yaml`** — an abstract 8-step pipeline replacing the former `forensic-orchestrator`-as-agent:
    - Steps 1–8 are a common template (control-objects → actual-control-plane-entity → signal-inventory → attribution-analysis → multi-binding-reality-check → runtime-ownership → reputation-layer-design → final-recommendation), but **without hardcoded domain entities** (`DomainAsset`, `binding_id` etc. — these come from a personal email-infra project). The consumer supplies their own `entities:` and `mechanisms:` in `input.required` (see §Technical approach).
    - **Attribution Analysis (step 4) → `role: reality-auditor`** (NOT adversary-checker; see §Decisions D-7 — attribution is reconstruction, not refutation).
    - **No `constraints:` blocks and no embedded JSON validators** — see §Decisions D-3. A step describes only `capability:`, `role:`, `produces:` (what is produced, a textual description), `depends_on:`. Output validation is the role's responsibility, not the SOP's.
7. **`sops/planner.mjs` stays a DAG-printer, not an executor** (see §Decisions D-2):

    - We do not add retry / scheduler / parallel-execution / resume / checkpoint.
    - Capability support: when printing the DAG, the planner checks that each step specifies either `role:`, or `capability:` (and in the latter case finds the role that provides this capability in `agents/{platform}/`). If a capability is found in no role — a warning, not an error.
    - This is a parser extension, ~10 lines.
8. **Documentation (minimal edits)**:

    - `README.md` — expand "What you get" (4 roles, knowledge layer, 2 SOPs), update the layout diagram, add a Changelog `v1.1 — agentic layer separation`.
    - `INSTALL.md` — mention `knowledge/` in the architecture diagram.
    - `agents/README.md` — expanded role table (4), a new "Capabilities" section, a "Knowledge refs" section.
    - `sops/README.md` — add 2 new SOPs; a section on the parameterized SOP input (entities/mechanisms for forensic-audit); explicitly declare that **the SOP describes orchestration, not validation logic**.
    - `playbook/playbook-v2.md` — **do not touch** (see §Decisions D-4). If an acute need arises, at most one reference in the `## Canonical Source of Truth` table to `knowledge/` — deferred to Phase E marked optional.

9. **Bootstrap** (`bootstrap/bootstrap.sh`, `bootstrap/bootstrap.ps1`): add 2 idempotent lines to the `CLAUDE.md` snippet about `knowledge/` and the optional roles `reality-auditor`, `adversary-checker`. No new directories are created in the consumer repo.

10. **CI validator extension** — extend the existing `engine/validators/validate-frontmatter.sh` with support for the `ROOT` parameter to apply it to `knowledge/` (see §Decisions D-6). In `.github/workflows/docs-validate.yml` add a second step `ROOT=knowledge bash engine/validators/validate-frontmatter.sh knowledge`. **No separate `validate-knowledge.sh`** — we reuse the existing one.

11. **Dogfood: ADR-001 in the `naprolom-docs` repo itself** (see §Decisions D-2): create `docs/adr/001-agentic-layer-separation.md`, `status: accepted`, recording the move from monolithic agents to the 4-layer Role/Knowledge/SOP/Capability model. This illustrates the dogfood model and exercises our own architectural pipeline.

### Excluded

1. **Renaming `agents/` → `roles/`** — breaks the stable v1.0 contracts (INSTALL/README/playbook/consumer plugins). "Role" stays a conceptual unit inside `agents/`; an explicit note in the README.
2. **Output templates as a separate `engine/templates/` subkind** — merged into `knowledge/report-formats.md` (see §Decisions D-OT).
3. **`constraints:` blocks in SOP YAML** — not introduced (see §Decisions D-3). Validation logic is the role's responsibility.
4. **Slash-command bindings** for the new roles — Tier 2, after dogfooding.
5. **Generic parametrized roles** (roles with parameters as in coding-orch frameworks) — out of scope.
6. **`runtime/` wrapper for `engine/` + `bootstrap/`** — see §Out-of-scope follow-up. Not part of v1.1; a possible separate v1.2 refactor.
7. **Additional knowledge files** (a 32-file set would rot into evil) — the rule: "knowledge = durable knowledge". 4 substantive files on v1.1 — that is the ceiling.
8. **Additional roles** (canonical-transformer, spec-reviewer, auditor) — Tier 2.

## Decisions (resolution of Open Questions)

| ID | Question | Decision | Rationale |
|----|--------|---------|-------------|
| D-1 | `status` for output templates | N/A | Output templates as a separate kind are removed (D-OT). |
| D-OT | Output templates as engine/templates/ | **Remove**, merge into `knowledge/report-formats.md` | This is not runtime infrastructure but knowledge about format. No one will `cp` them. A single markdown file is easier to maintain. |
| D-2 | `docs/adr/001-agentic-layer.md` in naprolom-docs (dogfood) | **Yes** | This is the arch-combo "choosing between two good options" — the very reason ADRs exist. |
| D-3 | `constraints:` blocks in SOP YAML | **Remove** | A SOP answers only "who / after whom / what it produces". Validation logic belongs to the role, not the process description. |
| D-P | `planner.mjs` role | **DAG-printer, not executor** | Otherwise in a month it grows into a small Airflow (retry/scheduler/parallel/resume/checkpoint). |
| D-C | Capabilities layer | **Introduce as concept + convention** | Lets us tomorrow decouple the SOP from a specific role/model. Without a separate directory. |
| D-4 | `playbook/playbook-v2.md` edits | **Do not touch** (max 1 reference) | Playbook = consumer-facing greenfield playbook, not naprolom-docs' own changelog. |
| D-5 | DAG `architecture-review.yaml` step 1→2 | **Sequential** | Reality → Architecture. Otherwise Architecture analyzes assumptions again, not reality. |
| D-6 | Validation of `knowledge/` in CI | **Extend the existing validator via the `ROOT` env**, without a second script | `ROOT=knowledge bash engine/validators/validate-frontmatter.sh knowledge` — clean and DRY. |
| D-7 | Attribution analysis role in `forensic-audit.yaml` | **`reality-auditor`** (not adversary-checker) | Attribution is reconstruction from signals, not refutation. Adversary checks others' finished conclusions. |
| D-8 | Adversary-checker condition in `architecture-review.yaml` | **Manual gate** | Human at step 5 decides whether an adversary is needed. No automatic `if high-impact`. |
| D-9 | `audit.yaml` vs `architecture-review.yaml` overlap | **Keep both** | Audit = post-incident/scheduled; arch-review = pre-merge. Different purposes. |
| D-A | Artifact as a first-class entity | **Introduce in v1.1** | The DAG connects via artifacts (Data Flow), not via "role→role". Raises the model's expressiveness almost for free. |
| D-CC | Capability Catalog location | **`knowledge/capabilities.md`** (not `agents/README.md`) | The README stays an overview; Capability becomes an independent system contract. |
| D-CP | Capability Catalog: providers field | **No `provided by:`** in the catalog | Break the two-way Role↔Capability dependency. The catalog contains only the **Contract** (description / consumes / produces / artifacts). "Role provides capability" is declared one-way in the Role itself (the `capabilities:` list in the FM of `agents/**/*.md`). |
| D-KR | Knowledge refs format | **Short-id*, not hardcoded path | In the Role FM: `knowledge: [architecture-principles, report-formats]`. The path is resolved by the Runtime (convention: `knowledge/<id>.md`). Allows changing the structure of `knowledge/` without rewriting the roles. |
| D-PL | planner.mjs scope | **Only roles + capabilities + SOP** (NOT knowledge) | Otherwise the planner gradually becomes the Runtime. Knowledge loading is the responsibility of the SOP/Role when executing a step, not the planner's. |
| D-HG | Human steps in SOP | **`gate: manual`** (not `role: human`) | Human is not a Runtime role. The planner prints `gate: manual` explicitly. For backend-compat with v1.0 SOPs, the planner accepts `role: human` as an alias and visualizes it as `gate: manual`. The existing 7 v1.0 SOPs are left untouched. |
| D-BR | Bootstrap deploy location in the consumer repo | **`docs/.runtime/naprolom-docs/`** (NOT `.context/runtime/...` at the root) | The user works only with `docs/`. The Runtime is localized inside `docs/.runtime/`, not scattered across the root. See §Two-repo model. Affects bootstrap paths, INSTALL, the playbook, the CLAUDE.md snippet, and all SOP/Role references to the Runtime. |

## Artifact model

> **Artifact** — a first-class entity that denotes what **travels between DAG steps**. Before v1.1, steps were connected implicitly via `depends_on: [<step-id>]` + a text description of `produces:`. From v1.1, an explicit `artifact:` contract is introduced in the SOP YAML.

### Why

Without an explicit artifact, the DAG connects steps by number:
```
step 1 → step 2 → step 3
```
This is control flow. But what the roles actually need is data flow — what step 1 _produced_ and what step 2 _consumed_. An explicit `artifact:` makes the contract two-sided:
```
step 1 produces reality-report
                    ↓ consumed by
step 2 (together with the Spec artifact)
                    produces architecture-findings
                                ↓ consumed by
step 4 adversary-checker
                    produces validated-findings
```

### Canonical artifact names (v1.1)

| Artifact | Producer | Consumer(s) | Description |
|----------|----------|-------------|----------|
| `reality-report` | reality-auditor | architecture-reviewer, adversary-checker | Current State Report (feature inventory, drift, architecture-extraction) |
| `architecture-findings` | architecture-reviewer | documentation-reviewer, adversary-checker, human | Findings: invariants, drift, missing ADRs, security |
| `documentation-report` | documentation-reviewer | human | Schema v1 compliance + entity_refs validity report |
| `validated-findings` | adversary-checker | human | Per-finding verdicts (SUSTAINED/WEAKENED/REFUTED) + confidence matrix |
| `forensic-report` | human (final merger in forensic-audit SOP) | — (artifact terminal: docs/audits/) | 8-part forensic audit report |
| `current-state-{context}` | any producer | any |  generic context artifact; a prefix, not a specification |

### Format in SOP YAML

Each step in `steps:` declares a **mandatory** `produces:` (artifact name) and an optional `consumes:` (list of artifacts from previous steps). `depends_on:` is retained — it is about control flow (execution order); `consumes:` is about data flow (what is used as input). In most cases they are isomorphic, but these are **different intents**, and their explicit separation gives the future system flexibility:

```yaml
- id: 2
  name: Architecture review against REAL state
  capability: review-spec
  role: architecture-reviewer
  consumes: [reality-report, spec]   # data flow: what we receive as input
  produces: architecture-findings   # data flow: what we pass downstream
  depends_on: [1]                    # control flow: after which step
```

### Rules

1. **Artifact name** — kebab-case, `^[a-z][a-z0-9-]*$`. Stable: if the name changes, that is a breaking change in the SOP contract (requires a SOP version bump).
2. **Planner** prints `consumes →` `produces` in the DAG visualization, alongside the control-flow `depends_on`. No execution logic.
3. **Adversary-checker** in `architecture-review.yaml` step 4 — `consumes: [architecture-findings]` (NOT `reality-report`), since it validates finished conclusions, not raw state. Example of data-flow differing from control-flow: in step 4 `depends_on: [1, 2]` (control flow: after both), but `consumes: [architecture-findings]` (data flow: consumed only from step 2 — step 1's contribution is already "embedded" in the findings via step 2's architectural layer).
4. Terminal artifacts (live in `docs/audits/`, `docs/adr/`, `docs/specs/implemented/`) have no consumer — they are persisted in the repo.
5. `artifact:` (string) — deprecated alias of `produces:` for the text description; for v1.1 **both are mandatory**: `produces: <artifact-name>` (strict contract) + `note: <free-form>` (human description). See examples in §Technical approach below.

## Technical approach

### Target structure (VLAD — two edits: product + consumer)

#### A. The `naprolom-docs` repository (product) — layout unchanged:

```
naprolom-docs/
├── README.md  INSTALL.md
├── playbook/              # Documentation Model layer (v1.0, don't touch layout, only paths inside files)
├── engine/
│   ├── templates/         # v1.0 templates (6) — NO new output-templates
│   ├── schemas/            # unchanged
│   ├── validators/         # unchanged (validate-frontmatter.sh already accepts ROOT)
│   └── scripts/           # unchanged
├── bootstrap/             # output snippet +2 lines in CLAUDE.md; paths in comments/snippet migrate (Phase 0)
├── agents/
│   ├── README.md          # extended: 4 roles + capabilities + knowledge refs
│   ├── claude-code/
│   │   ├── architecture-reviewer.md   # refactored (slim) + capabilities
│   │   ├── documentation-reviewer.md   # unchanged (on v1.1 — capabilities added only in FM)
│   │   ├── reality-auditor.md          # NEW
│   │   └── adversary-checker.md        # NEW
│   └── opencode/
│       ├── architecture-reviewer.md   # mirror
│       ├── documentation-reviewer.md   # mirror
│       ├── reality-auditor.md          # NEW
│       └── adversary-checker.md        # NEW
├── knowledge/             # NEW LAYER — v1.1
│   ├── README.md
│   ├── architecture-principles.md
│   ├── evidence-model.md
│   ├── audit-principles.md
│   ├── report-formats.md   # merged (replacement of all output templates + review-output-format)
│   │   └── reality-auditor.md          # NEW (Phase B4)
│   │   └── adversary-checker.md        # NEW (Phase B6)
│   └── opencode/  (mirror claude-code/)
│   └── capabilities.md     # NEW (D-CC): capability catalog — system contract, not README
├── sops/
│   ├── README.md          # extended
│   ├── planner.mjs        # unchanged + ~15 lines cap-check / artifact-aware DAG printing
│   ├── architecture-review.yaml   # NEW (review pipeline DAG)
│   ├── forensic-audit.yaml        # NEW (8-step, replaces forensic-orchestrator as agent)
│   └── (existing 7 SOPs unchanged — planner treats role:human as alias for gate:manual, D-HG)
├── docs/
│   ├── adr/
│   │   └── 001-agentic-layer-separation.md   # NEW (dogfood ADR, Phase E)
│   ├── audits/
│   └── specs/drafts/
│       └── 2026-07-08-agentic-layer.md   # /this/ spec
└── .github/workflows/docs-validate.yml       # +1 step (ROOT=knowledge in naprolom-docs itself)
```

> **Note:** `2026-07-08-agentic.md` (raw input) already removed at start of v3-revisions — marked done in Phase G1.

#### B. Consumer repository (after `bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh`) — NEW in v1.1 (D-BR):

```
consumer-project/
├── README.md, package.json, src/, tests/ ...   ← regular project code
├── CLAUDE.md                                    ← generated by bootstrap (snippet with refs to docs/.runtime/...)
└── docs/                                        ← ONLY root documentation directory
    ├── architecture/  adr/  specs/  audits/  backlog/  api/   ← user content (created by user)
    ├── runbooks/  guides/  ...                                ← user content
    └── .runtime/                                              ← System-owned (updated from submodule)
        └── naprolom-docs/                                     ← submodule mount point (D-BR)
            ├── engine/  bootstrap/  agents/  knowledge/  sops/  playbook/  INSTALL.md  README.md
            └── (.github/ — only if consumer inherits workflow templates; usually not needed, CI workflow lives in consumer's .github/workflows/, refs to docs/.runtime/naprolom-docs/...)
```

> **Invariant:** the consumer repo root contains **no** `agents/`, `knowledge/`, `sops/`, `engine/`, `bootstrap/`, `playbook/`, or `.context/runtime/` directories. Everything related to the Runtime is available **only** via `docs/.runtime/naprolom-docs/...`.
Frontmatter Schema v1, `type: guide`, `kind: index`, `status: active`. The content is markdown with numbered principles/classes/protocols, ready for inline reading by an AI agent. It is not executed, but loaded into the roles' context by reference.

### Capabilities convention

Each role declares `capabilities:` (list) in frontmatter:
```yaml
capabilities: [review-spec, review-adr, review-domain-model, review-security-model]
```

**Capability catalog** — a separate document **`knowledge/capabilities.md`** (D-CC). It contains **only the Contract** per capability (description, consumes, produces, artifacts), **without `provided by:`** (D-CP) — a one-way Role→Capability, declared in the Role FM. `agents/README.md` provides an overview table (Role → capability list) + a pointer to `knowledge/capabilities.md`. **The planner.mjs does not read the contents of `knowledge/`** (D-PL) — only roles (`agents/{platform}/`), capabilities (the per-role FM `capabilities:` field), and SOPs (`sops/*.yaml`).

**Knowledge refs** — the Role declares them in the FM:
```yaml
knowledge: [architecture-principles, report-formats]
```
**Short-id**, not a hardcoded path (`knowledge/architecture-principles.md`). The path is resolved by the Runtime at load time (convention: `knowledge/<short-id>.md`). This allows changing the structure of `knowledge/` without rewriting the roles (D-KR).

SOP step may reference:
```yaml
# option 1 — role directly (v1.0 style, compat)
role: reality-auditor

# option 2 — capability + role (v1.1 style, future-proof)
capability: state-reconstruction
role: reality-auditor

# option 3 — capability only (v1.2 future, requires agent resolution; planner warns)
capability: state-reconstruction
```

v1.1 supports option 1 + option 2. Option 3 — planner warning, not an error.

### Format of SOP `sops/forensic-audit.yaml` (simplified, no constraints, with artifact contracts)

```yaml
name: forensic-audit
description: 8-step multi-pass forensic audit pipeline (replaces ad-hoc forensic agent)
triggers:
  - manual invocation for deep architectural forensic
  — after an incident with an architectural cause
input:
  required:
    - type: spec|adr|audit
      path: <target subject document>
      artifact: subject-document
    - type: list
      name: entities
      note: "domain entities of the consumer (e.g., DomainAsset, UserAccount — NOT hardcoded in SOP)"
    - type: list
      name: mechanisms
      note: "governance mechanisms for audit"
output:
  - artifact: forensic-report
    final_path: docs/audits/YYYY-MM-DD-forensic-<topic>.md
    type: audit
    status: completed
steps:
  - id: 1
    name: Control Objects Identification
    capability: state-reconstruction
    role: reality-auditor
    platform: any
    consumes: [subject-document]
    produces: control-objects-matrix
    note: "ownership_matrix (entities × is_resource/is_route/is_reputation/is_execution/is_observation/is_decision) + evidence"
    depends_on: []
  - id: 2
    name: Actual Control Plane Entity
    capability: state-reconstruction
    role: reality-auditor
    platform: any
    consumes: [control-objects-matrix]
    produces: control-plane-answer
    note: "answer (A-E) + mechanisms + code_refs + confidence"
    depends_on: [1]
  - id: 3
    name: Signal Inventory
    capability: state-reconstruction
    role: reality-auditor
    platform: any
    consumes: [subject-document]
    produces: signal-inventory
    note: "external/internal signals × granularity/attribution"
    depends_on: [1]
  - id: 4
    name: Attribution Analysis
    capability: attribution-analysis    # D-7: reality, not adversary
    role: reality-auditor
    platform: any
    consumes: [signal-inventory, control-objects-matrix]
    produces: attribution-analysis
    note: "per-source attribution (hard/probabilistic/impossible) + reasoning"
    depends_on: [3]
  - id: 5
    name: Multi-Binding Reality Check
    capability: state-reconstruction
    role: reality-auditor
    platform: any
    consumes: [control-plane-answer, attribution-analysis]
    produces: multi-binding-verdict
    note: "verdict + evidence + contradictions"
    depends_on: [2]
  - id: 6
    name: Runtime Ownership Analysis
    capability: architecture-extraction
    role: reality-auditor
    platform: any
    consumes: [control-objects-matrix, multi-binding-verdict]
    produces: runtime-ownership-report
    note: "runtime_owner + per-attribute owner + conflict_behavior"
    depends_on: [5]
  - id: 7
    name: Reputation Layer Design (architecture recommendation)
    capability: review-domain-model
    role: architecture-reviewer
    platform: any
    consumes: [attribution-analysis, runtime-ownership-report]
    produces: reputation-layer-design
    note: "layer_responsibilities + unified_reputation_identity_exists?"
    depends_on: [4, 6]
  - id: 8
    name: Final Recommendation (ADR-precursor, human merge)
    gate: manual         # D-HG: NOT role: human — human is not a Runtime role
    consumes: [reputation-layer-design, runtime-ownership-report, attribution-analysis]
    produces: forensic-report
    note: "adr_recommendation + risk_register + open_questions → docs/audits/YYYY-MM-DD-forensic-<topic>.md (terminal artifact)"
    depends_on: [7]
```

Note:
- **No `constraints:`, `must_have:`, `min_mechanisms:`, etc.** The role itself knows what to produce — `note:` is textual, not a JSON-schema (D-3).
- **`produces:`** — the kebab-case artifact name (contract). **`note:`** — a free-form, human-readable description. **`consumes:`** — a list of artifact names from previous steps (data flow). **`depends_on:`** — control flow (after which step). See §Artifact model.
- **`gate: manual`** instead of `role: human` (D-HG). The human is not a Runtime role and not a capability provider. The planner prints it as a manual-gate step. The existing 7 v1.0 SOPs with `role: human` are accepted by the planner as an alias and visualized as `gate: manual` (backend-compat).
- In step 4 (Attribution Analysis): `consumes: [signal-inventory, control-objects-matrix]` but `depends_on: [3]` — control-flow from 3, while data-flow comes from the two artifacts of steps 3 and 1. An example of divergence; it lets future roles explicitly declare consumption without "orchestrating" the full depends_on (step 2 already comes after step 1, so step 1's artifact is available).
- `id: 8 produces: forensic-report` — a terminal artifact. It is persisted in the repo as `docs/audits/YYYY-MM-DD-forensic-<topic>.md`. Without an executor in v1.1 this contract is only a declaration (the human knows which final artifact they must assemble); a future executor (v1.2) turns the "terminal artifact" into a persist-commit.

### Format of SOP `sops/architecture-review.yaml` (simplified)

```yaml
name: architecture-review
description: Formal review-pipeline DAG (reality → arch review → doc review → adversary optional → human)
triggers:
  - PR touching docs/specs/drafts/ or docs/specs/review/
  - PR flagged with [architecture-review] label
input:
  required:
    - type: spec
      path_pattern: docs/specs/{drafts,review}/*.md
      artifact: subject-spec
output:
  - artifact: arch-review-report
    path: docs/audits/YYYY-MM-DD-arch-review-<slug>.md
    type: audit
    status: draft
steps:
  - id: 1
    name: Reality reconstruction
    capability: state-reconstruction
    role: reality-auditor
    platform: any
    consumes: [subject-spec]
    produces: reality-report
    note: "current state report — feature inventory, drift, architectural reality"
    depends_on: []
  - id: 2
    name: Architecture review against REAL state
    capability: review-spec
    role: architecture-reviewer
    platform: any
    consumes: [reality-report, subject-spec]
    produces: architecture-findings
    note: "findings: invariants, drift, missing ADRs, security"
    depends_on: [1]   # D-5: sequential, NOT parallel
  - id: 3
    name: Documentation review
    capability: validate-frontmatter
    role: documentation-reviewer
    platform: any
    consumes: [subject-spec]
    produces: documentation-report
    note: "Schema v1 compliance + entity_refs validity"
    depends_on: [2]
  - id: 4
    name: Adversary validation (optional, human decision gate)
    capability: claim-validation
    role: adversary-checker
    platform: any
    consumes: [architecture-findings]
    produces: validated-findings
    note: "per-finding verdicts (SUSTAINED/WEAKENED/REFUTED) + confidence matrix"
    depends_on: [1, 2]   # control flow: after both; data flow: consumes only from step 2 (reality-report already embedded in findings)
    condition: manual    # D-8: human decides at step 5
  - id: 5
    name: Human decision gate
    gate: manual         # D-HG: NOT role: human — human is not a Runtime role
    consumes: [architecture-findings, documentation-report, validated-findings]
    produces: decision-gate-result
    note: "approve / request-changes / reject + trigger step 4 if needed"
    depends_on: [3]
```

> **Ambiguity removed:** in step 5 the control-flow is `depends_on: [3]`, but the data-flow is `consumes: [architecture-findings, documentation-report, validated-findings]` (step 4). This is **correct and normal**, since step 4 is optional (`condition: manual`); if step 4 is gate-skipped, the `validated-findings` artifact is not produced and `consumes:` has one fewer item. Without an executor in v1.1 this is just a contract declaration; in v1.2 the executor will check the arity of consumes vs available artifacts.
>
> **Terminal artifact:** `decision-gate-result` — in v1.1 it is not persisted to the repo; it is used for the human action (approve/reject/changes-requested). An intermediate pipeline artifact.

### Bootstrap CLAUDE.md snippet change

After the existing 5 rules, add 2 (idempotently, via `grep -q`):
```
6. If the task involves architectural review — see sops/architecture-review.yaml; foundation is reality-auditor BEFORE architecture-reviewer.
7. Shared knowledge bases live in `docs/.runtime/naprolom-docs/knowledge/` (architecture-principles, evidence-model, audit-principles, report-formats, capabilities) — roles reference them by short-id, not inlined.
```

## Affected files

### NEW
- `docs/specs/drafts/2026-07-08-agentic-layer.md` — this file
- `docs/adr/001-agentic-layer-separation.md` — dogfood ADR (D-2)
- `knowledge/README.md`
- `knowledge/architecture-principles.md`
- `knowledge/evidence-model.md`
- `knowledge/audit-principles.md`
- `knowledge/report-formats.md` (merged — replacement output templates + review-output-format)
- `knowledge/capabilities.md` — NEW (D-CC): capability catalog — the capability contract channel; not in agents/README
- `agents/claude-code/reality-auditor.md`
- `agents/opencode/reality-auditor.md`
- `agents/claude-code/adversary-checker.md`
- `agents/opencode/adversary-checker.md`
- `sops/architecture-review.yaml`
- `sops/forensic-audit.yaml`

### MODIFIED
- `agents/claude-code/architecture-reviewer.md` — refactor to slim + `capabilities:` field
- `agents/opencode/architecture-reviewer.md` — mirror
- `agents/claude-code/documentation-reviewer.md` — add `capabilities:` to the FM (minimal)
- `agents/opencode/documentation-reviewer.md` — mirror
- `agents/README.md` — extended: 4 roles + capabilities overview section (pointer to `knowledge/capabilities.md`) + Knowledge refs section + layout. **NO capability definitions inline** — catalog lives in `knowledge/capabilities.md`
- `sops/README.md` — extended: 2 new SOPs + capabilities overview + parametrized input note + 'SOP = orchestration, not validation' + 'Artifact contracts' clarifier (what `consumes:`/`produces:` mean)
- `sops/planner.mjs` — ~15 lines: verify `role:` or `capability:` (warning on capability-only without role); print `consumes →` `produces` between steps in DAG visualization
- `README.md` — layout + What you get + Changelog v1.1
- `INSTALL.md` — knowledge/ mention in architecture diagram
- `bootstrap/bootstrap.sh` — CLAUDE.md snippet +2 lines
- `bootstrap/bootstrap.ps1` — mirror
- `.github/workflows/docs-validate.yml` — +1 step `ROOT=knowledge bash engine/validators/validate-frontmatter.sh knowledge`

### DELETED
- `docs/specs/drafts/agentic.md` — raw source; content preserved in git history (commit after Phase G2). Do not duplicate verbatim in spec (see §Appendix A note).

## Work Plan

### Phase 0 — Bootstrap path migration (D-BR)
**First — the fundamental fix**, then everything else. What changes is only **where bootstrap deploys Runtime in the consumer repo**:  from `.context/runtime/naprolom-docs/` to `docs/.runtime/naprolom-docs/`. Internal structure of `naprolom-docs` (the product) does NOT change.
0.1. `bootstrap/bootstrap.sh`:
   - `RUNTIME_ROOT` (submodule mount path detection) — leave as-is (it is determined from the location of bootstrap.sh внутри `naprolom-docs`, this does not depend on WHERE `naprolom-docs` itself is mounted).
   - comments in header: update paths 'Run from the ROOT of the consumer project' — instead of `.context/runtime/naprolom-docs/bootstrap/bootstrap.sh` use `docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh`.
   - check_gitmodules_path(): new helper (idempotent), which checks that `.gitmodules` points to `docs/.runtime/naprolom-docs`, NOT `.context/runtime/naprolom-docs`. If v1.0 path found — warn-only on v1.1 (consumers can migrate themselves via `git mv`). Это **advisory check**, does not block bootstrap.
   - in `CLAUDE.md` snippet paths: `.context/runtime/naprolom-docs/...` → `docs/.runtime/naprolom-docs/...`.
0.2. `bootstrap/bootstrap.ps1` — mirror 0.1 (PS syntax, single-quoted strings).
0.3. `INSTALL.md` — all command examples (`git submodule add ...`, `git submodule update --remote`, `bash .context/runtime/naprolom-docs/...`, `.gitmodules` блок) switch to `docs/.runtime/naprolom-docs/`. Architecture diagram — update consumer side: `docs/` contains user-content + `.runtime/`. Добавить новый §«Two-repo model» subsection, explaining product vs consumer (D-BR mapping). В.Importantly: **large subsection on self-vs-consumer** для clear separation.
0.4. `playbook/playbook-v2.md` — in §Bootstrap section update path to bootstrap.sh via `docs/.runtime/...`. В §Phase 1, §Phase 3, §Phase 4, §Canon Source of Truth — all `cp .context/runtime/naprolom-docs/engine/templates/...` → `cp docs/.runtime/naprolom-docs/engine/templates/...`. В §CI Schema v1 Guard — `bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh`.
0.5. `playbook/migrate-legacy.md` — if paths to migrate-legacy.mjs are mentioned — update to `docs/.runtime/...`. Check with grep.
0.6. `playbook/install-remote-prompt.md` — verify/update paths in instructions for remote agent.
0.7. `README.md` — Quick Start commands (`bash .context/runtime/naprolom-docs/...`) → `docs/.runtime/naprolom-docs/...`. Update consumer-side layout diagram.
0.8. `agents/README.md`, `sops/README.md` — any mentions of `.context/runtime/...` → `docs/.runtime/...`.
0.9. Existiong agent role files (`agents/claude-code/*.md`, `agents/opencode/*.md`) — in operating protocol may have hardcoded `.context/runtime/...` paths (например, architecture-reviewer ссылается `.context/runtime/naprolom-docs/playbook/playbook-v2.md`). Update all to `docs/.runtime/naprolom-docs/...`. Это часть Phase B refactor, но пути фиксируются здесь, so concerns don't overlap (slim refactor + path migration in one step).
0.10. `.github/workflows/docs-validate.yml` — in `run:` block update the validator path на `docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh` (in the **naprolom-docs** repo itself — validator lives in `engine/`, path stays local; this is about the **consumer workflow** that install-remote-prompt copies into the consumer repo).
0.11. `engine/validators/validate-frontmatter.sh` header — update example usage paths.
0.12. `engine/scripts/migrate-legacy.mjs` header comments — update consumer invocation examples.

> Phase 0 — это **sweep across all doc files**. grep for `.context/runtime` in `naprolom-docs` repo must return 0 matches after Phase 0 (except this spec file, where v4-changelog and §Two-repo model may mention old paths in historical comparison — this is OK).

### Phase A — Knowledge layer (minimum, without over-engineering)
A1. `knowledge/README.md` — index, explaining role knowledge refs.
A2. `knowledge/architecture-principles.md` — extract from Appendix A `architecture-reviewer.md` §«Analysis Principles» (14 + 3 meta). FM: `type: guide, kind: index, status: active, owners: [naprolom-team]`, `id: knowledge-architecture-principles`.
A3. `knowledge/evidence-model.md` — из Appendix A `reality-auditor.md` §«Trust Hierarchy» + §«Evidence Classification» + §«Behavioral Rules». FM аналогично.
A4. `knowledge/audit-principles.md` — из Appendix A `adversary-checker.md` §«5-Stage Validation Protocol» + §«Verdict System» + §«Confidence Model» + §«Behavioral Constraints».
A5. `knowledge/report-formats.md` — normalized description of output formats for 4 reviewers (architecture-review / reality-audit / adversary-report / forensic-report) from their inline blocks in Appendix A. One file.
A6. `knowledge/capabilities.md` — NEW (D-CC): capability catalog. Content per-capability entry: description, consumes, produces, **WITHOUT `provided by:`** (D-CP — one-directional Role→Capability in Role FM, not in the catalog). Формат:
   ```
   ## capability: review-spec
   Description: <one-line>
   Consumes: spec (artifact), reality-report (artifact)
   Produces: architecture-findings (artifact)
   ```
   'Role→Capability' mapping lives in `agents/README.md` overview table (see E4), **not here**.

### Phase B — Roles
> All roles declare knowledge refs in FM as **short-id list** (D-KR): `knowledge: [architecture-principles, report-formats]`. **No hardcoded `knowledge/...path...md` paths in the role body.** Role body references knowledge by short-id in prose («See knowledge: architecture-principles»), Runtime resolves the path when loading.

B1. Refactor `agents/claude-code/architecture-reviewer.md`:
   - Slim: System Prompt / When / Operating protocol / Refusal / What you do NOT do.
   - FM additions:
     ```yaml
     capabilities: [review-spec, review-adr, review-domain-model, review-security-model]
     knowledge: [architecture-principles, report-formats]
     ```
   - Remove 14 inline principles and output-format block.
B2. Mirror B1 в `agents/opencode/architecture-reviewer.md` + opencode-style FM (`description`, `mode: subagent`, `permission`, `color`, `hidden`).
B3. Minimal touch `agents/claude-code/documentation-reviewer.md` + `.opencode` mirror — add to FM:
   ```yaml
   capabilities: [validate-frontmatter, validate-entity-refs]
   knowledge: [report-formats, schema-v1]
   ```
B4. Create `agents/claude-code/reality-auditor.md`:
   - System Prompt (Reality Auditor), When you run, Operating protocol (7-stage), Refusal (no recommendations, no judgments; state reconstruction only), What you do NOT do (no tests/build/deploy).
   - FM:
     ```yaml
     capabilities: [state-reconstruction, drift-analysis, architecture-extraction, attribution-analysis]
     knowledge: [evidence-model, report-formats]
     ```
   - Permissions: `read: allow`, `bash: ask` (read-only whitelist: `git log/diff/show/blame`, `find`, `grep`, `tree`, `ls`, `wc`), `edit: deny`, `webfetch: allow`.
B5. Mirror B4 в `agents/opencode/reality-auditor.md`.
B6. Create `agents/claude-code/adversary-checker.md`:
   - System Prompt (Claim Validation), Input (Finding Set), 5-stage protocol (prose references knowledge: audit-principles), Output (prose references knowledge: report-formats), Refusal, Stalemate Protocol, What you do NOT do.
   - FM:
     ```yaml
     capabilities: [claim-validation, assumption-analysis]
     knowledge: [audit-principles, report-formats]
     ```
   - Permissions: `read: allow`, `bash: deny`, `edit: deny`, `webfetch: allow`.
B7. Mirror B6 в `agents/opencode/adversary-checker.md`.

### Phase C — SOPs (упрощённые, с artifact contracts)
C1. `sops/forensic-audit.yaml` — как в §Technical approach: `consumes:`/`produces:`/`note:`/`depends_on:`, без `constraints:`.
C2. `sops/architecture-review.yaml` — sequential DAG (D-5), с artifact contracts (`reality-report` → `architecture-findings` → `documentation-report` → `validated-findings` → `decision-gate-result`).

### Phase D — planner extension (минимальное)
D1. `sops/planner.mjs` — добавить в парсер шагов чтение `capability:` (опционально) + `role:` (опционально, но хотя бы один из двух обязателен; otherwise warning). Если step указывает `capability:` без `role:` — warning. Также читать `consumes:`/`produces:` и печатать их в DAG visualization рядом с control-flow `depends_on:` (data-flow arrows). Не более ~15 строк кода, никакой логики executor'а.

### Phase E — Documentation & dogfood
E1. `docs/adr/001-agentic-layer-separation.md` — dogfood ADR. FM: `id: adr-001-agentic-layer-separation, type: adr, status: accepted, date: 2026-07-08, owners: [naprolom-team]`. Body: Status / Context / Decision / Consequences. Decision описывает **5-слойную модель** (Knowledge / Role / Capability / SOP / Artifact), rationale, почему не переименовали `agents/` → `roles/`, почему output templates влит в knowledge, почему capability каталог живёт в `knowledge/capabilities.md`.
E2. `README.md` — обновить layout diagram (+ `knowledge/`, включая `capabilities.md`), What you get расширить до 4 ролей + 6 knowledge + 9 SOPs, Changelog добавить `v1.1 — agentic layer: Knowledge/Role/Capability/SOP/Artifact separation`.
E3. `INSTALL.md` — architecture diagram с `knowledge/`.
E4. `agents/README.md` — extended таблица roles (4) с колонкой capabilities (Role→Capability односторонне, это и есть providers mapping — см. D-CP); раздел «Capabilities» (overview + указатель на `knowledge/capabilities.md`, **БЕЗ inline capability definitions** — каталог живёт там); раздел «Knowledge refs» (короткий: объясняет short-id формат в Role FM `knowledge: [...]` и что путь резолвит Runtime); обновить layout.
E5. `sops/README.md` — добавить 2 новых SOP; раздел про parametrized input (`entities`/`mechanisms` в forensic-audit) с примером; clarifier «SOP описывает **оркестрацию**, не validation logic»; новый раздел «Artifact contracts» с пояснением `consumes:`/`produces:` и разницей data-flow vs control-flow (`depends_on:`); заметка про `gate: manual` для human steps (D-HG, с backend-compat note про `role: human` в существующих 7 SOP v1.0).
E6. `bootstrap/bootstrap.sh` — CLAUDE.md snippet +2 lines (идемпотентно, через `grep -q`).
E7. `bootstrap/bootstrap.ps1` — mirror E6 PS syntax.

### Phase F — CI & validation
F1. `.github/workflows/docs-validate.yml` — добавить второй шаг:
   ```yaml
   - name: Validate knowledge/ frontmatter
     run: ROOT=knowledge bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh knowledge
   ```
F2. Smoke test локально: `ROOT=docs bash engine/validators/validate-frontmatter.sh` и `ROOT=knowledge bash engine/validators/validate-frontmatter.sh knowledge` — оба должны `OK`.
F3. `node sops/planner.mjs forensic-audit --platform opencode` — печатает DAG с data-flow arrows (consumes → produces), control-flow (depends_on), gate-шаги как `gate: manual`. **Planner must NOT read contents of `knowledge/`** (D-PL) — only roles (`agents/{platform}/` *.md FM), capabilities (per-role FM), SOP (`sops/*.yaml`).
F4. `node sops/planner.mjs architecture-review --platform opencode` — prints sequential DAG (step 2 depends on step 1), step 5 как `gate: manual`.
F5. Dogfood self-review: invoke `architecture-reviewer` on this spec; apply corrections from findings.

### Phase G — Cleanup & commit
G1. Remove `docs/specs/drafts/agentic.md` (raw input preserved via git history). **DONE at start of v3-revisions.**
G2. Single commit `feat(runtime): v1.1 agentic layer — knowledge/, capabilities, +2 roles, architecture-review + forensic-audit SOPs`.
G3. Do NOT push. Show `git diff` to user for final review.

## Open questions (minimum, all previously unresolved — resolved in §Decisions)

All initial Open Questions resolved in §Decisions (D-1 ÷ D-9 + D-OT/D-P/D-C/D-A/D-CC/D-CP/D-KR/D-PL/D-HG). 2 secondary ones remain, not blocking:

Q-1. После Phase E: treat the created `docs/adr/001-...` as a full canonical ADR (validate it via `validate-frontmatter.sh` on strict-CI)? Рекомендация: **да** (it lives in `docs/adr/`, validator already covers it — this is the dogfood proof).

Q-2. В `knowledge/capabilities.md` на v1.1 — publish per-capability entry with **consumes/produces** artifact contract (full contract) или достаточно **description-only**? Рекомендация: **полный contract** (description + consumes + produces + artifacts) — без `provided by:` (см. D-CP). Capabilities.md was created to be a contract, not a list of names.

## Out-of-scope follow-up (v1.2 candidate)

Outside this spec, but proposed by the reviewer как будущая доработка. **Does not block v1.1 release** — Runtime already working; these are polish.

### Structural
- **`runtime/` wrapper внутри naprolom-docs.** Внутри репо продукта — обернуть `engine/` + `bootstrap/` в один каталог `runtime/`, чтобы корень продукта стал минимально чистым:
  ```
  README.md INSTALL.md
  runtime/   (engine, bootstrap, ...)
  agents/  knowledge/  sops/  docs/  .github/
  ```
  Это **не влияет на consumer'а** (в consumer'е всё уже локализовано в `docs/.runtime/naprolom-docs/...` благодаря D-BR). Изменение касается только читаемости репо `naprolom-docs` (продукта). Низкий приоритет — layout продукта уже приемлемый.
  В v1.1 НЕ ВХОДИТ — фиксируется здесь как roadmap reference.

### Knowledge layer refactor
- **Group `knowledge/` by domain**, а не по происхождению от ролей. Например:
  ```
  knowledge/
    architecture/   (principles.md, anti-fragility.md, decision-making.md)
    documentation/  (schema-v1.md, entity-model.md)
    review/         (evidence.md, confidence.md, reports.md)
    capabilities.md
  ```
  Why deferred: на v1.1 knowledge-файлов всего 5 (4 содержательных + README), группировка premature and complicates paths. When files > 10 — reconsider.

### SOP/Role contract
- **Knowledge loading from SOP, not from Role.** v1.1 уже ввёл **short-id knowledge refs** в Role FM (D-KR): `knowledge: [architecture-principles]` — путь резолвит Runtime. Следующий шаг v1.2: декларировать `knowledge_refs:` на уровне SOP-шага, чтобы Role был полностью переносимым (без знания о knowledge paths в FM). Инвазивно (требует переписать Roles + расширить planner), отложено.
- **Capability-only SOP шаги (option 3).** Пока planner warning'ает; в v1.2 — резолв capability → role через `knowledge/capabilities.md` automatically, с platform preference. На v1.1 каталог capabilities полностью decoupled от providers (D-CP), что уже подготовило почву.
- **SOP `forensic-audit.yaml` фазы (Control Objects, Signal Inventory и т.д.) вынести в knowledge.** Сейчас 8 фаз описаны как `name:`+`note:` в самом SOP; их содержательное описание (что именно искать, какие hypotheses проверять) может жить в `knowledge/forensic-audit-protocol.md` и подгружаться шагом. Отложено: на v1.1 `note:` поля достаточно для executor'a; если SOP разрастётся — вынесем.

### Execution layer (Major — v2.0)
- **executor** (retry/scheduler/parallel/resume/checkpoint). Явно отклонено в D-3/D-P. Если реальная потребность возникнет после dogfooding — это уже v2.0 с самостоятельной архитектурой.

## Appendix A: Raw input preservation

> The original file `docs/specs/drafts/agentic.md` (2168 lines, 4 raw agent prompts + architectural critique) is preserved until Phase G1. After deletion available via git history (commit SHA после Phase G2). Verbatim copy NOT inserted into spec to avoid bloat файла до 2200+ строк; план сохранения пути указан.

## Result
<!-- Filled after implementation -->