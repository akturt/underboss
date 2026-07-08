---
schema: 1
id: knowledge-evidence-model
type: guide
kind: index
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer]
tags: [knowledge, evidence, trust, reality-audit]
priority: P1
---

# Evidence Model

Trust Hierarchy, Evidence Classification и Behavioral Rules для `reality-auditor`.

## Trust Hierarchy (7 уровней)

Уровни достоверности данных, от наиболее к наименее надёжному:

| Level | Источник | Пример |
|-------|----------|--------|
| 1. **Verified Source** | CI/CD pipeline, automated test, linter | `validate-frontmatter.sh` exit 0 |
| 2. **Direct Observation** | git log/diff/blame, file content | `git show HEAD:path` |
| 3. **Derived Evidence** | Вычислено из Level 1-2 данных | Drift calculation from diff |
| 4. **Reported State** | Файлы в репо (config, docs) | `docs/architecture/README.md` |
| 5. **Inferred State** | Логический вывод из Level 1-4 | "Module X depends on Y because..."
| 6. **Stakeholder Claim** | Утверждение человека без данных | "We use microservices" |
| 7. **No Evidence** | Отсутствие какого-либо сигнала | No docs found = unknown |

### Правила
- Никогда не понижай уровень источника ниже его реального уровня.
- Level 6+ требует явной пометки `CLAIMED` в evidence matrix.
- Level 7 = "insufficient evidence", НЕ "no problem".

## Evidence Classes (4)

| Class | Определение | Маркер |
|-------|-------------|--------|
| **OBSERVED** | Напрямую подтверждено данными Level 1-2 | `[OBSERVED]` |
| **EVIDENCED** | Косвенно подтверждено Level 3-4 | `[EVIDENCED]` |
| **INFERRED** | Логический вывод из Level 1-5 | `[INFERRED]` |
| **CLAIMED** | Утверждение без подтверждающих данных (Level 6) | `[CLAIMED]` |

### Правила
- Каждый факт в reality-report помечается одним из 4 классов.
- `CLAIMED` facts требуют явного указания источника утверждения.
- `INFERRED` facts требуют указания chain of reasoning.
- Микс OBSERVED + CLAIMED в одном выводе = flag for human review.

## Behavioral Rules

1. **No recommendations** — reality-auditor констатирует факты, не предлагает исправлений.
2. **No judgments** — "this is bad" ≠ evidence. Факты нейтральны.
3. **State reconstruction only** — цель: восстановить текущее состояние, не оценить его качество.
4. **Evidence first** — каждый вывод подкреплён конкретным evidence (file path, git ref, diff snippet).
5. **Attribution required** — каждый evidence-класс указывает источник (кто/что предоставил данные).
6. **Confidence explicit** — каждый вывод имеет confidence level (high/medium/low) с обоснованием.
7. **No tests/build/deploy** — reality-auditor не запускает tests, не собирает, не деплоит. Только read-only investigation.
