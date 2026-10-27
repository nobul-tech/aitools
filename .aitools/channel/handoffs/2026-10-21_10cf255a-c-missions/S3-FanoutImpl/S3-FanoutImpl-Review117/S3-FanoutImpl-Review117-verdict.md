VERDICT: APPROVE

Independent review of PR #117 (FO-0, every test suite in CI) by S3-FanoutImpl-Review117 (level-2 reviewer under S3-FanoutImpl, Session Commander 10cf255a-c).

Scope: `git diff d7f6855...origin/feature/fanout-ci` at head 67badde. The only file is `.github/workflows/check.yml`. The red claude-mdm step is out of scope (the known Intune size gate, fixed by FO-0b).

## Summary

No blocking findings. Every suite the plan names for FO-0 is now invoked correctly on macOS and Linux. Each suite that has a bash selector also gets a /bin/bash 3.2 step. The "Every test suite is in CI" step fails when a suite is missing, when a suite is both exempt and run, when an exempt suite no longer exists, and when it finds no suites at all. `if: ${{ !cancelled() }}` does what it is meant to do: in run 40436962004 every new step ran and passed after the claude-mdm failure. The Windows choices match the suite headers and the CI evidence. The non-blocking items below are limits of the detector and follow-ups.

## CI evidence (run 40436962004, head 67badde)

- linux: steps 19-23 (b8-consumers, deploy-harness, hookin, rules-fanout-cursor, build-package) passed. Step 6 "Every test suite is in CI" passed. Step 18 claude-mdm failed (out of scope).
- macos: steps 25-31 passed, including b8-consumers /bin/bash 3.2 and build-package /bin/bash 3.2. Step 8 "Every test suite is in CI" passed. Step 23 claude-mdm failed. Step 24 (claude-mdm 3.2) and steps 32-35 were skipped.
- windows: all steps passed, including the new step 14, build-package via Git Bash.
- The claude-mdm failure is `[build-deploy] [error] deploy/deploy-harness.ps1 is 202519 bytes, over the Intune script limit (200000)`. That error matches the deploy-harness-mdm exemption reason word for word, so the exemption is justified.
- The cited Windows run 40435445568 (head 0764097) fails "Cursor rules fan-out tests (bash + pwsh parity, via Git Bash)" with `[setup-user-cursor] [error] This script is for macOS/Linux`. So dropping that suite from the Windows job is justified.

## Detector: local runs against the tree and mutated check.yml copies

I extracted the perl program from both jobs; the two copies are byte-identical. I ran it with the `git ls-files 'tests/*/test-*.sh'` list against each case below. The script is in the reviewer worktree, `.scratch/session-rv117/mutate.sh`.

| Case | rc | Result |
|---|---|---|
| T0 real tree | 0 | "All 14 test suites are in CI or exempt" (deploy-harness-mdm exempt) |
| M1 hookin removed from every job | 1 | error: not run |
| M3 hookin `run:` commented out | 1 | error: not run |
| M4 new suite with no step | 1 | error: not run |
| M5 exempt suite also run | 1 | error: run and also exempt |
| M6 exempt suite no longer tracked | 1 | error: stale exemption |
| M10 empty ls-files | 255 | die "no tests/*/test-*.sh found" |
| M11 only `test-cli.sh.old` run (prefix) | 1 | error: not run (the `(?:\s\|$)` anchor works) |
| M12 CRLF check.yml | 0 | pass (correct) |
| M7 suite run inside a `run: \|` block | 1 | **false positive** (it is run, but the check reports it missing) |
| M2 removed from the linux job only | 0 | passes: coverage is any job, not each job |
| M13 run only in the windows job | 0 | passes: same reason as M2 |
| M8 step has `if: false` | 0 | **false negative** |
| M9 `run: echo skip bash <path>` | 0 | **false negative** (contrived) |

YAML parses: `ruby -e 'require "yaml"; YAML.load_file(...)'` printed "YAML ok".

## Findings

1. **non-blocking: detector false positive and false negatives.** `.github/workflows/check.yml:139` and `:379` use the regex `/^\s*run:\s[^#\n]*\bbash\s+\Q$p\E(?:\s|$)/m`.
   - It only sees single-line `run:` steps. A suite started inside a `run: |` block is reported missing (M7). This fails loudly, so it is the safe direction, but the step comment should say "single-line `run:` only".
   - It does not see `if: false`, a disabled job, or a non-bash prefix (M8, M9).
   - It counts any job, so it does not enforce macOS and Linux each (M2, M13).
   - All of this is acceptable for a "cheap" check (plan FO-0). Suggestion: add one comment line listing these limits.
2. **non-blocking: `.ps1` suites are outside the detector.** At `:124` and `:364`, `git ls-files 'tests/*/test-*.sh'` skips `tests/logging/test-logging.ps1`, `tests/managed-files/test-managed-files.ps1` and `tests/managed-files/test-adopt-push.ps1`. All three are run today, and the plan scopes the check to `test-*.sh`, so this is in spec. A future pwsh-only suite would go unnoticed. Follow-up: extend it to `test-*.ps1` matched against `pwsh ... -File <path>`.
3. **non-blocking: the perl block is copied into two jobs** (`:116-154` and `:356-394`), so every exemption has to be edited twice. The check is static and the same on every platform, so one copy (linux) would be enough. If both stay, the existing "Same step in the ... job" comments are the only guard against drift.
4. **non-blocking: no bash 3.2 step for deploy-harness, hookin or rules-fanout-cursor.** Leaving them out is correct. These suites start the script under test with a plain `bash` from PATH: `tests/deploy-harness/test-deploy-harness.sh:107`, `tests/hookin/test-hookin.sh:138`, `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh:88`. A `/bin/bash` step would therefore test only the test harness under 3.2, not the scripts.
   - deploy-harness runs on macOS endpoints. Follow-up: add `AITOOLS_TEST_BASH` to these three suites, then add the 3.2 steps.
   - The b8-consumers 3.2 step (`:208-210`) also re-runs its pwsh cases, because the suite has no `--bash-only`. That costs time only.
   - build-package uses `TEST_BASH`, not `AITOOLS_TEST_BASH`, which matches its header (`tests/build-package/test-cli.sh:14`). Correct.
5. **non-blocking (optional, adjacent): the existing claude-mdm /bin/bash 3.2 step loses coverage while bash 5 is red.** That step (`:201-202`) has no `if: ${{ !cancelled() }}`, so it was skipped in this run. FO-0 put `!cancelled()` only on new steps, which is consistent with its scope. Adding it here, or in FO-0b, keeps 3.2 coverage visible.
6. **non-blocking: Windows has no fan-out coverage.** The comment at `:605-607` is accurate. But `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh:14` still claims "Git Bash", and the native `setup-user-cursor.ps1` fan-out never runs on a Windows runner. Follow-up: correct the header, and plan a native pwsh Windows step for the `.ps1` fan-out in FO-3/FO-5.
7. **non-blocking: the exemption has to be lifted explicitly.** The stale-exemption check fires only when FO-0b also adds a deploy-harness-mdm step. If FO-0b fixes the size but adds no step, the exemption stays and the suite is never run. Its reason text (sha d7f6855, 202519 bytes) would then be stale too. The FO-0b brief should require both: add the macOS and Linux steps, and remove both `%exempt` entries.

## What I did not run

- I did not run the added suites locally. CI on the PR head is green for all of them on three runners, and the plan's local-run gate belongs to the author.
- I did not run `check-pre-commit` or `check-pre-push`: the change is CI YAML only.
- I did not run deploy-harness-mdm: it calls build-deploy.sh, and CI already shows the failure.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
