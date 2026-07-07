---
schema: 1
id: documentation-system-playbook-v2
type: spec
status: implemented
date: 2026-07-07
updated: 2026-07-07
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter, agent-entry-protocol, lifecycle-spec, lifecycle-adr]
touches: [docs, .context, .claude/rules, .github/workflows]
code: [.github/workflows/docs-validate.yml, bootstrap/bootstrap.sh, bootstrap/bootstrap.ps1, validators/validate-frontmatter.sh, scripts/migrate-legacy.mjs, schemas/frontmatter.schema.json, templates/architecture.md, templates/adr.md, templates/spec.md, templates/audit.md, templates/runbook.md, templates/backlog.md]
docs: [migrate-legacy.md]
refs: []
depends_on: [adr-001-tech-stack, adr-002-three-schema-db, adr-003-arq-workers]
implements: []
supersedes: []
tags: [documentation, playbook, greenfield, schema-v1]
priority: P0
---

# Documentation System Playbook v2 (Greenfield)

> Руководство по внедрению документационной системы на любом IaC/backend/frontend - проекте **с нуля**.
> На основе архитектуры naprolom-infra (2026-06–07).
> **Версия 2 greenfield — Canonical Schema v1 с первого дня.**
>
> Этот playbook описывает **целевую Greenfield-модель** Documentation System v2.
> Если система внедряется в существующий репозиторий (brownfield), используйте
> [Migration Prompt](migrate-legacy.md) — готовый агент-промпт для миграции legacy frontmatter в Canonical Schema v1.

---

## Зачем это нужно

Без системы документация умирает за 2 недели. AI-агенты не понимают контекст. Новые разработчики тратят дни на онбординг. Архитектурные решения забываются и повторяются.

Цель системы: **документация = инфраструктура**, а не текстовые файлы на произвольную тему.

**Greenfield-подход v2** означает: ни один .md файл в `docs/` не создаётся без canonical frontmatter Schema v1. Никаких legacy-полей (`author`, `title`, `created`, `lifecycle`, `referenced_by`, `supersedes_adr`). Для нового репозитория migration script не нужен — bootstrap создаёт структуру сразу в canonical-виде. Для существующего репозитория см. [Migration Prompt](migrate-legacy.md).

---

## Bootstrap (создание структуры)

Bootstrap — единственный source of truth для создания структуры директорий. Скрипт живёт в репозитории Runtime, а не в самом playbook:

```bash
# Linux / macOS / WSL
bash bootstrap/bootstrap.sh [project-name]

# Windows (PowerShell)
powershell -File bootstrap/bootstrap.ps1
```

Bootstrap идемпотентен и минимален: создаёт `docs/` skeleton (5-слойная архитектура), `.context/` stubs (`project.yml`, `boundaries.yml`, `agent-entry.md`), `CLAUDE.md` snippet и `docs-validate.yml` workflow. Никакой магии модификации существующих файлов.

Полные шаблоны документов (`.md`) живут отдельно от bootstrap — см. `templates/`, не встраиваются в скрипт. Это устраняет дрейф между playbook и реальными артефактами.

**Время выполнения:** ~5 секунд vs 2-3 часа ручного создания.

---

---
---

## Canonical Schema v1 (Reference)

Все .md файлы в `docs/` обязаны иметь canonical frontmatter, соответствующий Schema v1. Это **негласное правило первого дня greenfield rollout**:CI валидирует с первого commit.

### Base Schema (обязательная для всех документов)

```yaml
---
schema: 1                          # mandatory — версия THIS schema
id: <kebab-case>                   # mandatory — stable, never changes
type: <type-enum>                  # mandatory — per §Type enum
status: <per-type-enum>            # mandatory — per §Status enum
date: YYYY-MM-DD                   # mandatory — дата создания (см. §Семантика date)
updated: YYYY-MM-DD                # optional — дата последнего изменения

owners: []                         # mandatory — teams/components owning document
entity_refs: []                    # optional — domain entities referenced
touches: []                        # optional — subsystems affected
code: []                           # optional — code files referenced
docs: []                           # optional — internal doc references
refs: []                           # optional — external URLs
depends_on: []                     # optional — IDs of docs this one depends on
implements: []                     # optional — IDs of ADRs this doc implements
supersedes: []                     # optional — IDs this doc supersedes
tags: []                           # optional — free-form tags
priority: P0 | P1 | P2 | P3        # optional
---
```

**15 полей.** Обязательны: `schema`, `id`, `type`, `status`, `date`, `owners`. Остальные опциональны.

> **Удалено:** `excludes-from-scope: []` — anti-pattern. Лучше явно сказать "про Y", чем "не про Z". Если нужно — используйте `tags: [not-X]`.

### Семантика поля `date` (per-type)

| Type | `date` означает | Пример |
|------|-----------------|--------|
| `spec` | Дата создания черновика | 2026-07-01 |
| `adr` | Дата принятия решения (не написания) | 2026-07-05 |
| `audit` | Дата проведения аудита (не создания файла) | 2026-04-06 |
| `runbook` | Дата создания/последнего обновления | 2026-07-07 |
| `architecture` | Дата создания/последнего обновления | 2026-07-07 |
| `guide`, `backlog`, `prompt` | Дата создания/последнего обновления | 2026-07-07 |

### Поле `updated` (optional)

Заполняется автоматически при каждом изменении контента (не frontmatter). Используется для определения "свежести" документа:

```yaml
date: 2026-07-01       # когда создан
updated: 2026-07-07    # когда последний раз менялся
```

**Правило:** если `updated` не заполнен, считаем что документ не менялся с момента создания.

### Type enum

```
spec | adr | audit | runbook | guide | api | architecture | backlog | prompt
```

### Status enum (per-type)

