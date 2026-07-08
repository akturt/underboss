---
schema: 1
id: agentic-layer
type: spec
status: approved
date: 2026-07-08
updated: 2026-07-08
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer, agent-role-separation, sop-dag, capabilities]
touches: [agents, sops, knowledge, engine/templates, bootstrap, README, INSTALL]
code: [.github/workflows/docs-validate.yml]
docs: [../../README.md, ../../INSTALL.md, ../../agents/README.md, ../../sops/README.md]
refs: []
depends_on: []
implements: []
supersedes: []
tags: [agentic, roles, sops, knowledge, capabilities, layered-runtime, v1.1, upgrade]
priority: P0
---

# Spec: Documentation System Runtime v1.1 — Agentic Layer

> Доработанная редакция. Учтены замечания ревизора в 5 проходов:
> v1: удалены output templates (слиты в `knowledge/report-formats.md`), `planner.mjs` зафиксирован как DAG-printer (не executor), YAML SOP упрощён (без `constraints:`), введён слой Capabilities.
> v2: **Artifact — сущность первого класса** (`artifact:` поле с каноническими именами, см. §Artifact model), **Capability Catalog вынесен в `knowledge/capabilities.md`** (не в `agents/README.md`).
> v3: Capability Catalog без providers (单向 Role→Capability). Knowledge refs через short-id (`knowledge: [architecture-principles]`). planner не читает knowledge (D-PL). `gate: manual` вместо `role: human` (D-HG).
> v4 (текущая): **Bootstrap разворачивает Runtime в `docs/.runtime/`, а НЕ в корень consumer-репо** (D-BR). Явное разделение: (a) репо `naprolom-docs` = продукт (каталоги в корне ОК); (b) consumer-репо = использует только `docs/`, всё остальное — в `docs/.runtime/`. Submodule монтируется в `docs/.runtime/naprolom-docs/`, НЕ в `.context/runtime/`. Затрагивает: bootstrap-скрипты, INSTALL, playbook, CLAUDE.md snippet, пути во всех SOP/ролях.
> Прочие улучшения (группировка knowledge по домену, загрузка knowledge из SOP не из роли) — отложены в **v1.2 roadmap** (§Out-of-scope follow-up).

## Goal
Разделить монолитные AI-агент-промпты предыдущей итерации на **пять ортогональных слоёв** — **Knowledge** (что агент знает), **Role** (кто он), **Capability** (что умеет), **SOP** (когда используется), **Artifact** (что путешествует между ролями в DAG) — без введения отдельного вида «output templates»; добавить в Runtime v1.1 две новые роли (`reality-auditor`, `adversary-checker`) и превратить бывший `forensic-orchestrator` в декларативный SOP `sops/forensic-audit.yaml`, не ломая стабильные контракты Runtime v1.0.

## Context
Runtime v1.0 заморожен и готов к dogfooding на Kordon. Перед финальным релизом пользователь обещал «финальный апгрейд» — интеграцию наработок по агентам из `/home/dev/.opencode/agents/`. В сыром виде эти наработки:

- смешивают **роль**, **протокол**, **базу знаний** и **формат вывода** в одном файле 300–600 строк;
- `forensic-orchestrator.md` — это workflow engine (DAG, retries, validators), а не агент; рекурсия `Agent → Orchestrator → Agents`;
- 14 архитектурных принципов, 5-stage validation, 7-stage forensic protocol — встроены в конкретный промпт и недоступны для переиспользования.

Это блокирует масштабирование на новые модели (Gemini/GPT/Kimi/Qwen) и порождает дублирование. Решение: вынести знания в общий `knowledge/` слой, превратить workflow в SOP, оставить ролям только идентичность, ввести **Capabilities** (что умеет) и **Artifacts** (что путешествует между шагами DAG) — пять сущностей первого класса вместо прежних «роль-всё-в-одном».

## Two-repo model (важный фикс v1.1)

> Этот раздел фиксирует принципиальное разграничение двух **разных** репозиториев — продукта и consumer'а. До v1.1 в INSTALL/playbook/bootstrap это было смешано: submodule монтировался в `.context/runtime/naprolom-docs/` (вне `docs/`), что засоряло корень consumer-репо служебными каталогами. v1.1 устанавливает чёткую модель.

### Репозиторий `naprolom-docs` (продукт)

Исходники Runtime. Все каталоги в корне — **нормально**:

```
naprolom-docs/
├── README.md INSTALL.md
├── playbook/  engine/  bootstrap/  agents/  knowledge/  sops/  docs/  .github/
```

Здесь docs/ — собственный dogfood проекта (audits, specs/drafts/this-spec.md).

### Consumer-репозиторий (пользователь Runtime)

Пользователь работает **только** с `docs/`. Runtime — **локализован** внутри `docs/.runtime/`, а НЕ разбросан по корню:

```
consumer-project/
├── README.md  pyproject.toml ...   ← код проекта живёт как обычно
└── docs/
    ├── architecture/  adr/  specs/  audits/  backlog/  api/   ← пользовательское содержимое
    └── .runtime/
        └── naprolom-docs/         ← submodule монтируется сюда (НЕ в .context/runtime/)
            ├── engine/  bootstrap/  agents/  knowledge/  sops/  playbook/  INSTALL.md  ...
```

Ключевая инварианта: **consumer-репо содержит ровно один корневой каталог — `docs/`**. Все служебные каталоги `naprolom-docs` (agents/, knowledge/, sops/, engine/, bootstrap/, playbook/, agents/, .github/) **НЕ появляются в корне consumer'а** — они доступны **только** по пути `docs/.runtime/naprolom-docs/...`.

### Почему так

1. **Пользователь mental model:** «всё про проект — в `docs/`». Никакого «а ещё есть `agents/`, `knowledge/`...» в корне.
2. **Чёткая граница:** `docs/.runtime/` — это System-owned (обновляется через `git submodule update --remote`); `docs/architecture|adr|specs|audits|backlog|api` — User-owned (создаётся и редактируется пользователем).
3. **Идемпотентность bootstrap:** скрипт создаёт/обновляет только `docs/` subtree, не трогает корень.
4. **Облегчённый .gitignore:** одна строчка `docs/.runtime/` (если пользователь решит игнорировать submodule в working tree) вместо 7.
5. **Единая точка для CI/CLI:** все пути встроены в `docs/.runtime/naprolom-docs/...` — компактен в workflow yml, runbook'ах, CLAUDE.md snippet.

### Что меняется технически

| Аспект | Что было (v1.0) | Что становится (v1.1) |
|--------|------------------|------------------------|
| Git submodule mount point | `.context/runtime/naprolom-docs/` (вне `docs/`) | `docs/.runtime/naprolom-docs/` (внутрь `docs/`) |
| `.gitmodules` path | `path = .context/runtime/naprolom-docs` | `path = docs/.runtime/naprolom-docs` |
| Bootstrap invocation | `bash .context/runtime/naprolom-docs/bootstrap/bootstrap.sh` | `bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh` |
| Validator path | `.context/runtime/naprolom-docs/engine/validators/...` | `docs/.runtime/naprolom-docs/engine/validators/...` |
| Templates `cp` | `cp .context/runtime/naprolom-docs/engine/templates/spec.md ...` | `cp docs/.runtime/naprolom-docs/engine/templates/spec.md ...` |
| Knowledge refs (Role → knowledge file) | `.context/runtime/naprolom-docs/knowledge/<id>.md` | `docs/.runtime/naprolom-docs/knowledge/<id>.md` (но roles используют short-id — путь резолвит Runtime, D-KR) |
| CLAUDE.md snippet (paths) | ссылки вида `.context/runtime/naprolom-docs/...` | ссылки вида `docs/.runtime/naprolom-docs/...` |
| CI workflow git checkout | `with: submodules: true` | без изменений (только пути в run: шагах) |
| Existing consumers v1.0 | n/a — миграция для них out-of-scope (см. §Migration) | (миграция через single `git mv` submodule + update paths в нескольких файлах; lehet так просто, что не стоит формализовать как SOP) |

