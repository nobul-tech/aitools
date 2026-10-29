# S3-MA-FrictionCI findings: CI history, check scripts, and what CI misses

**Version:** v1.0 · **Written:** 2026-10-26 (after 23:10Z) · **By:** S3-MA-FrictionCI (delegate of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose) · read-only research, not committed.

Sibling findings that overlap (cross-referenced, not repeated): `S3-MA-FrictionIssues-findings.md` (FI), `S3-MA-FrictionPRs-findings.md` (FP), `S3-MA-FrictionSessions-findings.md` (FS). This file adds the CI-side evidence and turns each point into a concrete test, CI step, check step or rule. Items marked **NEW** are not in the siblings.

## How I checked

- `gh run list -R nobul-tech/aitools --limit 200` (and `--limit 1000 --status failure`): 18 failed CI runs in total, 11 since 2026-10-22, 6 in June 2026. Every other run in the last 200 is green.
- `gh run view <id> --log-failed` for every failed run since 2026-10-22, summarised by `/Users/new-jose/repos/aitools/.scratch/session-ma-fci/failed-runs.sh` (output `failed-runs.txt` beside it). The fix commit for each failure came from `gh pr view <n> --json commits` and `git show`.
- `.github/workflows/check.yml`, `scripts/check-pre-commit.sh/.ps1`, `scripts/check-pre-push.sh/.ps1`, `scripts/githooks/pre-commit`, `scripts/init-hh-hooks.sh` (origin/main = bc4aad1, `git diff HEAD origin/main` shows these files unchanged).
- A shared clone of origin/main bc4aad1 at `/Users/new-jose/repos/aitools/.scratch/session-ma-fci/main-clone` (a clone, not a worktree). Probes on it: `probe-main.sh` (syntax under `/bin/bash` 3.2, pwsh parser on files CI skips, `perl -c`, `py_compile`, exec bits, hook parity, standing-order-guard smoke) and `run-nonci-suites.sh` (the four test suites CI does not run, isolated HOME, `AITOOLS_*` unset).
- `gh api repos/nobul-tech/aitools/rulesets/16468370`, `.../branches/main/protection`, `gh api repos/nobul-tech/aitools` (merge settings), `gh pr view 74/75` (checks), open-PR file lists (`pr-files.sh`), and the check.yml hunks each open PR carries (`pr-ci-diff.sh`).
- `git log origin/main --since=2026-10-20 --format=%B`, counted with grep.
- The INCIDENT markers in the mission folder: `git grep -hoE "INCIDENT:..." origin/main -- .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions`.

## Summary

