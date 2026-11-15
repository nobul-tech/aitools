# e9d6-17 report: every deny right the rules-fanout and skills-legacy .ps1 harnesses use is probed first (v1.0)

Mission e9d6-17-deny-probe, delegated by 38dc-13-windows-ci-ps1-only (RFI 38dc-20-1).
Worktree `C:\Users\jdpal\repos\aitools\.claude\worktrees\38dc-13`, branch
`fix/38dc-13-windows-ci-ps1-only` (HEAD 4f3705b at the start, 65f2aca at the end: the
merge of origin/main touched only `tests/managed-files/*`, nothing these two suites use;
`git diff --stat 4f3705b HEAD -- tests/rules-fanout tests/skills-legacy tests/lib tests/managed-files scripts`).
Not committed, not pushed (prompt: 38dc-13 verifies, commits and ships).

## Summary

1. Both harnesses now probe every deny right their ACL cases use (ReadData on a file,
   ListDirectory on a folder, and in skills-legacy CreateFiles + CreateDirectories +
   DeleteSubdirectoriesAndFiles on a folder) with one helper, `Test-DenyBlocks KIND`.
2. Each group of ACL cases is gated on the probes of all the rights it uses; a group
   whose deny does not block prints one SKIP line (as the .sh does), never FAIL lines.
3. When the probes pass (this machine), the output is identical to before: rules-fanout
   65/0/2, skills-legacy 40/0/0, same lines in the same order.
4. Six mutation runs: every forced-false probe and the no-op deny helper give SKIP, exit 0,
   no FAIL; the per-right gating is independent (forcing `list` false leaves the create
   case PASS, forcing `create` false leaves the unreadable cases PASS).
5. No SKIP text says chmod any more; no deny ACE or temp root left after any run.

## 1. Rights used and the checks that depend on each

### tests/rules-fanout/test-rules-fanout.ps1

| Right (Deny-Access) | Target | Case | Check lines that depend on it |
|---|---|---|---|
| ListDirectory | folder `~/.aitools/rules` | `unreadable` | `unreadable harness dir: ERROR row, exit 1`; `parity: unreadable: ...` |
| ReadData | file `~/.aitools/rules/.aitools-rules-manifest` | `manifest-unreadable` | `unreadable manifest: rules fanned out, ERROR rows, final row ERROR, exit 1`; `parity: manifest-unreadable: ...` |

One group (the .sh has one: `if $CAN_CHMOD_READ` around both cases,
`tests/rules-fanout/test-rules-fanout.sh` lines 452-466), now gated on
`$denyBlocksList -and $denyBlocksRead`.

### tests/skills-legacy/test-skills-legacy.ps1

| Right (Deny-Access) | Target | Case | Check lines that depend on it |
|---|---|---|---|
| ReadData | file `~/.aitools/skills/.aitools-skills-manifest` | `ps-mfu` | `ps unreadable manifest: exit 1, ERROR skills row, reverse discovery not run`; `golden ps: mfu: summary rows` |
| ListDirectory | folder `~/.aitools/skills` | `ps-hdu` | `ps unreadable ~/.aitools/skills: ...`; `golden ps: hdu: summary rows` |
| ListDirectory | folder `~/.claude/skills` | `ps-dstu` | `ps unreadable ~/.claude/skills: ...`; `golden ps: dstu: summary rows` |
| CreateFiles, CreateDirectories, DeleteSubdirectoriesAndFiles | folder `dp-ps-adoptfail/claude/skills` | `ps-adoptfail` (pty) | `ps pty adopt failure (fanned out): ...`; `golden ps: adoptfail: summary rows` |

Two groups, as in the .sh (`tests/skills-legacy/test-skills-legacy.sh` lines 363-390 and
412-424): the unreadable group, now gated on `$denyBlocksRead -and $denyBlocksList`, and
the adopt-failure case, now gated on `$denyBlocksCreate` (inside the existing `$havePty`
gate). Before, both were gated on the read probe only.

## 2. The probes added

