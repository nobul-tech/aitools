# S3-M3-B8c-Review: PR #90 (M3 B8c), commit 4b345cc

**Verdict: request changes.** One major, and the fix is small. The rest is sound: the #80 contract is used correctly, rc handling is right in both shells, nothing leaks into the PowerShell output stream, and the ait-harvest hardening does what the PR says.

Reviewer: S3-M3-B8c-Review (independent; I did not see the author's report). Scope: the diff of 4b345cc (`scripts/check-lib.sh`, `scripts/check-lib.ps1`, `scripts/ait-harvest.py`) and how the four check scripts use it.

Counts: blocker 0, major 1, minor 4, nit 3.

## Major

### M1. check-post-push step 5 now checks a different dotprofile than the harvester uses, and passes while archiving is off

- **Where:** `scripts/check-post-push.sh:115-147` and `scripts/check-post-push.ps1:134` onward ("Session archive readiness"), now fed by `resolve_config` / `ResolveConfig` (`scripts/check-lib.sh:162-171`, `scripts/check-lib.ps1:167-175`).
- **What changed:** step 5 is the check for session archiving, and archiving is done by `ait-harvest.py`. `read_config_user_repo` reads only config.json `userRepoPath`; the PR says so in its Follow-ups. Before this commit, step 5 used the same value. Now it uses the resolver's answer: env, then config, then convention, then scan. When config.json is stale, missing the key, or overridden by `AITOOLS_USER_REPO_PATH`, step 5 inspects a dotprofile the harvester never writes to.
- **Reproduced** (scratch `rv-step5.sh`, isolated HOME):
  - Setup: config.json `userRepoPath` points to a deleted directory, with `githubUser: t`. `~/repos/aitools-t/sessions/` holds a recent `.jsonl`, which is what you get after a `git pull` of sessions archived on another machine. settings.json has the session-archive hook.
  - New step 5: `[PASS] 1 archives, last within 7d`.
  - ait-harvest `read_config_user_repo()` returns `None` and logs `[warn] userRepoPath does not exist -- sessions not archived: .../gone`. Nothing is archived on this machine.
  - Old check-lib (4b345cc^) in the same HOME kept the dead path, `USER_REPO_PATH=[.../gone]`. Step 5 then gave the right answer: `[WARN] hook present but userRepoPath missing -- run aitools user init`.
- **Impact:** the PR's "stale config path -> convention" change makes the one check that watches archiving report PASS, or a misleading "hook may have stopped working", while archiving is off. The only signal left is a warn line in `ait-harvest.log`. script-standards.md "When analyzing code" applies: do not call a feature working when it is not operational.
- **Suggested fix (small, both shells):**
  - Have `resolve_config` / `ResolveConfig` also copy the via: `USER_REPO_VIA="$AITLIB_USER_REPO_VIA"` / `$script:UserRepoVia = $script:AitLibUserRepoVia`.
  - In step 5, when the hook is present and the via is not `config`, give a `step_warn "5"`, for example: "session archiving reads config.json userRepoPath only; dotprofile came from <via> -- run aitools user init".
  - Alternative: step 5 alone reads config.json `userRepoPath` directly (it checks the harvester, so it should see what the harvester sees). I prefer the via approach: it keeps one resolver call and stays correct once ait-harvest moves to the resolver.
  - Add the case to the check-lib test when it is promoted (m3).

## Minor

### m1. Dangling cross-reference: `reference/user-repo.md "Resolution"`
`scripts/check-lib.sh:154` and `scripts/check-lib.ps1:158` cite a section that does not exist. The headings in reference/user-repo.md are Naming Convention, Directory Structure, Profile Schema, Session Naming, Project Derivation, Config Schema, Archiving Mechanism, Template Resolution, User Rules Deployment, and so on. The resolver's own comment ("Which dotprofile") is dangling too, but that one is from #80. Suggested fix: cite `scripts/aitools-profile.sh` `resolve_user_repo` (the order is documented there), or add the section through the protected-file gate.

### m2. On rc 3, the step skip reason is wrong
With rc 3 (for example `AITOOLS_USER_REPO_PATH` pointing at a missing directory), the red `[error]` and the info line print before the checklist header. The steps then say `userRepoPath not configured`: pre-push step 7 "dotprofile deploy/ not verified", step 10, pre-commit step 11, post-push step 5. That is false; the dotprofile is set but broken. `check_log_init` also resets ERRORS, so the check exits as if nothing happened. Suggested fix: keep the rc, e.g. `USER_REPO_RC` / `$script:UserRepoRc`. When it is 3, either use the skip text "dotprofile unresolved -- see error above", or emit one `step_warn` (e.g. step "0" "Dotprofile resolution"). The info line alone is easy to miss above the header.

### m3. The tests live only in scratch
`test-checklib.sh` and `test_harvest_bom.py` are not in `tests/` and not in CI, so a regression in `resolve_config` or `read_config_user_repo` is invisible. The PR lists this as a follow-up. I'd do it in this PR or the next batch: `tests/profile/test-checklib.sh` fits next to test-lib.sh and can reuse its pwsh `AITOOLS_PROFILE_TEST_ANY_OS=1` pattern.

### m4. Resolver parity gaps that callers now inherit (owner: #80 / aitools-profile, not this diff)
Found with this PR's callers. These are not regressions against the old check-lib for configs that aitools writes:
- **`~` in config `userRepoPath`:** bash does not expand it, so the path counts as missing and resolution goes to scan (`via=scan`). PowerShell returns the literal `~/repos/aitools-t` with `via=config`. `Test-Path` accepts that; `git -C ~/...` from PowerShell does not, since a native argument is not tilde-expanded.
- **UTF-16 config.json:** bash says "invalid JSON" and goes to scan. PowerShell reads it, `via=config`. ait-harvest now warns and does not archive.

Suggest an incident or a #80 follow-up. Nothing to change in 4b345cc.

## Nits

- **n1. Falsy non-strings:** `scripts/ait-harvest.py:219-225`. `"userRepoPath": 0` or `false` reaches the `if not raw` branch and logs detail "not set", not the new non-string warning (probe: zero-path, false-path → detail). Fix: test `raw is None or raw == ""` first, then `isinstance`.
- **n2. PR body "Not run, Git Bash path forms":** moot for these consumers. Every `check-*.sh` exits at its MINGW/MSYS OS guard, before `resolve_config`, so no check consumes the `/c/...` form. Worth one line in the body so nobody tests it.
- **n3. Pre-existing, out of scope:** check-pre-push step 7 says "see checks.log", but its `log_detail` lines go to deploy.log: after the bridge, `LOG_FILE` is deploy.log. Confirmed under an isolated HOME: `pre-push 7` detail is in deploy.log, not in checks.log. A one-word fix for whoever owns step 7 next (H5).

## What I verified (all on macOS, isolated HOMEs under `.scratch/session-B8cRev/`)

- **Author's `test-checklib.sh`:** 12/0 (bash 5 + pwsh).
- **My `rv-probe.sh` (bash 5, /bin/bash 3.2 + pwsh 7, `$ErrorActionPreference = "Stop"` driver).** Cases: plain, corrupt JSON, UTF-16, tilde, two-candidate scan, one-candidate scan, trailing slash, space in path, resolver missing (`AITOOLS_PROFILE_SH/PS1` → nonexistent), bad env path with `AITOOLS_SUMMARY_FILE` set.
  - **rc 0 and 1:** no console output; deploy.log gets only detail lines (`via=...`, "none found (shared-only mode)"); ERRORS/WARNINGS 0.
  - **rc 3:** exactly one `[error]` line from the lib plus one `[info]` line from check-lib. One `ERROR|dotprofile|resolver failed` row, and only when a summary file exists. No ACTION row. ERRORS=1 before `check_log_init` and 0 after.
  - **PowerShell:** `@(ResolveConfig)` returns 0 objects (no output-stream pollution); `Resolve-UserRepoPath` returns `System.Int32`, count 1.
  - **Parity:** bash and PowerShell agree on every case except m4.
  - **set -u:** no unbound-variable error under 3.2 or 5.
- **Real `check-pre-commit.sh` and `check-pre-push.sh`** (bash 5 and /bin/bash 3.2), isolated HOME, fake git dotprofiles:
  - **Config-sourced:** step 11 WARN names the config dotprofile.
  - **`AITOOLS_USER_REPO_PATH`-sourced:** step 11 names the env dotprofile; pre-push step 7 archives from it and builds into its temp copy. Neither fake dotprofile was written to, so step 7 is safe at this head. build-deploy.sh reads `$HOME/.aitools/config.json` directly and does not source the lib or the resolver, so the author's H5 note is accurate.
  - Step 7 FAILs ("could not compare", diff exit 2) only because the fake dotprofile has no `deploy/`. The pre-commit FAIL is the known step 6.
- **`check-prereq-detection.sh` and `check-post-push.sh`:** run end to end under an isolated HOME, with no crash in `resolve_config`. The post-push FAILs (step 1 HEAD != origin/main, step 3 MCP config) are environmental.
- **`rv_harvest_cases.py`, 19 cases** (`python3 -I`, a temp HOME per case):
  - Return `dp`: plain and UTF-8 BOM. tilde also returns `dp` (`expanduser`).
  - Warn, no exception: UTF-16, latin-1, `[]`, `null`, int, list path, NUL in path, missing dir, file not dir, config.json that is a directory, corrupt.
  - Detail: empty path, no key, no file.
  - Levels match reference/logging.md: warn for "configured but archiving stops", detail for "not configured". Type hints are present (`data: Any`), and the imports are stdlib only.
- **Syntax:** `bash -n` (bash 5 and 3.2) on check-lib.sh and the 4 check scripts; pwsh parser on check-lib.ps1 and the 4 check .ps1 files; `ast.parse` on ait-harvest.py. All clean.

## Not run

Windows: real `check-*.ps1`, `aitools-profile.ps1` without the test switch, PS 5.1. The SessionEnd and SessionStart hooks end to end.

INCIDENT: (not filed) aitools-profile.sh/.ps1 differ on `~` expansion and UTF-16 config.json in `user-repo-path` (m4). Suggest an incident or a follow-up against #80.
