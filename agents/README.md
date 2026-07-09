---
schema: 1
id: agents-readme
type: guide
kind: index
status: active
date: 2026-07-08
updated: 2026-07-09
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer]
touches: []
docs: [../README.md, ../INSTALL.md, ../playbook/playbook-v2.md]
refs: []
depends_on: []
tags: [agents, roles, index, v1.5, capabilities, knowledge]
priority: P1
---

# agents/ — Репозитарий ролей AI-агентов

Runtime v1.5 содержит 4 роли, каждая — готовый промпт-конфигурация для конкретной платформы (Claude Code, opencode).

## Roles

| Role | Purpose | Capabilities | Platforms |
|------|---------|--------------|-----------|
| **Architecture Reviewer** | Reviews architectural changes against real project state | `review-spec`, `review-adr`, `review-domain-model`, `review-security-model` | claude-code, opencode |
| **Documentation Reviewer** | Validates Schema v1 compliance, entity_refs, path-status contract | `validate-frontmatter`, `validate-entity-refs` | claude-code, opencode |
| **Reality Auditor** | Reconstructs current project state from code, config, docs (read-only) | `state-reconstruction`, `drift-analysis`, `architecture-extraction`, `attribution-analysis` | claude-code, opencode |
| **Adversary Checker** | Validates architectural claims against evidence, assigns verdicts + confidence | `claim-validation`, `assumption-analysis` | claude-code, opencode |

## Capabilities

Each role declares `capabilities:` in frontmatter (unidirectional Role→Capability). The **Capability Catalog** (`knowledge/capabilities.md`) contains the full contract per capability (description, consumes, produces) — without `provided by:` (D-CP).

| Capability | Consumes | Produces |
|------------|----------|----------|
| `review-spec` | spec, reality-report | architecture-findings |
| `review-adr` | adr | architecture-findings |
| `review-domain-model` | domain-model, reality-report | architecture-findings |
| `review-security-model` | security-model, reality-report | architecture-findings |
| `validate-frontmatter` | changed-files | documentation-report |
| `validate-entity-refs` | changed-files | documentation-report |
| `state-reconstruction` | subject-document | reality-report |
| `drift-analysis` | reality-report | reality-report |
| `architecture-extraction` | reality-report | reality-report |
| `attribution-analysis` | signal-inventory, control-objects-matrix | attribution-analysis |
| `claim-validation` | architecture-findings | validated-findings |
| `assumption-analysis` | architecture-findings | validated-findings |

Full contracts: `knowledge/capabilities.md`

## Knowledge Refs

Each role declares `knowledge:` in frontmatter as **short-id list** (D-KR):

```yaml
knowledge: [architecture-principles, report-formats]
```

Runtime resolves `knowledge/<short-id>.md`. Roles never hardcode knowledge paths — they reference by short-id.

| Role | Knowledge refs |
|------|---------------|
| architecture-reviewer | `architecture-principles`, `report-formats` |
| documentation-reviewer | `report-formats` |
| reality-auditor | `evidence-model`, `report-formats` |
| adversary-checker | `audit-principles`, `report-formats` |

## Layout

```
agents/
├── README.md          ← this file
├── claude-code/       ← Claude Code configs
│   ├── architecture-reviewer.md
│   ├── documentation-reviewer.md
│   ├── reality-auditor.md
│   └── adversary-checker.md
└── opencode/          ← opencode configs
    ├── architecture-reviewer.md
    ├── documentation-reviewer.md
    ├── reality-auditor.md
    └── adversary-checker.md
```

## Подключение

Файлы ролей — готовые дескрипторы агента. Скопируйте их в configuration directory вашей платформы:

- **Claude Code**: `.claude/agents/<role>.md`
- **opencode**: `.opencode/agents/<role>.md`

Или используйте `CLAUDE.md` snippet из `INSTALL.md`.

## Использование через SOP

Роли вызываются **по имени** из декларативных SOP (`../sops/*.yaml`). Каждый YAML ссылается на роль через `role: <name>` или `capability: <name>` + `role: <name>`. Planner печатает DAG с указанием ролей и артефактов.

Human-шаги помечаются `gate: manual` (D-HG). Существующие SOP v1.0 с `role: human` backward-compatible — planner treat как alias для `gate: manual`.

## Расширение

Для кастомных ролей (например, `tf-reviewer.md`) — создайте в consumer-репо в `.claude/agents/` или `.opencode/agents/`. Когда роль станет универсальной — предложите в `naprolom-docs` через PR.