| Type | Valid `status` |
|------|----------------|
| spec, api | draft, review, approved, implemented, superseded |
| adr | proposed, accepted, deprecated, superseded |
| audit | draft, completed |
| architecture, runbook, guide, backlog, prompt | active, deprecated |

### Per-type Extensions

Опциональные расширения сверх Base. Base + Extension = полный schema для типа.

```yaml
audit:
  scope: "<краткое описание что проверялось>"   # optional, free-form
  trigger: "<почему проведён аудит>"            # optional, free-form

runbook:
  kind: deploy | cicd | ops | troubleshoot | edge-hub | secrets | integration | legacy  # optional

api:
  version: "<semantic version>"                 # optional

guide:
  kind: index | onboarding | legacy             # optional

architecture: {}                                 # нет extensions
adr: {}                                          # нет extensions
spec: {}                                         # нет extensions
prompt: {}                                       # нет extensions
backlog: {}                                      # нет extensions
```

### Поле `lifecycle` — **ИСКЛЮЧЕНО**

`lifecycle` не часть canonical schema. Lifecycle specs вычисляется из path:

```
docs/specs/drafts/*         → drafts
docs/specs/review/*         → review
docs/specs/approved/*       → approved
docs/specs/implemented/*    → implemented
docs/specs/superseded/*     → superseded
иначе                        → нет lifecycle
```

CI/Portal вычисляет lifecycle из path. Убирает дрейф между path и полем. Никогда не добавляйте `lifecycle:` в frontmatter.

---

## Entity Refs Workflow

Правила создания и использования `entity_refs` в документации.

### Что такое entity_ref

Стабильный идентификатор доменной сущности проекта. Формат: `kebab-case`, отражает суть, а не реализацию.

**Примеры:**
```yaml
entity_refs:
  - schema-v1                  # Schema документационной системы
  - canonical-frontmatter      # Формат frontmatter
  - agent-entry-protocol       # Протокол входа агента
  - lifecycle-spec             # Lifecycle спецификаций
  - three-schema-db            # 3-схемная архитектура БД
  - arq-workers                # ARQ воркеры
```

### Правила создания

1. **Stable ID:** entity_ref не меняется никогда. Если сущность переименована — old ref deprecated, new ref добавляется.

2. **Min 2 символа:** никаких однобуквенных ref.

3. **Kebab-case:** `schema-v1`, не `Schema V1` и не `schema_v1`.

4. **Один ref = одна сущность:** не дублировать `schema` и `schema-v1`.

5. **Где определить:** в корневом `docs/architecture/README.md` или в отдельном `docs/architecture/entity-catalog.md`.

### Проверка существования

Перед добавлением `entity_refs` в документ:

```bash
# Проверка что ref существует в каталоге
grep -r "schema-v1:" docs/architecture/
```

Если ref не найден:
- **Сначала создайте сущность** (документ, ADR, spec)
- **Потом ссылайтесь** на неё из других документов

### Использование в CI

```yaml
# Валидация entity_refs (опционально, в docs-validate.yml)
- name: Verify entity_refs exist
  run: |
    set -e
    # Извлекаем все entity_refs из документа
    refs=$(grep -A 100 "^entity_refs:" docs/specs/approved/*.md | grep "  - " | awk '{print $2}' | sort -u)
    for ref in $refs; do
      # Проверяем что ref определён в catalog
      if ! grep -rq "id: $ref" docs/architecture/; then
        echo "WARNING: entity_ref '$ref' not found in architecture docs"
      fi
    done
```

### Правила использования

- **Минимум 1 ref** для spec и audit (сущности, к которым относится документ)
- **Максимум 10 refs** (иначе документ слишком "общий")
- **Прямая связь:** если spec описывает сущность X → `entity_refs: [X]`
- **Косвенная связь:** если spec затрагивает X, но не описывает → `touches: [X]` (не `entity_refs`)

---

## Lightweight Change Path (без spec)

Не каждое изменение требует spec. Существует lightweight path для мелких изменений:

### Когда НЕ нужна spec

| Тип изменения | Что делать |
|---------------|-----------|
| Bug fix | Commit message + PR description |
| Config change | Commit message + PR description |
| Documentation update | Commit message + PR description |
| Refactoring без изменения behavior | Commit message + PR description |
| Dependency update | Commit message + PR description |
| Hotfix в продакшн | Commit message + PR description |

### Когда НУЖНА spec

| Тип изменения | Почему |
|---------------|--------|
| Новый API endpoint | Меняет контракт для клиентов |
| Новая таблица/столбец | Меняет data model |
| Новый сервис | Меняет topology |
| Изменение ACL/RBAC | Меняет security model |
| Изменение pipeline | Меняет flow данных |
| Миграция данных | Потенциально обратимо, требует plan |

### Формат lightweight changes

```markdown
## What
Исправлен баг: невалидный JSON в response.

## Why
Клиент получал 500 вместо 400 при невалидном JSON.

## Changed
- `app/api/v1/validators.py` — добавлена валидация JSON

## Testing
- Добавлен тест `tests/test_validators.py::test_invalid_json`
```

---

## Директории и их назначение

| Директория | Назначение | Правила |
|------------|-----------|---------|
| `.context/` | Метаданные проекта для AI-агентов | Читается первым всегда |
| `docs/architecture/` | Живая архитектура (топология, модель данных, инварианты) | Обновляется при каждом изменении топологии/схемы |
| `docs/adr/` | Architecture Decision Records | Body immutable после `accepted`. Frontmatter = metadata, может обновляться |
| `docs/specs/` | Жизненный цикл спецификаций | `drafts/ → review/ → approved/ → implemented/ → superseded/` |
| `docs/audits/` | Аудиты и forensic-отчёты | Body append-only, FM = metadata (mutable) |
| `docs/backlog/` | Единый бэклог задач | Свободный формат → нарезка в GitHub Issues |
| `docs/prompts/` | AI-контекстные промпты | type: prompt — отвечает LLM, не человеку |
| `docs/api/` | API specifications | type: api, versioned |
| `.claude/rules/` | Правила для AI-агента (Claude Code) | Привязаны к ADR и docs/ |
| `.ai/reports/` | Отчёты аудитов AI | Высокоуровневые сводки |

