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
| `docs/audits/2026-07-07-documentation-transformation-kordon.md` | **Value Proof** — кейс-стади трансформации Kordon/MegaDelta: 141 файл хаоса → 40 canonical за 30 мин / 1 промпт. |
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

## Почему Naprolom-Docs?

Потому что документация без системы **умирает за 2 недели**: нет lifecycle → никто не проверяет актуальность → автор не знает, куда писать обновление, и создаёт новый ad-hoc файл → ответственность размывается → проект превращается в цифровую свалку. AI-агенты в такой свалке находят по 2–3 версии одного документа и галлюцинируют.

Naprolom-Docs превращает документацию в **инфраструктуру**, а не текст:

- **Canonical Schema v1** — каждый `.md` в `docs/` самодокументирован (6 mandatory-полей). Никаких legacy-полей.
- **Lifecycle из path** — статус документа определяется папкой (`specs/approved/` → approved), а не изменчивым полем. AI отличает актуальное от устаревшего программно, не читая содержимое.
- **5-слойная архитектура** — Entry → Architecture → Decisions (ADR) → Specs → Operations. Навигация по структуре, а не по grep.
- **CI guard** — ни один файл без canonical frontmatter не попадёт в репозиторий.

Доказательство на практике — кейс Kordon/MegaDelta: **141 хаотичный файл → 40 canonical за 30 минут и 1 промпт**. Онбординг сократился с 2–5 дней до 5 минут, объём LLM-контекста — на 73%, стоимость промпта — на 80% (`docs/audits/2026-07-07-documentation-transformation-kordon.md`).

---

## Питч (для рабочего чата)

> Внедрили методологию Naprolom-Docs: документация теперь часть инфраструктуры, а не свалка `.md`-файлов. На проекте Kordon/MegaDelta за 30 минут и один промпт сожгли 141 хаотичный файл до 40 canonical (5 слоёв, Schema v1, lifecycle из пути). Итог: онбординг инженера — 5 минут вместо дней, контекст LLM легче на 73%, галлюцинации AI — минус 90%. Это не шаблон README, это Documentation-as-Code с CI-контролем.

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
- **2026-07-07** — добавлен **Value Proof** кейс (`docs/audits/2026-07-07-documentation-transformation-kordon.md`, тип `audit`): трансформация Kordon/MegaDelta 141→40 файлов. В README добавлены разделы «Почему Naprolom-Docs?» и питч для чата; в отчёт встроен блок про автоматизацию (оригинал промпта). Неканоничный `docs/reports/` удалён.
