---
schema: 1
id: install-remote-prompt
type: guide
kind: onboarding
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter]
touches: [docs, .context, .gitmodules, CLAUDE.md, .github/workflows]
docs: [../INSTALL.md, playbook-v2.md, migrate-legacy.md]
refs: []
depends_on: []
tags: [install, remote, agent-prompt, ubuntu]
priority: P0
---

# Универсальный промпт для удалённой установки naprolom-docs как Git Submodule

> **Self-contained prompt** для AI-агента на Linux-сервере (Ubuntu) на подключение naprolom-docs Runtime в существующий репозиторий проекта. Запусти этот промпт как есть.

---

## Роль агента

Ты — DevOps-агент, у которого есть доступ к git-репозиторию проекта на удалённом Linux-сервере. Твоя задача — подключить Documentation System Runtime `naprolom-docs` как Git Submodule и подготовить структуру проекта к совместной работе с Documentation Schema v1.

Пиши на русском, докладывай на каждом checkpoint'е, не переходи к следующему без подтверждения (если этого требует конкретный шаг). Команды bash копируй дословно, не «перефразируй».

## Входные условия

- На сервере установлен `git >= 2.20` и `node >= 18` (для `engine/scripts/migrate-legacy.mjs` и `sops/planner.mjs`).
- У тебя есть SSH-доступ к репозиторию проекта (через `git@github.com:akturt/<project>.git` или эквивалент) или HTTPS PAT ключом.
- Рабочая директория — корень клона проекта.

## Переменные проекта

| Переменная | Пример | Заменить на |
|---|---|---|
| `PROJECT_NAME` | `kordon` | Имя consumer-проекта (slug, lowercase) |
| `PROJECT_REPO_URL` | `git@github.com:akturt/kordon.git` | SSH или HTTPS URL репозитория |
| `PROJECT_REPOS_REMOTE` | `origin` | Стандартное имя remote (обычно `origin`) |
| `PROJECT_BRANCH` | `main` или `master` | Рабочая ветка, на которой делаем интеграцию |
| `AI_PLATFORM` | `opencode` или `claude-code` | Что установлено на сервере (если оба — `opencode` для Linux) |
| `TEAM_NAME` | `naprolom-team` | Кто будет owner документов в frontmatter |

## Контекст-урл (используй для инструкций внутри SOP и промптов)

Runtime submodule монтируется в `docs/.runtime/naprolom-docs/`. Все дальнейшие пути consumer-side относительные от него.

---

## Step 1 — Клон проекта (если ещё не склонирован на сервере)

```bash
cd ~                                          # или /opt / /srv — где должен жить проект
git clone <PROJECT_REPO_URL> <PROJECT_NAME>
cd <PROJECT_NAME>
git checkout <PROJECT_BRANCH>
git status                                     # убедись что ветка чистая, без uncommitted
```

**Checkpoint 1:** доклади:
- путь к клону
- текущую ветку
- наличие `docs/`, `.context/`, `CLAUDE.md`, `.github/workflows/` через `ls -la`

---

## Step 2 — Проверка brownfield vs greenfield

Система установки отличается в зависимости от того, есть ли уже `docs/` с `.md`:

```bash
ls docs/ 2>/dev/null && echo "DOCS_EXISTS" || echo "NO_DOCS"
find docs/ -name "*.md" 2>/dev/null | wc -l
```

**Правило:**
- `NO_DOCS` или `0 .md файлов` → **Greenfield path** → переходи к Step 3.
- Есть `.md` файлы в `docs/` → **Brownfield path** → переходи к Step 4.

Не делай переход дальше без подтверждения оператором, если count `.md` > 30 — там, скорее всего, legacy документация; нужна миграция.

---

## Step 3 — Greenfield path: подключить submodule

Только если в Step 2 — `NO_DOCS` (нет существующей документации).