`Test-DenyBlocks KIND` (plus `Test-Succeeds { ... }`, whose caught error is the "blocked"
answer) replaces `Test-DenyBlocksRead` in both files. It works on a throwaway folder
`acl-probe-<KIND>` in the suite's temp root (rules-fanout `$tmpRoot`, skills-legacy `$W`)
holding one file `item`, applies the same rights through the harness's own `Deny-Access`,
and returns `$true` only when:

| KIND | Deny | Must fail under the deny | Also required |
|---|---|---|---|
| read | ReadData on `item` | `[IO.File]::ReadAllText` | after `Undo-Deny`, the read works again |
| list | ListDirectory on the folder | `Get-ChildItem -LiteralPath -Force -ErrorAction Stop` (what setup-user-claude.ps1 line 388 and setup-user-skills.ps1 lines 233/295 call) | after `Undo-Deny`, the listing works again |
| create (skills-legacy only) | CreateFiles, CreateDirectories, DeleteSubdirectoriesAndFiles on the folder (the adopt-failure case's exact rights) | a new file, and separately a new folder | the existing `item` stays writable under the deny; after `Undo-Deny`, both creates work again |

If `Deny-Access` throws, the probe prints `| ACL deny not available (KIND): ...` and
returns `$false`. The probe folder is removed afterwards (a failure to remove it is
printed, not swallowed). The probes now run as the first statements inside the main
`try`, so the outer `finally` (the `$script:Denied` sweep and `Remove-TestTempRoot`) also
covers an interrupted probe; before, `Test-DenyBlocksRead` ran before the `try`.

Header comments updated in both files (the probe and its one-SKIP-per-group behaviour),
and the adopt-failure comment corrected (see 6, observation).

## 3. SKIP texts, old -> new

| File | Old | New |
|---|---|---|
| rules-fanout | `SKIP unreadable harness dir and manifest (root or Git Bash)` | `SKIP unreadable harness dir and manifest (a deny ACE does not block listing or reads here)` |
| skills-legacy | `SKIP ps unreadable cases (chmod does not block reads here)` | `SKIP ps unreadable cases (a deny ACE does not block reads or listing here)` |
| skills-legacy | `SKIP ps pty adopt failure (chmod does not block writes here)` | `SKIP ps pty adopt failure (a deny ACE does not block writes here)` |

Wording follows the model in tests/deploy-harness/test-deploy-harness.ps1 lines 586 and
773 ("(a deny ACE does not block writes here)"). Unchanged and out of scope: the two
rules-fanout SKIPs that are not ACL cases (`case-only duplicate (case-insensitive file
system)`, `dangling symlink (Git Bash)`). `grep -n chmod` on the two files: 15 hits, all
comments that name the .sh's mechanism; none in a SKIP text.

## 4. Before / after PASS lines

Runs: `pwsh -NoProfile -File <scratch>/run-suites.ps1 -Tag <tag>` (runs each suite with
`pwsh -NoProfile -File tests/<dir>/test-<dir>.ps1 *> <scratch>/<suite>-<tag>.log`, then
lists leftover `rules-fanout-*` / `skills-legacy-*` temp roots). Comparison:
`<scratch>/compare.ps1` (PASS/FAIL/SKIP lines and the final line, positional, case-sensitive).

| Run | rules-fanout | skills-legacy | leftover temp roots |
|---|---|---|---|
| before (original files) | 65 passed, 0 failed, 2 skipped (exit 0) | 40 passed, 0 failed, 0 skipped (exit 0) | 0 |
| after (probes added) | 65 / 0 / 2 (exit 0) | 40 / 0 / 0 (exit 0) | 0 |
| restored (after the mutations) | 65 / 0 / 2 (exit 0) | 40 / 0 / 0 (exit 0) | 0 |
| final (final bytes, after two comment-only edits) | 65 / 0 / 2 (exit 0) | 40 / 0 / 0 (exit 0) | 0 |

`compare.ps1 -A before -B after`: rules-fanout 68 lines, skills-legacy 41 lines,
identical (text and order) = True for both. Same for `-B restored` and `-B final`.

The two non-ACL SKIP lines are unchanged too: the rules-fanout run keeps
`SKIP case-only duplicate (case-insensitive file system)` and `SKIP dangling symlink (Git Bash)`.

## 5. Mutation checks

`<scratch>/mutate.ps1`: each mutation is one exact text replacement (must occur exactly
once, else ABORT) in the harness in place, one run, and a byte restore in a `finally`;
the restored file's SHA-256 must equal the one before the mutation.

| Mutation | Change | Expected | Result | Restored byte-identical | Leftover roots |
|---|---|---|---|---|---|
| a-all-rf | `return $blocks` -> `return $false` (every probe says "does not block") | 61/0/3, new SKIP | exit 0, 61 passed, 0 failed, 3 skipped; `SKIP unreadable harness dir and manifest (a deny ACE does not block listing or reads here)` | True | 0 |
| a-all-sl | same, skills-legacy | 32/0/2, both new SKIPs | exit 0, 32/0/2; `SKIP ps unreadable cases (...)`, `SKIP ps pty adopt failure (...)` | True | 0 |
| a-list-sl | `$denyBlocksList = (Test-DenyBlocks list) -and $false` | unreadable group SKIP, adopt failure still PASS | exit 0, 34/0/1; only `SKIP ps unreadable cases (...)`; `PASS ps pty adopt failure (fanned out): ...` and `PASS golden ps: adoptfail` still run | True | 0 |
| a-create-sl | `$denyBlocksCreate = (Test-DenyBlocks create) -and $false` | adopt failure SKIP, unreadable group still PASS | exit 0, 38/0/1; only `SKIP ps pty adopt failure (...)`; the three `PASS ps unreadable ...` lines still run | True | 0 |
| b-rf | `Deny-Access` adds no rule (the `$acl.AddAccessRule(...)` line removed, so Set-Acl writes the ACL unchanged) | probe catches it: SKIP, not FAIL | exit 0, 61/0/3, the new SKIP line | True | 0 |
| b-sl | same, skills-legacy | probe catches it: SKIP, not FAIL | exit 0, 32/0/2, both new SKIPs | True | 0 |
| c | restore, rerun | the original PASS lines | the "restored" row in section 4: identical to before | n/a | 0 |

Logs: `<scratch>/mut-<name>.log`. No mutation log, and no suite log, holds a `FAIL ` line,
`FATAL`, `could not remove`, `ACL deny not available` or `deny probe` (Grep over
`<scratch>/*.log`, no match). `grep MUTATION tests/` after the mutation script: no match.

## 6. Leftover ACEs, golden files, git state, parser

- Leftover ACE / temp-root check: after every run above (before, after, six mutations,
  restored, final) `run-suites.ps1` / `mutate.ps1` listed 0 `rules-fanout-*` /
  `skills-legacy-*` directories in the temp dir; every deny ACE lives on an item inside a
  temp root, so none is left. No log holds `could not remove the deny entry` or
  `could not remove the temp root`.
- `git -C W diff -- tests/rules-fanout/golden tests/skills-legacy/golden`: empty.
- `git -C W status --short` (at the end): ` M tests/rules-fanout/test-rules-fanout.ps1`,
  ` M tests/skills-legacy/test-skills-legacy.ps1` (and this report, untracked).
- Parser (`<scratch>/parse.ps1`, `[System.Management.Automation.Language.Parser]::ParseFile`):
  both files `parser OK`, after every edit.
- Diff size (`git diff --numstat`, final): rules-fanout +49/-19, skills-legacy +70/-21.

Observation (evidence for a comment fix, `<scratch>/probe-delete.ps1`, user not elevated):
a non-inheriting deny of CreateFiles + CreateDirectories + DeleteSubdirectoriesAndFiles on
a folder blocks a new file and a new subfolder, but NOT deleting an existing file or an
existing empty subfolder in it, and not listing or writing an existing file (why: the
child's own inherited ACL grants DELETE, and Windows allows a delete through either
DELETE on the child or FILE_DELETE_CHILD on the parent; that is from knowledge of the
Windows access model, not re-read this session; the outcome below is measured):

```
new file: BLOCKED (MethodInvocationException)
new subdir: BLOCKED (MethodInvocationException)
write existing file: allowed
list: allowed
delete existing file: allowed
delete existing empty subdir: allowed
cleanup: removed=True
```

So the old comment "a deny of creating, and deleting, entries in it" overstated it. The
adopt-failure case needs only the creates to fail (its target `claude/skills/mine` does
not exist yet), so behaviour is unaffected; the comment now says "a deny of creating
entries in it", and the probe's header says deletion is not probed and why. Unlike
`chmod 555`, this deny would not stop a delete; no case here relies on that.

Line endings: the two files' working copies are LF while `.gitattributes` says
`eol=crlf` (`git ls-files --eol`: `i/lf w/lf attr/text eol=crlf`); git warns "LF will be
replaced by CRLF the next time Git touches it". The index is LF either way, so the commit
is unaffected. Unknown whether they were LF before my edits (the files were added in
1e454ca by e9d6-03; the before-run would not show it).

## 7. Lines

- WRITE_BLOCKED: none.
- CONFLICT: none. (Prompt "one SKIP per group, as the .sh does" and "gate each group on
  the probe for the rights it uses": kept the .sh's groups and gated each on all the rights
  it uses, rather than splitting groups by right.)
- INCIDENT: none filed or proposed. (Hook note, not an incident: the standing-order-guard
  blocked a Monitor command containing `;` inside an `until ...; do ...; done` loop on
  three calls while allowing the same shape on others; I used single-condition monitors
  already armed instead. Unknown why it varied.)

## Identity note

Asked mid-mission "do you know your agent id": I know my mission name, e9d6-17
(e9d6-17-deny-probe), given by 38dc-13 (whose agent id ends e9d6). My own Claude Code
subagent id is not in my context, so I do not know it. The only id visible to me is the
parent session's, 87795dc3-e9b0-4f82-937b-139b3f13fa81 (from the scratchpad path).

## 8. Open questions (with suggested answers)

1. Move `Deny-Access` / `Undo-Deny` / `Test-Succeeds` / `Test-DenyBlocks` and the
   `$script:Denied` sweep into `tests/lib/platform-lib.ps1`? They are now duplicated in
   two harnesses, and deploy-harness has its own variant (`Add-Deny` / `Undeny`).
   Suggested: yes, as a follow-up after 38dc-13 merges (it touches tests/lib, out of this
   mission's scope); e9d6-03 open question 2 suggested the same.
2. Should the adopt-failure deny drop DeleteSubdirectoriesAndFiles, since it does not stop
   deleting existing entries? Suggested: keep it (harmless, documents the intent of
   `chmod 555`, and the probe applies the exact same rights); the corrected comments say
   what it does and does not block.
3. Split the rules-fanout group (list vs read) and the skills-legacy unreadable group
   (mfu vs hdu/dstu) so a single non-blocking right skips fewer cases? Suggested: no; it
   would diverge from the .sh's SKIP structure, and on the one non-blocking cause the
   harness comments name (backup privilege) read and list would presumably fail together
   (from knowledge, not verified: no elevated or backup-privileged run here).
4. Confirm on the first Windows CI run (elevated `runneradmin`) that the output stays
   65/0/2 and 40/0/0. Suggested: yes; three SKIP lines with "(a deny ACE does not block
   ...)" there would mean a right does not block on the runner, with no failure.

## 9. Files

- Changed: `tests/rules-fanout/test-rules-fanout.ps1`, `tests/skills-legacy/test-skills-legacy.ps1`.
- Scratch (`.claude/worktrees/38dc-13/.scratch/session-e9d6-17/`): `run-suites.ps1`,
  `compare.ps1`, `parse.ps1`, `mutate.ps1`, `probe-delete.ps1`; logs
  `<suite>-before|after|restored|final.log`, `mut-*.log`.
- This report: `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/38dc-13/e9d6-17-report.md`.
