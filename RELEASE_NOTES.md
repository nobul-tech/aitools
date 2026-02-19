# aitools Release Notes

## Versioning

`major.minor.patch` -- not semver (no API contract), but follows the same spirit:

- **Major** (v3 → v4): structural changes to CLI commands, architecture, or project layout
- **Minor** (v3.3): new features, new managed tools, batches of improvements
- **Patch** (v3.3.1): isolated bug fixes with no new functionality

Multiple changes on the same day roll into one release. Bug fixes ship alongside features in the same minor if they land together.

---

## v3.9 -- MCP Concurrency, Cursor Rule Parity, Tool Lifecycle Fields (2026-02-19)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | Chrome DevTools MCP now uses `--isolated` flag across all setup scripts (Claude Code and Cursor, macOS and Windows). Creates throwaway temp Chrome profiles per process, preventing Chrome profile lock conflicts when Claude Code and Cursor run concurrently. |

### Improvements

| # | Change |
|---|--------|
| 2 | **Tool lifecycle entries standardized**: All managed tools in `reference/tool-install-sources.md` now include 4 mandatory fields: Platform Status, Concurrency, Post-Install Config, Dependencies. Phase 1 recording requirements updated in `reference/tool-evaluation-criteria.md`. |
| 3 | **Cursor project rules parity**: Created 4 new `.cursor/rules/*.mdc` files mirroring Claude Code rules: `sources-of-truth.mdc`, `tool-lifecycle.mdc`, `cross-platform.mdc`, `concurrent-agents.mdc`. Updated `general.mdc` (moved cross-platform to dedicated file). |
| 4 | **Concurrent agent coordination**: New rule (`.claude/rules/concurrent-agents.md` + `.cursor/rules/concurrent-agents.mdc`) for multi-agent codebase editing awareness. |
| 5 | **Protected files expanded**: `.cursor/rules/*.mdc` added to source-of-truth protected files table. Agent column added for future ownership restrictions. |
| 11 | **Pre-commit/pre-push/post-push checklists**: New rules for all three git lifecycle stages (`.claude/rules/` + `.cursor/rules/` mirrors). Pre-commit: identity, syntax, build freshness, line endings, platform note. Pre-push: scratch files, release notes, roadmap, deploy freshness, branch hygiene. Post-push: two tiers (Always + Extensive) with 17 audit items and flag disposition protocol. |

### Documentation

| # | Change |
|---|--------|
| 6 | `shared/mcp/README.md`: New "Concurrency" and "Post-Setup Authentication" sections. Prominently notes Vercel/Webflow OAuth requirement. |
| 7 | `reference/cursor-practices.md`: New "Rule Correspondence" table mapping Claude Code to Cursor rules, with "Changing rules" workflow. |
| 8 | `reference/tool-install-sources.md`: Chrome DevTools MCP install commands updated to include `--isolated`. All tool entries expanded with lifecycle fields. |
| 9 | `CLAUDE.md`: Two new key decisions (`--isolated` for stdio MCP, 4 lifecycle fields). Project structure expanded to show `.cursor/rules/` files. |
| 10 | Deleted `plans/cursor-vs-claude-code-rules-blueprint.md` (absorbed into `reference/cursor-practices.md`). |

### Files created

| File | Purpose |
|------|---------|
| `.claude/rules/concurrent-agents.md` | Concurrent agent coordination rule (Claude Code) |
| `.cursor/rules/sources-of-truth.mdc` | Protected files review gate (Cursor) |
| `.cursor/rules/tool-lifecycle.mdc` | Tool lifecycle gate (Cursor) |
| `.cursor/rules/cross-platform.mdc` | Cross-platform rules (Cursor, condensed) |
| `.cursor/rules/concurrent-agents.mdc` | Concurrent agent coordination rule (Cursor) |
| `.claude/rules/pre-commit.md` | Pre-commit checklist (Claude Code) |
| `.claude/rules/pre-push.md` | Pre-push checklist (Claude Code) |
| `.claude/rules/post-push.md` | Post-push audit checklist (Claude Code) |
| `.cursor/rules/pre-commit.mdc` | Pre-commit checklist (Cursor) |
| `.cursor/rules/pre-push.mdc` | Pre-push checklist (Cursor) |
| `.cursor/rules/post-push.mdc` | Post-push audit checklist (Cursor) |

