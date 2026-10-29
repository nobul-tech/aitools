# S3-MA-Rebuild log

**Version:** v1.1 (v1.0 + the step 7 result) · **Written:** 2026-10-27 (UTC) · **By:** S3-MA-Rebuild (delegate of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose)

## 1. Result

- **Code (PR #131):** build-deploy.sh backs up the dotprofile `deploy/`, builds in a temp dir and swaps the new build in only on success (incident #86, decision A4). https://github.com/nobul-tech/aitools/pull/131
  - Branch `fix/build-deploy-backup`, commit 611396c.
  - Merged with `--merge` as d65623b at 2026-10-27T09:57:16Z.
- **Real rebuild (the one real-HOME run, decision A4):** dotprofile commit a7745dd, pushed to `nobul-jose/aitools-nobul-jose` main (20683a2..a7745dd).
  - Backup: `/Users/new-jose/repos/aitools-nobul-jose/deploy.bak.2026-10-27T101222Z/`. It was verified identical, and git ignores it through `.gitignore:2:*.bak.*`.
- **Pre-push step 7:** PASS from the main checkout (section 4).

## 2. What changed (PR #131)

### `scripts/build-deploy.sh`

Before the build, it copies `<dotprofile>/deploy/` to `<dotprofile>/deploy.bak.<UTC>/`:
- The copy uses `cp -Rp`, gets a `-N` suffix on a same-second clash, and is verified with `diff -rq`.
- It then prunes to the newest 5 (names sort by UTC) and logs every prune.
- If no backup can be made, or the copy differs, the build exits 1 and `deploy/` is untouched.
  - This is stricter than config-file-safety.md's "backup failures are non-fatal".
  - The reason is the commander's order "do a backup of the deploy and then do a rm -rf if necessary": `deploy/` is never replaced without a backup.
  - The deviation is stated in the code comment and in the PR.

It warns when the dotprofile does not ignore the backup (`git check-ignore`) and names the fix. `aitools user init` writes `*.bak.*` (`scripts/aitools:789`, `scripts/aitools.ps1:1456`), which already covers the backups.

The swap used to be `rm -rf deploy` then `mv` from `$TMPDIR`: a failed or cross-device `mv` lost `deploy/`. Now:
1. `mktemp -d <dotprofile>/deploy.swap.bak.XXXXXX`. The name matches `*.bak.*` but not the prune pattern.
2. Move the build into `swap/new`.
3. Rename the old `deploy/` to `swap/old`.
4. Rename `swap/new` to `deploy/`.
5. `rm -rf` the swap dir. Stale generated files go with it.
6. Every failure branch puts the old `deploy/` back, keeps the backup, and logs. There is no unchecked `rm`/`mv`.

### Other files

- `tests/build-deploy/test-build-deploy-backup.sh` (new). It uses an isolated HOME, a fixture dotprofile git repo per case, a stub `pwsh` and `AITOOLS_USER_REPO_PATH`. Cases:
  - **success:** stale file gone, backup identical, 6 old backups pruned to 5 (oldest first), no swap dir, git ignores the backups.
  - **failure:** stub pwsh exits 1, so PS1 validation fails late. The run exits 1, `deploy/` is unchanged, one backup is kept, and git is clean.
  - **first build:** no backup.
  - **unignored:** warning.
- `.github/workflows/check.yml`: the test runs on macOS (bash 5 and `/bin/bash` 3.2) and on Linux.
- Docs, written as versions for review after (decision A2):
  - `.claude/rules/deploy-paths.md` and `.cursor/rules/deploy-paths.mdc` ("deletes and rebuilds" replaced by the backup and swap description)
  - `reference/managed-file-deployment.md` "Backup Policy" (new "Generated `deploy/`" bullet)
  - `reference/user-repo.md` (directory tree line)

## 3. Verification

| What | Result | Evidence |
|---|---|---|
| `bash -n scripts/build-deploy.sh` | clean | worktree bdbackup |
| `check-hook-parity.py` | "18 hooks" OK | worktree bdbackup |
| New test, bash 5 | 24 passed, 0 failed | worktree and main checkout (after merge) |
| New test, `/bin/bash` 3.2 | 24 passed, 0 failed | worktree |
| Negative control: new test against origin/main's build-deploy.sh | 9 of 24 FAIL (every backup assertion) | `.scratch/session-bdbackup/mutation.sh` |
| check-pre-commit (worktree) | 11 PASS, 6 SKIP, 4 WARN, 1 FAIL | Step 6 is the known harvesting file mode (`harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` 100644) |
| check-pre-push (worktree, before rebuild) | 6 PASS, 3 WARN, 1 FAIL | Step 7 known stale. Its rebuild into the temp copy ran with the new build-deploy and succeeded |
| PR CI run 40482624231 | macos, linux, windows SUCCESS | `gh pr view 131 --json statusCheckRollup` |
| PR CodeQL run 40482649108 | Analyze x4 SUCCESS; CodeQL NEUTRAL (skipping) | same |
| Merge gate | mergeStateStatus CLEAN, head 611396c matched (`--match-head-commit`) | pre-merge comment https://github.com/nobul-tech/aitools/pull/131#issuecomment-6438817133 |
| main CI run 40484722384 (d65623b) | macos, linux, windows SUCCESS | `gh run watch --exit-status` |
| main "Push on main" run 40484722788 | success | `gh run view` |
| Real build-deploy (main checkout d65623b) | exit 0. Dotprofile via resolver: `/Users/new-jose/repos/aitools-nobul-jose`. "Backed up ... (verified identical)", "1 found", "Replaced deploy/", 50 scripts. 7 Intune size WARNs (known, FX-35) | `.scratch/session-bdbackup/real-build.log` in worktree bdbackup |
| Dotprofile status reviewed | 42 modified + 9 new under `deploy/`, no deletions. `sessions/.DS_Store` modified before this run, not mine, not committed. No `/Users/new-jose` paths in `deploy/`; no token patterns | `git status`, `grep` |

## 4. Pre-push step 7 after the rebuild

`bash /Users/new-jose/repos/aitools/scripts/check-pre-push.sh` ran from the main checkout with commit 23c0725 (this log v1.0) unpushed. With nothing unpushed the script skips every step, so the log was committed first. Result: 7 PASS, 1 SKIP, 2 WARN, 0 FAIL. Step 7 printed `[PASS] dotprofile deploy/ matches a fresh build; resolver consumers dry-run clean`. The WARNs were step 1 (confirm pre-commit) and step 6 (roadmap), both reminders. The known pre-push step 7 FAIL is gone.

## 5. Not run

- Windows / Git Bash. The test does not reach the build's Windows PS1 validation branch, and CI does not run the test on Windows.
- The generated scripts on an endpoint.
- No independent review of PR #131. This delegate cannot launch sub-agents. The pre-merge comment is a self-check and says so.

## 6. Incidents and follow-ups

- Incident #86 can close: correctiveAction PR #131 (d65623b), rebuild a7745dd. `registries/incidents.json` is not edited here; it is protected, and the ledger work owns it.
- INCIDENT: `shared/skills/delegate/SKILL.md` (line 436), `shared/skills/tool-adopt/SKILL.md` (line 166) and `shared/rules/hook-lifecycle.md` (line 119) still give "build-deploy deletes and rebuilds the real dotprofile deploy/" as the reason for the isolated-HOME rule. The rule still holds, but the reason is out of date. They are left for the docs scrub: the delegate skill is D-DEL5 territory.
- INCIDENT: a run killed mid-swap leaves `deploy.swap.bak.*`. It is ignored by git but is never cleaned up automatically. Candidate for the friction plan.
- The dotprofile `.gitignore` already ignores the backups (`*.bak.*`), so it needed no change.

## 7. WRITE_BLOCKED

None.
