# S3-FanoutImpl-CI hand-back (FO-0)

Version 1.1, 2026-10-27, by S3-FanoutImpl-CI (level 2) for S3-FanoutImpl.
Version 1.1 adds the FO-0b follow-up below. Sections after it are from v1.0.

## v1.1: FO-0b follow-up (the S3-FanoutImpl message)

- Head **dbe8f46**. CI run **40442790737**: green on macos, linux and windows. Every step passed, including deploy-harness-mdm, claude-mdm on bash 5 and on 3.2, Build deploy scripts and Check deploy drift. The earlier head e4096d8 was also green (run 40441806471).
- **#120 is merged in with `--no-ff` twice.** The first merge was at 978e72d, as the message asked. #120 then moved to 1d37d93 (cdad49f is review fixes, followed by a merge of main), so I merged it again. #117 contains #120's head, so #120 merges first.
- **I also merged origin/main c412377 into the branch.** GitHub reported #117 as CONFLICTING (mergeable_state dirty). Because of that, the CI workflow did not run on 57c9dd7. Locally the merge with main was clean (ort), and the branch had 3 merge bases with main (03b833f, 2419d23, 1692959). After this merge, GitHub reports it MERGEABLE.
- **deploy-harness-mdm** now has steps in the macos and linux jobs. Its `%exempt` entry is removed, so the exempt list is empty. Local results with #120 1d37d93:
  - deploy-harness-mdm: 65 pass, 0 fail (bash 5 and 3.2)
  - claude-mdm: 34 pass, 0 fail (bash 5 and 3.2)
- **Review finding 1:** the coverage step's comment now lists its blind spots: single-line `run:` only; a run in any job counts; `if:` is ignored; `bash <path>` can appear anywhere on the line before `#`; it covers test-*.sh only.
- **Review finding 3:** the coverage step now has a single copy, in the linux job. The macos job has a comment pointing to it. I did not use a YAML anchor, because Ruby 3.1+ `YAML.load_file` refuses aliases. That would break the plan's YAML parse check (local Ruby is 2.6, so the break would not show locally).
- **Review finding 5:** added `if: ${{ !cancelled() }}` to the claude-mdm macOS 3.2 step.
- **Findings 2, 4 and 6** are listed as follow-ups in the PR body.
- I re-ran the coverage test from the parsed YAML:
  - There is exactly 1 copy, in the linux job.
  - It passes on the tree: 14 suites, none exempt.
  - It fails, as it should, on: a removed step, a new suite, an exempt suite that is run, a stale exemption, a path that appears only in a comment.
  - It passes on an exempt suite that is not run.
- check-pre-push: only step 7 FAILs. The cause is the known stale dotprofile `deploy/`; the rebuild itself now succeeds.

## Summary

1. PR #117 adds 5 suites that were not in CI to `.github/workflows/check.yml`: b8-consumers, deploy-harness, hookin, rules-fanout-cursor and build-package.
2. It also adds a step called "Every test suite is in CI" to the macos and linux jobs. The step is inline perl. Its exempt list holds one suite, deploy-harness-mdm.
3. deploy-harness-mdm fails on the base because `deploy/deploy-harness.ps1` is 202519 bytes. That is over the Intune 200000-byte guard added by PR #111.
4. The same failure breaks `tests/claude-mdm`, which was already in CI. So the macos and linux jobs are red on that existing step and on nothing else.
5. Every FO-0 step passes in CI on all 3 jobs (run 40436962004). The windows job is green.

## PR

- URL: https://github.com/nobul-tech/aitools/pull/117
- Branch `feature/fanout-ci`, from `feature/fanout-base` d7f6855; head **67badde** (commits 0764097, 67badde)
- Files changed: `.github/workflows/check.yml` only
- Review diff: `git diff d7f6855...feature/fanout-ci`

## Suite results

Local runs on macOS, worktree at d7f6855. Logs are in `/Users/new-jose/repos/aitools/.claude/worktrees/fo-ci/.scratch/session-foci/logs/`.

