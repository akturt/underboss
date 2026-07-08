# sops/ — Standard Operating Procedures

> Декларативные описания процессов разработки. Не исполнение — описание. Оркестратором (временами) выступает человек или простой planner-скрипт.

## Что это

SOP — YAML-описание типового процесса разработки (New Feature, Bugfix, Release...) в виде:
1. **Input** — какие документы/артефакты должны существовать до старта.
2. **Steps** — последовательность шагов, каждому назначена роль из `agents/` либо `human` (ручной шаг).
3. **Output** — артефакты, которые должны появиться по завершении.

SOP не запускает ничего сам по себе. Это **источник правды для процесса** — план, по которому разработчик или AI-агент ведёт задачу.

## Зачем

Без SOP порядок «Кто и когда запускает Architecture Reviewer / Documentation Reviewer / etc» держится в голове у одного человека и нигде не зафиксирован. Через месяц — разночтения. Через три — каждый делает по-своему. SOP таблетки:
-описание в репозитории → diff'ается,.review'ится, версионности
- ссылки на роли по имени (а не на файлы в файловой системе) → тянутся из `agents/{platform}/`
- шаги могут идти параллельно — DAG описывается через `depends_on`
- запуск: пока руками, позже — простыми wrapper'ми или CI шагами

## Layout

```
sops/
├── README.md              ← этот файл
├── planner.mjs            ← по input типу печатает DAG выполнения (parallel groups)
├── new-feature.yaml
├── bugfix.yaml
├── new-service.yaml
├── architecture-change.yaml
├── audit.yaml
├── release.yaml
└── incident.yaml
```

## Использование

### Ручной запуск (пока основной способ)

Открываешь нужный YAML, читаешь `steps`, поочерёдно вызываешь роли (через slash command в Claude Code: `/agents architecture-reviewer`, или через `@architecture-reviewer` в opencode). Ручные шаги (`role: human`) делаешь сам.

### Простой planner

```bash
node sops/planner.mjs new-feature
# печатает:
#   Input required: docs/specs/drafts/YYYY-MM-DD-<slug>.md
#   Group 1 (parallel):
#     [1] Architecture Review       → role: architecture-reviewer (claude-code|opencode)
#     [2] Documentation Review      → role: documentation-reviewer (claude-code|opencode)
#   Group 2 (sequential):
#     [3] Implementation            → role: human
#   ...
#   Output: implemented spec, accepted ADR, completed audit
```

### Список доступных SOP

```bash
node sops/planner.mjs --list
```

## Формат YAML

```yaml
name: new-feature
description: <one-line>
triggers:        # optional: когда применять
  - <условие>
input:
  required:
    - type: spec
      path_pattern: docs/specs/drafts/YYYY-MM-DD-<slug>.md
      status: draft
output:
  - type: spec
    status: implemented
  - type: adr
    status: accepted
steps:
  - id: 1
    name: <human-readable step name>
    role: <name-in-agents-without-extension> | human
    platform: any | claude-code | opencode
    produces: <one-line artifact description>
    depends_on: [<step-id>, ...]   # empty → ready from start; non-empty → after listed
```

`platform: any` — роль существует в обоих платформах; планировщик подскажет пользователю вызвать в текущей платформе.
`platform: claude-code` — только в Claude Code.
`platform: opencode` — только в opencode.

## Расширение

Добавить новый SOP — создать `sops/<name>.yaml`. Не нужно трогать planner; он подхватит автоматически. Удалить — `rm sops/<name>.yaml`. Никакой регистр.

Добавить роль в существующий SOP — отредактировать `steps` в YAML. Planner пересчитает DAG.

## Что НЕ входит (намеренно)

- **Нет runtime state.** SOP не хранит прогресс между запусками. Кто запустил — тот и трекает в задаче/PR.
- **Нет middleware execution engine.** Не Temporal, не Airflow, не LangGraph. Просто YAML + planner, который печатает план.
- **Нет web UI.** CLI-only.
- **Нет автоматического запуска агентов.** Planner печатает план, запуск — за человеком или CI step. (Future Tier 2 — slash-command bindings).
- **Нет версионности процессов между проектами.** SOP лежат в submodule `naprolom-docs`; consumer использует те, что приезжают с обновлением submodule. Если проекту нужен кастомный SOP — создаёт локально в `.context/sops/` (вне submodule).