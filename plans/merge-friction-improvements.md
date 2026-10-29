# Merge friction improvements: plan (version 1.1)

**Version:** v1.1 · **Written:** 2026-10-26 (UTC) · **By:** S3-MA-FrictionPlan (v1.0); S3-MA-FrictionReview (v1.1, independent review fixes; verdict in `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MergeAll/S3-MA-FrictionReview-verdict.md`) · delegates of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose · **Decision:** A7 (MERGE-ALL brief: "plan v1.0, plans/merge-friction-improvements.md")

**Intent**: **Purpose**: Give an executing mission an ordered, testable way to
remove the friction this project hit while shipping and merging PRs #50-#116:
checks that were not required or went stale, stacked PRs with no CI, merges at
unreviewed SHAs, test suites CI never ran, CI-only failure classes, checks
that were red by design, the draft-approve-apply round trip, and worktree and
PR overhead. **Scope**: The prioritised friction list with evidence; each
proposed unit test, CI/CD step and check-script step (file, job, command, what
it catches, which past failure it would have caught); the process and rule
changes (versions not drafts, review-after, merge authority, less worktree and
PR overhead); the GitHub settings changes; batches in the plan-execution
format with verification per batch; pinned interfaces; open questions. NOT the
MERGE-ALL merge train itself (`S3-MA-Brief-brief.md`). NOT D-DEL5 and the
sources-of-truth review-after change, which MERGE-ALL writes as its
deliverable 3 (this plan only builds on them). NOT the build-deploy backup
change (A4, MERGE-ALL deliverable 5). NOT the v0.74.0 release (A5).
**Audience**: the mission that executes this plan and its per-batch
delegates; Jose, who owns the GitHub settings changes and reviews protected
files after they are committed (A2).

## 0. Sources and short names

Evidence comes from four v1.0 findings files written by MERGE-ALL research
delegates on 2026-10-26, all in
`.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MergeAll/`:

| Short | File | What it covers |
|---|---|---|
| FI | `S3-MA-FrictionIssues-findings.md` | GitHub issues #7-#32 and #72, the 5 failed runs in the last 200, repo settings and ruleset |
| FP | `S3-MA-FrictionPRs-findings.md` | PR history #50-#116: timelines, verdicts, merge methods, stacks, pairwise conflicts, worktrees |
| FC | `S3-MA-FrictionCI-findings.md` | all 18 failed CI runs, check.yml and the check scripts, probes on a clone of main bc4aad1 |
| FS | `S3-MA-FrictionSessions-findings.md` | the commander's typed prompts (live transcript newest first, plus archived sessions) |

Raw data and the scripts that produced it: `.scratch/session-mafric/`,
`.scratch/session-fricprs/`, `.scratch/session-ma-fci/`,
`.scratch/session-fricsess/` (gitignored; harvested at session end). Reusable
merge tooling already harvested: `harvesting/2026-10-23_session-f486b184-c_merge-check.sh`,
`..._pr-status.sh`, `..._stack-compare.sh`, `..._watch-runs.sh`.

