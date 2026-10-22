## Interactive Deploy Menus (this repo)

### Pattern

Setup scripts that write managed files use `Deploy-ManagedFile` /
`deploy_managed_file` (aitools-lib) for interactive deployment with diff
review. The full state machine is documented in
`@reference/managed-file-deployment.md`; the choices are governed by
`@.claude/rules/agentic-standards.md` "Managed-file review choices and merge".

There is one review menu: `[o]verwrite` / `[a]ccept & adopt` /
`[m]erge & adopt` / `[s]kip` / `[x]abort`. `[a]` and `[m]` appear only when
the caller passed an adopt target. JSON files get the same choices per
field, without `[m]`.

### Cross-platform parity

PS1 and bash menus MUST show identical options in identical order. When
modifying a menu in one language, update the other immediately. Check scripts
validate this (`check-post-push` step 29: Menu parity audit).

### Return value contract

Every return value from `Deploy-ManagedFile` / `deploy_managed_file` MUST be
handled at **every call site**: `created`, `updated`, `verified`,
`accept & adopt`, `skipped`, `failed`. On `failed` the library has restored
its backups and logged the error; the caller records the outcome (ERROR row)
and continues. Scripts with multiple call sites (e.g.,
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

Every menu function (`prompt_diff_review`, `review_json_fields`,
`prompt_json_field_review` and their PS1 twins) MUST handle:
- `AITOOLS_FORCE` env var (`--force` / `-Force` on `aitools` and `aitools install`): auto-select `overwrite`
- Non-terminal stdin: auto-select `overwrite`
- EOF at the prompt (interactive, input ended): log a warning, auto-select `overwrite`

No AI merge runs in a non-interactive run.

### Abort

`[x]abort` logs an error and exits 2; a bare exit 2 is a user abort
(D-TS13). Abort ends this setup script; the installer continues with the
next script.

The installers apply the same rule to their own prompts (gh login, repos path):
terminal and not forced = prompt; otherwise use the default.

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
review. There are two regimes.

**SOURCE owns every field** (JSON deployed through `deploy_managed_file`,
reviewed by `review_json_fields` / `Review-JsonFields`): each field that
differs between SOURCE and LOCAL (key path; a whole array is one field) is
one review with `[o]verwrite` / `[a]ccept & adopt` / `[s]kip` / `[x]abort`
(`[a]` only with an adopt target; no `[m]erge`). An adopted value is written
to the adopt target immediately. A field only in LOCAL stays in LOCAL and is
never written to SOURCE without a review; with an adopt target it gets its
own review, `[a]ccept & adopt` / `[s]kip` / `[x]abort` (no overwrite, which
would delete user data). Key order is preserved.

**Profile mirror** (unchanged): `settings.json`, mirrored at `profile.json`
`claude.settings`. Only managed fields are shown; preserved fields are never
displayed or changed. Implemented by `prompt_json_field_review` /
`Prompt-JsonFieldReview` (one prompt per leaf), driven by
`sync_managed_json` / `Sync-ManagedJson` in `@scripts/aitools-lib.sh` / `.ps1`.

**Granularity**: review is per-leaf — one independent prompt per divergent
setting, and per rule string for `permissions.{allow,ask,deny}`. When the
live file has a leaf that `profile.json` lacks, that leaf is auto-adopted
into `profile.json` with no prompt. `overwrite`/`adopt`/`skip` are per-leaf; only
`abort` is not: it ends the script (exit 2) and nothing is applied.

**Review display** (when a managed leaf differs):

```
  <field>: "current" → "proposed"  (source: profile.json)
```

**Menu** (profile mirror):

```
  [o]verwrite : profile.json value -> settings.json
  [a]dopt     : keep settings.json value -> write to profile.json
  [s]kip      : leave this setting unchanged
  [x]abort    : stop the run
```

(`[x]abort` ends this setup script with exit 2; the installer continues
with the next script.)

- **Adopt** available for every managed leaf (the settings sync mirrors all
  of settings.json in `profile.json`, including permission rules)
- **No `[m]erge`** — JSON fields are discrete values, not text blocks
- **Non-interactive / `--force`**: auto-select overwrite (same as text types)

Cross-ref: `@reference/managed-file-deployment.md` "JSON Config Review
Detail"
