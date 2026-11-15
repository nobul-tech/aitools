# 38dc-16 report: check-pre-commit step 6 skips the frozen deploy/; PR #154 review B1, N1, N4

**Intent**: **Purpose**: record how mission 38dc-16-pr154-step6-fix resolved review findings B1, N1 and N4 of PR #154 (verdict https://github.com/nobul-tech/aitools/pull/154#issuecomment-6883176450), with the evidence. **Scope**: check-pre-commit step 6 (both twins), the step 4 decision, the new test cases, the "on every push" wording, the closedIn of incidents #136 and #176, the v0.77.9 release note. NOT N2, N3, N5, N6, N7 (listed as follow-ups). **Audience**: the orchestrator M6-Polish, the reviewer 38dc-15, the commander.

Version 1.0, 2026-11-14. Author: 38dc-16 (delegated by M6-Polish under Session Commander 87795dc3-e). Branch `fix/m6-checks`, base commit 85c8751; the review-fix commit is the one that adds this file.

## Summary

1. B1 confirmed and fixed: step 6 listed every tracked `*.sh`, the 18 frozen `deploy/*.sh` included; both twins now list `git ls-files -s -- '*.sh' ':!deploy/'`, so step 6 neither reports nor, with the fix flag, stages anything under `deploy/`.
2. The `.ps1` passes `'--'` quoted: PowerShell drops a bare `--` before it reaches `InvokeGit`'s `$args` (probe below).
3. New step 6 cases in `tests/check-pre-commit/test-pre-commit-steps3-10.sh` (both twins, fix flag on and off) plus a static check per twin; a native pwsh mirror of the `.ps1` case passes on the new twin and fails both modes on the old one.
4. Step 4 (line endings) has no tree-wide pathspec: it acts only on files the committer staged, so it is left unchanged (reason below).
5. N1: "on every push" now says "when a dotprofile is configured" in the rule, its `.mdc` twin, both checklists, README and the two script comments; N4: #136 and #176 `closedIn` carry v0.77.9 and the fixing commit.

## B1 verified on the branch (85c8751)

- `scripts/check-pre-commit.sh:160`: `non_exec=$(git ls-files -s '*.sh' 2>/dev/null | grep -v '^100755' || true)`; with `--fix`, `:166-169` run `git update-index --chmod=+x "$f"` on each listed file.
- `scripts/check-pre-commit.ps1:163`: `$nonExec = InvokeGit ls-files -s '*.sh' | Where-Object { $_ -notmatch '^100755' }`; with `-Fix`, `:169-171` run `InvokeGit update-index --chmod=+x $f`.
- `git ls-files -s -- '*.sh' | grep -c "<TAB>deploy/"` -> `18`; `git ls-files -s -- '*.sh' ':!deploy/' | grep -c "<TAB>deploy/"` -> `0`; totals 544 -> 526 (exactly the 18 dropped); no tracked `.sh` path contains a nested `/deploy/` (count 0), so the root-relative exclude drops nothing else. All 544 are 100755 today (`grep -v '^100755'` empty), as the reviewer said: latent, not live.
- pwsh 7.6.10 probe (`.scratch/session-38dc-16/probe-dashdash.ps1`): a function called as `ShowArgs ls-files -s -- '*.sh' ':!deploy/'` receives 4 args, `--` gone; with `'--'` quoted it receives 5 (`probe-dashdash2.ps1`). Both forms give 526 files and 0 under `deploy/` through `InvokeGit`, because `git ls-files` treats every argument as a pathspec; the quoted form keeps the twins identical and safe if a pathspec ever starts with `-`.

## Changes (old -> new)

