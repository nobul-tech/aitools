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