### Что НЕ меняется

- **Внутренняя структура `naprolom-docs` репо** — каталоги в корне остаются (`agents/`, `knowledge/`, `sops/`, `engine/`, `bootstrap/`, `playbook/`, `docs/` dogfood). Это **продукт**, его layout — наш дизайн.
- **Имена** и назначение каталогов внутри Runtime — те же.
- **CLI взаимодействия** (validate-frontmatter.sh, planner.mjs, migrate-legacy.mjs) — те же, меняются только пути к ним в инструкциях.
- **Schema v1** frontmatter — нет изменений.

### Миграция для существующих v1.0 consumers (опционально, not v1.1 deliverable)

Текущий dogfooding-target Kordon ещё не выкатан — миграция не нужна. Для любого гипотетического consumer v1.0 → v1.1, путь: `git mv .context docs/.runtime && git submodule absorbgitdirs` (см. git docs). Это **one-command migration**; не формализуем как SOP (sufficiently редкая операция).

## Scope

### Included

1. **Новый `knowledge/` слой** в корне Runtime с **4** файлами (минимальный набор, не плодить):
   - `knowledge/README.md` — index, объясняющий роль knowledge ref-слоя.
   - `knowledge/architecture-principles.md` — 14 принципов (7 базовых + 7 операционных) + 3 мета-паттерна (стратификация по времени / семантическая плотность / асимптотическая сложность изменений), извлечённые из прежнего `architecture-reviewer.md`.
   - `knowledge/evidence-model.md` — Trust Hierarchy (7 уровней) + 4 evidence-класса (OBSERVED/EVIDENCED/INFERRED/CLAIMED) + behavioral rules, извлечённые из прежнего `reality-auditor.md`.
   - `knowledge/audit-principles.md` — 5-stage validation protocol + verdict-система (SUSTAINED/WEAKENED/REFUTED/INSUFFICIENT_EVIDENCE) + confidence-model, извлечённые из прежнего `adversary-checker.md`.

   > **`knowledge/report-formats.md` (merged)** — заменяет и прежний `knowledge/review-output-format.md`, и всю секцию output templates (см. §Decisions D-OT). Один файл с описанием выходных форматов: architecture-review / reality-audit / adversary-report / forensic-report. Их **не выносить** в `engine/templates/` как отдельные `.md` — это знания о формате, а не runtime-инфраструктура.
   
   Итого: **5 файлов knowledge** (`README` + 4 содержательных: `architecture-principles`, `evidence-model`, `audit-principles`, `report-formats`).

2. **Рефакторинг `agents/{claude-code,opencode}/architecture-reviewer.md`** в slim-форму:
   - System Prompt / When you run / Operating protocol → остаётся; добавляется блок **Knowledge refs** со ссылками на `knowledge/architecture-principles.md` и `knowledge/report-formats.md`.
   - 14 inline принципов и inline output-format блок — удаляются из роли.
   - Refusal protocol / What you do NOT do — остаются inline (это роль-специфично, не общее знание).

3. **Новые роли** в `agents/`:
   - `agents/{claude-code,opencode}/reality-auditor.md` — Project State Reconstruction Agent. Slim role + ссылка на `knowledge/evidence-model.md`, `knowledge/report-formats.md`. Permissions: `read: allow`, `bash: ask` (только read-only investigation: `git log/diff/show/status/blame`, `find`, `grep`, `tree`, `ls`, `wc`), `edit: deny`, `webfetch: allow`. Никогда не запускает tests/build/deploy.
   - `agents/{claude-code,opencode}/adversary-checker.md` — Claim Validation Agent. Slim role + ссылка на `knowledge/audit-principles.md`, `knowledge/report-formats.md`. Permissions: `read: allow`, `edit: deny`, `bash: deny`, `webfetch: allow`.

4. **Концепция Capabilities** — явно введена в спецификацию, реализована минимально:
   - Каждая роль декларирует `capabilities:` (list) в frontmatter (单向 Role→Capability).
   - SOP-шаг может ссылаться либо `role: <name>` (как раньше), либо `capability: <name>` + `role: <name>` (более абстрактно).
   - **Capability Catalog** живёт в **`knowledge/capabilities.md`** (D-CC) — отдельный документ-контракт. Содержит **только Contract** (description / consumes / produces / artifacts), **без `provided by:`** (D-CP) — чтобы не создавать двустороннюю зависимость Role↔Capability. «Role provides capability» декларируется单向 в самой Role FM (`capabilities: [...]`), а в `agents/README.md` даётся overview-таблица 4-role × capability-list.
   
   Канонический список capabilities на v1.1 (краткое repeat — определение в `knowledge/capabilities.md`, providers déclarées в `agents/README.md`):
   | Role | Capability |
   |------|------------|
   | architecture-reviewer | `review-spec`, `review-adr`, `review-domain-model`, `review-security-model` |
   | documentation-reviewer | `validate-frontmatter`, `validate-entity-refs` |
   | reality-auditor | `state-reconstruction`, `drift-analysis`, `architecture-extraction`, `attribution-analysis` |
   | adversary-checker | `claim-validation`, `assumption-analysis` |

5. **Новый SOP `sops/architecture-review.yaml`** — формальный DAG review pipeline. Sequential (Reality → Architecture, NOT parallel — см. §Decisions D-5):
   ```
   reality-auditor             (state reconstruction against actual repo)
            ↓
   architecture-reviewer       (review spec against REAL state, not imagined)
            ↓
   documentation-reviewer      (Schema v1 + entity_refs validity)
            ↓
   adversary-checker            (optionally, manual condition; sm. §Decisions D-8)
            ↓
   human                        (decision gate)
   ```

6. **Новый SOP `sops/forensic-audit.yaml`** — абстрактный 8-шаговый pipeline, замещающий прежний `forensic-orchestrator`-как-агент:
   - Шаги 1–8 общий шаблон (control-objects → actual-control-plane-entity → signal-inventory → attribution-analysis → multi-binding-reality-check → runtime-ownership → reputation-layer-design → final-recommendation), но **без зашитых доменных сущностей** (`DomainAsset`, `binding_id` и т.п. — это из personal email-infra project). Consumer подставляет свои `entities:` и `mechanisms:` в `input.required` (см. §Technical approach).
   - **Attribution Analysis (step 4) → `role: reality-auditor`** (НЕ adversary-checker; см. §Decisions D-7 — attribution это reconstruction, не refutation).
   - **Без `constraints:` блоков и встроенных JSON-валидаторов** — см. §Decisions D-3. Шаг описывает только `capability:`, `role:`, `produces:` (что produced, текстовое описание), `depends_on:`. Валидация выхода — ответственность роли, не SOP.

7. **`sops/planner.mjs` остаётся DAG-printer'ом, не executor'ом** (см. §Decisions D-2):
   - Не добавляем retry / scheduler / parallel-execution / resume / checkpoint.
   - Поддержка capabilities: planner при печати DAG проверяет, что для каждого шага указана либо `role:`, либо `capability:` (и в последнем случае находит роль, предоставляющую эту capability, в `agents/{platform}/`). Если capability не найдена ни в одной роли — warning, не error.
   - Это расширение парсера, ~10 строк.

