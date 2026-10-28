# S3-MA-FrictionIssues findings v1.0

**Version:** v1.0 · **Written:** 2026-10-26 · **By:** S3-MA-FrictionIssues (delegate of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose) · **Mode:** read-only research, not committed.

**Input for:** `plans/merge-friction-improvements.md` v1.0 (brief deliverable 4).

## How I checked

- `gh issue list -R nobul-tech/aitools --state all --limit 200`: 25 issues (#7-#32, #72). 14 open (#10, #14, #19, #21-#29, #31, #72), 11 closed. Read every body and comment (`gh issue view <n> --json title,body`, `--comments`).
- `gh pr list --state all --limit 200`: PRs #2-#116. 19 open, all base `main`, all `mergeStateStatus` CLEAN on 2026-10-26.
- `gh run list --limit 200`: 92 success, 5 failure, 3 in progress. Read the failed-step logs of all 5 failures (`gh run view <id> --log-failed`).
- `gh api repos/nobul-tech/aitools` (merge settings) and `.../rules/branches/main` (ruleset).
- `git log --all --since=2026-10-01`; `.github/workflows/check.yml`; `scripts/check-pre-commit.sh`, `scripts/check-pre-push.sh`; `tests/`.
- Operational learning: handoff `2026-10-22_10cf255a-c.md` sections D, G and I; mission packet sections 4-5.
- Scratch: `.scratch/session-mafric/` (dump scripts and raw output).

## Summary: the 12 recurring failure classes

| # | Class | Recurrences (evidence) | Cheapest catch |
|---|---|---|---|
| F1 | No merge gate on GitHub: checks are not required and go stale | ruleset 16468370 has only `deletion` + `non_fast_forward`; all 19 open PRs are CLEAN on checks from 2026-10-23, and main has moved since (8e490d7, 9923a3c, b40a320 ...) | Ruleset: required checks + strict "up to date"; `scripts/pr-merge-gate.sh` |
| F2 | Stacked PRs and squash merges break the stack | #74/#75 merged into stale bases (D.2); #71 and #73 were squashed, so 67e144f had to merge squashed #73 back | Disable squash/rebase; CI fails when a PR's base is not `main` |
| F3 | PRs merged before their review fixes, then fix-forward PRs | #56 then #60; #76/#77 then #84; #79 then #89; #116 needs one now; #111 commit 8caa79e never re-reviewed (brief) | Merge gate requires a verdict comment that names the head SHA |
| F4 | Test suites exist but CI never runs them | 4 suites: `tests/deploy-harness`, `tests/deploy-harness-mdm`, `tests/rules-fanout-cursor`, `tests/build-package` (`grep -c` in check.yml = 0); G16 | CI steps + a coverage check that every `tests/*/test-*` is wired |
| F5 | A skipped test group counts as a pass | #72: Windows "9 passed, 0 failed, 1 skipped" (run 39719152527), 13 PS1 interactive cases never run where users see the menu; PS1 logging entry tests "5 skipped" on macOS (run 39891264259) | `::warning::` per SKIP and an allowlist of expected skips |
| F6 | Platform-specific test assumptions | 5 of 5 failed CI runs (table F6) | `tests/lib/` helpers + lint |
| F7 | Local checks that are red by design, so agents learn to ignore red | packet section 4 lists 3 "known pre-existing failures" | Fix them; a dated known-failure list that fails when it expires |
| F8 | CI never runs the pre-commit/pre-push checks | `check.yml` runs only `check-hook-parity.py` (line 281) | CI job running `check-pre-commit.sh` in an isolated HOME |
| F9 | Issue tracker lags the code | #32 open 18 days after 7aacdef; #21-#31 open though #35-#45 claim fixes; epic #10 checkboxes stale; 23 incidents claimed fixed still open (G5) | Closing keywords in PR bodies + a post-merge issue-sync step |
| F10 | Draft, approve, apply: two PRs per protected change | 8 draft-only PRs and 6 apply PRs (F10 table); drafts go stale before they are applied | D-DEL5 versions + review-after (A2) |
| F11 | Contract drift between parallel missions | OL I: a non-existent flag and build markers in launch prompts; #100 headings are cut points for the MDM generator (D.4) | Contract test in the (unwired) MDM suite + pinned names |
| F12 | Silent wrong outcomes in setup scripts (logging and summary) | #13, #17, #18, #22-#30, #31; epic #21 | Lint steps for the known-bad shapes + a Linux install-twice smoke |

Each class is detailed below: evidence, root cause, remedy.

---

## F1. No merge gate on GitHub; checks go stale

**Evidence**
- `gh api repos/nobul-tech/aitools/rules/branches/main` returns only `deletion` and `non_fast_forward` (ruleset 16468370). No required status checks, no required review, no "require branches to be up to date".
- `gh api repos/nobul-tech/aitools`: `allow_auto_merge:false`, `allow_squash_merge:true`, `allow_rebase_merge:true`, `allow_merge_commit:true`, `delete_branch_on_merge:false`.
- All 19 open PRs show `mergeStateStatus` CLEAN. #102's checks completed 2026-10-23T05:16-05:25Z (`gh pr view 102 --json statusCheckRollup`). main has had commits since (2026-10-26: 9923a3c, 8e490d7, 1af8851, 3de51d6, b40a320, 5494d93). With no strict rule, CLEAN says nothing about the PR merged with today's main.
- The rollup has 7 entries: CI `macos`/`linux`/`windows`, 3 CodeQL `Analyze`, and a CodeQL aggregate that can be `NEUTRAL` (#102). "All green" is ambiguous for NEUTRAL.

**Root cause:** the gate is policy only (handoff E step 2: "nothing technical stops an agent merge; this is policy"), and GitHub has no rule that ties CLEAN to the current base.

**Remedies**
1. **Repo setting (commander, one-time):** add `required_status_checks` to ruleset 16468370 with contexts `macos`, `linux`, `windows`, and `strict_required_status_checks_policy: true`. Set `allow_squash_merge:false` and `allow_rebase_merge:false` (A1: merge commits only). Enable `allow_auto_merge` so `gh pr merge --merge --auto` waits for green by itself. Leave `delete_branch_on_merge` false until the #110-#116 stacks are merged (A1: keep branches until the chain merges), then turn it on.
2. **Script `scripts/pr-merge-gate.sh` / `.ps1`** (pair; bash 3.2). Input: PR number. Exits 0 only when all of these hold:
   - `baseRefName == main`;
   - every check in `statusCheckRollup` is SUCCESS, or NEUTRAL/SKIPPED on an allowlisted name (CodeQL aggregate);
   - the checks ran on the current `headRefOid` (from `gh api repos/:o/:r/commits/<sha>/check-runs`);
   - `git merge-base --is-ancestor origin/main <headRefOid>` is true, or the CI run is newer than the main tip (otherwise: "update the branch with a merge of main and wait for CI");
   - `mergeStateStatus == CLEAN`;
   - a verdict comment exists for the head SHA (F3).
   The mission's merge step calls it before every `gh pr merge --merge`.
3. **Unit test `tests/merge-gate/test-merge-gate.sh`.** Feed recorded `gh` JSON fixtures (stub `gh` on PATH). Assert exit 1 for: a stale base, a failing check, checks from an older head SHA, base != main, a missing verdict; exit 0 for an all-green current fixture.

## F2. Stacked PRs and squash merges break stacks

**Evidence**
- #74 and #75 merged into `fix/registry-paths` / `feature/user-level-skills` after those bases had already merged to main. The work is "merged" on GitHub but not on main (handoff D.2, verified with `gh pr view 74`).
- #71 was squash-merged (6dc9c99), so the old stack still carries PR-a's original commits 0db8cc9, 24b56d3, 01355d5, 63ce030 (handoff E step 1). #73 was squashed too, so 67e144f had to "Merge origin/main (squashed #73) into the config-writer branch".
- `check.yml:15-16`: `pull_request: branches: [main]`. A PR whose base is a stack branch gets **no CI at all**. #74 merged with zero checks (`gh pr checks 74`: "no checks reported").
- Open stacks now: #112 contains #103; #113 contains #103+#98; #114 contains #98+#108; #115 contains #113; #116 contains #115; #110/#111 contain #100 (brief A1). They are now based on `main` with `--no-ff` merges of the lower heads (#114, #115 bodies), which works.

**Root cause:** GitHub does not retarget a stacked PR when its base merges unless the base branch is deleted. Squash rewrites the lower PR's commits, so the upper branch carries duplicates.

**Remedies**
1. Disable squash and rebase merges (F1.1). One merge method means stacks never carry rewritten duplicates.
2. **CI job `pr-hygiene`** (ubuntu, `on: pull_request` with no branch filter, so stacked PRs trigger it): fail when `github.base_ref != 'main'` with "retarget to main; stack by merging the lower branch with --no-ff". The rest of CI stays as it is.
3. **Process (delegation rule / packet section 4):** every PR's base is `main`. A stacked change merges the lower head with `--no-ff` and says "contains #N" in the body. That is the pattern #114-#116 use; write it down.

## F3. Merged before the review fixes landed

**Evidence:** #56 merged, then #60 restored the sed guard it had regressed. #76/#77 merged at 50e4bb5/67e144f before S3-Profile-Review2's fixes, then #84. #79 merged at cc597ec before its Review3 fixes, then #89. #58 merged with open review findings, then #66 (handoff I: "Four PRs were merged before their reviews were addressed (#56, #58, #76/#77, #79)"). #111's 8caa79e was never re-reviewed (brief section 3). #89's 2f189a0 and #69 were never independently reviewed (G17).

**Root cause:** a review verdict is a free-text comment with no link to the commit it reviewed. Commits pushed after the verdict are invisible at merge time. GitHub refuses `--approve` from the same account (OL), so the native "dismiss stale approvals" setting cannot help.

**Remedies**
1. **Verdict format (the /delegate skill, reviewer section):** the first line of every verdict comment is `Verdict: APPROVE|CHANGES @ <40-char head sha>`.
2. **Gate:** `pr-merge-gate.sh` (F1.2) requires the newest `Verdict:` comment to be APPROVE at the current `headRefOid`. A push after the verdict blocks the merge until it is re-reviewed. The same fixtures test covers it.
3. **Optional CI job `verdict-check`** on `issue_comment` + `pull_request: synchronize`: posts a commit status `review/verdict` (success only when the verdict SHA equals the head). Then make it a required check. Needs a workflow with `statuses: write`. Yellow flag: comment-triggered workflows on public repos need care with untrusted input. Use the comment body only as data, never in `run:` interpolation.

## F4. Test suites that CI never runs

**Evidence:** `find tests -name 'test-*'` finds 12 entry files. Four are not referenced in `check.yml` (`grep -c "deploy-harness\|rules-fanout\|build-package"` = 0):
- `tests/deploy-harness/test-deploy-harness.sh` (#88)
- `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (#93/#111)
- `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` (#87, 79 cases)
- `tests/build-package/test-cli.sh` (568fb5b)

Handoff G16 already flagged it: "`tests/deploy-harness` not in CI; no `.ps1` tests for deploy-harness". Open PR #112 adds `tests/claude-mdm/` and wires it in. That is the right pattern, but nothing enforces it.

**Root cause:** wiring a suite into CI is a manual second step with no check behind it.

**Remedies**
1. **CI steps** in all three jobs: one step per suite above. Windows runs the bash suites through Git Bash, like the existing managed-file step.
2. **Check `scripts/check-ci-coverage.py`** (stdlib), run as a new pre-commit step and as a CI step in the linux job. It fails when a `tests/**/test-*.{sh,ps1}` path is not named in `.github/workflows/check.yml`; exemptions go in `scripts/check-ci-coverage-allow.txt`, one reason per line. Mirrors the step-20 allowlist pattern (`scripts/check-path-refs-allow.txt`).
3. **Unit test:** `tests/ci-coverage/test-ci-coverage.sh` builds a temp tree with one wired and one unwired suite, and asserts exit 1 naming the unwired one, then exit 0 after it is allowlisted.
- Step-number note: pre-commit runs to step 20 on main. The #74 re-land adds step 21. New steps should start at 22, and the plan should reserve the numbers so parallel PRs do not collide.

## F5. A skipped test group counts as a pass

**Evidence:** #72. The Windows job reported "9 passed, 0 failed, 1 skipped" with "SKIP interactive cases (no python3 pty on this platform)" (PR #68, run 39719152527). 13 interactive PS1 menu cases run only on macOS/Linux, where the PS1 entry points stop at their OS guard. Same shape on main: the PS1 logging suite on macOS: "15 passed, 0 failed, 5 skipped ... (aitools.ps1 runs on Windows only)" (run 39891264259). #73's profile suite never runs its PS1 side on Windows (#72 comment).

**Root cause:** the harnesses exit 0 when `failed == 0`, whatever was skipped, and CI has no visibility into skips.

**Remedies**
1. **Test-lib change:** every suite's SKIP prints `::warning title=skipped::<case> (<reason>)` when `GITHUB_ACTIONS=true`, and the summary line is parsed into the job summary (`$GITHUB_STEP_SUMMARY`).
2. **Expected-skip manifest `tests/expected-skips.txt`** (`<runner> <suite> <case-prefix> <reason>`). The suite exits 1 when a skip is not listed. A new skip then fails CI until someone records why.
3. **#72's preferred fix (input seam):** route `Read-ConsoleChoice` and the merge `[y/n]` read through one replaceable reader, so the interactive cases run on the Windows runner. Done-when from #72: no `SKIP interactive cases` line on Windows, and breaking a menu branch in `aitools-lib.ps1` fails the Windows job.
4. **Policy line** (cross-platform rule, a protected file, written as a version under A2): console/terminal tests must run on Windows; PS1 logic tests run on all three runners.

## F6. Platform-specific test assumptions (all 5 failed CI runs)

| Run | Branch | Failure | Fixed by |
|---|---|---|---|
| 39873612279 (macos+linux) | feature/m3-rekey | `error: src refspec main does not match any`: test bare remotes used the runner's default branch `master` | f473e55 "pin bare remotes and clones to main (CI default branch is master)" |
| 39888735993 (windows) | fix/mf-dotprofile-adopt-push | 4 FAILs: asserts expected a POSIX path, but the log held `C:\Users\RUNNER~1\AppData\Local\Temp\...` (8.3 short name, backslashes) | c05fec8 "Expect display_path form of the dotprofile in adopt-push ACTION asserts" |
| 39890650263, 39891264259, 39891714493 (macos, /bin/bash 3.2 step) | fix/mf-audit-profile-json | `a78-exc-ro`, `a8-mig-ro`: the expected pattern held a literal `profile.json\.tmp\.<pid>`; the real message held `.tmp.40736` | dbcc61a "Normalise temp file names in bash-only test runs" (3 pushes to get green) |

Same class outside the failed-run list:
- d977807 "CI: end the Windows profile-resolver step with exit 0": the runner appends `exit $LASTEXITCODE` to `shell: pwsh` steps (#72 comment).
- 435a7aa: pwsh on Linux ignores `\x04` through a pty (60 s timeout, #72).
- 9923a3c and 161edd0: PowerShell `-Path` treats `[`/`]` as wildcards; fixed with `-LiteralPath`.
- `.ps1` files check out with CRLF, so line-anchored patterns silently miss (OL I).
- PowerShell variable names ignore case (`$e` vs `$E`, OL I).

**Root cause:** each suite rebuilds its own fixtures (git init, temp paths, path comparison) and relearns the same platform facts one CI failure at a time.

**Remedies**
1. **Shared test helpers `tests/lib/test-helpers.sh` + `.ps1`:**
   - `t_git_init_bare <dir>` / `t_git_clone` always pass `-b main` / `--initial-branch=main` (or `-c init.defaultBranch=main`);
   - `t_norm_path <p>` (cygpath -m plus a long-name expansion on Windows; PS1: `(Get-Item -LiteralPath $p).FullName`);
   - `t_norm_tmp` replaces `\.tmp\.[0-9]+` with `.tmp.<pid>` before matching;
   - `t_strip_cr` for anything read from a `.ps1`.
   New suites source it; existing suites migrate when touched.
2. **Lint step (pre-commit, plus a CI linux step), `scripts/check-test-portability.py`.** It fails on:
   - `git init` or `git init --bare` in `tests/` without `-b`/`--initial-branch`/`init.defaultBranch`;
   - in `scripts/*.ps1`, `Copy-Item|Remove-Item|Test-Path|Get-Item|Move-Item` with a `-Path $var` argument (use `-LiteralPath`);
   - in `check.yml`, a `shell: pwsh` step whose last line is a native command without `exit 0` when the suite expects a non-zero exit (heuristic; warn only);
   - `^`-anchored patterns applied to `.ps1` content without CR stripping (warn).
3. **Unit test** `tests/test-portability/test-check-test-portability.sh`: one fixture per rule, asserting the rule fires, and a clean fixture that passes.
4. **CI belt-and-braces:** `git config --global init.defaultBranch main` in every job's first step. Tests must still pass without it, so keep (1).

## F7. Local checks that are red by design

**Evidence**
- Mission packet section 4 lists three "known pre-existing failures (record, not blockers)":
  - pre-commit step 6: `harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` is still `100644` (`git ls-files -s`, verified today);
  - pre-push step 7: the dotprofile deploy/ is stale;
  - pre-push step 3: the `[\s]` false positive. `scripts/check-pre-push.sh:70` `secret_pattern='...)[\s]*[=:]'`: in POSIX ERE, `[\s]` is a backslash or `s`, not whitespace.
- B1/8e490d7: step 7 now runs on every push and fails until the post-merge rebuild. Every delegate's PR body carries a "step 7 FAIL, expected" line.
- PR #54 (2026-10-22): "Not run: check-pre-push (step 7 fails on every change until #32 is fixed)". The check was skipped entirely because it was known red.

**Root cause:** a check that is always red trains every agent to read FAIL as noise. A real failure in the same run is then missed, or the whole check is not run.

**Remedies**
1. Fix the two cheap ones now:
   - `git update-index --chmod=+x` on the harvesting file (or exclude `harvesting/` from step 6, since harvested files are records);
   - replace `[\s]` with `[[:space:]]` in `check-pre-push.sh:70` and the `.ps1` twin.
2. Step 7 turns green with the mission's real rebuild (A4). Then keep it green.
3. **Known-failure baseline `scripts/check-known-failures.txt`** (`<script> <step> <expires YYYY-MM-DD> <issue/incident> <reason>`). `print_summary`/`PrintSummary` (check-lib) prints a listed failure as `KNOWN` (exit 0), not FAIL. Past its expiry date it becomes FAIL again. A known red becomes a dated debt instead of folklore in prompts.
4. **Unit test** in `tests/check-lib/`: a known entry reports KNOWN and exit 0; an expired entry reports FAIL and exit 1; an unlisted failure reports FAIL.

## F8. CI never runs the check scripts

**Evidence:** `grep -n "check-pre\|check-post\|check-path-refs\|check-hook-parity" .github/workflows/check.yml` returns only `check-hook-parity.py` (line 281, linux job, added in d993a0f). Steps 16 (capability bypass), 17 (hook portability), 20 (path refs, df10361 had to allowlist draft paths after the fact), 15 (deprecated summary terms), 14 (build prereqs) and the post-push menu-parity steps 29/30 run only when an agent remembers to run them locally. Delegates often record "Not run: pre-commit and pre-push (docs-only change)" (#94 body).

**Root cause:** the check scripts were written for a human pre-push loop, and their environment-dependent steps (userRepoPath, git identity) were never separated from the pure ones.

**Remedies**
1. **CI job `checks`** (ubuntu + macos):
   - isolated `HOME`, with git identity set to the expected value;
   - `bash scripts/check-pre-commit.sh --all-files`, which needs a new flag to check the whole tree instead of staged files;
   - `bash scripts/check-post-push.sh` limited to the pure steps.
   Steps that need a dotprofile SKIP with a reason (they already SKIP when `userRepoPath` is unset, check-pre-push step 7 per #55).
2. **Windows:** the same through `pwsh -File scripts/check-pre-commit.ps1`. This also catches the `.sh`/`.ps1` parity drift that step 16 had (#71 body: "Pre-commit step 16 parity fix").
3. **Unit test:** `tests/check-lib/test-all-files.sh` asserts that `--all-files` reports a planted dead path (step 20) and a planted CRLF `.sh` (step 4) in a temp repo.

## F9. The issue tracker lags the code

**Evidence**
- #32 was fixed on main in 7aacdef (2026-10-03). The commit never referenced the issue, so it stayed open until #55 (2026-10-22) closed it.
- Epic #21: sub-issues #22-#30 are all OPEN. Yet PR bodies claim fixes:
  - #38: #22 and #27a for setup-rust;
  - #39-#43: #23, #25, #26a-f, #27b;
  - #44: "#31 caller half";
  - #35/#56: #29 in part (handoff G20).
  Partial or full: unknown without a code check, and no issue comment records what remains.
- Epic #10's checklist still shows #11, #13, #15, #17, #18 unchecked, though all five closed 2026-10-03 via #33.
- Incidents: 23 incidents claimed fixed by session PRs are still `open`, and about 80 INCIDENT markers in 22 files were unfiled (G5).
- #102's title says #146-#161; its report says #146-#170 (brief Q4).

**Root cause:** PR bodies cite issues as prose ("Part of #21", "#26a") and never with closing keywords. Nothing reconciles issues or incidents after a merge.

**Remedies**
1. **PR template `.github/pull_request_template.md`** with sections "Fixes" (closing keywords, `Fixes #N`), "Partly fixes" (`Part of #N: <what remains>`), "Incidents" (`closes incident #N` / `updates #N`).
2. **CI job `pr-hygiene`** (F2.2): warns (annotation, not fail) when the body mentions `#N` for an open issue with "fix" nearby but has no closing keyword and no "Part of".
3. **Post-merge step in the mission (and in the /delegate shipping section):** for each `Part of #N`, post an issue comment saying what landed and what remains, and update the epic checklist.
4. **Audit script `scripts/issue-sync-audit.sh`** (gh + jq): lists open issues referenced by merged PRs since a date, and epic checklist items whose issue is closed. Run it in the RELEASE orchestrator before the notes.

## F10. Draft, approve, apply: the "draft" overhead the commander named

**Evidence**

| Draft-only PRs (no target file changed) | Then applied by |
|---|---|
| #57 incident batch #87-#128 | #65 |
| #58 gate review, "Drafts only" | #66 rev 5, then #67 decisions |
| #61 scratch rule "draft ... for approval" | #70 |
| #63 managed-file spec drafts | #70 |
| #64 registry Claude Code entry draft | #70 |
| #96 M3 protected-file drafts | #99, #101, #105 (row 8 still held; rows 5-6 deferred) |
| #102 M3 incidents "drafts for approval" | apply step after merge (brief) |
| #60 hook-lifecycle drafts | #70 |

- Drafts went stale before they were applied:
  - #99: two approved paragraphs were "now false against origin/main" and were held, and the `.mdc` twin was "derived, please confirm";
  - #101: row 15 edit 2 was held, and row 3 landed "with deletions only";
  - #105: "row 8 is held: one of its claims is false";
  - G2: `aitools-json.pl` still says `DRAFT`.
- Approvals happened in chat and are not in the repo: "#96 was merged with no comment" (handoff E step 1, G4).
- The commander, 2026-10-26: "i dont like that produced work is often 'draft'"; B3: "produced materials should not be drafts, they should be treated as version 1.0 of working docs".

**Root cause:** the sources-of-truth.md pre-write gate (draft, present, wait) is enforced by agents as "write a draft somewhere else and open a PR". Every protected change costs two PRs and a stale window, and the approval record lives in chat.

**Remedies** (deliverable 3 of the brief already carries the decision; these are the supports)
1. **D-DEL5** in `~/.claude/rules/delegation.md` (source: dotprofile `claude/rules/delegation.md`) and `shared/skills/delegate/SKILL.md`: outputs are versions (`**Version:** v1.0`, then v1.1 ...), written to their real target path. A change to a version is a new version with a one-line changelog.
2. **`.claude/rules/sources-of-truth.md` to review-after (A2):** write the version, commit it with `Protected-file: <path> v1.N` in the commit body, and the commander reviews the diff. The commit trailer gives the RELEASE orchestrator, and the commander, a `git log --grep "Protected-file:"` list to review.
3. **Check step (pre-commit `--all-files`, CI):** warn when a newly added `.md` under `.aitools/channel/handoffs/` or `plans/` has no `**Version:**` line, or carries "draft"/"for approval"/"awaiting approval" in its first 10 lines. Warn only, so historical files are not rewritten.
4. **Unit test:** a fixture with a versioned file passes; one with "Drafts only" in its header warns.

## F11. Contract drift between parallel missions

**Evidence**
- OL I: "launch prompts named a non-existent flag and non-existent build markers this session".
- D.4: `#100 edits scripts/deploy-harness.*, whose section headings are cut points for build-deploy's MDM generator (rewording a heading breaks the build)`.
- File collisions on `setup-user-claude.*` and `setup-user-config.*` (D.4).
- #111 replaced the heading cut points with body markers (Q6), and 8caa79e is unreviewed (brief).
- `tests/deploy-harness-mdm/` exists, but CI does not run it (F4).

**Root cause:** an interface used by two missions (a flag, a marker, a result-variable prefix such as `AITLIB_*`) lives only in prose. Nothing fails when one side changes it.

**Remedies**
1. Wire `tests/deploy-harness-mdm` into CI (F4.1). It is the contract test for the generator markers.
2. **Pinned-contract file `reference/contracts.txt`** (or a plan section): one line per interface, `<name> <defined-in> <consumed-by...>`. Example: `--no-machine scripts/setup-user-config.sh scripts/aitools`.
3. **`scripts/check-contracts.py`** (pre-commit + CI) greps that each name exists in every listed file.
4. **Unit test:** remove a name from a fixture consumer, and the check fails naming the file.
5. **Process:** launch prompts quote interface names from that file, not from memory (the /delegate skill, "operational learning" element).

## F12. Silent wrong outcomes in setup scripts (logging and summary conformance)

**Evidence** (issues):
- #13: the wrapper exits 0 on installer failure.
- #17: a false "[ok] installed via Homebrew".
- #18: failure detected by grepping output.
- #22: output truncated to 3 lines.
- #23: 32 sites with discarded output.
- #24: `while read; do [ -n "$l" ] && log; done` aborts under `set -e`.
- #25: diagnostics bypass logging.
- #26: ~23 `exit 1` sites with no `write_summary ERROR`; PS1 writes OK after LogError.
- #27b: `if ! bash "$s"; then log_error "... (exit $?)"` always logs exit 0.
- #29: prompts die on EOF.
- #30: malformed log lines, hardcoded `"os":"Windows"`.
- #31: fresh-install ordering.
- #11: config.json corrupted on re-run (critical).
- #19: Linux CI never runs the installer.
- Recurrence: #18 and #27 are the same output-grep pattern on different commands, and #24 says PR A "already fixed this pattern in setup-datadog.sh and setup-python.sh".

**Root cause:** the rules (script-standards.md) are prose, and only a few have a detection layer. The Swiss-cheese RCA in #19 names "Detection: CI has no functional Linux run".

**Remedies**
1. **Lint script `scripts/check-script-shapes.py`** (pre-commit + CI) for the mechanically detectable shapes:
   - `do \[ .* \] && log` (#24, suggested in the issue itself);
   - `if ! <cmd>; then ... \$?` within the then-block (#27b);
   - `exit 1` with no `write_summary ERROR`/`Write-Summary "ERROR"` in the preceding 5 lines (#26a; warn with an allowlist);
   - `| tail -[0-9]` / `| head -[0-9]` / `Select-Object -Last|-First` feeding `log` (#22);
   - `"os":"Windows"` literals (#30);
   - `read -r .* < /dev/tty` outside `read_tty_choice` (#29).
   One rule per #-issue, each with its fixture.
2. **Unit tests `tests/script-shapes/`:** a bad fixture and a good fixture per rule.
3. **CI job `linux-install`** (#19's corrective action, verbatim from the issue):
   - `ubuntu-latest` + `fedora:latest`, running `.github/scripts/linux-install-smoke.sh`;
   - pre-seed `/usr/local/go`, and a config with `googleDrives` before `userRepoPath`;
   - run `aitools install` non-interactively twice;
   - assert: exit 0, zero `[error]` lines, `config.json` parses with all keys, `/usr/local/go/bin/go` survives, each tool is on PATH, and after run 1 `settings.json` holds the profile keys (#31).
   This is the biggest single catch: #11, #12, #13, #14, #31 would each have failed it.
4. **Unit test for the A4 build-deploy change** `tests/build-deploy/test-backup-swap.sh` (isolated HOME, temp dotprofile):
   - a successful build leaves `deploy.bak.<UTC>/` and a new `deploy/`;
   - an injected failure (missing hook file) leaves the old `deploy/` byte-identical;
   - after 6 builds only 5 backups remain.
   Incident #86 is the motivating case (build-deploy `rm -rf`s the real deploy/ and leaves it half-built, F1 of handoff 2026-10-22).

---

## Process friction (no test can catch these)

- **P1. Worktree + PR overhead for records.** Handoffs, plans and mission records went through PRs: #53, #94, #97 (still open: "Mission records only"), #107 (closed), #57/#58/#66. Since 5976553/1af8851 (CLAUDE.md channel exception) these go direct to main. Remedy: a helper `scripts/commit-direct.sh <path>...`. It does `pull --ff-only`, stages only the named paths, commits with `-F`, pushes, and on a non-fast-forward pulls and retries once. Concurrent missions then share main safely without worktrees. Keep worktrees and PRs for code (brief Q1).
- **P2. Review-verdict mechanics.** GitHub refuses `--approve`/`--request-changes` from the PR author account (OL). Verdicts are comments. F3's SHA-stamped verdict line turns that limit into a merge gate.
- **P3. Waiting on CI.** A foreground `sleep` is blocked. Use `gh pr checks <n> --watch --interval 30` or `gh run watch <id>` (OL). Put both in the merge-gate script's `--wait` mode so every agent waits the same way.
- **P4. Context and usage limits stop missions mid-work** (PROFILE-TOOLS at B5, OL I). Commit and push after every batch. Already standing practice; keep it in D-DEL5's text.

## INCIDENT markers (not filed)

- INCIDENT: `.github/workflows/check.yml:15-16` runs CI only for PRs whose base is `main`. A PR based on a stack branch, as #74 and #75 were (handoff D.2), gets no CI on its head. Verified for #74: `gh pr checks 74` returns "no checks reported on the 'feature/user-level-skills' branch", so it merged with zero CI. Most stacked PRs (#76-#92) said "diff includes #N's commit", which means base `main`, so they did get CI. Spec: none says stacked PRs need CI (governance ambiguity).
- INCIDENT: 4 test suites on main are not run by CI (F4). Expected: G16, and the error-handling intent of `script-standards.md` (detection layer). Affected: `.github/workflows/check.yml`.
- INCIDENT: `scripts/check-pre-push.sh:70` uses `[\s]` in an ERE (literal `\` or `s`, not whitespace). Spec: `script-standards.md` "Cross-platform grep portability" (use POSIX classes). Check the `.ps1` twin for parity.
- INCIDENT: the repo allows squash and rebase merges, while A1 (2026-10-26) says merge commits only, and the squash of #71/#73 caused the stack duplication in D.2. Affected: the repo settings (commander).
- INCIDENT: issues #22-#30 and #31 are open while merged PRs #35-#45 claim full or partial fixes, with no issue comment recording what remains (F9). Code state: unknown, not verified here.

## Open questions (with suggested answers)

1. **Does a NEUTRAL CodeQL aggregate count as green for A1?** Suggested: yes, if every `Analyze (*)` job is SUCCESS. Allowlist the name `CodeQL` for NEUTRAL in the merge gate.
2. **Required checks in the ruleset: do it now, during MERGE-ALL?** Suggested: after the last merge. Strict "up to date" during a 19-PR train forces a CI rerun per PR, which A6 already does. Add it in the friction plan as the first follow-up.
3. **Turn on `delete_branch_on_merge`?** Suggested: after #116 merges and the #74/#75 re-land lands (brief Q2 keeps those branches).
4. **Known-failure baseline (F7.3): a check-lib change or a rule?** Suggested: check-lib code plus one line in script-standards.md (protected; written as a version under A2).

## Provenance

- `gh` and `git` commands as listed under "How I checked", run 2026-10-26.
- Raw dumps: `/Users/new-jose/repos/aitools/.scratch/session-mafric/` (bodies.txt, all-issues.txt, prs-summary.txt, runs-summary.txt, fail-<id>.log).
- Not done: the transcript was not read (the brief covers it); the code state behind each open issue (#22-#31) was not verified; Windows behaviour was not observed locally.