Facts re-checked by this author on main 99740cc (2026-10-26):
- `.github/workflows/check.yml:12-16` is `push: branches: [main]` and `pull_request: branches: [main]`. The jobs are `macos` (line 25), `linux` (225) and `windows` (330). There is no `concurrency` and no `paths-ignore`.
- check.yml names only 8 test entry files: logging (.sh and .ps1), managed-files (.sh and .ps1), and profile test-profile, test-config, test-lib and test-user-init.
- `find tests -name 'test-*'` finds 12 files. Not in CI: `tests/build-package/test-cli.sh`, `tests/deploy-harness/test-deploy-harness.sh`, `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` and `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`.
- `scripts/check-pre-push.sh:70` has `secret_pattern='...)[\s]*[=:]'`.
- Pre-commit step numbers: `check-pre-commit.sh` has steps 1-20, `check-pre-commit.ps1` has 1-16 and 20. `check-pre-push.sh` has 1-10. `check-post-push.sh` has 1-7 and 9-32.
- `git ls-files -s` shows `harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` as 100644.
- Two `*.bak.*` files are tracked under `shared/hooks/`.
- `scripts/aitools-json.pl` and `.ps1` each still contain `DRAFT` once.
- `.claude/rules/sources-of-truth.md:40-42` still reads "Draft the change / Present for review / Wait for approval". D-DEL5 is not yet in the dotprofile `claude/rules/delegation.md`; it has D-DEL1-D-DEL4 only.
- 18 PRs are open (#97-#116 without #99, #107).

v1.1 re-check (S3-MA-FrictionReview, 2026-10-26, against `origin/main` adb61ec):
- 99740cc is a local commit in the main checkout that is not on `origin/main`. The main checkout is ahead 1 and behind 11, so `git pull --ff-only` fails there (see P22). Every fact above still holds on adb61ec, re-checked with `git show origin/main:<path>` and `git grep ... origin/main`.
- 17 PRs are open (#101 merged as adb61ec).
- `gh pr view 108 --json statusCheckRollup,mergeStateStatus`: `mergeStateStatus` is `CLEAN`, and every check dates from 2026-10-23. `gh api repos/nobul-tech/aitools/compare/main...dbcc61a` gives `behind_by: 33`. Without strict required checks, GitHub reports CLEAN for a PR that is far behind main. No `statusCheckRollup` entry carries a commit SHA: the fields are `name, status, conclusion, startedAt, completedAt, detailsUrl, workflowName`.
- CodeQL is GitHub default setup, not a workflow file: `Analyze (actions|javascript-typescript|python)` plus an aggregate `CodeQL` check with an empty `workflowName`.
- Syntax loop probe (`.scratch/session-s3mafrev/syntax-probe.sh`): 89 tracked `.sh` files outside `harvesting/` and `.aitools/` pass `bash -n` (bash 5.3) and `/bin/bash -n` (3.2). Every `.py` passes `py_compile`, and the `.pl` file passes `perl -c`.

## 1. How to execute this plan

- **Sub-agent pattern** (`.claude/rules/plan-execution.md`). The plan touches
  more than 3 code files and two shared libraries (`scripts/check-lib.*`, and
  `scripts/aitools-lib.*` in X4). Every code batch therefore goes to a fresh
  delegate. Its prompt carries:
  - the seven delegation-duty elements (`/delegate` skill);
  - the error-handling rules block from `reference/plan-execution-detail.md`, "Sub-agent prompt template";
  - section 7 ("Pinned interfaces") verbatim.
- **v1.0 is design-level, not verbatim edits.** Open PRs and parallel
  missions move the code, so each batch delegate does three things before it
  applies anything:
  - drafts the exact old/new edits against main as it stands when the batch starts;
  - runs the error-handling audit checklist (`reference/plan-execution-detail.md`) on every block;
  - greps for every pinned name it uses, and stops with a "Contract change" note if one differs.
- **Start after MERGE-ALL.** Do not start until the MERGE-ALL merge train and its post-merge list (brief section 3.2) are done. Batches that edit check.yml would otherwise re-open the conflicts the train resolves (FC Q1, FP F5).
- **Ship per batch** (D-DEL4, D-DEL5):
  - Code and non-channel files: one branch per batch, off `origin/main`, named `<prefix>/friction-<batch id lower case>` (for example `fix/friction-x1`). Open a PR to `main`, commit and push after every batch.
  - Files under the channel exception (`plans/`, handoffs, `relay.md`, project `CLAUDE.md`) go straight to main (CLAUDE.md "Channel exception").
  - Dotprofile files are committed and pushed to its main (N-Q2).
- **Less worktree overhead** (section 5.3): one worktree per mission, not one per batch. Batch branches are created inside it, which is allowed because it is the mission's own worktree. Reviewers do not get worktrees.
- **Merging.** The executing mission merges its own PRs only when the commander authorises it in the launch prompt (D-DEL6, section 5.4). It then merges with `gh pr merge <n> --merge`, after `scripts/pr-merge-gate.sh <n>` passes (batch X2). After each merge it waits for main's CI on the merge SHA and runs the suites the PR touched (A6).
- **Protected files** (sources-of-truth.md table, which includes `.claude/rules/*.md`):
  - The batch writes the new version and commits it with a `Protected-file: <path> v<N>` trailer (section 7.6).
  - The PR body lists them under "Protected files changed (review after)".
  - The commander reviews the diff after (A2, review-after). No pre-write draft.
- **Bash rules for delegates** (packet section 5):
  - simple commands only; scratch scripts for anything longer; Perl, not sed;
  - never run `aitools`, `aitools install`, `setup-user-*`, `deploy-harness` or `build-deploy.sh` against the real HOME;
  - never switch the main checkout's branch; never remove a worktree.

## 2. Prioritised friction list

Each row is ordered by the damage it caused and how cheaply it can be
closed. "Caught" names the batch that closes it (section 6).

| P | Friction | Evidence (abridged; full in the cited finding) | Root cause | Caught by |
|---|---|---|---|---|
| 1 | **No merge gate: checks are not required, and "green" goes stale** | Ruleset 16468370 has only `deletion` and `non_fast_forward`, and the branch is not protected (FI-F1, FC-C5). On 2026-10-26 all open PRs carried checks from 2026-10-23 heads, 20 commits behind main (#97: 125 behind) (FP-F4). Merge settings: `allow_auto_merge`, `allow_update_branch` and `delete_branch_on_merge` false; squash and rebase allowed | The gate was policy only; GitHub ties CLEAN to nothing current | X2, G1, G3 |
| 2 | **Stacked PRs got no CI and merged into stale bases** | #74 (base `fix/registry-paths`) merged 2026-10-22T04:24:16Z, 14 min after its base squash-merged; #75 merged into #74's branch. Both have an empty `statusCheckRollup`, and neither is on main (FP-F1, FC-C6). The trigger is `pull_request: branches: [main]` | Base-filtered CI trigger; `delete_branch_on_merge` false, so no retarget; squash rewrote the base | X3, G1 |
| 3 | **Merged before review, or at an SHA no reviewer saw** | #76/#77 merged 6 min before their first verdict, then fix-forward #84. #79 merged before Review3, then #89. #80 merged after "changes requested" with one unreviewed fix (28e0f5b). #71 (63ce030) and #74 (ed1b75c) were not re-reviewed. 32 PRs have code commits after their last verdict; #111's 8caa79e is unreviewed (FP-F2, FC-C14) | A verdict is free text tied to no SHA; one account authors, reviews and merges, so `--approve` is refused | X2, X12, R1 |
| 4 | **Verdicts cannot gate** | GitHub refuses `--request-changes` from the author account (#79, #80, #81, #86). 8+ verdict formats ("approve with minors", "APPROVE-equivalent", "NON-BLOCKING", ...). Conditions such as "merge after #103" exist only in prose (FP-F3) | No machine-readable verdict | X2, X12, R1 |
| 5 | **Test suites CI never ran** | 4 suites on main are not in check.yml. All 4 are green on main today (macOS, isolated HOME): deploy-harness 45/0, deploy-harness-mdm 30/0, rules-fanout-cursor 78/0 with 1 skip, build-package 32/0 (FC-C2). The MDM generator's heading contract is tested only there (FI-F11) | Wiring a suite into CI is a manual step in three YAML jobs, with no check | X3, X4 |
| 6 | **CI builds nothing and checks a frozen directory** | In run 40415865053 build-deploy logs "No dotprofile found ... skipping deploy build", exits 0, and "Check deploy drift" diffs the frozen `aitools/deploy/` (FC-C1) | Build target moved to the dotprofile (#32); CI steps were not moved; skip = exit 0 | X10 |
| 7 | **CI-only failure classes, relearned one red run at a time** | All 11 failed runs since 2026-10-22 (FC-C4):<br>(a) the `/bin/bash` 3.2 bash-only leg: `<pid>` vs the real pid (39890650263, 39891264259, 39891714493; fixed by dbcc61a);<br>(b) runner default branch `master` (39873612279; f473e55);<br>(c) Windows 8.3/backslash paths (39888735993; c05fec8);<br>(d) the runner appends `exit $LASTEXITCODE` to pwsh steps (39720365900; d977807);<br>(e) Linux pwsh ignores `\x04` through a pty (39719101997, 39719152527; 435a7aa);<br>(f) a batch pushed knowingly red (39859094088, 39861809999, 39861915512). | No local runner matches CI's modes; fixtures re-derive git and path facts per suite; no rule against pushing red | X4, X5, X20, R3 |
| 8 | **Local checks red by design, so red is ignored** | Packet section 4 lists 3 "known pre-existing failures" (pre-commit step 6, pre-push steps 7 and 3). 36 commit bodies since 2026-10-20 cite step 6 (FS-S8). #99's new step-20 FAIL sat beside the "expected" ones while CI showed 7/7 green (FP-F7). #54 skipped pre-push entirely because it was "known red" (FI-F7) | Failures recorded instead of fixed; no expiry | X1, X6 |
| 9 | **Check scripts never run in CI; their .ps1 twins drift** | check.yml runs only `check-hook-parity.py` (FI-F8). `check-pre-commit.ps1` lacks steps 17-19 with no documented exemption (FC-C8). Step 3's `[\s]` bug is bash-only (FC-C8 corrects FI) | Check scripts were written for a human pre-push loop, and the user-state steps were never split from the pure ones | X7a, X7b |
| 10 | **Windows is CI-only and CI runs little of it** | The windows job lacks test-profile, test-config, test-lib and test-user-init (FC-C3, FS-S9). 87 of 245 non-merge commits since 2026-10-20 say "Not run: Windows". Issue #72: PS1 menu cases SKIP on Windows, and a skip counts as a pass (FI-F5) | No Windows machine in the loop; skips are invisible | X11, X4 (`--check` skip rule) |
| 11 | **Draft, approve, apply: two PRs per protected change** | Draft PRs #57, #58, #61, #63, #64, #96 and #102 needed apply PRs #65, #66/#67, #68/#70, #99, #101 and #105. #96 to #99 took about 4 days, and approved rows went stale (#99 held 2 paragraphs; #105 row 8). 118 tracked `*draft*` files sit under handoffs. Commander: "dont call it draft" (2026-03-27), "just write it" (2026-10-22), "i dont like that produced work is often 'draft'" (2026-10-26) (FI-F10, FP-F8, FS-S1) | `sources-of-truth.md` pre-write gate, D-DEL4 "returns drafts", and the /delegate PR skeleton make "draft" the only legal output | R1, R2, X8 (step 23) |
| 12 | **Worktree and PR overhead** | 75-76 worktrees, 11 GB, 17 detached reviewer or probe worktrees. Channel-only PRs #94, #97, #102, #104, #107. 33 branch-sync merges. The commander objected 6 times (transcript lines 5421, 6071, 6494, 6712, 6779, 7264) (FP-F9, FS-S2) | One worktree per delegate and per reviewer; every change through a PR until 2026-10-26; nothing detects a PR that belongs on main | R1, X3 (`pr-hygiene`), X20 (step 12), X21 |
| 13 | **Hand-back and report commits on code PR branches** | 25 "Add S3-... report/review/verdict" commits since 2026-10-20 (FS-S12). They move the reviewed head and re-run 10-30 min of CI; #95 has 24 commits (FP-F10) | Packet section 5 said "outputs in your worktree" before the channel exception | R1, X3 (WARN) |
| 14 | **Main checkout's branch switched; packet lost** | Commander, 2026-10-22T03:45:14Z (line 4106): "why did the branch change here? ... we should have stayed on main". The packet was on branch 0d5bd51 (FS-S7, FP-F11) | Prose-only rule; standing-order-guard has no such check | X9b |
| 15 | **Parallel-mission conflicts and contract drift** | `pairwise.sh`: #106 x #116 conflict in both installers, #112 x #116 in check.yml; five open PRs edit check.yml (FP-F5). Launch prompts named a non-existent flag and non-existent build markers (handoff I, FI-F11) | Every suite is a hand-written YAML hunk; interfaces live in prose | X4, X18 |
| 16 | **Every push pays a 3-OS run, docs included** | The last 24 green runs took 548-1177 s. Channel commits on main between 22:01Z and 23:09Z triggered 7 of 10 full runs. A6 waits on main CI after each merge (FC-C13, FS-S11) | No `paths-ignore`, no `concurrency` | X3 |
| 17 | **Issue tracker and release notes lag the code** | #32 open 18 days after 7aacdef; #22-#31 open while #35-#45 claim fixes; epic #10 checkboxes stale (FI-F9). Last notes commit 075c3da (2026-10-03), at least 47 PRs since (FP-F15, FC-C15) | Prose issue references with no closing keywords; no change record per PR | X15 |
| 18 | **The commander is the merge queue, and merge authority is written in 3 places that disagree** | About 45 PRs batch-merged by hand; 19 waited 3.5 days (FS-S3). A1 ("mission merges") vs D-DEL4 ("never merge") vs packet section 4 (FS-S16) | No single rule names who may merge or push what | R1 (D-DEL6), G1-G3 |
| 19 | **Context spent on hand-backs and re-statements** | 33 hand-backs carried 284,747 chars against the commander's own 59,214 chars; 2 compactions. "restate"/"re-print" 19 times; "im lost here" (840) (FS-S4, FS-S6) | No hand-back budget; questions cite bare labels | R1, R2 |
| 20 | **Silent wrong outcomes in setup scripts** | Issues #11, #13, #17, #18, #22-#31: exit 0 on failure, false OK, truncated logs, `$?` after `if !` (FI-F12). #19: Linux CI never runs the installer | Rules are prose; few detection layers | X16, X17 |
| 21 | **Smaller hazards** | `scripts/githooks/pre-commit` runs build-deploy against the real HOME (FC-C11). `check-pre-commit.sh --fix` step 3 does the same (`bash "$SCRIPT_DIR/build-deploy.sh"` with the real HOME; v1.1). Hooks have no smoke test in CI (FC-C10). Syntax checks skip `packaging/`, `tests/`, `shared/shell/`, the `.pl` file and two `.py` files, and run under bash 5 only (FC-C9). 2 tracked `.bak` files (FS). Stale main checkout gives no warning (FS-S13). Nesting probe has no version (FS-S14). Missions cut by usage limits lose state (FS-S15) | Various | X14, X9a, X3, X1, X22, X19, R1 |
| 22 | **Diverged main checkout blocks the channel exception** (v1.1) | 2026-10-26: the main checkout has 99740cc committed locally but not pushed, and is 11 commits behind `origin/main`. `git pull --ff-only` fails, so under CLAUDE.md "Channel exception" every agent must leave its channel files uncommitted. Other missions' uncommitted edits sit in the same tree (13 modified files) | Commit and push are separate steps, and several agents share one checkout. Nothing warns when local main is ahead of its upstream | X21 (`commit-direct` pushes in the same call), X22 (ahead-of-upstream warning) |

## 3. Proposed unit tests

Each test runs under an isolated HOME and a temp repo, needs no network, and
exits non-zero on any failure. Every one becomes a line in `tests/suites.txt`
(X4), so CI runs it on the listed platforms.

| Test file | Batch | What it asserts | Would have caught |
|---|---|---|---|
| `tests/pr-merge-gate/test-pr-merge-gate.sh` (+ `fixtures/*.json`, stub `gh` on PATH, temp git repo for the merge-tree cases) | X2 | Exit 1 with a named `refuse:` reason for each case:<br>- base not main;<br>- a FAILURE check;<br>- a `REQUIRED_CHECKS` name missing from the rollup (for example only the CodeQL checks present, or an empty rollup, as on #74/#75);<br>- `mergeStateStatus` CLEAN while `compare` reports `behind_by` > 0 (the #108 case: CLEAN, 33 behind);<br>- `mergeStateStatus` BEHIND, UNKNOWN (after the retries) or DIRTY;<br>- no `VERDICT:` line;<br>- a `VERDICT: PASS @ <head>` from an author not in `VERDICT_AUTHORS` (spoofed comment);<br>- a `CHANGES` or `BLOCK` at the head, or newer than the newest PASS;<br>- a verdict at an older SHA followed by a code commit;<br>- a verdict at an older SHA followed by a merge of main whose resolution changes a code file (an evil merge);<br>- `AFTER: #103` while #103 is open;<br>- NEUTRAL on a name not in the allowlist.<br>Exit 0 for: every required check SUCCESS, CLEAN, `behind_by` 0, and a PASS verdict at the head from an allowed author. Also exit 0 for a PASS at an older SHA when the head's tree equals `git merge-tree --write-tree <verdict> <merge-base(head, origin/main)>` outside the channel paths (5.5), which covers channel-only commits and clean merges of main. A verdict posted as a review (`reviews`) counts the same as a comment | #74/#75 stale-base merges; #76/#77, #79, #80, #71, #74 unreviewed merges; #111 8caa79e; stale 10-23 green (#108 CLEAN while 33 behind) |
| `tests/pr-merge-gate/test-pr-merge-gate.ps1` | X2 | The same fixtures against `pr-merge-gate.ps1`; identical reasons and exit codes | .sh/.ps1 parity drift |
| `tests/checks/test-run-suites.sh` | X4 | `run-suites.sh --check` is static and runs no suite, so it can serve as pre-commit step 22. It:<br>- fails naming a `tests/x/test-y.sh` that is not in `suites.txt`;<br>- fails on a `suites.txt` line whose path does not exist;<br>- passes when every suite is listed.<br>`run-suites.sh ci <job>` and `local`, using stub suites:<br>- FAIL a suite whose output has a `SKIP` line without `#<issue>` or `incident #<n>`, even when the suite exits 0;<br>- PASS when every skip names an issue;<br>- FAIL an `XPASS` line.<br>`--changed` selects only the suites whose `sources` globs match the diff. | 4 suites never in CI; #72's silent skips |
| `tests/checks/test-check-test-portability.sh` | X5 | `check-test-portability.py` fires on:<br>- a bare `git init` or `git init --bare` in `tests/`;<br>- `Remove-Item -Path $x` in `scripts/*.ps1`;<br>- a `^`-anchored match on `.ps1` content with no CR strip (warn).<br>A clean fixture passes. | run 39873612279 (master); 9923a3c/161edd0 (`-LiteralPath`); CRLF misses (handoff I) |
| `tests/lib/test-test-helpers.sh` (+ `.ps1`) | X5 | `t_git_init_main` creates branch `main` with `GIT_CONFIG_GLOBAL` set to an empty file. `t_norm_tmp` maps `.tmp.40736` to `.tmp.<pid>`. `t_norm_path` makes `C:\Users\RUNNER~1\...` and its POSIX form compare equal (Git Bash). `t_strip_cr` removes `\r` | runs 39890650263/39891264259/39891714493, 39873612279, 39888735993 |
| `tests/checks/test-known-failures.sh` | X6 | A listed, unexpired step reports `KNOWN` and exit 0. An expired entry reports FAIL and exit 1. An unlisted failure reports FAIL and exit 1. An entry with an expiry more than 14 days after its `added` date is rejected (FAIL) | step 6/3/7 folklore; #99 step-20 FAIL hidden among "known" ones |
| `tests/checks/test-secret-pattern.sh` | X1 | Step 3's pattern, bash and pwsh, flags `+token = abc` and `+api_key: x`; does not flag `+tokens: 3` or `+  secrets_found=...` | #134 `[\s]` false positives / misses |
| `tests/checks/test-check-parity.sh` | X7b | Step numbers in each `check-*.sh`/`.ps1` pair match, except numbers listed on a `# parity-exempt: <n> <reason>` header line | `check-pre-commit.ps1` missing 17-19 |
| `tests/checks/test-ci-mode.sh` | X7a | `check-pre-commit.sh --ci` in a temp repo reports a planted 100644 `.sh` (step 6) and a planted dead path (step 20), and SKIPs every step that needs staged files or a dotprofile | standing FAILs reaching CI unseen |
| `tests/checks/test-draft-language.sh` (+ `.ps1`) | X8 | Step 23 FAILs a governed file containing "Draft the change", "returns drafts" or "ships as a draft". The fixture list includes a `.cursor/rules/*.mdc` file, because `.cursor/rules/sources-of-truth.mdc:33-34` carries the same pre-write gate (v1.1), and a new `.md` under `plans/` or handoffs whose first 10 lines say "draft for approval" or have no `**Version:**`. It PASSes an allowlisted line and a file with `**Version:** v1.0` | the draft-language source lines (sources-of-truth.md:40, delegation.md:96, delegate SKILL.md:89-99) coming back |
| `tests/checks/test-channel-only.sh` | X20 | Pre-push step 12 WARNs on a branch whose diff against `origin/main` is only `.aitools/channel/**`, `plans/**` or `CLAUDE.md`; PASSes on a mixed branch; SKIPs on `main` | channel-only PRs #94, #97, #102, #104, #107 |
| `tests/hooks/test-hooks.sh` | X9a | Every hook in the hooks manifest (`shared/hooks/`) exits 0 on a minimal valid input for its event, with no `unbound variable` on stderr. standing-order-guard exits 2 on each violation form in hook-rollout.md and 0 on each exemption | I12 (hook crashed on every call although `bash -n` passed) |
| `tests/hooks/test-standing-order-guard-mainswitch.sh` | X9b | In the primary worktree of a temp repo with `git config aitools.pinMainCheckout true`, `git switch -c x` and `git checkout <branch>` are logged (observe) and exit 2 (enforce). These exit 0:<br>- the same commands in a linked worktree;<br>- the same commands in a primary worktree without the opt-in;<br>- `git checkout -- file`.<br>A `git -C <dir>` command is judged against `<dir>`, not the hook's cwd | 2026-10-22 branch switch (line 4106) |
| `tests/deploy-build/test-check-deploy-build.sh` | X10a | `check-deploy-build.sh --fixture tests/fixtures/dotprofile` builds `deploy/` in a temp copy and dry-runs the resolver consumers. The section headings `build-deploy.sh` cuts on live in `scripts/deploy-harness.sh`, not in the dotprofile (deploy-paths.md, `extract_span`). The heading case therefore renames one heading in a `git archive HEAD` copy of the aitools tree and runs that copy's `check-deploy-build.sh`, which must fail. A missing dotprofile with `--require-dotprofile` exits 1 | CI's no-op build (run 40415865053); MDM heading contract (handoff D.4) |
| `tests/review-gate/test-review-verdict.sh` | X12 | `review-verdict.sh` reads a fixture PR JSON with the same verdict rules as X2. It passes on `VERDICT: PASS @ <head sha7>` from an allowed author. It fails on:<br>- a missing verdict;<br>- CHANGES or BLOCK;<br>- an older SHA followed by code commits;<br>- a PASS from an author outside `VERDICT_AUTHORS` (on a public repo anyone can comment).<br>It never evaluates the comment body: a body of `$(touch /tmp/x)` creates no file | #111 8caa79e; comment-injection risk (FI-F3 yellow flag) |
| `tests/checks/test-issue-sync-audit.sh` | X15 | With a stub `gh`, the script lists an open issue cited by a merged PR with "fix" nearby, and an epic checklist item whose issue is closed | #32 open 18 days; epic #10 stale |
| `tests/script-shapes/test-check-script-shapes.sh` | X16 | One bad and one good fixture per rule: #24 `do [ ... ] && log`, #27b `$?` inside `if !` then-block, #26a `exit 1` without `write_summary ERROR` in the 5 preceding lines (warn), #22 `tail -N` / `Select-Object -Last` into `log`, #30 `"os":"Windows"`, #29 `read -r ... < /dev/tty` outside `read_tty_choice` | issues #22, #24, #26, #27, #29, #30 |
| `tests/contracts/test-check-contracts.sh` | X18 | Removing a pinned name from one fixture consumer fails `check-contracts.py`, naming the file and the name | non-existent flag/markers in launch prompts (handoff I) |
| `tests/checks/test-nesting-probe-age.sh` | X19 | With a stub `claude --version`: same version as the recorded probe gives PASS, a different one gives WARN, no record gives WARN | incident #139 re-asks (FS-S14) |
| `tests/hooks/test-stale-checkout.sh` | X22 | In a temp primary worktree:<br>- one commit behind its fetched upstream prints the "behind" warning;<br>- one unpushed commit ahead prints the "ahead, unpushed" warning (v1.1, P22);<br>- both at once prints "diverged";<br>- up to date prints nothing.<br>A linked worktree prints nothing | 105-commits-behind main checkout (handoff 2026-10-22 A) |
| `tests/worktree/test-worktree-list-safe.sh` | X21 | Lists a merged worktree and its ignored `.scratch/x.sh`; never lists an unmerged one as removable; removes nothing (the script has no remove mode) | S3-Hooks scripts lost with a removed worktree (handoff I) |

## 4. Proposed CI/CD steps and check-script steps

### 4.1 CI/CD (`.github/workflows/`)

| Workflow / job | Batch | Command or config | What it catches | Would have caught |
|---|---|---|---|---|
| check.yml `on:` | X3 | `pull_request:` with no `branches` filter; `push: branches: [main]` with `paths-ignore: ['.aitools/channel/**', 'plans/**', 'harvesting/**']` (push only; never on `pull_request` while checks are required, FC-C13) | PRs on any base get CI; docs-only pushes do not pay 10 min | #74/#75 zero CI; 7 of 10 main runs 22:01Z-23:09Z |
| check.yml `concurrency:` | X3 | `group: ci-${{ github.workflow }}-${{ github.event.pull_request.number \|\| github.sha }}`, `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` | Superseded PR runs; never cancels a main run | 25-33 min PR runs under load (FS-S11) |
| check.yml job `pr-hygiene` (ubuntu, pull_request only, seconds) | X3, X15 | Step "base is main": `if [ "$BASE_REF" != "main" ]; then echo "::error::base is $BASE_REF; retarget to main"; exit 1; fi` (`BASE_REF: ${{ github.base_ref }}` passed through `env:`, never interpolated into `run:`). Step "channel-only": `bash scripts/check-channel-only.sh --ci origin/main` (error: "commit these to main under the channel exception and close the PR"). Step "channel files in a code PR": WARN annotation. X15 adds "release note line" and "closing keywords" (WARN first) | Stacked bases; channel-only PRs; hand-back commits on code branches | #74/#75; #94, #97, #102, #104, #107; 25 report commits |
| check.yml all three jobs: "Test suites" | X3 then X4 | X3: one step per missing suite: `bash tests/deploy-harness/test-deploy-harness.sh`, `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`, `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`, `bash tests/build-package/test-cli.sh` (macos, linux; windows in `windows-extended`). X4 replaces every suite step with `bash tests/run-suites.sh ci <macos\|linux\|windows>` plus `bash tests/run-suites.sh --check` on linux | Unwired suites; YAML conflicts between PRs | FI-F4/FP-F6/FC-C2; #112 x #116 check.yml conflict |
| check.yml all jobs, first step | X3 | `git config --global init.defaultBranch main` (belt and braces; the X5 helpers make tests pass without it) | CI default-branch class | run 39873612279 |
| check.yml syntax steps | X3 | Loops driven by `git ls-files`: `'*.sh' ':!harvesting' ':!.aitools'` through `bash -n` and, on macOS, `/bin/bash -n`; `'*.ps1' ':!harvesting'` through the parser, printing the parser messages (not `2>/dev/null`); `'*.py'` through `py_compile`; `'*.pl'` through `perl -c` | Syntax errors in `packaging/`, `tests/`, `shared/shell/`, the `.pl` file and two `.py` files; bash 3.2 parse errors. `/bin/bash -n` cannot catch bash-4-only constructs that fail only at run time (`declare -A`, `mapfile`/`readarray`, `${v,,}`, `${v^^}`, `&>>`, `;;&`, `coproc`). X5's portability lint gets a rule for these, applied to scripts that must run under 3.2 (v1.1) | FC-C9 (re-probed in v1.1: 89 `.sh` files, all pass both shells, so the step lands green) |
| check.yml job `checks` (ubuntu; windows via `pwsh -File`) | X7a, X7b | Isolated `HOME`, git identity set; `bash scripts/check-pre-commit.sh --ci` (steps 6, 14, 15, 16, 17, 19, 20 and new 22-26 over all tracked files) | Check-script FAILs that only a local run would see | #99 step-20 FAIL beside a 7/7 green CI; step-16 parity drift (#71) |
| check.yml "Deploy build" (replaces "Build deploy scripts" and "Check deploy drift") | X10b | `bash scripts/check-deploy-build.sh --fixture tests/fixtures/dotprofile` (macos, linux; windows via Git Bash) | The MDM generator actually builds and its resolver consumers dry-run | run 40415865053 no-op; heading cut points (handoff D.4) |
| check.yml job `windows-extended` (windows, `shell: bash`) | X11 | `bash tests/run-suites.sh ci windows-extended` (test-profile, test-config, test-lib, test-user-init, test-adopt-push, deploy-harness). Ships with `continue-on-error: true` (observe); after one green run on main, remove it and make the job required (enforce) | Windows path-form and pwsh-parity bugs before users hit them | run 39888735993's class in the profile suites; issue #72 |
| check.yml hooks step (all three jobs) | X9a | `bash tests/hooks/test-hooks.sh` (via `run-suites.sh` once X4 lands) | Hooks crashing at runtime | I12 |
| `.github/workflows/review-gate.yml` job `review-verdict` | X12 | `on: pull_request: [opened, synchronize, reopened]` and `issue_comment: [created, edited]`. The job runs only `if: github.event_name == 'pull_request' \|\| github.event.issue.pull_request`, because `issue_comment` also fires on plain issues. `permissions: pull-requests: read, statuses: write, contents: read`. It runs `bash .github/scripts/review-verdict.sh "$PR"` with `PR` from `env:` (`github.event.pull_request.number \|\| github.event.issue.number`). It counts only verdicts whose author is in `VERDICT_AUTHORS` (default `nobul-jose`), because anyone can comment on a public repo. Posts commit status `review/verdict` on the head SHA (success only for `VERDICT: PASS @ <head sha7+>`, or a PASS at an older SHA whose later commits are channel-only or a merge of origin/main). The comment body is read as data (`gh api ... --jq`), never interpolated into `run:` | Merge at an unreviewed head | #76/#77, #79, #80, #111 |
| check.yml job `linux-install` (matrix `ubuntu-24.04`, `ubuntu-22.04`: the supported Linux list in cross-platform.md "Supported platforms and environments"; v1.0's `fedora:latest` is not a supported platform; plus one `AITOOLS_ENVIRONMENT=claude-code-web` case on 24.04) | X17 | `bash .github/scripts/linux-install-smoke.sh`: pre-seed `/usr/local/go` and a config with `googleDrives` before `userRepoPath`; `aitools install` non-interactive, twice; assert exit 0, zero `[error]` lines, config.json parses with all keys, `/usr/local/go/bin/go` survives, each tool on PATH, `settings.json` has the profile keys after run 1 | Installer regressions on Linux | issues #11, #12, #13, #14, #19, #31 |
| `.github/pull_request_template.md` | X15 | Sections: Summary; Why; Changes; Verification; Not run; Protected files changed (review after); `Fixes #N` / `Part of #N: <what remains>`; `Release note: <text \| none>` | Prose issue refs; missing release-note text | F9/F15 |

### 4.2 Check-script steps (`scripts/check-*.sh` and `.ps1`, identical numbers)

Step numbers are reserved here so parallel PRs do not collide (FI-F4 note).
Pre-commit 21 is reserved for the #74 re-land.

| Script | Step | Batch | Check | Level | Would have caught |
|---|---|---|---|---|---|
| check-pre-commit | 22 | X8 | `bash tests/run-suites.sh --check`: every `tests/**/test-*` listed; no un-ticketed SKIP | FAIL | 4 unwired suites; #72 skip |
| check-pre-commit | 23 | X8 | Draft language: governed files must not match `-i -E "draft the change\|returns drafts\|drafts? awaiting approval\|do not write it yet\|ships as a draft\|drafts? for (approval\|review)"`. The governed files are `.claude/rules/*.md`, `.cursor/rules/*.mdc` (v1.1), `shared/rules/*.md`, `shared/skills/*/SKILL.md` (including `mission-packet-template.md`), `.claude/skills/*/SKILL.md`, `CLAUDE.md`, `shared/claude-shared.md`, and the dotprofile `claude/rules/*.md` and `claude/CLAUDE.md` when present. "Present for review" is a WARN, not a FAIL, because `glossary.md:144` uses it for the glossary skill's own process. Allowlist in `scripts/check-draft-language-allow.txt` (`path\|text\|reason`). Newly added `.md` under `plans/` or `.aitools/channel/handoffs/` must have a `**Version:**` line and no "draft"/"for approval" in its first 10 lines | FAIL for governed files; WARN for new plans/handoffs | FI-F10 sources; FS-S1 |
| check-pre-commit | 24 | X8 | `python3 scripts/check-test-portability.py` (rules in X5) | FAIL (CR-strip rule WARN) | runs 39873612279; `-LiteralPath` fixes |
| check-pre-commit | 25 | X16 | `python3 scripts/check-script-shapes.py` (rules in X16; allowlist `scripts/check-script-shapes-allow.txt`) | FAIL (rule #26a WARN) | #22, #24, #26, #27b, #29, #30 |
| check-pre-commit | 26 | X8 | `git ls-files` must not list `*.bak.<YYYY>-*` | FAIL | the 2 tracked hook backups |
| check-pre-commit | 27 | X18 | `python3 scripts/check-contracts.py` against `reference/contracts.txt` | FAIL | launch-prompt contract drift |
| check-pre-push | 3 (fix) | X1 | `[\s]` to `[[:space:]]` in the `.sh` (the `.ps1` `\s` is already correct, FC-C8) | — | #134 |
| check-pre-push | 7 (refactor) | X10b | Calls `scripts/check-deploy-build.sh` with a `git archive HEAD` copy of the real dotprofile, then diffs against its committed `deploy/` | FAIL | as today, one implementation shared with CI |
| check-pre-push | 11 | X20 | `bash tests/run-suites.sh local --changed origin/main`. It runs, in every mode CI uses on this platform, the suites whose sources the push touches, and all suites when `scripts/aitools-lib.*` or `tests/lib/*` changed. The modes include `/bin/bash` 3.2 `--bash-only` on macOS. It runs with `GIT_CONFIG_GLOBAL` set to an empty file and `GIT_CONFIG_NOSYSTEM=1` | FAIL | classes a, b, f before the push |
| check-pre-push | 12 | X20 | `bash scripts/check-channel-only.sh origin/main` on a non-main branch | WARN | channel-only PRs |
| check-pre-push | 13 | X15 | Branch touches `scripts/`, `shared/` or `.github/` and no commit or PR body has `Release note:` | WARN | FP-F15 |
| check-post-push | 33 | X19 | Claude Code version vs the version recorded with the nesting probe in `reference/tool-ops-claude-code.md` | WARN | #139 re-asks |
| check-post-push | 34 | X19 | `gh api repos/nobul-tech/aitools`: WARN when `allow_squash_merge` or `allow_rebase_merge` is true; WARN when the ruleset lacks required checks (after G3) | WARN | F14 squash/merge mix |

## 5. Process and rule changes

### 5.1 Versions, not drafts: where it lives and how it is steered

The commander asked: "how do we document and steer behavior here? in the
/delegate skill or delegation rule, or in CLAUDE.md file? i want it across all
projects". A2 answered "User rule + skill; review after". This plan keeps
that and adds the layers that make it hold, because a rule alone does not
(channel CLAUDE.md: "Rules don't hold when it feels easy").

| Layer | Where (user scope unless noted) | Text or mechanism | Owner |
|---|---|---|---|
| Prevention, delegates | Dotprofile `claude/rules/delegation.md` (deployed to `~/.claude/rules/delegation.md`), decision **D-DEL5** | "Work products are versions (`**Version:** v1.0`, then v1.1 ...), written at their real target path and committed. A change to a version is a new version with a one-line changelog. Never call output a draft." Also rewrite D-DEL4's "Otherwise it returns drafts" to "writes the version and lists it under Protected files changed (review after)" | MERGE-ALL deliverable 3 |
| Prevention, the words delegates copy | `shared/skills/delegate/SKILL.md`: prompt skeleton, PR body section rename, lines 89-99 and 250 | Section "Protected-file drafts awaiting approval" becomes "Protected files changed (review after)" | MERGE-ALL deliverable 3 |
| Prevention, main session (not a delegate) | Dotprofile `claude/CLAUDE.md` and its fallback `shared/claude-shared.md` (Template sync rule), "Writing & Email Style" | One line: "Produced documents and changes are versions (v1.0, v1.1), never drafts; see delegation.md D-DEL5." | R2 (this plan) |
| Prevention, protected files | `.claude/rules/sources-of-truth.md` "The rule" | Write the version, commit it with a `Protected-file:` trailer, the commander reviews after (A2) | MERGE-ALL deliverable 3 |
| Prevention, Cursor and the other "present for review" sites (v1.1) | `.cursor/rules/sources-of-truth.mdc:33-34` has the same "Draft the change / Present for review" gate. "Present for review" also appears in `.claude/rules/tool-lifecycle.md:93`, `.cursor/rules/tool-lifecycle.mdc:44,54` and `shared/skills/tool-adopt/SKILL.md:156,190` | The same review-after text. If deliverable 3 changes only the `.claude` copy, Cursor agents keep the pre-write gate and the two rule sets disagree | MERGE-ALL deliverable 3 if it is still open, else R1 |
| Detection | Pre-commit step 23 (4.2) and `tests/checks/test-draft-language.sh` | Old wording returning in a governed file fails | X8 |
| Detection, prompts | `delegation-duty-guard.sh`, element 9 (observe mode, hook-rollout.md) | WARN when a delegation prompt contains `draft` outside a quoted path | R1 |
| Audit | `scripts/protected-diff.sh <since-ref>` (+ `.ps1`) | Lists every protected path changed since a ref, with commit, PR and `Protected-file:` trailer, so review-after is one page | X8 |
| Clean-up | `scripts/aitools-json.pl` and `.ps1` | Remove the `DRAFT` wording (handoff G2) | X1 |

**Suggested answer to the commander's question:** all three, each for its own
audience. The rule (D-DEL5) and the skill steer delegates. One line in the
user CLAUDE.md steers the main session, which is not a delegate, so no
delegation rule is in force for it. A check step catches the old words when
they return.

### 5.2 Review-after for protected files (A2)

- The commit that changes a protected file carries one trailer line per file: `Protected-file: <path> v<N>`.
- The PR body lists the files under "Protected files changed (review after)". Channel-exception commits carry the trailer too.
- `git log --grep "Protected-file:" <since>..` or `scripts/protected-diff.sh` gives the commander his review list. The RELEASE orchestrator includes it in the release notes "Documentation" table.
- A change the commander rejects becomes a new version (v<N+1>). History is never rewritten.

### 5.3 Less worktree and PR overhead (commander: "i dont like the overhead of worktrees/prs")

Proposed, each a rule line in the /delegate skill and packet template (R1):

1. **Non-code goes to main.** This already applies to plans, handoffs, relay and project CLAUDE.md (B2). The `pr-hygiene` job and pre-push step 12 detect the misses.
2. **Hand-backs, reports and verdict copies go to main**, in their own commit under the channel exception, never on a code branch (FP-F10, FS-S12). The verdict itself is a `gh pr comment`.
3. **One worktree per mission**, not per batch: the mission creates each batch branch inside its own worktree. This saves about one worktree per batch (75 today).
4. **Reviewers get no worktree.** They read with `gh pr diff <n>`, `git show <sha>:<path>` and `git diff <a>..<b>`. A reviewer that must run tests extracts the tree with `git archive <sha> | tar -x -C <scratch>/<name>` (#74's reviewer did this).
5. **Small direct-to-main helper** `scripts/commit-direct.sh` / `.ps1` (X21, FI-P1). It:
   - takes `<msg-file> <path>...`;
   - refuses any path outside the channel-exception list;
   - runs `pull --ff-only`, stages only the named paths, commits with `-F` and pushes;
   - on a non-fast-forward rejection, pulls with `--ff-only` and retries once, then stops and reports.
6. **Worktree listing, never removal by agents.** `scripts/worktree-list-safe.sh` / `.ps1` (X21) lists the worktrees whose branch is merged into `origin/main`, with their untracked and ignored files, so the commander can decide. Removing worktrees stays his decision (packet section 5).
7. **Keep PRs for code**, because CI on the PR is the merge gate (brief Q1). Reduce their cost instead:
   - the merge gate (X2) and update-branch;
   - `concurrency` and `paths-ignore` (X3);
   - one suite list (X4), so PRs stop conflicting in check.yml.

### 5.4 Merge authority, D-DEL6 (FS-S16)

Proposed text for the dotprofile `claude/rules/delegation.md`, recording A1, B2
and C as its sources:

> **D-DEL6 Merge authority.** Delegates never merge by default. An orchestrator
> whose launch prompt carries the commander's merge authorisation merges PRs
> with merge commits only (`gh pr merge <n> --merge`), one at a time, in the
> stated order, only after `scripts/pr-merge-gate.sh <n>` passes (every
> check green on the head SHA, `mergeStateStatus` CLEAN, a `VERDICT: PASS`
> at the head SHA), and after each merge waits for main's CI on the merge SHA
> and runs the suites the PR touched. When every file in `git diff --name-only
> <merge>^1 <merge>` matches the push `paths-ignore` list, no main run is
> expected: the orchestrator records "no CI expected (paths-ignore)" instead of
> waiting. Otherwise it polls `gh run list --commit <merge> --workflow CI` until
> a run appears, at most 5 polls, each a `gh run watch` or `--watch` call and
> never a bare sleep, and a missing run is an error. Any agent pushes channel-exception
> paths to main. Dotprofile writes go to the dotprofile's main; a push from
> another branch is an ERROR (C, #165). Tags only on the commander's order
> (A5).

### 5.5 Verdicts that gate (FP-F3)

- **Format.** The first line of every review comment is `VERDICT: PASS @ <sha7+>`, `VERDICT: CHANGES @ <sha7+>` or `VERDICT: BLOCK @ <sha7+>`. An optional second line is `AFTER: #<n>[,#<n>]`. The text below those lines is free.
- **Where it is defined.** The /delegate skill's reviewer section (R1) and section 7.3.
- **What reads it.** `pr-merge-gate.sh` (X2) and `review-verdict` (X12).
- **Who may post it (v1.1).** Only authors in `VERDICT_AUTHORS` (default `nobul-jose`; agents and the commander share that account). The repo is public, so any GitHub user can post a comment that starts `VERDICT: PASS`.
- **Where it is read from.** Both PR comments (`gh pr comment`, the current practice) and review bodies (`gh pr review --comment`; packet section 3 names `gh pr review`).
- **Precedence.** A `CHANGES` or `BLOCK` at the head, or one newer than the newest PASS, refuses. Otherwise the newest PASS decides.
- **"Later commits are channel-only or a merge of main"** has one definition. Let `M = git merge-base <head> origin/main`, the newest main the head contains, and compute `T = git merge-tree --write-tree <verdict sha> <M>` (git 2.38 or later; 2.54 on the Mac). Using `M` rather than `origin/main` keeps newer main commits that the head never merged out of the diff. The `behind_by` refusal covers those. The head passes when `git diff --name-only T <head>` lists only channel paths (section 7.9). A conflicted merge-tree (exit 1) refuses. A per-commit file list cannot do this job: it counts every file a merge of main brings in, and it misses a merge resolution that edits code.
- **No labels.** Labels need a second moving part (FP's label reset on push). The SHA in the verdict already goes stale by itself when the head moves.

### 5.6 Other rule lines

| Change | Where | Batch |
|---|---|---|
| "A pushed commit keeps CI green. A batch that must push red carries `CI: red-expected (<suite> <n> failing, fixed by <batch/PR>)` in its body. A case that cannot pass yet is `xfail <incident>` in its suite; an XPASS fails." (FC-C12, FS-S10) | `.claude/rules/script-standards.md` (new "Verification" section, protected) | R3 |
| Known-failures file: format, 14-day maximum expiry, one line per entry; the packet's prose list goes away (section 7.5) | `.claude/rules/script-standards.md` "Check script logging" | R3 |
| CI class d (pwsh steps that expect a non-zero native exit end with `exit 0` and a comment) and class e (pty cases run only where users reach them; each skip names its issue) | `reference/cross-platform-detail.md` (new "CI runner behaviour" section) | R3 |
| `tests/run-suites.sh` as a bash-only test driver (Git Bash is the managed bash on Windows) | `.claude/rules/cross-platform.md` "OS guard exemptions" row | R3 |
| MAINSWITCH row, observe | `.claude/rules/hook-rollout.md` enforcement table | X9b |
| Hand-back budget: the final message is at most 25 lines with the report path on line 1, and everything else goes in the report file (FS-S4) | /delegate "The delegate owes back", plus `delegation-duty-guard.sh` element 8 (observe) | R1 |
| Mission defaults: unless told otherwise a mission is an orchestrator. It carries the latest handoff's OL and the packet, has every delegate read all rules, asks open questions each with a suggested answer, writes versions, ships per D-DEL4, and keeps a state file (`<MF>/<name>/<prefix>-state.md`, v1.N, committed to main after each batch) (FS-S5, FS-S15). The packet moves into the skill as a template | /delegate SKILL.md "Mission defaults"; `shared/skills/delegate/mission-packet-template.md` | R1 |
| Questions are self-contained: restate the subject in plain words, quote the text it would change, give a suggested answer; never a bare label ("Q1c", "row 3 of 96") (FS-S6) | Dotprofile `claude/CLAUDE.md` / `shared/claude-shared.md`, UCI "Suggest answers with questions" | R2 |
| Probes are recorded as procedure plus a dated, versioned result (FS-S14) | `/tool-ops` skill text | R1 |

## 6. Batches

Each batch is 2-3 files plus its test (UCI "Smaller batches"). "After" lists
what must be on main first. Every code batch's verification includes:
- `bash -n` (and `/bin/bash -n` on macOS) on each touched `.sh`;
- the pwsh parser on each touched `.ps1`;
- the batch's new test;
- `bash scripts/check-pre-commit.sh` and `bash scripts/check-pre-push.sh` from the worktree. Until X1 and the A4 rebuild land, record step 7 as the only expected FAIL.

The ✱ marks batches that touch a shared library: a fresh delegate is mandatory (plan-execution.md).

### Wave 1: cheap, verified green today (start right after MERGE-ALL)

**X1. Fix the standing FAILs and stray files.** After: none.
- Files:
  - mode of `harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` (`git update-index --chmod=+x`);
  - `scripts/check-pre-push.sh` (line 70: `[\s]` to `[[:space:]]`);
  - `git rm` of the two tracked `shared/hooks/*.bak.2026-06-21T*` files;
  - `scripts/aitools-json.pl` and `.ps1` (remove the `DRAFT` wording). The word sits inside the files' intent statements (`aitools-json.pl:4` and `.ps1:3`: "Intent (DRAFT, awaiting commander approval)"), which are protected. The commit therefore carries `Protected-file:` trailers, and whether the commander approved that intent text is unknown (open question 11);
  - new `tests/checks/test-secret-pattern.sh`.
- Verify:
  - `git ls-files -s` shows 100755;
  - pre-commit step 6 PASS;
  - pre-push step 3 PASS on a diff containing `tokens: 3`;
  - the test passes;
  - `perl -c scripts/aitools-json.pl`.
- Done when pre-commit reports 0 FAIL on a clean main. Pre-push step 7 stays the only FAIL until the A4 rebuild.

**X2. Merge gate script.** After: none. Build it from the harvested `merge-check.sh` and `pr-status.sh`.
- Files:
  - `scripts/pr-merge-gate.sh`, `scripts/pr-merge-gate.ps1`;
  - `tests/pr-merge-gate/test-pr-merge-gate.sh` plus `fixtures/`;
  - `.ps1` test twin.
- Behaviour (interface 7.1):
  1. `gh pr view <n> --json baseRefName,headRefOid,mergeStateStatus,statusCheckRollup,comments,reviews,commits,state`. Then `gh api repos/<repo>/compare/main...<headRefOid> --jq .behind_by`, and `git fetch origin main pull/<n>/head` for the merge-tree test (5.5).
  2. Refuse with `refuse: <reason>` (exit 1) on the first failed condition:
     - the PR is not open, or its base is not main;
     - a name in `REQUIRED_CHECKS` (default `macos,linux,windows`; later batches add theirs) is missing from the rollup. Without this, an empty or partial rollup passes "no check failed" (#74/#75 had an empty rollup);
     - any check is not SUCCESS. NEUTRAL or SKIPPED passes only for names in `ALLOW_NEUTRAL=CodeQL`, and only when every `Analyze (*)` check is SUCCESS;
     - `behind_by` > 0 (v1.1). GitHub reports CLEAN for a PR far behind main unless strict required checks are on: #108 was CLEAN while 33 behind (section 0). `--update` updates the branch, waits for the new run, then re-checks;
     - `mergeStateStatus` is not CLEAN (UNKNOWN: re-query up to 5 times inside the `--wait` loop, never a bare sleep in a Bash tool call);
     - the verdict rules of 5.5 fail (allowed author, precedence, merge-tree definition);
     - an `AFTER:` PR that is not merged.
     v1.0 also had "any check ran on a SHA other than `headRefOid`". It is dropped because `statusCheckRollup` carries no SHA and always describes the head commit. Staleness against main is the `behind_by` condition.
  3. `--wait` runs `gh pr checks <n> --watch --interval 30` first.
  4. `--update` runs `gh pr update-branch <n>` first. Whether this needs G1 `allow_update_branch` is unverified: the API docs describe that setting as the "always suggest updating" button. The batch tests it on one PR. The update merges main into the branch, so the verdict then passes only through the merge-tree rule (5.5).
- Error handling: every `gh` call's exit code is checked, and an empty JSON field is a refusal, never a pass. Exit codes: 0 allow, 1 refuse, 2 usage or `gh` failure.
- Verify: both test files pass; `bash scripts/pr-merge-gate.sh <a merged PR>` refuses with "not open".
- Done when the executing mission's merge loop calls it before every `gh pr merge --merge`.

**X3. CI triggers, `pr-hygiene`, cost controls, the 4 missing suites, wide syntax loops.** After: MERGE-ALL done (check.yml stable).
- Files: `.github/workflows/check.yml`; new `scripts/check-channel-only.sh` (shared with X20); `tests/checks/test-channel-only.sh`.
- Changes: everything in 4.1 marked X3.
- Error handling in YAML:
  - `${{ }}` values go through `env:`, never into `run:` text;
  - a `pwsh` step expecting a non-zero native exit ends with `exit 0` and a comment (class d).
- Verify:
  - the PR's own run is green on all three jobs;
  - a throwaway PR based on a non-main branch shows `pr-hygiene` red;
  - a channel-only push to main starts no CI run (`gh run list --commit <sha>` is empty).
- Done when the 4 suites run in CI and `pr-hygiene` exists.
- Then commander step G2 (required checks) becomes possible.

### Wave 2: one suite list, test helpers, known failures

**X4. `tests/suites.txt` and `tests/run-suites.sh`.** After: X3.
- Files: `tests/suites.txt`, `tests/run-suites.sh`, `tests/checks/test-run-suites.sh`; then `.github/workflows/check.yml` (suite steps collapse into one step per job).
- Behaviour (interface 7.2):
  - Modes: `ci <job>`, `local [--changed <ref>]`, `--check`.
  - Each suite runs in every mode its line lists.
  - Prints `PASS|FAIL|SKIP <suite> <mode>` and a summary table; exits 1 on any FAIL.
  - `--check` is static (v1.1): it fails on an unlisted `tests/**/test-*` and on a listed path that does not exist, and runs no suite. Pre-commit step 22 calls it on every commit, so it must take seconds.
  - The run modes (`ci`, `local`) fail a suite whose output has a SKIP line without `#<n>` or `incident #<n>`, or an XPASS line, even when the suite exits 0.
- Verify:
  - `bash tests/run-suites.sh ci macos` gives the same pass counts as the individual steps;
  - `/bin/bash tests/run-suites.sh --check` passes;
  - CI is green.
- Done when check.yml has no per-suite steps left.

**X5. Shared test helpers and the portability lint.** After: X4.
- Files: `tests/lib/test-helpers.sh` and `.ps1`, `scripts/check-test-portability.py`, `tests/checks/test-check-test-portability.sh`, `tests/lib/test-test-helpers.sh`.
- Helpers (interface 7.4):
  - `t_git_init_main <dir> [--bare]`;
  - `t_norm_tmp`;
  - `t_norm_path <path>` (Git Bash: `cygpath -m`, then the long form);
  - `t_strip_cr <file>`.
  The PS1 twins are `T-GitInitMain`, `T-NormTmp`, `T-NormPath` and `T-StripCr`.
- Lint rules: as in the section 3 table.
- Verify: both tests pass; `python3 scripts/check-test-portability.py` on main lists the known bare-`git init` sites (FP-F13: managed-files:54,321; deploy-harness:81,86; profile/test-lib:77; test-profile:583-584,927-928; deploy-harness-mdm:63).
- Done when the lint runs and lists them. X5b fixes them.

**X5b. Migrate the bare `git init` sites to `t_git_init_main`.** After: X5.
- Files: the 5 suites named above, done as 2-3 suites per sub-batch (X5b-1, X5b-2).
- Also: add `env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS` to `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh:78`. With those variables exported, the test would rebuild the real dotprofile's `deploy/` (FC-C2 INCIDENT).
- Verify:
  - each suite passes with `GIT_CONFIG_GLOBAL` set to an empty file;
  - the lint is clean;
  - the lint becomes pre-commit step 24 (X8).

**X6 ✱. Known-failures baseline in check-lib.** After: X1.
- Files: `scripts/check-lib.sh` and `.ps1` (`step_fail` / `StepFail`, `print_summary` / `PrintSummary`); `scripts/check-known-failures.txt`; `tests/checks/test-known-failures.sh`.
- Behaviour (interface 7.5):
  - A matching unexpired line turns FAIL into `KNOWN` (yellow), which does not count toward the exit status. A line matches on script, step and label (v1.1). Step 2 reports two rows (`Script syntax (.sh)` and `(.ps1)`), so a step-only key would hide both.
  - `print_summary` lists KNOWN rows with their expiry.
  - An expired line, a malformed line or an expiry more than 14 days after `added` is a FAIL.
  - The file starts empty unless the A4 rebuild has not landed (then one step 7 line, expiring 14 days out).
- Error handling: an unreadable file is a WARN plus "no baseline", never a silent pass.
- Verify: the test passes; `check-pre-commit.sh` output is unchanged on a clean main.
- Done when the packet's "known pre-existing failures" prose can be deleted (R1).

### Wave 3: check scripts in CI

**X7a. `check-pre-commit.sh --ci` and the CI `checks` job.** After: X1, X6.
- Files: `scripts/check-pre-commit.sh`, `.github/workflows/check.yml`, `tests/checks/test-ci-mode.sh`.
- `--ci` runs the repo-wide steps over every tracked file (6, 14, 15, 16, 17, 19, 20, and 22-27 once they exist) and SKIPs the steps that need staged files or user state, each with its reason. The skipped steps are 1 (Git identity, which hard-codes `Jose <jose@nobul.tech>`), 2-5, 7-13 and 18. Today the script reads only `$1` (`[ "${1:-}" = "--fix" ]`), so `--ci` needs real argument parsing (v1.1).
- Which steps really pass in CI is unknown (FP Q4). The batch first runs every step under an isolated HOME with the X10a fixture dotprofile (or none) and records PASS/SKIP/FAIL per step in its PR body. Only then does it make the job required.
- Verify: the `checks` job is green; the test passes.

**X7b. `check-pre-commit.ps1` parity and `-Ci`.** After: X7a.
- Files: `scripts/check-pre-commit.ps1` (steps 17-19, or `# parity-exempt: 17 hooks run in bash on every platform`), `tests/checks/test-check-parity.sh`.
- The parity test covers pre-commit, pre-push and post-push. Post-push's missing step 8 needs an exemption line or a fix; the reason is unknown.
- Verify: the parity test passes; `pwsh -File scripts/check-pre-commit.ps1 -Ci` runs in the windows `checks` step.

**X8. New pre-commit steps 22, 23, 24, 26 and the review-after audit script.** After: X4, X5, X7a, and D-DEL5 on main (else step 23 fails on the old wording).
- Sub-batches, 2-3 files each:
  - X8-1: `scripts/check-pre-commit.sh` and `.ps1` (steps 22, 24, 26);
  - X8-2: the same two scripts plus `scripts/check-draft-language-allow.txt` (step 23) and `tests/checks/test-draft-language.sh`;
  - X8-3: `scripts/protected-diff.sh` and `.ps1`.
- `protected-diff.sh` reads the protected table from `.claude/rules/sources-of-truth.md` and lists the paths changed since a ref with their commits and trailers.
- Verify:
  - each step passes on main;
  - planting a violation fails it;
  - `bash scripts/protected-diff.sh v0.73.2` lists the MERGE-ALL protected changes.

### Wave 4: hooks

**X9a. Hook smoke tests.** After: X4.
- Files: `tests/hooks/test-hooks.sh` (a `suites.txt` line, all three platforms).
- Verify: the test passes on macOS and in CI on Linux and Windows (Git Bash).

**X9b. MAINSWITCH check in standing-order-guard (observe).** After: X9a.
- Files: `shared/hooks/standing-order-guard.sh` (`MODE_MAINSWITCH="observe"`), `tests/hooks/test-standing-order-guard-mainswitch.sh`, the `.claude/rules/hook-rollout.md` table row.
- Detection: the command is `git switch ...`, `git checkout -b|-B ...`, or `git checkout <ref>` without ` -- `. The target repo comes from `git -C <dir>`, a leading `cd <dir>`, or the hook's cwd. The target is the primary worktree when `git -C <dir> rev-parse --absolute-git-dir` equals `git -C <dir> rev-parse --path-format=absolute --git-common-dir`. Plain `--git-dir` can print a relative `.git`, so compare absolute paths. The check fires only when `git -C <dir> config --get aitools.pinMainCheckout` is `true`. Then call `violation "..." "$MODE_MAINSWITCH" "mainswitch"`. `git checkout <path>` without `--` restores a file and will log false positives in observe mode; the review phase decides whether to treat an existing path as an exemption.
- Scope (v1.1, changes v1.0's "every repo"): the hook is user-level, but the check is opt-in per repo. aitools sets `aitools.pinMainCheckout true` in its main checkout. In repos without a worktree policy, branching in the primary checkout is the normal workflow (the commander objects to worktree overhead), so a blanket check would push agents into more worktrees (open question 10).
- Verify: the hook-rollout.md pre-deploy steps (syntax, clean smoke, violation in observe logs, exemptions); the test passes.
- Promote to enforce after 1+ week of a clean log (hook-rollout.md).

### Wave 5: deploy build, Windows, verdict job

**X10a. Fixture dotprofile and `check-deploy-build.sh`.** After: A4 (build-deploy backup-then-swap) merged.
- Files:
  - `tests/fixtures/dotprofile/` (`profile.json` v2 with two id-keyed profiles, `claude/CLAUDE.md` with `{{PLACEHOLDER}}` tokens, `claude/rules/user1.md`), taken from `test-deploy-harness-mdm.sh` lines 59-71;
  - `scripts/check-deploy-build.sh` (bash-only with a documented exemption like `build-deploy.sh`, or a `.ps1` twin: Q5);
  - `tests/deploy-build/test-check-deploy-build.sh`.
- Body: the code of pre-push step 7 (`check-pre-push.sh:122-225`), moved into one file. It:
  - copies the dotprofile to a temp dir;
  - runs `env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE HOME=<tmp> AITOOLS_USER_REPO_PATH=<copy> bash scripts/build-deploy.sh`;
  - fails if `<copy>/deploy` was not built, as step 7 does today (`check-pre-push.sh:151-157`);
  - dry-runs the resolver consumers.
- Ordering fix (v1.1): v1.0 passed `--require-dotprofile` here, but X10b adds that flag. `build-deploy.sh` has no argument parsing today and exits 0 on every skip (`build-deploy.sh:86-88, 203-216`), so X10a must not depend on the flag. The "built nothing" check is X10a's guard. X10b adds the flag and then passes it from `check-deploy-build.sh`.
- Verify: the test passes; a fixture with a renamed section heading fails.

**X10b. `build-deploy --require-dotprofile`, pre-push step 7 and CI.** After: X10a.
- Files: `scripts/build-deploy.sh` (the flag makes every skip exit 1; the `aitools` loop keeps today's exit 0), `scripts/check-pre-push.sh` and `.ps1` (step 7 calls the script), `.github/workflows/check.yml` (replaces "Build deploy scripts" and "Check deploy drift").
- Verify:
  - the CI "Deploy build" step builds (its log shows the file count);
  - pre-push step 7 passes after the A4 rebuild.

**X11. `windows-extended` (observe), then enforce.** After: X4, X5b.
- Files: `tests/suites.txt` (windows-extended lines), `.github/workflows/check.yml`.
- Expect path-form failures first. Fix them with `t_norm_path`, 2-3 suites per follow-up PR.
- Done when one green run is on main and `continue-on-error` is removed. The commander then adds the job to the required checks (G3).

**X11b ✱. Issue #72 input seam (PS1 menu on Windows).** After: X11.
- Files: `scripts/aitools-lib.ps1` (route `Read-ConsoleChoice` and the merge `[y/n]` read through one replaceable reader); `tests/managed-files/test-managed-files.ps1`.
- The seam's shape is unknown until someone reads `Read-ConsoleChoice`. The delegate reads it first and records the design in the PR body.
- Done when (#72): no `SKIP interactive cases` line remains on Windows, and breaking a menu branch fails the Windows job.

**X12. `review-gate.yml` and `review-verdict.sh`.** After: X2 (shares the verdict parser rules).
- Files: `.github/workflows/review-gate.yml`, `.github/scripts/review-verdict.sh`, `tests/review-gate/test-review-verdict.sh` with fixtures.
- Security: the workflow uses `pull_request` and `issue_comment`, never `pull_request_target`. It checks out no PR code (it needs only `gh`), and the comment body is data only.
- Verify:
  - on a test PR, a `VERDICT: PASS @ <head>` comment turns `review/verdict` green;
  - a push turns it red until a new verdict;
  - a channel-only push keeps it green.

### Wave 6: hygiene, lints, contracts, smaller hazards

**X14. Retire `scripts/githooks/pre-commit`.** After: none.
- Files: `scripts/githooks/pre-commit`, `scripts/init-hh-hooks.sh` (and `.ps1` if one exists).
- First `git grep` both names; FC says nothing else references them. If something does, replace the hook body with a read-only call to `check-pre-commit.sh` instead.
- Same hazard class (v1.1): `check-pre-commit.sh --fix` step 3 runs `bash "$SCRIPT_DIR/build-deploy.sh"` with the real HOME, which deletes and rebuilds the real dotprofile `deploy/`. Make `--fix` skip the rebuild with a WARN that names the isolated-HOME command, or run it through `check-deploy-build.sh` once X10a lands. Update the `.ps1` twin the same way.
- Whether the hook is enabled on the Windows workstation is unknown. The PR body tells the commander to run `git config --get core.hooksPath` there.

**X15. PR template, release-note line, issue sync.** After: X3.
- Files: `.github/pull_request_template.md`, `.github/workflows/check.yml` (`pr-hygiene` steps "release note" and "closing keywords", WARN), `scripts/issue-sync-audit.sh` and `.ps1`, `tests/checks/test-issue-sync-audit.sh`, `scripts/check-pre-push.sh` and `.ps1` step 13. Split it as X15-1 (template plus YAML), X15-2 (audit script plus test), X15-3 (step 13).
- Verify: on a PR with no `Release note:` line, `pr-hygiene` shows a warning annotation; the audit lists #22-#31 against #35-#45 (FI-F9).
- The RELEASE orchestrator runs the audit before writing the notes.

**X16. `check-script-shapes.py` (pre-commit step 25).** After: X8.
- Files: `scripts/check-script-shapes.py`, `scripts/check-script-shapes-allow.txt`, `tests/script-shapes/` (one bad and one good fixture per rule).
- The first run on main will list existing sites. The allowlist carries them with the issue number, and fixing them is the work of epic #21, not this batch.
- Verify: the test passes; step 25 passes on main with the allowlist in place.

**X17. `linux-install` CI job (#19).** After: X3; and #89 (dry-run ignored by tool scripts) is not needed, because the job installs for real in a throwaway runner.
- Files: `.github/scripts/linux-install-smoke.sh`, `.github/workflows/check.yml`.
- Ships with `continue-on-error: true` until it is green on `ubuntu-24.04` and `ubuntu-22.04`, then becomes required. v1.0 named fedora, which is not on the supported list.

**X18. Pinned contracts (pre-commit step 27).** After: X8.
- Files: `reference/contracts.txt` (one line per interface: `<name> <defined-in> <consumed-by...>`, seeded from section 7 and `plans/build-package/implementation-plan.md` "Interfaces"), `scripts/check-contracts.py`, `tests/contracts/test-check-contracts.sh`.
- Process: launch prompts quote names from that file (R1, /delegate operational-learning element).

**X19. Post-push steps 33 and 34.** After: G1 (step 34 checks the settings G1 sets).
- Files: `scripts/check-post-push.sh` and `.ps1`, `tests/checks/test-nesting-probe-age.sh`.
- Step 33 needs a `probedVersion` line in `reference/tool-ops-claude-code.md` "Nesting probe" (protected; written as a version).

**X20. Pre-push steps 11 and 12.** After: X3, X4.
- Files: `scripts/check-pre-push.sh` and `.ps1` (step 11 `run-suites.sh local --changed origin/main`, step 12 `check-channel-only.sh`).
- Verify: on a branch that changes `scripts/aitools-profile.sh`, step 11 runs the profile suites in both macOS modes; class b reproduces (and fails) when a test omits `-b main` and `GIT_CONFIG_GLOBAL` is empty.

**X21. Direct-commit and worktree-listing helpers.** After: none.
- Files: `scripts/commit-direct.sh` and `.ps1`, `scripts/worktree-list-safe.sh` and `.ps1`, `tests/worktree/test-worktree-list-safe.sh` (and a test for `commit-direct` against a temp bare remote: it refuses a non-channel path, and after a race it retries once).
- Neither helper removes anything.
- `commit-direct` follows CLAUDE.md "Channel exception" exactly. When `pull --ff-only` fails (P22), it commits nothing, leaves the files uncommitted, and prints a "tell the commander" line with the ahead and behind counts. It never merges or rebases the shared checkout. It commits and pushes in one call, so no unpushed local commit is left behind (P22). Its path list is the one in 7.9.

**X22. SessionStart stale-checkout warning.** After: X9a.
- Files: `shared/hooks/stale-checkout-sessionstart.sh`, a hooks-manifest entry, `tests/hooks/test-stale-checkout.sh`.
- Behaviour: no network (uses the last-fetched refs); prints one line; always exits 0 (SessionStart cannot block). The line reports behind, ahead with unpushed commits, or diverged (P22, v1.1), from `git rev-list --left-right --count @{u}...HEAD`.

### Rules and skill batches (versions, review-after)

**R1. /delegate skill and delegation rule extensions.** After: MERGE-ALL deliverable 3 (D-DEL5 on main and in the dotprofile).
- Files:
  - `shared/skills/delegate/SKILL.md`: verdict format 5.5; mission defaults; hand-back budget; reviewers without worktrees; hand-backs to main; contracts quoted from `reference/contracts.txt`;
  - `shared/skills/delegate/mission-packet-template.md` (the packet, generalised);
  - dotprofile `claude/rules/delegation.md`: D-DEL6, and the inbound duty "hand-back budget".
- Then, separately:
  - `shared/hooks/delegation-duty-guard.sh` gets elements 8 (budget) and 9 (draft wording), observe mode;
  - `shared/skills/delegate/tests/expected-behaviors.md` gets the cases from FS-S4/S5/S6.
- Dotprofile files are committed and pushed to its main (N-Q2). aitools files go via a PR, with `Protected-file:` trailers where they apply.

**R2. User CLAUDE.md lines.** After: R1.
- Files: dotprofile `claude/CLAUDE.md` and `shared/claude-shared.md` (Template sync rule: both, same text).
- Text: the versions line (5.1) and the self-contained-questions extension of UCI "Suggest answers with questions" (5.6).

**R3. Project rule and reference versions.** After: X4, X6.
- Files: `.claude/rules/script-standards.md` (red-CI and xfail lines, known-failures line), `.claude/rules/cross-platform.md` (run-suites exemption row), `reference/cross-platform-detail.md` (CI runner behaviour, classes d and e).
- All protected: written as versions, `Protected-file:` trailers, review-after.

### GitHub settings (commander-owned; the mission may run them only with his explicit order)

| Step | When | Command | Effect |
|---|---|---|---|
| **G1** | After the MERGE-ALL train | `gh api -X PATCH repos/nobul-tech/aitools -F allow_squash_merge=false -F allow_rebase_merge=false -F allow_update_branch=true` | Merge commits only (A1); `gh pr update-branch` works (X2 `--update`) |
| **G2** | After #116 and the #74/#75 re-land have merged (A1: keep branches until the chains merge) | `gh api -X PATCH repos/nobul-tech/aitools -F delete_branch_on_merge=true` | GitHub retargets dependent PRs; no stale stack bases |
| **G3** | After X3 and X12 are green on main, and after the bypass question (Q1) is verified with chrome-devtools against GitHub's ruleset docs | Ruleset 16468370 gains `required_status_checks` (`macos`, `linux`, `windows`, `pr-hygiene`, `review/verdict`; later `windows-extended`, `checks`, `linux-install`) with `strict_required_status_checks_policy: true`. Then `allow_auto_merge=true` | "CLEAN" means green on current main by construction; `gh pr merge <n> --merge --auto` waits by itself |

Merge queue: the repo is public and org-owned. A merge queue could replace
the update-branch, wait and merge loop. Whether it is available and how it
treats required checks is not verified (FC-C5). It is a G4 candidate, to be
checked before G3 is designed.

## 7. Pinned interfaces

Every batch greps these against the code before using them. A batch that
must change one records a "Contract change" note in its PR body and in this
file's section 9 changelog, as a new version of this plan.

### 7.1 `scripts/pr-merge-gate.sh` / `.ps1`

```
pr-merge-gate.sh <pr> [--wait] [--update] [--repo <owner/name>]   (default nobul-tech/aitools)
pr-merge-gate.ps1 -Pr <n> [-Wait] [-Update] [-Repo <owner/name>]
stdout: "allow: #<n> <head sha7>"  or  "refuse: #<n> <reason>"
exit:   0 allow | 1 refuse | 2 usage or gh failure
env:    ALLOW_NEUTRAL (comma list, default "CodeQL")
        REQUIRED_CHECKS (comma list, default "macos,linux,windows")   (v1.1)
        VERDICT_AUTHORS (comma list of logins, default "nobul-jose")    (v1.1)
needs:  gh, git >= 2.38 (merge-tree --write-tree), a clone with origin
```

### 7.2 `tests/suites.txt` and `tests/run-suites.sh`

```
# path | platforms | modes | sources
tests/profile/test-profile.sh | macos,linux,windows-extended | bash,bash32-bashonly | scripts/aitools-profile.*,scripts/aitools-lib.*
run-suites.sh ci <macos|linux|windows|windows-extended>
run-suites.sh local [--changed <ref>]
run-suites.sh --check
```
Modes: `bash` (the job's bash, with pwsh parity where the suite has it),
`bash32-bashonly` (`AITOOLS_TEST_BASH=/bin/bash /bin/bash <suite> --bash-only`,
macOS only), `pwsh` (for `.ps1` suites). Exact mode names per suite come from
today's check.yml steps.

### 7.3 Verdict comment

```
VERDICT: PASS|CHANGES|BLOCK @ <sha, 7-40 hex>
AFTER: #<n>[,#<n>]          (optional second line)
```

### 7.4 Test helpers (`tests/lib/test-helpers.sh` / `.ps1`)

`t_git_init_main <dir> [--bare]`, `t_norm_tmp` (stdin to stdout), `t_norm_path <path>`,
`t_strip_cr <file>`; PS1 `T-GitInitMain`, `T-NormTmp`, `T-NormPath`, `T-StripCr`.

### 7.5 `scripts/check-known-failures.txt`

```
<script>\t<step>\t<label>\t<added YYYY-MM-DD>\t<expires YYYY-MM-DD>\t<issue or incident>\t<reason>
check-pre-push\t7\tdeploy/ matches source\t2026-10-27\t2026-11-10\tA4\tdotprofile deploy/ stale until the post-merge rebuild
```
The expiry is at most 14 days after `added`. A matching step reports `KNOWN`.

### 7.6 Commit trailers and markers

- `Protected-file: <path> v<N>` (one line per protected file; A2 review-after).
- `CI: red-expected (<suite> <n> failing, fixed by <batch/PR>)`.
- PR body: `Release note: <text>` or `Release note: none`; `Fixes #N`; `Part of #N: <what remains>`.
- Test output: `SKIP <case> (<reason>) #<issue>`; `XFAIL <case> incident #<n>`.

### 7.7 Reserved step numbers

Pre-commit: 21 (the #74 re-land), 22-27 (this plan). Pre-push: 11-13.
Post-push: 33-34. The same numbers are used in the `.ps1` twins.

### 7.8 CI names

The jobs `macos`, `linux` and `windows` keep their names. New jobs are `pr-hygiene`, `checks`, `windows-extended` and `linux-install`. The commit status is `review/verdict`, from workflow `review-gate.yml`.

### 7.9 Channel paths (v1.1)

One file, `scripts/channel-paths.txt`, holds one git pathspec per line, taken from CLAUDE.md "Channel exception": `.aitools/channel/handoffs/`, `.aitools/channel/relay.md`, `plans/`, `CLAUDE.md`. It is read by:
- `commit-direct` (X21);
- `check-channel-only.sh` (X3, X20);
- the verdict merge-tree rule (X2, X12).

v1.0 used `.aitools/channel/**` in some places, which is wider than the exception. A new channel path is added to this file and to CLAUDE.md in the same commit. The push `paths-ignore` list (4.1) may stay wider (`harvesting/**`), because skipping CI is not the same decision as skipping a PR.

## 8. Risks

- **Required checks may block channel-exception pushes** (FP-F4 caveat). A ruleset `required_status_checks` rule can reject direct pushes to main that have no passing checks. Agents and the commander share one account, so a bypass for that account bypasses it for agents too. Unverified. G3 waits on Q1.
- **`paths-ignore` with required checks.** A skipped required check stays pending. That is why `paths-ignore` is on `push` only (FC-C13).
- **Comment-triggered workflow** (X12) on a public repo. Never use `pull_request_target`, never interpolate a comment into `run:`, and never check out PR code. The X12 test covers it.
- **Parallel missions** (FAN-PLAN, BUILD-PKG, RECONCILE) edit check.yml, installers and tests. Run `pairwise.sh` over the open branches before each Wave 1-3 batch starts, and re-run it before each merge (FP-F5).
- **`windows-extended` will be red at first.** That is why it ships in observe mode (FC Q4).
- **X6 changes check-lib**, which every check script sources. A bug there turns every check run red or, worse, green. The test must include "unlisted FAIL still fails" (section 3).
- **Draft-language step false positives** in historical handoffs. Step 23 FAILs only on governed files. New plans and handoffs get a WARN, and old files are never rewritten.

## 9. Open questions (each with a suggested answer)

1. **Does a NEUTRAL CodeQL aggregate count as green?** Suggested: yes, when every `Analyze (*)` job is SUCCESS. `ALLOW_NEUTRAL=CodeQL` in the gate (FI Q1, FC Q3).
2. **When to apply G1-G3?** Suggested:
   - G1 right after the MERGE-ALL train;
   - G2 after #116 and the #74/#75 re-land;
   - G3 only after X3 and X12 are green and Q3 below is verified.
   Strict mode mid-train forces a rerun per PR, which A6 already does by hand (FI Q2, FP Q1, FC Q2).
3. **Required checks vs direct pushes to main.** Suggested: verify GitHub's ruleset behaviour for direct pushes and bypass modes with chrome-devtools before G3. If direct pushes would be blocked, either keep required checks off and rely on `pr-merge-gate.sh` plus D-DEL6, or move channel paths to a ruleset scope that excludes them (only if rulesets support path conditions; unknown).
4. **Known-failures file, or fix-only?** Suggested: fix X1 now, and add the file (X6) with the 14-day expiry cap. A permanent allowlist is the failure mode; an expiring one is a dated debt (FI Q4, FS Q1).
5. **Bash-only test and check drivers** (`tests/run-suites.sh`, `scripts/check-deploy-build.sh`) or `.ps1` twins? Suggested:
   - bash-only `run-suites.sh`, with an exemption row in cross-platform.md: Git Bash is the managed bash on Windows, and the driver also runs the `.ps1` suites;
   - a `.ps1` twin for `check-deploy-build` only if pre-push step 7's `.ps1` cannot call it through Git Bash today (the batch checks).
6. **User CLAUDE.md line for versions (5.1), in addition to D-DEL5 and the skill?** Suggested: yes. The main session is not a delegate, so the delegation rule alone does not reach it.
7. **Reviewer worktrees: retire them?** Suggested: yes. Reviewers use `gh pr diff`, `git show` and `git archive`. Only a reviewer that must run tests extracts a tree into scratch (FS Q5).
8. **Hand-back limit 25 lines?** Suggested: yes, with the report path on line 1 (FS Q4).
9. **Delete `scripts/githooks/pre-commit` and `init-hh-hooks.sh`?** Suggested: yes, after `git grep` confirms no other references (FC Q5).
10. **MAINSWITCH scope.** v1.0 suggested every repo (FS Q3). v1.1 suggests opt-in per repo through `git config aitools.pinMainCheckout true`, with aitools opted in and observe first. Elsewhere, branching in the primary checkout is how work avoids worktrees.
11. **The `aitools-json` intent statements say "DRAFT, awaiting commander approval".** Was the intent text approved? Suggested: treat it as approved v1.0 under review-after. X1 removes the word with a `Protected-file:` trailer, and the commander reviews the diff.
12. **Verdict authors.** Agents and the commander post from one account, so `VERDICT_AUTHORS=nobul-jose` cannot tell a reviewer's verdict from the author's own. Suggested: accept that for now, since the gate's job is to block outsiders and stale SHAs. A separate reviewer identity (a bot account or a GitHub App) is the follow-up that would make `--approve` and real reviews possible.

## 10. Not done in this version

- No code, test or CI change was made. This is the plan only (A7).
- Not verified:
  - the Linux and Windows results of the 4 suites (macOS only, FC-C2);
  - which check-pre-commit steps pass in CI (FP Q4; X7a measures it first);
  - GitHub ruleset push and bypass semantics (Q3);
  - merge-queue availability;
  - the cause of run 39859094088 beyond "batch pushed knowingly red".
- The code state behind open issues #22-#31 was not checked (FI). X15's audit lists them, and X16's allowlist records them.

## 11. Changelog

- v1.0 (2026-10-26): first version, written by S3-MA-FrictionPlan from the FI, FP, FC and FS findings v1.0 and the MERGE-ALL brief v1.0.
- v1.1 (2026-10-26): independent review fixes by S3-MA-FrictionReview (verdict file named in the header):
  - X2 and its test: `behind_by` refusal, because CLEAN does not mean current (#108: CLEAN, 33 behind); `REQUIRED_CHECKS` presence; the "check on another SHA" condition dropped (the rollup carries no SHA); `VERDICT_AUTHORS`; reviews read as well as comments; verdict precedence; the merge-tree definition of "channel-only or merge of main"; `update-branch` dependency marked unverified.
  - X12: author filter; `issue.pull_request` guard; PR number source.
  - D-DEL6: no-CI-expected handling after a paths-ignored merge.
  - X4: `--check` made static; the skip-ticket rule moved to the run modes.
  - X10a: no longer depends on X10b's flag; the heading test moved to an aitools-tree copy.
  - Step 23 and 5.1: `.cursor/rules/*.mdc`, `CLAUDE.md` and `shared/claude-shared.md` added, plus extra patterns.
  - X17: Ubuntu 24.04 and 22.04 instead of fedora.
  - X9b: opt-in scope; absolute git-dir comparison.
  - X6: label in the key.
  - X7a: step 1 and argument parsing.
  - X14: `--fix` step 3 hazard.
  - X3: bash-4 runtime constructs.
  - X1: the DRAFT text is inside intent statements.
  - New: P22 (diverged main checkout), the X21 `commit-direct` stop rule, the X22 ahead/diverged warning, 7.9 channel paths, questions 11-12.

## 12. INCIDENT markers carried from the findings (not filed; the executing mission files them via the /incident skill)

- `.github/workflows/check.yml:12-16` runs CI only for PRs whose base is main; #74/#75 merged with empty check rollups (FI, FP, FC). X3.
- 4 test suites on main are not run by CI (FI, FP, FC, FS). X3, X4.
- CI "Build deploy scripts" builds nothing; "Check deploy drift" checks the frozen `aitools/deploy/` (FC). X10.
- `scripts/check-pre-push.sh:70` `[\s]` in an ERE (bash only) (FI, FC; #134). X1.
- `check-pre-commit.ps1` lacks steps 17-19 with no documented exemption (FC). X7b.
- `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh:78` inherits `AITOOLS_USER_REPO_PATH` into a build-deploy run (FC). X5b.
- `scripts/githooks/pre-commit` runs build-deploy against the real HOME (FC). X14.
- The macOS pwsh syntax step hides parser messages with `2>/dev/null` (FC). X3.
- 2 tracked `*.bak.*` files under `shared/hooks/` (FS). X1.
- `scripts/aitools-json.pl/.ps1` still say `DRAFT` (FP; handoff G2). X1.
- No guard against switching the main checkout's branch (FP, FS). X9b.
- 32 PRs have commits after their last verdict; #111 8caa79e unreviewed (FP, FC). X2, X12.
- Repo allows squash and rebase against A1 (FI, FS). G1.
- Merge authority conflicts across A1, D-DEL4 and the packet (FS, ambiguity). R1 (D-DEL6).
- Windows CI job lacks the config, lib and user-init suites (FS, FC). X11.
- Issues #22-#31 open while merged PRs claim fixes, with no record of what remains (FI). X15.
