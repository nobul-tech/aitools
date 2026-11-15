# e9d6-19 report: deploy-harness tries, logs and retries the delete of a retired skill it cannot fully delete (v1.0)

Mission e9d6-19-retire-retry, delegated by 38dc-13-windows-ci-ps1-only (RFI 38dc-9, OBS-2 of
e9d6-18). Worktree `C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`, branch
`fix/38dc-13-windows-ci-ps1-only` at `2331302`. Not committed, not pushed (38dc-13 verifies,
commits and ships). Machine: Windows 11, pwsh 7, not elevated.

## Summary

1. The product already does all three things the commander asked for (try, log, retry), on
   both platforms' code: no product code changed (`scripts/deploy-harness.ps1` and `.sh`
   untouched, SHA-256 of the .ps1 `D860D867...609BF75` before and after).
2. New probe-gated case "locked retry" in `tests/deploy-harness/test-deploy-harness.ps1`
   (+56 lines, 865-919): a reader holds `s1\SKILL.md` across two runs, then releases; 5 new
   checks. Suite 115/0/0 -> 120/0/0; all 115 old lines unchanged, same order.
3. Mutations: no hold, ERROR->WARN row in run 1 and in run 2, release before run 2: each
   FAILs the intended checks (exit 1); probe says "does not block": one SKIP, exit 0. File
   restored byte-identical after every mutation.
4. Found while testing: (i) a run in the same UTC second as the last backup does not try the
   delete (`backup failed (... already exists)`, still logged + ERROR row, retried next run);
   (ii) backups accumulate one per failed run and are pruned only after the delete succeeds,
   to the newest 5: after 5 or more failed runs the one complete backup is pruned (measured).
