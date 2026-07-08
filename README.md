---
schema: 1
id: readme-runtime
type: guide
kind: index
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter]
touches: []
docs: [INSTALL.md, playbook/playbook-v2.md, playbook/migrate-legacy.md]
refs: []
depends_on: []
tags: [runtime, index, landing]
priority: P0
---

# naprolom-docs — Documentation System Runtime

**Превращает документацию в инфраструктуру**, а не в свалку `.md`-файлов. Каноническая Schema v1, lifecycle из path, 5-слойная архитектура, CI guard. Подключается как Git Submodule — один runtime на всю экосистему.

> **Доказательство:** проект Kordon/MegaDelta — 141 хаотичный файл → 40 canonical за 30 минут и один промпт. Онбординг с 2–5 дней до 5 минут, контекст LLM легче на 73%, стоимость промпта — на 80%. См. `docs/audits/`.

> **Установить на свой проект:** скопируй промпт из [`bootstrap/DEPLOY-PROMPT.md`](bootstrap/DEPLOY-PROMPT.md) и дай AI-агенту (opencode, Claude Code, Cursor). Агент автоматически определит тип проекта, подключит submodule и развернёт систему.

---

## Что это

`naprolom-docs` — это **Documentation System Runtime**: не набор промптов и не шаблон README. Это версионированный движок, который любой ваш проект подключает как Git Submodule и получает:

- **Canonical Schema v1** — единый frontmatter-формат для всех `.md` в `docs/` (6 обязательных полей, ноль legacy-полей).
- **Lifecycle из path** — статус spec/api определяется директорией (`drafts/` → `draft`, `approved/` → `approved`), а не editable-полем. AI отличает актуальное от устаревшего программно.
- **5-слойную архитектуру** — Entry (`.context/`) → Architecture → ADR → Spec → Operations. Навигация по структуре, а не по `grep`.
- **CI guard** — ни один `.md` без canonical frontmatter не попадёт в репозиторий.
- **Runnable migration** — для brownfield-репозиториев: `engine/scripts/migrate-legacy.mjs` переводит legacy FM в Schema v1 с `TODO_ENTITY_REF` маркерами для manual review.
- **SOPs** — декларативное описание типовых процессов разработки в `sops/*.yaml` (New Feature, Bugfix, Release, Incident и др.). Планировщик `sops/planner.mjs` печатает DAG выполнения по типу входной сущности. Роли упоминаются по имени (из `agents/`) или `human`.

---

## Как подключить

> **v1.1 (D-BR):** Runtime подключается **внутрь `docs/`**, а не в `.context/runtime/`. В корне consumer-репо остаётся только `docs/` — никаких служебных каталогов `agents/`, `knowledge/`, `sops/`, `engine/`, `bootstrap/`. См. §Two-repo model в `docs/specs/approved/2026-07-08-agentic-layer.md`.

```bash
# 1. Подключить submodule ВНУТРЬ docs/
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master

# 2. Запустить bootstrap (создаст docs/ skeleton, .context/, CLAUDE.md snippet, CI workflow)
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh

# 3. Заполнить .context/project.yml и .context/boundaries.yml под ваш проект

# 4. Создать первый документ из template
cp docs/.runtime/naprolom-docs/engine/templates/adr.md docs/adr/001-orchestrator-choice.md
```

**Полная инструкция с troubleshooting и edge-cases** → [`INSTALL.md`](INSTALL.md).

**Brownfield?** Если в репо уже есть `docs/` с `.md` — следуйте агент-промпту [`playbook/migrate-legacy.md`](playbook/migrate-legacy.md), а не `bootstrap.sh`.

---

## Что входит (Runtime layout)

