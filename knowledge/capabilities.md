---
schema: 1
id: knowledge-capabilities
type: guide
kind: index
status: active
date: 2026-07-08
owners: [underboss-team]

entity_refs: [runtime-agentic-layer]
tags: [knowledge, capabilities, catalog, contract]
priority: P1
---

# Capability Catalog

Capability contract. Contains **only the Contract** (description / consumes / produces / artifacts), **without `provided by:`** (D-CP — a one-way Role→Capability reference in the Role FM).

## review-spec
Description: Architecture review of specification documents against real project state.
Consumes: spec (artifact), reality-report (artifact)
Produces: architecture-findings (artifact)

## review-adr
Description: Review of Architecture Decision Records for lifecycle compliance and body immutability.
Consumes: adr (artifact)
Produces: architecture-findings (artifact)

## review-domain-model
Description: Review of domain model for consistency, drift, and architectural fitness.
Consumes: domain-model (artifact), reality-report (artifact)
Produces: architecture-findings (artifact)

## review-security-model
Description: Review of security model (RBAC, authn, authz) for drift and compliance.
Consumes: security-model (artifact), reality-report (artifact)
Produces: architecture-findings (artifact)

## validate-frontmatter
Description: Schema v1 frontmatter validation across all docs/**/*.md files.
Consumes: changed-files (artifact)
Produces: documentation-report (artifact)

## validate-entity-refs
Description: Entity reference integrity check — entity_refs exist in docs/architecture/.
Consumes: changed-files (artifact)
Produces: documentation-report (artifact)

## state-reconstruction
Description: Reconstruct current project state from code, config, and docs. Read-only investigation.
Consumes: subject-document (artifact)
Produces: reality-report (artifact)

## drift-analysis
Description: Compare documented state against actual code/config state to find discrepancies.
Consumes: reality-report (artifact)
Produces: reality-report (artifact)

## architecture-extraction
Description: Extract actual architecture (modules, dependencies, ownership) from codebase.
Consumes: reality-report (artifact)
Produces: reality-report (artifact)

## attribution-analysis
Description: Trace signals to their sources, determine attribution confidence.
Consumes: signal-inventory (artifact), control-objects-matrix (artifact)
Produces: attribution-analysis (artifact)

## claim-validation
Description: Validate architectural claims against evidence. Assign verdicts and confidence levels.
Consumes: architecture-findings (artifact)
Produces: validated-findings (artifact)

## assumption-analysis
Description: Identify and challenge implicit assumptions in architectural proposals.
Consumes: architecture-findings (artifact)
Produces: validated-findings (artifact)
