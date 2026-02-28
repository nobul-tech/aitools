# aitools Release Notes

## Versioning

`major.minor.patch` -- not semver (no API contract), but follows the same spirit:

- **Major** (v0 → v1): structural changes to CLI commands, architecture, or project layout
- **Minor** (v0.14): new features, new managed tools, batches of improvements
- **Patch** (v0.14.1): isolated bug fixes with no new functionality

Multiple changes on the same day roll into one release. Bug fixes ship alongside features in the same minor if they land together.

---

## v0.23.1 -- PS1 First-Class Documentation (2026-02-28)

### Documentation

| # | Change |
|---|--------|
| 1 | **PS1 shown as full equal in all docs**: README.md, CLAUDE.md, scripts/README.md -- split mixed/bash-only blocks into labeled macOS/Linux + Windows (PowerShell) pairs. PS1 is never summarized, footnoted, or commented out. |

**Verified on:** Windows (extensive post-push checklist: 20 PASS, 1 SKIP).

---

## v0.23 -- PowerShell 7 Baseline (2026-02-28)

### New features

| # | Change |
|---|--------|
| 1 | **pwsh as managed tool on Windows**: Added to `tool-install-sources.md` (Windows: `supported`). Install via `winget install --id Microsoft.PowerShell --source winget`. |
| 2 | **PS 7 version guard in deploy scripts**: Generated deploy `.ps1` files (`setup-user-claude`, `setup-user-cursor`, `setup-user-hooks`) now error on PS 5.1 with install instructions. |
| 3 | **Bootstrap exception in `aitools-install.sh`**: On Windows, tries `pwsh` first; falls back to `powershell.exe` only to install pwsh via winget on fresh machines. |

### Improvements

| # | Change |
|---|--------|
| 4 | **All bash→PS dispatch migrated to `pwsh`**: `scripts/aitools`, `scripts/aitools-install.sh`, `scripts/check-pre-commit.sh`, `scripts/check-post-push.sh`, `scripts/build-deploy.sh` -- every `powershell.exe` dispatch call now uses `pwsh`. |
| 5 | **pwsh availability check**: `deploy_configs()` in `scripts/aitools` now validates pwsh is installed before dispatching, with a clear error message and install command. |

### Documentation

| # | Change |
|---|--------|
| 6 | **Rules updated for PS 7 baseline**: `.claude/rules/cross-platform.md` + `.cursor/rules/cross-platform.mdc` -- dispatch pattern uses `pwsh`, new "PS 7 baseline" section documents retained PS 5.1 workarounds as harmless, ASCII-only relaxed to preference, pipeline encoding downgraded to advisory. |
| 7 | **Checklist rules updated**: All 6 checklist rule files (pre-commit, pre-push, post-push in both `.claude/` and `.cursor/`) -- Windows invocation commands use `pwsh`. |
| 8 | **Shared content + project docs**: `shared/claude-shared.md`, `CLAUDE.md`, `reference/claude-code-windows-shell.md`, `.claude/commands/pre-update.md`, `scripts/README.md` -- all `powershell.exe` references updated to `pwsh`. |

**Verified on:** Windows (pwsh 7.5.4, all scripts syntax-validated via build-deploy.sh). macOS: not tested.

---

## v0.22 -- Error Handling Audit & Rust Support (2026-02-27)

### New features

| # | Change |
|---|--------|
| 1 | **Rust (cargo) as managed tool**: Full lifecycle -- setup scripts (`setup-rust.sh/.ps1`), installer integration, deploy scripts, shell aliases. Installs via `rustup` with non-preferred source cleanup. |
| 2 | **Error handling rules**: New `.claude/rules/error-handling.md` with project-level requirements. Full audit of all scripts for silent failures -- 5 violations fixed, 4 logic bugs caught, 1 missing error path added. |
| 3 | **File logging for check scripts**: All check scripts (`check-pre-commit`, `check-pre-push`, `check-post-push`) now write structured logs to `checks.log` and JSONL to `checks.jsonl` alongside existing `deploy.log`. Shared logging via `check-lib.sh/.ps1`. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 4 | MEDIUM | **winget upgrade match string**: `setup-pandoc.ps1` used wrong match string for `winget upgrade`, causing silent no-op on Windows. |
| 5 | MEDIUM | **5 error suppression violations**: Scripts using `-ErrorAction SilentlyContinue`, `2>/dev/null`, or `|| true` without result checks. Each now has an immediate null/empty guard. |
| 6 | MEDIUM | **4 logic bugs from audit**: False passes in check scripts from unguarded `Get-ChildItem`/`Get-Content`, `StepPass` missing `$Detail` parameter, and step counts feeding into summaries without error handling. |
| 7 | LOW | **Missing error path**: One code path had no error handling for template read failure. Added content validation before write. |

