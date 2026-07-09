---
schema: 1
id: knowledge-report-formats
type: guide
kind: index
status: active
date: 2026-07-08
owners: [naprolom-team]

entity_refs: [runtime-agentic-layer]
tags: [knowledge, report, format, output]
priority: P1
---

# Report Formats

Выходные форматы 4 ревьюеров. Roles используют как шаблон вывода.

## Architecture Review

```
## Architecture Review

Verdict: APPROVED | REQUEST_CHANGES | REJECTED

### Findings
[F-01] (severity: high|medium|low)
File: path/to/file.md:LINE
Issue: <what's wrong>
Recommendation: <how to fix>
Evidence: <file path / line / diff snippet>

### Invariants verified
- INV-N: PASS/FAIL (one line per critical invariant)

### Must-do before merge
- [ ] (only if REQUEST_CHANGES / REJECTED)

### Architectural context read
- ADR-NUM: understood
- INV-N: verified
- module-index: confirmed up to date
```

## Reality Audit

```
## Reality Audit — Current State Report

### Feature Inventory
| Feature | Status | Evidence | Class |
|---------|--------|----------|-------|
| <name>  | exists/missing/drift | <evidence> | OBSERVED/EVIDENCED/INFERRED |

### Drift Analysis
| Expected (docs) | Actual (code) | Delta | Severity |
|-----------------|---------------|-------|----------|
| <doc claim>     | <observation> | <diff> | high/medium/low |

### Architecture Extraction
| Module | Responsibility | Dependencies | Owner |
|--------|---------------|--------------|-------|
| <name> | <desc>        | <list>       | <who> |

### Confidence Summary
- OBSERVED: N facts
- EVIDENCED: N facts
- INFERRED: N facts
- CLAIMED: N facts

### Open Questions
- <unresolved items with INSUFFICIENT_EVIDENCE>
```

## Adversary Report

```
## Adversary Validation Report

### Verdict Summary
| Finding | Verdict | Confidence | Evidence Chain |
|---------|---------|------------|----------------|
| F-01    | SUSTAINED/WEAKENED/REFUTED/INSUFFICIENT | HIGH/MEDIUM/LOW | <sources> |

### Per-Finding Detail
#### F-01: <finding title>
- **Claim**: <decomposed claim>
- **Evidence found**: <level + source>
- **Verdict**: <verdict>
- **Confidence**: <level>
- **Reasoning**: <how evidence leads to verdict>

### Contradictions
- <any conflicting evidence between findings>

### Open Questions
- <INSUFFICIENT_EVIDENCE items requiring human review>

### Aggregate
- Total findings: N
- SUSTAINED: N | WEAKENED: N | REFUTED: N | INSUFFICIENT: N
```

## Forensic Report

```
## Forensic Audit Report

### 1. Control Objects Identification
<entities × capabilities matrix with evidence>

### 2. Actual Control Plane Entity
<answer + mechanisms + code_refs + confidence>

### 3. Signal Inventory
<external/internal signals × granularity/attribution>

### 4. Attribution Analysis
<per-source attribution: hard/probabilistic/impossible>

### 5. Multi-Binding Reality Check
<verdict + evidence + contradictions>

### 6. Runtime Ownership Analysis
<runtime_owner + per-attribute owner + conflict_behavior>

### 7. Reputation Layer Design
<layer_responsibilities + unified_identity_exists?>

### 8. Final Recommendation
<adr_recommendation + risk_register + open_questions>
```

### Terminal Artifact
The forensic report is saved as `docs/audits/YYYY-MM-DD-forensic-<topic>.md`.