```bash
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
git submodule update --init --recursive
ls -la docs/.runtime/naprolom-docs/        # должно показать содержимое Runtime
```

Bootstrap создаст skeleton + CLAUDE.md snippet + workflow:

```bash
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
```

**Что должно появиться:**
- `docs/{architecture,adr,specs/{drafts,review,approved,implemented,superseded},audits,backlog,api}/` — 5-слойная структура.
- `.context/{project.yml,boundaries.yml,agent-entry.md}` — stubs.
- `CLAUDE.md` — snippet из 6 строк про Documentation Runtime (приложен к существующему или создан).
- `.github/workflows/docs-validate.yml` — CI guard.

Переходи к Step 5.

---

## Step 4 — Brownfield path: подключить submodule без перезаписи

Только если в Step 2 — существующая `docs/` с `.md`.

### 4a — Подключить submodule

```bash
mkdir -p docs/.runtime
git submodule add https://github.com/akturt/naprolom-docs.git docs/.runtime/naprolom-docs
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
git submodule update --init --recursive
```

### 4b — Сгенерировать только .context/ stubs (НЕ трогать существующий docs/)

Bootstrap идемпотентен: он не перезаписывает существующие файлы. Но безопаснее — явно скопировать stubs отдельно, а потом — при необходимости отредактировать.

```bash
# Создаём .context/ без вызова bootstrap (чтобы не задеть существующие .github/workflows/docs-validate.yml)
mkdir -p .context

# Создаём stubs, не перезаписывая существующие
[ -f .context/project.yml ] || cat > .context/project.yml << 'YML'
project:
  name: <PROJECT_NAME>
  description: "TODO: 1-sentence project description"
  domain: example.com
  maintainer: <TEAM_NAME>
  repository: <PROJECT_REPO_URL>

stack:
  backend: []
  database: []
  infrastructure: []

directories:
  key: {}
YML

[ -f .context/boundaries.yml ] || cat > .context/boundaries.yml << 'YML'
boundaries:
  pristine:
    - path: docs/.runtime/naprolom-docs/
      reason: "submodule, NEVER edit in-place"
  editable:
    - path: docs/
      reason: "documentation"
  generated: []
  secret: []
YML

[ -f .context/agent-entry.md ] || cp docs/.runtime/naprolom-docs/bootstrap/.context-agent-entry-template 2>/dev/null || cat > .context/agent-entry.md << 'MD'
# Agent Entry Protocol

Read in order:
1. .context/project.yml - what project this is
2. .context/boundaries.yml - what is editable / pristine / secret
3. docs/architecture/README.md - topology, invariants (create if missing)
4. CLAUDE.md - rules

Before creating any .md in docs/:
1. Identify `type` (spec|adr|audit|runbook|guide|api|architecture|backlog|prompt)
2. Copy template from runtime: docs/.runtime/naprolom-docs/documentation/templates/<type>.md
3. Fill the 6 mandatory fields: schema, id, type, status, date, owners
4. Never add `lifecycle:` to frontmatter (computed from path for specs/api)
5. Never add legacy fields: author, title, created, referenced_by, supersedes_adr, excludes-from-scope
MD
```

### 4c — Проверить состояние legacy frontmatter (без записи)

```bash
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --dry-run --owner <TEAM_NAME> 2>&1 | head -40
```

Сохраняй вывод для отчёта оператору: сколько `.md` было бы изменено, сколько с `TODO_ENTITY_REF` (требуют manual review).

### 4d — Запустить миграцию (только если оператор подтвердил)

**Не запускай без явного подтверждения.** Миграция перезаписывает все `.md` в `docs/` canonical Schema v1.

```bash
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --owner <TEAM_NAME>
```

**Exit codes:**
- `0` — миграция прошла чисто.
- `1` — есть `TODO_ENTITY_REF` marкеры. Не блокирующе, но требует manual review.
- `2` — `docs/` root не найден (что-то не так).