### Improvements

| # | Change |
|---|--------|
| 8 | **OS guards for check scripts**: `.sh` check scripts now reject Windows (Git Bash) with a clear message directing to the `.ps1` variant. |
| 9 | **`StepPass` detail support**: `StepPass` in `check-lib.ps1` now accepts and displays a `$Detail` parameter, matching `StepFail`/`StepWarn`/`StepSkip`. |

### Documentation

| # | Change |
|---|--------|
| 10 | **gh-issue-7490 comment reference**: Added `reference/gh-issue-7490-comment.md` documenting the upstream GitHub comment for Windows shell tracking. |

**Verified on:** Windows (PS 5.1, all scripts syntax-validated). macOS: not tested.

---

## v0.21 -- Interactive Clobber Protection (2026-02-27)

### New features

| # | Change |
|---|--------|
| 1 | **`--dry-run` for all setup scripts**: Every setup script (.sh/.ps1) and the `aitools` CLI now support `--dry-run`/`-DryRun`. Preview mode shows what would change without writing files. Env passthrough via `AITOOLS_DRY_RUN=1`. |
| 2 | **Clobber detection**: Config-writing scripts detect when a merge would lose non-managed fields. Warns in dry-run, refuses in normal mode (requires `--force` to proceed). |
| 3 | **Corrupt file handling**: Config-writing scripts now refuse to proceed on corrupt/unparseable JSON (instead of silently starting fresh). Use `--force` to override. |
| 4 | **`--dry-run` for `aitools install`**: Both `aitools-install.sh` and `.ps1` support `--dry-run` flag, passing through to all child scripts. |

### Improvements

| # | Change |
|---|--------|
| 5 | **PS1 scripts node-free**: `setup-user-cursor.ps1`, `setup-user-hooks.ps1`, and `setup-user-claude.ps1` no longer require Node.js. Converted from `node -e` to native PowerShell using `ConvertPSObjectToHashtable`. |
| 6 | **Deploy scripts updated**: `build-deploy.sh` regenerates deploy scripts with native PS merge and flag support. Deploy `setup-user-cursor.ps1` and `setup-user-hooks.ps1` are now node-free. |
| 7 | **New build emitters**: `ps1_hashtable_helper()`, `bash_flag_helpers()`, `ps1_param_block()`, `ps1_flag_helpers()` in `build-deploy.sh` for consistent flag/helper generation. |
| 8 | **Standing orders consolidated**: Grouped 6 standing order bullets under `### Standing Orders` heading with single enforcement note in `shared/claude-shared.md`. |
| 9 | **Platform dispatch in checklists**: Pre-commit, pre-push, and post-push rule blockquotes now show both macOS and Windows commands with "never run `.sh` on Windows" reminder. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 10 | HIGH | **Git stderr crash in PS1 check scripts**: `$ErrorActionPreference = "Stop"` caused CRLF warnings from `git diff` to terminate the script. Added `InvokeGit` wrapper to `check-lib.ps1` that temporarily lowers the preference around git calls. |
| 11 | LOW | **Reference link audit false positive**: Step 13 regex captured trailing backticks from markdown-formatted `@reference/` mentions (e.g., `` `@reference/` ``). Stripped trailing punctuation from matches. |

### Documentation

| # | Change |
|---|--------|
| 12 | **CC version registry**: Updated to 2.1.62. All CRITICAL upstream issues (Windows shell) still open. |

**Verified on:** Windows (PS 5.1 native, all scripts syntax-validated, extensive post-push 19 PASS / 0 FAIL). macOS: not tested.

---

## v0.20 -- PS 5.1 Compatibility Fixes and Config Safety (2026-02-27)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | CRITICAL | **`ConvertFrom-Json -AsHashtable` (PS 6+ only)**: Replaced with `ConvertPSObjectToHashtable` helper in `setup-user-mcp.ps1` and `setup-cursor-mcp.ps1`. On PS 5.1, the parameter error was caught as "invalid JSON", starting with empty `@{}` and silently clobbering all existing `settings.json`/`mcp.json` data. |
| 2 | CRITICAL | **`Join-Path` 3+ arguments (PS 6+ only)**: Chained to 2-arg calls in `setup-user-mcp.ps1` (4 instances) and `build-deploy.sh` heredoc (2 instances). Caused `A positional parameter cannot be found that accepts argument 'skills'` on PS 5.1. |
| 3 | HIGH | **`setup-user-hooks` missing from install flow**: Added to `aitools-install.ps1` and `.sh` deploy lists. Previously only deployed via `aitools` default command, not `aitools install`. |
| 4 | HIGH | **Empty `catch {}` in `setup-user-claude.sh`**: Replaced with ENOENT check to surface parse errors from malformed `config.json`. |

### Improvements

