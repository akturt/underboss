---
schema: 1
id: install-runtime
type: guide
kind: onboarding
status: active
date: 2026-07-08
updated: 2026-07-08
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter, runtime-agentic-layer]
touches: [docs, .context, .gitmodules, CLAUDE.md, .github/workflows]
docs: [playbook/playbook-v2.md, playbook/migrate-legacy.md]
refs: []
depends_on: []
implements: []
supersedes: []
tags: [install, submodule, consumer, onboarding, v1.1]
priority: P0
---

# INSTALL — Подключение Documentation System Runtime

> Этот документ открывает **пользователь naprolom-docs после `git submodule add`**.
> Остальное (`playbook/`, `engine/templates/`, `engine/validators/`, `engine/schemas/`, `engine/scripts/`, `bootstrap/`, `agents/`, `knowledge/`, `sops/`) — содержимое Runtime, оно подъезжает автоматически вместе с submodule.
>
> **v1.1 (D-BR):** Runtime подключается **внутрь `docs/`**, а не в `.context/runtime/`. В корне consumer-репо остаётся только `docs/` — никаких служебных каталогов в корне. Внутри `docs/` появляются user-content (`architecture/`, `adr/`, `specs/`, `audits/`, ...) И система ведёт себя локально под `docs/.runtime/naprolom-docs/`. См. §Two-repo model ниже.

---

## Two-repo model

`naprolom-docs` существует в **двух ролях одновременно** — важно их не путать:

### A. Репозиторий `naprolom-docs` (продукт)

Исходники Runtime. Здесь каталоги в корне — **нормально** (это разработка продукта):

```
naprolom-docs/
├── README.md  INSTALL.md
├── playbook/  engine/  bootstrap/  agents/  knowledge/  sops/  docs/  .github/
```

Внутри `docs/` лежит собственный dogfood (audits, specs, ADRs собсuanного проекта).

### B. Consumer-репозиторий (пользователь Runtime)

Вы подключаете Runtime как **Git Submodule внутрь `docs/`**. В корне consumer-репо остаётся только `docs/`. Никаких `agents/`, `knowledge/`, `sops/`, `engine/`, `bootstrap/`, `playbook/` в корне — всё локализовано под `docs/.runtime/naprolom-docs/`:

```
consumer-project/
├── README.md, package.json, src/, tests/ ...   ← обычный код проекта как обычно
├── CLAUDE.md                                    ← генерируется bootstrap'ом (snippet ссылается на docs/.runtime/...)
└── docs/                                        ← ЕДИНСТВЕННЫЙ корневой каталог документации
    ├── architecture/  adr/  specs/  audits/  backlog/  api/   ← ваше содержимое (user-owned)
    └── .runtime/                                              ← System-owned (управляется `git submodule update --remote`)
        └── naprolom-docs/                                     ← submodule mount point (D-BR)
            ├── engine/  bootstrap/  agents/  knowledge/  sops/  playbook/  INSTALL.md  README.md
            └── ...
```

Инварианта: **в корне consumer-репо — только `docs/`**. Это ментальная модель пользователя: «всё, что связано с документацией проекта — в `docs/`».

---

## Что вы получаете

Подключив `naprolom-docs` как Git Submodule, ваш проект получает:

