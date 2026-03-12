# Managed File Deployment

Specification for the interactive file deployment system used by setup scripts
(`setup-user-claude`, `setup-user-mcp`, `setup-user-hooks`).

## Overview

When `aitools install` deploys a managed file (CLAUDE.md, rules, skills,
hooks, MCP configs), it compares source content against the local file. If
they differ, the user is shown a diff preview and menu to choose an action.

## Functions

| Function (PS1) | Function (bash) | Purpose |
|----------------|----------------|---------|
| `Prompt-DiffReview` | `prompt_diff_review` | Show diff + menu, return user's choice |
| `Deploy-ManagedFile` | `deploy_managed_file` | Orchestrate: compare, review, write |
| `Record-DeployOutcome` | `deploy_tracker_record` | Count outcomes for summary panel |
| `Try-AutoMerge` | `try_auto_merge` | 3-way merge via `git merge-file` |

## State Machine

```
Source content
    |
    +-- File doesn't exist --> write --> "created"
    |
    +-- Content identical --> "unchanged"
    |
    +-- Content differs
         |
         +-- Deploy state: user didn't edit --> auto-deploy --> "updated"
         |
         +-- User edited + source changed
              |
              +-- Ancestor available (deploy state)
              |    |
              |    +-- Auto-merge succeeds --> Auto-Merge Menu
              |    |    |
              |    |    +-- [a]ccept (AdoptLabel)  --> write + adopt --> "merge-adopted"
              |    |    +-- [a]ccept (no label)    --> write         --> "updated"
              |    |    +-- [o]verwrite            --> write source  --> "updated"
              |    |    +-- [s]kip                 -->               --> "skipped"
              |    |    +-- [x]abort               --> exit 2
              |    |
              |    +-- Auto-merge conflicts --> Fallback Menu
              |
              +-- No ancestor --> Fallback Menu
                   |
                   +-- [o]verwrite            --> write source  --> "updated"
                   +-- [a]dopt (AdoptLabel)   --> copy to prof  --> "adopted"
                   +-- [m]erge               --> AI merge+write --> "updated"
                   +-- [s]kip                -->               --> "skipped"
                   +-- [x]abort              --> exit 2
```

## Menus

### Auto-Merge Menu (clean 3-way merge available)

With AdoptLabel:
```
  [a]ccept    : deploy merge + update <AdoptLabel>
  [o]verwrite
  [s]kip
  [x]abort
  choice [a/o/s/x]:
```

Without AdoptLabel:
```
  [a]ccept
  [o]verwrite
  [s]kip
  [x]abort
  choice [a/o/s/x]:
```

### Fallback Menu (no ancestor or merge conflicts)

With AdoptLabel:
```
  [o]verwrite : source wins --> deploy to local (backup kept)
  [a]dopt     : local wins --> copy back to <AdoptLabel>
  [m]erge     : AI-assisted merge of source + local
  [s]kip      : keep local as-is (no changes)
  [x]abort    : stop deployment
  choice [o/a/m/s/x]:
```

Without AdoptLabel:
```
  [o]verwrite : source wins --> deploy to local (backup kept)
  [m]erge     : AI-assisted merge of source + local
  [s]kip      : keep local as-is (no changes)
  [x]abort    : stop deployment
  choice [o/m/s/x]:
```

### Non-Interactive Behavior

When `AITOOLS_FORCE` is set or stdin is not a terminal:
- Auto-select `overwrite` (no menu shown)
- Log the forced decision to deploy.log

## Return Values

### prompt_diff_review / Prompt-DiffReview

| Value | Menu | Meaning |
|-------|------|---------|
| `"merge-adopt"` | Auto-merge | Accept merge + update profile |
| `"merge"` | Auto-merge | Accept merge (no profile update) |
| `"overwrite"` | Both | Source wins (deploy to local) |
| `"adopt"` | Fallback | Local wins (copy to profile) |
| `"skip"` | Both | Keep local unchanged |
| (exit 2) | Both | User aborted |

### deploy_managed_file / Deploy-ManagedFile

| Value | Meaning | File written? | Profile updated? |
|-------|---------|--------------|-----------------|
| `"created"` | New file | Yes | No |
| `"updated"` | Content changed | Yes | No |
| `"unchanged"` | Content identical | No | No |
| `"merge-adopted"` | Merge accepted + profile | Yes | Yes |
| `"adopted"` | Local wins, copied to profile | No | Yes |
| `"skipped"` | User chose skip | No | No |

## Caller Responsibilities

Every caller of `deploy_managed_file` MUST handle all return values:

| Return value | Validation? | Adopt flow? | Tracker? |
|-------------|-------------|-------------|----------|
| `created` | Yes | If applicable | Yes |
| `updated` | Yes | If applicable | Yes |
| `unchanged` | No | No | Yes |
| `merge-adopted` | Yes | Adopt already done by lib | Yes |
| `adopted` | No | Adopt already done by caller | Yes |
| `skipped` | No | No | Yes |

## Deploy State (Shadow System)

`Update-DeployState` / `_update_deploy_state` stores the deployed content hash.
On next run, this becomes the "ancestor" for 3-way merge. Stored in
`~/.aitools/deploy-state/` as SHA256 hashes with a manifest.

## Normalization

Before comparing source and existing content, both are normalized:
- Trailing whitespace: collapse `[\r\n]+$` to single `\n`
- Prevents round-trip diff noise (deploy --> adopt strips blanks --> deploy
  sees diff)

## Encoding (PS1)

`Try-AutoMerge` uses in-place `git merge-file` (no `-p` flag) and reads the
result via `[IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)`. This avoids
PowerShell's OEM codepage mangling UTF-8 from external commands.