**Verified on:** macOS (build validated, all setup scripts syntax-checked). Windows: PS1 MCP setup scripts updated but not validated on this machine.

---

## v3.8 -- Session Auto-Archive & User Repo (2026-02-19)

### New features

| # | Change |
|---|--------|
| 1 | **Session auto-archive**: Claude Code `SessionEnd` hook copies session transcripts to a private user repo (`aitools-<username>`) after each session ends. Files are organized by project under `sessions/<project>/<date>_<prefix>.jsonl`. Hook runs silently, never blocks Claude Code, and performs no git operations. |
| 2 | **`aitools user init`**: Interactive setup for the user repo -- detects GitHub username, creates repo with `profile.json` and `sessions/` structure, optionally creates a private GitHub repo, writes `userRepoPath` to config, and deploys the session archive hook. |
| 3 | **`aitools sessions list [project]`**: Lists archived sessions with file sizes, optionally filtered by project name. |
| 4 | **`aitools sessions archive <id>`**: Manually archives a specific session by ID (full UUID or prefix). Reads CWD from the JSONL transcript to derive the correct project name. |
| 5 | **`aitools sessions move <file> <project>`**: Refiles an archived session under a different project. Handles the case where CWD didn't match the actual project being worked on. |
| 6 | **Hook auto-deploy**: `setup-user-hooks.sh/.ps1` added to the deploy pipeline. Running `aitools` (no args) now installs/updates the hook in `~/.claude/settings.json` and shows a hint if the user repo isn't set up yet. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 7 | BUG | `aitools user init` (bash) now dispatches to `.ps1` on Windows for hook deployment. Previously called `setup-user-hooks.sh` which has an OS guard that rejects Windows. |
| 8 | BUG | `sessions archive` project derivation: Claude Code stores sessions in directories named by replacing `/` with `-` in the CWD path, which is lossy for project names containing hyphens (e.g., `ai-tooling` became `tooling`). Fixed by reading the actual `cwd` from the JSONL transcript via node instead of parsing the ambiguous directory name. |

### Documentation

