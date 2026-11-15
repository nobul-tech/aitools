Resolved on `main`. Both "Done when" conditions hold, and so does the addition from the comment above.

## 1. The Windows job runs the PS1 interactive cases (no `SKIP interactive cases`)

`tests/managed-files/pty-run.py` gained a Windows backend (pywinpty / ConPTY), and the PS1 suite runs natively on the Windows runner:

- #139 (CI platform targeting; B6 `a857c12` "pty-run.py Windows backend (pywinpty/ConPTY); managed-file suites use it", B5 `26c24f1` "PS1 managed-file stubs and OSC cleanup on native Windows")
- #148: pywinpty is installed by `scripts/setup-pywinpty.ps1` (hash-pinned), and the job fails when `import winpty` does not work afterwards

CI on `main` 592c5b3, run https://github.com/nobul-tech/aitools/actions/runs/43557171983, Windows job https://github.com/nobul-tech/aitools/actions/runs/43557171983/job/132332536670:

| Step | Result |
|---|---|
| Managed-file tests (PowerShell, native) | 56 passed, 0 failed, 0 skipped |
| Managed-file tests (bash, via Git Bash) | 79 passed, 0 failed, 3 skipped (read-only chmod, a >64 KB diff over ConPTY, and the `setup-user-claude.sh` round trip; none is an interactive menu case) |
| Menu-choice wrapper tests (PowerShell, native) | 63 passed, 0 failed, 0 skipped |
| Menu-choice wrapper tests (bash, via Git Bash, ConPTY) | 61 passed, 0 failed, 0 skipped |

Every interactive case this issue lists ran on Windows and passed. From the PowerShell step's log:

- `empty choice at the menu: asked again, then skip applies`
- `skip: nothing written`
- `adopt: LOCAL kept, copied to the repo`
- `adopt filter: the repo gets the filtered LOCAL`
- `merge & adopt: merge in LOCAL and the repo`
- `merge [n]o: back to the menu, merge not written`
- `failed AI merge: failed, nothing written`
- `adopt-target write failure: LOCAL restored, failed`
- `abort: exit 2, error logged, LOCAL unchanged`
- `json per-field: overwrite/adopt/skip + LOCAL-only adopt`
- `EOF at a prompt: empty choice, warning logged`
- the `display: ...` cases

`tests/menus/test-menu-choice.ps1` also drives the real `Prompt-DiffReview`, `Prompt-JsonFieldReview` and `Invoke-AiMerge` (the merge preview) through `Read-MenuChoice` / `Read-ConsoleChoice`. It feeds keys through `[Console]::SetIn` (the input seam suggested above), with one case on ConPTY.

## 2. Breaking a menu branch in `aitools-lib.ps1` fails the Windows suite

This was checked by mutation on Windows 11 (pwsh 7). Each mutation went into a scratch copy of `scripts/` + `tests/managed-files/`, and the suite ran exactly as the Windows step runs it (`pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1`):

| Mutation in `Prompt-DiffReview` | Suite |
|---|---|
| `[s]kip` returns `overwrite` | exit 1, 5 FAIL (`skip: nothing written`, `empty choice at the menu ...`, 3 `display` cases) |
| `[a]ccept & adopt` returns `skip` | exit 1, 3 FAIL (`adopt: ...` x2, `adopt filter ...`) |
| `[x]abort` does not call `Invoke-ManagedAbort` | exit 1, 1 FAIL (`abort: exit 2, error logged, LOCAL unchanged`) |

## The profile resolver on Windows (comment above)

The Windows job's step "Profile resolver tests (.ps1, native pwsh)" (`bash tests/profile/test-profile.sh`) ends `716 passed, 0 failed (windows: aitools-profile.ps1)` in the same run. The step "User init tests (.ps1, native pwsh, ConPTY menus)" ends `179 passed, 0 failed, 1 skipped`.

## Not done (optional, not in "Done when")

- Suggestion 4: there is no CI annotation for a skipped test group. `check.yml` has one `::warning::`, for deploy drift.
- The CI-authoring note that a pwsh step ending on an intentional non-zero native exit needs `exit 0` exists only as finding 7(d) in `plans/merge-friction-improvements.md`, not in a reference doc.
- The test policy (suggestion 3) is recorded in `CLAUDE.md` ("Windows runs the `.ps1` halves on native pwsh") and `plans/ci-platform-targeting.md`.

Closing.