| Suite | bash 5 | /bin/bash 3.2 | CI macos | CI linux | CI windows |
|---|---|---|---|---|---|
| b8-consumers | 60/0 | 60/0 (`AITOOLS_TEST_BASH`) | pass (5 + 3.2) | pass | not added (macOS, Linux only) |
| build-package test-cli | 36/0 | 36/0 (`TEST_BASH`) | pass (5 + 3.2) | pass | pass |
| deploy-harness | 76/0 | 76/0 (runner only) | pass | pass | not added |
| hookin | 39/0 | 39/0 (runner only) | pass | pass | not added |
| rules-fanout-cursor | 164/0, 1 skip (dupcase, case-insensitive FS) | same | pass | pass | **fails**, removed |
| deploy-harness-mdm | 10/54, rc 1 | 10/54 | exempt | exempt | -- |
| claude-mdm (already in CI) | 21/13, rc 1 | 21/13 | **fail** | **fail** | -- |

- deploy-harness, hookin and rules-fanout-cursor have no bash selector. Their inner scripts run with whatever `bash` is first on PATH, so I added no /bin/bash 3.2 step for them.
- The FO-0 steps carry `if: ${{ !cancelled() }}`. Without it, the claude-mdm failure would skip every step after it and the new suites would never report. I did not change any existing step.
- Coverage step test (`.scratch/session-foci/test-coverage-step.sh`): I extracted the step from the parsed YAML of both jobs and ran it.
  - It passes on the tree: 14 suites, 1 exempt.
  - It exits 1 and names the path in each of 5 broken cases: a step removed, a new suite with no step, an exempt suite that also runs, an exempt suite no longer in the repo, and a path that appears only in a comment.

## Verification

- `ruby -e 'require "yaml"; YAML.load_file(ARGV[0])' .github/workflows/check.yml`: parses.
- `bash scripts/check-pre-commit.sh`: only step 6 fails. This is known: the harvesting file is 100644.
- `bash scripts/check-pre-push.sh`: only step 7 fails. This is known: the dotprofile `deploy/` is stale.
- CI runs:
  - 40435445568 (head 0764097): windows failed on rules-fanout-cursor; macos and linux failed on claude-mdm.
  - 40436962004 (head 67badde): windows succeeded; macos and linux failed on claude-mdm only, and every FO-0 step passed.

## Not run

- The Linux and Windows steps locally; they ran only in CI.
- Existing steps that ran after claude-mdm and have no `if:` were skipped in CI on macos and linux: Build deploy scripts, Check deploy drift, and on macos also Line ending audit, Cross-platform script pairing and the claude-mdm 3.2 step.

## WRITE_BLOCKED

None.

## INCIDENT markers

- INCIDENT: When the open PRs are combined (base d7f6855), `build-deploy.sh` exits 1 because `deploy/deploy-harness.ps1` is 202519 bytes, over the 200000-byte Intune guard from PR #111 (fdb5109). This breaks `tests/claude-mdm` (21/13), which was already in CI, and `tests/deploy-harness-mdm` (10/54). In CI it is red on PR #117, and by the same cause it should be red on any PR built on this base; I did not check them. Owner: MERGE-ALL or the deploy-harness owner (FO-2 adds more skills content, which will make the file larger).
- INCIDENT: The header of `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` says "Platform: macOS, Linux, Git Bash". On Windows Git Bash its manifest cases fail: `setup-user-cursor.sh`'s OS guard exits 1 with "This script is for macOS/Linux. On Windows, use setup-user-cursor.ps1 instead." (CI run 40435445568, windows job). Either the header is wrong or the suite needs to skip those cases on Windows. Owner: the PR #110 code.

## Open questions

- Q: Should claude-mdm stay in CI while it is red on the base? Suggested answer: yes. Removing it would hide a real failure, and it turns green once deploy-harness.ps1 is back under the guard. When that happens, the deploy-harness-mdm exemption must come out (the coverage step fails while the exemption stays once the suite is run).
- Q: Should the existing steps also get `if: ${{ !cancelled() }}`, so that one failing suite does not hide the others? Suggested answer: yes, in a follow-up. It is out of FO-0 scope because it changes existing steps.
