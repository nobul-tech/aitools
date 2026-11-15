# e9d6-18 report: locked-file cases for the Windows deploy-harness and rules-fanout harnesses (v1.0)

Mission e9d6-18-locked-file, delegated by 38dc-13-windows-ci-ps1-only (RFI 38dc-6 /
38dc-20-2). Worktree `C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`, branch
`fix/38dc-13-windows-ci-ps1-only`. Not committed, not pushed (prompt: 38dc-13 verifies,
commits and ships). Machine: NEWCOPC\pepe, not elevated, pwsh 7.6.10.

## Summary

1. Three locked-file cases added, one per product path: the deploy-harness rules manifest
   replace and retired-skill backup copy (3 check lines each), and the rules-fanout rules
   manifest read (4 check lines).
2. A probe on this machine shows which hold blocks which operation; the hold is in the
   harness process (the product always runs in a child pwsh, so the harness is "another
   program"; share modes are per handle, so in-process and child-process holds behave
   the same, measured).
3. After: deploy-harness 115/0/0 (was 109/0/0), rules-fanout 69/0/2 (was 65/0/2); every
   old PASS/SKIP line unchanged and in the same order; parser OK.
4. Mutations: skip the hold, flip an expected value, release before the run: each FAILs
   the locked checks (exit 1); a probe that does not block gives one SKIP, exit 0. Every
   file restored byte-identical.
5. No leftover process or temp root after the normal runs and the mutation runs. No
   INCIDENT; two observations for 38dc-13 (section 7).

## 1. Which hold blocks which operation (probe on this machine)

Script `W\.scratch\session-e9d6-18\probe-lock.ps1` (with `holder.ps1`, a pwsh child that
opens the file and waits for a release file), output `probe-lock.log` in the same
folder. Scratch folder only; every handle closed and every child ended in `finally`
(`cleanup: removed=True; children alive=0`). Each mode was run twice, held in the probe
process and held in a separate child process; the results were identical:

| Hold | Operation (product line) | Result, in-process and child alike |
|---|---|---|
| FileShare.Read, FileAccess.Read (an ordinary reader) | `ReadAllLines` (Get-HarnessManifestPlan, `scripts/deploy-harness.ps1:421`) | allowed |
| same | `ReadAllText` (Read-HarnessManifest, `scripts/aitools-lib.ps1:3039`) | allowed |
| same | temp file + `File.Move(tmp, manifest, $true)` (Write-HarnessManifest, `deploy-harness.ps1:748-749`) | BLOCKED (UnauthorizedAccessException: "Access to the path is denied.") |
| FileShare.None, FileAccess.ReadWrite (an exclusive opener) | `Test-Path -PathType Leaf` | allowed |
| same | `ReadAllLines` / `ReadAllText` | BLOCKED (IOException: "... because it is being used by another process.") |
| same | `File.Copy` (Copy-SkillTree, `deploy-harness.ps1:541`) | BLOCKED (IOException, same text) |
| same | `File.Move` over it | BLOCKED (UnauthorizedAccessException) |
| FileShare.ReadWrite+Delete (delete-sharing granted) | `File.Move` over it | BLOCKED (UnauthorizedAccessException) |
| FileShare.None on a file in a skill folder (child) | `File.Copy` into the backup; then `Directory.Delete(backup, $true)` while the source is still held | copy BLOCKED; delete of the backup allowed (backup gone) |
| FileShare.Read on a file in a skill folder (child) | `File.Copy`; then `Directory.Delete(skill, $true)` | copy allowed; delete BLOCKED, `SKILL.md` left (observation, section 7) |

Mutation evidence (section 4, rf-probe-noblock first try): a ReadWrite/ReadWrite hold
also blocks `File.ReadAllText`, because ReadAllText opens with FileShare.Read, which
refuses a handle that already has write access.

What this decided:
- **Where to hold**: in the harness process. The product always runs in a child pwsh
  (`Invoke-TestScript`, `tests/lib/platform-lib.ps1:148-170`), so the harness is
  "another program" to it; share modes are checked per handle, and the probe measured no
  difference between a handle held in the same process and one held in a child. No child
  holder means no process can be left behind, and `finally` closes the handle on every
  path (a killed harness process loses its handles with it).
- **deploy-harness manifest**: FileShare.Read, the realistic cause (an editor, search
  indexer or virus scanner reading the file). It lets the plan's read through and makes
  the replace fail: the `catch` at `deploy-harness.ps1:750-756`, the path the prompt
  names. (FileShare.None would fail earlier, at the read in `deploy-harness.ps1:690-696`,
  "manifest not written, nothing retired": same ERROR row, other log text.)
