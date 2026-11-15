# M3b-Finish-V results, v1.0

Local verification of branch `fix/console-input-mode` at HEAD `7fecf4f122e8ed5793cbf38f55898e3f76ef08f5` (origin/main `a98208e` plus 4 commits: 59680ed, 5a1d62b, 25ad41b, 7fecf4f), worktree `C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input`. Windows 11, Git Bash 5.3.15(2), pwsh 7.6.10, Python 3.14.6, pywinpty 3.1.2. Run 2026-11-14 02:28Z to 02:51Z. No tracked file was edited.

Scratch root (S): `C:\Users\jdpal\repos\aitools\.claude\worktrees\console-input\.scratch\session-M3b-V\`

## Summary

- 38 of 38 tracked suites exited 0, with 0 failed cases. 2,899 cases passed. Summary lines report 57 skips, all for platform reasons (no symlinks, chmod or FIFOs under Windows, stdin is not a console). `setup-user-shell.sh` skips every case on Windows by design and is not in the Windows CI job.
- The known flake (`workflow-delegation-guard`, 476 KB prompt) did not fail. It passed on the first run with three advisory timing WARNs, so there was no rerun.
- The isolated build-deploy exited 0 and generated 50 scripts. `bash -n` passed on all 24 `.sh` files, and the pwsh parser passed on all 25 `.ps1` files. Each of the 23 deploy `.ps1` files that inline aitools-lib.ps1 contains `AitConsoleInput` and `Write-AiLog`. Every `Start-Job` match is the comment "Not Start-Job: ...", not code.
- Check scripts (native pwsh, isolated HOME): pre-commit has 1 FAIL (step 20, which was already failing before this branch). Pre-push has 0 FAIL, and step 7 PASS. Post-push has 2 FAIL: step 1 is expected on a branch, and step 3 comes from my isolated HOME, not the branch.
- Neither tree changed. The worktree's tracked files are untouched (only gitignored `scripts/__pycache__/*.pyc` was added). The real dotprofile shows ` M profile.json` before and after, an edit that was already there. Its `deploy/` was last written at 16:04 PT, before this run.

## Suite table

Every command ran from the worktree root, the way check.yml's Windows job runs it, with stdin `/dev/null` and an outer isolated HOME, USERPROFILE and AITOOLS_LOG_DIR under S (`home/` with `core.autocrlf=false`, which mirrors CI). Driver: S`run-suites.sh`. Results: S`suite-results.tsv`. Logs: S`suite-logs/<name>.log`. Digest: S`summary-output.log`.

| # | Suite | Command | Exit | Summary line (verbatim) | Notes |
|---|---|---|---|---|---|
| 1 | os-guards | `bash tests/os-guards/test-os-guards.sh` | 0 | `test-os-guards: 33 passed, 0 failed, 0 skipped (windows, bash 5.3.15(2)-release)` | |
| 2 | delegation-score | `python tests/harness-db/test-delegation-score.py` | 0 | `Ran 14 tests in 0.060s` / `OK` | |
| 3 | ait-harvest | `python tests/harvest/test-ait-harvest.py` | 0 | `Ran 14 tests in 1.398s` / `OK` | |
| 4 | logging (sh) | `bash tests/logging/test-logging.sh` | 0 | `---- 24 passed, 0 failed` | |
| 5 | logging (ps1) | `pwsh -NoProfile -File tests/logging/test-logging.ps1` | 0 | `---- 20 passed, 0 failed, 0 skipped` | |
| 6 | console-mode-guard (ps1) | `pwsh -NoProfile -File tests/aitools-entry/test-console-mode-guard.ps1` | 0 | `---- 76 passed, 0 failed, 7 skipped` | 7 SKIP: console cases (stdin or stdout is not a console). This is the branch's own suite. |
| 7 | managed-files (sh) | `bash tests/managed-files/test-managed-files.sh` | 0 | `79 passed, 0 failed, 3 skipped` | pty cases ran (pywinpty). SKIP: diff over 64 KB (ConPTY throughput), claude.md adopt round trip (sh, not on Windows), read-only cases |
| 8 | managed-files (ps1) | `pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1` | 0 | `56 passed, 0 failed, 0 skipped` | |
| 9 | adopt-push (sh) | `bash tests/managed-files/test-adopt-push.sh` | 0 | `28 passed, 0 failed, 0 skipped` | |
| 10 | adopt-push (ps1) | `pwsh -NoProfile -File tests/managed-files/test-adopt-push.ps1` | 0 | `22 passed, 0 failed, 0 skipped` | |
| 11 | menu-choice (sh) | `bash tests/menus/test-menu-choice.sh` | 0 | `61 passed, 0 failed, 0 skipped` | pty via ConPTY |
| 12 | menu-choice (ps1) | `pwsh -NoProfile -File tests/menus/test-menu-choice.ps1` | 0 | `63 passed, 0 failed, 0 skipped` | |
| 13 | setup-user-shell (ps1) | `pwsh -NoProfile -File tests/setup-user-shell/test-setup-user-shell.ps1` | 0 | `---- 37 passed, 0 failed, 0 skipped` | uses temp profile paths, so the real `Documents\PowerShell` is not touched |
| 14 | b8-consumers | `bash tests/b8-consumers/test-b8-consumers.sh` | 0 | `31 passed, 0 failed, 0 skipped (windows: ps1 scripts)` | |
| 15 | claude-mdm | `bash tests/claude-mdm/test-claude-mdm.sh` | 0 | `33 passed, 0 failed, 1 skipped (windows: ps1 scripts)` | |
| 16 | hookin | `bash tests/hookin/test-hookin.sh` | 0 | `29 passed, 0 failed, 0 skipped (windows: ps1 scripts)` | |
| 17 | build-deploy-backup | `bash tests/build-deploy/test-build-deploy-backup.sh` | 0 | `24 passed, 0 failed (windows)` | |
| 18 | pre-push-step7 | `bash tests/check-pre-push/test-pre-push-step7.sh` | 0 | `3 passed, 0 failed, 0 skipped` | |
| 19 | profile | `bash tests/profile/test-profile.sh` | 0 | `716 passed, 0 failed (windows: aitools-profile.ps1)` | 5 skip lines (macOS/Linux-only cases) |
| 20 | config | `bash tests/profile/test-config.sh` | 0 | `247 passed, 0 failed, 1 skipped (windows: ps1 writer)` | |
| 21 | lib | `bash tests/profile/test-lib.sh` | 0 | `201 passed, 0 failed` | 1 skip line (relay-run-rm-fail: macOS/Linux) |
| 22 | user-init | `bash tests/profile/test-user-init.sh` | 0 | `test-user-init: 179 passed, 0 failed, 1 skipped (windows: ps1 entry point)` | |
| 23 | install | `bash tests/profile/test-install.sh` | 0 | `19 passed, 0 failed (windows: ps)` | 1 skip line (step3-unresolvable: bash installer only) |
| 24 | fanout-lib | `bash tests/fanout-lib/test-fanout-lib.sh` | 0 | `90 passed, 0 failed, 20 skipped` | symlink, FIFO and chmod cases |
| 25 | rules-fanout | `bash tests/rules-fanout/test-rules-fanout.sh` | 0 | `61 passed, 0 failed, 3 skipped` | |
| 26 | rules-fanout-cursor | `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 0 | `145 passed, 0 failed, 6 skipped` | |
| 27 | skills-fanout | `bash tests/skills-fanout/test-skills-fanout.sh` | 0 | `106 passed, 0 failed, 7 skipped (windows: ps1 scripts)` | |
| 28 | skills-legacy | `bash tests/skills-legacy/test-skills-legacy.sh` | 0 | `32 passed, 0 failed, 2 skipped (windows: ps1 scripts)` | |
| 29 | deploy-harness | `bash tests/deploy-harness/test-deploy-harness.sh` | 0 | `99 passed, 0 failed, 2 skipped (windows: ps1 scripts)` | |
| 30 | deploy-harness-mdm | `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` | 0 | `56 passed, 0 failed, 0 skipped (windows: ps1 scripts)` | |
| 31 | delegation-duty-guard | `bash tests/hooks/test-delegation-duty-guard.sh` | 0 | `delegation-duty-guard: 44 passed, 0 failed (bash: 5.3.15(2)-release)` | advisory `WARN large prompt: 217 ms` |
| 32 | workflow-delegation-guard | `bash tests/hooks/test-workflow-delegation-guard.sh` | 0 | `workflow-delegation-guard: 74 passed, 0 failed, 1 skipped, 3 warnings (bash: 5.3.15(2)-release)` | Known flake did not fail, so no rerun. WARNs (advisory): 270-prompt stress 203 ms, 486 KB prompt 137 ms, adversarial 476 KB 180 ms |
| 33 | sh-file-fixup | `bash tests/hooks/test-sh-file-fixup.sh` | 0 | `test-sh-file-fixup: 41 passed, 0 failed, 2 skipped (bash: 5.3.15(2)-release)` | |
| 34 | glossary-skill-guard | `bash tests/hooks/test-glossary-skill-guard.sh` | 0 | `test-glossary-skill-guard: 12 passed, 0 failed, 0 skipped (bash: 5.3.15(2)-release)` | |
| 35 | sessionstart-harness-db | `bash tests/hooks/test-sessionstart-harness-db.sh` | 0 | `test-sessionstart-harness-db: 50 passed, 0 failed, 0 skipped (bash: 5.3.15(2)-release)` | |
| 36 | hooks-smoke | `bash tests/hooks/test-hooks-smoke.sh` | 0 | `test-hooks-smoke: 44 passed, 0 failed, 0 skipped (bash: 5.3.15(2)-release)` | |
| 37 | build-package-cli | `bash tests/build-package/test-cli.sh` | 0 | `36 passed, 0 failed` | |
| 38 | setup-user-shell (sh) | `bash tests/setup-user-shell/test-setup-user-shell.sh` | 0 | `0 passed, 0 failed, 1 skipped` | Expected on Windows: `SKIP all cases (setup-user-shell.sh runs on macOS/Linux only; Windows runs test-setup-user-shell.ps1)`. Not in the Windows CI job. |

Totals: 38 suites, 38 exit 0, 0 failed cases, 2,899 passed. The summary lines report 57 skips, and a few suites print skip lines without counting them. The full skip list (all platform reasons) is in S`summary-output.log`.

Windows CI steps I did not reproduce (they are not test suites): "Windows runner probe" (`tests/managed-files/winpty-probe.py`); the scripts/ and deploy/ syntax steps (the check scripts' post-push step 6 covers them: PASS); "Profile resolver (PowerShell, native machine id and hostname)", whose `setup-user-config.ps1` would write `$HOME\.aitools\config.json`; "Build deploy scripts" and "Check deploy drift" (unisolated in CI; replaced by the isolated build below).

## build-deploy (isolated)

Script: S`run-build.sh`. Log: S`build.log`. HOME and USERPROFILE = S`home-build`, AITOOLS_LOG_DIR = S`logs-build`, AITOOLS_USER_REPO_PATH = S`dotprofile` (a `git clone` of the real dotprofile).

- `[build-deploy] [info] Dotprofile: .../session-M3b-V/dotprofile (via AITOOLS_USER_REPO_PATH)`
- `[build-deploy] [ok] Build complete: 50 scripts generated in deploy/`, exit 0
- `[build-deploy] [ok] All PS1 files passed validation`. The embedded resolver is present once in each resolver-consuming script, and the try/finally cleanup is OK.
- `bash -n: 24 files, 0 failed`. `pwsh parse: 25 files, 0 failed`.
- 23 generated `.ps1` files inline aitools-lib.ps1, and each has `AitConsoleInput` (20 per inlined copy) and `Write-AiLog` (10 per copy). `setup-user-claude`, `setup-user-cursor` and `setup-user-settings` carry two copies: the lib plus the embedded resolver lib. `aitools-json.ps1` does not inline the lib.
- `Start-Job`: every match is the comment `# process's console. Not Start-Job: a job is a separate pwsh process with no`. There is no `Start-Job` call.
- WARN (does not fail the build): `24 generated script(s) over the Intune script limit`. This predates the branch: `scripts/aitools-lib.ps1` is 225,745 bytes on a98208e, already over 200,000 by itself. The branch makes it 235,844 bytes (+10,099 per inlined copy).
- `Harness snapshot: aitools/.claude/hooks not found -- not embedded` (info): the worktree has no `.claude/hooks`.

## Check scripts (native pwsh)

Script: S`run-checks.ps1`. Logs: S`check-pre-commit.log`, S`check-pre-push.log`, S`check-post-push.log`. Driver: S`checks-driver.log`.

Isolation: HOME and USERPROFILE = S`home-checks`, which holds `.aitools/config.json`, a copy of the real one with `userRepoPath` pointing to the scratch clone S`dotprofile-checks` and `repoPath` pointing to the worktree. AITOOLS_LOG_DIR = S`logs-checks` and AITOOLS_USER_REPO_PATH = S`dotprofile-checks`. I isolated these runs because post-push step 7 runs `build-deploy.sh` unconditionally (see INCIDENT). I passed no `-Fix`.

### check-pre-commit.ps1: exit 1, `=== SUMMARY: 7 PASS, 11 SKIP, 0 WARN, 1 FAIL ===`

- FAIL step 20 Path references, `dead repo path references (fix the path or see scripts/check-path-refs-allow.txt)`. It lists 5 references: `CLAUDE.md:100: .claude/rules/relay-outbound.md`, `reference/cursor-practices.md:43: .cursor/mcp.json`, `reference/tool-registry.md:341: .claude/settings.local.json`, `reference/tool-registry.md:354: .cursor/mcp.json`, `shared/claude-shared.md:95: .claude/settings.local.json`. This is already broken on main: the branch touches none of these files. One correction to the briefing: it named three files, but the step also reports `reference/cursor-practices.md`.
- Steps 2 to 5, 7 to 10, 12 and 13 SKIP because nothing is staged, which is expected for a verification run.

### check-pre-push.ps1: exit 0, `=== SUMMARY: 7 PASS, 0 SKIP, 3 WARN, 0 FAIL ===`

- Step 7 PASS: `fresh build OK (dotprofile deploy/ untracked, not compared); resolver consumers dry-run clean`
- WARN step 1 `confirm pre-commit checklist was run for each commit` (always WARN).
- WARN step 5 `non-docs changes without RELEASE_NOTES.md`: the branch has no RELEASE_NOTES entry.
- WARN step 6 `check if push completes or starts a roadmap item` (reminder).
- Step 8 `4 commit(s)`. Step 9 `branch: fix/console-input-mode`.

### check-post-push.ps1: exit 1, `=== SUMMARY: 22 PASS, 4 SKIP, 5 WARN, 2 FAIL ===`

- FAIL step 1 `HEAD != origin/main`: expected on a branch. origin/main is still a98208e after the step's fetch.
- FAIL step 3 MCP config integrity: `missing: ...\home-checks\.claude.json` and `missing: ...\home-checks\.cursor\mcp.json`. This comes from my isolated HOME. A read-only check of the real files shows `C:\Users\jdpal\.claude.json` has `chrome-devtools` (3) and `--isolated` (1), and `C:\Users\jdpal\.cursor\mcp.json` has 3 matches, so the step would pass against the real HOME.
- SKIP step 5 `SessionEnd hook not configured` and WARN step 17 `SessionEnd hook not in settings.json` also come from the isolation: the real `~/.claude/settings.json` contains `SessionEnd`.
- WARN step 19 `2 script(s) with potential blind overwrite` (setup-user-shell.sh, setup-user-settings.ps1): already a known WARN.
- WARN step 20 `CLI: 2.1.325 (Claude Code) vs registry: 2.1.309`: the machine is newer than the registry.
- WARN step 21 `15 tool(s) out of date; 2 OK, 4 skipped`: also the machine against the registry, unrelated to the branch.
- WARN step 25 `missing from Managed CLI Tools: google-chrome, certutil`: already a known WARN.
- SKIP 15 (side effect), 26 (`could not find deploy reference in CLAUDE.md`), 28 (retired).
- Step 7 `deploy/ drift audit` PASS. It built into the scratch clone (S`dotprofile-checks/deploy`) and then diffed the frozen aitools `deploy/`, which build-deploy no longer writes.
- Steps 23 (script standards, 12 PASS / 1 SKIP), 29 (menu parity `a,m,o,s,x`), 30, 31 and 32 (`19 hooks`) PASS.

## Git status before and after

| Tree | Before | After |
|---|---|---|
| worktree `console-input` (`status --short`) | (empty) | (empty). Ignored and untracked in source dirs: `!! scripts/__pycache__/ait-harvest.cpython-314.pyc`, `!! scripts/__pycache__/harness-db.cpython-314.pyc` (gitignored, written by the Python suites) |
| real dotprofile `aitools-nobul-jose` | ` M profile.json` (already there) | ` M profile.json` (unchanged). `deploy/` mtime `2026-11-13 16:04:11 -0800`, before this run started (18:28 PT) |
| origin/main | a98208e | a98208e |

Real `~/.aitools/logs`: checks.log and deploy.log were written at 02:38:47Z during my run, by the parallel mission M4-Winpty (`branch: feature/pywinpty-adopt` in those lines), not by me. Neither file has any line mentioning `console-input` or `session-M3b-V` (`grep -c` = 0 for each).
