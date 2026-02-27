# Error Handling Audit Plan (Phase 2)

Full audit and remediation of all reusable scripts against the error handling rules
established in Phase 1 (`.claude/rules/error-handling.md`, `.claude/rules/script-standards.md`
error handling section, standing order #7).

## Approach

For each error-suppression pattern found in every reusable script:

1. **Compliant** -- result is checked and logged/failed within 3 lines. No action.
2. **Exempt** -- command-existence check with explicit fallback. Document as compliant.
3. **Violation** -- suppressed error with no result check. Fix: add null guard,
   `StepFail`/`StepWarn` (check scripts), or `log_error`/`LogError` (setup scripts).
4. **Needs exemption** -- intentional suppression that can't be checked (rare). Document
   in script header + exemptions table in `script-standards.md`. Present to user for
   approval before committing.

**Fix order:** Shared code first (check-lib, build templates), then consumers (check scripts,
setup scripts), then generated output (deploy/). This prevents fixing a file that will be
overwritten by a rebuild.

## Findings

### Step 1: Shared code and build templates

| File | Patterns | Compliant | Exempt | Violation | Exemption |
|------|----------|-----------|--------|-----------|-----------|
| `check-lib.ps1` | 3 | 2 | 1 (InvokeGit `2>$null`) | 0 | 1 (InvokeGit) |
| `build-deploy.sh` | 14 | 8 | 3 | 0 | 0 |

**check-lib.ps1** InvokeGit (line 110): `& git @args 2>$null` suppresses git stderr that
triggers PS `ErrorActionPreference=Stop`. Documented in file header (lines 100-105). Caller
is responsible for checking result. Added to exemptions table.

**build-deploy.sh**: All patterns are compliant or exempt. Command-existence checks
(`command -v node`, `hostname -s || hostname`), conditional checks (`&& eval`, `if...then`),
and properly caught try/catch blocks. No fixes needed.

### Step 2: Check/audit scripts

| File | Patterns | Compliant | Exempt | Violation | Fixed |
|------|----------|-----------|--------|-----------|-------|
| `check-post-push.ps1` | 19 | 7 | 1 | **10** | **10** |
| `check-pre-commit.ps1` | 2 | 2 | 0 | 0 | -- |
| `check-pre-push.ps1` | 1 | 1 | 0 | 0 | -- |

**check-post-push.ps1 violations** (all fixed): 10 `Get-ChildItem -ErrorAction
SilentlyContinue` calls feeding into foreach loops without null guards. If a directory
doesn't exist, the loop processes 0 items, producing a false StepPass.

Fix: Added count/null guards before each foreach loop. If no files found, report
`StepFail` instead of silently passing.

Affected steps: 2 (deploy smoke-test), 6 (.sh syntax, .ps1 syntax), 8 (rule parity),
11 (cross-platform pairing), 14 (line ending audit).

### Step 3: Setup scripts

| File | Patterns | Compliant | Exempt | Violation | Exemption |
|------|----------|-----------|--------|-----------|-----------|
| All `setup-*.ps1` (8) | ~25 | ~25 | 0 | 0 | 0 |
| `setup-vercelcli.sh` | ~4 | 3 | 0 | 0 | 1 (cleanup) |
| `setup-pandoc.sh` | ~6 | 3 | 0 | 0 | 3 (cleanup) |
| `setup-rust.sh` | ~5 | 4 | 0 | 0 | 1 (cleanup) |
| Other `setup-*.sh` (5) | ~30 | ~30 | 0 | 0 | 0 |

**Cleanup exemptions** (5 total): Non-preferred package manager removal commands that
use `|| true` to prevent halting on failure. These are intentional -- the tool may
not be installed via that manager. Comments added to each. Listed in exemptions table.

### Step 4: Installer scripts

| File | Patterns | Compliant | Exempt | Violation | Exemption |
|------|----------|-----------|--------|-----------|-----------|
| `aitools-install.ps1` | ~13 | 12 | 1 (env cleanup) | 0 | 0 |
| `aitools.ps1` | ~30 | 25 | 3 (env cleanup) | 0 | 0 |
| `aitools-install.sh` | ~12 | 10 | 0 | 0 | 1 (apt-get update) |
| `aitools` (bash) | ~35 | 30 | 2 | 0 | 0 |

**aitools-install.sh line 273**: `apt-get install -y gh 2>/dev/null || true` -- in the
update path (gh already installed). May need sudo which may not be available. Non-blocking.
Comment added. Listed in exemptions table.

**aitools lines 693, 1034, 1062**: Initially flagged as violations by auditors but on
review are compliant -- each has a downstream result check (empty string check, `$found`
flag, matches count). Comments added to document the intent.

### Step 5: Rebuild and verify

1. `build-deploy.sh` run successfully -- propagated cleanup comments to deploy/
2. PS1 syntax validation passed for check-post-push.ps1
3. Bash syntax validation passed for all modified .sh scripts

### Step 6: Exemptions

5 exemptions documented in `script-standards.md` exemptions table:
- 3 setup scripts (cleanup patterns)
- 1 installer (apt-get update)
- 1 shared lib (InvokeGit stderr)

## Summary

| Category | Count |
|----------|-------|
| Patterns audited | ~89 across all scripts |
| Compliant | ~70 |
| Exempt (command-existence) | ~10 |
| **Violations fixed** | **10** (all in check-post-push.ps1) |
| **Comments added** | **10** (setup + installer scripts) |
| **Exemptions documented** | **5** |