8. **Документация (минимальные правки)**:
   - `README.md` — расширить «What you get» (4 роли, knowledge layer, 2 SOP), обновить layout diagram, добавить Changelog `v1.1 — agentic layer separation`.
   - `INSTALL.md` — упомянуть `knowledge/` в architecture diagram.
   - `agents/README.md` — расширенная таблица ролей (4), новый раздел «Capabilities», раздел «Knowledge refs».
   - `sops/README.md` — добавить 2 новых SOP; раздел про параметризованный SOP input (entities/mechanisms для forensic-audit); явно декларировать что **SOP описывает оркестрацию, не validation logic**.
   - `playbook/playbook-v2.md` — **не трогать** (см. §Decisions D-4). Если возникнет острая необходимость, максимум одна ссылка в `## Canonical Source of Truth` table на `knowledge/` — отложено на Phase E с пометкой optional.

9. **Bootstrap** (`bootstrap/bootstrap.sh`, `bootstrap/bootstrap.ps1`): в `CLAUDE.md` snippet добавить 2 идемпотентные строки про `knowledge/` и про опциональные роли `reality-auditor`, `adversary-checker`. Никаких новых директорий в consumer-репо не создаётся.

10. **CI validator extension** — расширить существующий `engine/validators/validate-frontmatter.sh` поддержкой параметра `ROOT` для применения к `knowledge/` (см. §Decisions D-6). В `.github/workflows/docs-validate.yml` добавить второй шаг `ROOT=knowledge bash engine/validators/validate-frontmatter.sh knowledge`. **Без отдельного `validate-knowledge.sh`** — повторно используем существующий.

11. **Dogfood: ADR-001 в самом `naprolom-docs` репо** (см. §Decisions D-2): создать `docs/adr/001-agentic-layer-separation.md`, `status: accepted`, фиксирующий переход от монолитных агентов к 4-слойной модели Role/Knowledge/SOP/Capability. Это иллюстрирует dogfood модель и проверит наш собственный архитектурный pipeline.

### Excluded

1. **Переименование `agents/` → `roles/`** — ломает стабильные контракты v1.0 (INSTALL/README/playbook/плагины потребителей). «Role» остаётся концептуальной единицей внутри `agents/`; в README явная заметка.
2. **Output templates как отдельный подвид `engine/templates/`** — слиты в `knowledge/report-formats.md` (см. §Decisions D-OT).
3. **`constraints:` блоки в SOP YAML** — не вводим (см. §Decisions D-3). Validation logic — ответственность роли.
4. **Slash-command bindings** для новых ролей — Tier 2, после dogfooding.
5. **Генерика parametrized roles** (роли с параметрами как в coding-orch frameworks) — out of scope.
6. **`runtime/` wrapper для `engine/` + `bootstrap/`** — см. §Out-of-scope follow-up. Не входит в v1.1, отдельная可能的 v1.2 рефакторинг.
7. **Дополнительные knowledge-файлы** (32-файловый разобьётся в зло) — правило: «knowledge = устойчивые знания». 4 содержательных файла на v1.1 — это ceiling.
8. **Дополнительные роли** (canonical-transformer, spec-reviewer, auditor) — Tier 2.

## Decisions (резолюция Open Questions)

| ID | Вопрос | Решение | Обоснование |
|----|--------|---------|-------------|
| D-1 | `status` для output templates | N/A | Output templates как отдельный вид удалён (D-OT). |
| D-OT | Output templates как engine/templates/ | **Удалить**, слить в `knowledge/report-formats.md` | Это не runtime-инфраструктура, а знание о формате. Никто не будет `cp` их. Один markdown-файл проще сопровождать. |
| D-2 | `docs/adr/001-agentic-layer.md` в naprolom-docs (dogfood) | **Да** | Это arch-combo «выбор между двумя хорошими вариантами» — ради него ADR и существуют. |
| D-3 | `constraints:` блоки в SOP YAML | **Убрать** | SOP отвечает только на «кто / после кого / что производит». Validation logic принадлежит роли, не описанию процесса. |
| D-P | `planner.mjs` роль | **DAG-printer, не executor** | Иначе через месяц вырастет маленький Airflow (retry/scheduler/parallel/resume/checkpoint). |
| D-C | Capabilities слой | **Ввести как концепцию + соглашение** | Позволяет завтра отвязать SOP от конкретной роли/модели. Без отдельной директории. |
| D-4 | `playbook/playbook-v2.md` правки | **Не трогать** (max 1 ссылка) | Playbook = consumer-facing greenfield playbook, не naprolom-docs own changelog. |
| D-5 | DAG `architecture-review.yaml` step 1→2 | **Sequential** | Reality → Architecture. Иначе Architecture снова анализирует предположения, не реальность. |
| D-6 | Валидация `knowledge/` в CI | **Расширить существующий validator через `ROOT` env**, без второго скрипта | `ROOT=knowledge bash engine/validators/validate-frontmatter.sh knowledge` — красиво и DRY. |
| D-7 | Attribution analysis роль в `forensic-audit.yaml` | **`reality-auditor`** (не adversary-checker) | Attribution — это реконструкция из сигналов, не опровержение. Adversary проверяет готовые выводы других. |
| D-8 | Adversary-checker condition в `architecture-review.yaml` | **Ручное gate** | Human на шаге 5 решает, нужен ли adversary. Без автоматического `if high-impact`. |
| D-9 | `audit.yaml` vs `architecture-review.yaml` пересечение | **Оставить оба** | Audit = post-incident/scheduled; arch-review = pre-merge. Разные purposes. |
| D-A | Artifact как сущность первого класса | **Ввести v1.1** | DAG соединяется через артефакты (Data Flow), не через «роль→роль». Поднимает выразительность модели почти бесплатно. |
| D-CC | Capability Catalog location | **`knowledge/capabilities.md`** (не `agents/README.md`) | README остаётся обзором, Capability становится самостоятельным контрактом системы. |
| D-CP | Capability Catalog: providers field | **Нет `provided by:`** в каталоге | Разорвать двустороннюю зависимость Role↔Capability. Каталог содержит seulement **Contract** (description / consumes / produces / artifacts). «Role provides capability» —单向 declared в самой Role (в `agents/**/*.md` FM `capabilities:` list). |
| D-KR | Knowledge refs format | **Short-id*, не hardcoded path | В Role FM: `knowledge: [architecture-principles, report-formats]`. Путь резолвит Runtime (соглашение: `knowledge/<id>.md`). Позволяет менять структуру `knowledge/` без переписывания ролей. |
| D-PL | planner.mjs scope | **Только roles + capabilities + SOP** (НЕ knowledge) | Иначе planner постепенно станет Runtime. Knowledge подгрузка — ответственность SOP/Role при исполнении шага, не planner'а. |
| D-HG | Human steps in SOP | **`gate: manual`** (не `role: human`) | Human — не роль Runtime. planner печатает `gate: manual` явно. Для backend-compat с v1.0 SOP planner принимает `role: human` как alias и визуализирует как `gate: manual`. Существующие 7 SOP v1.0 не трогаем. |
| D-BR | Bootstrap deploy location в consumer-репо | **`docs/.runtime/naprolom-docs/`** (НЕ `.context/runtime/...` в корне) | Пользователь работает только с `docs/`. Runtime локализован внутри `docs/.runtime/`, не разбрасывается по корню. См. §Two-repo model. Затрагивает bootstrap paths, INSTALL, playbook, CLAUDE.md snippet, all SOP/Role refs к Runtime. |