| # | Friction | Evidence | Remedy (type) |
|---|---|---|---|
| C1 **NEW** | CI's "Build deploy scripts" step builds nothing, and "Check deploy drift" compares a frozen directory | linux log of run 40415865053: `[warn] No dotprofile found ... skipping deploy build.`, exit 0 | CI fixture dotprofile + shared build-and-smoke script (CI step, check step) |
| C2 | Test suites CI never runs (FI-F4, FP-F6) | `tests/deploy-harness`, `deploy-harness-mdm`, `rules-fanout-cursor`, `build-package` absent from check.yml; **all four green on main today** (45/0, 30/0, 78/0+1 skip, 32/0) | Add them now (CI steps); one suite list (CI design) |
| C3 **NEW** | Windows runs almost none of the M3 suites | Windows job runs logging, managed-files, one inline resolver smoke; no test-profile/config/lib/user-init; 49 commit messages since 10-20 say Windows not run | `windows-extended` job, observe then require (CI step) |
| C4 | CI-only failure classes (FI-F6, FP-F13): all 11 recent failures | 5 classes below, each fixed by a follow-up commit | Local runner that matches CI; test helpers (unit tests) |
| C5 | PR checks are stale and nothing is required (FP-F4) | ruleset has only `deletion` + `non_fast_forward`; branch not protected; open PR checks are from 2026-10-23 | Ruleset with required checks; `gh pr update-branch` before merge (GitHub settings, process) |
| C6 **NEW** (verified) | Stacked PRs got no CI at all | `pull_request: branches: [main]`; `gh pr view 74/75`: `statusCheckRollup` empty | Trigger on every base + base-guard job (CI step) |
| C7 | Local check scripts never run in CI; standing FAILs (FI-F7/F8, FP-F7) | step 6, step 3, step 7 "known FAIL" in 5 commit messages since 10-20 | `--ci` mode for the repo-wide steps; fix the three standing FAILs; known-fail list with expiry |
| C8 **NEW** | Check-script parity gaps | `check-pre-commit.ps1` has steps 1-16 and 20, no 17-19; step 3's `[\s]` is a bash-only bug (the `.ps1` uses `\s`, correct) | Parity unit test of the check scripts (unit test) |
| C9 **NEW** | Syntax checks cover only `scripts/` and `deploy/`, and only under bash 5 | CI loops `scripts/*.sh deploy/*.sh shared/hooks/*.sh`, `scripts/*.ps1 deploy/*.ps1`, `scripts/*.py`; probes on main: `/bin/bash -n` 89/89 ok, 8 skipped `.ps1` ok, `aitools-json.pl` ok, 3 skipped `.py` ok | Widen the loops; add `/bin/bash -n` (CI step) |
| C10 **NEW** | Hooks have no smoke test in CI | hook-rollout.md requires a clean and a violation smoke test (I12: `bash -n` passed, hook crashed every call); probe on main: clean exit 0, `&&` exit 2 | `tests/hooks/test-hooks.sh` (unit test, CI step) |
| C11 **NEW** | `scripts/githooks/pre-commit` would run build-deploy against the real HOME | it runs `bash scripts/build-deploy.sh` then `git add deploy/`; enabled by `scripts/init-hh-hooks.sh`; not enabled on this Mac (`core.hooksPath` unset) | Retire or repoint the hook (code fix) |
| C12 | No rule that a pushed batch keeps CI green (INCIDENT in mission files) | 3ce5850 body: "Still failing ... test-config.sh 85/4"; run 39861809999 red on macOS and linux | Rule + commit trailer `CI: red-expected (<reason>)` (rule) |
| C13 (FS-S11) | Every push pays ~10-12 min of 3-OS CI, docs-only included | last 24 green runs: 548-1177 s; 40416825997 "Add MERGE-ALL mission brief v1.0" 638 s | `paths-ignore` for channel-exception paths on push; `concurrency` cancel (CI config) |
| C14 **NEW** | Review verdicts are not tied to a SHA, so an unreviewed head can merge (FP-F2/F3) | #111 head 8caa79e; its own PR comment: "the reviewer has not re-checked this commit" | `review-verdict` job: latest verdict comment must cite the head SHA (CI step) |
| C15 | Release notes drift (FP-F15) | pre-push step 5 only warns; last RELEASE_NOTES.md commit 075c3da (v0.73.3, untagged); latest tag v0.73.2 | `## Unreleased` section + PR-body `Release note:` line checked by CI (CI step, process) |

## C1. CI builds no deploy/ and checks a frozen directory (NEW)

**Evidence.** Run 40415865053 (push to main, 2026-10-26T22:53Z), linux job, step "Build deploy scripts":
`[2026-10-26T23:02:02Z] [build-deploy] [warn] No dotprofile found. Run 'aitools user init' first -- skipping deploy build.` The step exits 0. The next step, "Check deploy drift", diffs `aitools/deploy/`, which `.claude/rules/deploy-paths.md` says is frozen ("The shared `aitools/deploy/` is frozen (no longer regenerated)"). Both steps run on all three jobs (check.yml lines 152-186, 311-325, 448-471) and pass without testing anything.

**What it missed.** The MDM generator is only exercised by `tests/deploy-harness-mdm` (not in CI, C2) and by pre-push step 7 on a developer machine. Mission INCIDENT markers found by hand: "build-deploy inlines aitools-lib but not its sibling resolver ... no check catches it"; "The committed dotprofile deploy/ (825aed4 blobs) is stale versus main: 42 vs 50 files"; "build-deploy.sh exits 0 on every skip (node missing, no dotprofile, resolver error) ... a CI or package build cannot tell a skip from a build". deploy-paths.md: "Renaming a section heading or rewording those lines fails the build loudly", but in CI the build never runs, so it cannot fail.