- **Canonical Schema v1** — единый frontmatter-формат для всех `.md` в `docs/`.
- **5-слойную архитектуру** документации (architecture → ADR → spec → audit → runbook).
- **Lifecycle из path** для spec/api — статус документа определяется папкой, а не editable-полем.
- **CI guard** — ни один `.md` без canonical frontmatter не попадёт в репозиторий.
- **Bootstrap** — одна команда создаёт skeleton `docs/` + `.context/` + `CLAUDE.md` snippet.
- **Migration script** — для brownfield-репозиториев миграция legacy frontmatter в Schema v1.
- **Validators** — `validate-frontmatter.sh` для local + CI проверки (поддерживает `ROOT=` override для выборочной валидации `docs/` или `knowledge/`).
- **Templates** — canonical шаблоны всех типов документов (6 файлов в `engine/templates/`).
- **Schema** — `frontmatter.schema.json` (JSON Schema для IDE/агентов).
- **Agent roles** — готовые конфиги ролей в `agents/{claude-code,opencode}/`: `architecture-reviewer`, `documentation-reviewer`, `reality-auditor` (NEW v1.1), `adversary-checker` (NEW v1.1). Кладёте в `.claude/agents/` или `.opencode/agents/` (по желанию, опционально).
- **Knowledge layer** (NEW v1.1) — `knowledge/` с общими принципами (architecture-principles, evidence-model, audit-principles, report-formats, capabilities). Роли подключают по short-id.
- **SOPs** — 9 декларативных YAML-описаний типовых процессов (`new-feature`, `bugfix`, `new-service`, `architecture-change`, `audit`, `release`, `incident`, `architecture-review` NEW v1.1, `forensic-audit` NEW v1.1). Планировщик `sops/planner.mjs` печатает DAG шагов с ролями и **artifact contracts** (consumes/produces).

---

## Шаг 1 — Подключение submodule

Из корня вашего проекта:

```bash
# v1.1: монтируем ВНУТРЬ docs/, а не в .context/runtime/
mkdir -p docs/.runtime

git submodule add \
    https://github.com/akturt/naprolom-docs.git \
    docs/.runtime/naprolom-docs

# Закрепить ветку master в .gitmodules (чтобы `--remote` тянул master, а не detached HEAD)
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master

git commit -m "chore: add Documentation System Runtime via submodule"
```

После этого `.gitmodules` содержит:

```ini
[submodule "docs/.runtime/naprolom-docs"]
    path = docs/.runtime/naprolom-docs
    url = https://github.com/akturt/naprolom-docs.git
    branch = master
```

### Миграция с v1.0 (если ранее подключили в `.context/runtime/`)

```bash
git mv .context/runtime docs/.runtime
git submodule absorbgitdirs
# затем обновить пути в .github/workflows/docs-validate.yml, CLAUDE.md, .context/agent-entry.md
# (новый bootstrap при повторном запуске сделает это идемпотентно)
```

Bootstrap v1.1 advisory-warn'ет, если в `.gitmodules` найдёт старый путь `.context/runtime/`.

---

## Шаг 2 — Клонирование с подмодулями (для остальных участников)

```bash
# Новый клон — сразу с подмодулями
git clone --recurse-submodules <your-repo-url>

# Существующий клон — инициализация submodule
git submodule update --init --recursive
```

---

## Шаг 3 — Запуск bootstrap (один раз)

Bootstrap создаёт skeleton `docs/`, `.context/` stubs и `CLAUDE.md` snippet в вашем проекте. Идемпотентен — можно запускать повторно.

```bash
# Linux / macOS / WSL
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh

# Windows (PowerShell)
powershell -File docs\.runtime\naprolom-docs\bootstrap\bootstrap.ps1
```

Что создаст bootstrap:
- `docs/{architecture,adr,specs/{drafts,review,approved,implemented,superseded},audits,backlog,api}/` — 5-слойная структура.
- `.context/{project.yml,boundaries.yml,agent-entry.md}` — stubs для AI-агента (заполните под ваш проект).
- `CLAUDE.md` (или `AGENTS.md`) — snippet с 8 правилами Documentation Runtime (см. ниже).
- `.github/workflows/docs-validate.yml` — CI guard для `docs/` + второго шага для `knowledge/`.

Если `docs/` уже существует, bootstrap НЕ перезаписывает существующие файлы — только создаёт недостающие. `.gitkeep` для пустых директорий.

Bootstrap v1.1 также **advisory-check'ает** ваш `.gitmodules`: если он указывает на устаревший v1.0 path `.context/runtime/naprolom-docs` — выдаёт warning с инструкцией миграции, но не блокирует исполнения.

---

## Шаг 4 — CLAUDE.md snippet

Bootstrap автоматически добавляет в `CLAUDE.md` (или создаёт его) этот блок:

```markdown
## Documentation Runtime

Documentation System Runtime is connected as a Git Submodule:

    docs/.runtime/naprolom-docs/

Before any change to `docs/`:
1. Study `playbook/playbook-v2.md` (target model)
2. Use `engine/templates/` — do NOT copy templates into the project
3. Follow `engine/schemas/frontmatter.schema.json`
4. Run `engine/validators/validate-frontmatter.sh` before commit
5. For brownfield migration, follow `playbook/migrate-legacy.md`
6. For typical processes, pick a SOP in `sops/` and run `sops/planner.mjs <name>` — call roles by name
7. If task involves architectural review — see `sops/architecture-review.yaml`; foundation is `reality-auditor` BEFORE `architecture-reviewer`.
8. Common knowledge bases live in `knowledge/` (`architecture-principles`, `evidence-model`, `audit-principles`, `report-formats`, `capabilities`) — roles reference them by short-id, not inline.
```

Если у вас уже есть `CLAUDE.md` с другим содержимым — snippet аппендится в конец. Проверьте, что секция `## Documentation Runtime` не дублируется (bootstrap идемпотентен на этот счёт).

Альтернативные entry-файлы: `AGENTS.md` (opencode convention) или `.opencode/config` — snippet одинаковый, подставьте свой filename.

---

## Шаг 5 — Заполнить `.context/project.yml`

Bootstrap создаёт stub. Замените placeholders на реалии вашего проекта:

```yaml
project:
  name: my-project
  description: "One-sentence: что это за проект"
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

Эта информация — Layer 0 для AI-агента. Без неё агент не понимает, в каком проекте он работает.

---

## Шаг 6 — Заполнить `.context/boundaries.yml`

Bootstrap v1.1 создаёт stub с `docs/.runtime/` как `pristine` и `docs/` (остальное) — `editable`. Расширьте под ваш проект:

```yaml
boundaries:
  pristine:
    - path: vendor/
      reason: "third-party, tracked upstream"
    - path: docs/.runtime/
      reason: "Documentation System Runtime submodule (managed by git submodule update --remote), NEVER edit in-place"

  editable:
    - path: app/
      reason: "core application code"
    - path: docs/
      reason: "all user-authored documentation (architecture, adr, specs, audits, backlog, api)"
    - path: infra/
      reason: "infrastructure config"

  generated:
    - path: .env
      source: .env.example
      reason: "created by bootstrap from template"

  secret:
    - path: .env
      note: "passwords and tokens"
    - path: "*.key"
      note: "private keys"
```

**Критично:** путь `docs/.runtime/naprolom-docs/` обязан быть `pristine`. Это submodule — никогда не редактируйте его содержимое in-place, только обновляйте submodule целиком (Шаг 7).

---

## Шаг 7 — Создать первый документ

Скопируйте template из Runtime в ваш `docs/`:

```bash
# ADR (Architecture Decision Record)
cp docs/.runtime/naprolom-docs/engine/templates/adr.md docs/adr/001-orchestrator-choice.md
# Отредактируйте frontmatter (id, status, date, owners) и body

# Spec (использует lifecycle из path)
cp docs/.runtime/naprolom-docs/engine/templates/spec.md docs/specs/drafts/$(date +%Y-%m-%d)-new-api.md
# status: draft → обязательно совпадает с директорией drafts/

# Architecture
cp docs/.runtime/naprolom-docs/engine/templates/architecture.md docs/architecture/README.md

# Audit
cp docs/.runtime/naprolom-docs/engine/templates/audit.md docs/audits/$(date +%Y-%m-%d)-initial.md
```

Подробно о создании и lifecycle документов — в [`playbook/playbook-v2.md`](playbook/playbook-v2.md) (но учтите, что playbook упоминает пути вида `docs/.runtime/naprolom-docs/...` — это v1.1 form, после D-BR; старые paths `.context/runtime/...` в playbook уже обновлены).

---

## Локальная валидация перед коммитом

Перед коммитом `.md`-файлов в `docs/`:

```bash
# Строгая проверка (как в CI)
bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh

# Warn-only (если brownfield, но strict-период ещё не наступил)
WARN_ONLY=true bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh

# v1.1: валидация knowledge/ (если используете кастомный knowledge)
ROOT=knowledge bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh knowledge
```

CI (`docs-validate.yml`) делает то же самое автоматически — но локально быстрее Feedback loop.

---

## Обновление Runtime

### Вариант A — вручную (рекомендуется на первых порах)

```bash
# Подтянуть последние изменения из master naprolom-docs
git submodule update --remote --merge

# Зафиксировать новый SHA в вашем репо
git add docs/.runtime/naprolom-docs
git commit -m "chore: update Documentation System Runtime"
```

Пять секунд. По умолчанию подтягивается ветка `master` (см. `branch = master` в `.gitmodules`).

### Вариант B — Dependabot gitsubmodule (авто-PR)

GitHub умеет отслеживать обновления Git Submodules и создавать PR автоматически:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "gitsubmodule"
    directory: "/"
    schedule:
      interval: weekly
    commit-message:
      prefix: "chore"
```

Dependabot создаёт PR с новым SHA сабмодуля при каждом изменении `naprolom-docs/master`. Вы review'ите и merge'ите — никакой автоматики в master без вашего подтверждения.

### Откат

```bash
# К конкретному SHA naprolom-docs
cd docs/.runtime/naprolom-docs
git checkout <commit-sha>
cd ../..
git add docs/.runtime/naprolom-docs
git commit -m "chore: pin Documentation Runtime to <commit-sha>"
```

Конкретный SHA = воспроизводимость. Откат тривиален.

---

## Brownfield — у вас уже есть `docs/` с `.md`-файлами

Если в репозитории уже есть документация: не запускайте bootstrap (он не перезапишет существующие файлы, но и не мигрирует их). Вместо bootstrap следуйте [`playbook/migrate-legacy.md`](playbook/migrate-legacy.md) — там пошаговый агент-промпт для brownfield миграции.

Кратко: запустите `engine/scripts/migrate-legacy.mjs`, затем включите `WARN_ONLY=true` на несколько дней, вычистите забытые `docs/archive/`, переключите на strict.

---

## Чего НЕ делать

| ❌ Не делайте | ✅ Что вместо этого |
|---------------|----------------------|
| Копировать templates в `docs/` и хранить дубли в репо | Используйте templates как source of truth: `cp docs/.runtime/naprolom-docs/engine/templates/<type>.md docs/<type>/...` единожды |
| Редактировать файлы в `docs/.runtime/naprolom-docs/` in-place | Обновляйте submodule целиком, не трогайте содержимое |
| Изменять `WARN_ONLY=true` на `false` до cleanup в brownfield | Следуйте `[playbook/migrate-legacy.md:Step 5-7]` — warn-only → strict по чеклисту |
| Зафиксировать submodule по detached HEAD без записи в `.gitmodules` | Всегда `branch = master` в `.gitmodules`, чтобы `--remote` работал |
| Создавать `.md` без `cp docs/.runtime/naprolom-docs/engine/templates/...` | Canonical frontmatter нельзя написать «из головы» — начни с template, заполни 6 полей |
| Использовать legacy-поля (`author`, `title`, `created`, `lifecycle`, `referenced_by`, `supersedes_adr`, `excludes-from-scope`) | Заменить: `author`→`owners`, `title`→body H1, `created`→`date`, `lifecycle`→computed from path |
| Монтировать submodule в `.context/runtime/` (v1.0 path) | v1.1: используйте `docs/.runtime/naprolom-docs/` (D-BR). При миграции — `git mv .context/runtime docs/.runtime && git submodule absorbgitdirs` |

---

## SOP — Standard Operating Procedures (если используете процессы)

Если вы хотите следовать типовым процессам развития (New Feature / Bugfix / Release / Incident), Runtime содержит декларативные описания в `sops/*.yaml`. Каждая SOP — это YAML, описывающий шаги в виде DAG с референсами на роли из `agents/` или `gate: manual` (human step; v1.1 — НЕ `role: human`, см. D-HG).

```bash
# Список доступных SOP
node docs/.runtime/naprolom-docs/sops/planner.mjs

# План выполнения для new-feature (показывает параллельные группы, роли и artifacts)
node docs/.runtime/naprolom-docs/sops/planner.mjs new-feature --platform claude-code

# Только роли AI-агентов (без manual human steps)
node docs/.runtime/naprolom-docs/sops/planner.mjs new-feature --hide-human
```