### 4e — Установить CI guard в warn-only режиме (период миграции)

```bash
mkdir -p .github/workflows
[ -f .github/workflows/docs-validate.yml ] || cat > .github/workflows/docs-validate.yml << 'YML'
name: docs-validate
on:
  pull_request:
    paths: ["docs/**"]
jobs:
  schema-v1:
    runs-on: ubuntu-latest
    env:
      WARN_ONLY: "true"   # brownfield rollout: WARNING вместо FAIL
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
      - name: Validate Canonical Schema v1 frontmatter
        run: |
          bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh
YML
```

**Checkpoint 4:** доложи:
- сколько файлов мигрировало
- сколько `TODO_ENTITY_REF` маркеров осталось
- что warn-only CI конфигурация создана

---

## Step 5 — Заполнить project.yml и boundaries.yml под проект

Отредактируй `.context/project.yml` вручную или через heredoc, подставив реальный стек проекта:

```bash
cat > .context/project.yml << 'YML'
project:
  name: <PROJECT_NAME>
  description: "<читай README проекта, запиши 1 предложение>"
  domain: example.com
  maintainer: <TEAM_NAME>
  repository: <PROJECT_REPO_URL>

stack:
  backend: [<читай package.json / requirements.txt / go.mod - запиши языки и фреймворки>]
  database: [<читай конфиги миграций / docker-compose / .env.example>]
  infrastructure: [<Docker Compose / Kubernetes / Terraform / Ansible>]

directories:
  key:
    src/: "Основной код"
    docs/: "Документация"
    infra/: "Инфраструктура"
YML
```

Расширь `.context/boundaries.yml` под реальную структуру проекта:

```bash
# Найди директории с кодом, конфигами, секретами
ls -la
find . -maxdepth 2 -type d -not -path "./.git*" -not -path "./node_modules*"
```

Заполни в `.context/boundaries.yml`:
- `pristine` — то, что НЕ трогать (vendor/, third-party, docs/.runtime/naprolom-docs/).
- `editable` — где можно менять (src/, docs/, infra/).
- `generated` — то, что создают скрипты.
- `secret` — файлы с секретами (.env, *.key, *.pem).

---

## Step 6 — CLAUDE.md snippet (для AI-агента)

Если `CLAUDE.md` уже есть — проверь наличие секции «## Documentation Runtime»:

```bash
if [ -f CLAUDE.md ]; then
  grep -q "## Documentation Runtime" CLAUDE.md && echo "SNIPPET_EXISTS" || echo "NEED_APPEND"
else
  echo "NEED_CREATE"
fi
```

Для `NEED_APPEND` или `NEED_CREATE` — вызови bootstrap (он идемпотентен, не перезапишет) или скопируй snippet вручную:

```bash
bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh
```

Если залоговые создаются — `agent-entry.md` перезапишется только если он не существует (проверь через `bootstrap.sh` идемпотентность).

**Альтернатива для других AI entry-files:**

Для opencode создай symlink или копию:
```bash
[ -f AGENTS.md ] || ln -s CLAUDE.md AGENTS.md 2>/dev/null || cp CLAUDE.md AGENTS.md
```

---

## Step 7 — Скопировать роли агентов под платформу сервера

Игнорируй если `<AI_PLATFORM>` не указан — пропусти этот шаг.

### Для `opencode`

```bash
mkdir -p .opencode/agents
cp docs/.runtime/naprolom-docs/agents/opencode/*.md .opencode/agents/
ls -la .opencode/agents/
# должно показать: architecture-reviewer.md, documentation-reviewer.md
```

### Для `claude-code`

```bash
mkdir -p .claude/agents
cp docs/.runtime/naprolom-docs/agents/claude-code/*.md .claude/agents/
ls -la .claude/agents/
```

### Для обеих платформ одновременно

Просто скопируй оба набора. `CLAUDE.md` snippet остаётся общим — обе платформы читают его.

---

