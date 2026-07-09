---
schema: 1
id: documentation-system-migration-legacy
type: guide
kind: legacy
status: active
date: 2026-07-07
updated: 2026-07-08
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter, lifecycle-spec]
touches: [docs, .github/workflows]
docs: [playbook-v2.md]
refs: []
depends_on: [documentation-system-playbook-v2]
tags: [documentation, adoption, brownfield, migration, agent-prompt]
priority: P1
---

# Migration Prompt: Brownfield Repository → Canonical Schema v1

> Agent-ready протокол миграции существующего репозитория (brownfield) в целевую модель Documentation System v2 (Canonical Schema v1).
> Целевая модель описана в [`playbook-v2.md`](playbook-v2.md) (Greenfield Playbook). Этот гайд не часть модели — это **способ попасть в неё**.
>
> **Когда использовать:** существующий репозиторий уже содержит `.md`-файлы (legacy frontmatter или отсутствие оного).
> **Когда НЕ использовать:** новый (greenfield) репозиторий — используйте `bootstrap/bootstrap.sh` прямо из `playbook-v2.md`.

---

## Роль агента

Этот документ — **готовый промпт** для AI-агента (Claude Code, opencode), которому поручена миграция документации существующего проекта в Canonical Schema v1. Агент выполняет шаги по порядку, докладывает на каждом checkpoint'е и не переходит к следующему шагу без подтверждения от оператора (или без явного флага `--auto`).

## Входные требования

- Submodule `naprolom-docs` уже подключён по адресу `docs/.runtime/naprolom-docs/` (см. `../../INSTALL.md`).
- В репозитории уже запущен `bootstrap/bootstrap.sh` (`.context/`, `docs/` skeleton, `CLAUDE.md` snippet созданы).
- Node.js 18+ доступен для `engine/scripts/migrate-legacy.mjs`.

## Стратегия rollout

```
Audit legacy → Run migration script → Manual review
            → Warn-only CI (несколько дней)
            → Manual cleanup забытых документов
            → Strict CI
```

Greenfield — strict с первого PR. Brownfield проходит через `Warn → Strict`. Никогда не включайте strict CI сразу на brownfield — забытые `docs/archive/`, `docs/old/`, `docs/wiki/` сломают все PR.

---

## Step 1 — Аудит legacy (1–2 часа)

**Цель:** понять объём миграции до её начала.

```bash
# Сколько .md-файлов в проекте (вне submodule)?
find docs/ -name "*.md" -not -path "*/docs/.runtime/*" | wc -l

# Какие фронматтеры уже есть?
grep -rE "^(schema:|author:|title:|created:|lifecycle:|type:|status:)" docs/ \
  | awk -F: '{print $3}' | sort | uniq -c

# Какие legacy-поля присутствуют в frontmatter (только FM, через awk)?
for f in $(find docs/ -name "*.md"); do
  awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$f" \
    | grep -E "^(author|title|created|lifecycle|referenced_by|supersedes_adr|excludes-from-scope):"
done

# Какие директории не попадают в 5-слойную модель?
find docs/ -type d -not -path "*/docs/.runtime/*" \
  | grep -E "archive|old|wiki|tmp|legacy|draft|misc" || true
```

**Checkpoint 1:** доложи оператору:
- Сколько всего `.md`.
- Какие типы frontmatter (canonical vs legacy vs none).
- Какие «забытые» директории присутствуют.
- Оценка времени миграции (1 файл ≈ 30 секунд в скрипте + 1–2 минуты manual review на 10–20% файлов).

**Не переходи к Step 2 без подтверждения оператора.**

---

## Step 2 — Приоритизация (5–10 минут)

Разбей все `.md`-файлы на 3 корзины:

| Корзина | Критерий | Действие |
|---------|---------|----------|
| **Active** | Используется сейчас, на него ссылаются из кода / docs / issues | Мигрировать в первую очередь |
| **Archive** | Старая версия, неактуальная, историческая | Оставить в `docs/archive/` **без** canonical FM, исключить из CI (warn-only период перехватит) |
| **Orphan** | Ни на что не ссылается, > 1 года без обновлений | Удалить или переместить в `docs/archive/` — решает оператор |

**Checkpoint 2:** предъяви оператору список файлов по корзинам. Удаляй только с явного подтверждения (`Orphan → delete`).

