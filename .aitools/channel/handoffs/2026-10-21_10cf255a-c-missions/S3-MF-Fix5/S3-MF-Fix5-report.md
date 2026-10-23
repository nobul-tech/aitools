# S3-MF-Fix5 report: audit findings A-19, A-20, A-25, A-26 (claude part)

**Intent**: **Purpose**: Record what S3-MF-Fix5 changed, verified and left open for S3-MF-Audit findings A-19, A-20, A-25 and A-26 (claude part), so S3-M3Finish and Jose can review and merge PR #112. **Scope**: The four findings, the build-deploy port, the tests, verification, the reviewer verdict and follow-ups. NOT other audit findings. **Audience**: S3-M3Finish, Jose.

- PR: https://github.com/nobul-tech/aitools/pull/112. Branch `fix/mf-audit-claude-build`, stacked on PR #103. **Merge after #103.**
- Commits:
  - 286325e: setup-user-claude.sh/.ps1 (A-25, A-26)
  - db9ddf8: build-deploy.sh (A-19, A-20), tests/claude-mdm, CI
  - a third commit holds the reviewer file and this report

## Findings

| id | status | evidence |
|---|---|---|
| A-25 | fixed | The footer hostname is now `AITLIB_MACHINE_HOSTNAME` / `$script:AitLibMachineHostname`, or "unknown" when empty. Before, setup-user-claude.sh lines 93-109 ran `scutil`/`uname` itself and the .ps1 lines 171-175 read `COMPUTERNAME`. The lib sets the hostname in aitools-lib.sh:337 and :355 and in aitools-lib.ps1:268 and :286. The resolver puts `hostname` in every resolve result, rc 1 included (aitools-profile.sh:873). |
| A-26 (claude) | fixed | A dry run now writes `OK\|claude.md\|dry-run: would create`, `verified` or `dry-run: would update`. Also fixed: the .ps1 dry-run comparison. It compared `Get-Content -Raw` (with a trailing newline) using `-eq`, so an up-to-date file read as "differs". Both languages now compare as `deploy_managed_file` / `Deploy-ManagedFile` do. |
| A-19 | fixed | The generated resolver-embedding .ps1 files (setup-user-claude, -cursor, -settings) now run inside `try { ... } finally { Remove-AitoolsEmbed }`. `Remove-AitoolsEmbed` runs only once. A post-build check fails the build if the finally line is missing. A probe showed pwsh 7 runs `finally` on `exit N` and keeps the exit code. |
| A-20 | fixed in the producer | blog_warn/blog_error use colour only when stderr is a terminal. The child resolver's console copy goes to the terminal only; its lines are already in deploy.log. The entry points (scripts/aitools, aitools.ps1) belong to S3-MF-Runner and are unchanged. |

S3-MF-Fix4 needs no build-deploy port. PR #109's body says the cursor body is extracted whole (build-deploy.sh "3. deploy/setup-user-cursor.sh").

## Verification (macOS)

- `tests/claude-mdm/test-claude-mdm.sh` (new):
  - 32 passed, 0 failed under bash 5 and under /bin/bash 3.2.
  - Negative control: against base 547079c, 23 checks fail, covering every finding.
- Syntax: `bash -n` under bash 5 and 3.2, and the pwsh parser, are clean on the touched scripts and the generated ones.
- build-deploy run on a git-archive copy of the live dotprofile, under an isolated HOME with `AITOOLS_USER_REPO_PATH`:
  - exit 0, with no ANSI codes in its output
  - the generated scripts carry the fix
  - smoke runs of the generated setup-user-claude.sh: dry run, run, dry run gave `would create`, `created`, `verified`
- Existing suites and pre-commit / pre-push checks: see the PR body's Verification section.

## Not run

- Windows / Git Bash.
- Regenerating the live dotprofile deploy/.

## Reviewer

S3-MF-Fix5-Review: see S3-MF-Fix5-Review-pr112.md in this folder and the PR comment.

## Follow-ups

- The claude rules dry run writes no `claude rules` row. The audit did not list it, so it is out of scope here.
- The plan-execution sub-agent pattern was not used. The edits followed a verbatim plan with an error-handling audit (scratch `plan.md`), applied directly in two verified batches, plus an independent reviewer. That is a deviation from `.claude/rules/plan-execution.md`, and I am disclosing it here.
