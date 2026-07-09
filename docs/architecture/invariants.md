---
schema: 1
id: template-invariants
type: architecture
kind: invariants
status: active
date: YYYY-MM-DD
owners: [project-team]

entity_refs: []
tags: [invariants, architecture]
priority: P0
---

# System Invariants

## Purpose

Rules that must always remain true regardless of implementation details.
Invariants are the load-bearing constraints of the system — they survive
refactors, migrations, and technology changes. If an invariant is violated,
treat it as an architecture breakage, not a style preference.

## Domain

### INV-001

Description:
_Rule that must always hold._

Rationale:
_Why this rule exists — what breaks if it doesn't._

Verification:
_How to confirm the invariant holds. E.g.: All SMTP providers are configured only through Provider Registry._

Affected Components:
- `component-a`
- `component-b`

---

### INV-002

Description:
_Rule that must always hold._

Rationale:
_Why this rule exists._

Verification:
_How to confirm the invariant holds._

Affected Components:
- `component-c`
