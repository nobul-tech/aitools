# S3-AbortDocs hand-back (mission ABORT-DOCS, 2026-10-26)

Delegated by Session Commander 10cf255a-c. Branch `feature/harness-hookin`,
PR #106 (https://github.com/nobul-tech/aitools/pull/106). Docs only, no code
changed.

## Summary

1. The code on #106 makes only an exit 2 from `deploy-harness` stop the run.
2. Exit 2 from any other setup script is an ERROR row and the run continues.
3. bash and PowerShell behave the same. No parity incident.
4. Five docs updated to say this; the protected edits are listed old -> new in the PR comment.
5. Two incidents flagged, not filed: the profile-mirror menu text, and an abort reported as a failure.

## Behaviour found (citations: file + function)

| Script that exits 2 | Installer | `aitools` sync (no args, `gitpull`) |
|---|---|---|
| `deploy-harness` | `scripts/aitools-install.sh` `run_harness_step` / `scripts/aitools-install.ps1` `Invoke-HarnessStep`: log "Step 8b: aborted by user ... install stopped (exit 2)", WARN `harness files` `aborted by user`, return 2; the top level renders the summary and `exit 2` (Steps 9-22 do not run). `scripts/aitools` / `aitools.ps1` install branch: installer rc 2 -> "Installer aborted by user at a review menu -- run stopped (exit 2)", summary, exit 2 | `scripts/aitools` `deploy_configs` + `deploy_abort` / `scripts/aitools.ps1` `Deploy-Configs` + `Invoke-DeployAbort`: WARN `harness files` `aborted by user`, `break`, return before the relay -> AGENTS.md mirror; the no-args and `gitpull` branches read `deploy_aborted` / `$script:deployAborted`, render the summary, exit 2 (gitpull tag step not reached). Both the macOS branch (relayed) and the Git Bash branch (`pwsh -File deploy-harness.ps1`) of `deploy_configs` do this |
| any other setup script | `validate_and_run` / `Invoke-ValidatedScript`: `log_error "<name> failed (exit 2)"`, ERROR `script failed (exit 2)`, continue | `deploy_configs` / `Deploy-Configs`: `log_error`, ERROR `script failed (exit 2)`, `errors++`, continue |

Also: `aitools user init` (both entry points) treats `setup-user-hooks` exit 2
as "user init: aborted by user" and exits 2. `scripts/bootstrap.sh` does not
distinguish exit 2 ("Installer reported issues", continues to `user init`);
`scripts/bootstrap.ps1` runs the installer with `powershell` and does not
check the exit code. The lib's `_managed_abort` / `Invoke-ManagedAbort` logs
`log_error "Aborted by user"` and `exit 2`.

## Files changed

- `.claude/rules/interactive-menus.md` (protected; "Abort" section, profile-mirror note)
- `.cursor/rules/interactive-menus.mdc` (protected twin)
- `reference/managed-file-deployment.md` (protected; "[x]abort")
- `reference/tool-support-decision-tree.md` (D-TS13 row, 7.4 note, 7.5 launch sites, section 10 rows)
- `plans/tool-support-and-machine-profile.md` (protected; T-Q3 Note column only, decision text unchanged)

Not changed: `agentic-standards.md` / `.mdc` (abort row is accurate), the
reference menu blocks ("stop this script (exit 2)" matches the lib), code
comments in `scripts/aitools` / `aitools.ps1` that say "abort ends the whole
run, T-Q3" (code, out of scope).

## Verification

- `bash scripts/check-pre-commit.sh`: 7 PASS, 12 SKIP, 1 WARN (step 11,
  dotprofile uncommitted), 1 FAIL (step 6, the harvesting file mode that was
  already failing)
- `bash scripts/check-pre-push.sh`: 6 PASS, 1 SKIP, 3 WARN, 0 FAIL

## Not run

No runtime abort tests: docs only. Windows behaviour was read from the code, not run.

## INCIDENT markers (not filed)

- INCIDENT: the profile-mirror menu prints `[x]abort    : stop the run`
  (`prompt_json_field_review` in `scripts/aitools-lib.sh`,
  `Prompt-JsonFieldReview` in `scripts/aitools-lib.ps1`), but
  `setup-user-settings` is never `deploy-harness`, so every runner continues
  with an ERROR row. Suggested fix: change the text to "stop this script
  (exit 2)" like the text-review menu.
- INCIDENT: a user abort in any `setup-user-*` / tool setup script is shown
  as ERROR `script failed (exit 2)` (plus the lib's `log_error "Aborted by
  user"`), so the summary reports a user choice as a failure. Suggested
  answer: accept it for now (commander kept #106's behaviour), or have the
  runners write WARN `aborted by user` for exit 2 and keep going.
- The code comments citing "abort ends the whole run, T-Q3" in
  `deploy_abort` / `Invoke-DeployAbort` are true only for deploy-harness.
  Low priority.

## WRITE_BLOCKED

None.