---

## Step-by-Step: Внедрение с нуля (Greenfield)

### Phase 0: Подготовка (30 минут)

1. Определить стек проекта
2. Запустить bootstrap script:

```bash
./docs-bootstrap.sh my-project
```

3. Заполнить `.context/project.yml` и `.context/boundaries.yml`

### Phase 1: Agent Entry Protocol (1–2 часа)

Это **самый важный слой**. Без него AI-агенты не знают с чего начать.

#### 1.1 `.context/project.yml`

```yaml
project:
  name: my-project
  description: Что это за проект (1 предложение)
  domain: example.com
  maintainer: team-name
  repository: https://github.com/org/repo

stack:
  backend: [FastAPI, Python]
  database: [PostgreSQL 17]
  infrastructure: [Docker Compose, Traefik]

directories:
  key:
    app/: "Основной код"
    infra/: "Инфраструктура"
    docs/: "Документация"
```

#### 1.2 `.context/boundaries.yml`

```yaml
boundaries:
  pristine:    # НЕ ТРОГАТЬ (upstream, boilerplate)
    - path: vendor/
      reason: "third-party, tracked upstream"

  editable:    # МОЖНО ИЗМЕНЯТЬ
    - path: app/
      reason: "core application code"
    - path: docs/
      reason: "all documentation"
    - path: infra/
      reason: "infrastructure config"

  generated:   # СОЗДАЕТСЯ СКРИПТАМИ
    - path: .env
      source: .env.example
      reason: "created by bootstrap from template"

  secret:      # НИКОГДА НЕ КОММИТИТЬ
    - path: .env
      note: "passwords and tokens"
    - path: "*.key"
      note: "private keys"
```

#### 1.3 `.context/decisions.yml`

```yaml
decisions:
  - id: ADR-001
    title: "Выбор оркестратора"
    file: docs/adr/001-orchestrator-choice.md
    status: accepted
    summary: "Docker Compose для dev, Kubernetes для prod"
```

#### 1.4 `.context/agent-entry.md`

```markdown
# Agent Entry Protocol

## 1. Read First (in this order)
1. `.context/project.yml` — what project this is
2. `.context/boundaries.yml` — what you can/cannot edit
3. `docs/architecture/README.md` — topology, data model, invariants
4. `CLAUDE.md` (или аналог) — rules

## 2. Before Editing Any File
1. Check `.context/boundaries.yml`
2. If pristine → STOP, ask human
3. If generated → edit template, not output
4. If editable → proceed with existing patterns

## 3. Before Creating Any .md in docs/
1. Identify `type` (adr | spec | audit | runbook | architecture | backlog | prompt | guide | api)
2. `cp docs/<type>/_template.md <target-path>` (если template есть)
3. Заполни **минимум** 6 mandatory полей: `schema`, `id`, `type`, `status`, `date`, `owners`
4. Никогда не добавляй `lifecycle:` поле — оно computed from path
5. Никогда не используй legacy поля: `author`, `title`, `created`, `referenced_by`, `supersedes_adr`
```

#### 1.5 `CLAUDE.md` (или `AGENTS.md`, `.opencode/config`)

```markdown
# Project Name — Agent Rules

## Agent Entry Protocol
1. `docs/architecture/system-overview.md`
2. `docs/architecture/README.md`
3. `docs/adr/`
4. `docs/specs/approved/`

## Stack
[Краткое описание стека]

## Commands
[Ключевые команды]

## Architectural Invariants
[Главные правила, которые нельзя нарушать]

## Documentation Invariants (Schema v1)
- Все .md в docs/ обязаны иметь canonical Schema v1 frontmatter
- 6 mandatory полей: schema, id, type, status, date, owners
- lifecycle ВСЕГДА computed from path — нет такого поля в FM
- legacy поля запрещены: author, title, created, referenced_by, supersedes_adr
- type: prompt ≠ type: guide — prompts для LLM, guides для humans
```

### Phase 2: Architecture Layer (2–4 часа)

#### 2.1 `docs/architecture/README.md` — индекс модулей

```markdown
---
schema: 1
id: architecture-readme
type: architecture
status: active
date: YYYY-MM-DD
owners: [naprolom-team]
---

# Architecture Reference Index

## Critical Invariants (MUST verify before ANY change)
| ID | Rule | Where enforced |
|----|------|----------------|
| INV-1 | Never modify X | Validation code |
| INV-2 | Y must equal Z | API check |

## Module Index
| Topic | File | When to load |
|-------|------|--------------|
| Networks | topology.md | Adding service |
| Data Model | domain-model.md | Changing schema |
```

#### 2.2 `docs/architecture/system-overview.md` — AI-first overview

```markdown
---
schema: 1
id: architecture-system-overview
type: architecture
status: active
date: YYYY-MM-DD
owners: [naprolom-team]
---

# System Overview

## What is this
[1 абзац]

## Core Subsystems
| Subsystem | Components | Location |
|-----------|-----------|----------|

## Data Model
[Схема 5-слойной модели или аналог]

## Key Architecture Decisions
| Decision | Where documented |
|----------|-----------------|
```

#### 2.3 Детальные документы в `docs/architecture/`

Создавать по мере необходимости:
- `topology.md` (id: `architecture-topology`)
- `domain-model.md` (id: `architecture-domain-model`)
- `deploy-engine.md` (id: `architecture-deploy-engine`)
- `terminology.md` (id: `architecture-terminology`)

### Phase 3: ADR Layer (1–2 часа на каждый ADR)

#### 3.1 Создание ADR