| # | Change |
|---|--------|
| 5 | **Config backup coverage**: Added 20-rotating backup (`Backup-File`/`backup_file`) to `setup-user-mcp` (settings.json) and `setup-user-cursor` (cli-config.json). Previously only `setup-user-claude` and `setup-cursor-mcp` had backups. |
| 6 | **User repo auto-pull**: `aitools` default command and `aitools gitpull` now pull the user repo (quiet, non-blocking) before deploying configs. Prevents stale profile data when switching machines. |
| 7 | **Improved catch block messages**: All PS1 config merge catch blocks now report the actual exception instead of generic "invalid JSON" message. |

**Verified on:** Windows (PS 5.1 native, all setup scripts executed, merge preservation confirmed). macOS: not tested.

---

## v0.19 -- Checklist Verification Scripts (2026-02-26)

### New features

| # | Change |
|---|--------|
| 1 | **Automated checklist scripts**: `check-pre-commit.sh/.ps1` (12 steps, `--fix` mode), `check-pre-push.sh/.ps1` (10 steps, read-only), `check-post-push.sh/.ps1` (5 always + 15 extensive steps, `--extensive` flag). Shared library `check-lib.sh/.ps1` provides colored output, counters, and summary. Replaces ad-hoc bash commands with single-command checklists. |
| 2 | **pwsh as managed tool**: Added to `tool-install-sources.md` (macOS: supported, Windows: n/a). PS1 validation in check scripts and `build-deploy.sh` now uses pwsh on macOS. Rule files updated to treat pwsh as required. |
| 3 | **macOS PS1 validation in build pipeline**: `build-deploy.sh` now validates all generated `.ps1` files via `pwsh` on macOS (previously skipped). |

### Improvements

| # | Change |
|---|--------|
| 4 | **Invocation lifecycle field**: Added 5th required field to tool entries in `tool-install-sources.md`. Documents direct CLI command and anti-patterns per tool. |
| 5 | **Dual deployment path rules**: New `.claude/rules/deploy-paths.md` and `.cursor/rules/deploy-paths.mdc` codify the dev/repo vs MDM path equivalence requirement. |
| 6 | **3 coaching standing orders**: Checklist scripts (not ad-hoc commands), scratch files for complex bash, Perl for string manipulation. |
| 7 | **Script reference notes in rules**: Pre-commit, pre-push, and post-push rule files now reference the check scripts at the top. |

### Files created

| File | Purpose |
|------|---------|
| `scripts/check-lib.sh` | Shared library: colors, counters, step formatters, config reader |
| `scripts/check-lib.ps1` | PS1 equivalent |
| `scripts/check-pre-commit.sh` | 12 pre-commit steps with `--fix` mode |
| `scripts/check-pre-commit.ps1` | PS1 equivalent |
| `scripts/check-pre-push.sh` | 10 pre-push steps, read-only |
| `scripts/check-pre-push.ps1` | PS1 equivalent |
| `scripts/check-post-push.sh` | 5 always + 15 extensive steps |
| `scripts/check-post-push.ps1` | PS1 equivalent |
| `.claude/rules/deploy-paths.md` | Dual deployment path rules |
| `.cursor/rules/deploy-paths.mdc` | Cursor equivalent |

**Verified on:** macOS (bash -n, pwsh ParseFile, all check scripts executed). Windows: PS1 validated via pwsh on macOS (not tested natively).

---

## v0.18 -- Release Notes Gate for Version Tagging (2026-02-26)

### New features

| # | Change |
|---|--------|
| 1 | **Release notes enforcement in gitpull**: `aitools gitpull` now checks RELEASE_NOTES.md for a matching `## vX.Y` heading before creating a version tag. If no entry exists, tagging is skipped with a yellow warning and instructions. Prevents tags without release notes (as happened with v0.17.0). Both bash and PowerShell entry points enforce the gate. |

### Improvements

| # | Change |
|---|--------|
| 2 | **Pre-update command warns about missing release notes**: `/pre-update` now flags when remote commits would trigger a tag but RELEASE_NOTES.md has no matching entry. Options table notes the requirement. |
| 3 | **Pre-commit and post-push rules updated**: Step 9 (release notes) strengthened to reference the automated enforcement. Post-push version tag section notes that gitpull now handles this automatically. Mirrored in `.cursor/rules/`. |

**Verified on:** macOS (bash -n, deploy syntax OK). Windows: PS1 not validated locally (tested: macOS).

---

## v0.17.1 -- Deploy Hooks to ~/.claude/hooks/ (2026-02-26)

### New features