## Artifact model

> **Artifact** — сущность первого класса, обозначающая что **путешествует между шагами DAG**. До v1.1 шаги соединялись неявно через `depends_on: [<step-id>]` + text-описание `produces:`. С v1.1 вводится явный `artifact:` контракт в SOP YAML.

### Зачем

Без явного артефакта DAG соединяет шаги по номеру:
```
step 1 → step 2 → step 3
```
Это control flow. Но реально ролям нужно data flow — что шаг 1 _произвёл_, что шаг 2 _потребил_. Явный `artifact:` делает контракт двусторонним:
```
step 1 produces reality-report
                    ↓ consumed by
step 2 (вместе со Spec артефактом)
                    produces architecture-findings
                                ↓ consumed by
step 4 adversary-checker
                    produces validated-findings
```

### Канонические artifact names (v1.1)

| Артефакт | Producer | Consumer(s) | Описание |
|----------|----------|-------------|----------|
| `reality-report` | reality-auditor | architecture-reviewer, adversary-checker | Current State Report (feature inventory, drift, architecture-extraction) |
| `architecture-findings` | architecture-reviewer | documentation-reviewer, adversary-checker, human | Findings: invariants, drift, missing ADRs, security |
| `documentation-report` | documentation-reviewer | human | Schema v1 compliance + entity_refs validity report |
| `validated-findings` | adversary-checker | human | Per-finding verdicts (SUSTAINED/WEAKENED/REFUTED) + confidence matrix |
| `forensic-report` | human (final merger в forensic-audit SOP) | — (artifact terminal: docs/audits/) | 8-part forensic audit report |
| `current-state-{context}` | любой producer | любой |  generic-артефакт контекста; префикс, не спецификация |

### Формат в SOP YAML

Каждый шаг в `steps:` декларирует **обязательный** `produces:` (имя артефакта) и опциональный `consumes:` (список артефактов от предыдущих шагов). `depends_on:` сохраняется — он про control flow (последовательность исполнения); `consumes:` — про data flow (что используется как вход). В большинстве случаев они изоморфны, но это **разные намерения** и их явное разделение даёт будущей системе flexibility:

```yaml
- id: 2
  name: Architecture review against REAL state
  capability: review-spec
  role: architecture-reviewer
  consumes: [reality-report, spec]   # data flow: что получаем на вход
  produces: architecture-findings   # data flow: что отдаём дальше
  depends_on: [1]                    # control flow: после какого шага
```

### Правила

1. **Имя артефакта** — kebab-case, `^[a-z][a-z0-9-]*$`. Stable: если меняется имя — это breaking-change в SOP contract (требует bump версии SOP).
2. **Planner**печатает `consumes →` `produces` в DAG visualization, рядом с control-flow `depends_on`. Без execution logic.
3. **Adversary-checker** в `architecture-review.yaml` step 4 — `consumes: [architecture-findings]` (НЕ `reality-report`), т.к. валидирует готовые выводы, не raw state. Пример data-flow differ от control-flow: в step 4 `depends_on: [1, 2]` (control flow: после обоих), но `consumes: [architecture-findings]` (data flow: только consumed от step 2 — step 1 contribution уже «встроен» в findings через архитектурный слой шага 2).
4. Terminal артефакты (live в `docs/audits/`, `docs/adr/`, `docs/specs/implemented/`) не имеют consumer — они сохраняются в репо.
5. `artifact:` (строка) — deprecated alias `produces:` для текстового описания; для v1.1 **обязательны оба**: `produces: <artifact-name>` (strict contract) + `note: <free-form>` (human description). См. примеры в §Technical approach ниже.

## Technical approach

### Целевая структура (VLАД — два редактирования, продукт + consumer)

#### A. Репозиторий `naprolom-docs` (продукт) — без изменений layout:

```
naprolom-docs/
├── README.md  INSTALL.md
├── playbook/              # Documentation Model layer (v1.0, не трогать layout, только пути внутри файлов)
├── engine/
│   ├── templates/         # v1.0 templates (6) — БЕЗ новых output-templates
│   ├── schemas/            # unchanged
│   ├── validators/         # unchanged (validate-frontmatter.sh уже принимает ROOT)
│   └── scripts/           # unchanged
├── bootstrap/             # output snippet +2 строки в CLAUDE.md; пути в comments/snippet мигрируют (Phase 0)
├── agents/
│   ├── README.md          # extended: 4 roles + capabilities + knowledge refs
│   ├── claude-code/
│   │   ├── architecture-reviewer.md   # refactored (slim) + capabilities
│   │   ├── documentation-reviewer.md   # unchanged (на v1.1 — capabilities добавлены только в FM)
│   │   ├── reality-auditor.md          # NEW
│   │   └── adversary-checker.md        # NEW
│   └── opencode/
│       ├── architecture-reviewer.md   # mirror
│       ├── documentation-reviewer.md   # mirror
│       ├── reality-auditor.md          # NEW
│       └── adversary-checker.md        # NEW
├── knowledge/             # NEW LAYER — v1.1
│   ├── README.md
│   ├── architecture-principles.md
│   ├── evidence-model.md
│   ├── audit-principles.md
│   ├── report-formats.md   # merged (замена всех output templates + review-output-format)
│   │   └── reality-auditor.md          # NEW (Phase B4)
│   │   └── adversary-checker.md        # NEW (Phase B6)
│   └── opencode/  (mirror claude-code/)
│   └── capabilities.md     # NEW (D-CC): capability catalog — контракт системы, не README
├── sops/
│   ├── README.md          # extended
│   ├── planner.mjs        # unchanged + ~15 строк cap-check / artifact-aware DAG printing
│   ├── architecture-review.yaml   # NEW (review pipeline DAG)
│   ├── forensic-audit.yaml        # NEW (8-step, замещает forensic-orchestrator как агент)
│   └── (existing 7 SOPs unchanged — planner treats role:human as alias для gate:manual, D-HG)
├── docs/
│   ├── adr/
│   │   └── 001-agentic-layer-separation.md   # NEW (dogfood ADR, Phase E)
│   ├── audits/
│   └── specs/drafts/
│       └── 2026-07-08-agentic-layer.md   # /this/ spec
└── .github/workflows/docs-validate.yml       # +1 step (ROOT=knowledge в самом naprolom-docs)
```

> **Note:** `2026-07-08-agentic.md` (raw input) уже удалён в начале v3-правок — в Phase G1 помечено выполненным.

#### B. Consumer-репозиторий (после `bash docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh`) — НОВОЕ в v1.1 (D-BR):

```
consumer-project/
├── README.md, package.json, src/, tests/ ...   ← обычный код проекта
├── CLAUDE.md                                    ← генерируется bootstrap'ом (snippet с refs на docs/.runtime/...)
└── docs/                                        ← ЕДИНСТВЕННЫЙ корневой каталог документации
    ├── architecture/  adr/  specs/  audits/  backlog/  api/   ← user content (создаёт пользователь)
    ├── runbooks/  guides/  ...                                ← user content
    └── .runtime/                                              ← System-owned (nentropy обновляется из submodule)
        └── naprolom-docs/                                     ← submodule mount point (D-BR)
            ├── engine/  bootstrap/  agents/  knowledge/  sops/  playbook/  INSTALL.md  README.md
            └── (.github/ — только если consumer наследует workflow templates; обычно не нужно, CI workflow лежит в самом consumer .github/workflows/, refs на docs/.runtime/naprolom-docs/...)
```

