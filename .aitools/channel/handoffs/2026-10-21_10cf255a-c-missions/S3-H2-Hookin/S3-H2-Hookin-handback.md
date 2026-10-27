# S3-H2-Hookin hand-back (2026-10-23)

## Summary

1. `deploy-harness` now runs as Step 8b of `aitools-install.sh` / `.ps1`, right after Step 8 (Node). The installer's own `~/.aitools/bin` step is removed: `deploy-harness` deploys the same three CLIs (scripts/deploy-harness.sh, its "bin" list).
2. In the `aitools` sync, `deploy-harness` is first in `deploy_configs` / `Deploy-Configs`, and `setup-user-config` is no longer in the list. `deploy-harness` runs the writer itself with the same bare arguments (scripts/deploy-harness.sh:99-115, .ps1:89-108), so the writer runs once per sync.
3. Exit codes:
   - 2 = `[x]abort` (D-TS13). The whole run stops (T-Q3/SD-5): the summary gets `WARN|harness files|aborted by user`, the summary is shown, and the run exits 2.
   - 1 = errors. The summary gets `ERROR|harness files|script failed (exit 1)` and the run continues.
4. Tests: `tests/hookin/test-hookin.sh` + `hookin-driver.ps1`, 38/38 on macOS. The PS1 functions were run under pwsh, with the real `deploy-harness` and a pty for the abort cases.
5. PR https://github.com/nobul-tech/aitools/pull/106 (branch `feature/harness-hookin`). Reviewer verdict: see below.

## Decisions (disciplined initiative)

- **D1: remove the writer from the loop.** I did not change `deploy-harness`, because S3-H2-Manifest owns it. The loop called the writer bare (scripts/aitools:1151+1172 and aitools.ps1:157+184 on main), which is the same call `deploy-harness` makes.
- **D2: keep the installer's Step 5.** It is the only place that passes the bootstrap flags, and `deploy-harness`'s writer needs them already written to config.json. As a result, `aitools install` runs the writer twice: once at Step 5 and once bare inside Step 8b, which normally reports `verified`. See open question Q1.
- **D3: only `deploy-harness`'s exit 2 ends the run.** The other loop scripts keep today's behaviour.
- **D4: the bash installer runs `bash -n` before Step 8b.** bash exits 2 on a syntax error, and without the check that would read as an abort.
- **D5: Git Bash on Windows runs `deploy-harness.ps1` unrelayed.** `scripts/aitools` on Git Bash calls it with plain `pwsh -File`. The PS1 review prompt is `[Console]::Write` output with no newline, so a bash line relay would hide the prompt.
- **D6: the installer exports `AITOOLS_RUN_ID`.** This gives `deploy.jsonl` one run id per install. The test checks it.

## Verification

- `bash tests/hookin/test-hookin.sh`: 38 passed, 0 failed, 0 skipped.
- `tests/deploy-harness`: 45/45.
- `tests/logging`: sh 24/24; ps1 15 passed, 5 skipped (Windows-only).
- `tests/profile/test-config.sh`: 190/190.
- `test-user-init.sh`: 200/200.
- `bash -n` and the pwsh parser pass on every touched script.
- `check-pre-commit`: the only FAIL is the known step 6. `check-pre-push`: 0 FAIL.
- Delegates: S3-H2-Hookin-BatchSh and S3-H2-Hookin-BatchPs applied the verbatim edits (plan-execution.md). I read the full `scripts/aitools` diff. After their report, I fixed the row wording for "exit 0 with error lines".

## Not run

- Either installer or `aitools` end to end against a real HOME.
- Any PS1 on Windows.
- The Git-Bash-on-Windows branch.
- The `main` call sites of the abort handling. I checked them by reading only.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- INCIDENT: `run_child_relayed` / `Invoke-ChildRelayed` (aitools-lib) log `"<label> failed (exit 2)"` at error level before the caller can see that exit 2 was a user abort. The abort is counted as an error. This is spec ambiguity against D-TS13 ("bare exit 2 = user abort").
- INCIDENT: reference/managed-file-deployment.md "[x]abort" says the installer continues with the next script after an abort. T-Q3/SD-5 say abort ends the whole run. Spec deviation.
- INCIDENT: D-TS13's bare exit 2 is ambiguous with other exit-2 causes. bash exits 2 on a syntax error or a misused builtin, and a `set -e` script dies with the failing command's code. All of these read as a user abort. Step 8b guards the syntax case only.

## Open questions (with suggested answers)

- **Q1: should `aitools install` run the writer once?** Suggested: add `--skip-config` / `-SkipConfig` to `deploy-harness` (S3-H2-Manifest), and Step 8b passes it.
- **Q2: should every loop script's exit 2 end the run?** T-Q3 suggests yes. Suggested: a follow-up PR, plus the reference/managed-file-deployment.md edit.
- **Q3: the abort skips the `aitools` self-update re-stamp and the relay-outbound prompt.** Is that acceptable? Suggested: yes, abort means stop.
- **Q4: PR #100 changes `deploy-harness`.** The "7 added" counts in tests/hookin may need updating after it merges. Suggested: whichever PR merges second rebases and adjusts.

## Reviewer verdict

S3-H2-Hookin-Review (independent delegate; it got only the PR, the packet and the intent): **not blocking**, 9 findings, all non-blocking (3 nits). Review: https://github.com/nobul-tech/aitools/pull/106#pullrequestreview-5623237089

- **Fixed in commit 2.** The `Invoke-DeployAbort` parameter `$ScriptName` hid the lib's `$scriptName`, so the abort line was logged as `[deploy-harness.ps1]` instead of `[aitools]`. I renamed the parameter to `$AbortedScript` and added a test. hookin now passes 39/39.
- **Left open:**
  - An abort is logged as two errors (the lib relay plus deploy-harness's own line). This needs a lib change (INCIDENT above).
  - The loop's syntax-error and missing-script rows say `deploy-harness` instead of `harness files` (nit).
  - `read-session-full.py` is mode 100644 in the repo, so its deployed copy is not executable. That was already true before this PR.
  - The `return 2` / `exit 2` wiring in `main()` is untested. One of the reviewer's 7 mutations, removing `return 2` in the no-args branch, survived.
- The reviewer reproduced hookin 38/38, also under /bin/bash 3.2, and deploy-harness 45/45.