| # | Change |
|---|--------|
| 9 | New `reference/user-repo.md`: documents the user repo pattern, naming convention, session naming, project derivation, and CLI commands. |
| 10 | `plans/user-repo-and-session-hooks.md`: status updated to "Phase A implemented", open questions resolved (hook schema, jq dependency, project derivation). |
| 11 | `shared/claude-shared.md`: strengthened "Smaller batches" coaching bullet (rules ignored when batch size causes focus to narrow); added "Subagent context gap" coaching bullet (subagents don't inherit project rules). |
| 12 | `reference/claude-code-practices.md`: new "Session Storage Internals" section documenting `~/.claude/projects/` storage scheme, lossy path sanitization, and JSONL transcript structure. |
| 13 | `reference/claude-code-effectiveness.md`: progress log entry for v3.8 implementation lessons. |

### Bug fixes (follow-up)

| # | Severity | Fix |
|---|----------|-----|
| 14 | BUG | Restored executable bits on `setup-user-hooks.sh` and `session-archive.sh` — the Write tool dropped them during initial creation. |

### Files created

| File | Purpose |
|------|---------|
| `shared/hooks/session-archive.sh` | SessionEnd hook script (bash-only, runs on both platforms) |
| `scripts/setup-user-hooks.sh` | Deploys hook config to `~/.claude/settings.json` (macOS/Linux) |
| `scripts/setup-user-hooks.ps1` | Same for Windows |
| `reference/user-repo.md` | User repo pattern documentation |

**Verified on:** macOS (hook, setup, all CLI commands tested end-to-end). Windows untested (PS1 scripts not validated on this machine).

---

## v3.7 -- Tool Lifecycle Terminology & Verified-on Convention (2026-02-18)

### Improvements

| # | Change |
|---|--------|
| 1 | **4-state tool lifecycle per platform**: Replaced the 3-value model (`approved`/`pending`/`n/a`) with a 4-state lifecycle (`evaluating` → `approved` → `supported`, plus `n/a`). The new intermediate `approved` state distinguishes "user said yes" from "fully scripted with setup scripts." Canonical definition in `reference/tool-evaluation-criteria.md`. |
| 2 | **"Tested on" → "Verified on" convention**: Renamed `**Tested on:**` to `**Verified on:**` across all release notes (9 instances). Eliminates overloading: "verified" means release changes were checked on this platform; "approved"/"supported" describe tool lifecycle status. Convention section renamed accordingly. |

### Tool status (under new terminology)

| Tool | macOS | Windows |
|------|-------|---------|
| Claude Code CLI | supported | supported |
| Vercel CLI | supported | supported |
| Cursor Agent CLI | supported | supported |
| Node.js | supported | supported |
| Pandoc | supported | supported |
| MCP servers (chrome-devtools, vercel, webflow) | supported | supported |
| Typst | evaluating | evaluating |

### Documentation

| # | Change |
|---|--------|
| 3 | `reference/tool-evaluation-criteria.md`: new "Tool Platform States" section defining the 4 states and their mapping to lifecycle phases. |
| 4 | `CLAUDE.md`: new key decision for tool platform states and verified-on convention. |
| 5 | `.claude/rules/cross-platform.md`: `tested-platform` → `verified-platform` reference. |
| 6 | `plans/per-platform-tool-approval.md`: updated from 3-value to 4-state model, resolved open questions (inline status, installer warnings are future scope). |
| 7 | `RELEASE_NOTES.md` v3.6 item #2: updated to reference 4-state model. |

**Verified on:** macOS. Windows not affected (documentation-only changes).

---

## v3.6 -- Roadmap System & Typst Evaluation (2026-02-18)

### New features

| # | Change |
|---|--------|
| 1 | **Roadmap tracking system**: `ROADMAP.md` at project root tracks active/planned work items with links to detailed plans in `plans/`. Completed items move to `RELEASE_NOTES.md`. |
| 2 | **Per-platform tool approval plan filed**: First roadmap item — detailed plan for separating tool approval pipelines per platform (macOS/Windows). Introduces a 4-state lifecycle model (`evaluating`/`approved`/`supported`/`n/a`) per platform. Plan only, no implementation yet. |

### Tool evaluation

| # | Change |
|---|--------|
| 3 | **Typst** added to "Under Evaluation" in `reference/tool-install-sources.md`. PDF engine for pandoc (`--pdf-engine=typst`) — single ~30-50 MB binary vs multi-GB LaTeX distributions. Pending hands-on testing before approval. |

### Documentation

| # | Change |
|---|--------|
| 4 | `CLAUDE.md`: added `plans/` to project structure, added roadmap tracking key decision. |
| 5 | `.claude/rules/sources-of-truth.md`: `ROADMAP.md` and `plans/*.md` added to protected files table. |
| 6 | Deploy scripts (`setup-user-claude.sh/.ps1`) rebuilt with coaching notes from `shared/claude-shared.md`. |

**Verified on:** macOS. Windows not affected (documentation-only changes; deploy scripts are generated output).

---

## v3.5.1 -- clip2md macOS fixes (2026-02-18)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `clip2md` (bash) crashed with `tr: Illegal byte sequence` on macOS, preventing auto-naming. Root cause: `perl -pe` without `-CSD` flag can't match multi-byte Unicode characters. `\x{00A0}` (NBSP) only replaced the `\xa0` byte, leaving an orphaned `\xc2` that corrupted the output. `\x{202F}` (narrow NBSP) was not matched at all. Fixed by adding `-CSD` (UTF-8 I/O mode) to the perl invocation. |
| 2 | BUG | `clip2md` and `cc` overwrite/init prompts failed in zsh with `read:NNN: -p: no coprocess`. Root cause: `read -rp "prompt"` is bash-only; in zsh `-p` means coprocess. Fixed by splitting into `printf "prompt"` + `read -r answer`, which works in both shells. |

### Documentation

| # | Change |
|---|--------|
| 3 | Added coaching notes to `shared/claude-shared.md`: ask the user for help when the environment is broken instead of brute-forcing workarounds; always `cd` back before deleting temp dirs. |

**Verified on:** macOS (bash -n validated, clip2md auto-name and explicit-name tested end-to-end). Windows not affected (PS1 uses native .NET Unicode and `Read-Host`).

---

## v3.5 -- clip2md AI-Powered Naming & Logging (2026-02-18)

### New features

| # | Change |
|---|--------|
| 1 | **clip2md auto-naming**: Running `clip2md` with no arguments uses the Claude Code CLI (`claude -p`) to generate a descriptive filename and one-line summary. Content-type-aware prompt: emails get `YYMMDD-participant-topic`, articles get `source-topic`, docs get `product-section`. Max 50 chars but compact by default. Writes to hidden temp file, renames on success. Collision avoidance via `-2`, `-3` suffixes. |
| 2 | **clip2md explicit-name improvements**: `clip2md notes` auto-appends `.md`, prompts before overwriting, shows AI summary when claude is available. |
| 3 | **clip2md logging**: All operations log to `clip2md.log` (Windows: `%LOCALAPPDATA%\ai-tooling\`, macOS: `~/Library/Logs/ai-tooling/`). Events: saves, errors, temp file lifecycle, overwrite decisions. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 4 | BUG | `clip2md` (bash) `.md` extension strip was case-sensitive -- `clip2md notes.MD` produced `notes.MD.md`. Fixed with glob character class `%.[mM][dD]`. |

### Implementation details

| # | Detail |
|---|--------|
| 5 | AI helper `_clip2md_ai` sanitizes Claude's response: filename lowercased, non-alnum replaced with hyphens, truncated to 50 chars at word boundary, Windows reserved names prefixed with `clip-`. Summary truncated to 80 chars at word boundary. |
| 6 | PS1 temp file uses `Get-Random` for uniqueness; bash uses `$$-$RANDOM`. Hidden via dot prefix (`.clip2md-<random>.tmp`). Cleanup via `try/finally` (PS1) or explicit error-path removal (bash). |
| 7 | PS1 pipes markdown to `claude -p` directly (accepts potential pipeline encoding mangling since Claude only needs topic understanding, not exact content). File content is written from the pre-pipe `$md` variable. |

**Verified on:** Windows (PS1 validated, auto-name and explicit-name tested end-to-end). macOS tested in v3.5.1.

---

## v3.4.4 -- clip2md clipboard encoding fix (2026-02-17)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `clip2md` (PS1) produced mojibake for em-dashes, curly quotes, and NBSP. Root cause: `[System.Windows.Forms.Clipboard]::GetData("HTML Format")` decodes UTF-8 clipboard bytes as Windows-1252, producing double-encoded characters. Fixed by re-encoding the string back to bytes via Windows-1252, then decoding as UTF-8. |
| 2 | BUG | `clip2md` (PS1) now also strips narrow no-break space (U+202F) alongside regular NBSP (U+00A0). Gmail uses narrow NBSP around time values. |

### Documentation

| # | Change |
|---|--------|
| 3 | Added .NET clipboard encoding gotcha to `.claude/rules/cross-platform.md`. |

**Verified on:** Windows (PS1 validated). macOS not affected (bash clipboard path uses osascript).

---

## v3.4 -- Graceful Tool Addition & Cross-Platform Safety (2026-02-17)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `setup-pandoc.ps1` contained an em-dash (U+2014) in a string literal. PS 5.1 reads BOM-free UTF-8 as Windows-1252, where the em-dash's bytes include `0x94` (right double quotation mark), prematurely terminating the string and causing cascading parse errors. Replaced with `--`. |

### Improvements

| # | Change |
|---|--------|
| 2 | **Pre-validation for setup scripts**: `aitools-install.ps1` now validates PS1 scripts with `[Parser]::ParseFile` before executing. Scripts with parse errors are skipped with a warning instead of failing with cascading errors. `aitools-install.sh` does the same with `bash -n`. |
| 3 | **Pre-validation for deploy configs**: `deploy_configs()` (bash) and `Deploy-Configs` (PS1) in the `aitools` CLI now validate each script before executing, using the same ParseFile/`bash -n` pattern. |
| 4 | **Build-time PS1 validation** (Windows only): `build-deploy.sh` validates all generated `.ps1` deploy scripts with `ParseFile` after building. Catches encoding and syntax errors at build time. |

### Documentation

| # | Change |
|---|--------|
| 5 | Added ASCII-only rule for PS1 executable code to `.claude/rules/cross-platform.md`. |
| 6 | Added pre-validation convention to `.claude/rules/cross-platform.md`. |
| 7 | Added verified-platform convention to release notes (see below). |

### Verified-platform convention

Each release section ends with a verified-platform note:
```
**Verified on:** Windows. macOS untested for items 2, 3, 4.
```

**Verified on:** Windows. macOS untested for items 2, 3, 4.

---

## v3.4.1 -- clip2md NBSP fix (2026-02-17)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `clip2md` (both `.sh` and `.ps1`) now converts non-breaking spaces (U+00A0) to regular spaces. Gmail uses `&nbsp;` extensively; pandoc passes these through as raw NBSP bytes, which render as `??` in terminal output and pollute saved markdown files. |

**Verified on:** Windows (PS1 validated). macOS untested for item 1.

---

## v3.4.2 -- clip2md pipeline encoding fix (2026-02-17)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `clip2md` (PS1) piped pandoc output through PowerShell, which uses the console codepage (not UTF-8). Non-ASCII characters (NBSP, curly quotes, em-dashes) were mangled to `?` (0x3F) before the `-replace` fix could match them. Rewrote to use temp files for pandoc I/O, bypassing the pipeline entirely. Also strips `&nbsp;` entities from HTML before pandoc. |
| 2 | BUG | `clip2md` (bash) now also strips `&nbsp;` entities at the HTML stage before pandoc, as defense in depth. |

### Documentation

| # | Change |
|---|--------|
| 3 | Added PowerShell pipeline encoding gotcha to `.claude/rules/cross-platform.md`. |

**Verified on:** Windows (PS1 validated). macOS untested for item 2.

---

## v3.4.3 -- clip2md path resolution and empty output guard (2026-02-17)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `clip2md` (PS1) wrote output files relative to the .NET working directory (`[Environment]::CurrentDirectory`) instead of PowerShell's `$PWD`. Files ended up in `$HOME` instead of the current directory. Fixed by resolving paths with `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath()` before calling `[IO.File]::WriteAllText()`. |
| 2 | BUG | `clip2md` (PS1) now shows an error if pandoc produces empty output, instead of silently writing an empty file. |

### Documentation

| # | Change |
|---|--------|
| 3 | Added .NET vs PowerShell working directory gotcha to `.claude/rules/cross-platform.md`. |

**Verified on:** Windows (PS1 validated). macOS not affected (bash CWD tracks correctly).

---

## v3.3 — Pandoc Integration, Tool Lifecycle, PS 5.1 Fix (2026-02-17)

### New features

| # | Change |
|---|--------|
| 1 | **Pandoc integration**: new `setup-pandoc.sh`/`.ps1` setup scripts, `clip2md` alias for clipboard-to-markdown conversion via pandoc. |
| 2 | **Tool lifecycle rules**: added source-of-truth review gate (`.claude/rules/sources-of-truth.md`) and tool lifecycle gate (`.claude/rules/tool-lifecycle.md`) to enforce phased tool adoption. |
| 3 | **Self-update resilience**: `aitools` and `aitools.ps1` now validate syntax (`bash -n` / `[Parser]::ParseFile`) before overwriting the installed copy. If the repo version has parse errors on the current platform, the self-update is skipped with a warning — the working installed copy stays in place. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 4 | BUG | `aitools.ps1` path conversion used a `-replace` scriptblock (PowerShell 7+ feature). On Windows PowerShell 5.1, the scriptblock was stringified instead of executed, producing a garbage path that caused `build-deploy.sh` to fail. Replaced with `-match`/`$Matches` which works on all PS versions. |
| 5 | BUG | `clip2md` output now strips Gmail inline styles and empty pandoc attribute blocks (`{...}`) for cleaner markdown. |

### Documentation

| # | Change |
|---|--------|
| 6 | Added release versioning convention to `RELEASE_NOTES.md` and `CLAUDE.md` Key Decisions. |
| 7 | Added PowerShell 5.1 compatibility rule to `.claude/rules/cross-platform.md` — documents minimum PS version target and common PS 7+ gotchas. |

---

## v3.2 — Deploy Script Fixes + Error Tracking (2026-02-16)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | Generated bash deploy scripts now define logging helpers before the OS guard, so `log_error` is available when the guard fires. |
| 2 | BUG | Generated bash deploy scripts log to `~/Library/Logs/ai-tooling/deploy.log` (matching source scripts and `aitools` CLI), not `~/Library/Logs/ai-tooling-deploy.log`. |
| 3 | BUG | `setup-cursor-mcp.ps1` and `setup-user-cursor.ps1` now write BOM-free UTF-8 via `[System.IO.File]::WriteAllText` instead of `Set-Content -Encoding UTF8`. Fixes JSON parsing issues on PowerShell 5.1. |

### Improvements

| # | Severity | Change |
|---|----------|--------|
| 4 | WARNING | `setup-user-mcp` and `setup-cursor-mcp` (both `.sh` and `.ps1`) now track errors and exit with code 1 on failure, matching the pattern used by other setup scripts. |
| 5 | STALE | Fixed drifted line-number reference in `reference/claude-code-windows-shell.md`. |

---

## v3.1 — Cross-Platform Bug Fixes (2026-02-16)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `setup-user-cursor` no longer opens GUI editor or overwrites clipboard during automated deploy (`aitools`/`aitools gitpull`). Interactive behavior preserved when run directly. |
| 2 | BUG | PS1 `Deploy-Configs` no longer double-counts errors or reports false failures from stale `$LASTEXITCODE`. Reset between iterations; `continue` after catch prevents double-increment. |
| 3 | BUG | PS1 `setup-user-mcp.ps1` now unsets `CLAUDECODE` env var before `claude mcp add`, matching the bash version. Fixes failure when run inside a Claude Code session. |
| 4 | BUG | PS1 `aitools.ps1` now converts `$repoPath` to Unix-style path before passing to `bash.exe` for `build-deploy.sh`. Prevents fragile mixed-path parsing in Git Bash. |
| 5 | BUG | `--addmcp`, `--version`, `--help` now work on PowerShell 5.1. PS 5.1 doesn't support `--` prefix; these flags are now detected as positional args and remapped. |
| 6 | WARNING | PS1 self-update now stamps both `aitools.ps1` and bash `aitools`, matching the bash self-update behavior. Prevents stale version stamps. |
| 7 | WARNING | Fixed double-logging in `deploy_configs()`. Child scripts already log to the deploy log via tee/Add-Content; parent now redirects stdout to /dev/null instead of the same file. |
| 8 | WARNING | PS1 scripts now write BOM-free UTF-8 via `[System.IO.File]::WriteAllText` instead of `Set-Content -Encoding UTF8` (which writes BOM on PowerShell 5.1). Affects `setup-user-claude.ps1` and `setup-user-mcp.ps1`. |

### How the interactive gate works

Setup scripts that touch the clipboard or open GUI editors now check whether they're being called interactively:

- **Bash** (`setup-user-cursor.sh`): `[ -t 1 ]` — true when stdout is a terminal, false when redirected by `deploy_configs()`
- **PowerShell** (`setup-user-cursor.ps1`): `$env:AITOOLS_DEPLOY` — set by `deploy_configs()` / `Deploy-Configs` before calling child scripts, cleared after

When non-interactive, clipboard copy and `open`/`Start-Process` are skipped. Running the script directly still triggers both.

---

## v3 — Config Sync, Version Tagging, Config Backups (2026-02-16)

### New command structure

| Command | What it does |
|---------|-------------|
| `aitools` (no args) | Quiet pull + rebuild + deploy all configs. Warns and continues if offline. |
| `aitools gitpull` | Pull + rebuild + deploy + date-formatted changelog + version tag. Clones repo if missing. |
| `aitools install` | Pull + rebuild + install all tools + deploy configs (unchanged). |

**Machine-switching workflow:**
- Arrive at machine → `aitools` (quick sync) or `aitools gitpull` (verbose changelog)
- Full setup → `aitools install`

### Version tagging

`aitools gitpull` creates and pushes a version tag: `v<date>.<session>.0` (e.g., `v2026-02-16.1.0`).
Commits after a tag are shown by `--version` as `2026-02-16.1.3` (3 commits since tag).
Falls back to `YYYY-MM-DD (hash)` when no tags exist.

### Config file backups

Setup scripts now back up files before overwriting. Keeps at most 20 timestamped copies per file.

| File | Backed up by |
|------|-------------|
| `~/.claude/CLAUDE.md` | `setup-user-claude` |
| `~/.cursor/mcp.json` | `setup-cursor-mcp` |

Backup format: `<file>.bak.<ISO-UTC-timestamp>` (e.g., `CLAUDE.md.bak.2026-02-17T023527Z`)

### Cross-platform fix

The bash `aitools` entry point now correctly dispatches to `.ps1` scripts via `powershell.exe` on Windows for all code paths (no-args, gitpull, install). Previously, only the `install` path had this forwarding — the new `deploy_configs()` function was missing it.

Added dispatch rule documentation to user-level CLAUDE.md, project CLAUDE.md, and `.claude/rules/cross-platform.md` to prevent recurrence.

---

## v2 — CLI Subcommands, MCP Restructuring, Full Tool Chain (2026-02-14)

### CLI Subcommands

`aitools` now separates sync from install:

- `aitools` — Pull latest + rebuild deploy scripts + self-update. Does not install.
- `aitools install` — Install/update ALL dev tools and deploy configurations.
- `aitools --addmcp <name...>` — Add MCP servers to the current project.

### Full Tool Chain via `aitools install`

`aitools install` is now the single command that installs and updates everything:

| Tool | Install method |
|------|---------------|
| GitHub CLI (gh) | brew (macOS) / winget (Windows) |
| Node.js | brew (macOS) / winget (Windows) |
| Claude Code CLI | Native installer (auto-updates) / winget (Windows) |
| Vercel CLI | npm install -g vercel |
| Cursor CLI | Official installer |
| ripgrep | brew (macOS) / winget (Windows) |
| Chrome DevTools MCP | Configured at user level |

### MCP Architecture Change

User-level MCP now includes **only chrome-devtools**. Vercel and Webflow are now
added per-project to reduce context bloat (flagged by `claude doctor`).

- **Before**: chrome-devtools, vercel, webflow all at user level
- **After**: chrome-devtools at user level; vercel/webflow at project level via `--addmcp`

Legacy user-level vercel/webflow entries are cleaned up on next `aitools install`.

### New: `aitools --addmcp`

Add MCP servers to the current project for all AI tools (Claude Code + Cursor):

    cd ~/repos/my-project
    aitools --addmcp vercel
    aitools --addmcp vercel webflow

Creates/updates `.mcp.json` (Claude Code) and `.cursor/mcp.json` (Cursor).
Merges with existing config — safe to re-run.

Supported servers: `vercel`, `webflow`

### Logging Improvements

All MCP setup scripts now include structured logging:
- macOS: ~/Library/Logs/ai-tooling/deploy.log
- Windows: %LOCALAPPDATA%\ai-tooling\deploy.log

All paths in log output use native OS format.

### Documentation

- New `reference/tool-install-sources.md` — official docs and verified install commands for all managed tools
- Updated `shared/mcp/README.md` — two-tier MCP architecture docs
- Updated `CLAUDE.md` — new CLI usage examples
