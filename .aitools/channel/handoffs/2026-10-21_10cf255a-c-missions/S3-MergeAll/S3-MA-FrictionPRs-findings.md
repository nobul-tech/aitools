# S3-MA-FrictionPRs: friction in PR history #50-#116

**Version:** v1.0 · **Written:** 2026-10-26 (UTC) · **By:** S3-MA-FrictionPRs (read-only research delegate of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose) · **Status:** not committed (per task)

**Intent**: **Purpose**: Give the MERGE-ALL friction plan (`plans/merge-friction-improvements.md`) the evidence it needs: each friction point seen in PRs #50-#116, with its root cause and a concrete remedy (unit test, CI step, check-script step, or process/rule change). **Scope**: GitHub PR history (#50-#116; #72 is an issue, #117-#120 do not exist), review comments, follow-up commits, CI runs, repo settings, worktrees, and the commander's typed prompts in session 10cf255a-c. NOT the merge execution itself, NOT the plan text. **Audience**: the MERGE-ALL orchestrator and whoever writes the friction plan.

## Method (reproducible)

All scripts are in `/Users/new-jose/repos/aitools/.scratch/session-fricprs/`; raw `gh` JSON is in `data/`.

| Script | What it does |
|---|---|
| `dump.sh` | `gh pr view` for #50-#120 (body, comments, reviews, commits, files, checks), `gh issue list`, `gh run list --limit 300` |
| `analyze.py` | Per PR: base, merge time, reviews and comments before and after the merge, check roll-up |
| `timeline.py <n>...` | Commits, reviews, comments and the merge in time order |
| `unreviewed.py` | Commits pushed after the last verdict (the reviewed SHA is not the merged SHA) |
| `merge-method.sh` | Parent count of each merge commit (1 = squash, 2 = merge commit), `mergedBy`, whether it is on origin/main |
| `tests-vs-ci.py` | `tests/` directories each PR adds compared with what `.github/workflows/check.yml` runs |
| `stacks.sh` | Which open PR heads contain other open PR heads; how far each is behind main |
| `pairwise.sh` | `git merge-tree --write-tree` for every pair of open PR branches (writes no refs) |
| `failed-logs.sh` | `gh run view --log-failed` for the 8 non-success runs out of the last 300 |
| `typed.py` | The commander's typed prompts (no tool results) that match friction keywords, from `user-prompts.py` output |

Repo settings were read with `gh api repos/nobul-tech/aitools` and `.../rulesets/16468370`.

## Summary

