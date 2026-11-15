# Managed configuration

**Intent**: **Purpose**: Show, with ASCII diagrams, every user-scope
configuration file aitools writes (JSON configs, MCP registrations and
shell profile blocks): its writer, its source of truth, which fields it
owns and preserves, how a difference is detected, shown and resolved, and
where it lives on macOS, Linux and Windows. **Scope**: Configuration only.
NOT context files such as the user `CLAUDE.md` or `AGENTS.md`
(`@reference/managed-context.md`). NOT rules, skills, hooks, reference or
registry files (`@reference/artifact-manifests.md`). NOT the
`profile.json` schema or machine-profile resolution (`@reference/user-repo.md`).
NOT tool installation (`/tool-registry` skill). **Audience**: Agents and
maintainers changing a `setup-user-*` / `setup-cursor-*` script, the
settings sync in `scripts/aitools-lib.sh` / `.ps1` or `profile.json`, and
anyone asking why a setting changed, came back, or was adopted into the
dotprofile.

Version 1.0, 2026-11-07, Session Commander f500b663-7. A version, not a
draft (D-DEL5). Describes `main` at `ab3bc22`. Paths: `~` is `$HOME` on
macOS/Linux and `%USERPROFILE%` on Windows; section 8 lists both forms.

## 1. At a glance

```
  FILE (user scope)              WRITER                     SOURCE OF TRUTH              STRATEGY
  -----------------              ------                     ---------------              --------
  ~/.aitools/config.json         setup-user-config          installer flags +            merge owned keys,
                                 (the only writer)          profile.json (derived)       preserve the rest
  ~/.claude/settings.json        setup-user-settings        profile.json                 per-leaf sync with
    every key except "hooks"     (sync_managed_json)        claude.settings              review; auto-adopt
  ~/.claude/settings.json        setup-user-hooks           shared/hooks/                merge, silent
    "hooks" key                                             hooks-manifest.json
  ~/.claude.json                 setup-user-mcp, through    hardcoded in the script      compare, then
    user-scope MCP servers       `claude mcp add/remove`                                 remove + add
  ~/.cursor/cli-config.json      setup-user-cursor step 3   profile.json cursor.cli      merge owned keys,
                                                            (defaults without one)       preserve the rest
  ~/.cursor/mcp.json             setup-cursor-ide-mcp       hardcoded in the script      merge owned servers,
                                                                                         preserve the rest
  login profile PATH block       setup-user-shell           the script                   marked block,
    ~/.bash_profile | $PROFILE   (installer only)                                        replaced in place
  shell rc aliases line          aitools-install            shared/shell/aliases.sh|ps1  marker line,
    ~/.bashrc ~/.zshrc | $PROFILE (installer only)                                       added once
```

Three kinds of source of truth:

```
  dotprofile profile.json  ----> config.json (derived keys), settings.json (all but hooks),
  (aitools-<user>, git)          cli-config.json (cursor.cli)
  aitools repo (git)       ----> settings.json hooks (hooks manifest), aliases
  the setup script itself  ----> MCP servers (Claude Code, Cursor), PATH block
```

## 2. Where each runs

```
  aitools install  (scripts/aitools-install.sh | .ps1)
     Step 5   setup-user-config ............ config.json (bootstrap: reposPath, repoPath,
                                             googleDrives; plus the derived keys)
     ...      setup-user-shell ............. PATH block in the login profile
     ...      aliases source line .......... ~/.bashrc, ~/.zshrc  |  $PROFILE
     Step 8b  deploy-harness --skip-config . (config.json already written in Step 5)
     then     the same deploy scripts as `aitools` (below)

  aitools  (daily sync: deploy_configs in scripts/aitools | aitools.ps1)
     1  deploy-harness ..................... calls setup-user-config (config.json)
     2  setup-user-claude
     3  setup-user-mcp ..................... ~/.claude.json (via the claude CLI)
     4  setup-user-skills
     5  setup-cursor-ide-mcp ............... ~/.cursor/mcp.json
     6  setup-user-cursor .................. ~/.cursor/cli-config.json (step 3)
     7  setup-user-settings ................ settings.json, all but "hooks"
     8  setup-user-hooks ................... settings.json "hooks"
```

