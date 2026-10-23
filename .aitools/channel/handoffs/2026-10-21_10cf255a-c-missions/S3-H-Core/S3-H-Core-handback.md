# S3-H-Core hand-back (2026-10-22)

## Summary

1. `scripts/deploy-harness.sh` / `.ps1` build `~/.aitools/{reference,registries,hooks,rules,skills,bin}` from git-tracked repo files through `deploy_managed_file` (tool `harness files`, adopt target = repo file) and generate `config.json` via `setup-user-config`.
2. Conflicts: first source wins, case-insensitive, each skipped duplicate `log_error` + `ERROR|harness files|<name>: dup in <source>`; exit 1.
3. Tests: `tests/deploy-harness/test-deploy-harness.sh` 45/45 on macOS; ps1 run on macOS pwsh with the OS guard disabled (scratch): 15/15; real repo under isolated HOME: 130 added, rerun 130 verified.
4. Approved docs written: reference/harness.md section, aitools-workspace.md rows, "harness files" tool name, managed-file-deployment.md rule content-sources row; reference/managed-file-deployment.md drafted (PR #81 owns it).
5. PR https://github.com/nobul-tech/aitools/pull/88, branch `feature/harness-deploy-harness`; independent review by S3-H-Core-Review (see "Reviewer verdict").

## CLI interface

`deploy-harness.sh [--dry-run] [--force] [--help]` / `deploy-harness.ps1 [-DryRun] [-Force] [-Help]`; env `AITOOLS_DRY_RUN=1`, `AITOOLS_FORCE=1`. Unknown argument: ERROR row `bad arguments`, exit 1.
Exit: 0 done (warnings possible); 1 errors (failed file, duplicate, non-git source, config.json not generated); 2 user abort at a review menu (from the library's `_managed_abort` / `Invoke-ManagedAbort`).
Summary: one row `OK|WARN|ERROR` under `harness files` with counts; `DETAIL` rows only for accept & adopt / skipped / failed; one ERROR row per duplicate, per non-git source, and for config.json failure.

setup-user-config as called: `bash scripts/setup-user-config.sh` (no flags: re-derive from profile.json) or `... --dry-run`; PS1 `& scripts/setup-user-config.ps1` or `-DryRun` (in-process, as `aitools.ps1 Deploy-Configs` does). Non-zero exit -> `log_error` + `ERROR|harness files|config.json not generated`; the run continues. Requires `reposPath`/`repoPath` already in config.json (installer Step 5): without them the writer exits 1 (tested with the real writer).

## Files changed

scripts/deploy-harness.sh, scripts/deploy-harness.ps1, tests/deploy-harness/test-deploy-harness.sh, reference/harness.md, reference/script-standards-detail.md, .claude/rules/aitools-workspace.md, .claude/rules/managed-file-deployment.md, scripts/check-path-refs-allow.txt, this hand-back, S3-H-Core-drafts/reference/managed-file-deployment.md.

## Verification

- `bash -n scripts/deploy-harness.sh`: OK. pwsh Parser on deploy-harness.ps1: OK.
- `bash tests/deploy-harness/test-deploy-harness.sh`: 45 passed, 0 failed, 0 skipped.
- Scratch `.scratch/session-hcore/smoke-real.sh` (real worktree content, isolated HOME): `OK|harness files|130 added`, then `OK|harness files|130 verified`; `diff -r registries` identical; reference identical except `tool-registry.md` (library trims a trailing blank line).
- Scratch `.scratch/session-hcore/ps1-smoke.sh` (ps1 with guard disabled, pwsh on macOS, pty for adopt/abort): 15 passed, 0 failed; ERROR rows identical to bash.
- check-pre-commit: only known step 6 FAIL. check-pre-push: 0 FAIL. check-script-compliance: 13 PASS. tests/logging: 24 passed.

## Not run

- deploy-harness.ps1 on Windows; no `.ps1` test file (OS guard blocks it on macOS).
- Hook-ins, MDM, fan-out (other missions).

## Decisions made (disciplined initiative)

- Git-tracked only for every source (not just reference/registries): keeps adopt backups and worktree junk out; non-git source = ERROR.
- `*.bak.*` never deployed (tracked `shared/hooks/*.bak.*` exist on main).
- No extra protected-adopt WARN in the script: the library already logs `Adopted into protected file <path>` (`_managed_protected_note`); a second WARN would double count. Test covers it.
- bin goes through deploy_managed_file (brief: "each file") although the installer's comment argues no review for bin.
- Own counters instead of `deploy_tracker_record` to avoid ~130 DETAIL rows on a first run.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- INCIDENT: `.claude/rules/managed-file-deployment.md` "Adopt target" says an adopt target in the dotprofile is committed and pushed automatically (N-Q2); `scripts/aitools-lib.sh` ("Review choices" block, `_managed_adopt_notice`) says the library never commits or pushes. Spec deviation (pre-existing).
- INCIDENT: `reference/harness.md` intent scope is "Architecture and component definitions only. NOT operational guides"; the approved conflict-handling section is operational detail. Intent drift to resolve (widen intent or move the section).
- INCIDENT: shared contract says fan-out consumers copy "every regular file" in `~/.aitools/rules`; the library leaves `<file>.bak.<ts>` there after each update, so consumers would fan out backups. Contract needs "*.md, skip *.bak.*".

## Open questions (with suggested answers)

1. Should project skills (`.claude/skills`) be fanned out to user level from `~/.aitools/skills`? documentation-standards.md says project skills are not deployed. Suggest: deploy-harness keeps copying them (brief says so); the skills fan-out (if any) copies only `shared/skills` units.
2. Should `hooks/` contain non-hook files (`hooks-manifest.json`, `.py`)? Suggest yes: setup-user-hooks needs the manifest and helpers when it moves to read from `~/.aitools/hooks`.
3. MDM variant has no git checkout. Suggest S3-H-MDM embeds the file list at build time (from `git ls-files`) instead of calling git at run time.

## Reviewer verdict

S3-H-Core-Review (independent level-3 delegate): **no blocking findings**, 10 non-blocking, posted as a comment review:
https://github.com/nobul-tech/aitools/pull/88#pullrequestreview-5620917126

Addressed in commit 3 of this PR:
- #3 preserved-file comparison is now case-insensitive in bash (matches the PS1 hashtable).
- #5 chmod failure and conflict-lookup failure now write an ERROR row.
- #7 the case-insensitive conflict test asserts content and the absence of `Hook-Lifecycle.md`.

Left open (for S3-Harness):
- #1 contract: consumers must skip `*.bak.*` in `~/.aitools/rules`. #87 copies them today.
- #2 retired rules are preserved forever and fanned out. Needs a decision: WARN row, or pruning.
- #4 dry-run compares JSON as text. This is the library's behavior.
- #6 tests/deploy-harness is not in CI, and there is no `.ps1` test. check.yml is owned by M3.
- #8 the PS1 temp-file `SilentlyContinue` is not in the exemptions table (trivial).
- #9 Hookin constraints:
  - Step 8b must come after Node.
  - The writer would run twice per sync if setup-user-config stays first in the deploy list.
  - Do not pipe stdin.
  - Exit 1 must not abort the installer.
- #10 is the N-Q2 rule/library mismatch above.
