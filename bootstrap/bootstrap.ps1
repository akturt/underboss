# bootstrap/bootstrap.ps1
#
# Minimal Documentation System Runtime bootstrap (Windows / PowerShell).
# Creates docs/ skeleton + .context/ stubs + drops CLAUDE.md snippet into the
# consumer repository. Idempotent. Mirrors bootstrap.sh.
#
# v1.1 (D-BR): submodule resides inside docs/.runtime/naprolom-docs/, not .context/runtime/.
#
# Usage:
#   powershell -File docs\.runtime\naprolom-docs\bootstrap\bootstrap.ps1
#   powershell -File docs\.runtime\naprolom-docs\bootstrap\bootstrap.ps1 -ProjectPath C:\path\to\project

[CmdletBinding()]
param(
  [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

if (-not $ProjectPath) {
  try {
    $ProjectPath = (git rev-parse --show-toplevel 2>$null | Out-String).Trim()
  } catch {}
  if (-not $ProjectPath) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ProjectPath = (Resolve-Path (Join-Path $ScriptDir "..\..\..")).Path
  }
}

$RuntimeRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host "-> Target project:  $ProjectPath"
Write-Host "-> Runtime root:    $RuntimeRoot"
Write-Host ""

# v1.1 (D-BR): advisory check for old v1.0 submodule path.
$gitmodules = Join-Path $ProjectPath ".gitmodules"
if (Test-Path $gitmodules) {
  $gm = Get-Content -Path $gitmodules -Raw -ErrorAction SilentlyContinue
  if ($gm -match '\.context/runtime/naprolom-docs') {
    Write-Host "WARNING: .gitmodules references legacy v1.0 path '.context/runtime/naprolom-docs'." 2>&1
    Write-Host "  v1.1 expects submodule mounted at 'docs/.runtime/naprolom-docs'." 2>&1
    Write-Host "  To migrate: git mv .context/runtime docs/.runtime && git submodule absorbgitdirs" 2>&1
    Write-Host "  (Advisory only — bootstrap continues.)" 2>&1
    Write-Host ""
  }
}

$dirs = @(
  "docs\architecture",
  "docs\adr",
  "docs\specs\drafts",
  "docs\specs\review",
  "docs\specs\approved",
  "docs\specs\implemented",
  "docs\specs\superseded",
  "docs\audits",
  "docs\backlog",
  "docs\api"
)
foreach ($d in $dirs) {
  New-Item -ItemType Directory -Force -Path (Join-Path $ProjectPath $d) | Out-Null
}
foreach ($keep in @("docs\architecture","docs\adr","docs\audits","docs\backlog","docs\api")) {
  $p = Join-Path $ProjectPath (Join-Path $keep ".gitkeep")
  if (-not (Test-Path $p)) { New-Item -ItemType File -Path $p | Out-Null }
}

$ctx = Join-Path $ProjectPath ".context"
New-Item -ItemType Directory -Force -Path $ctx | Out-Null

function Write-StubIfMissing($path, $lines) {
  if (-not (Test-Path $path)) {
    $lines | Set-Content -Path $path -Encoding utf8
  }
}

$projectYml = @(
  'project:',
  '  name: TODO-project-name',
  '  description: "TODO: 1-sentence project description"',
  '  domain: example.com',
  '  maintainer: team-name',
  '  repository: TODO',
  '',
  'stack:',
  '  backend: []',
  '  database: []',
  '  infrastructure: []',
  '',
  'directories:',
  '  key: {}'
)
Write-StubIfMissing (Join-Path $ctx 'project.yml') $projectYml

$boundariesYml = @(
  'boundaries:',
  '  pristine:',
  '    - path: docs/.runtime/',
  '      reason: "Documentation System Runtime submodule (managed by git submodule update --remote)"',
  '  editable:',
  '    - path: docs/',
  '      reason: "all user-authored documentation"',
  '  generated: []',
  '  secret: []'
)
Write-StubIfMissing (Join-Path $ctx 'boundaries.yml') $boundariesYml

$agentEntry = @(
  '# Agent Entry Protocol',
  '',
  'Read in order:',
  '1. `.context/project.yml` - what project this is',
  '2. `.context/boundaries.yml` - what is editable / pristine / secret',
  '3. `docs/architecture/README.md` - topology, invariants (create if missing)',
  '4. `CLAUDE.md` - rules',
  '',
  'Before creating any .md in docs/:',
  '1. Identify `type` (spec|adr|audit|runbook|guide|api|architecture|backlog|prompt)',
  '2. Copy template from runtime: `docs/.runtime/naprolom-docs/engine/templates/<type>.md`',
  '3. Fill the 6 mandatory fields: schema, id, type, status, date, owners',
  '4. Never add `lifecycle:` to frontmatter (computed from path for specs/api)',
  '5. Never add legacy fields: author, title, created, referenced_by, supersedes_adr, excludes-from-scope'
)
Write-StubIfMissing (Join-Path $ctx "agent-entry.md") $agentEntry

$snippet = @(
  '## Documentation Runtime',
  '',
  'Documentation System Runtime is connected as a Git Submodule:',
  '',
  '    docs/.runtime/naprolom-docs/',
  '',
  'Before any change to `docs/`:',
  '1. Study `docs/.runtime/naprolom-docs/playbook/playbook-v2.md` (target model)',
  '2. Use `docs/.runtime/naprolom-docs/engine/templates/` - do NOT copy templates into the project',
  '3. Follow `docs/.runtime/naprolom-docs/engine/schemas/frontmatter.schema.json`',
  '4. Run `docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh` before commit',
  '5. For brownfield migration, follow `docs/.runtime/naprolom-docs/playbook/migrate-legacy.md`',
  '6. For typical processes, pick a SOP in `docs/.runtime/naprolom-docs/sops/` and run `node docs/.runtime/naprolom-docs/sops/planner.mjs <name>` - call roles by name',
  '7. If task involves architectural review - see `docs/.runtime/naprolom-docs/sops/architecture-review.yaml`; foundation is `reality-auditor` BEFORE `architecture-reviewer`.',
  '8. Common knowledge bases live in `docs/.runtime/naprolom-docs/knowledge/` (`architecture-principles`, `evidence-model`, `audit-principles`, `report-formats`, `capabilities`) - roles reference them by short-id, not inline.'
)

$claude = Join-Path $ProjectPath "CLAUDE.md"
if (Test-Path $claude) {
  $existing = Get-Content -Path $claude -Raw -ErrorAction SilentlyContinue
  if ($existing -notmatch "## Documentation Runtime") {
    $newContent = ($snippet -join "`n") + "`n`n" + $existing
    $newContent | Set-Content -Path $claude -Encoding utf8
    Write-Host "-> Prepended 'Documentation Runtime' section to existing CLAUDE.md"
  } else {
    Write-Host "-> CLAUDE.md already has 'Documentation Runtime' section, skipped"
  }
} else {
  $snippet | Set-Content -Path $claude -Encoding utf8
  Write-Host "-> Created CLAUDE.md with Documentation Runtime snippet"
}
} else {
  $snippet | Set-Content -Path $claude -Encoding utf8
  Write-Host "-> Created CLAUDE.md with Documentation Runtime snippet"
}