## Step 8 — Создать первый архитектурный документ (опционально, по указанию оператора)

```bash
PROJECT_NAME_KEBAB=$(echo "<PROJECT_NAME>" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
cp docs/.runtime/naprolom-docs/documentation/templates/adr.md docs/adr/001-bootstrap-documentation-runtime.md
# Отредактируй frontmatter (id, date, owners) и body (Context про подключение naprolom-docs, Decision про submodule+branch=master, Consequences)
$EDITOR docs/adr/001-bootstrap-documentation-runtime.md 2>/dev/null || true
```

Заполни в body минимально:
- **Context:** «Проект <PROJECT_NAME> не имеет формализованной документационной системы. Документация растёт хаотично, новых агентов и разработчиков сложно онбордингнуть.»
- **Decision:** «Принять naprolom-docs как Documentation System Runtime, подключенный как Git Submodule, пиненный за ветку master в .gitmodules.»
- **Consequences:** «Все .md в docs/ обязаны соответствовать Canonical Schema v1. CI guard следит. Процессы разработки следуют декларативным SOP из sops/.»
- **Status:** accepted

---

## Step 9 — Запустить validator перед коммитом

```bash
# strict mode (greenfield)
bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh

# warn-only (если brownfield и миграция ещё не завершена)
WARN_ONLY=true bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh
```

**Ожидаемый вывод:**
```
docs-validate: OK
```

Если есть ошибки (`ERROR: <file>: ...`) — не коммить; доложи оператору список файлов и что именно нарушено.

---

## Step 10 — Закоммитить и запушить

```bash
git add -A
git status --short
git commit -m "chore: add naprolom-docs Documentation System Runtime as git submodule

Stage <PROJECT_NAME> for Canonical Schema v1 documentation:

- Add submodule docs/.runtime/naprolom-docs pinned to master branch
- Add .context/ stubs (project.yml, boundaries.yml, agent-entry.md)
- Add .github/workflows/docs-validate.yml calling documentation/validation/validate-frontmatter.sh
- Add CLAUDE.md snippet (6 rules: playbook→templates→schema→validator→migrate→sops)
- <GREENFIELD: 'Bootstrap created docs/ skeleton (5-layer architecture)'>
- <BROWNFIELD: 'Existing docs/ preserved; CI guard in WARN_ONLY=true period'>
- <IF ROLES COPIED: 'Add <AI_PLATFORM> reviewer roles from agents/<platform>/'>
- <IF FIRST ADR: 'Add ADR-001 recording this runtime adoption decision'>"
git push <PROJECT_REPOS_REMOTE> <PROJECT_BRANCH>
```

---

## Step 11 — Финальный отчёт оператору

После пуша предоставь сводку:

```
## Подключение naprolom-docs Runtime to <PROJECT_NAME>

Repository: <PROJECT_REPO_URL>
Branch: <PROJECT_BRANCH>
Path: docs/.runtime/naprolom-docs/ (submodule pinned to master)
Mode: GREENFIELD | BROWNFIELD (warn-only period for ~3-7 days)
Commit SHA: <git rev-parse HEAD>
Submodule SHA: <git -C docs/.runtime/naprolom-docs rev-parse HEAD>

Files created/changed:
- .gitmodules (new submodule entry, branch=master)
- docs/.runtime/naprolom-docs/ (submodule)
- .context/project.yml
- .context/boundaries.yml
- .context/agent-entry.md
- CLAUDE.md (Documentation Runtime snippet)
- .github/workflows/docs-validate.yml
- <IF GREENFIELD: 'docs/ skeleton (5-layer architecture)'>
- <IF AI_PLATFORM: '.<platform>/agents/{architecture-reviewer,documentation-reviewer}.md'>
- <IF FIRST ADR: 'docs/adr/001-bootstrap-documentation-runtime.md'>

Validator result: docs-validate: OK (or WARN count: <N> if brownfield warn-only)
Next steps for operator:
  1. Review .context/project.yml — замени TODO на реальный стек
  2. Review .context/boundaries.yml — классифицируй файлы проекта
  3. First SOP run: node docs/.runtime/naprolom-docs/sops/planner.mjs --list
  4. <IF BROWNFIELD> outline cleanup: ~<N> docs with TODO_ENTITY_REF need manual entity_refs
  5. <IF BROWNFIELD> после cleanup переключить CI на strict: WARN_ONLY="" в .github/workflows/docs-validate.yml
```

