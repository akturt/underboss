---
schema: 1
id: readme
type: guide
kind: index
status: active
date: 2026-07-07
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter]
touches: [docs]
docs: [docs/guides/legacy-migration.md, 2026-07-07-documentation-system-playbook-v2.md]
refs: []
depends_on: [documentation-system-playbook-v2]
tags: [documentation, index, start-here]
priority: P0
---

# naprolom-docs

Документационная система проекта **naprolom**, построенная на Canonical Schema v1 (Greenfield Playbook v2).

> **START HERE** — если вы агент или новый участник, начните с `.context/agent-entry.md`, затем `docs/architecture/README.md`.

---

## Что в этом репозитории

| Документ | Назначение |
|----------|-----------|
| `2026-07-07-documentation-system-playbook-v2.md` | **Целевая модель** Documentation System v2 — Schema v1, bootstrap, workflow, CI, readiness. Greenfield-first. |
| `docs/guides/legacy-migration.md` | **Adoption Guide** — как внедрить систему в существующий (brownfield) репозиторий: аудит legacy, migration script, warn-only → strict rollout. |
| `README.md` | Этот файл — индекс и точка входа. |

---

## Два режима внедрения

```
                 Documentation System v2 (целевая модель)
                          ↑                  ↑
        новый репо → Playbook (greenfield)   существующий репо → Adoption Guide (brownfield)
                          │                  │
                   Strict CI с 1-го PR   Warn-only → Strict CI
```

- **Greenfield** — новый проект без `docs/`. Bootstrap создаёт структуру сразу в canonical-виде. CI strict с первого PR.
- **Brownfield** — существующий репо с `.md` файлами. Миграция frontmatter + warn-only период + cleanup + switch to strict.

---

## Структура документации

```
docs/
  guides/
    legacy-migration.md     # Adoption Guide (brownfield)
  architecture/             # живая архитектура (topology, data model, invariants)
  adr/                      # Architecture Decision Records
  specs/                    # drafts / review / approved / implemented / superseded
  audits/                   # аудиты (append-only body)
  backlog/                  # единый бэклог
  prompts/                  # AI-контекстные промпты
  api/                      # API specifications
.context/                   # метаданные проекта для AI-агентов (project.yml, boundaries.yml, ...)
.claude/rules/              # правила для AI-агента
.github/workflows/          # docs-validate.yml (CI Schema v1 guard)
```

Полное описание схемы, типов, статусов и lifecycle — в Playbook v2, §«Canonical Schema v1».

---

## Canonical Schema v1 (кратко)

Каждый `.md` в `docs/` обязан иметь frontmatter:

```yaml
---
schema: 1            # mandatory
id: <kebab-case>     # mandatory, stable
type: <enum>         # mandatory (spec|adr|audit|runbook|guide|api|architecture|backlog|prompt)
status: <per-type>   # mandatory
date: YYYY-MM-DD     # mandatory
owners: []           # mandatory
---
```

Обязательны 6 полей: `schema`, `id`, `type`, `status`, `date`, `owners`.
Legacy поля запрещены: `author`, `title`, `created`, `lifecycle`, `referenced_by`, `supersedes_adr`, `excludes-from-scope`.
`lifecycle` для spec/api **вычисляется из пути**, не хранится в frontmatter.

---

## Быстрый старт

```bash
# Greenfield: создать структуру с нуля
./docs-bootstrap.sh <project-name>

# Brownfield: см. docs/guides/legacy-migration.md
```

---

## Статус репозитория

| Этап | Состояние |
|------|-----------|
| Playbook v2 (greenfield модель) | ✅ implemented |
| Adoption Guide (brownfield) | ✅ добавлен (`docs/guides/legacy-migration.md`) |
| `.context/`, templates, CI | ⏳ bootstrap ещё не запускался в этом репо |
| Architecture layer (ADR/specs/audits) | ⏳ предстоит наполнить |

---

## Чейнджлог (this repo)

- **2026-07-07** — initial commit: README + Playbook v2 (greenfield).
- **2026-07-07** — выделен отдельный **Adoption Guide** (`docs/guides/legacy-migration.md`) из временного `todos.md`; playbook очищен от категоричного «никакой migration», добавлена ссылка на guide. `todos.md` ликвидирован.
