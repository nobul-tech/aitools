---
description: Prepare for aitools update -- capture state, clear logs, load failure remediation context
allowed-tools: [Read, Bash, Glob, Grep, Write, Edit]
---

# Pre-Update Preparation

You are preparing for an aitools update. Follow these steps in order.

## 1. Capture pre-update state

Run these commands and present the results as a summary table:

```
aitools --version
git describe --tags --always
git status --short
```

Then read the last 30 lines of the deploy log (before clearing it):

- macOS: `~/Library/Logs/aitools/deploy.log`
- Windows: `$LOCALAPPDATA/aitools/deploy.log`

If the log file doesn't exist, note that and move on.

## 2. Fetch and diff remote vs local

Run `git fetch origin main` first, then run all of these and analyze the output:

```
git log --oneline HEAD..origin/main
git diff HEAD..origin/main --stat
git diff HEAD..origin/main -- RELEASE_NOTES.md
git diff HEAD..origin/main -- scripts/ shared/
git diff HEAD..origin/main -- .claude/rules/ .cursor/rules/
git diff HEAD..origin/main -- CLAUDE.md
```

Based on the diffs, provide a summary covering:

- **What's coming**: new features, bug fixes, config changes
- **Protected file changes**: flag any changes to source-of-truth files
- **Cross-platform impact**: note changes to setup scripts or OS-specific logic
- **Deploy behavior changes**: which deploy scripts will behave differently
- **Potential failure points**: new scripts, changed build logic, new dependencies

**Release notes gate**: If remote has commits beyond the latest tag, check whether
RELEASE_NOTES.md on remote contains a version entry that would match the next tag
(minor or patch). If not, warn: "`aitools gitpull` will skip tagging because
RELEASE_NOTES.md has no entry for vX.Y.Z. Add release notes on the source machine
before pulling."

If HEAD is already up to date with origin/main, say so and skip the diff analysis.

## 3. Clear deploy log

Truncate the deploy log so post-update output is isolated.
Use `truncate -s 0` (not shell `>` redirect, which can hang in Claude Code):

- macOS: `truncate -s 0 ~/Library/Logs/aitools/deploy.log`
- Windows: `pwsh -Command 'Set-Content -Path "$env:LOCALAPPDATA\aitools\deploy.log" -Value $null'`

Detect the current platform and use the correct command.

## 4. Wait for user instruction

Present three options and ask which command to run:

| Command | What it does |
|---------|--------------|
| `aitools` | Quiet pull + rebuild + deploy configs |
| `aitools gitpull` | Loud pull + rebuild + deploy + changelog + minor version tag **(requires RELEASE_NOTES.md entry)** |
| `aitools gitpull --patch` | Same as gitpull but bumps patch (v0.14.0 -> v0.14.1) **(requires RELEASE_NOTES.md entry)** |
| `aitools install` | Quiet pull + rebuild + full installer (tools + configs) |

**Recommendation**: If pre-update state (step 1) or prior `check-post-push` results
show missing build prerequisites (NASM, CMake), recommend `aitools install` -- it runs
the full installer including setup-rust which invokes the build prerequisite framework.

Do NOT run any of these yet. Wait for the user to choose.

## 5. Post-update verification

After the user runs the update command (or asks you to run it), verify:

1. **Exit code**: was it 0?
2. **Deploy log**: read the full deploy log and check for errors/warnings
3. **Version comparison**: run `aitools --version` and `git describe --tags --always` again -- compare with pre-update values
4. **Deploy script syntax**: run `bash -n deploy/*.sh` to catch build corruption

Report results as a before/after comparison.

## 6. Failure remediation protocol

If anything fails at any point:

1. **Stop.** Do not retry the same command blindly.
2. **Capture evidence**: save the error output, read the deploy log, run `git status`
3. **Investigate root cause**: check the log signatures below, read the relevant script
4. **Document the bug**: note severity, affected platform, reproduction steps
5. **Fix it** before doing anything else -- the fix takes priority over the update

### Known failure modes

| Symptom | Likely cause | Investigation |
|---------|-------------|---------------|
| `build-deploy.sh` syntax error | Bad edit to scripts/ or shared/ | `bash -n scripts/build-deploy.sh`, check recent diffs |
| deploy/*.sh syntax error post-build | Build script concatenation bug | Compare `scripts/` source with `deploy/` output |
| Version mismatch (installed != repo) | Deploy didn't run or failed silently | Read deploy log, check `aitools --version` source |
| `command not found: aitools` | Shell alias not loaded | Check `~/.zshrc` or PS profile for alias, run `source` |
| OS guard rejection | Wrong platform script called | Check `uname -s` output, verify dispatch logic |
| Permission denied on .sh | Missing executable bit | `git ls-files -s '*.sh' \| grep -v '^100755'`, fix with `git update-index --chmod=+x` |
| Stale deploy/ after update | `build-deploy.sh` wasn't run or output wasn't committed | `bash scripts/build-deploy.sh && git diff deploy/` |
| Network error on pull | Git remote unreachable | Check connectivity, try `git fetch` manually |
| Hook errors during pull | Pre/post hooks failing | Read hook output, check `.claude/settings.json` |
| `cargo install` fails: NASM/CMake not found | Build prerequisite missing | Run `aitools install` (setup-rust checks prereqs). Check `check-post-push` step 27 |
