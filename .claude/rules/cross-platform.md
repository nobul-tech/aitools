## Cross-Platform Awareness (this repo)

This repo is explicitly cross-platform — it provides tooling for both machines.

When writing scripts or paths **in this repo**:
- Provide both `.ps1` and `.sh` variants for setup/utility scripts
- Use forward slashes in paths when possible (works on both platforms)
- Repos live under `~/repos/` (macOS) / `C:\repos\` (Windows); some legacy projects still on Google Drive
- Use `$HOME` or `~` for user directory references, not hardcoded paths
- After creating `.sh` files on Windows, always run `git update-index --chmod=+x <file>` -- Windows doesn't set the Unix executable bit

### Equal platform visibility

When showing usage examples, commands, or invocations in documentation
(CLAUDE.md, reference/, plans/), always show both macOS/bash and
Windows/PowerShell. Never abbreviate one platform as "same but .ps1"
or treat either platform as the obvious default.

This is enforced as a Project Standing Order (PSO) in CLAUDE.md.

### Platform targeting principle

Scripts come in platform pairs: `.sh` targets macOS/Linux, `.ps1` targets
Windows. Every setup, utility, and check script must have both variants
unless listed in the OS guard exemptions table below. The OS guard enforces
this at runtime; header comments document the target platform.

### OS guard patterns

These are the canonical, copyable patterns. For block order placement, see
`script-standards.md`. For the logging requirement, see
`reference/script-standards-detail.md` "OS guard logging convention".

**PowerShell (Windows scripts):**

```powershell
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}
```

Key: Use `-not $IsWindows` (catches macOS AND Linux). Never use `$IsMacOS`
alone — it misses Linux. The `PSVersion.Major -ge 6` check ensures the guard
is transparent to PS 5.1 on Windows (where `$IsWindows` is undefined).

**Bash (macOS/Linux scripts):**

```bash
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use the .ps1 version."
        exit 1 ;;