`--dry-run` and `--force` (`-DryRun`, `-Force`; `AITOOLS_DRY_RUN=1`,
`AITOOLS_FORCE=1`) reach every script. MDM runs the generated
`<dotprofile>/deploy/` copies (section 7).

## 3. Shared write discipline

Every JSON writer follows `.claude/rules/config-file-safety.md`:

```
  read existing file
     |-- missing ............. start from {}
     |-- invalid JSON ........ "corrupt": ERROR row, file untouched,
     |                         unless --force (then rewritten, WARN)
     v
  merge ONLY the owned keys (everything else preserved, key order kept)
     |
     v
  clobber check: a top-level key present before and missing after?
     |-- yes ................. ERROR "merge would lose fields", untouched,
     |                         unless --force (WARN)
     v
  compare (key order ignored) with what is on disk
     |-- equal ............... "verified" / "unchanged": nothing written
     v
  backup_file (<file>.bak.<TS>, at most 20 kept) -> write -> validate
     (parse + required keys; a failure is ERROR, and setup-user-config
      writes to a temp file first, so a failed merge leaves the old file)
     |
     v
  changes logged: "CHANGED: <key>: old -> new" lines and DETAIL rows
  (deploy.log), counts on the console
```

`--dry-run` plans and logs; nothing is written.

## 4. ~/.claude/settings.json: two owners, split by key

```
                      ~/.claude/settings.json
   +---------------------------------------------------------------+
   |  "hooks": {...}            |  every other key                  |
   |  owner: setup-user-hooks   |  owner: setup-user-settings       |
   |  source: hooks manifest    |  source: profile.json             |
   |  silent merge (no menu)    |          "claude": {"settings":{}}|
   +---------------------------------------------------------------+
```

### 4.1 Everything except hooks: the profile mirror (setup-user-settings)

`sync_managed_json` / `Sync-ManagedJson`. `profile.json` `claude.settings` is
a mirror of `settings.json`; the two are compared leaf by leaf.

```
  0. legacy migration: old top-level preference keys in profile.json move
     under claude.settings (logged "Migrated legacy prefs ...")
  1. deprecated permission rules removed from settings.json first, so they are
     never adopted: MCP(vercel), MCP(webflow), Agent(claude-code-guide)
  2. for every managed LEAF (any key path; permissions.allow / ask / deny one
     leaf PER RULE STRING):

     in settings.json only ................. AUTO-ADOPT into profile.json, no prompt
     equal ................................. nothing
     differ, or in profile.json only ....... per-leaf review:

        <field>: "current" -> "proposed"  (source: profile.json)
          [o]verwrite : profile.json value -> settings.json
          [a]dopt     : keep settings.json value -> write to profile.json
          [s]kip      : leave this setting unchanged
          [x]abort    : stop the script (exit 2; the run continues
                        with the next script)

        no terminal, EOF or --force -> overwrite
  3. backup both files, write the ones that changed, validate
```

- The review is per leaf: one prompt per differing setting and per
  permission rule, never one prompt for the whole file. There is no
  `[m]erge` for JSON.
- **Adopted values are not committed.** Auto-adopts and `[a]dopt` write
  `profile.json` in the dotprofile working tree; nothing commits or pushes
  it (unlike a managed-file adopt into the dotprofile, which
  `dotprofile_commit_push` commits and pushes). Commit the dotprofile, or
  the other machines never see the change; the session-start check warns
  "uncommitted changes in <dotprofile>".
- No dotprofile, or no `profile.json`: nothing synced, WARN
  `not synced: no dotprofile` / `profile.json missing`.

### 4.2 hooks (setup-user-hooks)

Generated from the hooks manifest: for each `{file, event, matcher}` one
entry `bash "<home>/.claude/hooks/<file>"` under `hooks.<event>`, updated in
place, added when missing, duplicates removed; stale hooks removed by a
hand-maintained list. No review menu: harness-managed keys reconcile
silently. After the write: every manifest hook registered exactly once,
command/prompt schema valid. Detail: `@reference/artifact-manifests.md`
section 5.

The hook command is an absolute path, so it differs per platform:

```
  macOS   bash "/Users/<you>/.claude/hooks/standing-order-guard.sh"
  Linux   bash "/home/<you>/.claude/hooks/standing-order-guard.sh"   (/root/... as root)
  Windows bash "C:/Users/<you>/.claude/hooks/standing-order-guard.sh"
```

