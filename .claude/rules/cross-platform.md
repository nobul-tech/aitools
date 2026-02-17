## Cross-Platform Awareness (this repo)

This repo is explicitly cross-platform — it provides tooling for both machines.

When writing scripts or paths **in this repo**:
- Provide both `.ps1` and `.sh` variants for setup/utility scripts
- Use forward slashes in paths when possible (works on both platforms)
- Repos live under `~/repos/` (macOS) / `C:\repos\` (Windows); some legacy projects still on Google Drive
- Use `$HOME` or `~` for user directory references, not hardcoded paths

### OS guard + dispatch rule

Every `.sh` setup script has `case "$(uname -s)" in MINGW*...) exit 1`. The bash `aitools` entry point runs in Git Bash on Windows. So:

- **Never call `.sh` setup scripts without a `uname -s` dispatch.** On Windows, call the `.ps1` variant via `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$path")"`.
- When adding a new code path that invokes setup scripts, search the file for existing `MINGW*|MSYS*|CYGWIN*` blocks and replicate the pattern.
- When adding a command to `scripts/aitools`, add the equivalent to `scripts/aitools.ps1`.

Note: The dual-script rule is specific to this repo. Most projects are platform-specific and don't need both variants.

### Cross-language script calls require explicit approval

**Default**: Every script gets a native variant for each platform (`.sh` + `.ps1`). Both Windows/PowerShell and macOS/bash are first-class citizens.

**Crossing languages** (e.g., PowerShell calling a bash script via Git Bash, or bash calling PowerShell via `powershell.exe`) **is an exception, not the default.** Before planning any cross-language call:

1. **Stop and ask the user** — explain what you're proposing, why a native variant isn't feasible, and what the trade-off is
2. **Get explicit approval** — do not proceed without it
3. **If approved**: document the exception in the script header, at every call site, and in the table below
4. **If denied**: write the native variant instead

This applies during planning (plan mode), not just implementation. If your plan includes a cross-language call, flag it and ask before finalizing the plan.

#### Approved exceptions

| Script | Why single-language | Approved | Other-platform invocation |
|--------|-------------------|----------|--------------------------|
| `scripts/build-deploy.sh` | Build step that produces platform-independent output (both .sh and .ps1 deploy scripts). Runs once, result committed to git. Maintaining a parallel PS1 would double maintenance for no output difference. | 2026-02-17 | `aitools.ps1` calls via Git Bash (guaranteed prerequisite): `& $bashExe "$path/build-deploy.sh"` |

### PowerShell 5.1 compatibility

Windows ships with PowerShell 5.1 (Windows PowerShell). All `.ps1` scripts in this repo must work on PS 5.1.

Common PS 7+ features that break on 5.1:
- `-replace` with a scriptblock (e.g., `-replace 'pat', { $_.Groups[1] }`) — use `-match`/`$Matches` instead
- Null-coalescing `??` and null-conditional `?.` operators
- Ternary `$x ? $a : $b` — use `if/else` instead
- `Join-Path` with 3+ arguments — chain two calls instead
- `Set-Content -Encoding UTF8` writes BOM on 5.1 — use `[System.IO.File]::WriteAllText()` instead
- `[Parser]::ParseFile()` returns the AST object -- always assign to `$null` (i.e., `$null = [Parser]::ParseFile(...)`) or the full AST dumps to stdout

### ASCII-only rule for PS1 executable code

PS 5.1 reads BOM-free UTF-8 files using the system ANSI codepage (Windows-1252). Multi-byte UTF-8 characters (em-dash, curly quotes, ellipsis) can contain bytes that map to quote characters in Windows-1252, breaking string literals. Rules:
- No non-ASCII characters in PS1 executable code (strings, expressions)
- Non-ASCII in comments is tolerated but discouraged
- Use: `--` not em-dash, `"` not smart quotes, `...` not ellipsis

### PowerShell pipeline encoding gotcha

PowerShell pipes external command output through the console's codepage (often Windows-1252), not UTF-8. Non-ASCII bytes from external tools (pandoc, curl, git, etc.) get mangled to `?` (0x3F) in the pipeline. This affects all PS versions on Windows, not just 5.1.

**Never pipe UTF-8 output from external commands through PowerShell when non-ASCII content is expected.** Instead:
- Use temp files: write input with `[System.IO.File]::WriteAllText()`, run the command with `-o` output flag, read result with `[System.IO.File]::ReadAllText()`
- Or set `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` before piping (session-wide side effect)

### .NET vs PowerShell working directory

PowerShell's `Set-Location`/`cd` changes `$PWD` but NOT `[Environment]::CurrentDirectory` (the .NET CWD). Any .NET API that takes a relative path (`[IO.File]::WriteAllText`, `[IO.File]::ReadAllText`, etc.) resolves against the .NET CWD, not `$PWD`. This causes files to be written to the wrong location.

**Always resolve to absolute paths before calling .NET file APIs:**
```powershell
$resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($relativePath)
[System.IO.File]::WriteAllText($resolved, $content, ...)
```

### Pre-validation convention

When creating or modifying any `.ps1` or `.sh` script in this repo:
- Before committing, validate syntax on the current platform:
  - PS1: `powershell.exe -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('path', [ref]$null, [ref]$e); $e"`
  - Bash: `bash -n path/to/script.sh`
- On Windows, always validate PS1 files (PS 5.1 catches encoding and syntax issues that PS 7 does not)
- On macOS, always validate `.sh` files; PS1 validation requires `pwsh` (if installed)
- If the other platform's script can't be validated locally, note it in the commit message: `(tested: macOS)` or `(tested: Windows)`
- Note untested items in `RELEASE_NOTES.md` (see tested-platform convention)