- **deploy-harness skill**: FileShare.None on `s2\SKILL.md` (38dc-20 probe 7): the copy
  fails, the half-made backup can still be deleted.
- **rules-fanout**: FileShare.None (38dc-20 table row 13). A plain reader does not block
  the read, so it cannot reproduce this failure.

## 2. The cases

All new check names start `ps1 locked:` (deploy-harness, `$lang` = ps1) or `ps locked:`
(rules-fanout, `$L` = ps, the harness's own language tag). Each section has a comment
saying it is Windows only and that the .sh twin has no equivalent because on POSIX an
open file never blocks a rename, copy or read (an intended platform difference, not a
parity gap). Each is gated on a probe and prints one SKIP line where the hold does not
block, never FAIL.

### 2a. deploy-harness: rules manifest held open by a reader

- Product: `scripts/deploy-harness.ps1` Write-HarnessManifest (681-759), replace at
  747-756: `LogError "$title manifest: cannot write ${manifest}: $_ -- manifest not
  written"`, `Write-Summary "ERROR" $tool "$Kind manifest not written"`, `.tmp` removed.
- Harness: `tests/deploy-harness/test-deploy-harness.ps1` lines 776-863 (section
  "Locked files"), case `locked`: first run, then a new rule `shared/rules/new.md` is
  committed (so the manifest would change), the manifest is copied aside, the manifest is
  held (`Hold-File (M) Read Read`), and the run is made in `try`, with `Release-Held` in
  `finally`.
- Checks:
  1. `ps1 locked: rules manifest held open by a reader -- ERROR row, exit 1, run completes`:
     exit 1; row `ERROR|harness files|rules manifest not written`; log
     `[error] Rules manifest: cannot write .* -- manifest not written`; `new.md` deployed;
     `Skills manifest: wrote` logged (the run went on).
  2. `ps1 locked: the old rules manifest unchanged byte for byte, no .tmp left`.
  3. `ps1 locked: released -- the next run writes the rules manifest`: exit 0, manifest
     exactly `hook-lifecycle.md / new.md / scratch.md` (all `shared`), no ERROR row.
- Observed product text (from mutation log `mut-dh-mf-b-flip.log`): `Rules manifest: cannot
  write ...\locked\home\.aitools\rules\.aitools-rules-manifest: Exception calling "Move"
  with "3" argument(s): "Access to the path is denied." -- manifest not written`.

### 2b. deploy-harness: a file in a retired skill held open with no sharing

- Product: Remove-RetiredSkill (`deploy-harness.ps1:630-677`): Copy-SkillTree (534-543)
  throws at `File.Copy` (541); the `catch` (646-650) logs `Retired skill ${Name}: backup
  failed ($_) -- $d not removed`, writes ERROR `retire failed: <name>`, calls
  Remove-SkillBackupCopy (552-594), which deletes the half-made backup and logs `removed
  the incomplete backup` (572).
- Harness: same case, after 2a: `s2\SKILL.md` copied aside, `shared/skills/s2` removed
  from the source, `s2\SKILL.md` held (`ReadWrite None`) during the run, released in
  `finally`.
- Checks:
  1. `ps1 locked: skill file held open with no sharing -- partial backup removed, skill
     kept (ERROR row, exit 1)`: exit 1; row `ERROR|harness files|retire failed: s2`; log
     `[error] Retired skill s2: backup failed (` and `Retired skill s2: removed the
     incomplete backup`; no `s2.bak.*` directory; no `bak cleanup failed` row.
  2. `ps1 locked: the skill unchanged byte for byte`: `SKILL.md` equals the copy taken
     before, and it is the only entry in `s2`.
  3. `ps1 locked: released -- the next run backs up and removes the skill`: exit 0, `s2`
     gone, exactly one `s2.bak.*` holding `skill two`, manifest line `s2<TAB>retired`.
- Observed product text (`mut-dh-sk-b-flip.log`): `Retired skill s2: backup failed
  (Exception calling "Copy" with "3" argument(s): "The process cannot access the file
  '...\skills\s2\SKILL.md' because it is being used by another pr[ocess]` and `Retired
  skill s2: removed the incomplete backup ...\skills\s2.bak.2026-11-14T214023Z`.
- The checks do not match the .NET message ("being used by another process"): it is
  localized, so it would fail on a non-English Windows. Mutation (a) shows the hold is
  the cause instead.

Probe (deploy-harness, before the case): on `lock-probe\m` in the temp root, a Read/Read
hold must leave `ReadAllLines` working and block `File.Move` over the file; a
ReadWrite/None hold must block `File.Copy`; after release both must work. Otherwise
`SKIP locked-file cases (an open handle does not block a replace or a copy here)`.

### 2c. rules-fanout: the rules manifest held open with no sharing

- Product: `scripts/setup-user-claude.ps1:411-421`: Read-RulesManifest ->
  Read-HarnessManifest (`aitools-lib.ps1:3031-3062`, `ReadAllText` at 3039) throws; `catch`
  logs `Cannot read the rules manifest ${rulesManifest}: $_ -- every rule fanned out, none
  retired`, writes ERROR `cannot read rules manifest`, sets `$manifestFailed` (final row
  ERROR). The fan-out still runs.
- Harness: `tests/rules-fanout/test-rules-fanout.ps1` lines 607-665: case
  `manifest-locked`, seeded like `manifest-unreadable` (`a.md|shared`, rule `a.md`); the
  seed copies the manifest aside and opens it `ReadWrite, None` into `$script:Held`; the
  `Case-Run` is in `try`, the handle closed in `finally` (and again in the suite's outer
  `finally`, line 685).
- Checks:
  1. `ps locked: manifest held open with no sharing -- rules fanned out, ERROR rows, final
     row ERROR, exit 1`: exit 1; `a.md` fanned out; rows `ERROR|claude rules|cannot read
     rules manifest` and `DETAIL|claude rules|failed: .aitools-rules-manifest`; last
     non-DETAIL row `ERROR|claude rules|1 failed`; log `[error] Cannot read the rules
     manifest `.
  2. `ps locked: the manifest unchanged byte for byte`.
  3. `ps locked: exit code, ~/.claude/rules and summary rows match golden
     manifest-unreadable (same outcome)`: the same result file as the ACL case, compared
     with the committed `tests/rules-fanout/golden/manifest-unreadable.result`.
     `Parity` got two optional parameters (`$Golden`, `$CheckName`) for this; with neither
     given it prints the same name and compares the same file as before (every old parity
     line is unchanged, section 3).
  4. `ps locked: released -- the next run is clean (verified, exit 0)`: `Rerun` in the same
     HOME: exit 0, `OK|claude rules|1 verified`, no ERROR row.
- Observed product text (`mut-rf-b-flip.log`): `Cannot read the rules manifest
  ...\manifest-locked\ps\.aitools\rules\.aitools-rules-manifest: Exception calling
  "ReadAllText" with "2" argument(s): "The process cannot access the file ...`.
- The product does what the prompt and 38dc-20 row 13 expected: the same outcome as the
  unreadable manifest.

Probe: `Test-LockBlocks` (ReadWrite/None on `lock-probe\item` must block `ReadAllText`, and
the read must work again after release). Otherwise `SKIP manifest held open (an open
handle with no sharing does not block reads here)`.

Header comments: deploy-harness line 16 now lists "files held open by another program"
(the header keeps its 39 lines, which `-Help` prints with `-TotalCount 39`); rules-fanout
header gained four lines on the locked case (its `-Help` reads the whole comment block).

## 3. Before / after

Runs: `W\.scratch\session-e9d6-18\run-suites.ps1 -Tag before|after` (each suite `pwsh
-NoProfile -File tests\<dir>\<suite>.ps1 *> <scratch>\<suite>-<tag>.log`). Comparison:
`compare.ps1` (the PASS/FAIL/SKIP lines of `before` must appear in `after` in the same
order and unchanged, the rest listed as new).

| Suite | before | after | old lines present, unchanged, same order | new lines |
|---|---|---|---|---|
| deploy-harness | 109 passed, 0 failed, 0 skipped (exit 0) | 115 passed, 0 failed, 0 skipped (exit 0) | True (109 of 109) | 6 `PASS ps1 locked: ...` |
| rules-fanout | 65 passed, 0 failed, 2 skipped (exit 0) | 69 passed, 0 failed, 2 skipped (exit 0) | True (67 of 67, both old SKIP lines included) | 4 `PASS ps locked: ...` |

The files were not edited after the `after` run (SHA-256 before the mutations, and again
after them: deploy-harness `29A70552...0B8785`, rules-fanout `4B5A8C28...99E3AC`).

## 4. Mutation checks

`W\.scratch\session-e9d6-18\mutate.ps1`: one exact text replacement (it must occur once,
else ABORT), one suite run, the file restored byte for byte in a `finally`, SHA-256
compared. Logs `mut-<name>.log`. Every mutation: restored byte-identical = True.

| Mutation | Change | Result |
|---|---|---|
| dh-mf-a-nohold | `Hold-File (M) Read Read` removed | exit 1, 113/2/0: FAIL `...held open by a reader -- ERROR row...` and FAIL `...unchanged byte for byte...` (the manifest was written); retry line PASS |
| dh-mf-b-flip | expected row `rules manifest not written` -> `skills manifest not written` | exit 1, 114/1/0: FAIL `...held open by a reader...` only |
| dh-mf-c-early | `Hold-File (M) Read Read; Release-Held` (released before the run) | exit 1, 113/2/0: the same two FAILs as (a); retry line PASS |
| dh-sk-a-nohold | the skill `Hold-File` removed | exit 1, 113/2/0: FAIL `skill file held open...` and FAIL `the skill unchanged...` (it was retired); retry line PASS |
| dh-sk-b-flip | expected row `retire failed: s2` -> `retire failed: s1` | exit 1, 114/1/0: FAIL `skill file held open...` only |
| dh-sk-c-early | skill hold then `Release-Held` before the run | exit 1, 113/2/0: same two FAILs as (a) |
| dh-probe-noblock | `$haveLock = ($lockBlocked -eq 3)` (the probe says "does not block") | exit 0, 109/0/1: `SKIP locked-file cases (an open handle does not block a replace or a copy here)`; no FAIL |
| rf-a-nohold | `$script:Held = $null` (no hold) | exit 1, 67/2/2: FAIL `manifest held open...` and FAIL the parity line; `unchanged byte for byte` and retry PASS |
| rf-b-flip | expected final row `1 failed` -> `2 failed` | exit 1, 68/1/2: FAIL `manifest held open...` only |
| rf-c-early | hold, then `$script:Held.Dispose()` inside the seed (released before the run) | exit 1, 67/2/2: same two FAILs as (a) |
| rf-probe-noblock (first try) | probe hold `ReadWrite, None` -> `ReadWrite, ReadWrite` | exit 0, 69/0/2, still PASS: my mutation was wrong, not the harness (a writer with ReadWrite sharing still blocks ReadAllText, see section 1) |
| rf-probe-noblock | probe hold -> `Read, Read` (an ordinary reader) | exit 0, 65/0/3: `SKIP manifest held open (an open handle with no sharing does not block reads here)`; no FAIL |

Why (a) gives FAIL, not SKIP: the probe runs on its own file and does not know about the
case's hold, so a case that loses its hold FAILs on its ERROR-row check. That is the
right outcome: a missing hold is a broken test and must be loud. SKIP is only for a
machine where an open handle really does not block, which the probe mutations show.
The rules-fanout `the manifest unchanged byte for byte` check stays PASS under (a) and
(c), as it should: setup-user-claude never writes the manifest; that check guards
against the product touching the file, not the hold. The same holds for both "released"
retry lines: they describe the clean state after release.

## 5. Leftover processes and temp roots

`W\.scratch\session-e9d6-18\leftovers.ps1` lists `deploy-harness-<12 hex>` /
`rules-fanout-<12 hex>` folders in the temp dir and any process whose command line names
one of them, `holder.ps1` or either suite.
- During the `after` run (as a control): 1 root, 2 processes (the suite and its
  deploy-harness.ps1 child), so the check does see them.
- After the `after` run: `temp roots left: 0`, `processes from the suites: 0`.
- After all 12 mutation runs: `temp roots left: 0`, `processes from the suites: 0`.
- The harness cases start no child of their own (the handle is in the harness process),
  so nothing new can be left behind; the probe's `holder.ps1` children were all ended
  (`children alive=0`).

## 6. Parser, git state

- PowerShell parser (`parse.ps1`, `Parser]::ParseFile`): both files `parser OK` (final
  bytes).
- `git diff --check`: clean (only git's "LF will be replaced by CRLF" note for
  rules-fanout, whose working copy was already LF before this mission, e9d6-17 report
  section 6). deploy-harness working copy stays all CRLF (`git ls-files --eol`:
  `i/lf w/crlf`).
- `git diff --numstat`: deploy-harness +93/-2, rules-fanout +74/-5.
- `git diff --stat -- tests/*/golden tests/lib scripts`: empty. No .sh file touched; no
  .sh suite run; nothing run against the real HOME.
- `git status --short`: the two harnesses modified, this report untracked.

## 7. Observations (not filed; for 38dc-13 to triage)

- OBS-1 (correction to 38dc-20 probe 8's wording): replacing a file that is open fails on
  Windows even when the holder grants FILE_SHARE_DELETE (measured: ReadWrite+Delete hold,
  in-process and child, File.Move BLOCKED). So any program with the manifest open blocks
  the replace, not only one "without delete-sharing". Not a product defect: the product
  reports the ERROR row and the next run writes the manifest (2a).
- OBS-2 (product, low): a retired skill whose file is held by an ordinary reader
  (FileShare.Read): the backup copy succeeds and is verified, then `Remove-SkillTree`
  (`Directory.Delete($d, $true)`) deletes the other files and fails on the held one
  (probe E: `skill dir left: SKILL.md`). The product then logs `cannot remove`, ERROR
  `retire failed` (`deploy-harness.ps1:663-671`) and leaves a half-deleted skill
  directory. No data is lost (a complete, verified backup exists), and the next run
  retires the remnant, which leaves a second, partial backup beside the complete one.
  Not tested here (out of the prompt's three paths). Suggest: no change now; if wanted,
  a later case or a rename-then-delete in Remove-RetiredSkill.

## 8. Lines for 38dc-13

RELEASE_NOTES row (Improvements):

`| N | Windows test harnesses: locked-file cases (a file held open by another program) for the deploy-harness rules manifest replace, the retired-skill backup copy, and the setup-user-claude rules manifest read; each checks the ERROR row, the log, that the user's file is unchanged and that the next run succeeds; probe-gated (SKIP where an open handle does not block); Windows only by design (POSIX never blocks on an open file) |`

Review after:

`tests/deploy-harness/test-deploy-harness.ps1: no locked-file coverage -> section "Locked files" (Hold-File/Release-Held, lock probe, case "locked": 6 "ps1 locked:" checks), handles closed in the outer finally, header line 16; tests/rules-fanout/test-rules-fanout.ps1: no locked-file coverage -> Test-LockBlocks, SameBytes, case "manifest-locked" (4 "ps locked:" checks, parity against golden manifest-unreadable), Parity gains optional -Golden/-CheckName (old calls unchanged), header +4 lines, handle closed in the outer finally.`

- INCIDENT: none.
- CONFLICT: the "Auto mode" system text (use Bash cat/sed for file work) vs the user's
  USO "Dedicated tools for file ops" -- resolved by tier 1 (the commander's standing
  order): Read/Edit/Write/Grep for files, perl only for the two scratch-file edits.
- WRITE_BLOCKED: none.

## 9. Open questions (with suggested answers)

1. Assert the .NET text "being used by another process" to prove the cause? Suggested:
   no; it is localized (a non-English Windows would FAIL), and mutations (a)/(c) already
   prove the hold is what makes the checks pass.
2. Move `Hold-File` / `Release-Held` / the lock probes into `tests/lib/platform-lib.ps1`
   with the ACL helpers (e9d6-07 and e9d6-17 open questions)? Suggested: yes, in the same
   follow-up that moves the deny helpers; out of this mission's scope (tests/lib).
3. Cover OBS-2 (half-deleted retired skill under a FileShare.Read holder)? Suggested: not
   now; no data loss, and it needs a product decision (accept, or rename the directory
   before deleting it) before a test can pin the behaviour.
4. Confirm on the first Windows CI run that deploy-harness gives 115/0/0 and rules-fanout
   69/0/2. Suggested: yes; a SKIP line naming "open handle" there would mean the runner
   does not block, with no failure.

## 10. Files

- Changed: `tests/deploy-harness/test-deploy-harness.ps1`,
  `tests/rules-fanout/test-rules-fanout.ps1`.
- Scratch (`W\.scratch\session-e9d6-18\`): `run-suites.ps1`, `compare.ps1`, `parse.ps1`,
  `mutate.ps1`, `leftovers.ps1`, `probe-lock.ps1`, `holder.ps1`; logs
  `<suite>-before|after.log`, `mut-*.log`, `probe-lock.log`.
- This report: `W\.aitools\channel\handoffs\2026-11-14_87795dc3-missions\38dc-13\e9d6-18-report.md`.