## 5. ~/.aitools/config.json (setup-user-config)

The machine's own facts, derived; never hand-edited
(`@reference/user-repo.md` "Config Schema").

```
  INPUTS                                      OWNED KEYS
  ------                                      ----------
  flags from the caller                       version, meta
    --repos-path, --repo-path ............... reposPath, repoPath  (kept when not passed)
    --drives-json ........................... googleDrives (non-empty array; else kept or [])
    --machine-id | --no-machine
  aitools-profile.sh | .ps1 (resolver,
  from the dotprofile's profile.json) ....... githubUser, userRepoPath, machineId,
                                              machineAlias (kept when derivation fails)
  every other key ........................... preserved in place

  write path: merge into a temp file -> validate -> backup_file -> mv
  never prompts; exit 0 / 1; --dry-run merges in a system temp dir only
```

Called by `aitools install` Step 5, `aitools user init`, and
`deploy-harness` section 1 on every `aitools` run (skipped with
`--skip-config` when the installer already ran it). The MDM copy skips it
with OK `config.json` `n/a (no bootstrap)` when `reposPath` / `repoPath` are
absent.

## 6. MCP servers and Cursor CLI

### 6.1 Claude Code MCP: ~/.claude.json (setup-user-mcp)

aitools never edits `~/.claude.json`; it drives the `claude` CLI, which owns
the file.

```
  claude mcp list   (CLAUDECODE unset, so it works inside a session)
     -> "name=details" per server, ANSI stripped
     |
     for chrome-devtools, vercel, webflow:
        details == expected .......... nothing (row OK "claude mcp" "verified")
        missing / different / list
        unavailable / --force ........ claude mcp remove <name> --scope user
                                       claude mcp add ... --scope user
                                       (row OK "configured"; a failed add: ERROR)

  expected:
    chrome-devtools   local:            npx chrome-devtools-mcp@latest --isolated
                      claude-code-web:  npx -y chrome-devtools-mcp@latest --isolated
                                        --headless --chromeArg=--no-sandbox   (Linux only, D-CHR2)
                      Windows:          cmd /c npx chrome-devtools-mcp@latest -- --isolated
    vercel            --transport http  https://mcp.vercel.com
    webflow           --transport http  https://mcp.webflow.com/mcp
```

Permission rules for these servers are not written here: they are
`settings.json` leaves, owned by the profile mirror (4.1).

### 6.2 Cursor IDE MCP: ~/.cursor/mcp.json (setup-cursor-ide-mcp)

```
  read ~/.cursor/mcp.json -> merge mcpServers.chrome-devtools, .vercel, .webflow
  (other servers and top-level keys preserved) -> section 3 discipline
     CHANGED: <server>: old -> new  (logged)       rows: OK "cursor ide mcp"
                                                   "updated" | "verified"
  then, best-effort:  agent mcp remove vercel ; agent mcp remove webflow
     (Cursor's CLI no longer has disable/enable; "removed" stands in for the
      former default-off; a failure is a WARN; no `agent` CLI -> manual steps
      logged)
  changed -> ACTION "Restart Cursor IDE to apply MCP changes"
```

What `agent mcp remove` changes on disk, and whether the next run re-adds
the two servers to `mcp.json`, is not recorded in the script or in
`@reference/tool-ops-cursor.md`; verify before relying on either.

### 6.3 Cursor CLI: ~/.cursor/cli-config.json (setup-user-cursor step 3)

```
  profile.json cursor.cli  (dotprofile via the resolver)
     vimMode (bool, default false), model (default "auto")
     resolver error -> merge SKIPPED (ERROR "not merged: dotprofile error"),
                       never defaults written over the user's choices
     no dotprofile  -> defaults
        |
        v
  owned:      version (= 1), editor.vimMode, permissions (allow/deny arrays
              ensured), model (only when "auto"), hasChangedDefaultModel
  preserved:  authInfo, privacyCache, network, statsigBootstrap, maxMode, and
              every other key
  rows:       OK "cursor cli" created | updated | verified | "dry-run: would update"
```

## 7. Delivery paths