**Не переходи к Step 3 без подтверждения оператора.**

---

## Step 3 — Runnable migration (5–30 минут)

Запусти миграционный скрипт из Runtime:

```bash
# Dry-run: покажет что было бы изменено, без записи
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --dry-run

# Реальный прогон
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --owner <team-name>

# Тихий режим (только summary)
node docs/.runtime/naprolom-docs/engine/scripts/migrate-legacy.mjs --quiet --owner <team-name>
```

**Что делает скрипт:**
- Добавляет `schema: 1`, `id` (из filename), `type` (из path), `status` (из path / lifecycle), `date` (из `created` или filename), `owners` (из `author` или `--owner`).
- Ставит `updated: <today>` на всех изменённых файлах.
- Для `spec`/`audit`: если `entity_refs` пуст → ставит `TODO_ENTITY_REF` маркер для manual review.
- Удаляет legacy-поля: `author`, `title`, `created`, `lifecycle`, `referenced_by`, `supersedes_adr`, `excludes-from-scope`.
- Если legacy `title:` существовал → превращает его в `# <title>` в body (H1, как требует Schema v1).
- Идемпотентен. Повторный запуск на уже-canonical файлах — no-op.

**Exit codes:**
- `0` — все файлы мигрированы чисто.
- `1` — есть файлы с `TODO_ENTITY_REF` — нужен manual review (Step 4).
- `2` — `docs/` root не найден.

**Checkpoint 3:** после прогона доложи:
- Сколько файлов изменено.
- Сколько файлов с `TODO_ENTITY_REF` (перейдут в Step 4).
- Какие директории не тронуты (Archive).

**Не переходи к Step 4 без подтверждения оператора.**

---

## Step 4 — Manual review (10–20% файлов, ~30 минут на 50 файлов)

Скрипт помечает `TODO_ENTITY_REF` те `spec`/`audit`, для которых не удалось инферить доменную сущность. Твоя задача — определить real entity refs:

```bash
# Список всех файлов, требующих review
grep -rl "TODO_ENTITY_REF" docs/
```

Для каждого:
1. Открой файл, прочитай body.
2. Определи доменную сущность (одну или несколько), которую документ описывает.
3. Проверь существует ли соответствующий `id:` в `docs/architecture/` (entity catalog).
4. Замени `TODO_ENTITY_REF` на реальный `id` сущности (kebab-case, ≥ 2 символа).
5. Если сущность не определена — создай её (architecture-документ или ADR) и **затем** ссылайся.

Дополнительно проверить в manual review:
- Правильно ли автоматически выведен `type:`? (Например, файл в `docs/adr/` — действительно ADR, а не spec.)
- Правильно ли выведен `status:`? (Например, ADR `proposed` может на самом деле `accepted`.)
- Нет ли потери информации при удалении `lifecycle:` — если значение `lifecycle` нестандартное, добавь его как комментарий или в `tags:`.

**Checkpoint 4:** покажи оператору список всех изменений manual review.

**Не переходи к Step 5 без подтверждения оператора.**

---

## Step 5 — Warn-only CI (несколько дней)

Включи CI guard в warn-only режиме на период rollout. В `.github/workflows/docs-validate.yml` (созданном bootstrap):

```yaml
jobs:
  schema-v1:
    env:
      WARN_ONLY: "true"   # brownfield rollout: WARNING вместо FAIL
```

Запушь изменения. CI будет печатать предупреждения, но не падать. Это «мягкий» период, в течение которого забытые `docs/archive/`, `docs/old/`, `docs/wiki/`, `docs/tmp/` не ломают PR.

В этом режиме локальная проверка:

```bash
# Что скажет polity CI в warn-only
WARN_ONLY=true bash docs/.runtime/naprolom-docs/documentation/validation/validate-frontmatter.sh
```

Длительность warn-only: 3–7 дней или до тех пор, пока в нескольких PR подряд не будет ни одного warning'а.

**Checkpoint 5:** уверен что warn-only включён и CI зелёный.

---

## Step 6 — Cleanup забытых директорий

За warn-only период вычисти нестандартные документы:

