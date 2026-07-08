---
schema: 1
id: knowledge-audit-principles
type: guide
kind: index
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer]
tags: [knowledge, audit, validation, adversary, confidence]
priority: P1
---

# Audit Principles

5-Stage Validation Protocol, Verdict System и Confidence Model для `adversary-checker`.

## 5-Stage Validation Protocol

Каждый claim из `architecture-findings` проходит 5 этапов:

### Stage 1: Claim Decomposition
Разбить каждый finding на отдельные, проверяемые claims:
- **Factual claim** — "файл X существует / не существует"
- **Causal claim** — "изменение Y привело к Z"
- **Normative claim** — "следует сделать X" (только factual часть проверяется)

### Stage 2: Evidence Hunt
Для каждого claim найти подтверждающие или опровергающие данные:
- Level 1-2 evidence (verified/direct) — strongest
- Level 3-5 evidence (derived/inferred) — contextual
- Absence of evidence — не evidence of absence

### Stage 3: Verdict Assignment
Каждый claim получает вердикт:

| Verdict | Определение |
|---------|-------------|
| **SUSTAINED** | Claim подтверждён Level 1-2 evidence |
| **WEAKENED** | Claim частично подтверждён, но есть противоречия Level 3-4 |
| **REFUTED** | Claim опровергнут Level 1-3 evidence |
| **INSUFFICIENT_EVIDENCE** | Недостаточно данных для вердикта (Level 5-7) |

### Stage 4: Confidence Matrix
Для каждого verdict — confidence level:

| Confidence | Критерий |
|------------|----------|
| **HIGH** | Level 1-2 evidence, keine contradictory data |
| **MEDIUM** | Level 3-4 evidence, minor contradictions |
| **LOW** | Mixed levels, significant gaps, or Level 5+ reliance |

### Stage 5: Synthesis
Объединить individual verdicts в общий отчёт:
- Общий verdict по каждому finding
- Confidence matrix (finding × verdict × confidence)
- Open questions (INSUFFICIENT_EVIDENCE items)
- Contradictions между findings

## Verdict System

### Per-Finding Verdict
Каждый finding из architecture-review получает:
- **Verdict**: SUSTAINED / WEAKENED / REFUTED / INSUFFICIENT_EVIDENCE
- **Confidence**: HIGH / MEDIUM / LOW
- **Evidence chain**: sources used for this verdict
- **Reasoning**: как evidence приводит к verdict

### Aggregate Verdict
Общий результат adversary-check:
- **All SUSTAINED** → findings validated, proceed
- **Mixed** → report具体情况, human decides
- **Any REFUTED** → findings need revision
- **Any INSUFFICIENT** → more data needed

## Confidence Model

### Sources of Confidence
- **Evidence quality** (Level 1-2 = high, Level 5-7 = low)
- **Evidence quantity** (multiple independent sources = higher)
- **Consistency** (no contradictions = higher)
- **Recency** (current data = higher than stale)

### Confidence Degrades When:
- Claims rely on Level 5+ evidence
- Contradictory evidence exists
- Data is stale (>30 days for code, >7 days for config)
- Chain of reasoning is long (>3 hops)

## Behavioral Constraints

1. **No new claims** — adversary-checker проверяет claims других, не генерирует новые.
2. **No recommendations** — verdict + confidence, без предложений по исправлению.
3. **Read-only** — не редактирует файлы, не запускает команды (webfetch разрешён для fact-checking).
4. **Stalemate Protocol** — если adversary-checker не может определить verdict (insufficient evidence) — пометить как `INSUFFICIENT_EVIDENCE` и передать human, НЕ угадывать.
5. **Proportional scrutiny** — high-impact findings проверяются строже, low-impact — быстрее.
6. **Source attribution** — каждый verdict указывает конкретные evidence sources.
7. **No appeal to authority** — "author said so" ≠ evidence. Только данные.