> **Инварианта:** в корне consumer-репо **нет** каталогов `agents/`, `knowledge/`, `sops/`, `engine/`, `bootstrap/`, `playbook/`, `.context/runtime/`. Всё, что связано с Runtime, доступно **только** через `docs/.runtime/naprolom-docs/...`.
Frontmatter Schema v1, `type: guide`, `kind: index`, `status: active`. Содержание — markdown с пронумерованными принципами/классами/протоколами, готов к инлайн-чтению AI-агентом. Не выполняется, а загружается в контекст ролями по ссылке.

### Capabilities convention

Каждая роль декларирует `capabilities:` (list) в frontmatter:
```yaml
capabilities: [review-spec, review-adr, review-domain-model, review-security-model]
```

**Capability catalog** — отдельный документ **`knowledge/capabilities.md`** (D-CC). Содержит **только Contract** per-capability (description, consumes, produces, artifacts), **без `provided by:`** (D-CP) —单向 Role→Capability, объявлен в Role FM. `agents/README.md` даёт overview-таблицу (Role → capability list) + указатель на `knowledge/capabilities.md`. ** planner.mjs не читает содержимое `knowledge/`** (D-PL) — только roles (`agents/{platform}/`), capabilities (per-role FM `capabilities:` field), SOP (`sops/*.yaml`).

**Knобledge refs** — Role декларирует в FM:
```yaml
knowledge: [architecture-principles, report-formats]
```
**Short-id**, не hardcoded path (`knowledge/architecture-principles.md`). Путь резолвит Runtime при подгрузке (соглашение: `knowledge/<short-id>.md`). Позволяет менять структуру `knowledge/` без переписывания ролей (D-KR).

SOP-шаг может ссылаться:
```yaml
# option 1 — role directly (v1.0 style, compat)
role: reality-auditor

# option 2 — capability + role (v1.1 style, future-proof)
capability: state-reconstruction
role: reality-auditor

# option 3 — capability only (v1.2 future, requires agent resolution; planner warns)
capability: state-reconstruction
```

На v1.1 поддерживается option 1 + option 2. Option 3 — planner warning, не ошибка.

### Формат SOP `sops/forensic-audit.yaml` (упрощённый, без constraints, с artifact contracts)

```yaml
name: forensic-audit
description: 8-step multi-pass forensic audit pipeline (замещает ad-hoc forensic agent)
triggers:
  - manual invocation for deep architectural forensic
  - после инцидента с архитектурной причиной
input:
  required:
    - type: spec|adr|audit
      path: <target subject document>
      artifact: subject-document
    - type: list
      name: entities
      note: "доменные сущности consumer'а (e.g., DomainAsset, UserAccount — НЕ зашито в SOP)"
    - type: list
      name: mechanisms
      note: "механизмы управления для audit"
output:
  - artifact: forensic-report
    final_path: docs/audits/YYYY-MM-DD-forensic-<topic>.md
    type: audit
    status: completed
steps:
  - id: 1
    name: Control Objects Identification
    capability: state-reconstruction
    role: reality-auditor
    platform: any
    consumes: [subject-document]
    produces: control-objects-matrix
    note: "ownership_matrix (entities × is_resource/is_route/is_reputation/is_execution/is_observation/is_decision) + evidence"
    depends_on: []
  - id: 2
    name: Actual Control Plane Entity
    capability: state-reconstruction
    role: reality-auditor
    platform: any
    consumes: [control-objects-matrix]
    produces: control-plane-answer
    note: "answer (A-E) + mechanisms + code_refs + confidence"
    depends_on: [1]
  - id: 3
    name: Signal Inventory
    capability: state-reconstruction
    role: reality-auditor
    platform: any
    consumes: [subject-document]
    produces: signal-inventory
    note: "external/internal signals × granularity/attribution"
    depends_on: [1]
  - id: 4
    name: Attribution Analysis
    capability: attribution-analysis    # D-7: reality, не adversary
    role: reality-auditor
    platform: any
    consumes: [signal-inventory, control-objects-matrix]
    produces: attribution-analysis
    note: "per-source attribution (hard/probabilistic/impossible) + reasoning"
    depends_on: [3]
  - id: 5
    name: Multi-Binding Reality Check
    capability: state-reconstruction
    role: reality-auditor
    platform: any
    consumes: [control-plane-answer, attribution-analysis]
    produces: multi-binding-verdict
    note: "verdict + evidence + contradictions"
    depends_on: [2]
  - id: 6
    name: Runtime Ownership Analysis
    capability: architecture-extraction
    role: reality-auditor
    platform: any
    consumes: [control-objects-matrix, multi-binding-verdict]
    produces: runtime-ownership-report
    note: "runtime_owner + per-attribute owner + conflict_behavior"
    depends_on: [5]
  - id: 7
    name: Reputation Layer Design (architecture recommendation)
    capability: review-domain-model
    role: architecture-reviewer
    platform: any
    consumes: [attribution-analysis, runtime-ownership-report]
    produces: reputation-layer-design
    note: "layer_responsibilities + unified_reputation_identity_exists?"
    depends_on: [4, 6]
  - id: 8
    name: Final Recommendation (ADR-precursor, human merge)
    gate: manual         # D-HG: НЕ role: human — human не роль Runtime
    consumes: [reputation-layer-design, runtime-ownership-report, attribution-analysis]
    produces: forensic-report
    note: "adr_recommendation + risk_register + open_questions → docs/audits/YYYY-MM-DD-forensic-<topic>.md (terminal artifact)"
    depends_on: [7]
```

