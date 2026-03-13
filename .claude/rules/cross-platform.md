## Cross-Platform Awareness (this repo)

This repo is explicitly cross-platform — it provides tooling for both machines.

When writing scripts or paths **in this repo**:
- Provide both `.ps1` and `.sh` variants for setup/utility scripts
- Use forward slashes in paths when possible (works on both platforms)
- Repos live under `~/repos/` (macOS) / `C:\repos\` (Windows)
- Use `$HOME` or `~` for user directory references, not hardcoded paths
- After creating `.sh` files on Windows, always run `git update-index --chmod=+x <file>`

### Equal platform visibility

When showing usage examples in docs, always show both macOS/bash and
Windows/PowerShell. Never abbreviate one platform as "same but .ps1".
Enforced as a PSO in CLAUDE.md.

### Platform targeting principle

Scripts come in platform pairs: `.sh` targets macOS/Linux, `.ps1` targets
Windows. Every script must have both variants unless listed in the exemptions
table. The OS guard enforces at runtime; header comments document platform.

### OS guard patterns

Canonical, copyable patterns. Rationale: `@reference/cross-platform-detail.md`

**PowerShell (Windows scripts):**

```powershell
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}
```

**Bash (macOS/Linux scripts):**

```bash
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use the .ps1 version."
        exit 1 ;;
esac
```

Guards MUST use structured logging. Source `init-logging` before the guard.

### OS guard exemptions

| Category | Scripts | Rationale |
|----------|---------|-----------|
| Shared libraries | `aitools-lib.sh/.ps1`, `check-lib.sh/.ps1` | Dot-sourced, never invoked directly |
| Init libraries | `init-logging.sh/.ps1` | Sourced for initialization |
| Hooks | `shared/hooks/*.sh` | CC hooks run bash on all platforms |
| Shell alias modules | `shared/shell/aliases.sh/.ps1` | Sourced into shell profiles |
| Build scripts | `build-deploy.sh` | See cross-language exceptions |
| Scratch/test files | `.scratch/*.sh` | Temporary, not deployed |

### Dead code from platform guards

Do not write platform branches for the rejected platform below an OS guard.
After the guard, branch on capability (`command -v pwsh`) not identity
(`$IS_MACOS`).

### OS guard + dispatch rule

- Never call `.sh` setup scripts without a `uname -s` dispatch
- On Windows, call `.ps1` via `pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$path")"`
- When adding a command to `scripts/aitools`, add the equivalent to `scripts/aitools.ps1`

### Cross-language script calls require explicit approval

Crossing languages is an exception. Before planning any cross-language call:
ask the user, get approval, document the exception.

#### Approved exceptions

| Script | Why | Approved | Invocation |
|--------|-----|----------|------------|
| `build-deploy.sh` | Platform-independent output, result committed | 2026-02-17 | `& $bashExe "$path/build-deploy.sh"` |

### PowerShell 7 baseline

PS 7 (`pwsh`) is the project baseline. Deploy scripts error on PS 5.1.
Legacy PS 5.1 workarounds remain — harmless, cleanup deferred.
Patterns: `@reference/cross-platform-detail.md`

### ASCII preference for PS1 executable code

Prefer ASCII in PS1 strings and expressions for consistency.

### Windows platform gotchas

Brief rules — full details and code examples in
`@reference/cross-platform-detail.md`.

- **PowerShell pipeline encoding**: Prefer temp files over piping for non-ASCII
- **.NET clipboard encoding**: Re-encode Windows-1252 → UTF-8 for clipboard HTML
- **.NET working directory**: Resolve to absolute paths before .NET file APIs
- **Refresh-Path**: Additive PATH merge from registry; safe to call repeatedly
- **Git Bash PATH shadowing**: Git's `usr/bin/` can shadow managed tools (perl).
  Use explicit PATH prepend; no fallback to bundled versions
- **Strawberry Perl text mode**: Defaults to `:crlf` layer (double-CR on
  explicit `\r\n` writes). Fix: `export PERLIO=:perlio` or per-invocation prefix

### Pre-validation convention

Before committing scripts, validate syntax on the current platform:
- PS1: `pwsh -NoProfile -Command '$e = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile("path", [ref]$null, [ref]$e); if ($e) { $e }'`
- Bash: `bash -n path/to/script.sh`
- Note untested platform in commit message: `(tested: Windows)` or `(tested: macOS)`