$wfDir = Join-Path $ProjectPath ".github\workflows"
New-Item -ItemType Directory -Force -Path $wfDir | Out-Null
$wf = Join-Path $wfDir "docs-validate.yml"
if (-not (Test-Path $wf)) {
  $wfContent = @(
    "name: docs-validate",
    "on:",
    "  pull_request:",
    '    paths: ["docs/**"]',
    "jobs:",
    "  schema-v1:",
    "    runs-on: ubuntu-latest",
    "    env:",
    '      WARN_ONLY: ""',
    "    steps:",
    "      - uses: actions/checkout@v4",
    "        with:",
    "          submodules: true",
    "      - name: Validate Canonical Schema v1 frontmatter (docs/)",
    "        run: |",
    "          bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh",
    "      - name: Validate knowledge/ frontmatter",
    "        run: |",
    "          ROOT=knowledge bash docs/.runtime/naprolom-docs/engine/validators/validate-frontmatter.sh knowledge"
  )
  $wfContent | Set-Content -Path $wf -Encoding utf8
  Write-Host "-> Created .github/workflows/docs-validate.yml"
} else {
  Write-Host "-> .github/workflows/docs-validate.yml exists, skipped (review manually if needed)"
}

Write-Host ""
Write-Host "OK Bootstrap complete."
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Fill .context/project.yml with project-specific stack and metadata"
Write-Host "  2. Edit .context/boundaries.yml for pristine/secret paths of THIS project"
Write-Host "  3. Copy template to create first ADR: copy docs/.runtime/naprolom-docs/engine/templates/adr.md to docs/adr/001-<slug>.md"
Write-Host "  4. Create docs/architecture/README.md (topology + invariants)"
Write-Host "  5. Commit the new structure"