| # | Change |
|---|--------|
| 1 | **deploy/ variant for setup-user-hooks**: `build-deploy.sh` now generates `deploy/setup-user-hooks.sh` and `.ps1` with embedded hook script and claude preferences. MDM-only machines (no repo) now get session archive hooks and preferences. Build produces 14 scripts (was 12). |
| 2 | **Hook deployed to ~/.claude/hooks/**: Setup scripts copy `shared/hooks/session-archive.sh` to `~/.claude/hooks/session-archive.sh` and point the `settings.json` hook command to the deployed copy. Follows the same deployed-copy pattern as skills and CLAUDE.md. |

### Documentation

| # | Change |
|---|--------|
| 3 | **user-repo.md updated**: Archiving Mechanism section now documents the deployed-copy pattern for hooks. |

### Files created

| File | Purpose |
|------|---------|
| `deploy/setup-user-hooks.sh` | Self-contained hook + preferences deploy (macOS/Linux) |
| `deploy/setup-user-hooks.ps1` | Self-contained hook + preferences deploy (Windows) |

**Verified on:** macOS (bash -n, both variants run, identical settings.json output). Windows: PS1 syntax not validated (pwsh not available), functional test deferred (tested: macOS).

---

## v0.17.0 -- CC Version Tracking Registry (2026-02-24)

### New features

| # | Change |
|---|--------|
| 1 | **Claude Code version dependency registry**: `reference/claude-code-version-deps.md` tracks version-dependent workarounds with severity tiers (CRITICAL/HIGH/MEDIUM/LOW), baseline versions, and upstream issue links. Post-push checklist #20 triggers review on CC upgrades. |

### Documentation

| # | Change |
|---|--------|
| 2 | **user-repo.md expanded**: Added Config Schema section (v2), session archive hook contract, template resolution docs. |

**Verified on:** macOS. Documentation only -- no scripts modified.

---

## v0.16.2 -- Config.json Version Bump to v2 (2026-02-22)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | Low | **config.json stuck at v1**: `aitools-install.sh/.ps1` wrote `"version": 1` even after `userRepoPath` and `machineAlias` fields were added in v0.15. Bumped to `"version": 2` to match actual schema. |

### Documentation

| # | Change |
|---|--------|
| 2 | **Config schema documented**: `reference/user-repo.md` now has a full Config Schema section (v1 and v2) with field descriptions and migration notes. Follows the same pattern as the Profile Schema section. |

**Verified on:** macOS (bash -n, pwsh parse). Windows: PS1 syntax validated via pwsh, functional test deferred (tested: macOS).

---

## v0.16.1 -- User-Scope CLAUDE.md Migration (2026-02-22)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | Medium | **Placeholder bug**: `scripts/setup-user-claude.sh/.ps1` read `shared/claude-shared.md` raw without interpolating `{{PLACEHOLDER}}` tokens. `~/.claude/CLAUDE.md` contained literal `{{PROFILE_NAME}}` etc. Fixed by adding profile.json interpolation (same pattern as `build-deploy.sh`). |

### New features

| # | Change |
|---|--------|
| 2 | **User repo CLAUDE.md template**: Personal preferences now live in `<userRepoPath>/claude/CLAUDE.md` (dotfile repo), synced across machines via git. Setup scripts read from user repo first, fall back to `shared/claude-shared.md`. |
| 3 | **Scaffold in `user init`**: `aitools user init` copies `shared/claude-shared.md` to `<userRepoPath>/claude/CLAUDE.md` if missing, keeping placeholders for per-machine interpolation at deploy time. |

### Files created

| File | Purpose |
|------|---------|
| `<userRepoPath>/claude/CLAUDE.md` | Personal CLAUDE.md template with `{{PLACEHOLDER}}` tokens |

**Verified on:** macOS (bash -n, pwsh parse, setup-user-claude.sh live run with resolved placeholders). Windows: PS1 syntax validated via pwsh, functional test deferred (tested: macOS).

---

## v0.16 -- Profile Validation & v1 Migration (2026-02-22)

### New features

| # | Change |
|---|--------|
| 1 | **Profile validation**: `scripts/profile-check.js` -- standalone Node.js script that reads `config.json`, locates `profile.json`, validates v2 fields (identity, profiles, machine match), and outputs structured JSON. Detects v1 profiles needing migration, missing fields, corrupt JSON, and alias mismatches. |
| 2 | **Profile check in sync/install flows**: `aitools` (no-args sync) and `aitools install` now run profile validation after deploy. Healthy v2 profiles produce no output. Issues show yellow warnings. v1 profiles prompt for interactive migration. Non-interactive terminals fall back to warn-only. |
| 3 | **v1-to-v2 interactive migration**: When a v1 profile is detected, the user is prompted for a machine alias (the only field not in v1). Migration preserves non-v1 sections (e.g., `cursor` preferences), handles multiple v1 machines, commits and pushes the user repo. Available in `aitools` sync, `aitools install`, and `aitools user init`. |
| 4 | **v1 detection in `user init`**: Paths 1 (repo exists) and 2 (GitHub clone) now detect v1 profiles and auto-trigger migration before proceeding with the existing v2 machine-addition flow. |

### Improvements

| # | Change |
|---|--------|
| 5 | **Standing order for dedicated tools**: Added to `shared/claude-shared.md` -- Use Read/Edit/Write/Grep/Glob for all file operations, never Bash equivalents. Elevated from coaching to standing order. |

### Files created

| File | Purpose |
|------|---------|
| `scripts/profile-check.js` | Standalone profile validation script (read-only, JSON output) |

**Verified on:** macOS (bash -n, pwsh parse, profile-check.js with live v2 profile, aitools sync smoke test). Windows: PS1 syntax validated via pwsh, functional test deferred (tested: macOS).

---

## v0.15.2 -- Post-Write Config Validation (2026-02-21)

### New features

| # | Change |
|---|--------|
| 1 | **Post-write validation for all config writers**: Every script that writes a config file now validates output immediately after writing. JSON configs are checked for valid parse, required keys, and double-slash paths. CLAUDE.md is checked for non-empty content and required sections. Catches malformed output at write time instead of by manual inspection. |
| 2 | **`validate_json_config` (bash) / `ValidateJsonConfig` (PS1)**: Reusable validation functions added to `aitools-install.sh/.ps1`. Uses `python3` (primary) or `node` (fallback) for JSON parsing, plus `grep` for required keys and a Python walker for double-slash path detection. |

### Improvements

| # | Change |
|---|--------|
| 3 | **Config write safety rule updated**: `.claude/rules/config-file-safety.md` and `.cursor/rules/config-file-safety.mdc` now document post-write validation as a requirement alongside read-then-merge, with gold standard references. |

### Files modified (17 write sites across 14 scripts)

| Script | Config validated | Method |
|--------|----------------|--------|
| `scripts/aitools-install.sh` | `config.json` | `validate_json_config` function |
| `scripts/aitools-install.ps1` | `config.json` | `ValidateJsonConfig` function |
| `scripts/setup-user-mcp.sh` | `settings.json` | Inline Node.js |
| `scripts/setup-user-mcp.ps1` | `settings.json` | Inline PS1 try/catch |
| `scripts/setup-user-hooks.sh` | `settings.json` | Inline Node.js |
| `scripts/setup-user-hooks.ps1` | `settings.json` | Inline Node.js |
| `scripts/setup-cursor-mcp.sh` | `mcp.json` | Inline Node.js |
| `scripts/setup-cursor-mcp.ps1` | `mcp.json` | Inline PS1 try/catch |
| `scripts/setup-user-cursor.sh` | `cli-config.json` | Inline Node.js |
| `scripts/setup-user-cursor.ps1` | `cli-config.json` | Inline Node.js |
| `scripts/setup-user-claude.sh` | `CLAUDE.md` | Inline bash checks |
| `scripts/setup-user-claude.ps1` | `CLAUDE.md` | Inline PS1 checks |
| `scripts/aitools` | `config.json`, `settings.local.json` | Inline Node.js |
| `scripts/aitools.ps1` | `config.json`, `settings.local.json` | Inline Node.js |
| `scripts/build-deploy.sh` | Generated deploy scripts | Embedded validation in templates |

**Verified on:** macOS (bash -n on all scripts, deploy/ rebuilt and verified)

---

## v0.15.1 -- Config Write Safety (2026-02-21)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | Medium | `setup-cursor-mcp.sh/.ps1` now merges managed servers into `~/.cursor/mcp.json` instead of overwriting. User-added MCP servers are preserved across re-runs. |
| 2 | Low | Empty `catch {}` blocks in inline Node.js across all setup scripts and CLI now warn on corrupt JSON instead of silently starting with empty config. ENOENT (file missing) still starts fresh silently. |
| 5 | Medium | `aitools user init` (Path 1: repo already exists) now auto-detects `machineAlias` from `profile.json` by hostname match instead of leaving it empty. Hostname comparison uses short name (strips DNS suffix) to handle `Joses-MBP` vs `Joses-MBP.lax`. Same fix applied to `build-deploy.sh` profile lookup fallback. |

### New features

| # | Change |
|---|--------|
| 3 | **Config write safety rule** (`.claude/rules/config-file-safety.md`): codifies read-then-merge as the default for JSON config writes, documents managed vs preserved fields pattern, and flags empty `catch {}` as an anti-pattern. |
| 4 | **Pre-commit step 8** (config merge safety): verifies setup scripts use read-then-merge before committing. **Post-push step 19** (config merge audit): flags blind overwrites in extensive audits. |

**Verified on:** macOS

---

## v0.15 -- Standalone Chrome DevTools Skills (2026-02-21)

### New features

| # | Change |
|---|--------|
| 1 | **Standalone Chrome DevTools skills**: Vendored `chrome-devtools` and `a11y-debugging` SKILL.md files from upstream repo into `shared/skills/`. Deployed to `~/.claude/skills/` by `setup-user-mcp`. Replaces the Claude Code plugin (which bundled MCP config without `--isolated`). |
| 2 | **Self-contained skill deployment**: `build-deploy.sh` embeds skill content inline in deploy scripts via heredocs. Deploy scripts need no sibling files. |

### Improvements

| # | Change |
|---|--------|
| 3 | **Build script CRLF handling**: `build-deploy.sh` now strips CR before sed pattern matching on PS1 source files, fixing broken template extraction on macOS. |

### Documentation

| # | Change |
|---|--------|
| 4 | Updated `reference/tool-install-sources.md`: replaced plugin install section with standalone skills, added source URLs. |
| 5 | Updated `reference/cursor-practices.md`: skills section now reflects deployed Chrome DevTools skills. |
| 6 | Updated `shared/mcp/README.md`: plugin section replaced with skills section. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 7 | Medium | **Installer clobbers `userRepoPath`/`machineAlias`**: `aitools install` step 5 overwrote `config.json` with only 4 managed keys, dropping `userRepoPath` and `machineAlias` set by `aitools user init`. This caused downstream deploys (e.g., `setup-user-cursor`) to lose profile-driven preferences like `vimMode`. Both `.sh` and `.ps1` installers now preserve these keys. |

### Files created

| File | Purpose |
|------|---------|
| `shared/skills/chrome-devtools/SKILL.md` | Vendored browser automation & debugging skill |
| `shared/skills/a11y-debugging/SKILL.md` | Vendored accessibility auditing skill |

**Verified on:** macOS (bash -n, build-deploy.sh, setup-user-mcp.sh run, skills deployed to ~/.claude/skills/). Windows: deferred (tested: macOS).

---

## v0.14 -- Version Scheme Reset, Git Checklist Improvements (2026-02-21)

### Improvements

| # | Change |
|---|--------|
| 1 | **Version scheme reset**: Replaced date-based tags (`v2026-02-17.3.0`) with clean incremental versions (`v0.14.0`, `v0.15.0`). Continuity from v3.13 -- next `gitpull` creates v0.15.0. |
| 2 | **Pre-commit: PS1 validation on macOS**: When `pwsh` is installed, PS1 scripts are now validated on macOS too, not just Windows. |
| 3 | **Pre-commit: conditional platform note**: Platform note (`tested: macOS`) now only required when `.sh` or `.ps1` files are in the commit. Pure docs/markdown commits can omit it. |
| 4 | **Pre-commit: release notes gate**: New step 8 requires a `RELEASE_NOTES.md` entry when committing features, bug fixes, or behavioral changes. |
| 5 | **Pre-commit: deploy drift check**: New step 9 verifies no unstaged deploy/ changes remain after build freshness step. |
| 7 | **Pre-push: credential scan**: Moved credential/secret scan from post-push Extensive #14 to pre-push #3. Catches secrets before they leave the machine. |
| 8 | **Pre-push: WIP commit check**: New step #4 rejects `WIP`, `fixup!`, `squash!`, and `TODO` prefix commits before push. |
| 9 | **Pre-push: commit count check**: New step #8 pauses for review when pushing >5 commits. |
| 10 | **Pre-push: simplified cross-references**: Steps 5 (release notes) and 7 (deploy/) now reference pre-commit steps instead of re-describing the check. |
| 11 | **Post-push: read-only MCP check**: Always tier #3 changed from running setup scripts to grep-based verification. Full setup scripts moved to Extensive tier #14. |
| 12 | **Post-push: version consistency**: Always tier #4 now also verifies `aitools --version` matches the latest git tag. |
| 13 | **Post-push: pwsh validation on macOS**: Extensive #5 now notes that PS1 files can be validated on macOS when `pwsh` is installed. |
| 14 | **Session archive warnings**: `aitools` (no-args sync) now warns when the session archive hook is installed but `userRepoPath` is not configured. Previously only checked if the hook was installed. Same warning in `aitools.ps1`. |
| 15 | **Install hint for session archive**: `aitools install` now prints a hint about `aitools user init` when `userRepoPath` is missing. Same hint in `aitools-install.ps1`. |
| 16 | **Post-push Always #5**: New "Session archive readiness" check promoted to Always tier. Detects inactive session archive without running the full Extensive audit. |

### Documentation

| # | Change |
|---|--------|
| 6 | Updated version examples in `RELEASE_NOTES.md`, `.claude/rules/documentation-standards.md`, and `.cursor/rules/documentation-standards.mdc` to reflect new `v0.x` scheme. |

**Verified on:** macOS (bash -n on both scripts, build-deploy.sh rebuilt). Windows: deferred.

---

## v3.13 -- Plugin Docs, Overrides Framework, Web Source Rule (2026-02-21)

### New features

| # | Change |
|---|--------|
| 1 | **Overrides framework**: New section in `reference/tool-install-sources.md` documenting intentional deviations from upstream defaults (e.g., `--isolated` flag for Chrome DevTools MCP). Prevents audit false positives. |
| 2 | **Chrome DevTools MCP plugin docs**: Documented `/plugin install chrome-devtools-mcp` as optional install method that adds structured skills (`chrome-devtools`, `a11y-debugging`). Updated lifecycle Post-Install Config field. |
| 3 | **Web source reading rule**: New `.claude/rules/web-sources.md` and `.cursor/rules/web-sources.mdc` codifying preference for Chrome DevTools MCP skill over WebFetch when reading official docs for source-of-truth files. |
| 4 | **Profile v2 overrides schema**: Extended `reference/user-repo.md` with `overrides` key for machine-readable tracking of intentional config deviations. Informational only -- CLI integration deferred. |

### Improvements

| # | Change |
|---|--------|
| 5 | **User-level MCP skill preference**: Added Chrome DevTools MCP skill preference bullet to `shared/claude-shared.md`, propagated to deploy scripts. |
| 6 | **MCP README plugin note**: Added plugin install note to `shared/mcp/README.md` with `--isolated` precedence explanation. |

### Files created

| File | Purpose |
|------|---------|
| `.claude/rules/web-sources.md` | Web source reading rule (Claude Code) |
| `.cursor/rules/web-sources.mdc` | Web source reading rule (Cursor) |

**Verified on:** macOS (bash -n on all deploy scripts, build-deploy.sh rebuilt). Windows: deferred.

---

## v3.12.1 -- clip2md Plain Text Support (2026-02-20)

### New features

| # | Change |
|---|--------|
| 1 | **clip2md plain text fallback**: When no HTML is on the clipboard, `clip2md` now falls back to plain text. Plain text skips pandoc entirely -- saved as-is. Useful for terminal output, code snippets, and plain notes. Status messages show source type: `(HTML, ~XXX words)` or `(text, ~XXX words)`. |

### Improvements

| # | Change |
|---|--------|
| 2 | **Pandoc check moved inside HTML branch**: `clip2md` no longer requires pandoc when saving plain text. Pandoc is only checked when HTML content is detected. |

**Verified on:** Windows (bash -n + ParseFile validated). macOS: deferred.

---

## v3.12 -- Bug Fixes, v2 Profiles, Template Interpolation (2026-02-20)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | **git pull failure misdiagnosis** ([#1](https://github.com/nobul-jose/ai-tooling/issues/1)): Any non-zero `git pull` exit was reported as "Could not reach remote". Real cause (e.g., dirty `deploy/` files) was hidden. Fix: reset generated `deploy/` before pull; distinguish network errors from other failures in both scripts. |
| 2 | BUG | **user init existing repo failure** ([#2](https://github.com/nobul-jose/ai-tooling/issues/2)): `gh repo create` failed silently when repo already existed on GitHub. Local repo had no remote, no push. Fix: rewritten `user init` with 3-path flow (local exists / GitHub exists / fresh). |

### New features

| # | Change |
|---|--------|
| 3 | **v2 profile creation in user init**: Fresh repos now create v2 `profile.json` with `version`, `identity`, and per-machine `profiles` sections. Includes machine alias prompt. |
| 4 | **Multi-machine user init**: When GitHub repo exists but no local clone, `user init` clones it, prompts for machine alias, adds a new profile entry, commits, and pushes. |
| 5 | **Phase B template interpolation**: `shared/claude-shared.md` uses `{{PLACEHOLDER}}` tokens for identity fields. `build-deploy.sh` reads `profile.json` via config and interpolates at build time. Fallback to hardcoded defaults if profile unavailable. |

### Improvements

| # | Change |
|---|--------|
| 6 | **Windows tool discovery rule**: Added to `shared/claude-shared.md` -- documents that `which`/`command -v` in Git Bash misses Windows PATH tools; use `powershell.exe Get-Command` instead. |
| 7 | **GitHub issue tracking convention**: Added to `shared/claude-shared.md` -- when bugs are referenced, check the repo's GitHub issues for full context. |
| 8 | **machineAlias in config**: `user init` now writes `machineAlias` to `~/.aitools/config.json` alongside `userRepoPath`. Used by build-deploy.sh to select the correct profile. |

**Verified on:** Windows (bash -n + ParseFile validated on all scripts, deploy/ rebuilt and verified). macOS: scripts updated but not validated on this machine.

---

## v3.11 -- Cleanup & Deprecations (2026-02-19)

### Deprecated

| # | Change |
|---|--------|
| 1 | **Cursor User Rules clipboard workflow removed**: `setup-user-cursor` scripts no longer copy `user-rules.md` to clipboard or open the file. Cursor project rules (`.cursor/rules/*.mdc`) auto-load and cover the same ground. The source file `shared/cursor-rules/user-rules.md` is retained as reference. |

### Removed

| # | Change |
|---|--------|
| 2 | **`docs/` folder removed**: Vendor-specific PDFs and markdown conversions (4.7 MB, mostly StorNext/Quantum). Copies exist elsewhere. |
| 3 | **`conversionutils/` folder removed**: Legacy PDF-to-markdown utilities superseded by Marker. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 4 | BUG | `setup-user-cursor.sh/.ps1` now have exit footers that check the error counter and exit with code 1 on failure. Previously, scripts exited 0 regardless of errors. |

### Documentation

| # | Change |
|---|--------|
| 5 | `reference/cursor-practices.md`: User Rules section updated to note deprecated workflow. |
| 6 | `CLAUDE.md`: Removed `docs/` and `conversionutils/` from project structure, removed legacy PDF conversion usage examples, simplified Marker key decision. |
| 7 | `README.md`: Removed `docs/` and `conversionutils/` directory rows, removed PDF conversion section. |
| 8 | `reference/session-showcase.md`: Removed `docs/` from repo structure, updated Cursor setup description. |

**Verified on:** macOS (bash -n validated on all .sh scripts, deploy/ rebuilt). Windows: PS1 scripts updated but not validated on this machine.

---

## v3.10 -- Audit & Governance Rules (2026-02-19)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `setup-vercelcli.sh/.ps1` and `setup-pandoc.sh/.ps1` now track errors via `ERRORS`/`$errors` counter and exit with code 1 on failure. Previously, `log_error()` only logged -- scripts silently exited 0 even when errors occurred. |

### New rules

| # | Change |
|---|--------|
| 2 | **Script standards** (`.claude/rules/script-standards.md` + `.cursor/rules/script-standards.mdc`): Codifies block order, error tracking requirement, logging helpers, exit footer, and gold standard references for all setup scripts. |
| 3 | **Documentation standards** (`.claude/rules/documentation-standards.md` + `.cursor/rules/documentation-standards.mdc`): Codifies RELEASE_NOTES format, version numbering, ROADMAP format, reference doc threshold, and when to create plans. |

### Improvements

| # | Change |
|---|--------|
| 4 | **Pre-commit checklist enhanced** (items 6-7): Added executable bit check (`git ls-files -s '*.sh' | grep -v '^100755'`) and install command consistency check (verify against `tool-install-sources.md`). |
| 5 | **Tool lifecycle rule enhanced**: Added lifecycle field completeness check (all 4 fields required) and Under Evaluation guard (evaluating-only tools must not have setup scripts, installer entries, aliases, or build pipeline entries). |

### Documentation

| # | Change |
|---|--------|
| 6 | `reference/cursor-practices.md`: Rule Correspondence table updated with 2 new rule pairs. |
| 7 | `CLAUDE.md`: Gold standard reference updated from setup-vercelcli to setup-user-mcp. Documentation standards key decision added. |

### Files created

| File | Purpose |
|------|---------|
| `.claude/rules/script-standards.md` | Script standards rule (Claude Code) |
| `.cursor/rules/script-standards.mdc` | Script standards rule (Cursor, condensed) |
| `.claude/rules/documentation-standards.md` | Documentation standards rule (Claude Code) |
| `.cursor/rules/documentation-standards.mdc` | Documentation standards rule (Cursor, condensed) |

**Verified on:** macOS (bash -n validated on all .sh scripts, deploy/ rebuilt). Windows: PS1 scripts updated but not validated on this machine.

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
| 3 | **clip2md logging**: All operations log to `clip2md.log` (Windows: `%LOCALAPPDATA%\aitools\`, macOS: `~/Library/Logs/aitools/`). Events: saves, errors, temp file lifecycle, overwrite decisions. |

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
| 2 | BUG | Generated bash deploy scripts log to `~/Library/Logs/aitools/deploy.log` (matching source scripts and `aitools` CLI), not `~/Library/Logs/ai-tooling-deploy.log`. |
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
- macOS: ~/Library/Logs/aitools/deploy.log
- Windows: %LOCALAPPDATA%\aitools\deploy.log

All paths in log output use native OS format.

### Documentation

- New `reference/tool-install-sources.md` — official docs and verified install commands for all managed tools
- Updated `shared/mcp/README.md` — two-tier MCP architecture docs
- Updated `CLAUDE.md` — new CLI usage examples