```bash
cp .context/runtime/naprolom-docs/templates/adr.md docs/adr/NNN-<slug>.md
# NN — следующий свободный номер (zero-padded до 3 цифр)
# slug — kebab-case, описывает решение (не реализацию)
```

Заполнить:
- `id`: `adr-NNN-<slug>` (stable, never changes)
- `status`: `proposed` (после принятия меняется на `accepted`,FM-only edit)
- `date`: дата принятия решения (не дата написания)
- `owners`: команды, принимающие ответственность
- `supersedes`: если заменяет старый ADR — список ID
- Body: `# ADR-NNN:`, Status, Context, Decision, Consequences, Related

#### 3.2 Правила ADR

1. **Body immutable после acceptance.** Если решение меняется — создаём новый ADR с `supersedes: [adr-XXX]` и body нового решения. Body старого ADR **не модифицируется** — оно доказательство принятия решения в прошлом.

2. **Frontmatter = metadata.** Добавление или изменение frontmatter **не считается** изменением содержимого ADR и **не нарушает** принцип immutability. Frontmatter обновляется при lifecycle transitions:
   - `proposed → accepted` (при принятии)
   - `accepted → deprecated` (когда решение устарело без замены)
   - `accepted → superseded` (когда заменяется новым ADR; одновременно новый ADR получает `supersedes: [<old-id>]`)

3. **Нет стабов.** ADR создаётся только когда решение написано полностью. `status: proposed` означает-complete (draft не бывает).

4. **ADR отвечает на "Почему?"**, а не "Что построили?" Если хотите описать реализацию — это spec, не ADR.

5. **Референс в specs:** каждая approved спека должна ссылаться на релевантный ADR через `implements: [adr-XXX-foo]` (если спека прямо имплементирует решение ADR) или `depends_on: [adr-XXX-foo]` (если ADR — предпосылка, но не имплементируем).

### Phase 4: Spec Lifecycle (2–3 часа)

#### 4.1 Создание спеки

```bash
cp .context/runtime/naprolom-docs/templates/spec.md docs/specs/drafts/YYYY-MM-DD-<slug>.md
# fill frontmatter: status: draft (обязательно совпадает с директорией!)
# fill body: Goal, Context, Scope, Technical approach, Affected files, Open questions
```

#### 4.2 Lifecycle

```
docs/specs/drafts/     → черновик, WIP, status: draft
docs/specs/review/     → готово к ревью, status: review
docs/specs/approved/   → можно имплементировать, status: approved
docs/specs/implemented/ → архив (никогда не удалять), status: implemented
docs/specs/superseded/ → заменено новым (никогда не удалять), status: superseded
```

Продвижение через `git mv` + `status` update в FM:

```bash
# draft → review
git mv docs/specs/drafts/2026-07-06-feature.md docs/specs/review/
# затем в файле: status: draft → status: review

# review → approved
git mv docs/specs/review/2026-07-06-feature.md docs/specs/approved/
# в файле: status: review → status: approved

# approved → implemented (после завершения)
git mv docs/specs/approved/2026-07-06-feature.md docs/specs/implemented/
# в файле: status: approved → status: implemented
# заполнить ## Result section

# approved → superseded (если заменена)
git mv docs/specs/approved/2026-07-06-feature.md docs/specs/superseded/
# в файле: status: approved → status: superseded
# в новой спеке: supersedes: [<old-id>]
```

**CI валидирует:** если file в `docs/specs/drafts/` ⇒ `status: draft` (иначе fail). Path и status обязаны совпадать. Это и есть source-of-truth lifecycle (D-4 Variant B).

#### 4.3 Правила

- **Создание:** `cp .context/runtime/naprolom-docs/templates/spec.md docs/specs/drafts/YYYY-MM-DD-<slug>.md`
- **Нельзя имплементировать** спеку не в `approved/` (CI FAIL на PR, меняющем код без соответствующей спеки в `approved/`)
- **После имплементации:** заполнить `## Result`, переложить в `implemented/`, `status: implemented`
- **Supersede:** если новая спека заменяет старую — переместить старую в `superseded/` с `status: superseded`, в новой указать `supersedes: [<old-id>]`
- **Никогда не удалять** выполненные спеки — это история решений

### Phase 5: Operations Docs (1–2 часа)

#### 5.1 Минимальный набор runbooks

| Файл | type | kind | Назначение |
|------|------|------|-----------|
| `docs/deploy.md` | runbook | deploy | Bootstrap/deploy пошагово |
| `docs/cicd.md` | runbook | cicd | CI/CD — канонический источник |
| `docs/ops.md` | runbook | ops | Day-to-day операции |
| `docs/troubleshooting.md` | runbook | troubleshoot | Паттерны сбоев и фиксы |
| `docs/secrets.md` | runbook | secrets | Референс секретов |

#### 5.2 Шаблон runbook

```markdown
---
schema: 1
id: runbook-<slug>
type: runbook
status: active
date: YYYY-MM-DD
owners: [naprolom-team]
kind: deploy | cicd | ops | troubleshoot | secrets | integration
---

# Topic

## When to use
[Описание ситуации]

## Prerequisites
- [Требование 1]
- [Требование 2]

## Steps
1. Шаг 1
2. Шаг 2
3. Шаг 3

## Verification
[Как проверить что всё работает]

## Rollback
[Что делать если пошло не так]
```

### Phase 6: AI Agent Rules (1–2 часа)

#### `.claude/rules/` — контекстные правила

| Файл | Назначение |
|------|-----------|
| `doc-update.md` | Протокол обновления доков после изменений |
| `spec-workflow.md` | Lifecycle спеки, создание Issues, ссылка на Schema v1 |
| `audit-workflow.md` | Создание audits из canonical template |
| `entity-workflow.md` | Правила создания и использования entity_refs |
| `new-service.md` | Чек-лист добавления нового сервиса |
| `testing.md` | Как запускать тесты |

#### 6.1 `.claude/rules/doc-update.md`

