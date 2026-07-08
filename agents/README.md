---
schema: 1
id: agents-readme
type: guide
kind: index
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter]
touches: []
docs: [../README.md, ../INSTALL.md, ../playbook/playbook-v2.md]
refs: []
depends_on: []
tags: [agents, roles, index]
priority: P1
---

# agents/ — Репозитарий ролей AI-агентов

Runtime v1.0 содержит минимальный набор ролей, общих для большинства проектов. Каждая роль — это готовый промпт-конфигурация для конкретной платформы (Claude Code, opencode), которую потребительский проект подключает и сразу использует без необходимости писать с нуля.

## Роли в Runtime v1.0

| Роль | Назначение | Платформы |
|------|-----------|-----------|
| **Architecture Reviewer** | Валидирует архитектурные изменения: ADR правильной формы, обновления `docs/architecture/`, инварианты. | claude-code, opencode |
| **Documentation Reviewer** | Проверяет PR'ы на соответствие Canonical Schema v1: валидный frontmatter, path-status match, entity_refs, отсутствие legacy-полей. | claude-code, opencode |

## Почему только две роли сейчас

Architecture + Documentation Reviewer — это **универсальный минимум**, который работает в любом проекте независимо от стека. Дальнейшие роли (Canonical Transformer, Spec Reviewer, Auditor, Reviewer) — Tier 2, добавляются после dogfooding на первом проекте по реальным потребностям команды.

## Layout

```
agents/
├── README.md          ← этот файл
├── claude-code/       ← конфиги для Claude Code
│   ├── architecture-reviewer.md
│   └── documentation-reviewer.md
└── opencode/          ← конфиги для opencode
    ├── architecture-reviewer.md
    └── documentation-reviewer.md
```

## Подключение

Файлы ролей — это готовые дескрипторы агента. Скопируйте их в configuration directory вашей платформы:

- **Claude Code**: `.claude/agents/<role>.md` (создаётся в consumer-репо).
- **opencode**: `.opencode/agents/<role>.md` (создаётся в consumer-репо).

Или — alternative для минимального случая — используйте `CLAUDE.md` snippet из `INSTALL.md`, который не требует отдельных конфигов ролей, а явно указывает агенту следовать `playbook/playbook-v2.md` как протоколу review.

## Использование через SOP

Роли в этом каталоге вызываются **по имени** из декларативных SOP в `../sops/*.yaml`. Каждый YAML ссылается на роль через `role: <name>` (например, `role: architecture-reviewer`). Планировщик `../sops/planner.mjs` печатает DAG выполнения с указанием, какую роль вызывать на каждом шаге и в каком порядке (с параллельными группами). Запуск роли — через slash command вашей платформы (`/architecture-reviewer` для Claude Code, `@architecture-reviewer` для opencode).

Custom-роли (`role: human` в SOP) — это ручные шаги. executor = человек, не агент. Не нужно писать конфиг для `human` — это явно marker того, что шаг ручной.

## Расширение

Runtime v1.0 не поддерживает кастомные роли в submodule. Если нужны дополнительные роли под ваш контекст (например, `tf-reviewer.md` для Terraform-heavy проектов) — создайте их в вашем consumer-репо в `.claude/agents/` или `.opencode/agents/`. Когда роль станет достаточно универсальной, чтобы быть полезной другим проектам в экосистеме — предложите её в `naprolom-docs` через PR (см. INSTALL → «Обновление Runtime»).
