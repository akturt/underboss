---
schema: 1
id: knowledge-index
type: guide
kind: index
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer]
tags: [knowledge, index, reference]
priority: P1
---

# Knowledge Layer

Знания, которыми пользуются Roles. Загружаются в контекст по **short-id** из Role FM:

```yaml
knowledge: [architecture-principles, report-formats]
```

Runtime резолвит путь: `knowledge/<short-id>.md`. Позволяет менять структуру `knowledge/` без переписывания Roles.

## Contained

| Short-id | File | Описание |
|----------|------|----------|
| `architecture-principles` | `architecture-principles.md` | 14 принципов + 3 мета-паттерна анализа |
| `evidence-model` | `evidence-model.md` | Trust Hierarchy (7 уровней) + 4 evidence-класса |
| `audit-principles` | `audit-principles.md` | 5-stage validation + verdict system + confidence model |
| `report-formats` | `report-formats.md` | Выходные форматы 4 ревьюеров |
| `capabilities` | `capabilities.md` | Capability Catalog — контракт capabilities |

## Как используют Roles

- **architecture-reviewer** → `architecture-principles`, `report-formats`
- **documentation-reviewer** → `report-formats`
- **reality-auditor** → `evidence-model`, `report-formats`
- **adversary-checker** → `audit-principles`, `report-formats`

## Правила

1. Знания **не выполняются** — загружаются в контекст как справочный материал.
2. Roles **не дублируют** содержимое knowledge inline — ссылаются по short-id.
3. SOP-шаги **не читают** knowledge напрямую — это ответственность Role при исполнении шага.
4. Новые knowledge-файлы добавляются через PR с `type: guide, kind: index`.