```markdown
---
# Applies always — no path restriction
---

# Doc Update Protocol

After completing any task and before asking for review:

1. Identify touched components from `git diff --stat`
2. Map components to docs:
   | Changed | Update |
   |---------|--------|
   | docker-compose.yml | docs/architecture/README.md |
   | .env.example | docs/secrets.md |
3. Ask user: "Обновить доки? Затронуты: [список]"
4. If yes: update only relevant sections (max 20 lines per file)
5. Update frontmatter `updated` если контент изменился
```

#### 6.2 `.claude/rules/spec-workflow.md`

```markdown
---
applies-to: path("docs/specs/**")
---

# Spec Workflow

Создание:

1. `cp .context/runtime/naprolom-docs/templates/spec.md docs/specs/drafts/YYYY-MM-DD-<slug>.md`
2. fill FM:
   - `id`: `<slug>` (без даты, stable)
   - `status`: `draft` (обязательно — совпадает с drafts/ директорией)
   - `date`: дата создания
   - `updated`: дата последнего изменения (optional)
   - `owners`: команда
   - `touches`: подсистемы
   - `entity_refs`: сущности, к которым относится spec
3. fill body: Goal, Context, Scope, Technical approach, Affected files, Open questions

Lifecycle (path == status, нет отдельного `lifecycle` поля):

```
drafts/  (status: draft)  →  review/   (status: review)
review/  (status: review)  →  approved/ (status: approved)
approved/(status: approved)→  implemented/ (status: implemented)
approved/(status: approved)→  superseded/  (status: superseded)
```

Каждая transition — `git` mv + update `status` в FM. CI валидирует path-status match.

**Запрещено:**
- имплементировать спеку не в `approved/`
- оставлять `lifecycle:` поле (оно убрано из Schema v1)
- удалять спеки — `implemented/` и `superseded/` permanent
- создавать .md без `schema: 1` и `id:`
```

#### 6.3 `.claude/rules/audit-workflow.md`

```markdown
---
applies-to: path("docs/audits/**")
---

# Audit Workflow

Когда создаёшь новый audit:

1. Скопируй `.context/runtime/naprolom-docs/templates/audit.md` в `docs/audits/YYYY-MM-DD-<slug>.md`
2. Заполни frontmatter:
   - `id`: `audit-<slug>` (slug без даты)
   - `status`: `draft` (если в работе) или `completed` (если завершён)
   - `date`: дата проведения (не дата создания файла)
   - `scope`: что проверялось (одно предложение, per-type extension)
   - `trigger`: почему проведён (per-type extension)
   - `entity_refs`: сущности, затронутые в audit
   - `touches`: subsystems affected
3. Заполни body (canonical structure):
   - `# Audit: <title>` (без даты в заголовке — дата в frontmatter)
   - Summary → Findings → Conflicts (optional) → Resolution → Delta

**Append-only rule:**
- Frontmatter = metadata (mutable: `status: draft → completed` разрешён)
- Body = content (immutable после `status: completed`)

**Никогда:**
- Не редактируй body существующего audit после `status: completed`
- Не создавай audit без `id` или без `type: audit`
- Не используй inline `**Date:**` в body — дата живёт в frontmatter
- Новый аудит по новой дате — нового старого не править
```

#### 6.4 `.claude/rules/entity-workflow.md`

```markdown
---
# Applies always — no path restriction
---

# Entity Refs Workflow

## Определение

`entity_refs` — стабильные идентификаторы доменных сущностей проекта. Формат: `kebab-case`.

## Когда использовать

- **spec:** entity_refs содержит сущности, которые spec ОПИСЫВАЕТ (не просто затрагивает)
- **audit:** entity_refs содержит сущности, которые audit ПРОВЕРЯЕТ
- **architecture:** entity_refs содержит сущности, которые документ ОПИСЫВАЕТ
- **runbook:** entity_refs содержит сущности, к которым относится runbook
- **adr:** entity_refs пуст (ADR описывает решение, не сущность)

## Правила

1. **Min 1 ref** для spec и audit
2. **Max 10 refs** (иначе документ слишком "общий")
3. **Прямая связь:** spec описывает X → `entity_refs: [X]`
4. **Косвенная связь:** spec затрагивает X, но не описывает → `touches: [X]`

## Создание нового ref

1. Создайте документ, описывающий сущность (architecture, spec, ADR)
2. Определите `id` в canonical format (kebab-case)
3. Добавьте в `docs/architecture/entity-catalog.md` или в соответствующий architecture doc
4. Теперь можно ссылаться из других документов

## Проверка

```bash
# Проверить что ref существует
grep -r "schema-v1:" docs/architecture/

# Проверить что все entity_refs в проекте определены
grep -rh "entity_refs:" docs/ | grep -v "^\s*entity_refs: \[\]" | awk '{print $2}' | while read ref; do
  grep -rq "$ref" docs/architecture/ || echo "WARNING: $ref not defined"
done
```
```

#### 6.5 `.claude/rules/new-service.md`

```markdown
---
applies-to: path("**/{docker-compose*.yml,*.service.yml}")
---

# New Service Checklist

Before adding a new service:

1. Update `docs/architecture/README.md` Module Index
2. Update `docs/architecture/topology.md` (если есть сетевые порты)
3. Create new `docs/<service>-deploy.md` (type: runbook, kind: deploy)
4. Add secrets to `docs/secrets.md`
5. Add service to `docs/ops.md` day-to-day operations
6. Create spec in `docs/specs/drafts/YYYY-MM-DD-<service>-integration.md`
```

---

## AI Agent: Protocol загрузки контекста

При старте работы с репозиторием агент загружает:

```
1. .context/project.yml        — что это за проект
2. .context/boundaries.yml     — что можно/нельзя трогать
3. docs/architecture/README.md  — топология, data model, инварианты
4. CLAUDE.md                    — правила работы с кодовой базой
5. docs/adr/                    — принятые архитектурные решения
6. docs/specs/approved/         — что имплементировать
```

---

## Canonical Source of Truth

| Тема | Канонический источник |
|------|----------------------|
| CI/CD | `docs/cicd.md` (type: runbook, kind: cicd) |
| Service topology | `docs/architecture/README.md` |
| Data model | `docs/architecture/domain-model.md` |
| Secrets | `docs/secrets.md` (type: runbook, kind: secrets) |
| Active tasks | `docs/backlog/active.md` (type: backlog) |
| Agent rules | `CLAUDE.md` + `.claude/rules/` |
| Frontmatter schema | Этот playbook §«Canonical Schema v1» + templates |
| Audit workflow | `.claude/rules/audit-workflow.md` |
| Spec workflow | `.claude/rules/spec-workflow.md` |
| Entity refs | `.claude/rules/entity-workflow.md` |

При конфликте информации — читать канонический источник.

---

## Аудиты и снэпшоты

`docs/audits/` — **append-only body**, **mutable frontmatter**. Каждый новый аудит создаётся из canonical шаблона.

### Создание нового аудита

1. `cp .context/runtime/naprolom-docs/templates/audit.md docs/audits/YYYY-MM-DD-<slug>.md`
2. Заполнить frontmatter: `id`, `status: draft`, `date`, `scope`, `trigger`, `entity_refs`, `touches`
3. Заполнить body: `# Audit: <title>`, Summary, Findings, Conflicts (optional), Resolution, Delta
4. Если audit завершён — `status: completed` (terminal)

### Audit Frontmatter (canonical schema + audit per-type extension)

| Поле | Type | Mandatory | Description |
|------|------|-----------|-------------|
| `schema` | int | да | Schema version (`1`) |
| `id` | string | да | Stable ID, `audit-<slug>` |
| `type` | enum | да | `audit` (constant) |
| `status` | enum | да | `draft` или `completed` |
| `date` | date | да | Дата проведения |
| `owners` | [] | да | Teams/components |
| `updated` | date | нет | Дата последнего изменения |
| `scope` | string | нет | Что проверялось (per-type extension) |
| `trigger` | string | нет | Почему проведён (per-type extension) |
| `entity_refs` | [] | нет | Сущности, затронутые audit-ом |
| `touches` | [] | нет | Subsystems affected |

### Audit Body structure (canonical)

```
# Audit: <title>

> Scope: <...>
> Trigger: <...>

## Summary
<!-- 1-2 предложения: что проверялось, что нашли -->

## Findings
| # | Severity | Finding | Evidence | Recommendation |
|---|----------|---------|----------|----------------|
| F-01 | ... | ... | ... | ... |

## Conflicts
<!-- противоречия между находками (если есть) -->

## Resolution
<!-- как разрешили или plan разрешения -->

## Delta
<!-- что изменилось с прошлого аудита этой сущности -->
```

### Append-only rule

> **Frontmatter = metadata. Body = content.**
> Append-only правило относится к **body** аудита. Frontmatter может обновляться (например, `status: draft → completed`).
> Body не редактируется после `status: completed`. Новый аудит = новый файл с новой датой.

---

## Backlog: от идей до Issues

```
docs/backlog/active.md       ← черновая корзина (свободный формат)
         ↓ команда: "нарежь бэклог на задачи"
GitHub Issues                ← атомарные задачи с acceptance criteria
         ↓ после имплементации
Issue закрывается            ← backlog → раздел Done
```

Файл `docs/backlog/active.md` имеет canonical frontmatter:

```yaml
---
schema: 1
id: backlog-active
type: backlog
status: active
date: YYYY-MM-DD
owners: [naprolom-team]
---
```

---

## Метрики качества документации

Ключевые индикаторы здоровья документационной системы:

### Coverage Metrics

| Метрика | Цель | Как проверить |
|---------|------|---------------|
| % документов с `entity_refs` | >80% | `grep -L "entity_refs" docs/**/*.md` |
| % specs в `approved/` или `implemented/` | >50% | `ls docs/specs/{approved,implemented}/ \| wc -l` |
| % ADR со статусом `accepted` | >90% | `grep -l "status: accepted" docs/adr/*.md` |
| % документов без legacy fields | 100% | CI guard |

### Freshness Metrics

| Метрика | Цель | Как проверить |
|---------|------|---------------|
| % документов обновлённых за последние 90 дней | >70% | `find docs/ -mtime -90 -name "*.md"` |
| % specs без `updated` field | <20% | `grep -L "updated:" docs/specs/**/*.md` |
| % документов старше 1 года без review | <10% | `find docs/ -mtime +365 -name "*.md"` |

### Quality Metrics

| Метрика | Цель | Как проверить |
|---------|------|---------------|
| Все .md в `docs/` с `schema: 1` | 100% | CI guard |
| Все .md без legacy fields | 100% | CI guard |
| Все spec path-status match | 100% | CI guard |
| Все runbooks с `kind:` field | 100% | `grep -L "kind:" docs/**/*.md` |

### Автоматическая проверка

```bash
# Скрипт проверки здоровья документации
#!/bin/bash
set -euo pipefail

echo "📊 Documentation Health Check"
echo "=============================="

# 1. Schema coverage
total=$(find docs/ -name "*.md" | wc -l)
with_schema=$(grep -rl "^schema: 1" docs/ | wc -l)
echo "Schema coverage: $with_schema/$total ($(echo "scale=1; $with_schema*100/$total" | bc)%)"

# 2. Entity refs coverage
with_refs=$(grep -rl "entity_refs:" docs/ | grep -v "\[\]" | wc -l)
echo "Entity refs: $with_refs/$total ($(echo "scale=1; $with_refs*100/$total" | bc)%)"

# 3. Legacy fields
legacy=0
for field in "lifecycle:" "^author:" "^title:" "^created:" "supersedes_adr:" "referenced_by:"; do
  count=$(grep -rl "$field" docs/ 2>/dev/null | wc -l)
  legacy=$((legacy + count))
done
echo "Legacy fields: $legacy (should be 0)"

# 4. Spec status distribution
echo ""
echo "Spec status distribution:"
for dir in drafts review approved implemented superseded; do
  count=$(ls docs/specs/$dir/*.md 2>/dev/null | wc -l)
  echo "  $dir: $count"
done

# 5. ADR status distribution
echo ""
echo "ADR status distribution:"
for status in proposed accepted deprecated superseded; do
  count=$(grep -l "status: $status" docs/adr/*.md 2>/dev/null | wc -l)
  echo "  $status: $count"
done
```