- `docs/archive/` → либо дописать canonical FM, либо удалить (решает оператор).
- `docs/old/` → мигрировать с `engine/scripts/migrate-legacy.mjs` либо удалить.
- `docs/wiki/` → перенести релевантное в `docs/architecture/` / `docs/adr/`, остальное удалить.
- `docs/tmp/` → удалить (это обычно сессионные файлы, не документация).
- `*.log`, `PHASE_*_REPORT.md`, `*_verification_*.md` → удалить из `docs/`.

```bash
# Найти забытые директории
find docs/ -type d -not -path "*/docs/.runtime/*" \
  | grep -E "archive|old|wiki|tmp|misc"

# Найти сессионные файлы (обычно не документация)
find docs/ -name "*.log" -o -name "PHASE_*" -o -name "*_verification_*"
```

Для каждого уточни у оператора: мигрировать (canonical FM по Schema v1) или удалить.

**Checkpoint 6:** warn-only CI не выдаёт ни одного warning.

---

## Step 7 — Switch to strict CI

Когда warn-only несколько дней не выдаёт warnings — верни guard в strict режим:

```yaml
jobs:
  schema-v1:
    env:
      WARN_ONLY: ""   # greenfield-strict
```

С этого момента brownfield репозиторий живёт по тем же strict-правилам, что и greenfield. Любой новый `.md` без canonical FM ломает PR.

**Checkpoint 7:** strict CI зелёный, rollback невозможен.

---

## Readiness Checklist

Миграция завершена, когда:

- [ ] `schema: 1` есть во всех `.md` в `docs/` (вне `docs/archive/`).
- [ ] `id`, `type`, `status`, `date`, `owners` заполнены на всех `.md`.
- [ ] `owners` ≠ `unassigned` для active-документов (только Archive может быть `unassigned`).
- [ ] `updated` проставлен мигратором.
- [ ] `entity_refs` заполнен (нет `TODO_ENTITY_REF`) для `spec`/`audit` (min 1 ref).
- [ ] Нет legacy-полей в frontmatter (CI их запрещает).
- [ ] `.context/` bootstrapped (`project.yml`, `boundaries.yml`, `agent-entry.md`).
- [ ] `docs/architecture/entity-catalog.md` создан.
- [ ] Warn-only CI пройден, переключено на strict.
- [ ] CI ни в одном PR не падает на frontmatter.

---

## Edge Cases

### `title:` без H1 в body

Скрипт сам добавит `# <title>` в body. Проверь, что в body не было H1 — иначе будет дубль. Скрипт safe: проверяет перед вставкой.

### Нестандартный `lifecycle:`

Например, `lifecycle: rejected`. Скрипт для ADR мапит `rejected` → `status: deprecated`, для других типов → `status: active`. Если нестандартное значение критично — перенеси в `tags:`.

### `excludes-from-scope:` содержал важную информацию

Поле удаляется как anti-pattern. Если важно явно сказать «не про Z» — используй `tags: [not-X]` или раздел `## Scope / Excluded` в body.

### Orphan spec without entity

Скрипт ставит `TODO_ENTITY_REF`. Если domain entity действительно не идентифицируется — это сигнал, что документ слишком общий или неактуальный. Раздели на несколько spec'ов или перемести в `docs/archive/`.

### ADR с `status: proposed` в body, но в FM отсутствует

Скрипт не парсит body. Проверь manual review: если в body `## Status: accepted` — поставь `status: accepted` в FM.

---

## Анти-паттерны

| Ошибка | Почему плохо | Решение |
|--------|-------------|---------|
| Включить strict CI сразу на brownfield | Забытые `docs/archive/` сломают все PR | Warn-only период обязателен |
| `entity_refs: []` у spec/audit | Модель требует min 1 ref для spec/audit | Скрипт ставит `TODO_ENTITY_REF`, в Step 4 замени |
| `updated` не проставлен | Документ реально изменился при миграции → свежесть не отслеживается | Скрипт ставит `updated = today` автоматически |
| `excludes-from-scope:` оставлен | CI запрещает его; anti-pattern | Скрипт удаляет; заменяй на `tags: [not-X]` |
| Мигрировать неактуальный архив | Тратишь время на dead docs | Оставить в `docs/archive/` без migration |
| Удалять `docs/archive/` целиком | Теряешь историю решений | Только canonical FM добавлять или оставлять |
| Manual review пропущен | Скрипт мог вывести `type`/`status`/`id` неточно | Обязательно 10–20% files просмотреть вручную |