---

## Edge Cases

### Git-version < 2.20

`git submodule add --branch master <url> docs/.runtime/naprolom-docs` — поддерживается, но если git старый, вручную добавь `branch = master` в `.gitmodules` после `add`.

### Node.js не установлен

Установи через `apt-get install -y nodejs` или через nvm (`curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash && nvm install --lts`). Без node — `engine/scripts/migrate-legacy.mjs` и `sops/planner.mjs` не работают. Validator (`validate-frontmatter.sh`) — работает (POSIX awk).

### Submodule не включается в clone у других участников

Подскажи им `git clone --recurse-submodules <url>` или `git submodule update --init --recursive` в существующем клоне. Это фикс на .gitmodules, не на твоей стороне.

### `git submodule update --remote` не тянет master

Проверь `.gitmodules` содержит:
```
[submodule "docs/.runtime/naprolom-docs"]
    path = docs/.runtime/naprolom-docs
    url = https://github.com/akturt/naprolom-docs.git
    branch = master
```

Если строки `branch = master` нет — добавь:
```bash
git config -f .gitmodules submodule."docs/.runtime/naprolom-docs".branch master
git add .gitmodules && git commit -m "chore: pin submodule to master branch"
```

### `WARN_ONLY=true` — workflow fail

`WARN_ONLY` должен быть в `env:` секции job, не в `steps:`. Проверь:
```yaml
jobs:
  schema-v1:
    runs-on: ubuntu-latest
    env:                              # ← вот тут, не в steps
      WARN_ONLY: "true"
```

### Что НЕ делать

- ❌ Не редактируй файлы в `docs/.runtime/naprolom-docs/` in-place. Это submodule.
- ❌ Не запускай bootstrap дважды на brownfield с существующим `.github/workflows/docs-validate.yml` — bootstrap создаёт только если файл отсутствует.
- ❌ Не включай strict CI (`WARN_ONLY=""`) сразу на brownfield. Сначала пройди полный cleanup забытых архивов, потом переключай.
- ❌ Не создавай `.md` в `docs/` без `cp docs/.runtime/naprolom-docs/documentation/templates/<type>.md docs/<type>/...` — canonical frontmatter сложно написать «из головы».

---

## После подключения — как оператор будет запускать работу

Подключённый consumer проект начинает использовать Runtime так:

```bash
# Список доступных SOP
node docs/.runtime/naprolom-docs/sops/planner.mjs --list

# План выполнения для new-feature (с указанием платформы)
node docs/.runtime/naprolom-docs/sops/planner.mjs new-feature --platform opencode

# Только то, что нужно вызвать агентов (без manual human steps)
node docs/.runtime/naprolom-docs/sops/planner.mjs new-feature --hide-human

# Создать новый документ из template
cp docs/.runtime/naprolom-docs/documentation/templates/adr.md docs/adr/002-<decision>.md

# Перед коммитом запустить validator
bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh
```

Запуск ролей ai-агентом (для opencode):
```
@architecture-reviewer проверь PR #123
@documentation-reviewer validate-PR #123
```

Запуск ролей в Claude Code:
```
/architecture-reviewer
/documentation-reviewer
```

---

## Финальный аккорд

Если что-то идёт не так — останавливайся и спрашивай оператора. Не додумывай. Лучше недоделать явно, чем доделать неправильно и оставить дрейф.