| # | Friction | Strongest evidence | Remedy type |
|---|---|---|---|
| F1 | Stacked PRs merged into stale bases (#74/#75) | #74 base `fix/registry-paths`, merged 04:24:16Z, 14 min after #71 had squash-merged that base to main; checks `{}` | CI on every base + base-is-main gate; merge-commit-only repo setting |
| F2 | Merged before the review, or the merged SHA was never reviewed | #76/#77 merged 6 min before their first verdict; 32 PRs have commits after the last verdict | Review label reset on push; merge gate checks verdict SHA = head SHA |
| F3 | Review verdicts cannot gate anything | GitHub refuses request-changes from the same account (#79, #80, #81, #86); 8+ free-text verdict formats | Fixed verdict line + `review:*` label + CI job |
| F4 | "Green" is stale; nothing is required | 18 open PRs have checks from 10-23 heads, all `mergeStateStatus` UNKNOWN, 20 main commits behind; ruleset has only deletion + non-fast-forward | `gh pr update-branch` before merge; ruleset required checks (strict) |
| F5 | Conflicts from parallel missions and the hand-listed check.yml | `pairwise.sh`: #106 x #116 (both installers), #112 x #116 (check.yml) | One test runner discovered by CI; file-ownership map |
| F6 | Test suites that CI never runs | main: `tests/deploy-harness`, `deploy-harness-mdm`, `rules-fanout-cursor`, `build-package`; open PRs add `hookin`, `b8-consumers`, `claude-mdm`; Windows runs no profile suites (#72) | Runner + discovery audit step |
| F7 | Local check scripts are not in CI, and "known failures" hide real ones | Pre-commit step 6, pre-push step 7 and step 3 are standing FAILs (packet section 4); #99's step-20 FAIL was seen only locally while CI was 7/7 green | Fix the 3 standing FAILs; CI job for check-pre-commit |
| F8 | Protected-file draft churn | 118 tracked `*draft*` files under handoffs; 2 PRs per change (#57->#65, #63/#64->#70, #96->#99/#101/#105); #96->#99 took 4 days; `DRAFT` still in `scripts/aitools-json.pl/.ps1` | D-DEL5 versions + review-after; check step for DRAFT markers |
| F9 | Worktree overhead | 75 worktrees (11 GB) under `.claude/worktrees`; commander complaints at lines 5421, 6071, 6494, 6712, 6779, 7264 | Direct-to-main for non-code (done in part); safe prune script; reviewers read with `git show`/`git archive` |
| F10 | Hand-back and report commits on PR branches | 20+ of the commits after the last verdict are "Add ... hand-back/report/verdict"; #95 has 24 commits | Hand-backs go to main under the channel exception, never on the PR branch |
| F11 | The main checkout's branch was switched | Commander, 2026-10-22T03:45:14Z (line 4106): "why did the branch change here? ... we should have stayed on main" | PreToolUse hook that blocks `git switch/checkout <branch>` in the main checkout |
| F12 | Fix-forward PRs | #84 (for #76/#77), #89 (for #79), #60 (for #56), the 9 audit-fix PRs #108-#116 after M3 merged | Follows from F2/F3; the merge gate |
| F13 | CI-only failure classes | bash 3.2 leg (#108, run 39891714493), `git init` default branch (#86, run 39873612279), Windows-only (#103, run 39888735993) | Pre-push runs the `/bin/bash` 3.2 legs; test lint for `git init` without `-b` |
| F14 | Squash-then-merge-commit switch mid-stream | #50-#75 squash (1 parent), #76-#99 merge commits (2 parents); #71's squash orphaned PR-a commits in the #74/#75 stack | Repo setting: merge commits only (A1) |
| F15 | Release notes drift | Last notes commit 075c3da (2026-10-03, v0.73.3); at least 47 merged PRs since; latest tag v0.73.2 | Per-PR change fragments + a check step |

## F1. Stacked PRs merged into stale bases (#74/#75)

**Evidence**
- `merge-method.sh`: `#74 base=fix/registry-paths commit=66e680f on_main=no`, `#75 base=feature/user-level-skills commit=f61d6fc on_main=no`.
- `analyze.py`: #71 (the base of #74) merged 2026-10-22T04:10:06Z; #74 merged 04:24:16Z into the already-merged base; #75 merged 04:24:26Z into #74's branch. Both show `checks={}`: no CI ran.
- Cause of `checks={}`: `.github/workflows/check.yml:12-16` triggers on `pull_request: branches: [main]` only.
- Handoff 2026-10-22 D.2 and I ("Check a PR's base before merging a stack") record the consequence: SD-8-ext and S2L-QA not in effect, T-Q9 and incidents #113/#123/#124 blocked.
- #71 was squash-merged (6dc9c99, 1 parent), so the stack's copies of PR-a's commits (0db8cc9, 24b56d3, 01355d5, 63ce030) are not on main. The re-land needs a cherry-pick recipe (handoff E1).

**Root cause**: three barriers missing at once. (1) GitHub does not retarget a PR whose base was merged unless the base branch is deleted, and `delete_branch_on_merge` is `false`. (2) CI does not run on PRs whose base is not `main`, so a stacked PR has no red signal. (3) Squash merge rewrites the base's commits, so the stack no longer shares history with main.

**Remedies**
- **CI step** (job `pr-base`, new, in `check.yml`): change the trigger to `pull_request:` with no branch filter, and add a first job:
  `if [ "${{ github.base_ref }}" != "main" ]; then echo "::error::base is ${{ github.base_ref }}; retarget to main before merging"; exit 1; fi`.
  A stacked PR then shows a red check, which the merge gate (F4) refuses.
- **Repo setting** (commander or mission, after MERGE-ALL): `allow_squash_merge=false`, `allow_rebase_merge=false` (decision A1: merge commits only). Then enable `delete_branch_on_merge=true`, so GitHub retargets dependent PRs to main. A1 says to keep the branches until the whole chain has merged, so enable it after this mission.
- **Merge-gate script** (see F4) refuses any PR whose `baseRefName` is not `main`.
- **Unit test**: `tests/pr-merge-gate/test-pr-merge-gate.sh`, fixture JSON with `baseRefName: "fix/registry-paths"`; asserts exit 1 and `refuse: base is not main`.

## F2. Merged before the review, or merged at an unreviewed SHA

**Evidence**
- `unreviewed.py`: `#76 MERGED BEFORE ANY VERDICT (merged 2026-10-22T04:37:58Z, first verdict 04:44:18Z)`, same for #77 (04:38:28Z vs 04:44:19Z). The fixes shipped in fix-forward #84 ("Land the review fixes for #76/#77 (merged before the fixes)").
- #79: comment 2026-10-22T21:10:24Z: "This PR merged at cc597ec before the Review3 fixes were pushed to its branch. The fixes ... ship in fix-forward #89."
- #80: review 21:14:08Z "Verdict: changes requested ... 2 majors" (M2: names contradict the approved tree, no protected-file draft). One fix commit, 28e0f5b (21:23:54Z, M1 only), then merged 00:37:47Z with no re-review.
- #71: review 04:05:51Z, 2 MAJOR. Fix 63ce030 at 04:07:06Z, merged 04:10:06Z with no re-review. #74: review 04:13:25Z, 3 MAJOR; ed1b75c at 04:14:18Z; merged 04:24:16Z with no re-review.
- `unreviewed.py` lists 32 PRs (merged and open) with non-merge commits after the last verdict. Code-bearing examples: #73 a278b28, #83 a87ffce, #86 26be34e, #88 7cc2c44, #90 9779372, #91 c719630, #92 7ede24d/6d4ccdf, #95 ff6e7dd, #98 fae7d62, #108 dbcc61a, #111 8caa79e (the brief's note: "never re-reviewed"), #115 2ae798a. The rest are hand-back or report commits (F10).
- Handoff I: "Four PRs were merged before their reviews were addressed (#56, #58, #76/#77, #79)".

**Root cause**: nothing ties a verdict to a SHA. Merges were done in batches by the commander (prompts 2026-10-22T03:24:35Z "i also merged many PRs"; 2026-10-23T01:58:29Z "all PRs merged") while missions were still pushing fixes. Neither GitHub nor CI knows that a review exists (F3).

**Remedies**
- **Process (in /delegate and the merge gate)**: a verdict cites the head SHA it reviewed (`@ <sha7>`). A PR is mergeable only when the latest non-blocking verdict's SHA equals `headRefOid`, or every commit after it touches only `.aitools/channel/**`.
- **CI job** (`review-gate`, new workflow `.github/workflows/review-gate.yml`, `on: pull_request: types [opened, synchronize, labeled, unlabeled]`, `permissions: pull-requests: write`): on `synchronize`, if the push changes any path outside `.aitools/channel/`, remove the `review:pass` label (`gh pr edit $N --remove-label review:pass`). The job passes only when `review:pass` is present and `review:changes` is absent. It runs on the head SHA, so it shows in `statusCheckRollup` and in `mergeStateStatus`.
- **Unit test**: `tests/pr-merge-gate/` fixtures: (a) verdict at `abc1234`, head `def5678` with a code commit after it: refuse; (b) only `.aitools/channel/` changed after it: allow; (c) no verdict: refuse.

## F3. Review verdicts cannot gate anything

**Evidence**
- GitHub refuses request-changes from the PR author's account, so every verdict is a comment: #79 ("Posted as a comment: GitHub refused `--request-changes`"), #80, #81, #86, #116 (comments quoted in `analysis.txt`).
- Verdict formats in this history alone: `VERDICT: CHANGES REQUESTED (3 blocking)` (#93), `**Verdict: no blockers.**` (#71), `NO BLOCKING FINDINGS` (#99, #110), `NON-BLOCKING` (#101, #105), `BLOCKING:` (#100), `approve with minors` (#115, #116), `APPROVE-equivalent` (#100, #112), `Verdict: ship after fixes` (#83), `approve-equivalent ... One condition: #86 does not merge before batch 5` (#86). Conditions such as "merge after #103" (#112) and "merge with or after B5" (#92) appear only in prose.

**Root cause**: one GitHub account for author, reviewer and merger; no machine-readable verdict.

**Remedies**
- **Process (/delegate skill, reviewer section)**: the first line of every verdict comment is `VERDICT: PASS|CHANGES|BLOCK @ <sha7>` and, when present, `AFTER: #<n>[,#<n>]`. The reviewer also sets the label: `gh pr edit <n> --add-label review:pass` (or `review:changes`). Labels work from the same account.
- **Check script** (`scripts/pr-merge-gate.sh`, a version of the harvested `harvesting/2026-10-23_session-f486b184-c_merge-check.sh` and `pr-status.sh`): parses the latest `VERDICT:` line, checks the SHA (F2), and refuses when an `AFTER:` PR is not yet merged.
- **Unit test**: `tests/pr-merge-gate/` fixture with `AFTER: #103` while #103 is open: refuse with `refuse: #112 waits for #103`.

## F4. "Green" is stale, and nothing is required

**Evidence**
- `gh api repos/nobul-tech/aitools`: `allow_auto_merge=false`, `delete_branch_on_merge=false`, squash, rebase and merge all allowed.
- Ruleset 16468370 ("Reibung"): rules `deletion` and `non_fast_forward` only. No required status checks, no up-to-date requirement, no required review.
- `open-state.sh` (2026-10-26): all 18 open PRs report `mergeable=UNKNOWN mergeStateStatus=UNKNOWN`. Their checks (7/7 SUCCESS) ran against 10-23 heads. `stacks.sh`: 17 heads are 20 main commits behind, #97 is 125 behind.
- The commander's goal asks for "all github CI/CD checks/auto merge status are green". Auto-merge is disabled on the repo, so it has no status today.

**Root cause**: PR checks run once, against the merge ref at push time. Main then moved (direct-to-main commits and #99's merge) and GitHub does not re-run them. `mergeStateStatus` is computed lazily and stays UNKNOWN until something asks for it.

**Remedies**
- **Process (merge loop)**: before each merge, `gh pr update-branch <n> -R nobul-tech/aitools` (merges main into the head as a merge commit, with no rebase or force-push), then `gh pr checks <n> --watch --interval 30`, then re-query `mergeStateStatus` until it is not UNKNOWN (bounded retries), and merge only on CLEAN. The update merge triggers `synchronize`, so F2's label reset applies. Its paths are main's, which F2's exemption should ignore when the commit is a merge from main.
- **Ruleset** (commander, after MERGE-ALL): add `required_status_checks` (`macos`, `linux`, `windows`, `pr-base`, `review-gate`) with `strict_required_status_checks_policy: true`. **Caveat (unknown, verify first):** a required-checks rule can block the direct pushes to main that the channel exception (CLAUDE.md, line 79) relies on, unless a bypass actor is set. All agents use the commander's account, so a bypass for that account also bypasses it for agents.
- **Optional**: enable `allow_auto_merge` and use `gh pr merge <n> --merge --auto`. Then "auto-merge status" has a meaning: GitHub merges once the required checks pass.
- **Unit test**: `tests/pr-merge-gate/` fixture with `mergeStateStatus: "BEHIND"` or `"UNKNOWN"`: refuse; `"CLEAN"` with all checks SUCCESS: allow.

## F5. Conflicts from parallel missions and a hand-listed check.yml

**Evidence**
- `pairwise.sh` (2026-10-26): every open branch merges cleanly into main on its own (`merge-check.sh`: all `dry-run=clean`), but `CONFLICT feature/harness-hookin x fix/mf-installer-relay: scripts/aitools-install.ps1 scripts/aitools-install.sh` (#106 x #116) and `CONFLICT fix/mf-audit-claude-build x fix/mf-installer-relay: .github/workflows/check.yml` (#112 x #116). This matches the brief's Step 4.
- `tests-vs-ci.py`: #103, #112, #113, #115 and #116 all edit `check.yml`, each adding steps to the same three job blocks.
- Handoff D.4: "File collisions to watch: mf-adopt and the HARNESS-2 setup-user-claude fan-out both edit `scripts/setup-user-claude.*` ..."
- `stacks.sh`: #116 contains #98, #103, #113 and #115; #115 contains #98, #103 and #113; #114 contains #98 and #108; #113 contains #98 and #103; #112 contains #103; #110 and #111 contain #100. Each stacked PR's diff against main includes its lower PRs (base is main), so reviewers have to scope by SHA range (see #111's review: "I reviewed only what #111 adds over `origin/feature/harness-rules-manifest`").

**Root cause**: every new test suite is a hand-written step in three jobs, so every test-adding PR edits the same lines. Two missions (HARNESS-2 and M3-FINISH) each changed the installers without an owner for those files.

**Remedies**
- **Unit-test runner** (`tests/run-all.sh`, plus `tests/run-all.ps1` for the PowerShell suites): discovers `tests/*/test-*.sh` and `tests/*/test-*.ps1`, runs each, prints `PASS|FAIL <suite>`, exits 1 on any failure. A suite opts out of a platform with a header line `# ci-skip: windows`. **CI**: each job's test steps become one step, `bash tests/run-all.sh` (and on Windows also `pwsh -File tests/run-all.ps1`). Adding a suite no longer edits `check.yml`, which removes the #112 x #116 conflict class.
- **Process**: launch prompts carry a file-ownership map (packet section 6 already says so). Add a pre-launch check: `pairwise.sh` over the branches of running missions, run by the orchestrator before it launches a mission that touches the same files.
- **Merge loop**: run `pairwise.sh` (or `git merge-tree` of the next PR against the simulated result of the previous merges) before each merge step to predict conflicts.

## F6. Test suites that CI never runs

**Evidence**
- `find tests -name 'test-*'` on main: 12 scripts. `check.yml` runs `tests/logging`, `tests/managed-files` and `tests/profile/*` only. Not run: `tests/deploy-harness/test-deploy-harness.sh` (#88), `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (#93), `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` (#87), `tests/build-package/test-cli.sh` (BUILD-PKG).
- Open PRs add more suites that CI will not run: `tests/hookin` (#106), `tests/b8-consumers` (#109), `tests/claude-mdm` (#112); #100, #110 and #111 change `tests/deploy-harness*`.
- `tests/deploy-harness-mdm` covers the build-deploy MDM generator, which cuts `deploy-harness.*` at its section headings ("rewording a heading breaks the build", handoff D.4). #100 and #111 edit `deploy-harness.*`, and CI would not catch a heading change.
- Windows job (`check.yml:330-471`): only logging, managed-files and an inline profile probe; no `tests/profile/*.sh` suites. Issue #72 (open): "PS1 managed-file review menu has no Windows test coverage". Handoff G7: "nothing from this session has run on Windows". Windows deploy drift is only a `::warning::` (`check.yml:470`).
- Issue #19 (open): "Linux CI never runs the installer".

**Root cause**: suites are opt-in per job (F5), and nothing checks that a new `tests/*` directory is wired in.

**Remedies**
- **CI step** (all three jobs, until `run-all.sh` lands): "Test discovery audit": `for d in tests/*/; do grep -q "$d" .github/workflows/check.yml || { echo "::error::$d is not run by CI"; exit 1; }; done`. After `run-all.sh` lands, the audit checks that every suite printed a PASS or SKIP line instead.
- **Check-script step** (`check-pre-push` new step): the same audit, so it fails locally before the push.
- **CI (Windows)**: run `tests/profile/test-*.sh` through Git Bash and the managed-file interactive cases (#72) with a pty or `script` shim; make Windows non-profile deploy drift an error once the line-ending cause is known.

## F7. Local check scripts are not in CI, and standing FAILs hide real ones

**Evidence**
- `check.yml` never runs `scripts/check-pre-commit.sh`, `check-pre-push.sh` or `check-post-push.sh` (`grep check-pre` finds nothing).
- Packet section 4 lists "Known pre-existing failures (record, not blockers)": pre-commit step 6 (`harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` is 100644, confirmed today with `git ls-files -s`), pre-push step 7 (dotprofile deploy/ stale), pre-push step 3 (`[\s]` false positives). Decision B1 makes step 7 fail on every push until the rebuild.
- #99 body: "`bash scripts/check-pre-commit.sh` ... 2 FAIL. **Step 20 FAIL, from this PR.**" CI on #99 was 7/7 SUCCESS. A reader of the PR's checks would not know about step 20, and the new FAIL sat next to the "expected" step 6 FAIL.
- PR bodies of #74, #79, #86, #89, #112, #115 and #116 each have 2-4 matches of a `step N ... FAIL|fails` regex (a rough count of recorded local step failures; not read one by one).

**Root cause**: standing FAILs taught every agent to read FAIL as "probably the known one". The check scripts need user state (dotprofile, config.json), so nobody wired them into CI.

**Remedies**
- **Fix the standing FAILs** (small PRs): `git update-index --chmod=+x` on the step 6 harvest file; fix step 3's `[\s]` pattern; the rebuild clears step 7 (deliverable 5). After that, "0 FAIL" is the bar.
- **CI job** (`checks`, Linux): `bash scripts/check-pre-commit.sh` against the PR's changed files, under an isolated `HOME` with a fixture dotprofile. Steps that need real user state SKIP (12 already SKIP locally, per #99's body). Which steps can run in CI is **unknown**; verify step by step before making the job required.
- **Unit test**: `tests/check-scripts/test-standing-failures.sh` runs pre-commit on a clean main checkout and asserts 0 FAIL. It fails as soon as someone adds a new standing FAIL.

## F8. Protected-file draft churn

**Evidence**
- `git ls-files .aitools/channel/handoffs | grep -ci draft`: 118 tracked draft files.
- Two PRs per protected change: #57 ("draft incident batch #87+ for commander approval") -> #65 (file them); #61, #63 and #64 ("drafts ... for approval") -> #68/#70 ("Apply approved drafts"); #96 ("M3 protected-file drafts for approval (no protected file changed)", merged 2026-10-23T01:58:10Z) -> #99 (merged 2026-10-26T23:08:21Z, about 4 days later), with #101 and #105 still open; #102 ("drafts for approval") still needs an apply script and its own incidents PR after merge (brief section 3).
- Draft mentions per PR body (`analyze.py`): #99 26, #70 18, #60 15, #63 12, #69 11.
- Re-approval loops: #99's "2 paragraphs held" and the `.mdc` twin "please confirm" (handoff D.4, F2); #105 row 8 "needs a new version" (brief section 3).
- `DRAFT` still marks shipped code: `scripts/aitools-json.pl` and `scripts/aitools-json.ps1` (grep) (handoff G2: "aitools-json.pl still says `DRAFT`").
- Commander: 2026-10-26T22:39:56Z (line 6779) "no drafts, the produced plan should be executable ... version 1.0"; line 7264 "i dont like that produced work is often 'draft'".

**Root cause**: `sources-of-truth.md` requires draft, present, wait. For agents that means a draft file, a draft PR, an approval message and an apply PR. Approval evidence lives in chat (handoff E1: "#96 was merged with no comment").

**Remedies**
- **Rule change** (already decided, A2 and D-DEL5): versions, never drafts; protected files written and committed, commander reviews the diff after.
- **Check-script step** (pre-commit, new): fail when a staged file (outside `.aitools/channel/handoffs/` history) adds the words `DRAFT`, `(draft)` or `draft for approval`, or when a new file name contains `draft`. Message: "write a version (v1.0), not a draft (D-DEL5)".
- **Review-after support** (check step or script, `scripts/protected-diff.sh <since-ref>`): lists every protected path (the `sources-of-truth.md` table) changed since a ref, with commit and PR, so the commander's review-after is one page. Commits that touch a protected file carry a `Protected: <paths>` trailer; the pre-commit step checks the trailer is present.
- **Clean-up**: remove the `DRAFT` wording from `aitools-json.pl/.ps1` (the approved intent text is in #96 rows).

## F9. Worktree overhead

**Evidence**
- `git worktree list`: 75 entries (main plus 74 under `.claude/worktrees/`); `du -sh .claude/worktrees`: 11G. Most belong to merged branches (for example `applydrafts`, `delegate-ol`, `sourcetruth`, `gate-decisions`). Reviewers created detached worktrees of their own (`h2-cursor-rv`, `h2-hookin-rev`, `h2-mdm-review`, `mf-fix4-review`, `mf-fix5-review`, `mf-relay-reva`, `mf-relay-revb`, `mf-runner-review`); one worktree is nested inside another (`fanplan/.scratch/session-plan/wt112main`).
- Worktrees cannot be cleaned: "Removing a git worktree deletes its ignored files: never remove another agent's worktree" (packet section 5; the S3-Hooks scripts were lost that way, handoff I). Commander 2026-10-26T22:45:00Z (line 7017): "hold off on removing the worktree for now".
- Commander quotes: 2026-10-23T02:29:31Z (line 5421) "i dont like the overhead of worktrees/PRs for handoffs"; line 6071 "fix it directly on main, no worktree/pr overhead"; line 6494 "bypass worktrees/pr branches"; line 6712 "no worktrees etc."; line 6779 "no worktrees/prs, this should bypass all of that"; line 7264.

**Root cause**: one worktree per delegate (packet section 4) and per reviewer; scratch and hand-backs in ignored paths make removal unsafe; no lifecycle step removes them.

**Remedies**
- **Process**: reviewers do not need a worktree. They read with `git show <sha>:<path>`, `git diff <a>..<b>` and `git archive <sha> | tar -x -C <scratch>` when they must run tests (#74's reviewer already did this). Non-code work goes direct to main (B2, CLAUDE.md channel exception). Code PRs keep worktrees (brief Q1).
- **Script** (`scripts/worktree-prune-safe.sh` plus a `.ps1` twin, dry-run by default): for each worktree whose branch is merged into origin/main (`git merge-base --is-ancestor`) or detached at a commit on main, list `git -C <wt> status --porcelain --ignored`. When there are untracked or ignored files outside build outputs, copy them to `harvesting/` (per the `/harvest` skill) before removal; otherwise report. It removes only with `--apply` and only on the commander's order (F4 of handoff 2026-10-22).
- **Unit test**: `tests/worktree-prune/test-worktree-prune.sh` with a temp repo: a merged worktree with an ignored `.scratch/x.sh` is not removed until the file is copied; an unmerged worktree is never removed.

## F10. Hand-back and report commits on PR branches

**Evidence**: of the 32 PRs with commits after the last verdict (`unreviewed.py`), many of those commits are documentation the mission wrote about itself: #81 5b33692 "Add S3-DiffUX hand-back and independent review verdict", #95 b595632 "Add the S3-M3-B5a mission report", #99 dab978d, #100 699eba8, #101 583436e, #103 945deb5, #105 dfa1776, #110 adcf4a7, #112 52821bd, #114 f8e8fc0, #116 0e0a3f7. #95 has 24 commits. These commits move the head after the review, so the "reviewed SHA = head" rule (F2) fails for a reason unrelated to code, and they add `.aitools/channel/` files to code PRs, which then conflict with direct-to-main channel commits.

**Root cause**: before B2 (2026-10-26), hand-backs had to ship through a PR, so they rode on the code PR.

**Remedy (process, /delegate skill)**: hand-backs, reports and verdict copies go to main directly under the channel exception, in their own commit, never on the PR branch. The F2 gate also exempts `.aitools/channel/**` commits, for PRs already open.

## F11. The main checkout's branch was switched

**Evidence**: commander, 2026-10-22T03:45:14Z (line 4106): "I cant run aitools because the branch changed. why did the branch change here? it shouldt have, we should have stayed on main". No hook in `shared/hooks/` matches `git (switch|checkout)` (grep, 2026-10-26). The rule exists only as prose (packet sections 4 and F3 of the handoff).

**Remedy (hook)**: `shared/hooks/main-checkout-guard.sh`, PreToolUse on Bash: when the command is `git switch`, `git checkout <branch>` or `git checkout -b`, and `git -C <target> rev-parse --show-toplevel` is the main checkout (`git rev-parse --git-common-dir` equals `--git-dir`), block it with "use a worktree (packet section 4)". `git checkout -- <path>` and `git -C <worktree> ...` stay allowed. **Unit test**: `tests/hooks/test-main-checkout-guard.sh` feeds the hook JSON for each form and asserts block or allow. Rollout per `.claude/rules/hook-rollout.md` (observe first).

## F12. Fix-forward PRs

**Evidence**: #84 ("Land the review fixes for #76/#77 (merged before the fixes)"), #89 ("#79 fix-forward"), #60 ("fix hook-lifecycle drafts (#82 follow-up)") after #56. After M3 merged, the M3-FINISH audit (#104) produced nine fix PRs, #108-#116, against code merged hours before (A-1..A-26). #116 itself now needs a fix-forward (brief section 3).

**Root cause**: F2 and F3 (merge before or without a verdict at the head SHA), plus batch merges without main CI in between (A6 is new).

**Remedy**: the merge gate (F2-F4) and A6 (main CI plus touched suites after each merge). No separate test.

## F13. CI-only failure classes

**Evidence** (8 non-success runs in the last 300, `failed-logs.sh`):
- **bash 3.2 leg only**: run 39891714493 (#108): "Profile resolver tests (macOS /bin/bash 3.2) ... 531 passed, 2 failed" (`a78-exc-ro`, `a8-mig-ro`: the expected line has `<pid>`, the actual has `.tmp.40736`). Fixed in dbcc61a "Normalise temp file names in bash-only test runs".
- **git default branch**: run 39873612279 (#86): "error: src refspec main does not match any" in the user-init push-rejected case on macOS and Linux runners. Today `tests/profile/test-user-init.sh:114,122` use `-b main`; other suites still use bare `git init -q` (`tests/managed-files/test-managed-files.sh:54,321`, `tests/deploy-harness/test-deploy-harness.sh:81,86`, `tests/profile/test-lib.sh:77`, `tests/profile/test-profile.sh:583-584,927-928`, `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh:63`). They pass today because they push `HEAD`. Decision C (#165: non-main dotprofile pushes become an ERROR) makes a branch-dependent failure more likely.
- **Windows only**: run 39888735993 (#103): "FAIL push failure: WARN logged, ACTION 'run git push in <dotprofile>'", "FAIL push rejected", "FAIL commit failure" on the Windows runner only.
- **Contract change**: run 39859094088 (#86): config writer tests `c1-fresh`, `c2-verified`, `c3-upgrade`, `c8-dry-run` "no row 'OK|aitools config|...'" on Linux and macOS. The fix is in a later commit; the exact cause is unknown (not investigated).

**Remedies**
- **Check-script step** (pre-push, new): on macOS, when `tests/profile/` or `scripts/aitools-profile.*` changed, run the `/bin/bash` 3.2 legs exactly as CI does (`AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-*.sh --bash-only`).
- **Test lint** (pre-commit step, or a check in `tests/run-all.sh`): fail on `git init` or `git -C ... init` in `tests/` without `-b <name>` or `-c init.defaultBranch=`. A one-line grep (`grep -rnE 'git (-C [^ ]+ )?init( -q)?( |$)' tests | grep -v -- '-b '`).
- **Windows**: F6's Windows suites; and the mission records Windows coverage as CI-only in the release notes (brief Q5).

## F14. Squash, then merge commits

**Evidence**: `merge-method.sh`: #50-#75 have 1 parent (squash), #76-#99 have 2 (merge commit). The switch happened mid-session. #71's squash (6dc9c99) is why the #74/#75 re-land must drop four PR-a commits (handoff E1). The commander had to ask about it (2026-10-26T22:47:02Z, line 7065: "the method (sqush merged? commit merged?)") and decided A1 (merge commits).

**Remedy**: the repo setting in F1 (`allow_squash_merge=false`, `allow_rebase_merge=false`), so the UI and `gh pr merge` cannot squash by accident. The merge-gate script passes `--merge` explicitly.

## F15. Release notes drift

**Evidence**: brief section 3: the last RELEASE_NOTES.md commit is 075c3da (2026-10-03T05:09:35Z, v0.73.3, untagged); the latest tag is v0.73.2. At least 47 PRs have merged since (#50-#71, #73-#96 and #99, per `merge-method.sh`); PRs below #50 were not checked. The RELEASE orchestrator has to reconstruct notes from commit and PR messages.

**Remedies**
- **Process**: each PR adds `changes/<pr-or-branch>.md` (one fragment, no shared file, so no conflicts); the release step folds them into RELEASE_NOTES.md and deletes them.
- **Check step** (pre-push, WARN at first): if the branch changes `scripts/`, `shared/` or `.github/` and adds no `changes/*.md`, warn "add a change fragment".

## Priority (smallest change, biggest effect first)

1. Merge gate script plus its fixture tests (F1-F4, F14): it is the mission's own tool, and the harvested `merge-check.sh` / `pr-status.sh` are its start.
2. `tests/run-all.sh` plus discovery audit (F5, F6): removes the check.yml conflict class and wires in 4 suites on main and 3 in open PRs.
3. Fix the three standing check FAILs (F7).
4. Hand-backs to main; reviewers without worktrees (F9, F10).
5. `review-gate.yml` plus the verdict line and labels (F2, F3).
6. Repo settings and ruleset (F1, F4, F14), after MERGE-ALL and with the bypass question answered.
7. DRAFT check plus protected-diff script (F8); main-checkout guard hook (F11); test lint and bash 3.2 pre-push step (F13); change fragments (F15).

## Open questions (each with a suggested answer)

- **Q1. Required checks in the ruleset vs the channel exception.** A required-checks rule can block direct pushes to main. Suggested: add only `pull_request`-level rules now (require the checks for merges through PRs) and verify against GitHub's ruleset docs with chrome-devtools before enabling. Do not enable during MERGE-ALL.
- **Q2. `delete_branch_on_merge`.** A1 keeps branches until the chain has merged. Suggested: enable it after MERGE-ALL's last merge, when the brief's Q2 clean-up deletes merged head branches anyway.
- **Q3. Should `review-gate` be required for docs-only PRs?** Suggested: no; the job passes automatically when every changed path is under `plans/`, `.aitools/channel/` or `*.md` outside the protected table.
- **Q4. Which check-pre-commit steps can run in CI?** Unknown. Suggested: one delegate runs it under an isolated HOME with a fixture dotprofile and records PASS/SKIP/FAIL per step before the CI job is written.

## INCIDENT markers (not filed)

- INCIDENT: `.github/workflows/check.yml:12-16` runs CI only for PRs whose base is main, so stacked PRs (#74, #75) merged with no checks (`statusCheckRollup` empty). Expected: every PR carries a red or green signal before merge.
- INCIDENT: four test suites on main (`tests/deploy-harness`, `tests/deploy-harness-mdm`, `tests/rules-fanout-cursor`, `tests/build-package`) are not run by CI (check.yml); the MDM generator's heading contract is untested in CI.
- INCIDENT: `scripts/aitools-json.pl` and `scripts/aitools-json.ps1` still carry `DRAFT` wording after the approved intents (handoff G2).
- INCIDENT: no guard prevents switching the main checkout's branch; it happened on 2026-10-22 (line 4106) and the rule is prose only.
- INCIDENT: 32 PRs have commits after their last review verdict; at least #71, #74 and #80 merged with code commits that no reviewer saw, and #111's 8caa79e is open and unreviewed.

## Provenance

- `gh` data fetched 2026-10-26 between about 23:15Z and 23:40Z; `git -C /Users/new-jose/repos/aitools pull --ff-only`: "Already up to date" (main 5494d93 at `git worktree list`).
- #99 had merged (2026-10-26T23:08:21Z, merge commit 3c4f8fe) when this was written, so MERGE-ALL had started; the open set was 18 PRs.
- Transcript: `~/.claude/projects/-Users-new-jose-repos-aitools/10cf255a-c378-45d7-83f1-a0baffa7c172.jsonl`, read through `user-prompts.py` (166 items); line numbers are the transcript's.
- Nothing was written to GitHub, to any branch, or to any worktree. This file is not committed.
