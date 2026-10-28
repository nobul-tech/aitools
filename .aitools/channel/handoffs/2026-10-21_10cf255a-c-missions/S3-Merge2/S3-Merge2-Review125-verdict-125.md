VERDICT: MERGEABLE

# S3-Merge2-Review125: pre-merge review of PR #125 (FO-6), v1.0

Independent pre-merge review by S3-Merge2-Review125 (delegated by S3-Merge2, mission MERGE-2, Session Commander 10cf255a-c), on the commander's 2026-10-28 order: "launch a mission to serve as an orchestrator and merge open prs in the correct order. learn from past mistakess. give it explicit instructions to fix issues when they arise. do this now. have the orchestrator launch a review first."

- **Head reviewed:** `7754c15ff02f7f7810e7fc6a2f675dc8cae67bd0` (`feature/fanout-skills-legacy`)
- **Against:** `origin/main` `86a0ea88faec50e13b9d49067f3894bb4c771bea` (2026-10-28), and the open train heads #122 d3e0249, #120 1d37d93, #117 dbe8f46, #118 d29dc5f, #119 fd660a9, #121 4339c08, #124 282c28b, #123 096a8bf
- **GitHub:** `mergeStateStatus` DIRTY / CONFLICTING. CI on 7754c15: macos, windows and CodeQL SUCCESS; linux FAILURE (fanout-lib `bd-special`, see below).
- **Blocking findings in the PR's own code:** 0. Non-blocking: 3.

