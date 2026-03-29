# RFC 0007: Cross-Platform Engineering

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Informed by**: .claude/rules/cross-platform.md, reference/cross-platform-detail.md, 15 hooks (all-platform bash), build-deploy.sh (single bash-only exception), all setup-*.sh/.ps1 pairs (18), aitools-lib.sh/.ps1, check scripts (5 pairs), standing-order-guard.sh (stat dispatch, portability enforcement), 8+ incident fixes for platform bugs, RFCs 0001-0006
**Relationship**: Engineering discipline underlying all other RFCs. Every script, hook, and deploy artifact is governed by these patterns.

---

## 1. Summary

aitools is explicitly cross-platform — macOS, Windows, and Linux are all first-class. Every setup script gets both .sh and .ps1. Every hook runs bash on all platforms. The build pipeline produces platform-independent output from a single bash script. The product (RFC 0001 v2) is web-accessible from any device.

Cross-platform engineering is the most incident-prone area of the harness. The stat fallback chain broke 4 times. CRLF handling caused recurring commit friction. PATH divergences between Git Bash and PowerShell caused silent tool invisibility. Each incident produced operational learning that is now codified in rules but was learned through pain.

This RFC unifies the cross-platform patterns currently scattered across 1 rule, 1 reference file, 15 hooks, 36 setup scripts, 2 shared libraries, and 8+ incident fixes into a single authoritative specification.

## 2. The Three Platforms

| Platform | Shell | Entry point | Python | Package manager |
|----------|-------|------------|--------|----------------|
| macOS | zsh (user), bash 5.x (scripts, managed via Homebrew) | `aitools` (bash) | python3 (pyenv or system) | Homebrew |
| Windows | Git Bash (CC hardcoded), pwsh 7+ (scripts) | `aitools.ps1` (pwsh) | python (winget/python.org) | winget, pip |
| Linux | bash | `aitools` (bash) | python3 (system) | apt/dnf, pip |

### The Windows shell constraint

Claude Code on Windows is hardcoded to Git Bash. CLAUDE_CODE_SHELL is broken (silently ignored). CC #7490, #25558, #5049, #16225, #20453. All hooks run in bash on all platforms. PowerShell scripts are invoked from bash via `pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$path")"`.

This is the single most impactful platform constraint. It means:
- All hooks must be portable bash (BSD + GNU compatible)
- Git Bash PATH is a subset of Windows PATH — tools installed via winget may be invisible
- The `pwsh -Command` pattern is required for any PowerShell operation from CC

## 3. The Dual-Script Rule

Every setup script gets both .sh and .ps1 with OS guards. This is a standing order.

### OS guard patterns (canonical, copyable)

**Bash (macOS/Linux scripts):**
```bash
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use the .ps1 version."
        exit 1 ;;
esac
```

**PowerShell (Windows scripts):**
```powershell
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}
```

Guards MUST use structured logging. Source init-logging before the guard.

### Exemptions

