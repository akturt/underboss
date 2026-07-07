---
schema: 1
id: adoption-guide-existing-repo
type: guide
kind: legacy
status: active
date: 2026-07-07
owners: [naprolom-team]

entity_refs: [schema-v1, canonical-frontmatter, lifecycle-spec]
touches: [docs, .github/workflows]
docs: []
refs: [2026-07-07-documentation-system-playbook-v2.md]
depends_on: [documentation-system-playbook-v2]
tags: [documentation, adoption, brownfield, migration]
priority: P1
---

# Documentation System Adoption Guide (Existing Repository)

> Как внедрить Documentation System v2 (Canonical Schema v1) в **существующий** репозиторий.
> Целевая модель описана в `2026-07-07-documentation-system-playbook-v2.md` (Greenfield Playbook).
> Этот гайд — лишь **способ попасть в ту модель**, не часть самой модели.

---

## Когда использовать этот гайд

| Ситуация | Путь |
|----------|------|
| Новый репозиторий (нет `docs/`) | Greenfield Playbook → `./docs-bootstrap.sh` |
| Существующий репозиторий с `.md` файлами | **Этот гайд** |

Задача не «миграция схемы». Задача — **внедрение системы документации в существующий проект**. Сюда входит не только переписывание frontmatter, но и bootstrap `.context`, создание templates, запуск CI, создание entity catalog, cleanup ADR и перенос specs.

---

## Rollout Strategy (важно)

Brownfield rollout отличается от greenfield режимом CI:

| Режим | Greenfield | Brownfield (этот гайд) |
|-------|-----------|------------------------|
| CI guard | Strict с первого PR | **Warn-only → Strict** |

В больших репозиториях почти всегда находятся забытые документы (`docs/archive/`, `docs/old/`, `docs/wiki/`, `docs/tmp/`), не попавшие под миграцию. Поэтому rollout выглядит так:

```
Migration
   ↓
Warn-only CI (несколько дней)
   ↓
Manual cleanup забытых документов
   ↓
Strict CI
```

Greenfield остаётся `Strict с первого PR`. Brownfield проходит через `Warn → Strict`.

---

## Шаг 1: Аудит legacy (1-2 часа)

```bash
# Сколько файлов?
find docs/ -name "*.md" | wc -l

# Какие типы?
grep -r "^type:" docs/ | awk '{print $2}' | sort | uniq -c

# Какие legacy поля?
grep -r "^author:\|^title:\|^created:\|^lifecycle:\|^referenced_by:\|^supersedes_adr:\|^excludes-from-scope:" docs/
```

Также найди забытые директории вне ожидаемой структуры:

```bash
# Что не попало под шаблоны?
find docs/ -type d | grep -E "archive|old|wiki|tmp|legacy" || true
```

---

## Шаг 2: Приоритизация

- **Active docs** (используются сейчас) → мигрировать в первую очередь
- **Archive docs** (старые, не актуальные) → мигрировать позже или оставить как есть (см. §Archive strategy)
- **Orphan docs** (ни на что не ссылаются) → удалить или архивировать

---

## Шаг 3: Bootstrap окружения

Запустить bootstrap из Greenfield Playbook, чтобы создать `.context/`, templates и CI:

```bash
./docs-bootstrap.sh <project-name>
```

Это даст актуальные `_template.md` для всех типов, `.context/project.yml`, `.context/boundaries.yml`, `.context/agent-entry.md` и `.github/workflows/docs-validate.yml`.

Затем создать entity catalog (он потребуется на шаге 4):

```bash
# docs/architecture/entity-catalog.md — список всех domain-сущностей репозитория
# Каждая сущность = stable kebab-case id, на который ссылаются entity_refs
```

---

## Шаг 4: Migration script

Написать `scripts/migrate-legacy.mjs`:

```javascript
// Псевдокод
const TODAY = new Date().toISOString().slice(0, 10);

for (const doc of glob("docs/**/*.md")) {
  const { frontmatter, body } = parse(doc);

  // Добавить mandatory fields
  frontmatter.schema = 1;
  frontmatter.id = generateIdFromFilename(doc);
  frontmatter.type = inferTypeFromPath(doc); // e.g., docs/adr/ → type: adr
  frontmatter.status = inferStatusFromFrontmatter(frontmatter);
  frontmatter.date = frontmatter.created || extractDateFromFilename(doc) || TODAY;
  frontmatter.owners = [frontmatter.author || "unassigned"];

  // Обязательные поля после миграции (см. Readiness checklist)
  frontmatter.updated = TODAY; // документ реально изменился при миграции

  // entity_refs: минимум 1 для spec/audit.
  // Инферить из пути/заголовка, иначе поставить явный маркер для manual review.
  if (["spec", "audit"].includes(frontmatter.type)) {
    frontmatter.entity_refs = inferRefs(doc, body) || ["TODO_ENTITY_REF"];
  }

  // Удалить legacy fields
  delete frontmatter.author;
  delete frontmatter.title;
  delete frontmatter.created;
  delete frontmatter.lifecycle;
  delete frontmatter.referenced_by;
  delete frontmatter.supersedes_adr;
  delete frontmatter["excludes-from-scope"];

  // Переместить title в body H1
  if (frontmatter.title) {
    body = `# ${frontmatter.title}\n\n${body}`;
  }

  write(doc, { frontmatter, body });
}
```

Ключевые отличия от наивного варианта:

1. **`updated: TODAY`** — документ реально изменился при миграции, фиксируем свежесть.
2. **`entity_refs` не пустые** — для `spec`/`audit` минимум 1 ref (требование модели). Если инферить нельзя — ставим `TODO_ENTITY_REF` и ловим на manual review.
3. **`excludes-from-scope:` удаляется** — CI его уже запрещает, мигратор тоже должен его убирать.

---

## Шаг 5: Manual review (10-20% файлов)

Проверить вручную, с фокусом на маркеры из шага 4:

- Правильно ли определён `type`?
- Правильно ли определён `status`?
- Нет ли потерянной информации при удалении legacy полей?
- `entity_refs: [TODO_ENTITY_REF]` → замениить на реальный ref из entity catalog
- Нет ли потерянной информации?

---

## Шаг 6: Archive strategy

Если документ не актуален — не тратить время на миграцию. Оставить в `docs/archive/` без canonical frontmatter, но явно исключить из CI (warn-only период перехватит оставшиеся). Решить позже: удалить или дописать canonical FM.

---

## Шаг 7: Включить CI в режиме warn-only

Вместо `exit 1` в `docs-validate.yml` на период rollout — печатать WARNING и не падать:

```yaml
# Временно (warn-only):
- name: Verify all .md in docs/ have schema: 1
  run: |
    missing=$(git grep -L "^schema: 1$" -- 'docs/**/*.md' || true)
    if [ -n "$missing" ]; then
      echo "WARNING: .md files without schema: 1 frontmatter:"
      echo "$missing"
    fi
# ...аналогично для legacy fields и spec path-status match
```

Держать warn-only несколько дней, пока не вычистятся забытые `docs/archive/`, `docs/old/`, `docs/wiki/`, `docs/tmp/`.

---

## Шаг 8: Switch to strict CI

Когда warn-only больше не выдаёт предупреждений — переключить guard обратно в `exit 1` (как в Greenfield Playbook). С этого момента brownfield репозиторий живёт по тем же strict-правилам, что и greenfield.

---

## Readiness Checklist (Migration complete when)

- [ ] `schema: 1` на всех `.md` в `docs/`
- [ ] `id` на всех `.md` в `docs/`
- [ ] `owners` заполнен (не `unassigned` для active docs)
- [ ] `updated` проставлен мигратором (`updated = today`)
- [ ] `entity_refs` заполнен (нет `TODO_ENTITY_REF`, min 1 для spec/audit)
- [ ] Нет legacy полей (`author`, `title`, `created`, `lifecycle`, `referenced_by`, `supersedes_adr`, `excludes-from-scope`)
- [ ] `.context/` bootstrapped (project.yml, boundaries.yml, agent-entry.md)
- [ ] entity catalog создан (`docs/architecture/entity-catalog.md`)
- [ ] warn-only CI пройден, переключено на strict
- [ ] CI green

---

## Частые ошибки

| Ошибка | Решение |
|--------|---------|
| Strict CI сразу на brownfield | Начать с warn-only, иначе забытые `docs/archive/` сломают все PR |
| `entity_refs: []` у spec/audit | Модель требует min 1 ref — инферить или `TODO_ENTITY_REF` + manual review |
| `updated` не проставлен | Документ изменился при миграции — ставить `updated = today` |
| `excludes-from-scope:` оставлен | Удалять, CI его запрещает |
| Мигрировать неактуальный архив | Оставить в `docs/archive/` без migration, решить позже |
