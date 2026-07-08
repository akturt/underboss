---
schema: 1
id: knowledge-architecture-principles
type: guide
kind: index
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer]
tags: [knowledge, architecture, principles, review]
priority: P1
---

# Architecture Principles

14 принципов архитектурного анализа + 3 мета-паттерна. Используются `architecture-reviewer` при ревью.

## Basic Principles (7)

1. **Single Source of Truth** — каждый архитектурный факт имеет ровно одно место хранения. Дублирование = drift risk.
2. **Explicit Dependencies** — зависимости между модулями декларируются явно (imports, APIs, events), неявно через shared state.
3. **Invariants Over Implementation** — критические инварианты системы фиксируются в `docs/architecture/README.md` и проверяются при каждом review. Реализация может меняться; инварианты — нет.
4. **ADR Before Code** — архитектурное решение оформляется как ADR (`docs/adr/`) до merge кода, реализующего это решение.
5. **Path-Status Contract** — lifecycle-позиция документа (draft/review/approved/implemented) определяется директорией + `status:` FM. Несоответствие = ошибка.
6. **Immutability After Acceptance** — тело ADR с `status: accepted` неизменяемо. Только FM-транзиции (`status:` переход). Нарушение = REJECT.
7. **Entity Refs Integrity** — `entity_refs` в spec/audit указывают на реально существующие `id:` в `docs/architecture/`. Broken ref = warning.

## Operational Principles (7)

8. **Schema v1 Compliance** — каждый `.md` в `docs/` обязан иметь Schema v1 frontmatter с 6 mandatory fields. CI проверяет это автоматически.
9. **Template-First Creation** — новые документы создаются через `cp engine/templates/<type>.md`, не «из головы». Шаблон гарантирует canonical structure.
10. **Append-Only Audits** — тело audit с `status: completed` неизменяемо. Новый аудит того же объекта = новый файл с новой датой.
11. **Separation of Concerns** — Role = идентичность (кто я), Knowledge = знания (что знаю), SOP = процесс (когда применяю), Capability = навык (что умею). Не смешивать.
12. **DRY Knowledge** — общие знания живут в `knowledge/`, не дублируются inline в Roles. Roles ссылаются по short-id.
13. **Artifact Contracts** — DAG соединяется через артефакты (`consumes:`/`produces:`), не через неявный depends_on. Data flow ≠ control flow.
14. **Gate: Manual** — human-шаги в SOP помечаются `gate: manual`, не `role: human`. Human — не роль Runtime.

## Meta-Patterns (3)

### Stratification by Time
Архитектурные решения имеют разные горизонты изменения: topology (months), data model (weeks), implementation (days). Review должен учитывать горизонт изменения при оценке impact.

### Semantic Density
Критические инварианты должны быть «плотными» — одно предложение, однозначная интерпретация, проверяемый факт. Размытые инварианты = невалидные инварианты.

### Asymptotic Complexity of Changes
Каждое архитектурное решение увеличивает когнитивную сложность системы. При review оценивай: ослабляет ли изменение общую архитектуру или укрепляет? Чем больше компонентов затронуто — тем строже review.
