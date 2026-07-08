---
schema: 1
id: install-runtime
type: guide
kind: onboarding
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter]
touches: [docs, .context, .gitmodules, CLAUDE.md, .github/workflows]
docs: [playbook/playbook-v2.md, playbook/migrate-legacy.md]
refs: []
depends_on: []
tags: [install, submodule, consumer, onboarding]
priority: P0
---

# INSTALL — Подключение Documentation System Runtime

> Этот документ открывает **пользователь naprolom-docs после `git submodule add`**.
> Остальное (`playbook/`, `engine/templates/`, `engine/validators/`, `engine/schemas/`, `engine/scripts/`, `bootstrap/`) — содержимое Runtime, оно подъезжает автоматически вместе с submodule.

---

## Что вы получаете

Подключив `naprolom-docs` как Git Submodule, ваш проект получает:

- **Canonical Schema v1** — единый frontmatter-формат для всех `.md` в `docs/`.
- **5-слойную архитектуру** документации (architecture → ADR → spec → audit → runbook).
- **Lifecycle из path** для spec/api — статус документа определяется папкой, а не editable-полем.
- **CI guard** — ни один `.md` без canonical frontmatter не попадёт в репозиторий.
- **Bootstrap** — одна команда создаёт skeleton `docs/` + `.context/` + `CLAUDE.md` snippet.
- **Migration script** — для brownfield-репозиториев миграция legacy frontmatter в Schema v1.
- **Validators** — `validate-frontmatter.sh` для local + CI проверки.
- **Templates** — canonical шаблоны всех типов документов.
- **Schema** — `frontmatter.schema.json` (JSON Schema для IDE/агентов).
- **Agent roles** — готовые конфиги ролей (`architecture-reviewer`, `documentation-reviewer`) для Claude Code и opencode. Кладёте в `.claude/agents/` или `.opencode/agents/` — активируете через slash commands.
- **SOPs** — 7 декларативных YAML-описаний типовых процессов (`new-feature`, `bugfix`, `new-service`, `architecture-change`, `audit`, `release`, `incident`). Планировщик `sops/planner.mjs` печатает DAG шагов с ролями.

---

## Архитектура подключения

```
ваш-проект/
│
├── docs/                          ← ваша документация (Canonical Schema v1)
├── src/                           ← ваш код
├── .context/
│   ├── CLAUDE.md                  ← AI-агент entry (snippet ниже)
│   ├── context.md                 ← ваш контекст
│   └── runtime/
│       └── naprolom-docs/         ← Git Submodule (Documentation Runtime)
│           ├── README.md          ← landing page
│           ├── INSTALL.md         ← этот документ
│           ├── playbook/          ← целевая модель + brownfield-промпт
│           ├── engine/            ← Documentation Engine (validators, templates, schemas, scripts)
│           ├── bootstrap/         ← создание структуры в вашем проекте
│           ├── agents/            ← роли AI-агентов для claude-code и opencode
│           ├── sops/              ← Standard Operating Procedures (YAML) + planner
│           └── docs/              ← dogfood: собственная документация Runtime
└── .gitmodules                    ← конфиг submodule
```

`.context/runtime/` — Layer 0 для AI-агентов. Внутри может жить сколько угодно runtime-компонентов: позже сюда добавятся `opencode-agents/`, `company-policy/`, и т.д.

---

## Шаг 1 — Подключение submodule

Из корня вашего проекта:

```bash
mkdir -p .context/runtime

git submodule add \
    https://github.com/akturt/naprolom-docs.git \
    .context/runtime/naprolom-docs

# Закрепить ветку master в .gitmodules (чтобы `--remote` тянул master, а не detached HEAD)
git config -f .gitmodules submodule.".context/runtime/naprolom-docs".branch master

git commit -m "chore: add Documentation System Runtime via submodule"
```

После этого `.gitmodules` содержит:

```ini
[submodule ".context/runtime/naprolom-docs"]
    path = .context/runtime/naprolom-docs
    url = https://github.com/akturt/naprolom-docs.git
    branch = master
```

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
bash .context/runtime/naprolom-docs/bootstrap/bootstrap.sh

