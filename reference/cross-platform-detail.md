# Cross-Platform Detail

Detail and background for `.claude/rules/cross-platform.md`. This file is
referenced by `@` links from the rules file — it loads on demand, not every
session.

## OS guard patterns — rationale

**PowerShell guard**: Use `-not $IsWindows` (catches macOS AND Linux). Never
use `$IsMacOS` alone — it misses Linux. The `PSVersion.Major -ge 6` check
ensures the guard is transparent to PS 5.1 on Windows (where `$IsWindows` is
undefined).

**Prerequisite**: Guards MUST use structured logging (`LogError`/`log_error`),
not raw output (`Write-Host`/`echo`). This requires logging to be initialized
before the guard. Source `init-logging.ps1`/`init-logging.sh` after the lib
source and before the guard. See `script-standards.md` block order.

## Environment detection

Rule: `.claude/rules/cross-platform.md` "Environment branches". Decisions D-ENV1..D-ENV9
(2026-10-05) are recorded in the PR that introduced the API.

### Resolution (both libraries, at load time)

1. **Platform** from `uname -s` (bash) or `$IsWindows`/`$IsMacOS`/`$IsLinux` (PowerShell;
   PS 5.1, where they are undefined, is `windows`): `macos`, `linux`, `windows`, `unknown`.
2. **Environment**: an `AITOOLS_ENVIRONMENT` already set to `claude-code-web` or `local`
   (case-sensitive) is an override; otherwise `CLAUDE_CODE_REMOTE=true` gives
   `claude-code-web`; otherwise `local`.
3. `claude-code-web` exists only on Linux: on any other platform the environment is `local`.
4. An override that is invalid, or `claude-code-web` off Linux, is replaced by the resolved
   value; `logging_init` / `Initialize-Logging` logs one warning. When `AITOOLS_ENVIRONMENT`
   came from the process environment it stays exported with the resolved value, so child
   scripts resolve the same value without repeating the warning.
5. Every `logging_init` / `Initialize-Logging` writes one detail line:
   `platform=<p> environment=<e> (AITOOLS_ENVIRONMENT='...' CLAUDE_CODE_REMOTE='...' type='...')`.
   `CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE` is logged, not used.

Signals: `CLAUDE_CODE_REMOTE=true` is documented by Claude Code for hooks and setup scripts
to detect a cloud session. Rejected signals: a `config.json` key (lost on container reclaim),
a CLI flag (does not reach hooks or children), `profile.json` (shared across machines), and a
root + no-display probe (would apply the sandbox-off chrome-devtools args to any root Linux
host). The environment Setup script runs before Claude Code starts and is not documented
to receive `CLAUDE_CODE_REMOTE` (unverified); it sets `AITOOLS_ENVIRONMENT=claude-code-web`
explicitly.

### API

| Bash (`aitools-lib.sh`) | PowerShell (`aitools-lib.ps1`) | Value / behaviour |
|---|---|---|
| `AITOOLS_PLATFORM` | `$AitoolsPlatform` | `macos`, `linux`, `windows`, `unknown` |
| `IS_MACOS`, `IS_WINDOWS`, `IS_LINUX` | (`$IsWindows` etc. built in) | `true` / `false` |
| `AITOOLS_ENVIRONMENT` | `$AitoolsEnvironment` | `claude-code-web` or `local` |
| `is_claude_code_web` | `Test-ClaudeCodeWeb` | true in Claude Code web |
| `is_local_environment` | `Test-LocalEnvironment` | true for a local agent |
| `write_environment_skip TOOL REASON` | `Write-EnvironmentSkip -Tool -Reason` | info line + `OK` row `n/a (<environment>)` |
| -- | `Resolve-AitoolsPlatform`, `Resolve-AitoolsEnvironment` | pure resolvers (testable from any platform) |

The value list is closed. A new environment (for example a hosted Cursor agent) is added by
decision: a new value, its signal, and the scripts that branch on it.

### Hooks

Hooks cannot source the library. A hook that needs the platform or environment copies the
code between `# --- BEGIN aitools environment block ---` and
`# --- END aitools environment block ---` in `scripts/aitools-lib.sh` verbatim, markers
included. The block is bash 3.2 compatible, `set -u` safe and depends only on `uname`.
Embedding rather than deploy-time injection keeps `shared/hooks/*.sh` runnable as-is for the
hook-rollout smoke tests and avoids a third copy of template logic in `setup-user-hooks.sh`,
`.ps1` and `build-deploy.sh` (`deploy-paths.md`). A check that compares each hook's copy with
the library is planned.

### Reporting a step that does not apply