- `scripts/check-pre-commit.sh` step 6: `git ls-files -s '*.sh'` -> `git ls-files -s -- '*.sh' ':!deploy/'`, with a 3-line comment (why deploy/ is excluded; incidents #136, #176; git-safety.md).
- `scripts/check-pre-commit.ps1` step 6: `InvokeGit ls-files -s '*.sh'` -> `InvokeGit ls-files -s '--' '*.sh' ':!deploy/'`, with the same comment plus why `'--'` is quoted.
- Non-fix reporting excludes `deploy/` too (the same list feeds both branches): the frozen tree is audited by no check any more (post-push steps 2, 6, 14 retired from it by #176; pre-commit steps 3 and 10 by #136), it is reset to HEAD before every pull (`.claude/rules/git-safety.md`), and a FAIL there could only be repaired by staging a change under `deploy/`, which git-safety forbids.
- Both twins, step 3 comment: "on every push, checks the exit code" -> "on every push when a dotprofile is configured, checks the exit code".
- `tests/check-pre-commit/test-pre-commit-steps3-10.sh`: header "step 6" case description and static line (help range 2-40 -> 2-48); helpers `section6`, `mk_repo6`, `rec_is`, `mode_is`, `step6_checks`; a step 6 block in the `.sh` section and in the `.ps1` section; one static check per twin.
- `.claude/rules/deploy-paths.md` and `.cursor/rules/deploy-paths.mdc` item 3: "on every push and dry-runs the result" -> "on every push when a dotprofile is configured (it SKIPs without one and WARNs without node (`.sh`) or Git Bash (`.ps1`); then nothing checks the generated scripts) and dry-runs the result"; "... are retired SKIPs, and post-push steps 6 and 14 ..." -> "... are retired SKIPs, pre-commit step 6 (exec bits, repaired by `--fix`) excludes `deploy/`, and post-push steps 6 and 14 ...". Sources: `scripts/check-pre-push.sh:125` (SKIP `userRepoPath not configured`), `:127` (WARN `node not found`), `scripts/check-pre-push.ps1:130`, `:132` (WARN `Git Bash not found`).
- `README.md`: "repairs line endings and exec bits of staged and tracked `.sh` files" -> "repairs line endings of staged `.sh` files (step 4) and exec bits of tracked `.sh` files outside the frozen aitools `deploy/` (step 6)"; "which rebuilds into a temporary copy." -> "which rebuilds into a temporary copy when a dotprofile is configured (it SKIPs without one)." The sentence "No step of the `check-*` scripts reads the frozen aitools `deploy/`" was false at 85c8751 (B1) and is true after this change; kept.
- `reference/pre-commit-checklist.md` step 3: "on every push" -> "on every push when a dotprofile is configured (it SKIPs without one and WARNs without node or Git Bash)"; step 6: `git ls-files -s '*.sh' | grep -v '^100755'` -> `git ls-files -s -- '*.sh' ':!deploy/' | grep -v '^100755'` plus one sentence on the exclusion.
- `reference/post-push-checklist.md` step 7: "which runs on every push." -> "which runs on every push when a dotprofile is configured (it SKIPs without one and WARNs without node or Git Bash)."
- `registries/incidents.json` (closed entries, `/incident` skill "Closing an incident" step 3):
  - #136 `closedIn`: "PR #154 (branch fix/m6-checks, mission M6-B)" -> "v0.77.9 (PR #154, branch fix/m6-checks, mission M6-B, commit 448ca00)"; `correctiveAction`: + one paragraph on the review fix (step 6 pathspec, the quoted `'--'`, the new cases, the old twins failing both modes); `preventionLayer`: "nothing may be staged under deploy/" -> "nothing may be staged under deploy/ (also by step 6 with a 100644 deploy/x.sh)", "+ list tracked *.sh files without excluding deploy/" in the static list.
  - #176 `closedIn`: "PR #154 (branch fix/m6-checks, mission 38dc-09)" -> "v0.77.9 (PR #154, branch fix/m6-checks, mission 38dc-09, commit 1536e6b)"; `preventionLayer`: "(an isolated rebuild on every push)" -> "(an isolated rebuild on every push when a dotprofile is configured; it SKIPs without one and WARNs without node or Git Bash)".
  - Commits: 448ca00 "Retire check-pre-commit steps 3 and 10: no path runs build-deploy.sh"; 1536e6b "Stop check-post-push steps 2, 6 and 14 reading the frozen aitools deploy/" (`git log --oneline origin/main..HEAD`). The PR's merge commit does not exist yet; the orchestrator may add it after the merge. Parse check: `python -c "import json; json.load(...)"` -> ok.
- `RELEASE_NOTES.md` v0.77.9: row 1 + "Step 6 (exec bits) no longer lists the frozen aitools `deploy/` (`git ls-files -s -- '*.sh' ':!deploy/'`), so neither twin reports it or, with the fix flag, stages a mode change under it (PR review B1)."; Files-created row + "step 6 never reports or stages a 100644 `deploy/` file"; "Verified on" + one sentence that the step 6 cases came after the 38/0 count. Reason: the entry's title ("No check ... inspects the frozen deploy/") and the suite description would otherwise misdescribe what ships.

## The new test cases and why the old code fails them

Fixture (`mk_repo6`): a git repo with `deploy/x.sh` and `scripts/y.sh`, both added with `git add --chmod=-x` (100644 on every platform) and committed. Step 6 is cut out between `# 6. ` and `# 7. ` (`section6`) and run with the existing stub harness (`run.sh` in the test's bash, `run.ps1` in pwsh), fix flag on and off. `step6_checks` asserts:

| Assertion | Fix on | Fix off |
|---|---|---|
| `mode_is <repo> deploy/x.sh 100644` | yes | yes |
| `[ -z "$(git -C <repo> diff --cached --name-only -- deploy)" ]` | yes | yes |
| `scripts/y.sh` mode | 100755 (the step still repairs outside deploy/) | 100644 |
| record is exactly one line | `PASS 6 (fixed)` | `FAIL 6 1 file(s) missing +x` |

Old pathspec (`'*.sh'`): with the fix flag the step runs `update-index --chmod=+x deploy/x.sh`, so `deploy/x.sh` becomes 100755 and is staged under `deploy/` (two assertions fail); without it the record is `FAIL 6 2 file(s) missing +x` (the exact-record assertion fails). Each mode kills the mutant on its own.

Static (both twins): every non-comment line matching `ls-files ... *.sh` must contain `:!deploy/`, and at least one such line must exist.

Evidence on this machine (native pwsh only; the `.sh` suite is not run on Windows, per the commander):

- `probe-step6.ps1` (a native mirror of the `.ps1` step 6 case, same fixture and assertions):
  ```
  new  fix=True  rc=0 deploy/x.sh=100644 stagedUnderDeploy=[] scripts/y.sh=100755 rec=[PASS 6 (fixed)] => ALL CHECKS PASS
  old  fix=True  rc=0 deploy/x.sh=100755 stagedUnderDeploy=[deploy/x.sh] scripts/y.sh=100755 rec=[PASS 6 (fixed)] => SOME CHECK FAILS
  new  fix=False rc=0 deploy/x.sh=100644 stagedUnderDeploy=[] scripts/y.sh=100644 rec=[FAIL 6 1 file(s) missing +x] => ALL CHECKS PASS
  old  fix=False rc=0 deploy/x.sh=100644 stagedUnderDeploy=[] scripts/y.sh=100644 rec=[FAIL 6 2 file(s) missing +x] => SOME CHECK FAILS
  ```
- `probe-static.ps1` (the two new perl one-liners, verbatim): new `.sh` and `.ps1` -> no output (pass); old `.sh` -> `160: non_exec=$(git ls-files -s '*.sh' ...)`, old `.ps1` -> `163: $nonExec = InvokeGit ls-files -s '*.sh' ...` (fail).
- The `.sh` twin's step 6 case runs only in CI (linux, macos bash 5 and /bin/bash 3.2, and the windows job, which runs this suite through Git Bash).

## Step 4 decision (line endings, also touched by the fix flag)

Not affected, left unchanged. Step 4 takes its files from `STAGED_FILES` (`git diff --cached --name-only --diff-filter=ACMR`, `.sh:37`; `$stagedSh`, `.ps1:38-42`), not from a tree-wide pathspec. It can only touch a `deploy/` file the committer staged; it never selects one on its own. Excluding `deploy/` there would hide a CRLF file the committer is about to commit. (A separate latent issue, below as INCIDENT: its repair runs `git add "$f"` on the whole working-tree file.)

## Checks (Windows 11, pwsh 7.6.10)

| Command | Result |
|---|---|
| pwsh parser, `scripts/check-pre-commit.ps1` | 0 errors |
| `bash -n` on `scripts/check-pre-commit.sh` and the test suite (parse only) | OK |
| line endings: `.ps1` | 432 CRLF, 0 bare LF; `.sh` files 0 CR |
| `check-pre-commit.ps1` (no `-Fix`, `AITOOLS_LOG_DIR` in scratch, review-fix files staged) | 11 PASS, 6 SKIP, 2 WARN (5 platform note, 11 dotprofile uncommitted changes, pre-existing), 0 FAIL; step 6 PASS |
| `check-pre-push.ps1` (`AITOOLS_LOG_DIR` in scratch) | 7 PASS, 3 WARN (1, 6, 8), 0 FAIL; step 7 PASS "fresh build OK (dotprofile deploy/ untracked, not compared); resolver consumers dry-run clean" |
| `git fetch origin`; `git log HEAD..origin/main` | empty: main has not moved since e50c3de, no merge needed |

## Not run

- `tests/check-pre-commit/test-pre-commit-steps3-10.sh` locally (commander, 2026-11-14: tests run as `.ps1` on Windows; this is a `.sh` suite). CI runs it.
- `check-pre-commit` with the fix flag (never against the real repo from an agent), `check-post-push`, `aitools`, `setup-user-*`, `deploy-harness`, `build-deploy.sh`.

## CONFLICT

- CONFLICT: commander 2026-11-14 ("tests should be .ps1 here on windows and executed as powershell scripts, git bash scripts cause known issues") vs `.claude/rules/cross-platform.md` "Pre-validation convention" (`bash -n` on every touched `.sh`) -- resolved by tier 1 (the commander's words): no `.sh` script or suite was executed; `bash -n` (parse only, nothing runs) was used on the two touched `.sh` files to meet the rule. Flagged so the commander can say if he wants even that avoided.

## INCIDENT markers (not filed)

- INCIDENT: check-pre-commit step 4 `--fix` / `-Fix` repairs CRLF by rewriting the working-tree file and running `git add "$f"` / `InvokeGit add $f` (at 85c8751: `.sh:136-141`, `.ps1:137-144`), which also stages any unstaged hunks of that file, and the `.ps1` reads the working tree, not the index, to decide. Low severity (spec: a fix should repair only what the check reported). Not deploy-specific; out of scope here.

## WRITE_BLOCKED

None.

## Follow-ups (out of scope)

- N2, N3 (reviewer): `.github/workflows/check.yml` deploy-tree steps; owned by mission 38dc-13. The CI step names still say "check-pre-commit steps 3 and 10 tests" although the suite now also covers step 6; rename there too.
- N5, N6: `scripts/check-lib.ps1` (another branch).
- N7: README pre-existing step counts.
- The M6-B report (summary item 1) and the PR body summary state "no step of any check-* script reads the frozen aitools deploy/" as fact for the code before this fix; it was false then (B1) and is true now. The M6-B report is another delegate's version and is not edited; the PR body gets a "Review fix" section that says so.
- `scripts/check-post-push.sh:205` / `.ps1:226` comments ("check-pre-push step 7 runs on every push (commander, 2026-10-26)") predate this PR and quote the decision; not changed.

## Open questions

1. Should the PR's merge commit be appended to #136 and #176 `closedIn` after the merge? Suggested: yes, by the orchestrator in its post-merge channel commit, matching #173's "merge c66d4b1" form.
2. Should the INCIDENT on step 4 (`git add` of the whole file) be filed? Suggested: yes, low, in the next incidents batch; fix with `git add` only when the file has no unstaged changes, else WARN.