esac
```

**Prerequisite**: Guards MUST use structured logging (`LogError`/`log_error`),
not raw output (`Write-Host`/`echo`). This requires logging to be initialized
before the guard. Source `init-logging.ps1`/`init-logging.sh` after the lib
source and before the guard. See `script-standards.md` block order.

### OS guard exemptions

Scripts without a blocking entry guard:

| Category | Scripts | Rationale |
|----------|---------|-----------|
| Shared libraries | `aitools-lib.sh/.ps1`, `check-lib.sh/.ps1` | Dot-sourced by callers that have their own guards. Never invoked directly. |
| Init libraries | `init-logging.sh/.ps1` | Sourced for initialization. Platform-native (each only runs on its target). |
| Hooks | `shared/hooks/*.sh` | Claude Code hooks run in bash on all platforms by design. No PS1 variant. |
| Shell alias modules | `shared/shell/aliases.sh/.ps1` | Sourced into shell profiles. Platform-specific functions use inline runtime guards. |
| Build scripts | `build-deploy.sh` | Runs on all platforms. See cross-language exceptions table. |
| Scratch/test files | `.scratch/*.sh` | Temporary development files. Not deployed or reusable. |

### Dead code from platform guards

When an OS guard exits on the wrong platform, any platform-conditional code
below the guard for the rejected platform is dead code. For example, an
`$IS_WINDOWS` branch in a bash script with an OS guard that exits on Windows
can never execute.

**Rule:** Do not write platform branches for the rejected platform below an
OS guard. If the guard exits on Windows, all code below it runs on
macOS/Linux only — no `if $IS_WINDOWS` branches needed. If the guard exits
on non-Windows, all code below runs on Windows only — no `if ($IsMacOS)`
branches needed.

**Corollary:** Platform-conditional code (like `require_pwsh` for PS1
validation) should use capability checks, not platform identity checks.
After the guard, you know which platform you're on — branch on capability
(`command -v pwsh`) not identity (`$IS_MACOS`).

### OS guard + dispatch rule

Every script uses the guard pattern from the OS guard patterns section above. The bash `aitools` entry point runs in Git Bash on Windows. So:

- **Never call `.sh` setup scripts without a `uname -s` dispatch.** On Windows, call the `.ps1` variant via `pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$path")"`.
- When adding a new code path that invokes setup scripts, search the file for existing `MINGW*|MSYS*|CYGWIN*` blocks and replicate the pattern.
- When adding a command to `scripts/aitools`, add the equivalent to `scripts/aitools.ps1`.

Note: The dual-script rule is specific to this repo. Most projects are platform-specific and don't need both variants.

### Cross-language script calls require explicit approval

**Default**: Every script gets a native variant for each platform (`.sh` + `.ps1`). Both Windows/PowerShell and macOS/bash are first-class citizens.

**Crossing languages** (e.g., PowerShell calling a bash script via Git Bash, or bash calling PowerShell via `pwsh`) **is an exception, not the default.** Before planning any cross-language call:

1. **Stop and ask the user** — explain what you're proposing, why a native variant isn't feasible, and what the trade-off is
2. **Get explicit approval** — do not proceed without it
3. **If approved**: document the exception in the script header, at every call site, and in the table below
4. **If denied**: write the native variant instead

This applies during planning (plan mode), not just implementation. If your plan includes a cross-language call, flag it and ask before finalizing the plan.

#### Approved exceptions

| Script | Why single-language | Approved | Other-platform invocation |
|--------|-------------------|----------|--------------------------|
| `scripts/build-deploy.sh` | Build step that produces platform-independent output (both .sh and .ps1 deploy scripts). Runs once, result committed to git. Maintaining a parallel PS1 would double maintenance for no output difference. | 2026-02-17 | `aitools.ps1` calls via Git Bash (guaranteed prerequisite): `& $bashExe "$path/build-deploy.sh"` |

### PowerShell 7 baseline

PS 7 (`pwsh`) is the project baseline on both platforms. Deploy scripts enforce
this with a version guard that errors on PS 5.1.

Existing PS 5.1 workarounds remain in scripts -- they are harmless on PS 7 and
will be cleaned up in a future pass. Common patterns you'll see:
- `if/else` instead of ternary `$x ? $a : $b`
- Chained `Join-Path` calls instead of 3+ arguments
- `[System.IO.File]::WriteAllText()` instead of `Set-Content -Encoding UTF8`
- `$null = [Parser]::ParseFile(...)` to suppress AST dump
- `ConvertPSObjectToHashtable` helper for JSON round-tripping

### ASCII preference for PS1 executable code

Prefer ASCII in PS1 strings and expressions. PS 7 handles BOM-free UTF-8
natively, so this is a preference for consistency, not a hard requirement.
Existing ASCII workarounds (e.g., `--` instead of em-dash) are harmless.

### PowerShell pipeline encoding (advisory)

On Windows, PowerShell can mangle non-ASCII bytes from external commands
(pandoc, curl, git) when piping through the console codepage. PS 7 improves
this but doesn't fully eliminate it. When non-ASCII content is expected:
- Prefer temp files over piping (`-o` flag, `[IO.File]::ReadAllText()`)
- Or set `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`

### .NET clipboard encoding gotcha (Windows)

`[System.Windows.Forms.Clipboard]::GetData("HTML Format")` returns a .NET string where the UTF-8 clipboard bytes have been decoded as Windows-1252. This produces mojibake: em-dash (U+2014) becomes `a]S`, NBSP (U+00A0) becomes `A` + NBSP, curly quotes become `a]Y`/`a]o`, etc.

**Fix**: re-encode the string back to bytes via Windows-1252 (reversing the incorrect decode), then decode as UTF-8:
```powershell
$win1252 = [System.Text.Encoding]::GetEncoding(1252)
$rawBytes = $win1252.GetBytes($raw)
$raw = [System.Text.Encoding]::UTF8.GetString($rawBytes)
```

This only affects Windows (macOS clipboard access via `osascript` handles encoding correctly).

### .NET vs PowerShell working directory

PowerShell's `Set-Location`/`cd` changes `$PWD` but NOT `[Environment]::CurrentDirectory` (the .NET CWD). Any .NET API that takes a relative path (`[IO.File]::WriteAllText`, `[IO.File]::ReadAllText`, etc.) resolves against the .NET CWD, not `$PWD`. This causes files to be written to the wrong location.

**Always resolve to absolute paths before calling .NET file APIs:**
```powershell
$resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($relativePath)
[System.IO.File]::WriteAllText($resolved, $content, ...)
```

### Refresh-Path behavior (Windows)

`Refresh-Path` (aitools-lib.ps1) merges new PATH entries from the Windows
registry into the current session PATH after package manager installs. It is
**additive** — it preserves existing PATH entries (including those inherited
from the parent process or added by `Ensure-ToolOnPath`) and only adds
directories found in the registry that are missing from the current PATH.

Setup scripts call `Refresh-Path` after winget/MSI installs to pick up new
binaries without restarting the shell. The function is safe to call multiple
times — duplicate directories are filtered.

### Git Bash PATH shadowing (Windows)

Git for Windows bundles tools in its `usr/bin/` directory (notably `perl`).
When Claude Code (Git Bash) spawns `pwsh`, the child process inherits Git
Bash's PATH where `usr/bin/` may appear before managed tool install
directories (e.g., `C:\Strawberry\perl\bin`).

**Consequence**: `perl --version` from pwsh-spawned-by-Git-Bash may return
Git's bundled perl (v5.38.2) instead of the managed Strawberry Perl (v5.42.0).

**Resolution in check scripts**: `check-lib.ps1` explicitly prepends the
managed Strawberry Perl install path on Windows, ensuring it takes priority
over Git's bundled version. Per PSO "Fail, don't mask": if the managed tool
is not installed, the script fails — no fallback to Git's bundled version.

**Resolution in other contexts**: Use `Refresh-Path` (aitools-lib.ps1) or
read the Windows system PATH from the registry directly.

**Currently shadowed tools**: Only `perl` confirmed.

### Pre-validation convention

When creating or modifying any `.ps1` or `.sh` script in this repo:
- Before committing, validate syntax on the current platform:
  - PS1: `pwsh -NoProfile -Command '$e = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile("path", [ref]$null, [ref]$e); if ($e) { $e }'`
  - Bash: `bash -n path/to/script.sh`
- On Windows, always validate PS1 files with pwsh
- On macOS, always validate `.sh` files; PS1 validation requires `pwsh` (managed tool -- install via `brew install powershell/tap/powershell`)
- If the other platform's script can't be validated locally, note it in the commit message: `(tested: macOS)` or `(tested: Windows)`
- Note untested items in `RELEASE_NOTES.md` (see verified-platform convention)