Заметьте:
- **Никаких `constraints:`, `must_have:`, `min_mechanisms:` и т.п.** Роль сама знает, что производить — `note:` текстовое, не JSON-schema (D-3).
- **`produces:`** — kebab-case имя артефакта (контракт). **`note:`** — free-form human-reading описание. **`consumes:`** — список имён артефактов от предыдущих шагов (data flow). **`depends_on:`** — control flow (после какого шага). См. §Artifact model.
- **`gate: manual`** вместо `role: human` (D-HG). Human — не роль Runtime, не capability provider. planner печатает это как manual-gate step. Существующие 7 SOP v1.0 c `role: human` planner принимает как alias и визуализует как `gate: manual` (backend-compat).
- В step 4 Attribute Analysis: `consumes: [signal-inventory, control-objects-matrix]` но `depends_on: [3]` — control-flow от 3, а data-flow от двух артефактов шагов 3 и 1. Пример расходения; позволяет будущим ролям явно декларировать потребление, не «оркестрируя» полное depends_on (step 2 уже после step 1, step 1's artifact доступен).
- `id: 8 produces: forensic-report` — terminal artifact. Сохраняется в репо как `docs/audits/YYYY-MM-DD-forensic-<topic>.md`. На v1.1 без executor'a этот contract лишь декларация (human знает, какой final artifact он должен собрать); будущий executor (v1.2) превращает «terminal artifact» в persist-commit.

### Формат SOP `sops/architecture-review.yaml` (упрощённый)

```yaml
name: architecture-review
description: Formal review-pipeline DAG (reality → arch review → doc review → adversary optional → human)
triggers:
  - PR touching docs/specs/drafts/ or docs/specs/review/
  - PR flagged with [architecture-review] label
input:
  required:
    - type: spec
      path_pattern: docs/specs/{drafts,review}/*.md
      artifact: subject-spec
output:
  - artifact: arch-review-report
    path: docs/audits/YYYY-MM-DD-arch-review-<slug>.md
    type: audit
    status: draft
steps:
  - id: 1
    name: Reality reconstruction
    capability: state-reconstruction
    role: reality-auditor
    platform: any
    consumes: [subject-spec]
    produces: reality-report
    note: "current state report — feature inventory, drift, architectural reality"
    depends_on: []
  - id: 2
    name: Architecture review against REAL state
    capability: review-spec
    role: architecture-reviewer
    platform: any
    consumes: [reality-report, subject-spec]
    produces: architecture-findings
    note: "findings: invariants, drift, missing ADRs, security"
    depends_on: [1]   # D-5: sequential, НЕ parallel
  - id: 3
    name: Documentation review
    capability: validate-frontmatter
    role: documentation-reviewer
    platform: any
    consumes: [subject-spec]
    produces: documentation-report
    note: "Schema v1 compliance + entity_refs validity"
    depends_on: [2]
  - id: 4
    name: Adversary validation (опционально, decision gate human)
    capability: claim-validation
    role: adversary-checker
    platform: any
    consumes: [architecture-findings]
    produces: validated-findings
    note: "per-finding verdicts (SUSTAINED/WEAKENED/REFUTED) + confidence matrix"
    depends_on: [1, 2]   # control flow: после обоих; data flow: consumes только от step 2 (reality-report уже embedded в findings)
    condition: manual    # D-8: human decides на шаге 5
  - id: 5
    name: Human decision gate
    gate: manual         # D-HG: НЕ role: human — human не роль Runtime
    consumes: [architecture-findings, documentation-report, validated-findings]
    produces: decision-gate-result
    note: "approve / request-changes / reject + trigger step 4 if needed"
    depends_on: [3]
```

> **Ambiguity removed:** в step 5 control-flow `depends_on: [3]`, но data-flow `consumes: [architecture-findings, documentation-report, validated-findings]` (step 4). Это ** правильно и нормально**, т.к. step 4 — опциональный (`condition: manual`); если gate-skip step 4, артефакт `validated-findings` не производится и `consumes:` имеет одно меньше. На v1.1 без executor'a это просто контракт-декларация; на v1.2 executor будет проверять arity consumes vs available artifacts.
>
> **Terminal artifact:** `decision-gate-result` — на v1.1 не сохраняется в репо, используется для human-action (approve/reject/changes-requested). Промежуточный артефакт пайплайна.

### Bootstrap CLAUDE.md snippet изменение

После существующих 5 правил добавить 2 (идемпотентно, через `grep -q`):
```
6. Если задача связана с архитектурным review — посмотри sops/architecture-review.yaml; фундамент — reality-auditor перед architecture-reviewer.
7. Общие базы знаний лежат в `docs/.runtime/naprolom-docs/knowledge/` (architecture-principles, evidence-model, audit-principles, report-formats, capabilities) — роли ссылаются на них через short-id, не inline'ят.
```

## Affected files

### NEW
- `docs/specs/drafts/2026-07-08-agentic-layer.md` — этот файл
- `docs/adr/001-agentic-layer-separation.md` — dogfood ADR (D-2)
- `knowledge/README.md`
- `knowledge/architecture-principles.md`
- `knowledge/evidence-model.md`
- `knowledge/audit-principles.md`
- `knowledge/report-formats.md` (merged — replacement output templates + review-output-format)
- `knowledge/capabilities.md` — NEW (D-CC): capability catalog — канал контракт capabilities; не в agents/README
- `agents/claude-code/reality-auditor.md`
- `agents/opencode/reality-auditor.md`
- `agents/claude-code/adversary-checker.md`
- `agents/opencode/adversary-checker.md`
- `sops/architecture-review.yaml`
- `sops/forensic-audit.yaml`

### MODIFIED
- `agents/claude-code/architecture-reviewer.md` — refactor to slim + `capabilities:` field
- `agents/opencode/architecture-reviewer.md` — mirror
- `agents/claude-code/documentation-reviewer.md` — добавить `capabilities:` в FM (минимальное)
- `agents/opencode/documentation-reviewer.md` — mirror
- `agents/README.md` — extended: 4 roles + overview раздел capabilities (указатель на `knowledge/capabilities.md`) + Knowledge refs section + layout. **NO capability definitions inline** — каталог живёт в `knowledge/capabilities.md`
- `sops/README.md` — extended: 2 новых SOP + capabilities overview + parametrized input note + «SOP = orchestration, not validation» + «Artifact contracts» clarifier (что такое `consumes:`/`produces:`)
- `sops/planner.mjs` — ~15 строк: проверка либо `role:`, либо `capability:` (warning на capability-only без role); печать `consumes →` `produces` между шагами в DAG visualization
- `README.md` — layout + What you get + Changelog v1.1
- `INSTALL.md` — knowledge/ mention в architecture diagram
- `bootstrap/bootstrap.sh` — CLAUDE.md snippet +2 строки
- `bootstrap/bootstrap.ps1` — mirror
- `.github/workflows/docs-validate.yml` — +1 step `ROOT=knowledge bash engine/validators/validate-frontmatter.sh knowledge`

### DELETED
- `docs/specs/drafts/agentic.md` — raw source; содержимое сохранено в git history (commit после Phase G2). Не дублируем verbatim в spec (см. §Appendix A note).

## План работ (Work Plan)

### Phase 0 — Bootstrap path migration (D-BR)
**Сначала — фундаментальный фикс**, потом всё остальное. Меняется только **где bootstrap разворачивает Runtime в consumer-репо**: с `.context/runtime/naprolom-docs/` на `docs/.runtime/naprolom-docs/`. Внутренняя структура `naprolom-docs` (продукта) НЕ меняется.
0.1. `bootstrap/bootstrap.sh`:
   - `RUNTIME_ROOT` (submodule mount path detection) — оставить как есть (он определяется из расположения bootstrap.sh внутри `naprolom-docs`, это не зависит от того, КУДА mounted сам `naprolom-docs`).
   - комментариев в header: обновить пути «Run from the ROOT of the consumer project» — вместо `.context/runtime/naprolom-docs/bootstrap/bootstrap.sh` указать `docs/.runtime/naprolom-docs/bootstrap/bootstrap.sh`.
   - check_gitmodules_path(): новый helper (идемпотент), который проверяет что `.gitmodules` указывает на `docs/.runtime/naprolom-docs`, а НЕ на `.context/runtime/naprolom-docs`. Если v1.0 path найден — warn-only на v1.1 (consumers могут мигрировать сами через `git mv`). Это **advisory check**, не блокирующий bootstrap.
   - във `CLAUDE.md` snippet paths: `.context/runtime/naprolom-docs/...` → `docs/.runtime/naprolom-docs/...`.
0.2. `bootstrap/bootstrap.ps1` — mirror 0.1 (PS-синтаксис, single-quoted strings).
0.3. `INSTALL.md` — все примеры команд (`git submodule add ...`, `git submodule update --remote`, `bash .context/runtime/naprolom-docs/...`, `.gitmodules` блок) переключить на `docs/.runtime/naprolom-docs/`. Architecture diagram — обновить consumer side: `docs/` содержит user-content + `.runtime/`. Добавить новый §«Two-repo model» subsection, объясняющий продукт vs consumer (gender с описанием D-BR). В.Importantly: **бoльшой subsection про self-vs-consumer** для явного разграничения.
0.4. `playbook/playbook-v2.md` — в §Bootstrap section указать путь к bootstrap.sh через `docs/.runtime/...`. В §Phase 1, §Phase 3, §Phase 4, §Canon Source of Truth — все `cp .context/runtime/naprolom-docs/engine/templates/...` → `cp docs/.runtime/naprolom-docs/engine/templates/...`. В §CI Schema v1 Guard — `bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh`.
0.5. `playbook/migrate-legacy.md` — если упоминаются пути к migrate-legacy.mjs — обновить на `docs/.runtime/...`. Проверить grep.
0.6. `playbook/install-remote-prompt.md` — проверить/обновить пути в инструкциях для remote agent.
0.7. `README.md` — Quick Start команды (`bash .context/runtime/naprolom-docs/...`) → `docs/.runtime/naprolom-docs/...`. Layout diagram consumer-раздел обновить.
0.8. `agents/README.md`, `sops/README.md` — любые упоминания `.context/runtime/...` → `docs/.runtime/...`.
0.9. Existiong agent role files (`agents/claude-code/*.md`, `agents/opencode/*.md`) — в operating protocol могут быть hardcoded `.context/runtime/...` пути (например, architecture-reviewer ссылается `.context/runtime/naprolom-docs/playbook/playbook-v2.md`). Обновитьвсе на `docs/.runtime/naprolom-docs/...`. Это часть Phase B refactor, но пути фиксируются здесь, чтобы не пересекать concerns (refactor slim + path migration в одном шаге).
0.10. `.github/workflows/docs-validate.yml` — в `run:` блоке обновить путь к валидатору на `docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh` (в **самом naprolom-docs** репо — валидатор лежит в `engine/`, путь остаётся локальным; это про **consumer workflow**, который install-remote-prompt копирует в consumer-репо).
0.11. `engine/validators/validate-frontmatter.sh` header — обновить example usage пути.
0.12. `engine/scripts/migrate-legacy.mjs` header comments — обновить примеры consumer invocation.

> Phase 0 — это **sweep across all doc files**. Грep по `.context/runtime` в репо `naprolom-docs` должен вернуть 0 matches после Phase 0 (кроме этого spec файла, где v4-changelog и §Two-repo model могут упоминать старый путь в historical comparison — это OK).

### Phase A — Knowledge layer (минимум, без переусложнения)
A1. `knowledge/README.md` — index, объясняющий role knowledge refs.
A2. `knowledge/architecture-principles.md` — извлечь из Appendix A `architecture-reviewer.md` §«Принципы анализа» (14 + 3 мета). FM: `type: guide, kind: index, status: active, owners: [naprolom-team]`, `id: knowledge-architecture-principles`.
A3. `knowledge/evidence-model.md` — из Appendix A `reality-auditor.md` §«Trust Hierarchy» + §«Evidence Classification» + §«Behavioral Rules». FM аналогично.
A4. `knowledge/audit-principles.md` — из Appendix A `adversary-checker.md` §«5-Stage Validation Protocol» + §«Verdict System» + §«Confidence Model» + §«Behavioral Constraints».
A5. `knowledge/report-formats.md` — нормализованное описание выходных форматов 4 ревьюеров (architecture-review / reality-audit / adversary-report / forensic-report) из их inline-блоков в Appendix A. Один файл.
A6. `knowledge/capabilities.md` — NEW (D-CC): capability catalog. Содержание per-capability entry: description, consumes, produces, **WITHOUT `provided by:`** (D-CP —单向 Role→Capability в Role FM, не в каталоге). Формат:
   ```
   ## capability: review-spec
   Description: <one-line>
   Consumes: spec (artifact), reality-report (artifact)
   Produces: architecture-findings (artifact)
   ```
   «Role→Capability» mapping живёт в `agents/README.md` overview-таблице (см. E4), **не здесь**.

### Phase B — Roles
> Все roles декларируют knowledge refs в FM как **short-id list** (D-KR): `knowledge: [architecture-principles, report-formats]`. **Никаких hardcoded `knowledge/...path...md` путей в теле роли.** Тело роли ссылается на knowledge по short-id в prose («See knowledge: architecture-principles»), Runtime резолвит путь при подгрузке.

B1. Refactor `agents/claude-code/architecture-reviewer.md`:
   - Slim: System Prompt / When / Operating protocol / Refusal / What you do NOT do.
   - FM additions:
     ```yaml
     capabilities: [review-spec, review-adr, review-domain-model, review-security-model]
     knowledge: [architecture-principles, report-formats]
     ```
   - Убрать 14 inline принципов и output-format блок.
B2. Mirror B1 в `agents/opencode/architecture-reviewer.md` + opencode-style FM (`description`, `mode: subagent`, `permission`, `color`, `hidden`).
B3. Minimal touch `agents/claude-code/documentation-reviewer.md` + `.opencode` mirror — добавить в FM:
   ```yaml
   capabilities: [validate-frontmatter, validate-entity-refs]
   knowledge: [report-formats, schema-v1]
   ```
B4. Create `agents/claude-code/reality-auditor.md`:
   - System Prompt (Reality Auditor), When you run, Operating protocol (7-stage), Refusal (no recommendations, no judgments; state reconstruction only), What you do NOT do (no tests/build/deploy).
   - FM:
     ```yaml
     capabilities: [state-reconstruction, drift-analysis, architecture-extraction, attribution-analysis]
     knowledge: [evidence-model, report-formats]
     ```
   - Permissions: `read: allow`, `bash: ask` (read-only whitelist: `git log/diff/show/blame`, `find`, `grep`, `tree`, `ls`, `wc`), `edit: deny`, `webfetch: allow`.
B5. Mirror B4 в `agents/opencode/reality-auditor.md`.
B6. Create `agents/claude-code/adversary-checker.md`:
   - System Prompt (Claim Validation), Input (Finding Set), 5-stage protocol (prose ссылается на knowledge: audit-principles), Output (prose ссылается на knowledge: report-formats), Refusal, Stalemate Protocol, What you do NOT do.
   - FM:
     ```yaml
     capabilities: [claim-validation, assumption-analysis]
     knowledge: [audit-principles, report-formats]
     ```
   - Permissions: `read: allow`, `bash: deny`, `edit: deny`, `webfetch: allow`.
B7. Mirror B6 в `agents/opencode/adversary-checker.md`.

### Phase C — SOPs (упрощённые, с artifact contracts)
C1. `sops/forensic-audit.yaml` — как в §Technical approach: `consumes:`/`produces:`/`note:`/`depends_on:`, без `constraints:`.
C2. `sops/architecture-review.yaml` — sequential DAG (D-5), с artifact contracts (`reality-report` → `architecture-findings` → `documentation-report` → `validated-findings` → `decision-gate-result`).

### Phase D — planner extension (минимальное)
D1. `sops/planner.mjs` — добавить в парсер шагов чтение `capability:` (опционально) + `role:` (опционально, но хотя бы один из двух обязателен; иначе warning). Если step указывает `capability:` без `role:` — warning. Также читать `consumes:`/`produces:` и печатать их в DAG visualization рядом с control-flow `depends_on:` (data-flow arrows). Не более ~15 строк кода, никакой логики executor'а.

### Phase E — Documentation & dogfood
E1. `docs/adr/001-agentic-layer-separation.md` — dogfood ADR. FM: `id: adr-001-agentic-layer-separation, type: adr, status: accepted, date: 2026-07-08, owners: [naprolom-team]`. Body: Status / Context / Decision / Consequences. Decision описывает **5-слойную модель** (Knowledge / Role / Capability / SOP / Artifact), rationale, почему не переименовали `agents/` → `roles/`, почему output templates влит в knowledge, почему capability каталог живёт в `knowledge/capabilities.md`.
E2. `README.md` — обновить layout diagram (+ `knowledge/`, включая `capabilities.md`), What you get расширить до 4 ролей + 6 knowledge + 9 SOPs, Changelog добавить `v1.1 — agentic layer: Knowledge/Role/Capability/SOP/Artifact separation`.
E3. `INSTALL.md` — architecture diagram с `knowledge/`.
E4. `agents/README.md` — extended таблица roles (4) с колонкой capabilities (Role→Capability单向, это и есть providers mapping — см. D-CP); раздел «Capabilities» (overview + указатель на `knowledge/capabilities.md`, **БЕЗ inline capability definitions** — каталог живёт там); раздел «Knowledge refs» (короткий: объясняет short-id формат в Role FM `knowledge: [...]` и что путь резолвит Runtime); обновить layout.
E5. `sops/README.md` — добавить 2 новых SOP; раздел про parametrized input (`entities`/`mechanisms` в forensic-audit) с примером; clarifier «SOP описывает **оркестрацию**, не validation logic»; новый раздел «Artifact contracts» с пояснением `consumes:`/`produces:` и разницей data-flow vs control-flow (`depends_on:`); заметка про `gate: manual` для human steps (D-HG, с backend-compat note про `role: human` в существующих 7 SOP v1.0).
E6. `bootstrap/bootstrap.sh` — CLAUDE.md snippet +2 строки (идемпотентно, через `grep -q`).
E7. `bootstrap/bootstrap.ps1` — mirror E6 PS-синтаксис.

### Phase F — CI & validation
F1. `.github/workflows/docs-validate.yml` — добавить второй шаг:
   ```yaml
   - name: Validate knowledge/ frontmatter
     run: ROOT=knowledge bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh knowledge
   ```
F2. Smoke test локально: `ROOT=docs bash engine/validators/validate-frontmatter.sh` и `ROOT=knowledge bash engine/validators/validate-frontmatter.sh knowledge` — оба должны `OK`.
F3. `node sops/planner.mjs forensic-audit --platform opencode` — печатает DAG с data-flow arrows (consumes → produces), control-flow (depends_on), gate-шаги как `gate: manual`. **Planner НЕ должен читать содержимое `knowledge/`** (D-PL) — только roles (`agents/{platform}/` *.md FM), capabilities (per-role FM), SOP (`sops/*.yaml`).
F4. `node sops/planner.mjs architecture-review --platform opencode` — печатает sequential DAG (step 2 depends on step 1), step 5 как `gate: manual`.
F5. Dogfood self-review: вызвать `architecture-reviewer` на этом spec; применить corrections из findings.

### Phase G — Cleanup & commit
G1. Удалить `docs/specs/drafts/agentic.md` (raw input preserved via git history). **ВЫПОЛНЕНО в начале v3-правок.**
G2. Single commit `feat(runtime): v1.1 agentic layer — knowledge/, capabilities, +2 roles, architecture-review + forensic-audit SOPs`.
G3. НЕ пушить. Показать `git diff` пользователю для final review.

## Open questions (минимум, все unresolved ранее — resolved в §Decisions)

Все первоначальные Open Questions разрешены в §Decisions (D-1 ÷ D-9 + D-OT/D-P/D-C/D-A/D-CC/D-CP/D-KR/D-PL/D-HG). Остаются 2 вторичных, не блокирующих:

Q-1. После Phase E: трактовать созданный `docs/adr/001-...` как полноправный canonical ADR (валидировать его через `validate-frontmatter.sh` на strict-CI)? Рекомендация: **да** (он лежит в `docs/adr/`, валидатор уже покрывает — это и есть dogfood proof).

Q-2. В `knowledge/capabilities.md` на v1.1 — публиковать per-capability entry с **consumes/produces** artifact contract (полный контракт) или достаточно **description-only**? Рекомендация: **полный contract** (description + consumes + produces + artifacts) — без `provided by:` (см. D-CP). Capabilities.md создан ради того, чтобы быть контрактом, а не списком имён.

## Out-of-scope follow-up (v1.2 candidate)

Вне этой спецификации, но предложено ревизором как будущая доработка. **Не блокирует v1.1 релиз** — Runtime уже работоспособен; эти улучшения скорее polish.

### Структурные
- **`runtime/` wrapper внутри naprolom-docs.** Внутри репо продукта — обернуть `engine/` + `bootstrap/` в один каталог `runtime/`, чтобы корень продукта стал минимально чистым:
  ```
  README.md INSTALL.md
  runtime/   (engine, bootstrap, ...)
  agents/  knowledge/  sops/  docs/  .github/
  ```
  Это **не влияет на consumer'а** (в consumer'е всё уже локализовано в `docs/.runtime/naprolom-docs/...` благодаря D-BR). Изменение касается только читаемости репо `naprolom-docs` (продукта). Низкий приоритет — layout продукта уже приемлемый.
  В v1.1 НЕ ВХОДИТ — фиксируется здесь как roadmap reference.