```
naprolom-docs/                                  ← репо-ПРОДУКТ (layout продукта; D-BR — в consumer'е всё локализовано под docs/)
├── README.md                              ← этот файл (landing page)
├── INSTALL.md                             ← consumer integration (submodule + bootstrap)
├── playbook/
│   ├── playbook-v2.md                      ← целевая Greenfield-модель (Schema v1, lifecycle, CI)
│   └── migrate-legacy.md                   ← brownfield агент-промпт (7 шагов с checkpoint'ами)
├── engine/
│   ├── templates/                          ← canonical шаблоны Schema v1 (NEVER copy into project)
│   │   ├── architecture.md  adr.md  spec.md
│   │   └── audit.md  runbook.md  backlog.md
│   ├── schemas/
│   │   └── frontmatter.schema.json         ← JSON Schema (base + per-type extensions + forbidden legacy)
│   ├── validators/
│   │   └── validate-frontmatter.sh         ← frontmatter-only (awk), WARN_ONLY switch, path-status match, ROOT= path override
│   └── scripts/
│       └── migrate-legacy.mjs              ← runnable brownfield миграция (без внешних зависимостей)
├── bootstrap/
│   ├── bootstrap.sh                        ← POSIX, минимальный, идемпотентный (D-BR: advisory path-check)
│   ├── bootstrap.ps1                       ← Windows / PowerShell
│   └── DEPLOY-PROMPT.md                    ← промпт для AI-агента: автоустановка на любой проект
├── knowledge/                              ← v1.1 NEW: общий knowledge-слой (роли подключают по short-id)
│   ├── architecture-principles.md
│   ├── evidence-model.md
│   ├── audit-principles.md
│   ├── report-formats.md
│   └── capabilities.md                     ← capability catalog (без providers, D-CP)
├── agents/                                 ← роли AI-агентов для claude-code и opencode (4 roles, slim)
│   └── README.md                           ← overview capabilities, указатель на knowledge/capabilities.md
├── sops/                                   ← Standard Operating Procedures (YAML) + planner.mjs
│   ├── planner.mjs                         ← печатает DAG (DAG-printer, не executor)
│   └── *.yaml                              ← new-feature / bugfix / new-service / architecture-change / audit / release / incident / architecture-review / forensic-audit
├── docs/                                   ← dogfood: собственная документация Runtime
│   ├── adr/                                ← dogfood ADRs (001-agentic-layer-separation)
│   ├── audits/                             ← value-proof кейсы (напр. Kordon/MegaDelta)
│   └── specs/approved/                     ← спеки Runtime v1.x
└── .github/workflows/docs-validate.yml     ← CI guard + knowledge/ validation step
```

> **Внимание:** этот layout описывает репозиторий-продукт `naprolom-docs`. В consumer-репозитории (после `bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh`) вы увидите только `docs/` в корне плюс `docs/.runtime/naprolom-docs/...` где лежит submodule со всем содержимым Runtime. См. §«Two-repo model» в INSTALL.md.

---

## Quick Start

### Greenfield (новый репо)

```bash
git clone your-new-repo && cd your-new-repo
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
# → docs/, .context/, CLAUDE.md, docs-validate.yml созданы
# → заполните .context/project.yml, создайте первый ADR из template
git add -A && git commit -m "chore: bootstrap documentation runtime"
```

### Brownfield (репо с существующей документацией)

```bash
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master

# Запустить миграцию (dry-run сначала!)
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --dry-run
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --owner your-team
# → covered TODO_ENTITY_REF markers go to manual review

# Включить warn-only CI на 3–7 дней → cleanup forgotten docs → strict
```

См. [`playbook/migrate-legacy.md`](playbook/migrate-legacy.md) — 7 шагов с checkpoint'ами для агента.

---

## Обновление Runtime

```bash
# Вариант A — вручную (пять секунд, рекомендуется)
git submodule update --remote --merge
git add docs/.runtime/naprolom-docs
git commit -m "chore: update Documentation System Runtime"
```

```yaml
# Вариант B — Dependabot gitsubmodule (авто-PR)
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "gitsubmodule"
    directory: "/"
    schedule:
      interval: weekly
```