SOP — это чек-лист, не оркестратор. planner.mjs — DAG-printer (не executor; D-P). Вы читаете план, вручную вызываете роли через slash commands в агентах (например, `/architecture-reviewer` в Claude Code или `@architecture-reviewer` в opencode), выполняете manual-шаги сами. Никакого runtime scheduler.

### v1.1: Artifact contracts

SOP v1.1 использует явные `consumes:` и `produces:` поля — контроль data-flow между шагами DAG (не просто control-flow через `depends_on:`). Канонические artifact-имена: `reality-report`, `architecture-findings`, `documentation-report`, `validated-findings`, `forensic-report`. См. `knowledge/report-formats.md` и `sops/architecture-review.yaml` / `sops/forensic-audit.yaml`.

Кастомные SOP для специфичных процессов вашего проекта — кладите в `.context/sops/` вашего репозитория (вне submodule), Runtime их не переопределяет.

---

## Troubleshooting

### `git submodule update --remote` ничего не тянет

Проверьте, что в `.gitmodules` есть строка `branch = master`. Если её нет — добавьте:

```bash
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
```

### Bootstrap v1.1 warning о v1.0 path

Если увидели:
```
⚠ WARNING: .gitmodules references legacy v1.0 path '.context/runtime/naprolom-docs'.
  v1.1 expects submodule mounted at 'docs/.runtime/naprolom-docs'.
  To migrate: git mv .context/runtime docs/.runtime && git submodule absorbgitdirs
```

Это advisory warning (bootstrap продолжился). Чтобы переключиться на v1.1 layout — выполните указанную команду, затем update путей в `.github/workflows/docs-validate.yml`, `CLAUDE.md`, `.context/agent-entry.md`.

### CI падает на legacy полях в прозе/код-блоке

CI guard проверяет **только frontmatter**, не весь файл. Упоминания `lifecycle:` в таблице или `title:` в примере кода не должны ломать CI. Если ломается — проверьте, что у вас актуальная версия Runtime (`git submodule update --remote`).

### `WARN_ONLY=true` в CI не работает

Переменная должна быть установлена в `env:` секции job, не в `steps:`. Проверьте `.github/workflows/docs-validate.yml`:

```yaml
jobs:
  schema-v1:
    runs-on: ubuntu-latest
    env:
      WARN_ONLY: "true"   # ← вот тут, не в steps
```

### Bootstrap перезаписал мой `CLAUDE.md`

Нет. Bootstrap проверяет наличие секции `## Documentation Runtime` и аппендит только если её нет. Откатите через `git checkout CLAUDE.md` и добавьте snippet вручную при необходимости.

### Хочу разные entry-файлы для разных AI-платформ

Bootstrap создаёт `CLAUDE.md`. Для opencode symlink или скопируйте в `AGENTS.md`. Содержимое snippet идентично. Подробности про роли — в `agents/README.md`.

---

## Что НЕ вошло в Runtime v1.1 (запланировано на v1.2+)

- **`runtime/` wrapper** внутри самого naprolom-docs (продукт-only polish — не влияет на consumer).
- Группировка `knowledge/` по домену (`knowledge/architecture/`, `knowledge/documentation/`, ...).
- Knowledge loading из SOP, не из Role (`knowledge_refs:` на уровне шага).
- Capability-only SOP шаги (option 3 в `sops/planner.mjs` — пока planner warning'ает; v1.2 резолв capability→role автоматически).
- SOP `forensic-audit.yaml` фазы (Control Objects, Signal Inventory и т.д.) вынести в `knowledge/forensic-audit-protocol.md`.
- Slash-command bindings для ролей в CI.
- `examples/{fastapi,golang,terraform,ansible}/` — готовые стек-специфичные примеры.
- `validate-links.sh`, `normalize-frontmatter.mjs`, `repository_dispatch`.

См. README → Status и changelog. Полный v1.2 roadmap — в `docs/specs/approved/2026-07-08-agentic-layer.md` §Out-of-scope follow-up.