| Category | Scripts | Rationale |
|----------|---------|-----------|
| Shared libraries | aitools-lib.sh/.ps1, check-lib.sh/.ps1 | Dot-sourced, never invoked directly |
| Init libraries | init-logging.sh/.ps1 | Sourced for initialization |
| Hooks | shared/hooks/*.sh | CC hooks run bash on all platforms |
| Shell aliases | shared/shell/aliases.sh/.ps1 | Sourced into shell profiles |
| Build scripts | build-deploy.sh | Cross-language exception (approved, output committed to git) |
| Scratch/test files | .scratch/*.sh | Temporary, not deployed |

### Dead code rule

Do NOT write platform branches for the rejected platform below an OS guard. After the guard, branch on capability (`command -v pwsh`) not identity (`$IS_MACOS`).

## 4. Hook Portability

Hooks run bash on ALL platforms (macOS, Linux, Windows Git Bash). They are standalone — cannot source aitools-lib.sh. Must handle BSD vs GNU divergences.

### Known command divergences

| Command | macOS (BSD) | Linux/Git Bash (GNU) | Correct pattern |
|---------|-------------|---------------------|-----------------|
| stat modification time | `stat -f %m file` | `stat -c %Y file` | uname -s dispatch |
| stat birth time | `stat -f %B file` | `stat -c %W file` | uname -s dispatch |
| stat formatted date | `stat -f "%SB" -t "%Y-%m-%d"` | `date -d "@$(stat -c %Y)"` | uname -s dispatch |
| find formatted output | find -printf unavailable | `find -printf '%T@'` | find -print0 + stat loop |
| grep Perl regex | grep -P unavailable | `grep -P` | perl -ne or grep -E |
| date parsing | `date -j -f fmt` | `date -d string` | uname -s dispatch |

### The stat dispatch pattern (canonical)

```bash
if [ "$(uname -s)" = "Darwin" ]; then
    mod_time=$(stat -f %m "$file" 2>/dev/null || echo "0")
else
    mod_time=$(stat -c %Y "$file" 2>/dev/null || echo "0")
fi
```

### The BANNED fallback chain

**NEVER** use `stat -f %m "$file" || stat -c %Y "$file"`. On Git Bash, GNU `stat -f` means `--file-system` (not format). It partially succeeds with wrong multiline output, contaminating the variable. Under `set -u`, bash arithmetic crashes with "File: unbound variable". This broke 4 times before the rule was written. The standing-order-guard.sh hook should eventually detect this pattern.

### All hooks must use `set -euo pipefail`

The `-u` flag catches unset variables — correct behavior. It surfaces bugs as crashes rather than silent wrong results.

## 5. Line Endings and Encoding

### CRLF rules

| File type | Line endings | Enforcement |
|-----------|-------------|-------------|
| .sh files | LF only | sh-file-fixup.sh PostToolUse hook (auto-fixes CRLF->LF + chmod +x + git index +x) |
| .ps1 files in deploy/ | CRLF | build-deploy.sh converts at build time via `perl -pi -e 's/(?<!\r)\n/\r\n/'` |
| .ps1 files in scripts/ | LF in git, CRLF at runtime | .gitattributes `* text=auto eol=lf`, PS1 handles both |
| .md files | LF | Standard |

### The PERLIO fix

Strawberry Perl on Windows defaults to `:crlf` text layer, causing double-CR (`\r\r\n`) on explicit `\r\n` writes. Fix: `export PERLIO=:perlio` (set at top of build-deploy.sh). No-op for Git's bundled perl.

### Encoding

- Bash: UTF-8 throughout. BOM handling in read_config_key (strips \357\273\277).
- PowerShell: UTF-8 without BOM via `[System.Text.UTF8Encoding]::new($false)` for all file writes.
- PowerShell pipeline encoding: .NET clipboard and external command stdout decode as Windows-1252 (OEM codepage). Prefer temp files over piping for non-ASCII content. `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` for claude CLI output capture.

## 6. PATH and Tool Discovery

### The Git Bash PATH problem

Git Bash on Windows inherits a subset of the Windows PATH. Many tools installed via winget (aitools, pandoc, etc.) are on the PowerShell PATH but invisible to Git Bash.

**Rule**: To check if a tool is installed on Windows:
```bash
pwsh -NoProfile -Command 'Get-Command <tool> -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source'
```
Never use `which` or `command -v` on Windows for tool availability.

### Git Bash PATH shadowing

Git's `usr/bin/` can shadow managed tools. Example: Git bundles perl 5.38.2 which shadows Strawberry Perl 5.42. Fix: explicit PATH prepend for the managed version. No fallback to bundled versions.

### Refresh-Path (PowerShell)

After winget install, the binary may not be on PATH. `Refresh-Path` (aitools-lib.ps1) merges registry PATH entries into current session PATH (additive, never removes). Safe to call repeatedly.

### ensure_tool_on_path (bash)

Three-step: command -v (current PATH) -> hash -r (cache refresh) -> known paths fallback (filesystem check + session PATH update). Known paths must be empirically verified per KnownPaths rule.

### KnownPaths empirical verification

All hardcoded install paths MUST be empirically verified on the actual platform. Install the tool, record the path, document `# Verified: YYYY-MM-DD (vX.Y.Z)`. Unverified paths marked `# UNVERIFIED`. Guessing paths from installer type is a process violation.

## 7. The Build Pipeline (Cross-Platform)

build-deploy.sh is intentionally bash-only — the approved cross-language exception. It produces platform-independent output: both .sh and .ps1 deploy scripts from one build. The output is committed to git, so both platforms get identical deploy/ contents.

### Cross-language calls

Crossing languages (bash calling .ps1, .ps1 calling bash) is an exception requiring explicit approval.

| Script | Why approved | Invocation |
|--------|-------------|-----------|
| build-deploy.sh (from aitools.ps1) | Platform-independent output | `& $bashExe "$path/build-deploy.sh"` |

On Windows, aitools.ps1 invokes build-deploy.sh via Git Bash (prerequisite for CC).

### PS1 syntax validation at build time

build-deploy.sh validates all generated .ps1 files with `[System.Management.Automation.Language.Parser]::ParseFile()` on both platforms (native pwsh on Windows, managed pwsh on macOS). Parse errors at build time, not install time.

### CRLF conversion at build time

`perl -pi -e 's/(?<!\r)\n/\r\n/' deploy/*.ps1` — .gitattributes requires eol=crlf for deploy/*.ps1.

## 8. PowerShell 7 Baseline

PS 7 (pwsh) is the project baseline. Deploy scripts error on PS 5.1. Legacy 5.1 workarounds remain in code — harmless, cleanup deferred.

Key PS 7 features used:
- `$IsWindows`, `$IsMacOS` (PS 6+)
- Ternary operator (PS 7+)
- `[System.Text.UTF8Encoding]::new($false)` (UTF-8 no BOM)

### ASCII preference for PS1 executable code

Prefer ASCII in PS1 strings and expressions for consistency across editor encodings and terminal renderers.

## 9. Config File Patterns (Cross-Platform)

### JSON config paths

| Config | Windows | macOS |
|--------|---------|-------|
| settings.json | %USERPROFILE%\.claude\settings.json | ~/.claude/settings.json |
| mcp.json | %USERPROFILE%\.claude.json | ~/.claude.json |
| config.json | %USERPROFILE%\.aitools\config.json | ~/.aitools/config.json |
| deploy state | %USERPROFILE%\.aitools\deploy-state\ | ~/.aitools/deploy-state/ |
| logs | %LOCALAPPDATA%\aitools\ | ~/Library/Logs/aitools/ |

### Platform-specific config values

MCP server commands differ by platform (cmd /c npx on Windows, npx on macOS). Hook paths use platform-appropriate separators. OS guards + platform dispatch prevent cross-platform value writes.

### Read-then-merge default

All config-writing scripts use read-then-merge. Blind overwrite only for sole-owner files (CLAUDE.md). Managed vs preserved fields documented in script headers.

## 10. Testing and Verification (Cross-Platform)

### Pre-validation convention

Before committing scripts:
- PS1: `pwsh -NoProfile -Command '$e = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile("path", [ref]$null, [ref]$e); if ($e) { $e }'`
- Bash: `bash -n path/to/script.sh`
- Note untested platform in commit message: `(tested: Windows)` or `(tested: macOS)`

### CI pipeline

.github/workflows/check.yml: 3 runners (macOS-14, ubuntu-latest, windows-2022). Validates syntax, build-deploy drift, line endings, script pairing.

### Check scripts (cross-platform pairing checks)

- check-pre-commit step 2: Script syntax (.sh + .ps1)
- check-post-push step 6: Full syntax validation (all .sh + .ps1)
- check-post-push step 11: Cross-platform pairing (every .sh has .ps1 and vice versa)
- check-post-push step 29: Deployment menu parity (PS1 and bash menus show identical options)
- check-post-push step 31: Deployment state machine sync (return values match across platforms)
- check-script-compliance step 10: Cross-platform pairing for all setup scripts

## 11. Incident History

Cross-platform is the most incident-prone area. Key incidents that produced rules:

| Incident | Root cause | Rule produced |
|----------|-----------|--------------|
| stat fallback chain (4 times) | GNU stat -f means --file-system, not format | BANNED pattern in cross-platform.md |
| CRLF in .sh files | Write tool produces CRLF on macOS | sh-file-fixup.sh PostToolUse hook |
| Git Bash perl shadowing | Git bundles old perl, shadows Strawberry | Explicit PATH prepend rule |
| PERLIO double-CR | Strawberry Perl :crlf layer | export PERLIO=:perlio in build-deploy.sh |
| PS1 pipeline encoding | PowerShell OEM codepage mangles UTF-8 | Temp file pattern for non-ASCII |
| Git Bash PATH invisibility | winget tools not on Git Bash PATH | pwsh Get-Command pattern |
| CLAUDE_EFFORT_LEVEL unbound | Missing default in build-deploy.sh, CI caught it | Default variable initialization convention |
| chmod +x missing | Write tool creates 100644 | sh-file-fixup.sh + git update-index |

Each incident followed the pattern: pain -> investigation -> rule -> hook/check -> prevention. The three-layer governance model (RFC 0004-v2) was built from this experience.

## 12. Phase Plan

### Phase 0: Codify existing patterns (1 session)
- Verify all 15 hooks use the canonical stat dispatch (not fallback chain)
- Verify all setup scripts have OS guards with structured logging
- Verify sh-file-fixup.sh catches all CRLF/chmod cases
- Add hook portability check to check-pre-commit (step 17 exists but may have gaps)
- **Exit**: Zero hook portability violations

### Phase 1: PATH reliability (1 session)
- Implement ensure_tool_on_path for all KnownPaths entries in setup scripts
- Verify all KnownPaths empirically on both platforms
- Add PATH verification to check-post-push
- **Exit**: Every tool findable on both platforms after install

### Phase 2: CI expansion (1 session)
- Add hook portability test to CI (run hooks with mock input on all 3 runners)
- Add deploy script functional test (dry-run on all 3 runners)
- Add line ending enforcement to CI
- **Exit**: Platform bugs caught in CI before merge

## 13. Open Questions

1. **Linux as CI-only vs first-class**: Linux is tested in CI but no developer actively uses it daily. Is it truly first-class or CI-verified?
2. **WSL support**: Some Windows users may prefer WSL over Git Bash. Should the harness support WSL as an alternative shell? Currently untested.
3. **Apple Silicon vs Intel**: macOS Homebrew paths differ (/opt/homebrew vs /usr/local). KnownPaths must cover both. Currently most paths are /opt/homebrew (Apple Silicon verified).
4. **Git Bash version**: CC bundles its own Git Bash. Version and capabilities may change with CC updates. Not tracked as a version dependency.

## 14. References

### Rules and reference
- .claude/rules/cross-platform.md (OS guards, exemptions, hook portability, PowerShell baseline)
- reference/cross-platform-detail.md (rationale, gotchas, encoding, PATH)

### Hooks (portability-critical)
- shared/hooks/*.sh (all 15, all-platform bash)
- sh-file-fixup.sh (CRLF/chmod auto-fix)
- standing-order-guard.sh (enforces dedicated tools USO)

### Scripts
- aitools-lib.sh (ensure_tool_on_path, check_build_prereqs, display_path)
- aitools-lib.ps1 (Refresh-Path, Ensure-ToolOnPath, Check-BuildPrereqs)
- build-deploy.sh (cross-language exception, PS1 validation, CRLF conversion)

### Related RFCs
- 0004-v2: Harness architecture (platforms listed)
- 0005-v2: Session intelligence (Python cross-platform detection)
- 0008 (planned): Verification pipeline (CI, check scripts)
- 0010 (planned): Python/SQLite engineering (cross-platform Python)