5. No leftover process or temp root; parser OK; `bash -n` OK on the unchanged .sh. No
   incident filed (commander's words).

## 1. Answers (a)-(e)

Line numbers are the current worktree files.

**(a) Run N tries the delete: yes.** `Write-HarnessManifest` turns the previous
`s1<TAB>shared` line into a `retire` action and the line into `retired`
(`Get-HarnessManifestPlan`, `scripts/deploy-harness.ps1:439-441`), then calls
`Remove-RetiredSkill` for the directory (`:701-724`). `Remove-RetiredSkill` (`:630-677`) copies
the skill to `s1.bak.<UTC>` (`:638`, `:644-651`), verifies the copy (`:652-662`; a reader
permits both the copy and the hash), then `Remove-SkillTree` = `Directory.Delete($d, $true)`
(`:547-549`, called at `:663-667`). Measured: the delete removed `tests\` and left only the held
`SKILL.md` (check 1 below). .sh twin: `retire_skill_dir` (`scripts/deploy-harness.sh:592-627`),
`rm -rf` at `:618`.

**(b) It logs that it could not, with an ERROR row: yes.** `:663-672`: the delete exception
goes to `LogDetail` (`:666`), then, because the directory still exists, `LogError "Retired
skill ${Name}: cannot remove $d"` (`:669`) and `Write-Summary "ERROR" $tool "retire failed:
<name>"` (`:670`). `LogError` counts an error, so the run exits 1 (`:819-821`). .sh:
`:618-621` (`log_error`, `write_summary ERROR`), same texts. Measured log line:
`[error] Retired skill s1: cannot remove C:\...\locked-retry\home\.aitools\skills\s1`; row
`ERROR|harness files|retire failed: s1`; exit 1.

**(c) Every later run tries again, logs and rows again: yes.** The manifest written on run N
holds `s1<TAB>retired` (the manifest write does not depend on the retire outcome, `:733-758`).
On run N+1 the planner reads that line as a `stale` action and keeps it `retired`
(`:436-438`); `stale` takes the same branch as `retire` (`:701`), so `Remove-RetiredSkill` runs
again while the directory exists, on every run, with the same log line and row. The line stays
until a source has the name again (`:435`). .sh: `:480-482`, `:651-663`. Documented:
`reference/harness.md` "Skills manifest and retired skills" ("Any failure is `log_error` + an
ERROR row and the directory stays (the next run tries again)"). Measured on run 2 (still held):
same log line once, same ERROR row, exit 1, `s1<TAB>retired` kept. One exception, found by the
first version of this case: (i) in section 4.

**(d) After release the next run completes the removal: yes.** Run 3: copy, verify, delete
succeeds, `Log "Removed $d (retired skill; backup $bak)"`, DETAIL `retired: skills/s1`,
`Remove-OldSkillBackups` (`:673-676`); exit 0, no ERROR row, manifest still `s1<TAB>retired`.
.sh: `:623-626`.

**(e) Backups on each retry.** Each failed run makes a new `s1.bak.<UTC>` of what is left
(run 1: the complete skill; later runs: only the held file), verified against the remnant, and
keeps it: the failure path returns at `:671` before `Remove-OldSkillBackups` (`:676`), and the
.sh likewise (`:621` vs `:626`). So while the file stays held, one backup directory accumulates
per run, unbounded. The prune (keep the newest 5 by name, `$skillBackupsKeep = 5` `:493`,
`Remove-OldSkillBackups` `:500-528`; .sh `SKILL_BACKUPS_KEEP=5` `:527`, `prune_skill_backups`
`:534-558`) runs only on the successful run. It then bounds the count to 5, but it removes the
oldest first, and the oldest is the only complete backup: when 5 or more runs failed before the
success, the complete backup is pruned and the files deleted on run 1 survive in no backup.
Measured (mutation `demo-prune`: 7 held runs, then release): run 3 logged 3 `Pruned old
backup` lines; the 5 kept backups each hold only `SKILL.md`; `tests\t.md` is in none. This is
compatible with "try, log, retry" (every run tried, logged, and rowed), and the content of a
retired skill normally still exists in its source repo's git history (it is retired because a
source dropped it), so it is a loss from `~/.aitools` only. Not fixed here (not one of (b)-(d);
the prompt rules out redesign). Open question 1.

## 2. The new case

`tests/deploy-harness/test-deploy-harness.ps1:865-919`, inside the "Locked files" section,
after e9d6-18's two cases; Windows only by the section's existing comment (POSIX never blocks
a delete on an open file). Comment block quotes the commander's RFI 38dc-9 answer.

- **Probe** (`:875-892`): a scratch directory `lock-probe-del\d` with files `f`, `g`; hold `f`
  with `Read, Read`; `File.Copy` of `f` must work (else the catch prints `delete-lock probe:
  <message>` and the case SKIPs); `Directory.Delete(d, true)` must throw; after `Release-Held`
  the delete must work. `$haveDelLock = $delBlocked`. Handle released in `finally`. Otherwise:
  `SKIP locked retry case (an open reader does not block a directory delete here)`. Separate
  from e9d6-18's probe so its 115 lines are unaffected.
- **Fixture**: `Setup-Case locked-retry`, first run, then `shared/skills/s1` removed (s1 has
  `SKILL.md` and `tests\t.md`). The hold (`Hold-File "$sk1\SKILL.md" Read Read`) wraps runs 1
  and 2 in `try`; `Release-Held` in `finally`; the suite's outer `finally` also disposes any
  held handle (`:1000-1001`, unchanged).
- **Timing**: `Start-Sleep -Milliseconds 1100` before runs 2 and 3, with a comment: backup
  names have one-second resolution and a run takes under a second here (section 4 (i)).
- **Checks** (5):
  1. `ps1 locked retry: run 1 -- delete tried (tests\ gone, held SKILL.md left), 'cannot
     remove' logged, ERROR row, exit 1, line retired`: rc 1; `tests\` gone and `SKILL.md` the
     only entry; exactly one log line matching `\[error\] Retired skill s1: cannot remove
     .*/\.aitools/skills/s1$`; row `ERROR|harness files|retire failed: s1`; no `retired:
     skills/s1` row; manifest line `s1<TAB>retired`.
  2. `ps1 locked retry: run 1 -- one complete backup (both files)`: one `s1.bak.*`, holding
     `SKILL.md` = `skill one` and `tests\t.md` = `skill one test`.
  3. `ps1 locked retry: run 2, still held -- tried again: 'cannot remove' logged, ERROR row,
     exit 1, line still retired`: same as 1 for run 2's fresh log and summary (the remnant is
     still only `SKILL.md`).
  4. `ps1 locked retry: run 2 -- a second backup (what is left), the complete one kept`: two
     `s1.bak.*`, the complete one still present.
  5. `ps1 locked retry: released -- run 3 removes the directory, line stays retired, DETAIL
     row, no ERROR row, exit 0`: rc 0; `s1` gone; `s1<TAB>retired`; row `DETAIL|harness
     files|retired: skills/s1`; no `ERROR|` row; log `Removed .*/\.aitools/skills/s1 \(retired
     skill; backup `; three `s1.bak.*`, the complete one kept.
- The checks do not match the .NET exception text (localized), as e9d6-18 decided.
- Header comment unchanged: line 16 already lists "files held open by another program", and
  `-Help` prints exactly 39 header lines.

## 3. Product code

Unchanged (`git diff --stat -- scripts` empty). No .sh change, so no parity edit, no golden
file affected, no Review-after line for product code.

## 4. Observations (found while testing; not filed, per the commander)

- **(i) Same-second retry does not try the delete.** The first version of this case ran run 2
  directly after run 1 and FAILed: run 2 started in the same UTC second, found
  `s1.bak.2026-11-14T221237Z` already there and took the collision branch (`:639-643`; .sh
  `:600-604`): `LogError "Retired skill s1: backup failed (<bak> already exists) -- <dir> not
  removed"` + ERROR `retire failed: s1`, no delete attempt; run 3 (next second) removed it. So
  it still logs, rows and retries, but that one run does not "try to delete". Only reachable
  when two runs start within one second of each other (tests; never an interactive `aitools`
  run in practice). Log: `W\.scratch\session-e9d6-19\deploy-harness-after.log` from the first
  attempt was overwritten; the evidence is quoted from that run's FAIL output above.
- **(ii) Backup accumulation and the prune** (section 1 (e)).

## 5. Before / after

`W\.scratch\session-e9d6-19\run-suite.ps1 -Tag before|after`, `compare.ps1`:

| | before | after |
|---|---|---|
| deploy-harness .ps1 | 115 passed, 0 failed, 0 skipped (exit 0) | 120 passed, 0 failed, 0 skipped (exit 0) |

Old lines all present, unchanged, same order: True (115 of 115). New: the 5 `PASS ps1 locked
retry: ...` lines.

## 6. Mutation checks

`W\.scratch\session-e9d6-19\mutate.ps1` (each replacement must occur exactly once; restore in
`finally`; SHA-256 compared). Results `mutate-results.txt`, logs `mut-<name>.log`.

| Mutation | Change | Result |
|---|---|---|
| a-nohold | `Hold-File "$sk1\SKILL.md" Read Read` removed | exit 1, 116/4/0: FAIL checks 1, 3, 4, 5 (run 1 retires s1; check 2 PASS: the backup is complete either way) |
| b1-flip-run1 | run 1 expected row `ERROR|...` -> `WARN|...` | exit 1, 119/1/0: FAIL check 1 only |
| b2-flip-run2 | run 2 expected row `ERROR|...` -> `WARN|...` | exit 1, 119/1/0: FAIL check 3 only |
| c-early | `Release-Held` before run 2 | exit 1, 118/2/0: FAIL check 3 (run 2 succeeds, no retry error) and check 5 (2 backups, not 3); 1, 2, 4 PASS |
| probe-noblock | `$haveDelLock = $false` | exit 0, 115/0/1: `SKIP locked retry case (an open reader does not block a directory delete here)` |
| demo-prune (measurement for (e)) | 5 more held runs before run 2 | exit 1, 118/2/0: checks 4, 5 FAIL by design; `DEMO pruned lines in run 3: 3`; 5 backups left, each `SKILL.md` only |

Every mutation: `restored byte-identical=True`. Final harness SHA-256 `390B7F98...E2FC3651B`,
the bytes of the `after` run.

## 7. Leftovers, parser, git

- `W\.scratch\session-e9d6-18\leftovers.ps1`: control during a mutation run: 1 root, 1
  process (the detector sees them); after all runs: `temp roots left: 0`, `processes from the
  suites: 0`. The case starts no child of its own (the handle is in the harness process).
- PowerShell parser (`eol-parse.ps1`): both .ps1 files `parser OK`. Harness line endings: CRLF
  1026, bare LF 0 (consistent with the CRLF working copy).
- `bash -n scripts/deploy-harness.sh`: OK (unchanged file). No .sh suite run; nothing run
  against the real HOME.
- `git status --short`: ` M tests/deploy-harness/test-deploy-harness.ps1` (+56/-0), plus this
  report. `git diff --check`: clean.

## 8. Lines for 38dc-13

RELEASE_NOTES row (Improvements):

`| N | Windows deploy-harness harness: a "locked retry" case pins the commander's try-log-retry rule for a retired skill that cannot be fully deleted (a file held by a reader across two runs): each run tries the delete, logs "cannot remove", writes an ERROR "retire failed" row and exits 1; after release the next run removes the directory and keeps the manifest line retired; probe-gated (SKIP where an open reader does not block a delete); no product change (the code already did all three) |`

Review after:

`tests/deploy-harness/test-deploy-harness.ps1: no retire-retry coverage -> "Locked files" gains a delete-lock probe and case "locked retry" (5 "ps1 locked retry:" checks, lines 865-919; Start-Sleep 1100 ms before runs 2 and 3 for the one-second backup names).`

- CONFLICT: the "auto mode" system text (use Bash cat/sed for file work) vs USO "Dedicated
  tools for file ops" -- resolved by tier 1 (the commander's standing order): Read/Edit/Write/
  Grep for files.
- CONFLICT: the mission rule "no foreground sleep" (Bash tool) vs the test's need to cross a
  second boundary -- not a conflict on reading: the rule governs Bash tool calls; the
  `Start-Sleep` is in test code. Recorded so 38dc-13 can judge.
- WRITE_BLOCKED: none.
- INCIDENT: none filed (commander: "it should NOT file any incidents").

## 9. Open questions (with suggested answers)

1. Should the prune keep the complete backup when retries made partial ones (section 1 (e))?
   Suggested: yes, as a small follow-up, the smallest form being: on a retry (the line is
   already `retired`), skip making a new backup when an earlier `<name>.bak.<UTC>` exists, or
   never prune the oldest backup of a name. Not done here: (b)-(d) pass, the prompt limits
   changes to failures of (b)-(d), and the source repo's git history still has the content.
2. Fix the same-second collision (section 4 (i)) so a retry always tries the delete? Suggested:
   no; it needs two runs inside one second, which only a test produces, and it still logs,
   rows and retries.
3. Confirm on the first Windows CI run that deploy-harness gives 120/0/0. Suggested: yes; a
   `SKIP locked retry case` line there means the runner's reader does not block a delete, with
   no failure.

## 10. Files

- Changed: `tests/deploy-harness/test-deploy-harness.ps1`.
- Scratch `W\.scratch\session-e9d6-19\`: `run-suite.ps1`, `compare.ps1`, `mutate.ps1`,
  `eol-parse.ps1`, `wait-mutate.sh`; logs `deploy-harness-before.log`,
  `deploy-harness-after.log`, `mut-*.log`, `mutate-results.txt`.
- This report: `W\.aitools\channel\handoffs\2026-11-14_87795dc3-missions\38dc-13\e9d6-19-report.md`.