---

## Шпаргалка: Lifecycle Документов

| Тип документа | type | Valid status | Где хранится | Правила |
|--------------|------|--------------|-------------|---------|
| ADR | `adr` | `proposed → accepted → deprecated → superseded` | `docs/adr/` | Body immutable после acceptance; FM = metadata |
| Spec | `spec` | `draft → review → approved → implemented → superseded` | `docs/specs/{drafts,review,approved,implemented,superseded}/` | Git mv + update `status`, never delete |
| Audit | `audit` | `draft → completed` | `docs/audits/` | Body never edit after completed; FM mutable |
| Runbook | `runbook` | `active → deprecated` | `docs/*.md` | Обновляется при изменениях; kind distinguishes |
| Architecture | `architecture` | `active → deprecated` | `docs/architecture/` | Обновляется при изменениях топологии/схемы |
| Guide | `guide` | `active → deprecated` | `docs/*.md` (index, README) | Navigation entrance |
| API | `api` | `draft → review → approved → implemented → superseded` | `docs/api/` | Versioned spec |
| Backlog | `backlog` | `active → deprecated` | `docs/backlog/` | Свободный формат |
| Prompt | `prompt` | `active → deprecated` | `docs/prompts/` | Контекст для LLM |

> **Note:** `lifecycle` не колонка в таблице — он computed из path для specs/api. Для других типов lifecycle = status (нет отдельной директории).

---

## Частые ошибки

| Ошибка | Почему плохо | Решение |
|--------|-------------|---------|
| Нет entry point для AI | Агент не знает с чего начать | `.context/` + `docs/README.md` START HERE |
| ADR-подобные документы в audits/ | Нет формального статуса | Вынести в `docs/adr/` с формальным lifecycle |
| Спеки с `lifecycle:` полем в FM | Дрейф между path и полем при `git mv` | Lifecycle **computed from path**, не хранить в FM. CI валидирует `status` vs path |
| Frontmatter без `schema:` / `id:` / `type:` | Машина не отличит canonical от legacy | Все .md в `docs/` обязаны иметь 6 mandatory полей Schema v1 |
| `author:` / `title:` / `created:` / `referenced_by:` legacy поля | Conflicts with canonical schema, breaks Portal parser | Заменить: `author` → `owners`, `title` → body `# H1`, `created` → `date`, `referenced_by` → computed by Portal |
| Inline `**Date:**` в audit/spec body | Conflicts with frontmatter date | Не использовать; дата живёт в FM, body содержит только `# H1` title |
| Дублирование в .claude/rules/ | Выходят из синхронизации | Thin pointers → канонический источник в docs/ |
| Runbooks без `kind:` | Нельзя отличить deploy от troubleshoot | `type: runbook` всегда с `kind:` |
| Body ADR модифицирован при добавлении FM | Нарушение immutability | Carve-out rule: FM ≠ body. Body byte-for-byte не трогается, при необходимости update — FM only |
| Audit без canonical template | Body structure varies, hard to parse | Всегда `cp .context/runtime/naprolom-docs/templates/audit.md ...` |
| Создание .md без template | FM не canonical, нет `schema:`/`id` | Greenfield invariant: начинаем с `cp <type>/_template.md`, не с пустого файла |
| Удаление выполненных спек | Потеря истории решений | Никогда не удалять, хранить в `implemented/` |
| `supersedes_adr:` вместо `supersedes:` | Legacy field, breaks parser | `supersedes: [<id>]` — list (может быть несколько) |
| Использование `excludes-from-scope` | Anti-pattern: лучше сказать "про Y", чем "не про Z" | Использовать `tags: [not-X]` если необходимо |
| Нет `entity_refs` в spec/audit | Не понятно к каким сущностям относится | Минимум 1 ref для spec и audit |

---

## Метрики готовности (Schema v1 greenfield)

Проверка что система внедрена с первого дня:

- [ ] `.context/project.yml` существует и содержит стек
- [ ] `.context/boundaries.yml` классифицирует файлы
- [ ] `docs/architecture/README.md` существует, canonical FM, содержит инварианты и индекс модулей
- [ ] `.context/runtime/naprolom-docs/templates/spec.md` существует с Canonical Schema v1 Base
- [ ] `.context/runtime/naprolom-docs/templates/audit.md` существует с audit extension (`scope`, `trigger`)
- [ ] `.context/runtime/naprolom-docs/templates/adr.md` существует с canonical ADR FM
- [ ] Хотя бы 1 ADR в `docs/adr/` со статусом `accepted` (или proposed)
- [ ] `docs/README.md` существует, canonical FM (`type: guide, kind: index`), START HERE секция
- [ ] `.claude/rules/doc-update.md` определяет протокол обновления доков
- [ ] `.claude/rules/audit-workflow.md` определяет создание audits
- [ ] `.claude/rules/spec-workflow.md` определяет spec lifecycle + path-status validation rule
- [ ] `.claude/rules/entity-workflow.md` определяет entity_refs workflow
- [ ] `docs/backlog/active.md` существует, canonical FM (`type: backlog, status: active`)
- [ ] CI guard: PR fail если в `docs/**/*.md` нет `schema: 1` mandatory полей
- [ ] Mass grep validation: `git grep "^schema: 1$" docs/` → matches all .md files
- [ ] Mass grep validation: `git grep "lifecycle:" docs/` → **0 matches**
- [ ] Mass grep validation: `git grep "^author:" docs/` → 0 matches
- [ ] Mass grep validation: `git grep "^title:" docs/` → 0 matches
- [ ] Mass grep validation: `git grep "supersedes_adr:" docs/` → 0 matches
- [ ] Mass grep validation: `git grep "referenced_by:" docs/` → 0 matches
- [ ] Mass grep validation: `git grep "excludes-from-scope:" docs/` → 0 matches

