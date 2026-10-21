## Interactive Deploy Menus (this repo)

> DRAFT — needs commander approval (new intent statement; the file had none).
> S4-Review merge of M2 (S5-Tools) and M3 (S5-Profile): adds the machine
> registration menu of `aitools user init` (M3) beside the tool menu (M2).

**Intent**: **Purpose**: Govern the interactive menus aitools shows —
option parity between bash and PowerShell, return-value handling,
non-interactive defaults, console I/O, and encoding — for managed-file
deployment, the tool install-method menu, and the machine registration
menu. **Scope**: Menu behaviour, defaults, and the JSON field-level review
contract. NOT the managed-file state machine
(`@reference/managed-file-deployment.md`). NOT the tool support decision
tree (`@reference/tool-support-decision-tree.md`). NOT machine resolution
order (`@reference/user-repo.md` "Resolution"). NOT JSON write safety
(`@.claude/rules/config-file-safety.md`). **Audience**: Agents writing or
changing menu code in `scripts/aitools-lib.sh` / `.ps1`, in setup scripts,
or in the `aitools` / `aitools.ps1` entry points.

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

Both managed-file menu functions MUST handle:
- `AITOOLS_FORCE` env var (`--force` / `-Force` on `aitools` and `aitools install`): auto-select `overwrite`
- Non-terminal stdin: auto-select `overwrite`
- EOF at the prompt (interactive, input ended): log a warning, auto-select `overwrite`

The installers apply the same rule to their own prompts (gh login, repos path):
terminal and not forced = prompt; otherwise use the default.

### Tool install-method menu

The menu of the tool support decision tree (`tool_method_menu` /
`Read-ToolMethodChoice`, `@reference/tool-support-decision-tree.md`) follows
the parity, console I/O, and encoding sections of this rule, with one
difference: `AITOOLS_FORCE`, non-terminal stdin, EOF, and unrecognised input
change nothing (a tool install has no overwrite equivalent; D-TS3). `[k]eep` is
remembered per machine (tool exception); the one-run keep is the empty default
(HOLD), unlike managed-file `[s]kip`. `[x]abort` exits 2 and stops the run once
the installer contract in the reference ("Contract with the installers and entry
points") lands -- the same contract fixes managed-file `[x]abort`. Exit 2 from a setup script
means user abort only; a script never passes a helper's return code 2 (for
example `resolve_machine_profile`'s "no match") through as its exit code.

### Machine registration menu

`aitools user init` asks which machine profile this machine is (numbered
aliases, `[n]ew`, `[s]kip`; `@reference/user-repo.md` "Registration") through
`tty_interactive` / `read_tty_choice` and their PowerShell equivalents, with
the same parity and console I/O rules. Non-terminal stdin, `AITOOLS_FORCE`,
and EOF never pick a profile: ERROR + ACTION (`aitools user init --alias
<alias>`), because a guessed machine writes another machine's values.

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