`write_environment_skip` / `Write-EnvironmentSkip` writes `OK` with detail
`n/a (<environment>)`, matching the tool platform state `n/a`. Not `WARN`: nothing is wrong,
and a WARN row promotes the script's later OK rows. Not "skipped": that word is governed as
the user's choice in managed file deployment.

### Example (setup-user-mcp.sh, D-CHR2)

```bash
if is_claude_code_web; then
    CHROME_MCP_CMD=(npx -y chrome-devtools-mcp@latest --isolated --headless --chromeArg=--no-sandbox)
else
    CHROME_MCP_CMD=(npx chrome-devtools-mcp@latest --isolated)
fi
```

`setup-user-mcp.ps1` has no branch: on Windows the environment is always `local`.

## PowerShell 7 baseline — legacy workarounds

PS 7 (`pwsh`) is the project baseline. Existing PS 5.1 workarounds remain in
scripts — harmless on PS 7, cleanup deferred. Patterns you'll see:

- `if/else` instead of ternary `$x ? $a : $b`
- Chained `Join-Path` calls instead of 3+ arguments
- `[System.IO.File]::WriteAllText()` instead of `Set-Content -Encoding UTF8`
- `$null = [Parser]::ParseFile(...)` to suppress AST dump
- `ConvertPSObjectToHashtable` helper for JSON round-tripping

## PowerShell pipeline encoding (advisory)

On Windows, PowerShell can mangle non-ASCII bytes from external commands
(pandoc, curl, git) when piping through the console codepage. PS 7 improves
this but doesn't fully eliminate it. When non-ASCII content is expected:

- Prefer temp files over piping (`-o` flag, `[IO.File]::ReadAllText()`)
- Or set `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`

## .NET clipboard encoding gotcha (Windows)

`[System.Windows.Forms.Clipboard]::GetData("HTML Format")` returns a .NET
string where the UTF-8 clipboard bytes have been decoded as Windows-1252.
This produces mojibake: em-dash (U+2014) becomes `a]S`, NBSP (U+00A0) becomes
`A` + NBSP, curly quotes become `a]Y`/`a]o`, etc.

**Fix**: re-encode back to bytes via Windows-1252, then decode as UTF-8:

```powershell
$win1252 = [System.Text.Encoding]::GetEncoding(1252)
$rawBytes = $win1252.GetBytes($raw)
$raw = [System.Text.Encoding]::UTF8.GetString($rawBytes)
```

Only affects Windows (macOS clipboard via `osascript` handles encoding correctly).

## .NET vs PowerShell working directory

PowerShell's `Set-Location`/`cd` changes `$PWD` but NOT
`[Environment]::CurrentDirectory` (the .NET CWD). Any .NET API that takes a
relative path (`[IO.File]::WriteAllText`, etc.) resolves against the .NET CWD,
not `$PWD`.

**Always resolve to absolute paths before calling .NET file APIs:**

```powershell
$resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($relativePath)
[System.IO.File]::WriteAllText($resolved, $content, ...)
```

## Refresh-Path behavior (Windows)

`Refresh-Path` (aitools-lib.ps1) merges new PATH entries from the Windows
registry into the current session PATH after package manager installs. It is
**additive** — preserves existing entries (including those from the parent
process or `Ensure-ToolOnPath`) and only adds directories found in the
registry that are missing from the current PATH. Safe to call multiple times.

## Git Bash PATH shadowing (Windows)

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

## Strawberry Perl text mode (Windows)

Strawberry Perl defaults to `:unix:crlf` PerlIO layers (text mode):
`\n` → `\r\n` on output, `\r\n` → `\n` on input. Git's bundled perl uses
`:unix:perlio` (no translation).

**Consequence**: Perl one-liners that explicitly write `\r\n` (e.g.,
`s/\n$/\r\n/`) produce double-CR (`\r\r\n`) under Strawberry Perl, because
the `:crlf` layer translates the `\n` inside the explicit `\r\n` again.

**Fix**: Set `PERLIO=:perlio` before invoking perl. This replaces the `:crlf`
layer with buffered binary I/O, matching Git perl's behavior. No-op for Git
perl (already uses `:perlio`).

Usage patterns:

```bash
# Script-wide (build-deploy.sh)
export PERLIO=:perlio

# Per-invocation
PERLIO=:perlio perl -pe 's/foo/bar/' file.txt
```

```powershell
# PowerShell
$env:PERLIO = ":perlio"
& perl -pe "s/foo/bar/" $file
```

**Why not sitecustomize.pl?** Strawberry Perl is not compiled with
`-Dusesitecustomize` — a `sitecustomize.pl` file will never be executed.
`PERLIO` is the only global override mechanism.

**Applied in**: `build-deploy.sh` (`export PERLIO=:perlio` near top).