**Merge conditions.** These follow the train order, not code fixes:
1. merge #125 only after #123;
2. merge `origin/main`, by then containing #117-#123, into the branch with `--no-ff`, resolving the conflicts listed below;
3. confirm CI is green, linux included;
4. get a re-verify comment on that new head (the head changes, so this verdict's SHA no longer covers it).

At 7754c15 itself GitHub cannot merge it (CONFLICTING).

## Code review (FO-6's own commits 72589f9 and 293ec10, against main)

I read the full diffs `3178810..72589f9` and `6d34dd8..293ec10` of `scripts/setup-user-skills.sh` / `.ps1` and the `build-deploy.sh` generator section. Everything below still holds against current main:

- **The harness check sits in the extracted body**, so MDM carries it: `[ -d "$HOME/.aitools/skills" ]` / `Test-Path -LiteralPath ... -PathType Container`. build-deploy wraps the embedded deploy in `if [ "$SKILLS_FANNED_OUT" != "true" ]` / `if (-not $skillsFannedOut)`.
- **Fan-out mode** writes one row, `OK skills "n/a (fanned out)"`, and leaves both tool rows to the fan-outs. `SKILLS_ROW_TOOL` / `$skillsRowTool` routes reverse discovery's rows to `skills`.
- **Every new `log_error` / `LogError` is paired with an ERROR row**, and the exit footer is unchanged:
  - `no adopt: dotprofile error | harness unreadable | manifest unreadable | target unreadable`
  - `adopt failed: <name>`
- **Error suppression:** `rc` is captured (`out=$(read_harness_manifest ...) || rc=$?`, checked on the next line), and every PowerShell catch logs. There is no unguarded `2>/dev/null`, `|| true` or `SilentlyContinue`.
- **bash 3.2:** nothing newer than 3.2 is used (`case` patterns, `${var##*: }`, `<<<`). `tests/skills-legacy` passes under /bin/bash 3.2.
- **sh/ps1 parity:** the same branches, rows and log text. The suite compares the rows.
- **interactive-menus return values:** the PR changes none of the `deploy_managed_file` call sites. Fallback `deploy_skill` / `Deploy-Skill` still handle `accept & adopt` (sync to the other targets) and `created|updated|skipped|verified|failed`.
- **Earlier findings:** S3-FanoutImpl-Review125 B1 and N1-N3, AuditA N1-N5 and AuditB N1/N3 are fixed. The re-verify (issuecomment-6434304976) still holds against this head.

**Main-side changes since the branch was cut that touch this PR's area:**
- **#128 / #129 changed the skill set:** 20 in `shared/skills`, 2 in `.claude/skills`, `aitool-ops` / `aitool-eval` deleted. The fallback discovers skills at run time, so nothing is hard-coded. In fan-out mode, a deleted skill that deploy-harness recorded as `retired` is excluded from reverse discovery (manifest lines of every source, retired included). See N2 for the case it misses.
- **#131 changed `scripts/build-deploy.sh`:** it auto-merges with this PR's 9-line generator change. `tests/build-deploy/test-build-deploy-backup.sh` passes on the trial merge (below).

## CI: run 40450703903, linux, `FAIL ps bd-special` / `FAIL parity bd-special`

`gh run view 40450703903 --log-failed`: "Fan-out lib helper tests (bash + pwsh parity)", 356 passed, 2 failed.
- **What fails:** pwsh's `Backup-Dir` prune removed the decoy `r[1]*?.bak.2020-01-01T000000Z.bak.2020-01-02T000000Z` instead of `r[1]*?.bak.2020-01-02T000000Z`. These are wildcard characters in a `-Path` on Linux.
- **The fix is not on this branch:** #118 commit 32a1354 ("Prune old directory backups with .NET calls in Backup-Dir", `scripts/aitools-lib.ps1`) is on `feature/fanout-lib` but not in 7754c15 (`git log 7754c15..d29dc5f` lists it).
- **It works on #118's head:** linux job 122045018305 on d29dc5f shows `ok sh bd-special`, `ok ps bd-special`, `ok parity bd-special`, 374 passed, 0 failed.
- **It merges cleanly:** `git merge-tree 7754c15 d29dc5f` has no conflicts.
- **Answer: yes, it clears** once #118 is on main and main is merged into this branch.

## Expected conflicts and how to resolve them

**On origin/main as it is today** (trial merge `--no-ff --no-commit`), 3 files:

| File | Conflict | Resolution |
|---|---|---|
| `.github/workflows/check.yml` | 4 hunks, macOS + Linux jobs. This PR's (train's) fan-out steps vs main's `tests/profile/test-install.sh` and `tests/build-deploy/test-build-deploy-backup.sh` steps | Keep both sides. The union parses (ruby YAML) |
| `README.md` | 2 hunks, MDM script list | Take main's list (#132 scrub, fuller) and add the FO note that the rules fan-outs read `~/.aitools/rules`. #126 owns the final README text |
| `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` | header, `--help` range, forced size-gate fixture | Take the FO side (pads the CLAUDE.md template; FO-3 no longer embeds dotprofile rules, so main's padded rule would not reach the generated script). `--help` range 2-30 matches the FO header |

**Once the train lands**, from pairwise `git merge-tree` of 7754c15 with each current train head:
- #122: `check.yml` again (adjacent steps; keep both sides).
- #121 (4339c08): `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`, comment wording plus one `mkdir -p` line. Take #121's side.
- #123 (096a8bf): `tests/skills-fanout/test-skills-fanout.sh` case `cursor-none`. Both sides assert "no cursor skills row". #123's uses `cnondetail`; this PR's also greps the log line `No harness skills at ... setup-user-skills deploys skills`, which #123's lib still logs (`aitools-lib.sh:3098`, `.ps1:3111` on 096a8bf). Either side passes; keeping this PR's stricter check is fine.
- #117, #118, #119, #120, #124: clean.

## Non-blocking

- **N1.** Carried follow-ups from the PR body, still open: `skills` in the tool-name table (FO-7/#126 adds it), the OK-to-WARN promotion of the n/a row, the `Read-HarnessManifest` directory message in the lib, the dry-run `verified` count, and `*.bak.*` directories offered for adoption in fallback mode. None blocks this merge.
- **N2 (new, behaviour note).** In fan-out mode, a skill retired from the sources before this machine's first manifest existed (for example a stale `~/.claude/skills/aitool-ops` left by the old setup-user-skills, on a machine whose `~/.aitools/skills` manifest never listed it) is not in the harness names. Reverse discovery then offers it for adoption as user-created. This only happens interactively; a non-interactive run makes no adopt choice. It behaved the same way before this PR, in fallback mode. A follow-up could seed the exclusion from #129's deleted names. Not a blocker.
- **N3.** The Windows job still does not run `tests/skills-legacy`. The .ps1 is covered under pwsh on macOS and Linux with the OS guard patched, as stated in the PR.

## What I ran

**Trial merge** of `origin/main` into 7754c15 (`--no-ff --no-commit`, not committed or pushed): conflicts resolved as in the table, suites run under isolated HOMEs (`HOME`, `USERPROFILE` and `GIT_CONFIG_GLOBAL` in scratch), then aborted. The results:

| Suite (on the trial merge) | Result |
|---|---|
| tests/skills-legacy, bash 5 / /bin/bash 3.2 / `CI=true` | 50/0/0 each |
| tests/skills-fanout, bash 5 + pwsh / 3.2 `--bash-only` | 158 passed, 1 skipped / 65 passed, 28 skipped |
| tests/fanout-lib (macOS; bd-special passes here, the failure is Linux-only) | 358/0/0 |
| tests/claude-mdm | 38/0/0 |
| tests/deploy-harness-mdm | 67/0/0 |
| tests/deploy-harness | 131/0/0 |
| tests/build-deploy/test-build-deploy-backup.sh (main's #131) | 24/0 |
| tests/rules-fanout | 118 passed, 1 skipped |
| tests/rules-fanout-cursor | 198 passed, 1 skipped |
| tests/b8-consumers | 60/0/0 |
| tests/hookin | 46/0/0 |
| tests/profile/test-install.sh (main's suite) | 41/0 |

**Other checks:**
- `bash -n scripts/setup-user-skills.sh` and `/bin/bash -n scripts/build-deploy.sh`: OK.
- pwsh parser on `setup-user-skills.ps1` and `aitools-lib.ps1`: OK.
- `.github/workflows/check.yml` after the union: ruby YAML parse OK.
- `git merge-tree` of 7754c15 with each train head: as listed above.
- Train chain from 86a0ea8: stops at #122 (`check.yml` + modify/delete `shared/skills/aitool-ops/SKILL.md`); without #122, stops at #117 (`check.yml`). The train heads have not merged current main yet.

Worktree: `/Users/new-jose/repos/aitools/.claude/worktrees/m2-rv125` (detached at 7754c15; the merge was aborted).

**Not run:**
- Windows.
- A real Linux pwsh run of `bd-special`: no Linux runner here. The evidence is #118's CI job.
- `check-pre-commit` / `check-pre-push` as a reviewer (no commit).
- Interactive pty adopt cases beyond what `tests/skills-legacy` covers.

-- S3-Merge2-Review125 (level 3: S3-Merge2 -> Session Commander 10cf255a-c)