### Knowledge layer refactor
- **Группировка `knowledge/` по домену**, а не по происхождению от ролей. Например:
  ```
  knowledge/
    architecture/   (principles.md, anti-fragility.md, decision-making.md)
    documentation/  (schema-v1.md, entity-model.md)
    review/         (evidence.md, confidence.md, reports.md)
    capabilities.md
  ```
  Почему отложено: на v1.1 knowledge-файлов всего 5 (4 содержательных + README), группировка преждевременна и усложнит пути. Когда files > 10 — пересмотреть.

### SOP/Role契约
- **Knowledge loading из SOP, не из Role.** v1.1 уже ввёл **short-id knowledge refs** в Role FM (D-KR): `knowledge: [architecture-principles]` — путь резолвит Runtime. Следующий шаг v1.2: декларировать `knowledge_refs:` на уровне SOP-шага, чтобы Role был полностью переносимым (без знания о knowledge paths в FM). Инвазивно (требует переписать Roles + расширить planner), отложено.
- **Capability-only SOP шаги (option 3).** Пока planner warning'ает; в v1.2 — резолв capability → role через `knowledge/capabilities.md` automatically, с platform preference. На v1.1 каталог capabilities полностью decoupled от providers (D-CP), что уже подготовило почву.
- **SOP `forensic-audit.yaml` фазы (Control Objects, Signal Inventory и т.д.) вынести в knowledge.** Сейчас 8 фаз описаны как `name:`+`note:` в самом SOP; их содержательное описание (что именно искать, какие hypotheses проверять) может жить в `knowledge/forensic-audit-protocol.md` и подгружаться шагом. Отложено: на v1.1 `note:` поля достаточно для executor'a; если SOP разрастётся — вынесем.

### Execution layer (Major — v2.0)
- **executor** (retry/scheduler/parallel/resume/checkpoint). Явно отклонено в D-3/D-P. Если реальная потребность возникнет после dogfooding — это уже v2.0 с самостоятельной архитектурой.

## Appendix A: Raw input preservation

> Исходный файл `docs/specs/drafts/agentic.md` (2168 строк, 4 raw agent prompt'а + architectural critique) сохраняется до Phase G1. После удаления доступен через git history (commit SHA после Phase G2). Verbatim-копия НЕ вставлена в spec во избежание раздувания файла до 2200+ строк; план сохранения пути указан.

## Result
<!-- Заполняется после реализации -->