---

## Время на внедрение

| Phase | Время | Блокер |
|-------|-------|--------|
| Phase 0: Структура + templates | 5 мин | Нет (bootstrap script) |
| Phase 1: Agent Entry | 1–2 ч | Нет |
| Phase 2: Architecture | 2–4 ч | Понимание текущей архитектуры |
| Phase 3: ADRs | 1–2 ч на ADR | Решения должны быть приняты |
| Phase 4: Spec Lifecycle | 2–3 ч | Phase 0 |
| Phase 5: Operations | 1–2 ч | Phase 0 |
| Phase 6: AI Rules | 1–2 ч | Phase 1 |
| CI Schema v1 guard | 30 мин | Phase 0 (добавить в `.github/workflows/docs-validate.yml`) |

**Итого:** 8–17 часов на полное внедрение. Минимально: Phase 0 + 1 = 2–3 часа (включая templates creation).

> Greenfield экономия vs миграция с v1: ~в 2 раза быстрее — нет необходимости retrofit 155 .md файлов, нет migration script, нет 7 waves W0-W7, нет manual review ADR bodies на byte-for-byte сохранность.

---

## CI Schema v1 Guard (включить с первого PR)

> **Принцип без ложных срабатываний.** Guard проверяет **только frontmatter** (YAML между первым и вторым `---`), а не весь файл. Поэтому упоминания legacy-полей в прозе, таблицах и code-блоках (например, в этом playbook или в Migration Prompt) не ломают CI. Lifecycle и legacy-поля запрещены именно как **ключи frontmatter**, и проверяются только там, где они и могут быть — в FM.

`.github/workflows/docs-validate.yml`:

```yaml
name: docs-validate
on:
  pull_request:
    paths: ["docs/**"]

jobs:
  schema-v1:
    runs-on: ubuntu-latest
    env:
      WARN_ONLY: ""   # brownfield: "true" на rollout период
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
      - name: Validate Canonical Schema v1 frontmatter
        run: |
          bash .context/runtime/naprolom-docs/validators/validate-frontmatter.sh
```


**Почему так:**
- `awk` режет только блок FM → legacy-поля в теле документа (проза/таблицы/код) не вызывают false positive.
- `WARN_ONLY=true` включает режим warn-only для brownfield rollout (Migration Prompt, §Warn-only CI). Greenfield оставляет переменную пустой → strict.
- Проверка `schema: 1` и mandatory-полей идёт по FM, не по всему файлу.

**Greenfield:** strict с первого PR (переменная `WARN_ONLY` пуста).
**Brownfield:** на период rollout поставить `WARN_ONLY: "true"`, после cleanup переключить обратно в strict.

Этот guard **включается с первого PR** (greenfield). Никаких transition periods, никаких warn-only.

---

## Result

**status:** implemented

**changed (this Runtime refactor):**
- `playbook/playbook-v2.md` — этот файл (ранее в корне репо, переименован и перенесён).
- `playbook/migrate-legacy.md` — агент-промпт для brownfield миграции (ранее `docs/guides/legacy-migration.md`).
- `templates/architecture.md`, `templates/adr.md`, `templates/spec.md`, `templates/audit.md`, `templates/runbook.md`, `templates/backlog.md` — canonical шаблоны, вынесенные из playbook как standalone файлы.
- `schemas/frontmatter.schema.json` — JSON Schema для Canonical Schema v1 (base + per-type extensions + forbidden legacy fields).
- `validators/validate-frontmatter.sh` — frontmatter-only валидатор (с `WARN_ONLY` switch, path-status match с `drafts→draft` нормализацией, проверкой `kind:` для runbook).
- `bootstrap/bootstrap.sh`, `bootstrap/bootstrap.ps1` — минимальный идемпотентный bootstrap (создаёт `docs/` skeleton, `.context/` stubs, `CLAUDE.md` snippet, `docs-validate.yml` workflow).
- `scripts/migrate-legacy.mjs` — runnable миграция brownfield (без внешних зависимостей).
- `INSTALL.md` — consumer integration: submodule add, `.gitmodules` branch=master, CLAUDE.md snippet, manual update, Dependabot gitsubmodule.
- `README.md` — переписан как Landing Page Runtime (не как canonical index репозитория).
- `.github/workflows/docs-validate.yml` — workflow, вызывающий `validators/validate-frontmatter.sh` (локально; push ожидает нового PAT с `workflow` scope).
- `agents/{claude-code,opencode}/` — роли `architecture-reviewer`, `documentation-reviewer` для обеих платформ.

**deviations (vs. исходный план v2):**
- `templates/` вынесены из playbook как standalone canonical файлы — устраняет дрейф между документацией и реальными артефактами.
- `bootstrap/` минимизирован: создаёт только `docs/` + `.context/` + `CLAUDE.md` snippet + workflow — никакой магии модификации существующих файлов.
- Валидатор поддерживает нормализацию `drafts` → `draft` (директория plural, статус singular).
- CI guard вызывает `validators/validate-frontmatter.sh`, не содержит inline-проверок — единый source of truth.
- `docs/bootstrap script inline в playbook` удалён — playbook ссылается на `bootstrap/bootstrap.sh`.
