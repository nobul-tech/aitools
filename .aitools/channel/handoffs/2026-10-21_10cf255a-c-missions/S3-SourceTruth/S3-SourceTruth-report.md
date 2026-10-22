# S3-SourceTruth report -- mission SOURCE-TRUTH

1. The managed-file model is implemented in both libraries and every caller: SOURCE is the source of truth, there is no deploy state, and adopt and merge write the repo.
2. Tests pass on macOS: bash 42/42, PS1 23/23, logging 24/24, check-post-push steps 29/30/31.
3. The tests found and fixed two real bugs. Bash `_merge_validate` always returned 0, so bash AI-merge validation never rejected anything. The PS1 JSON post-write check read the wrong argument, so every PS1 JSON write would have failed.
4. The commander's D-TS13 reversal is applied (no abort marker), and the 13 contract defaults are listed in the PR for decision.
5. PR #68 is open. Windows was not run; CI covers it.

- **PR**: https://github.com/nobul-tech/aitools/pull/68
- **Branch**: feature/managed-file-source-of-truth. origin/main 6eb2b0b was merged in rather than rebased, because the branch was already pushed and force-push is not allowed.
- **Commits**: ac567ba, 0e24323 (merge), c2dcd5e, 00ee123, 3b12d3c, 3213c27, plus this report.

## Files changed

- **Libraries**: scripts/aitools-lib.sh, scripts/aitools-lib.ps1
- **Callers**: scripts/setup-user-claude.{sh,ps1}, setup-user-skills.{sh,ps1}, setup-user-hooks.{sh,ps1}
- **Build and checks**: scripts/build-deploy.sh, scripts/check-post-push.{sh,ps1}
- **Tests (new)**: tests/managed-files/{test-managed-files.sh, test-managed-files.ps1, pty-run.py}
- **CI**: .github/workflows/check.yml
- **Mission folder**: S3-SourceTruth-plan.md, S3-SourceTruth-Audit-findings.md, S3-SourceTruth-blocks/ (verbatim code, apply tools, .old/.new pairs), and this report

## Verification (commands and results)

PR #68 "Verification" has the full list. In summary:

- **Syntax**: `bash -n` and `/bin/bash -n` pass on every touched `.sh`; the pwsh parser passes on every touched `.ps1`.
- **Exact apply**: all 11 code files are byte-identical to a dry apply of the blocks on origin/main copies (PS1 compared after CRLF->LF, with 0 bare LF).
- **Tests**:
  - `bash tests/managed-files/test-managed-files.sh`: 42 passed, 0 failed
  - `pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1`: 23 passed, 0 failed
  - tests/logging: bash 24/24; PS1 15 passed, 5 skipped
- **Build and checks**:
  - build-deploy under an isolated HOME with a fake dotprofile: exit 0; all 42 generated scripts parse (S3-SourceTruth-B5).
  - check-post-push under an isolated HOME: 28 SKIP (retired); 29, 30 and 31 PASS.
  - check-pre-commit: only the known step-6 FAIL (harvesting file mode).
  - check-pre-push: only the known step-7 FAIL (dotprofile deploy/ stale).

## Not run

- **Windows**: no Windows machine here; CI runs the new suites on Windows.
- **A real AI merge**: the tests use a stub `claude`.
- **`aitools` / `aitools install`**: forbidden.
- **`check-pre-commit --fix`**: it builds with the real HOME (#136).

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

- **INCIDENT: bash `_merge_validate` always returned 0** (main, aitools-lib.sh). Its last command is an assignment, so bash AI-merge validation never rejected output. Fixed in this PR; it needs an incident record for provenance.
- **INCIDENT: the bash failed-merge reason is lost.** `invoke_ai` runs inside `$(...)` in `_invoke_ai_merge`, so `AI_REJECT_REASON` never reaches the caller and the log reads "unknown error". Same on main (audit M4).
- **INCIDENT: the real dotprofile `deploy/` was rebuilt** at 2026-10-21 20:42:49 local (03:42:49Z) by a process outside this mission. Evidence:
  - /Users/new-jose/repos/aitools-nobul-jose/deploy/* mtime is 20:42:49.
  - The content has none of this branch's code: grep for `_managed_write()` in deploy/setup-user-skills.sh finds 0.
  - No git hooks are installed (.git/hooks holds only samples).
  - Every delegate of this mission used an isolated HOME.
  - The dotprofile now has 23 modified deploy/ files plus sessions/.DS_Store. I did not touch it. The source may be another session running build-deploy, or check-pre-commit with `--fix`, against the real HOME (#86/#136 class).
- **INCIDENT (low): check-post-push step 30** tokenizes return values with `\w[\w-]*`, so it never checks "accept & adopt".
- **INCIDENT (low): PS1 console input after `Start-AiSpinner`'s job** comes back corrupted under the pty harness. Unknown whether a real terminal shows it.

## Open questions for the commander (each with a suggested answer)

1. **Contract item 8**: does a failed backup of an existing file fail that file? Today `config-file-safety.md` says backups are non-fatal. Suggested: keep it failing for managed files (nothing is written without a restore point) and approve the config-file-safety.md wording drafted in PR #68.
2. **Contract item 13**: should adopt create a dotprofile CLAUDE.md template when the dotprofile has none? Suggested: yes, as on main; the next run reads the new template and verifies.
3. **Repo `.bak.*` files** (audit L1): adopt targets now get rotated backups inside git working trees. Suggested: add `*.bak.20*` to the .gitignore of both repos, since git already backs up those files.
4. **Corrupt LOCAL JSON** (audit M2): today it fails on every run. Suggested: overwrite it from SOURCE with a backup on non-interactive runs (SOURCE is the source of truth); latent until a JSON caller exists.
5. **#29**: close it now, or wait for EOF tests of the JSON-field and merge prompts? Suggested: close it after the follow-up that adds those two tests and converts the entry-point bare reads in scripts/aitools and relay-outbound-prompt.sh.

## Delegates used

| Name | Task | Result |
|---|---|---|
| S3-SourceTruth-Audit | Reviewed the plan before execution | "Ready after fixes". Fixed: H1, L3, L6. M1-M4 and L1 are raised as questions or follow-ups. Findings file is in the mission folder. |
| S3-SourceTruth-B1 | Bash lib | Clean; verified byte-identical |
| S3-SourceTruth-B2 | PS1 lib | Clean; verified identical after CRLF->LF |
| S3-SourceTruth-B3 | Bash callers | Clean; found the missing skills sync ERROR row (fixed) |
| S3-SourceTruth-B4 | PS1 callers | Clean; found the same gap and a stale comment (both fixed) |
| S3-SourceTruth-B5 | build-deploy and check-post-push | Clean; isolated-HOME build and checks |

Delegates B1, B3 and B4 said they did not read all five reference files the packet lists; the edits were mechanical and I verified every output against the dry apply.
