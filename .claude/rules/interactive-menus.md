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
handled at **every call site**. Scripts with multiple call sites (e.g.,
setup-user-claude deploys both CLAUDE.md and rules) must handle all return
values at each site independently.

**Known limitation:** Step 30 (return value coverage audit) validates at
file level, not call-site level. It can miss incomplete handlers when the
same file has another call site that does handle the value. Manual audit
is required for multi-deployment scripts.

Adding a new return value requires updating:

1. The function itself (both PS1 and bash)
2. `Record-DeployOutcome` / `deploy_tracker_record` (both)
3. Every caller's switch/case block (both)
4. `@reference/managed-file-deployment.md` (spec)

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
codepage (CP437) mangles non-ASCII. See `@reference/cross-platform-detail.md`
PowerShell pipeline encoding.

### JSON field-level review

JSON config deployments use field-level review rather than text diff
review. Only managed fields are shown; preserved fields are never
displayed or changed. Implemented by `prompt_json_field_review` /
`Prompt-JsonFieldReview` (one prompt per leaf), driven by
`sync_managed_json` / `Sync-ManagedJson` in `@scripts/aitools-lib.sh` / `.ps1`.

**Granularity**: review is per-leaf — one independent prompt per divergent
setting, and per rule string for `permissions.{allow,ask,deny}`. When the
source (`profile.json`) has a value the live file lacks, that leaf is auto-adopted
into the source with no prompt. `overwrite`/`adopt`/`skip` are per-leaf; only
`abort` is global (stops the run).

**Review display** (when a managed leaf differs):

```
  <field>: "current" → "proposed"  (source: profile.json)
```

**Menu**:

```
  [o]verwrite : proposed (source) value wins → settings.json
  [a]dopt     : local value wins → write back to profile.json
  [s]kip
  [x]abort    : stop the run (global)
```

- **Adopt** available only for fields sourced from `profile.json` (the
  settings sync mirrors all of settings.json there, so adopt applies to every
  managed leaf, including permission rules). Fields hardcoded in scripts cannot
  be adopted — adopt omitted when a changed field is script-sourced
- **No `[m]erge`** — JSON fields are discrete values, not text blocks
- **Non-interactive / `--force`**: auto-select overwrite (same as text types)

Cross-ref: `@reference/managed-file-deployment.md` "JSON Config Review
Detail"
