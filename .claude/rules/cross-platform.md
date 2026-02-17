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
