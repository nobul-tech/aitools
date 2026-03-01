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

### OS guard + dispatch rule

Every `.sh` setup script has `case "$(uname -s)" in MINGW*...) exit 1`. The bash `aitools` entry point runs in Git Bash on Windows. So:

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

### Pre-validation convention

When creating or modifying any `.ps1` or `.sh` script in this repo:
- Before committing, validate syntax on the current platform:
  - PS1: `pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('path', [ref]$null, [ref]$e); $e"`
  - Bash: `bash -n path/to/script.sh`
- On Windows, always validate PS1 files with pwsh
- On macOS, always validate `.sh` files; PS1 validation requires `pwsh` (managed tool -- install via `brew install powershell/tap/powershell`)
- If the other platform's script can't be validated locally, note it in the commit message: `(tested: macOS)` or `(tested: Windows)`
- Note untested items in `RELEASE_NOTES.md` (see verified-platform convention)
