## Interactive Deploy Menus (this repo)

### Pattern

Setup scripts that write managed files use `Deploy-ManagedFile` /
`deploy_managed_file` (aitools-lib) for interactive deployment with diff
review. The full state machine is documented in
`@reference/managed-file-deployment.md`.

### Cross-platform parity

PS1 and bash menus MUST show identical options in identical order. When
modifying a menu in one language, update the other immediately. Check scripts
validate this (`check-post-push` step 29: Menu parity audit).

### Return value contract

Every return value from `Deploy-ManagedFile` / `deploy_managed_file` MUST be
handled by every caller. Adding a new return value requires updating:

1. The function itself (both PS1 and bash)
2. `Record-DeployOutcome` / `deploy_tracker_record` (both)
3. Every caller's switch/case block (both)
4. `reference/managed-file-deployment.md` (spec)

Check scripts validate caller completeness (`check-post-push` step 30).

### Non-interactive fallback

Both menu functions MUST handle:
- `AITOOLS_FORCE` env var: auto-select `overwrite`
- Non-terminal stdin: auto-select `overwrite`

### Console I/O

- PS1: `[Console]::ReadLine()` / `[Console]::WriteLine()` -- NOT `Read-Host`
  (adds prompts) or `Write-Host` (can't redirect)
- Bash: `read -r < /dev/tty` / `printf ... > /dev/tty` -- NOT bare `read`
  (conflicts with piped input)

### Encoding

PS1 menus displaying content from external commands (git, pandoc, etc.) MUST
read via temp file + `[IO.File]::ReadAllText(..., UTF8)`. Never capture
external command stdout through the PowerShell pipeline for display -- OEM
codepage (CP437) mangles non-ASCII. See `cross-platform.md` PowerShell
pipeline encoding.