Подробно: [`INSTALL.md` → Обновление Runtime](INSTALL.md#обновление-runtime).

---

## Playbook

Целевая модель (что означает «Documentation System внедрена»):
- **[`playbook/playbook-v2.md`](playbook/playbook-v2.md)** — Greenfield-модель: Canonical Schema v1, 5-слойная архитектура, entity_refs workflow, lifecycle из path, CI guard, метрики готовности.
- **[`playbook/migrate-legacy.md`](playbook/migrate-legacy.md)** — Brownfield агент-промпт: 7 шагов, runnable migration script, warn-only → strict rollout.
- **[`INSTALL.md`](INSTALL.md)** — Подключение submodule, bootstrap, `.gitmodules`, CLAUDE.md snippet, troubleshooting.

---

## SOP (Standard Operating Procedures)

`sops/` — декларативные описания типовых процессов разработки в виде YAML. Не исполнение — описание:
- `new-feature.yaml`, `bugfix.yaml`, `new-service.yaml`, `architecture-change.yaml`, `audit.yaml`, `release.yaml`, `incident.yaml`.
- Каждый — DAG шагов с референсами на роли из `agents/{platform}/` либо `human`.
- `sops/planner.mjs` — по input типу печатает последовательность шагов с параллельными группами.

```bash
# Список доступных SOP
node sops/planner.mjs

# План выполнения для new-feature (показывает роль + параллельность)
node sops/planner.mjs new-feature --platform claude-code

# Только роли AI-агентов (без human-шагов) — чтобы понять, что запускать
node sops/planner.mjs new-feature --hide-human
```

Пока запуск — ручной через slash commands (`/architecture-reviewer`, `/documentation-reviewer` в Claude Code; `@architecture-reviewer`, `@documentation-reviewer` в opencode). SOP работает как чек-лист «что и в каком порядке вызвать на конкретный тип работы». Future Tier 2 — slash-command bindings, CI step интеграция.

---

## Почему Git Submodule, а не npm/pip/git-release

- **Не требует Node.js/Python/Go toolchain** в проекте — работает для FastAPI, Go, Rust, Terraform, Ansible.
- **Фиксируется commit SHA** — воспроизводимость, тривиальный откат.
- **Обновляется по вашему решению** — нет автоматического registry pull, который сломает проект.
- **Не засоряет основной репо** — Runtime живёт в `docs/.runtime/`, а корень consumer'а содержит только `docs/` (v1.1, D-BR). Раньше v1.0 использовал `.context/runtime/`; в v1.1 это deprecated в пользу локализации внутрь `docs/`.
- **Соответствует вашему стеку** GitOps/IaC — единый источник истины, обновления через PR-review.

Альтернативы (npm package, GitHub Releases + curl) рассмотрены и отклонены: завязка на toolchain либо нарушает portability, либо теряет воспроизводимость.

---

## Стратегия обновлений

- **`naprolom-docs`** — единственный источник истины, развивается независимо в этом репозитории.
- **Каждый consumer** подключает его как Git Submodule, закреплённый за `branch = master` в `.gitmodules`.
- **Обновления распространяются только через PR:** новый SHA сабмодуля приезжает в dependent-репо (вручную или через Dependabot) → review → merge. Никаких direct commits в master consumer-проекта.
- **Цель:** единая Documentation System во всей экосистеме без дрейфа версий.

---

## Статус репозитория

| Этап | Состояние |
|------|-----------|
| Runtime layout (bootstrap/, engine/templates/, engine/schemas/, engine/validators/, engine/scripts/) | ✅ v1.0 |
| Playbook v2 (greenfield-модель) | ✅ реализован |
| Migration Prompt (brownfield агент-промпт) | ✅ реализован |
| INSTALL.md (consumer integration) | ✅ реализован |
| Bootstrap (.sh + .ps1, идемпотентный) | ✅ реализован, протестирован на POSIX и Windows |
| agents/ (claude-code, opencode: reviewer, architect) | ⏳ Этап 2 (this session) |
| examples/{fastapi,golang,terraform,ansible}/ | ⛔ Tier 2 — после dogfooding |
| validate-links.sh, normalize-frontmatter.mjs | ⛔ Tier 2 |
| repository_dispatch, Dependabot template | ⛔ Tier 2 |
| prompts/ каталог | ⛔ заменено на `agents/` |
| **Dogfooding на реальном проекте** | ⏳ Этап 3 — следующий шаг |

> Runtime v1.0 **freeze** планируется после dogfooding на первом стратегическом проекте Naprolom. До этого момента новые функции не добавляются — только bugfixes на основе реального использования.

---

## Чейнджлог

- **2026-07-08** — **v1.1 — Agentic Layer Separation**. Пять сущностей первого класса: **Knowledge** (`knowledge/` — 4 файла принципов + capabilities.md), **Role** (slim-roles в `agents/`, +2 новые: `reality-auditor`, `adversary-checker`), **Capability** (что умеет;单向 Role→Capability, каталог в `knowledge/capabilities.md` без `provided by:`), **SOP** (декларативный DAG с artifact-contract'ами; gate:manual вместо role:human), **Artifact** (что путешествует между шагами — reality-report, architecture-findings, validated-findings, forensic-report). Два новых SOP: `architecture-review.yaml` (sequential Reality→Arch→Doc→Adversary-optional→human) и `forensic-audit.yaml` (8-step pipeline, замещает прежний forensic-orchestrator). `sops/planner.mjs` остаётся DAG-printer (НЕ executor), расширен чтением `capability:`/`consumes:`/`produces:`/`gate:`. **D-BR: bootstrap разворачивает Runtime в `docs/.runtime/naprolom-docs/`, НЕ в `.context/runtime/`** — корень consumer'а содержит только `docs/`. См. `docs/specs/approved/2026-07-08-agentic-layer.md` и `docs/adr/001-agentic-layer-separation.md` (dogfood).
- **2026-07-08** — **SOP layer (Tier 1.5)**: введён четвёртый слой `sops/` — декларативные YAML-описания типовых процессов разработки. 7 протоколов: `new-feature`, `bugfix`, `new-service`, `architecture-change`, `audit`, `release`, `incident`. `sops/planner.mjs` — простой node-скрипт, который по input типу печатает DAG выполнения (параллельные группы из `depends_on`). Роли в SOP ссылаются на `agents/{claude-code,opencode}/` по имени (`architecture-reviewer`, `documentation-reviewer`) или `human` для ручных шагов. Никакого runtime/БД/Temporal/LangGraph — просто YAML + planner. Запуск пока ручной через slash commands; slash-command bindings — Tier 2 после dogfooding. README дополнен секцией «SOP» и упомянут в четырёхслойной модели: Runtime → Documentation Engine → AI Layer → SOP Layer.
- **2026-07-08** — **Runtime engine/ layering**: `templates/`, `schemas/`, `validators/`, `scripts/` сгруппированы под `engine/` (Documentation Engine слой). `bootstrap/` поднят рядом на корне (Runtime-уровень). `agents/` остался как самостоятельный AI-слой. Все consumer-facing пути в INSTALL, README, playbook, migrate-legacy, bootstrap.sh, bootstrap.ps1, workflow и агентах обновлены на `engine/...` префикс. Устранён визуальный дрейф «свалка директорий в корне»; корень теперь читается как трёхслойная модель: Runtime → Documentation Engine → AI Layer.
- **2026-07-08** — **Runtime refactor v1.0**: репозиторий превращён из набора промптов в Documentation System Runtime. Структура `playbook/`, `bootstrap/`, `templates/`, `schemas/`, `validators/`, `scripts/`, `agents/`, `docs/`. Создан `INSTALL.md` как consumer-integration document. Playbook вынесен из корня, §Bootstrap и §Result переписаны под актуальные пути. CI guard теперь вызывает `validators/validate-frontmatter.sh` (единый source of truth). Создан runnable `scripts/migrate-legacy.mjs` для brownfield-миграции. Добавлены `bootstrap/bootstrap.sh` и `bootstrap.ps1` (идемпотентные, минимальные). Adoption Guide переформатирован как агент-промпт `playbook/migrate-legacy.md`.
- **2026-07-07** — v2 split: пособие переписано как Greenfield Playbook; Adoption Guide выделен отдельно (brownfield); добавлен Value Proof case Kordon/MegaDelta; README переписан с индексом, Why-секцией и питчем. CI guard исправлен (frontmatter-only, без false positives); `WARN_ONLY` switch для brownfield rollout.
- **2026-07-07** — initial commit: README + Playbook v2 (greenfield модель).
