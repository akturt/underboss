---
schema: 1
id: architecture-readme
type: architecture
status: active
date: 2026-07-09
owners: [naprolom-team]
---

# Architecture Overview

## Project Identity

- Name: naprolom-docs
- Domain: unknown
- Stack: unknown

## Stack

| Layer | Technology |
|-------|-----------|
| Backend | TBD |
| Database | TBD |
| Infrastructure | TBD |

## Project Layout

```
naprolom-docs/
  docs/
    architecture/     # topology, domain model, invariants
    adr/              # Architecture Decision Records
    specs/            # specifications (draft → review → approved → implemented)
    audits/           # audit reports, reality checks
    backlog/          # backlog, TODO, wishlist
    api/              # API documentation
  src/                # application source code
  tests/              # tests
  .context/           # runtime context
```

## Boundaries

See `.context/boundaries.yml` for detailed boundary definitions.

- **Pristine**: naprolom-docs/, src/, tests/, docs/, .context/
- **Editable**: docs/** (except runtime/)
- **Generated**: docs/.runtime/, node_modules/
- **Secret**: .env, *.key, *.pem

## See Also

- [ADR](../adr/) — Architecture Decision Records
- [Backlog](../backlog/) — TODO, Wishlist, Experiments
- [Boundaries](../../.context/boundaries.yml) — Boundary definitions
