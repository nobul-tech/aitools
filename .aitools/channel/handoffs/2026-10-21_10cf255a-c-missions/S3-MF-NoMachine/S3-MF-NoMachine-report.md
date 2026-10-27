# S3-MF-NoMachine report: setup-user-config --no-machine / -NoMachine

**Intent**: **Purpose**: Record what mission S3-MF-NoMachine shipped (M3-FINISH item 2), how it was verified and reviewed, and what is left open. **Scope**: scripts/setup-user-config.sh/.ps1, tests/profile/test-config.sh, PR #98. NOT the caller change (S3-MF-Runner). **Audience**: S3-M3Finish, S3-MF-Runner, Jose.

## Summary

- PR: https://github.com/nobul-tech/aitools/pull/98, branch `feature/mf-config-no-machine`.
- Commits:
  - b5292fd: the flag and tests c22 to c22j;
  - a second commit: the review fixes (m2 wording, n4 cases c22k and c22l), the review file and this report.
- Files changed: scripts/setup-user-config.sh, scripts/setup-user-config.ps1, tests/profile/test-config.sh.

## Flag contract (stated in the PR body, "Contract change")

`--no-machine` / `-NoMachine` means the caller owns machine registration.

- **Written:** every other managed field.
- **Preserved:** `machineId` and `machineAlias` are never set and never deleted.
- **Not reported** for "no profile matches this machine" and "profile.json has no machine profiles":
  - no ERROR row and no ACTION row;
  - no section-3 ACTION;
  - those resolver messages, and any warning that names `aitools user init` or `aitools-profile migrate`, go to deploy.log at detail.
- **Exit code:** 0 for an unregistered machine alone.
- **Still reported:** an invalid profile.json, a missing dotprofile path, ambiguous matches, and bootstrap or validation errors.
- **Log:** one info line, `config: --no-machine: machine registration is left to the caller ...` (PowerShell writes `-NoMachine`).
- **Bad arguments:** the flag together with `--machine-id` / `-MachineId` or `--machine-alias` / `-MachineAlias` gives `ERROR|aitools config|bad arguments`, exit 1.
- **Caller duty:** pass the flag only for a machine the caller has found unregistered. The writer does not check this.
- **Unchanged:** the rest of the PR #86 contract.

## Verification (macOS arm64)

- **Syntax:** `bash -n` (bash 5 and /bin/bash 3.2) and the pwsh parser are clean (.scratch/session-mfnomach/syntax.sh).
- **test-config.sh with pwsh parity:** 269 passed, 0 failed (258 before c22k and c22l).
- **test-config.sh under /bin/bash 3.2, bash only:** 174 passed, 0 failed.
- **test-user-init.sh:** 200 passed, 0 failed (on b5292fd).
- **check-pre-commit:** 1 FAIL, step 6. This is the known pre-existing failure. Step 11 WARNs about an uncommitted change in the live dotprofile, which this mission did not touch.
- **check-pre-push under an isolated HOME:**
  - Without a userRepoPath: 0 FAIL.
  - With userRepoPath pointing at the dotprofile (step 7 checks a git-archive copy): step 7 FAILs. This is the known stale dotprofile `deploy/`; every generated file is listed.
- **CI on b5292fd:** all green (linux, macos, windows, CodeQL).

## Not run

- Windows / Git Bash.
- The claude-code-web environment.
- An end-to-end user init that passes the flag (that is S3-MF-Runner's change).

## Review

- **Reviewer:** S3-MF-NoMachine-Review, an independent general-purpose agent with no isolation.
- **Verdict:** approve. 0 blockers, 0 majors, 3 minors, 4 nits.
- **Review comment:** https://github.com/nobul-tech/aitools/pull/98#issuecomment-6355804455
- **Review file:** S3-MF-NoMachine-Review-pr98.md, in this folder.
- **Fixed:**
  - m2: the header and the help text now say the flag is only for an unregistered machine.
  - n4: added c22k (ambiguous match, still an ERROR) and c22l (dry run).
- **Left open, with suggested answers:**
  - m1: a v2 profile.json without a `profiles` object is still reported as invalid with the flag. The resolver uses one message for two states. Suggest splitting the message in a later resolver PR.
  - m3: some warnings that name no command are still counted, so the config row becomes WARN. There is still no ERROR or ACTION. Suggest leaving it.
  - n1, for S3-MF-Runner: decide the flag at scripts/aitools:998 (`machine_key` empty after the registration flow). Do not decide it at the writer call: lines 1010-1017 also empty `machine_key` when the owner is "config", and that machine is registered.
  - n2: an ambiguous match still shows the writer's ACTION. Suggest leaving it; it is a real profile.json problem.
  - n3: the derivation log line shows machine values that the flag does not write. Suggest leaving it.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- `INCIDENT:` (reviewer m1) aitools-profile.sh `resolve_machine` emits "profile.json is not v2 or has no profiles" for two different states. The writer therefore cannot tell a missing `profiles` object (an unregistered machine) from a non-v2 file.

## Delegates

- S3-MF-NoMachine-Review (general-purpose, no isolation).