# Windows (PowerShell)
powershell -File .context\runtime\naprolom-docs\bootstrap\bootstrap.ps1
```

Что создаст bootstrap:
- `docs/{architecture,adr,specs/{drafts,review,approved,implemented,superseded},audits,backlog,api}/` — 5-слойная структура.
- `.context/{project.yml,boundaries.yml,agent-entry.md}` — stubs для AI-агента (заполните под ваш проект).
- `CLAUDE.md` (или `AGENTS.md`) — snippet с 5 правилами Documentation Runtime (см. ниже).
- `.github/workflows/docs-validate.yml` — CI guard, вызывающий `engine/validators/validate-frontmatter.sh` из submodule.

Если `docs/` уже существует, bootstrap НЕ перезаписывает существующие файлы — только создаёт недостающие. `.gitkeep` для пустых директорий.

---

## Шаг 4 — CLAUDE.md snippet

Bootstrap автоматически добавляет в `CLAUDE.md` (или создаёт его) этот блок:

```markdown
## Documentation Runtime

Documentation System Runtime is connected as a Git Submodule:

    .context/runtime/naprolom-docs/

Before any change to `docs/`:
1. Study `playbook/playbook-v2.md` (target model)
2. Use `engine/templates/` — do NOT copy templates into the project
3. Follow `engine/schemas/frontmatter.schema.json`
4. Run `engine/validators/validate-frontmatter.sh` before commit
5. For brownfield migration, follow `playbook/migrate-legacy.md`
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

Bootstrap создаёт stub с `docs/` как `editable`. Расширьте под ваш проект:

```yaml
boundaries:
  pristine:
    - path: vendor/
      reason: "third-party, tracked upstream"
    - path: .context/runtime/naprolom-docs/
      reason: "submodule, NEVER edit in-place"

  editable:
    - path: app/
      reason: "core application code"
    - path: docs/
      reason: "all documentation"
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

**Критично:** путь `.context/runtime/naprolom-docs/` обязан быть `pristine`. Это submodule — никогда не редактируйте его содержимое in-place, только обновляйте submodule целиком (Шаг 7).

---

## Шаг 7 — Создать первый документ

Скопируйте template из Runtime в ваш `docs/`:

```bash
# ADR (Architecture Decision Record)
cp .context/runtime/naprolom-docs/engine/templates/adr.md docs/adr/001-orchestrator-choice.md
# Отредактируйте frontmatter (id, status, date, owners) и body

# Spec (использует lifecycle из path)
cp .context/runtime/naprolom-docs/engine/templates/spec.md docs/specs/drafts/$(date +%Y-%m-%d)-new-api.md
# status: draft → обязательно совпадает с директорией drafts/

# Architecture
cp .context/runtime/naprolom-docs/engine/templates/architecture.md docs/architecture/README.md

# Audit
cp .context/runtime/naprolom-docs/engine/templates/audit.md docs/audits/$(date +%Y-%m-%d)-initial.md
```

Подробно о создании и lifecycle документов — в [`playbook/playbook-v2.md`](playbook/playbook-v2.md).

---

## Локальная валидация перед коммитом

Перед коммитом `.md`-файлов в `docs/`:

```bash
# Строгая проверка (как в CI)
bash .context/runtime/naprolom-docs/engine/validators/validate-frontmatter.sh

# Warn-only (если brownfield, но strict-период ещё не наступил)
WARN_ONLY=true bash .context/runtime/naprolom-docs/engine/validators/validate-frontmatter.sh
```

CI (`docs-validate.yml`) делает то же самое автоматически — но локально быстрее Feedback loop.

---

## Обновление Runtime

### Вариант A — вручную (рекомендуется на первых порах)

```bash
# Подтянуть последние изменения из master naprolom-docs
git submodule update --remote --merge

# Зафиксировать новый SHA в вашем репо
git add .context/runtime/naprolom-docs
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

### Вариант C — GitHub Actions nightly (опционально)

Workflow в вашем репо: каждую ночь проверяет новый commit в naprolom-docs, создаёт PR если есть обновление. Подробности — в будущих версиях Runtime; сейчас используйте Variант A или B.