```
                     DEV                          MDM (<dotprofile>/deploy/)           PACKAGE
  settings.json      live profile.json            live profile.json (resolver at       live dotprofile, else
  (profile mirror)                                run time); none -> not synced        n/a (no dotprofile)
  settings hooks     repo manifest                manifest + registration list         repo manifest (payload)
                                                  embedded at build time
  config.json        writer in scripts/           writer copied into deploy/; skipped  writer in the payload;
                                                  without the bootstrap keys           repoPath = the payload
  cli-config.json    live profile.json            live profile.json, else the          live dotprofile, else
                                                  build-time cursor.cli values         defaults
  MCP                scripts                      extracted, same code                 same code
  shell blocks       installer                    setup-user-shell copied as is;       installer
                                                  aliases not wired (no shared/)
```

No machine's values are interpolated at build time
(`.claude/rules/deploy-paths.md`).

## 8. Paths

```
  WHAT                        macOS                          Linux                          Windows
  ----                        -----                          -----                          -------
  aitools config              ~/.aitools/config.json         ~/.aitools/config.json         %USERPROFILE%\.aitools\config.json
  Claude settings             ~/.claude/settings.json        ~/.claude/settings.json        %USERPROFILE%\.claude\settings.json
  Claude MCP (CLI-owned)      ~/.claude.json                 ~/.claude.json                 %USERPROFILE%\.claude.json
  Cursor CLI config           ~/.cursor/cli-config.json      ~/.cursor/cli-config.json      %USERPROFILE%\.cursor\cli-config.json
  Cursor IDE MCP              ~/.cursor/mcp.json             ~/.cursor/mcp.json             %USERPROFILE%\.cursor\mcp.json
  PATH block                  ~/.bash_profile                ~/.bash_profile                $PROFILE (PowerShell 7 profile)
  aliases line                ~/.bashrc, ~/.zshrc            ~/.bashrc, ~/.zshrc            $PROFILE
  aliases source              shared/shell/aliases.sh        shared/shell/aliases.sh        shared\shell\aliases.ps1
  profile.json                ~/repos/aitools-<user>/        ~/repos/aitools-<user>/        %USERPROFILE%\repos\aitools-<user>\
                              profile.json                   profile.json                   profile.json
  backups                     <file>.bak.<TS> beside it      <file>.bak.<TS> beside it      <file>.bak.<TS> beside it
  log                         ~/.aitools/logs/deploy.log     ~/.aitools/logs/deploy.log     %USERPROFILE%\.aitools\logs\deploy.log
  writers                     scripts/<name>.sh (bash)       scripts/<name>.sh (bash)       scripts/<name>.ps1 (pwsh 7)
```

- **Linux = macOS** for every script: one `.sh` per tool (D-ENV0). The
  only branches are by capability (Homebrew present for the PATH block)
  and by environment (`claude-code-web`, Linux only, for the chrome-devtools
  arguments in 6.1).
- **Windows**: the `.ps1` twins write the same files under `%USERPROFILE%`.
  Paths inside JSON values use forward slashes where the consumer is bash
  (hook commands, 4.2).
- **PATH block precedence** (macOS/Linux): `~/.local/bin`, then Homebrew
  (`brew shellenv`), then any earlier installer prepends, then the system.
  Windows: `$HOME\.local\bin` prepended in `$PROFILE`.

## 9. Cross-references

- Write safety, read-then-merge, backups: `.claude/rules/config-file-safety.md`
- Settings review menu and per-leaf rules: `.claude/rules/interactive-menus.md`
  "JSON field-level review"
- Platform-specific config values: `.claude/rules/managed-file-deployment.md`
  "Platform-specific config values"
- profile.json, config.json schema, resolution: `@reference/user-repo.md`
- Hooks manifest and settings registration: `@reference/artifact-manifests.md`
- User CLAUDE.md and AGENTS.md: `@reference/managed-context.md`
- Code: `scripts/setup-user-config`, `setup-user-settings`, `setup-user-hooks`,
  `setup-user-mcp`, `setup-cursor-ide-mcp`, `setup-user-cursor`,
  `setup-user-shell` (`.sh` / `.ps1`); `sync_managed_json` in
  `scripts/aitools-lib.sh` (`Sync-ManagedJson` in `.ps1`)
