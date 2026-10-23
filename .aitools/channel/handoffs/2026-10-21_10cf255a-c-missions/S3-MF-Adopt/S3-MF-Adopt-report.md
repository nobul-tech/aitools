# S3-MF-Adopt report (N-Q2: dotprofile adopt is committed and pushed by the library)

**PR:** https://github.com/nobul-tech/aitools/pull/103. **Branch:** `fix/mf-dotprofile-adopt-push`. **Commits:** 11ba964 (the change), c05fec8 (a Windows test fix), and a third commit that adds this report and the review file.

## Summary

The library now commits and pushes an adopt target when that target is in the dotprofile. This covers accept & adopt, merge & adopt and JSON field adopt. The new helper is `dotprofile_commit_push FILE MESSAGE` in bash and `Invoke-DotprofileCommitPush -File -Message` in PS1.

- **What it commits:** only the one file (pathspec commit). Other staged or unstaged changes in the dotprofile stay out.
- **How it pushes:** without prompts.
- **How it decides "in the dotprofile":** it compares git top levels, not path strings. The dotprofile comes from the caller's resolved path. If the caller never resolved it, the helper asks the resolver quietly.
- **Result values** (`AITLIB_DOTPROFILE_PUSH` / `$script:AitLibDotprofilePush`): `committed-pushed`, `unchanged`, `commit-failed`, `push-failed`, `not-dotprofile`.
- **When the commit or push fails:** the helper logs a WARN and writes one ACTION per run. The deploy outcome stays `accept & adopt`.
- **Adopt targets in the aitools repo:** unchanged. They stay working-tree changes with the "Uncommitted change" line.

The private rules-path commit block in setup-user-claude.sh/.ps1 is removed, because the library now does this. The old PS1 block committed everything staged (it used no pathspec).

## Files changed

- `scripts/aitools-lib.sh`: the new helper, `_managed_adopt_notice`, and header comments.
- `scripts/aitools-lib.ps1`: the new helper, `Write-ManagedAdoptNotice`, and header comments.
- `scripts/setup-user-claude.sh` and `scripts/setup-user-claude.ps1`: the private commit block removed.
- `tests/managed-files/test-adopt-push.sh` and `.ps1`: new tests.
- `.github/workflows/check.yml`: the new tests added to 3 jobs.
- Draft for `reference/managed-file-deployment.md` (a protected file): `S3-MF-Adopt-drafts/reference/managed-file-deployment.md.edit.txt`.

## Verification

All on macOS:

| Test | Passed | Failed |
|---|---|---|
| test-adopt-push.sh | 28 | 0 |
| test-adopt-push.ps1 | 23 | 0 |
| test-managed-files.sh | 57 | 0 |
| test-managed-files.ps1 | 39 | 0 |

`bash -n` and the pwsh parser are clean on every touched script.

The check scripts fail only on known pre-existing items:
- **check-pre-commit:** fails step 6, the known harvesting file with mode 100644.
- **check-pre-push:** fails step 7, the known stale dotprofile `deploy/`.

**CI:**
- On 11ba964, Windows failed 4 asserts. The test expected the bash path form, and display_path prints the Windows form. c05fec8 fixes the test.
- On c05fec8, Linux, Windows and CodeQL pass. The macOS job was still pending when this report was written.

## Not run

- Windows by hand: it is covered by CI only, and the pty cases are skipped there.
- The PS1 resolver fallback off Windows: aitools-profile.ps1 refuses to run on other OSes.
- A real push to GitHub over ssh or https.
- The generated deploy/ scripts at runtime.

## Reviewer

S3-MF-Adopt-Review gave **APPROVE** at c05fec8: https://github.com/nobul-tech/aitools/pull/103#issuecomment-6356052149. The details are in `S3-MF-Adopt-Review-pr103.md`.

- The one blocking finding (B1, the Windows test asserts) is fixed in c05fec8.
- It made 10 non-blocking findings (N1–N10).

## WRITE_BLOCKED

None. Two inline commands were refused by the standing-order guard (`$(...)` and `;`). I redid both with the Edit tool or a scratch script.

## INCIDENT markers (not filed)

- INCIDENT: `adopt_managed_file` / `Adopt-ManagedFile` writes user-created hooks and skills into the dotprofile without commit or push, contrary to N-Q2 (reviewer N4).
- INCIDENT: no spec says what a dotprofile push does with earlier unpushed local commits (it publishes them), or which branch it pushes (the current branch, not "its main" as the rule says). The resolver's own push does the same (reviewer N1, N2).

## Open questions

- **Should the push target main explicitly** (`git push origin HEAD:main`, or refuse when the branch is not main)? I suggest refusing with a WARN + ACTION when the current branch is not main, because that matches the rule text "its main".
- **Should the helper fall back to `identity.git` from profile.json** when the machine has no git identity, as `ui_commit` in scripts/aitools does? I suggest yes, in a follow-up. It needs a JSON reader in the lib.
