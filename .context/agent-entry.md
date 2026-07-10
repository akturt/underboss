# Agent Entry Point

This project uses **Underboss Runtime v2.0.0**.

## Your first action

```bash
bash docs/.runtime/underboss/engine/reality-engine/reporters/reality-report.sh .
```

Then open `docs/REALITY-REPORT.md` (or the generated artifact it points to) and act on the drift items listed there.

## Where to look

| Area | Purpose |
|------|---------|
| `bootstrap/DEPLOY-PROMPT.md` | Full autonomous install / upgrade prompt (send to your AI agent) |
| `docs/` | Project documentation (authoritative output) |
| `docs/.runtime/underboss/` | Runtime git submodule — do not edit directly |
| `.context/` | Local project snapshot — boundaries, metadata, agent state |
| `README.md` | Installation overview |

## Boundaries

Read `.context/boundaries.yml` before writing anything. Paths are relative to repo root.

## Do not

- Edit files inside `docs/.runtime/underboss/` by hand — update via submodule.
- Commit secrets (`.env`, `*.key`, `*.pem`, `secrets/`).
- Write to paths listed under `pristine` in `.context/boundaries.yml`.