**Root cause.** The build target moved to the dotprofile repo (#32, closed 2026-10-03), and CI kept the old steps. build-deploy treats "no dotprofile" as a skip with exit 0.

**Remedy.**
1. **Fixture:** `tests/fixtures/dotprofile/` with `profile.json` (v2, two id-keyed profiles), `claude/CLAUDE.md` (with `{{PLACEHOLDER}}` tokens), `claude/rules/user1.md`. `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` already builds a git fixture this way (lines 59-71); move that into a shared helper.
2. **Script:** `scripts/check-deploy-build.sh` (and `.ps1` twin, or a documented bash-only exemption like build-deploy): copy the dotprofile (fixture in CI, `git archive HEAD` of the real one locally) to a temp dir, run build-deploy with `env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS HOME=<tmp> AITOOLS_USER_REPO_PATH=<copy>`, fail if `<copy>/deploy` was not built, then the dry-run smoke of the resolver consumers. This is the body of pre-push step 7 (check-pre-push.sh:122-225) moved into one file; step 7 then calls it with the real dotprofile and also diffs against the committed `deploy/`.
3. **CI step** (macos and linux jobs; windows via Git Bash): `bash scripts/check-deploy-build.sh --fixture tests/fixtures/dotprofile`. Delete the two dead steps ("Build deploy scripts", "Check deploy drift") or keep the drift check only until `aitools/deploy/` is deleted.
4. **build-deploy flag:** `--require-dotprofile` (exit 1 instead of 0 on any skip), used by the CI step and by build-package. The `aitools` loop keeps today's exit 0.

## C2. Suites CI never runs (FI-F4, FP-F6, handoff G16)

**Evidence.** `git show origin/main:.github/workflows/check.yml | grep tests/` lists only `tests/logging`, `tests/managed-files`, `tests/profile/*`. Not run: `tests/deploy-harness/test-deploy-harness.sh`, `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`, `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`, `tests/build-package/test-cli.sh`. None of the 19 open PRs adds them (`pr-ci-diff.sh`: the open PRs add only `test-adopt-push`, `test-claude-mdm`, `test-install`).

**Verified on origin/main bc4aad1 today** (`run-nonci-suites.sh`, macOS, isolated HOME):

| Suite | Result | Time |
|---|---|---|
| test-deploy-harness.sh | 45 passed, 0 failed, 0 skipped | 19 s |
| test-deploy-harness-mdm.sh | 30 passed, 0 failed, 0 skipped | 80 s |
| test-rules-fanout-cursor.sh | 78 passed, 0 failed, 1 skipped | 8 s |
| build-package/test-cli.sh | 32 passed, 0 failed | 0 s |

So they can be added as required steps today with no red to fix first (Linux and Windows unverified).

**Remedy.**
- **CI steps** (macos + linux, then windows via Git Bash in the observe job of C3): `bash tests/deploy-harness/test-deploy-harness.sh`, `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`, `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`, `bash tests/build-package/test-cli.sh`; plus `AITOOLS_TEST_BASH=/bin/bash /bin/bash ...` runs on macOS for the two deploy-harness suites (MDM endpoints may run the system bash 3.2: unknown, confirm with the BUILD-PKG design).
- **One suite list (stops check.yml merge conflicts, FP-F5).** Five open PRs edit check.yml (#103, #112, #113, #115, #116), and #116's conflict in it is one of the two the brief names. Add `tests/suites.txt` (one line per suite: path, platforms, `bash32` flag) and `tests/run-suites.sh <platform>` that runs every listed suite and prints a pass/fail table. Each job runs `bash tests/run-suites.sh macos|linux|windows`. A new suite is one line in a list, not three YAML hunks.
- **Unit test of the list:** `tests/run-suites.sh --check` fails when a `tests/**/test-*.sh` or `test-*.ps1` file is not in `tests/suites.txt` (no suite can be forgotten again).
- **Isolation hazard to fix while adding them.** `test-deploy-harness-mdm.sh:78` runs `HOME="$hb" bash scripts/build-deploy.sh` without `env -u AITOOLS_USER_REPO_PATH`. An exported `AITOOLS_USER_REPO_PATH` (the entry points export it since #86, per the PR #95 INCIDENT) would point that build, which deletes and rebuilds `<dotprofile>/deploy`, at the real dotprofile. CI is safe (unset); a developer shell after `aitools` may not be. Fix: `env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS` on that line, as check-pre-push.sh:143 already does.

## C3. Windows runs almost none of the M3 suites (NEW)

**Evidence.** The windows job (check.yml:330-471) runs: bash and pwsh syntax, logging (bash + pwsh), managed-files (bash + pwsh), one inline resolver smoke (machine-id, hostname, register, user-repo-path, setup-user-config), build, drift. It does not run `tests/profile/test-profile.sh`, `test-config.sh`, `test-lib.sh` or `test-user-init.sh`, which carry the pwsh parity cases. Managed-file tests skip on Windows: "SKIP read-only cases (chmod does not block writes on this platform)", "SKIP interactive cases (no python3 pty on this platform)" (run 39888735993; issue #72 open). `git log origin/main --since=2026-10-20 --format=%B` has 49 lines saying Windows was not run. Handoff 2026-10-22 G7: "nothing from this session has run on Windows".

**What it would have caught.** The only Windows-specific bug that reached CI did so because #103 added its suite to the windows job: run 39888735993 failed 4 asserts on `C:\Users\RUNNER~1\AppData\Local\Temp\...` versus the POSIX path the test expected (fix c05fec8 "Expect display_path form of the dotprofile in adopt-push ACTION asserts"). The profile suites have the same pattern (they assert on temp paths in messages) and have never run there.

**Remedy.**
- **CI job `windows-extended`** (shell: bash, Git Bash): `bash tests/run-suites.sh windows-extended` with test-profile, test-config, test-lib, test-user-init (pty cases auto-skip), test-adopt-push, deploy-harness. Ship it with `continue-on-error: true` (observe; the job shows green and does not block merges), fix what fails, then remove `continue-on-error` and make it required (enforce). This is the hook-rollout observe/enforce cycle applied to CI. Expect path-form failures first.
- **Issue #72 (PS1 menu on Windows):** a pwsh-only in-process test: `[Console]::SetIn([IO.StringReader]::new("a`n"))`, force the interactive branch with a test switch, call `Prompt-DiffReview`, assert the adopt result and the repo write. Needs a small seam in aitools-lib.ps1 (how the menu decides it has a terminal). Proposal only: the seam's shape is unknown until someone reads `Read-ConsoleChoice`.

## C4. The five CI-only failure classes (all 11 failed runs since 2026-10-22)

| Class | Runs | What failed | Fix commit | Why local runs passed |
|---|---|---|---|---|
| a. Test mode CI uses but the author did not | 39890650263, 39891264259, 39891714493 (#108) | macOS `/bin/bash 3.2 --bash-only`: `FAIL a78-exc-ro`, `FAIL a8-mig-ro` (real PID where `<pid>` was expected) | dbcc61a: "case_fresh skipped the NORM_TMP normalisation (it ran only inside the parity block)" | Author ran with pwsh parity; CI's bash-only step takes another path. Three red pushes in 12 minutes |
| b. git default branch | 39873612279 (#86) | `error: src refspec main does not match any` in test-user-init, macOS and linux | f473e55: "the runner's init.defaultBranch is master" | Author's global gitconfig sets `init.defaultBranch=main` |
| c. Windows path form | 39888735993 (#103) | 4 asserts, `C:\Users\RUNNER~1\...` vs POSIX path | c05fec8 (display_path form) | No local Windows |
| d. Runner shell wrapper | 39720365900 (#73) | Windows step exit 1 after all checks passed | d977807: the runner appends `exit $LASTEXITCODE` to pwsh steps | Not reproducible without the runner wrapper |
| e. pty/terminal driver behaviour | 39719101997, 39719152527 (#68) | Linux pwsh `FAIL EOF at the menu: overwrite` (60 s timeout) | 435a7aa: "pwsh on Linux does not end [Console]::ReadLine on a \x04" | Passed on macOS |
| f. Knowingly red batch (C12) | 39859094088, 39861809999, 39861915512 (#86) | test-config `FAIL c1-fresh/c2-verified/c3-upgrade/c8-dry-run` | later #86 batch 4 (c1ca81e/e1743ec) | 3ce5850 body already said "Still failing ... test-config.sh 85/4" |

June 2026 (6 runs, 27508321406 .. 27527054612): all "Check deploy drift" on push to main (deploy/ not regenerated). That class ended when deploy/ was frozen, and C1 shows the step now checks nothing.

**Remedies.**
- **Local runner that matches CI:** `tests/run-suites.sh local` (from C2) runs every suite in every mode CI uses on this platform: on macOS both `bash` (5) and `AITOOLS_TEST_BASH=/bin/bash /bin/bash ... --bash-only`, with `GIT_CONFIG_GLOBAL=<empty temp file>` and `GIT_CONFIG_NOSYSTEM=1` so the developer's gitconfig cannot hide class b. Pre-push step (new step 11, or folded into step 1): run `tests/run-suites.sh local --changed` for the suites whose sources the push touches (a map in `tests/suites.txt`), and all suites when `scripts/aitools-lib.*` changes. This closes a, b and f before the push.
- **Unit test helpers** in a shared `tests/lib/assert.sh`:
  - `git_init_main <dir>` / `git_init_bare_main <dir>`: `git init -q -b main` (git 2.28+) for every fixture repo; a lint in `run-suites.sh --check` fails on a bare `git init` in `tests/` (class b).
  - `assert_path_msg <expected-posix-path>`: compares after normalising both sides through the lib's `display_path` (and `cygpath -m` on Git Bash), so a test cannot hard-code one path form (class c).
  - `norm_tmp`: replaces temp-file PIDs and mktemp suffixes in captured output, applied to every captured run, not only inside the parity block (class a).
  - `read_lf <file>`: strips `\r` before line-anchored matching, for `.ps1` files that check out CRLF (handoff I: "line-anchored grep/perl patterns in tests silently miss them").
- **Rule (class d):** check.yml pwsh steps that expect a non-zero native exit end with `exit 0` and a comment, as d977807 did; add the runner behaviour to `reference/tool-ops-*.md` or the CI comment block (it is in the commit body only).
- **Rule (class e):** interactive pty cases run only on the platform whose users reach that path, and each skipped case names the issue that tracks the gap (#72). A `SKIP` line without an issue number fails `run-suites.sh --check` (FI-F5: a skipped group counts as a pass).

## C5. Stale green and no required checks (FP-F4, FI-F1)

**Evidence.** `gh api repos/nobul-tech/aitools/rulesets/16468370`: rules `deletion`, `non_fast_forward`, target `~DEFAULT_BRANCH`. `branches/main/protection`: 404 "Branch not protected". Repo settings: `allow_auto_merge: false`, `allow_update_branch: false`, `allow_squash_merge: true`, `allow_rebase_merge: true`, `delete_branch_on_merge: false`. All 18 open PRs except #106 last ran CI on 2026-10-23 (`pr-files.txt`); main has moved since (9923a3c Backup-File, 8e490d7 step 7, #99 merge 3c4f8fe, bc4aad1). #102 shows `CodeQL: NEUTRAL`.

**Remedy (GitHub settings, commander-owned):**
- Ruleset 16468370 gains `required_status_checks` (`macos`, `linux`, `windows`, later `windows-extended`, `base-guard`, `review-verdict`) with `strict_required_status_checks_policy: true` (head must contain main), and `pull_request` with allowed merge methods `merge` only (A1: merge commits only).
- Repo: `allow_update_branch: true` (lets `gh pr update-branch <n>` merge main into the head with no rebase or force-push), `allow_squash_merge: false`, `allow_rebase_merge: false`, `allow_auto_merge: true` (then `gh pr merge <n> --merge --auto` waits for green itself). Keep `delete_branch_on_merge: false` until the stacks have merged (A1 "keep the branches").
- Merge queue: the repo is public and org-owned, where GitHub offers merge queues (from GitHub docs as I know them; not verified today). It would replace the mission's update-branch / wait / merge loop with one queue that tests each PR on top of the previous one.
- **Process for this mission (until the settings change):** per PR, `gh pr update-branch <n> -R nobul-tech/aitools`, `gh pr checks <n> --watch --interval 30`, re-query `mergeStateStatus` until it is not UNKNOWN, merge on CLEAN. Open question Q3 below on NEUTRAL.

## C6. Stacked PRs got no CI at all (verified)

**Evidence.** check.yml:15-16 `pull_request: branches: [main]` filters on the base branch. `gh pr view 74`: base `fix/registry-paths`, `statusCheckRollup: []`, merged 2026-10-22T04:24:16Z; `gh pr view 75`: base `feature/user-level-skills`, `statusCheckRollup: []`. So the two PRs that "merged off main" (handoff D.2) also never ran a single check.

**Remedy.**
- **CI trigger:** `pull_request:` with no `branches` filter, so every PR runs CI whatever its base.
- **CI job `base-guard`** (ubuntu, seconds): fails when `github.base_ref != 'main'`, with the message "retarget to main before merging (stacked PRs merged into stale bases: #74/#75)". Required (C5), so a stacked PR cannot merge into another branch. Its first line: `if [ "${{ github.base_ref }}" != "main" ]; then echo "::error::base is ${{ github.base_ref }}, not main"; exit 1; fi`.

## C7. Check scripts are not in CI; standing FAILs hide real ones (FI-F7/F8, FP-F7)

**Evidence.** check.yml never runs `check-pre-commit`, `check-pre-push` or `check-post-push`. The mission packet section 4 lists "Known pre-existing failures (record, not blockers)": pre-commit step 6, pre-push step 7, pre-push step 3. 5 commit messages since 10-20 cite "known FAIL(s)". Repo-wide steps that would pass in CI today, verified on bc4aad1: step 20 (`check-path-refs.py`: "dead path references: 0"), hook parity ("18 hooks", rc 0, already on linux only). Step 6 would fail on exactly one file: `100644 ... harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh`.

**Remedy.**
- **Fix the standing FAILs first** (FP/FI already list them): `git update-index --chmod=+x harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh`; step 3 `[\s]` -> `[[:space:]]` in check-pre-push.sh:70 only (C8); step 7 clears with the A4 rebuild.
- **`--ci` mode for check-pre-commit.sh/.ps1:** run only the steps that are repo-wide and need no dotprofile or staged files (6 exec bit, 14 build prereq, 15 deprecated terms, 16 capability bypass, 17 hook portability, 19 schema file, 20 path refs), against all tracked files. **CI step** on linux (and the `.ps1` on windows): `bash scripts/check-pre-commit.sh --ci`. FI-F8 notes this would also have caught the step-16 parity drift.
- **Known-fail list with expiry** (alarm fatigue): `scripts/check-known-fails.txt`, lines `step<TAB>reason<TAB>owner<TAB>expires YYYY-MM-DD`. `step_fail` prints `KNOWN` instead of `FAIL` while a matching line is unexpired and turns back to `FAIL` after the date; `print_summary` lists KNOWN rows. Replaces the packet's prose list, which every delegate has to re-read.

## C8. Check-script parity gaps (NEW)

**Evidence.**
- `check-pre-commit.ps1` defines steps 1-16 and 20 (grep of its `Step*` calls); `check-pre-commit.sh` defines 1-20. Missing in `.ps1`: 17 hook portability, 18 Python syntax, 19 harness DB schema file. 17 may be intentionally bash-side (hooks run in bash), but 18 and 19 are platform-neutral. Whether this is intended is unknown; no exemption is documented.
- Step 3 secret scan: `.sh:70` `[\s]*[=:]` (POSIX ERE: `\` or `s`, so `tokens:` matches and `token =` does not), `.ps1:71` `\s*[=:]` (.NET regex: whitespace, correct). FI line 163 says to fix "the `.ps1` twin" too; only the bash side is wrong.

**Remedy.**
- **Unit test `tests/checks/test-check-parity.sh`:** extract the step numbers from each `.sh`/`.ps1` pair of `check-*` scripts (`step_(pass|fail|warn|skip) "N"` vs `Step(Pass|Fail|Warn|Skip) "N"`) and fail on a difference not listed in a `# parity-exempt: N reason` header line.
- **Unit test `tests/checks/test-pre-push-patterns.sh`:** feed fixture diff lines to the step 3 pattern in both languages (`+token = abc`, `+api_key: x` must match; `+tokens: 3`, `+  secrets_found=$(...)` must not) and to step 2's blocklist (`shared/rules/scratch.md` must not match: the false positive one INCIDENT marker records). Needs the patterns moved into variables a test can source, or the test greps them out of the scripts.

## C9. Syntax checks cover only part of the tree, only under bash 5 (NEW)

**Evidence.** check.yml loops: bash `scripts/*.sh scripts/githooks/pre-commit deploy/*.sh shared/hooks/*.sh`; pwsh `scripts/*.ps1 deploy/*.ps1`; python `scripts/*.py`. Not covered: `packaging/**` (BUILD-PKG, new today: `packaging/macos/aitools-pkg-run.sh`, `packaging/windows/*.ps1`), `shared/shell/aliases.sh/.ps1`, `tests/**/*.sh/.ps1`, `shared/hooks/intelligence-stop.py`, `tests/managed-files/pty-run.py`, `scripts/aitools-json.pl` (no `perl -c`). The macOS pwsh loop sends parser output to `2>/dev/null` and prints only the file name. Bash syntax runs under Homebrew bash 5 only, while the user rules require bash 3.2 compatibility; only the four profile suites run under `/bin/bash`.

**Probe on bc4aad1** (`probe-main.sh`): `/bin/bash -n` on all 89 tracked `.sh` outside `harvesting/` and `.aitools/`: 0 failures. pwsh parser on the 8 `.ps1` CI skips: 0 failures. `perl -c scripts/aitools-json.pl`: syntax OK. `py_compile` on the 3 skipped `.py`: ok. So widening is free today.

**Remedy (CI steps):** loop over `git ls-files '*.sh' ':!harvesting' ':!.aitools'` (bash -n, plus `/bin/bash -n` on macOS), `git ls-files '*.ps1' ':!harvesting'` (parser, print the parser messages), `git ls-files '*.py'` (py_compile), `git ls-files '*.pl'` (`perl -c`). Driving the loops from `git ls-files` means a new directory is covered without a YAML edit.

## C10. Hooks have no smoke test in CI (NEW)

**Evidence.** `.claude/rules/hook-rollout.md` "Pre-deploy verification" requires a clean-input smoke test and a violation test, because `bash -n` passed while the hook crashed on every call (I12). CI runs only `bash -n` on `shared/hooks/*.sh`. Probe on bc4aad1: standing-order-guard clean input exit 0, `git status && git log` exit 2.

**Remedy.** **Unit test `tests/hooks/test-hooks.sh`:** for every hook in `shared/hooks/hooks-manifest.json`, run it with a minimal valid JSON input for its event under an isolated HOME and assert exit 0 and no `unbound variable` on stderr; for standing-order-guard, assert exit 2 on each violation form hook-rollout.md lists (`&&`, `||`, `;`, `$()`, backticks, 4+ lines, `rm` with a glob, `cat` outside a pipeline, the #82 `sed` near-miss forms) and exit 0 on each exemption (`sed -n '60,75p' file`, `pwsh -Command` with `;`). **CI step:** on all three jobs (hooks run in Git Bash on Windows; cross-platform.md "Hook portability").

## C11. `scripts/githooks/pre-commit` would run build-deploy against the real HOME (NEW)

**Evidence.** origin/main `scripts/githooks/pre-commit`: when `shared/` or `scripts/build-deploy.sh` is staged it runs `bash scripts/build-deploy.sh` and `git add deploy/`. `scripts/init-hh-hooks.sh:8` enables it (`git config core.hooksPath scripts/githooks`). Since the build target moved, build-deploy resolves the real dotprofile (deploy-paths.md: "it takes the dotprofile from `AITOOLS_USER_REPO_PATH`, else from the resolver"), and it deletes and rebuilds `<dotprofile>/deploy/` (handoff F.1, #86). An agent commit in any worktree of a clone with the hook enabled would trigger that; `git add deploy/` stages the frozen aitools `deploy/`. Not enabled here (`git config --get core.hooksPath` exit 1). Whether it is enabled on the Windows workstation: unknown.

**Remedy (code fix):** delete the hook and `init-hh-hooks.sh`, or replace the hook with a call to `check-pre-commit.sh` (read-only). After A4 (backup + temp build + swap) the hazard shrinks but the hook still writes the real dotprofile from an agent's commit.

## C12. No rule that each pushed batch keeps CI green (INCIDENT in mission files)

**Evidence.** Two unfiled markers in the mission folder: "the stack has no rule that each pushed batch keeps CI green, or that a deliberately red CI is declared. b70fc64 landed with the macos/linux CI red and the commit message did not call it a CI failure (M1)" and "(reviewer) no rule says each pushed batch keeps CI green". Runs 39859094088 (b70fc64), 39861809999 (3ce5850), 39861915512 (c78bf12) are red on the same 4 test-config cases.

**Remedy (rule, user-scope delegation rule or script-standards):** "A pushed commit keeps CI green. When a batch must push red (usage limits, D-DEL4 "commit and push after every batch"), its commit body carries `CI: red-expected (<suite> <n> failing, fixed by <batch/PR>)`." **CI support:** the `review-verdict` job (C14) or a small `ci-declared-red` step reads the head commit body; reviewers then know the red is declared. The pre-push runner (C4) prints the line to paste.

## C13. Every push pays a 3-OS CI run, docs included (FS-S11)

**Evidence.** Last 24 green CI runs: 548 to 1177 s (pull_request runs 603-1177 s, push 548-686 s). Channel-exception commits run the full matrix: 40416825997 "Add MERGE-ALL mission brief v1.0" (638 s), 40415865053 and 40415470079 (BUILD-PKG docs, 666 s and 612 s). A6 (main CI after every merge) times 19 merges at roughly 3.5 h of serial waiting, plus the update-branch re-runs on each PR.

**Remedy (CI config):**
- `push: paths-ignore: ['.aitools/channel/**', 'plans/**', 'harvesting/**']` on the push trigger only (those paths go direct to main and have no PR; required checks apply to PRs, so ignoring them on push cannot block a merge).
- `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: ${{ github.event_name == 'pull_request' }} }`: a new push to a PR cancels its superseded run.
- Do not put `paths-ignore` on `pull_request` while the checks are required: a skipped required check stays pending and blocks the merge.

## C14. Review verdicts are not bound to the head SHA (FP-F2/F3)

**Evidence.** #111: head 8caa79e; the PR's only comment: "8caa79e fixes re-verify finding N6 ... the reviewer has not re-checked this commit." Handoff I: "Four PRs were merged before their reviews were addressed (#56, #58, #76/#77, #79)". Verdicts live in mission files and PR comments, and GitHub refuses `--approve` from the same account.

**Remedy.** **CI job `review-verdict`** (pull_request, `issue_comment` and `synchronize` events): find the newest PR comment that starts with `Verdict:` (`gh pr view $N --json comments,headRefOid`) and pass only if it says `APPROVE` and names the current head SHA (7+ hex chars), else fail with "no verdict for <sha>". Made required (C5), it blocks a merge at an unreviewed SHA. A merge-from-main commit made by `update-branch` changes the head, so the job accepts a verdict whose SHA is the head's first parent when the head is a merge of origin/main (FP F2 describes the same exemption).

## C15. Release notes drift (FP-F15)

**Evidence.** Pre-push step 5 and pre-commit step 9 only warn ("non-docs changes without RELEASE_NOTES.md"). RELEASE_NOTES.md tops out at "v0.73.3 ... (2026-10-03)" (line 15), last commit 075c3da; latest tag v0.73.2; none of the 19 open PRs touches it (`pr-files.txt`). The RELEASE mission has to rebuild three weeks of notes from commit and PR messages (A3/A5).

**Remedy.** A `## Unreleased` section at the top of RELEASE_NOTES.md, and a `Release note:` line required in every non-docs PR body. **CI step** (pull_request): fail when the PR changes files outside `*.md`, `.aitools/`, `plans/`, `harvesting/` and its body has no `Release note:` line (or `Release note: none`). The release orchestrator then collects the lines (`gh pr list --state merged --search "merged:>2026-10-03" --json body`). Avoids per-PR conflicts in RELEASE_NOTES.md itself.

## Priority (smallest change, biggest effect)

1. Fix the three standing FAILs (C7) and add the four green suites (C2) and the widened syntax loops (C9): no red to fix first, verified today.
2. `base-guard` + unfiltered `pull_request` trigger (C6) and `paths-ignore`/`concurrency` (C13): YAML only.
3. Ruleset: required checks, strict, merge-commit only, update-branch and auto-merge on (C5): commander's settings change; makes "green and CLEAN" mean something.
4. `tests/suites.txt` + `run-suites.sh` with CI-matching local mode and test helpers (C2, C4): ends check.yml conflicts and the a/b/f classes.
5. Fixture dotprofile + `check-deploy-build.sh` (C1); `windows-extended` observe job (C3); hook smoke tests (C10).
6. `review-verdict` (C14), release-note line (C15), parity tests (C8), the githook (C11), the CI-green rule (C12).

## INCIDENT markers (not filed)

- INCIDENT: check.yml "Build deploy scripts" builds nothing in CI (`No dotprofile found ... skipping deploy build`, exit 0) and "Check deploy drift" checks the frozen `aitools/deploy/`, so CI never exercises the MDM generator. Spec: deploy-paths.md "Dual Deployment Paths" (both paths must produce equivalent results). Severity high (silent false pass).
- INCIDENT: `scripts/githooks/pre-commit` (enabled by `scripts/init-hh-hooks.sh`) runs `scripts/build-deploy.sh` against the real HOME on a commit touching `shared/`, against handoff F.1 / #86, and stages the frozen `deploy/`. Severity high if enabled anywhere (unknown).
- INCIDENT: `check-pre-commit.ps1` lacks steps 17, 18 and 19 of the `.sh`, with no documented exemption (cross-platform.md "Platform targeting principle"). Severity medium.
- INCIDENT: `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh:78` runs build-deploy with HOME isolated but `AITOOLS_USER_REPO_PATH` inherited; with it exported, the test would rebuild the real dotprofile `deploy/`. Severity medium (CI unaffected).
- INCIDENT: PRs whose base is not main get no CI (`pull_request: branches: [main]`); #74/#75 merged with empty check rollups. Severity high (already the root of handoff D.2).
- INCIDENT: the macOS pwsh syntax step sends parser errors to `2>/dev/null` and prints only file names (check.yml:79-83); a failure shows no line or message in the macOS log. Severity low.

## Open questions (each with a suggested answer)

- Q1. Add the four green suites (C2) and the widened syntax loops (C9) to check.yml before the merges or after? Suggested: after the last merge, in the friction plan's first PR; adding steps now changes every open PR's required set mid-sequence and re-opens check.yml conflicts.
- Q2. Change ruleset 16468370 (required checks, strict, merge-commit only) during MERGE-ALL? Suggested: after the 19 merges; with strict on, every one of the 19 PRs needs update-branch plus a full CI run first anyway, which the mission does by hand.
- Q3. #102 shows `CodeQL: NEUTRAL`. Is NEUTRAL "green" for the merge gate? Suggested: yes for CodeQL (no alerts to judge on a docs/JSON PR), and `mergeStateStatus` CLEAN decides.
- Q4. `windows-extended` as observe (`continue-on-error`) or required from day one? Suggested: observe until one green run, then required; required from day one would block the friction-plan PR on Windows path-form fixes nobody has seen yet.
- Q5. Keep `scripts/githooks/pre-commit`? Suggested: delete it and `init-hh-hooks.sh`; nothing references them except each other.

## Provenance

Runs: 39891714493, 39891264259, 39890650263, 39888735993, 39873612279, 39861915512, 39861809999, 39859094088, 39720365900, 39719152527, 39719101997, 27527054612, 27526218071, 27523210139, 27522676750, 27522251437, 27508321406, 40415865053 (build log). Commits: dbcc61a, c05fec8, f473e55, d977807, 435a7aa, 3ce5850, bc4aad1 (origin/main probed). PRs: #74, #75, #86, #103, #108, #111, #112, #113, #115, #116 and the 19 open PRs' file lists. Scripts and outputs in `/Users/new-jose/repos/aitools/.scratch/session-ma-fci/` (failed-runs.sh/.txt, pr-files.sh/.txt, pr-ci-diff.sh/.txt, probe-main.sh, parse-list.ps1, run-nonci-suites.sh, suite-logs/). Linux and Windows results for C2 are unverified (macOS only).