### Откат

```bash
# К конкретному SHA naprolom-docs
cd .context/runtime/naprolom-docs
git checkout <commit-sha>
cd ../..
git add .context/runtime/naprolom-docs
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
| Копировать templates в `docs/` и хранить дубли в репо | Используйте templates как source of truth: `cp <runtime>/engine/templates/<type>.md docs/<type>/...` единожды |
| Редактировать файлы в `.context/runtime/naprolom-docs/` in-place | Обновляйте submodule целиком, не трогайте содержимое |
| Изменять `WARN_ONLY=true` на `false` до cleanup в brownfield | Следуйте `[playbook/migrate-legacy.md:Step 5-7]` — warn-only → strict по чеклисту |
| Зафиксировать submodule по detached HEAD без записи в `.gitmodules` | Всегда `branch = master` в `.gitmodules`, чтобы `--remote` работал |
| Создавать `.md` без `cp engine/templates/...` | Canonical frontmatter нельзя написать «из головы» — начни с template, заполни 6 полей |
| Использовать legacy-поля (`author`, `title`, `created`, `lifecycle`, `referenced_by`, `supersedes_adr`, `excludes-from-scope`) | Заменить: `author`→`owners`, `title`→body H1, `created`→`date`, `lifecycle`→computed from path |

---

## Что не вошло в Runtime v1.0 (запланировано на v1.1+)

- `examples/{fastapi,golang,terraform,ansible}/` — готовые стек-специфичные примеры.
- `prompts/` — каталог AI-промптов (текущие роли живут в `agents/`).
- `validate-links.sh` — проверка мёртвых ссылок между документами.
- `normalize-frontmatter.mjs` — авто-нормализация (сортировка ключей, mandatory заполнение).
- `repository_dispatch` — централизованная рассылка обновлений в зависимые репо.
- Полный набор ролей в `agents/` — сейчас только `architecture-reviewer` и `documentation-reviewer` для `claude-code` и `opencode`.
- `sops/` slash-command bindings — пока запуск ролей по SOP ручной. CI step bindings и slash-commands — Tier 2 после dogfooding.

См. README → Status и changelog.

---

## SOP — Standard Operating Procedures (если используете процессы)

Если вы хотите следовать типовым процессам развития (New Feature / Bugfix / Release / Incident), Runtime содержит декларативные описания в `sops/*.yaml`. Каждая SOP — это YAML, описывающий шаги в виде DAG с референсами на роли из `agents/` или `human` (manual).

```bash
# Список доступных SOP
node .context/runtime/naprolom-docs/sops/planner.mjs

# План выполнения для new-feature (показывает параллельные группы и роли)
node .context/runtime/naprolom-docs/sops/planner.mjs new-feature --platform claude-code

# Только роли AI-агентов (без manual human steps) — чтобы понять, кого вызвать через slash command
node .context/runtime/naprolom-docs/sops/planner.mjs new-feature --hide-human
```

SOP — это чек-лист, не оркестратор. Вы читаете план, вручную вызываете роли через slash commands в агентах (например, `/architecture-reviewer` в Claude Code или `@architecture-reviewer` в opencode), выполняете manual-шаги сами. Никакого runtime scheduler.

Кастомные SOP для специфичных процессов вашего проекта — кладите в `.context/sops/` вашего репозитория (вне submodule), Runtime их не переопределяет.

---

## Troubleshooting

### `git submodule update --remote` ничего не тянет

Проверьте, что в `.gitmodules` есть строка `branch = master`. Если её нет — добавьте:

```bash
git config -f .gitmodules submodule.".context/runtime/naprolom-docs".branch master
```

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

Нет. Bootstrap проверяет наличие секции `## Documentation Runtime` и аппендит только если её нет. Если у вас奇特ый кейс — откатите через `git checkout CLAUDE.md` и добавьте snippet вручную.

### Хочу разные entry-файлы для разных AI-платформ

Bootstrap создаёт `CLAUDE.md`. Для opencode symlink или скопируйте в `AGENTS.md`. Содержимое snippet идентично. Подробности про роли — в `agents/README.md`.
