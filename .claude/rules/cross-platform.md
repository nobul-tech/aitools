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
