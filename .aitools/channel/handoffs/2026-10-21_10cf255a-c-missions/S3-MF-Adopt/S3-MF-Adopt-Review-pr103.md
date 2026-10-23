# S3-MF-Adopt-Review: PR #103 review

Reviewer: S3-MF-Adopt-Review (independent; delegated by S3-MF-Adopt), 2026-10-22.
PR: https://github.com/nobul-tech/aitools/pull/103, branch `fix/mf-dotprofile-adopt-push`.
Head reviewed: **c05fec8** (11ba964 plus a test-only fix). Read with the base,
11ba964.

## Verdict: APPROVE

There are no blocking findings at c05fec8. CI on c05fec8: linux pass, windows
pass, CodeQL pass, macos still pending when this was written. I ran the macOS
suite locally and it passes (see Tests). Approve once the macos job is green.

The one blocking issue found at 11ba964 is fixed in c05fec8:

- **B1 (fixed in c05fec8)**: Windows CI failed 4 asserts in
  `tests/managed-files/test-adopt-push.sh` (job 120203060113: "14 passed, 4
  failed, 1 skipped"). The asserts expected the ACTION row to name the
  dotprofile in its bash path form. The library prints `display_path`, which
  is the Windows form (`C:\Users\RUNNER~1\...`) under Git Bash. The library
  was right and the test was wrong. c05fec8 adds `DPD` (from `cygpath -w`)
  and uses it in the 5 ACTION asserts. Windows job 120206540857 now shows
  bash "18 passed, 0 failed, 1 skipped" and PS1 "14 passed, 0 failed, 1
  skipped".

## Requirement checks (N-Q2 and the 2026-10-22 commander requirement)

| Requirement | Result | Evidence |
|---|---|---|
| One shared lib helper | Met | `dotprofile_commit_push` (aitools-lib.sh:1031); `Invoke-DotprofileCommitPush` (aitools-lib.ps1, after `Write-ManagedProtectedNote`) |
| Called from the adopt path of deploy_managed_file / Deploy-ManagedFile and the JSON field review | Met | `_managed_adopt_notice` is called at aitools-lib.sh:2020 (text adopt/merge) and :2308 (`review_json_fields`), once per file. PS1: `Write-ManagedAdoptNotice` at aitools-lib.ps1:2009 and :2322 |
| "In the dotprofile" decided by git, not by the path string | Met | `git rev-parse --show-toplevel` of the file's dir is compared with that of the dotprofile (sh:1049-1065). A string prefix is used only when the dotprofile is not a git repo, to choose WARN or detail. Symlinked dotprofile paths pass (edge cases 5 and 6) |
| Pathspec commit; unrelated changes never committed | Met | `git add -- base`, then `git commit -m msg -- base` (sh:1068-1077). Unrelated staged and unstaged files are left out (tests "direct: unrelated ..."). When the same file is staged at one version and edited again, the working-tree version is committed (edge 12: `--only` semantics) |
| Push failure = WARN + ACTION; deploy outcome unchanged | Met | sh:1086-1098. `log_warn` increments WARNINGS (PS1: warnings=3 after 3 failure modes, edge-ps1). The ACTION is written once per run (`_aitlib_action_once`). The adopt result stays `accept & adopt` and the exit code is 0 (tests "adopt, push fails") |
| Adopt target in the aitools repo stays a working-tree change | Met | The `not-dotprofile` branch falls back to the old "Uncommitted change in ..." log (sh:1114-1119). Test "adopt outside the dotprofile" |
| Result globals AITLIB_* / $script:AitLib*, set inside functions only; nothing returns 2 | Met | `AITLIB_DOTPROFILE_PUSH` / `$script:AitLibDotprofilePush` is set inside the function only. Always returns 0 |
| PS1 helper writes nothing to the output stream | Met | I checked this myself: `@(Invoke-DotprofileCommitPush ...).Count` is 0 for committed-pushed, push-failed, commit-failed, not-git and unchanged (edge-ps1.ps1). `Log*` use Write-Host and file appends. git output goes to `$null` or into captured variables |
| bash/PS1 parity (outcomes, log lines, ACTION text) | Met | The warn and ok lines and the ACTION texts are the same in the bash edge run and the PS1 edge run |
| set -e / set -u safety, bash 3.2 | Met | Every failing command is guarded with `|| rc=$?`. `${AITLIB_USER_REPO_PATH+set}` detects "the caller resolved". The test passes under /bin/bash 3.2.57 (28/0/0) |
| setup-user-claude's private commit block removed | Met | Both .sh and .ps1. The old block ran only after a merge, with `2>/dev/null` and a bare `git add`. The library now covers adopt and merge |
| build-deploy / MDM copies | Met for the code | build-deploy inlines the whole lib (`inline_lib_bash` / `inline_lib_ps1`), so no duplicated block exists. No "Sync merged" remains anywhere under scripts/ |

Spot-checked in the code, not through the tests: the pathspec commit and the
`git diff --cached --quiet` "unchanged" gate (sh:1068-1078, ps1 equivalent);
the toplevel comparison; the PS1 env save and restore in `finally`
(`$env:X = $null` removes a variable that was not set before).

## Non-blocking findings

- **N1: the push publishes unrelated local commits.** If the dotprofile
  already has unpushed commits, `git push` sends them along with the adopt
  commit (edge 4: an unrelated local commit `notes.md` reached the remote).
  This meets the letter of "never commit unrelated changes", but it
  publishes unrelated work. The resolver push (aitools-profile.sh) and the
  old setup-user-claude block behaved the same way. Suggested fix: before the
  push, check `git rev-list --count @{u}..HEAD`; if it is greater than 1,
  WARN + ACTION instead of pushing. Or record the behavior in the spec draft.
- **N2: it pushes the current branch, not main.** When the dotprofile is
  checked out on another branch with an upstream, the commit and push go to
  that branch (edge 3: remote `feature` got the change, `main` did not). The
  rule (.claude/rules/managed-file-deployment.md "Adopt target") says
  "pushed to its main". Suggest: when the branch is not main, commit but do
  not push, with WARN + ACTION. Or have the spec say "its current branch".
- **N3: misleading ACTION when there is no upstream.** With no upstream, an
  unborn HEAD, or a detached HEAD, the ACTION is "run git push in <dp>"
  (edges 1, 2, 7), and plain `git push` fails the same way for the user.
  Suggest a third case: when the output contains "no upstream" or "not
  currently on a branch", the ACTION is `git push -u origin <branch>`, or
  "check out a branch".
- **N4: hook and skill adopts into the dotprofile are not committed (outside
  this PR's stated scope).** `adopt_managed_file` / `Adopt-ManagedFile`
  (aitools-lib.sh:2346) writes user-created hooks and skills into
  `$USER_REPO_PATH/claude/hooks|skills/` (setup-user-hooks.sh:235,
  setup-user-skills.sh:218, and the .ps1 twins) with no commit or push. That
  is a library write into the dotprofile that N-Q2 ("dotprofile writes
  auto-commit and push") covers, but the requirement named only
  deploy_managed_file. Suggested follow-up: call `dotprofile_commit_push`
  for each target in `adopt_managed_file` / `Adopt-ManagedFile`.
- **N5: generated deploy/ scripts without the resolver.** Some generated
  scripts get no embedded resolver block: deploy-harness, setup-user-hooks,
  setup-user-skills, setup-user-mcp (build-deploy.sh 1355/1448/1538/1632/1943/2093).
  In those scripts the helper's fallback (`_aitlib_profile_run` /
  `Invoke-AitLibProfile`) finds no resolver. It falls to `not-dotprofile`
  with a detail line, and the adopt is reported only as an "Uncommitted
  change" info line. deploy-harness also reads `userRepoPath` from
  config.json, not from the resolver. Not verified at runtime (I did not run
  build-deploy).
- **N6: multi-line git output in deploy.log.** `log_detail "git push in
  $d: $out"` writes multi-line git output as one entry, so the continuation
  lines lack the `[ts] [script] [level]` prefix (logging.md /
  script-standards.md "Log line format"). aitools-profile.sh does the same
  today. Suggest logging line by line, as the `ai-rejected:` lines are.
- **N7: git add errors are mislabelled.** When `git add` fails, its output is
  logged as "git commit in ..." (sh:1079; ps1 same). Cosmetic.
- **N8: test parity gaps.** The PS1 test has no direct-new-file,
  direct-action-once, merge-dotprofile, "backup not committed", or
  "caller-resolved dotprofile wins" cases. The PS1 resolver fallback runs
  only on Windows (aitools-profile.ps1 has an OS guard). The interactive
  (pty) adopt cases never run on Windows in either language. The PS1
  adopt-through-Deploy-ManagedFile path with commit-failed is not tested;
  my direct-call check covers its output-stream cleanliness.
- **N9: case-sensitive path compare on Windows.** The toplevel compare is
  case-sensitive (`!=` / `-cne`). Both values come from `git rev-parse`, so
  they are probably consistent. Not verified with differently-cased Windows
  paths.
- **N10: one commit message for adopt and merge.** A merge & adopt is
  committed with the same message as a plain adopt ("Adopt X from the
  deployed copy"). Cosmetic.

## Protected-doc draft

`S3-MF-Adopt-drafts/reference/managed-file-deployment.md.edit.txt` matches the
code as reviewed: function names, the result table, the message, the
GIT_TERMINAL_PROMPT and BatchMode settings, ACTION once per run. If N1 and N2
are accepted as documented behavior, add them to the draft. The draft still
needs commander approval (sources-of-truth.md).

## Tests run (macOS arm64, worktree at c05fec8)

| Command | Result |
|---|---|
| `bash tests/managed-files/test-adopt-push.sh` | 28 passed, 0 failed, 0 skipped (rc 0) |
| same, `bash` = /bin/bash 3.2.57 on PATH | 28 passed, 0 failed, 0 skipped (rc 0) |
| `pwsh -NoProfile -File tests/managed-files/test-adopt-push.ps1` | 23 passed, 0 failed, 0 skipped (rc 0) |
| `bash tests/managed-files/test-managed-files.sh` | 57 passed, 0 failed, 0 skipped (rc 0) |
| `pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1` | 39 passed, 0 failed, 0 skipped (rc 0) |
| `bash -n` and `/bin/bash -n` on aitools-lib.sh, setup-user-claude.sh, test-adopt-push.sh | all rc 0 |
| pwsh parser on aitools-lib.ps1, setup-user-claude.ps1, test-adopt-push.ps1 | all rc 0 |
| Reviewer edge script (12 cases, bash 3.2): unborn HEAD, no upstream, other branch, unpushed commit, symlinks x2, detached HEAD, spaces, gitignored file, outside any repo, dotprofile not a git repo, partial staging | All return 0 with a sensible state. Findings N1-N3 come from these runs |
| Reviewer PS1 output-stream check (5 outcomes) | 0 output objects in every case; WARN count and ACTION rows match bash |
| CI 11ba964 | windows FAIL (B1), linux pass |
| CI c05fec8 | linux pass (7m55s), windows pass, CodeQL pass, macos pending |

Scripts used: `.scratch/session-mfrev/{run-tests.sh,run-32.sh,edge.sh,edge-ps1.ps1,winlog.sh}`
in the worktree.

## Not verified

- The macOS CI job on c05fec8 (pending at the time of writing).
- A real push to GitHub over ssh or https (BatchMode, credential helper, a
  token in the remote URL appearing in the logged push output): unknown.
- The generated deploy/ (MDM) scripts at runtime (N5). I did not run
  build-deploy.sh (real-HOME rule).
- `check-pre-commit.sh` / `check-pre-push.sh`: not run by me.
- Windows behavior beyond what CI ran (no interactive cases there).

## INCIDENT markers (not filed)

- INCIDENT: `adopt_managed_file` / `Adopt-ManagedFile` writes user-created
  hooks and skills into the dotprofile without commit or push, contrary to
  N-Q2 "dotprofile writes auto-commit and push" (N4).
- INCIDENT: the dotprofile push publishes any pre-existing unpushed local
  commits, and pushes the current branch rather than main. No spec states
  either behavior (N1, N2; also true of aitools-profile.sh's push).
