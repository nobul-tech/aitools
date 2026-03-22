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
- When adding a command to `@scripts/aitools`, add the equivalent to `@scripts/aitools.ps1`

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

### Hook portability (all-platform bash)

Hooks (`shared/hooks/*.sh`) run in bash on ALL platforms — macOS,
Linux, and Windows Git Bash. They are exempt from the dual-script
rule (no `.ps1` pair needed) but MUST be portable across all bash
environments. Hooks cannot source `aitools-lib.sh` or `check-lib.sh`
— they are standalone deployed files.

**Known command divergences in hooks:**

| Command | macOS (BSD) | Linux/Git Bash (GNU) | Correct pattern |
|---------|-------------|---------------------|-----------------|
| `stat` modification time | `stat -f %m file` | `stat -c %Y file` | `uname -s` dispatch |
| `stat` birth time | `stat -f %B file` | `stat -c %W file` (0 if unsupported) | `uname -s` dispatch |
| `stat` formatted date | `stat -f "%SB" -t "%Y-%m-%d"` | `date -d "@$(stat -c %Y)"` | `uname -s` dispatch |
| `find` formatted output | `find -printf` not available | `find -printf '%T@'` | Use `find -print0` + `stat` loop |
| `grep` Perl regex | Not available | `grep -P` | Use `perl -ne` or `grep -E` |
| `date` parsing | `date -j -f fmt` | `date -d string` | `uname -s` dispatch |

**Canonical `stat` dispatch pattern for hooks** (from `session-archive.sh:68`):

```bash
if [ "$(uname -s)" = "Darwin" ]; then
    mod_time=$(stat -f %m "$file" 2>/dev/null || echo "0")
else
    mod_time=$(stat -c %Y "$file" 2>/dev/null || echo "0")
fi
```

**NEVER use the fallback chain pattern** `stat -f %m "$file" || stat -c %Y "$file"`.
On Git Bash, GNU `stat -f` means `--file-system` (not format). It
partially succeeds with wrong multiline output, contaminating the
variable. Under `set -u`, bash arithmetic then crashes with
"File: unbound variable". This bug recurred 4 times before this
rule was written.

**All hooks must use `set -euo pipefail`** (code style default).
The `-u` flag catches unset variables, which is the correct behavior
— it surfaces bugs as crashes rather than allowing silent wrong
results.
