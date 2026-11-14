# e9d6-07 report: tests/deploy-harness ported to a native PowerShell harness

Version 1.0, 2026-11-14. Author: e9d6-07-port-deploy-harness (delegated by
38dc-13-windows-ci-ps1-only). Audience: 38dc-13 (verifies, commits, ships).

## Summary

1. New `tests/deploy-harness/test-deploy-harness.ps1`: the Windows harness. It runs
   deploy-harness.ps1 with native pwsh; no case needs Git Bash.
2. Local result: 109 passed, 0 failed, 0 skipped. The Windows CI run on main had 99 passed,
   0 failed, 2 skipped. All 99 PASS lines are the same, in the same order. The 2 SKIPs (the
   chmod read-only cases) are now 10 PASS lines. Their names are the same as in the Linux CI
   run, and they match the shared golden `skills-readonly.trace`.
3. `test-deploy-harness.sh` now has the OS guard and runs on macOS/Linux only. Every
   ps1/windows branch is removed, and the macOS/Linux cases, check names and output are
   unchanged.
4. Mutation proof: 4 mutations, each turns at least one PASS into a FAIL, and the suite
   exits 1. The files were restored, and the golden diff is empty.
5. No product incident found. Contract change requests: 3 optional helper additions to
   tests/lib (below).

## Files changed

- `tests/deploy-harness/test-deploy-harness.ps1`: new, 879 lines. CRLF in the working tree
  (.gitattributes gives `*.ps1` eol=crlf; it was tested that way). ASCII only.
- `tests/deploy-harness/test-deploy-harness.sh`: edited (+66 / -137).
- Golden files are not changed: `git -C W diff -- tests/deploy-harness/golden` is empty.
- `git -C W status --short tests/deploy-harness` shows only
  `M test-deploy-harness.sh` and `?? test-deploy-harness.ps1`.

## What Windows-reached code the suite tests

- `scripts/deploy-harness.ps1`: every section. That is the config-writer call (stub and
  real), the six directories, Add-Source (git ls-files, `*.bak.*`, the flat, flat-md and
  units layouts, hidden and backup skill directories), conflicts (first source wins, case
  folding), Deploy-ManagedFile per file (`-NoReview` for reference/registries),
  Get-HarnessManifestPlan, Remove-RetiredRule, Remove-RetiredSkill with Copy-SkillTree,
  Get-TreeDifference, Remove-SkillBackupCopy and Remove-OldSkillBackups, Write-HarnessManifest,
  preserved files, the summary row and the exit footer, -DryRun, -Force, -Help, a bad
  argument, AITOOLS_DRY_RUN and AITOOLS_FORCE.
- `scripts/aitools-lib.ps1`: Initialize-Logging, Write-Summary, Deploy-ManagedFile, the
  review menu on a ConPTY terminal (Get-ReviewDiff, overwrite, accept & adopt, skip and
  abort), the adopt write-back into the aitools repo ("Uncommitted change in"), and
  Read-HarnessManifest (the reader case).
- `scripts/setup-user-config.ps1`, `aitools-profile.ps1`, `aitools-json.ps1`: the "real
  writer, no bootstrap config" error path.
- `tests/managed-files/pty-run.py`: its Windows backend (pywinpty and ConPTY), which runs the
  interactive cases.

## Windows-relevant behaviours ported, by name (class c: .ps1 equivalent written)

All of the following run as native pwsh children through `Invoke-TestScript`, with HOME and
USERPROFILE set to the case home and stdin at EOF. The interactive cases run through pty-run.py.

- First run: the six directories, 14 added, the config writer called without flags, the
  nested reference tree, registries JSON, untracked and `*.bak.*` files not deployed, hooks
  flat, skills as directories, rules from shared/rules only, no .claude/ or dotprofile
  source, bin CLIs, ".claude/hooks not found" logged as info.
- Rerun, which verifies everything. An edit then a rerun: overwrite, a backup kept,
  "1 updated", the backup not reported as preserved. A preserved file.
- Read-only copies (reference/registries): the source wins, backups kept, no warning.
- Interactive (pty): adopt (LOCAL kept and copied to the repo, logged as uncommitted, a DETAIL
  row, the next run verifies), read-only copies on a terminal (no menu), skip (a WARN row),
  abort (exit 2), -Force and AITOOLS_FORCE=1 on a terminal (no menu).
- Conflicts: exit 1, an ERROR row per duplicate hook, log_error naming both sources, first
  source wins, a case-insensitive duplicate not deployed.
- Dry run (-DryRun and AITOOLS_DRY_RUN=1): counts, nothing written, the writer called with
  --dry-run.
- Config writer failures: the stub with exit 1, and the real writer with no bootstrap config.
- Dotprofile not a source: missing, and not a git checkout.
- Rules manifest: first run, LF and no BOM, retire, the retired line persisting, a retired
  name found again, a name that reappears, the withdrawn sources (aitools, dotprofile;
  dry run, real run, no dotprofile), a source not listed, case-insensitive names, an unknown
  header, invalid lines, a directory named like a retired rule, a retired name with `[ ]`.
- Rules read-only (newly ported, was SKIP): a failed rule backup keeps the file (ERROR row,
  exit 1), the retry, a manifest write failure.
- Skills manifest sequence (`skills.trace` golden): first, dryrun, withdrawn, move, retire,
  rerun, copydeploy, copyretire (`b[1]` pruned to 5, decoy kept), invalid, header, mfdir,
  mfdirgone.
- Skills read-only (newly ported, was SKIP; `skills-readonly.trace` golden): a partial backup
  with an unreadable file, the retry, a partial backup holding a read-only item (the Windows
  attribute-clearing path, below), the retry, a failed backup (skills directory not
  writable), the retry.
- Upper- and mixed-case rule extensions (X.MD, Mixed.Md), the `.BAK.` rejection, DUP.MD in
  the dotprofile, retirement.
- Read-HarnessManifest reader. Arguments: `--bogus` and `-Help`.

Cases that needed Git Bash: none. The suite runs no bash code on Windows. Fixture git
commands use native git (`C:\Program Files\Git\cmd\git.exe`, the same installation and
system config the Git Bash harness used).

## Read-only / ACL cases: now run natively (were SKIP)

Evidence (`.scratch/session-e9d6-07/probe-acl.ps1`, run 2026-11-14, as a user who is not an
elevated admin): a deny ACE for the current user's SID on a directory with CreateFiles and
CreateDirectories, this folder only, blocks a new file and a new directory. Writing an
existing file and listing still work, which is chmod 555 on a directory. Deny ReadData on a
file blocks File.Copy while enumeration still works, which is chmod 000. Removing the ACE
restores access.

- In the harness, Deny-Write, Deny-Read and Undeny wrap Get-Acl and Set-Acl. Every ACE is
  tracked and removed again: after each case, and in the final cleanup if a case throws.
- A probe at the start of the run sets `$haveReadonly`. If a deny ACE does not block on a
  runner, the old two SKIP lines appear instead of failures. The SKIP reason is reworded to
  "(a deny ACE does not block ...)". This is the counterpart of the .sh's root check.
- `.sh` "chmod 555 rs/ro" (the partial backup holds a read-only directory, and the cleanup
  needs `chmod -R u+w`): the Windows counterpart is the ReadOnly attribute on `rs\ro\a.md`.
  Evidence (`probe-order.ps1`): `[IO.Directory]::GetFiles(AllDirectories)` lists
  `SKILL.md, ro\a.md, ro\secret.md`, so a.md is copied before the unreadable secret.md
  fails. File.Copy keeps the ReadOnly attribute (True), and `Directory.Delete(recursive)`
  refuses the tree (UnauthorizedAccessException). So the case exercises
  Remove-SkillBackupCopy's attribute clearing. That is Windows-only product code that had no
  Windows test before.
- Not verified: whether the elevated runneradmin account in CI is blocked the same way. I
  expect it is: deny ACEs apply to every SID in the token, and .NET does not enable backup
  semantics. The probe makes the outcome visible as SKIP rather than FAIL if it is not.

## CI count vs local count

- Windows CI on main ("deploy-harness tests (.ps1, native pwsh)", Git Bash harness): 99 passed,
  0 failed, 2 skipped.
- Local, before the read-only port: 99 passed, 0 failed, 2 skipped, identical to CI line for
  line (`compare-ci.py`: "identical (same lines, same order)").
- Local, final: 109 passed, 0 failed, 0 skipped. The differing lines, all with one reason
  (the read-only cases now run, see above):
  - `- SKIP failed rule backup and manifest write failure (chmod does not block writes here)`
    becomes `+ PASS ps1: failed backup keeps the file (ERROR row, exit 1)`,
    `+ PASS ps1: next run retries and removes it`,
    `+ PASS manifest write failure: ERROR row, exit 1, run completes`
  - `- SKIP skills partial and failed backups (chmod does not block reads or writes here)`
    becomes `+ PASS ps1 skills: partial backup removed again; directory kept (ERROR row, exit 1)`,
    `+ PASS ps1 skills: readable again -- backed up and removed`,
    `+ PASS ps1 skills: partial backup with a read-only subdirectory removed (no leftover, nothing renamed)`,
    `+ PASS ps1 skills: read-only case retried -- backed up and removed`,
    `+ PASS ps1 skills: failed backup keeps the directory (ERROR row, exit 1)`,
    `+ PASS ps1 skills: next run retries -- backed up and removed`,
    `+ PASS skills read-only parity: trace equals the golden file`
  - Final line: `99 passed, 0 failed, 2 skipped (windows: ps1 scripts)` becomes
    `109 passed, 0 failed, 0 skipped (windows: ps1 scripts)`.
- I also compared with the Linux CI run (`compare-linux.py`). After mapping the language word
  sh to ps1 and dropping the sh-only "first run sh: hooks and bin CLIs executable", the 109
  result lines are identical in names and order.

## Harness environment vs the Git Bash harness (contract item 6)

- HOME and USERPROFILE are native backslash paths. The old harness passed `cygpath -m`
  (`C:/...`) forms, which is not what a real Windows profile looks like. No check depends on
  this: the log is still normalized `\` to `/` as before. config.json keeps the forward-slash
  form (`C:/...`), as the old harness wrote it, so no JSON escaping is needed.
- The child pwsh no longer inherits Git Bash's MSYS PATH, TERM or MSYSTEM. Neither
  deploy-harness.ps1 nor the parts of aitools-lib.ps1 it uses read MSYSTEM or SHELL. TERM is
  read only by Test-ReviewColour (colour of the review diff on an interactive console). The
  checks strip ANSI, so no difference was seen and no variable needed setting. Diffs come
  from git (Get-ReviewDiff), not from `diff` on PATH.
- The pty runner's Python: python3, else python, whichever can `import winpty` (a Windows
  Store stub fails the import and is passed over). In CI, python3 is setup-python's, with
  pywinpty installed by the earlier step.
- The reader case captures stdout and stderr separately, as the .sh did (Invoke-TestScript
  merges them). This uses an inline set-and-restore of the three variables.
- A fixture git failure prints `FAIL fixture: git ...` and counts as a failure. The .sh
  ignored it.
- The temp root is deleted with .NET after clearing the ReadOnly attributes git puts on its
  object files, and then Remove-TestTempRoot runs. This is because Remove-Item -Recurse
  treats `[ ]` in names below the root as wildcards (the `b[1]` skill). Not tested: whether
  Remove-TestTempRoot alone would have failed here.

## Mutation results (`.scratch/session-e9d6-07/mutate-dh.ps1`; each file restored in a finally, byte check True)

| Mutation | Change | Check that failed | Exit |
|---|---|---|---|
| a-golden | `golden/skills.trace`: `OK\|harness files\|15 added` -> `16 added` | skills parity: trace equals the golden file (sh and ps1 share it) | 1 (108/1/0) |
| b-expected | harness: first-run row `14 added` -> `13 added` | first run: one OK row, 14 added | 1 (108/1/0) |
| c-env | harness: writerfail `STUB_WRITER_RC = "1"` -> `"0"` | writer failure: exit 1, ERROR row, files still deployed | 1 (108/1/0) |
| d-acl | harness: Deny-Read on `pb\secret.md` removed | ps1 skills: partial backup removed again; directory kept (ERROR row, exit 1); skills read-only parity: trace equals the golden file | 1 (107/2/0) |

Afterwards, `git -C W status --short tests/deploy-harness` showed only the intended changes,
and `git -C W diff -- tests/deploy-harness/golden` was empty.

## Syntax and guard

- `bash -n tests/deploy-harness/test-deploy-harness.sh`: OK. `git diff --check`: clean.
  Bash 3.2: no new constructs (`case`, `${BASH_VERSINFO[5]:-}`, as in the exemplar).
- PowerShell parser (`parse-ps1.ps1`, ParseFile) on the new .ps1: "parse OK", on the final
  CRLF file.
- Guard: `bash tests/deploy-harness/test-deploy-harness.sh` in Git Bash gives exit 1, empty
  stdout, and on stderr "This script is for macOS/Linux. On Windows, run
  tests/deploy-harness/test-deploy-harness.ps1 with pwsh." The guard is at line 43, before
  --help (line 57) and before `mktemp` (line 68), so it writes nothing. The /tmp entry count
  in that check moved (688 to 690), but a harness run was in progress at the same time and
  creates its own temp files, so that count proves nothing. The line order is the evidence.
- The .ps1 OS guard is the exact contract form (first statement after param and the -Help
  line). -Help prints header lines 1-39 and exits 0. Unlike the exemplar's `-Skip 1`, it
  keeps line 1: a .ps1 has no shebang to skip, and skipping it started the help
  mid-sentence.
- The .sh's --help range was updated to `2..39`.

## INCIDENT / CONFLICT / WRITE_BLOCKED

- INCIDENT: none. No product deviation found. Observation, not an incident:
  deploy-harness.ps1 Add-Source writes its git stderr to `[IO.Path]::GetTempFileName()` in
  the real user temp dir (removed right after), even under a test HOME. This is harmless.
- CONFLICT: none. The contract's "same cases ... a SKIP that existed only because of Git Bash
  (e.g. chmod) may become a PASS" covers the read-only port.
- WRITE_BLOCKED: none.

## Contract change requests (tests/lib; optional, none blocking)

1. `Invoke-TestScript -ErrFile F`: capture stderr separately, as several .sh harnesses do
   (`> out 2> err`). Used inline here for the reader case.
2. ACL helpers in `platform-lib.ps1` (Deny-Write, Deny-Read, Undeny, plus the probe and the
   final cleanup), from this harness. The other suites that skip chmod cases on Windows could
   then run them (plan follow-up "Windows symlink / chmod / read-only coverage").
3. `Remove-TestTempRoot`: clear ReadOnly attributes and delete with .NET first. Git object
   files are read-only, and Remove-Item -Recurse can misread `[ ]` in child names.

## Open questions (each with a suggested answer)

- Q1: The CI step "deploy-harness tests (.ps1, native pwsh)" still runs
  `bash tests/deploy-harness/test-deploy-harness.sh`, which now refuses Windows. Suggested
  answer: 38dc-13 changes it to
  `pwsh -NoProfile -File tests/deploy-harness/test-deploy-harness.ps1` (after the pywinpty
  install step, which already precedes it).
- Q2: Does the elevated CI runner honour the deny ACEs? Suggested answer: yes (reason above).
  Check the first Windows CI run for `109 passed, 0 failed, 0 skipped`. Two SKIP lines with
  "(a deny ACE does not block ...)" would mean no, with no failure.
- Q3: Keep the read-only cases on Windows, or keep them SKIP to match the old CI count?
  Suggested answer: keep them. They add Windows coverage of Remove-RetiredRule,
  Write-HarnessManifest and Remove-SkillBackupCopy failure paths, and they match the shared
  golden.

## New operational learning

- The Edit tool trims trailing whitespace at the end of `new_string`. A `replace_all` of
  `"MkDir "` with `"New-Dirs "` produced `New-Dirs@(...)` (a parse-time "term not
  recognized"). Rename with a pattern that does not end in a space, or with perl.
- PowerShell command precedence: an alias beats a function, so a helper named `Ls` is
  shadowed by the `ls` alias. `mkdir` is a built-in function, and `strip` resolved to
  `strip.exe` on this machine. Check helper names with Get-Command before using them.
- NTFS deny ACEs (Get-Acl and Set-Acl, InheritanceFlags None) are a working Windows
  counterpart of chmod 555 on a directory and chmod 000 on a file, for a user who is not an
  elevated admin. The ReadOnly file attribute is the counterpart of a read-only item that
  survives a copy (File.Copy keeps it, and Directory.Delete refuses it).
- `[IO.Directory]::GetFiles(dir, "*", AllDirectories)` lists a directory's own files before
  those of its subdirectories (seen: `SKILL.md, ro\a.md, ro\secret.md`).
- A harness stopped with TaskStop skips its `finally`: check for its temp root and remove it
  with a script that also clears deny ACEs and ReadOnly attributes.

## Sources

CI log: `W\.scratch\session-38dc-13\ci-windows-main.log` and `ci-linux-main.log`, sections
extracted with `ci-section.py` into `W\.scratch\session-e9d6-07\dh-ci.txt` and
`dh-ci-linux.txt`. Local runs: `deploy-harness-run.log` (99/0/2), `deploy-harness-run2.log`
(109/0/0), `deploy-harness-final.log` (final file). Mutations: `mutate-summary.log` and
`mutate-*.log`. Probes: `probe-acl.ps1`, `probe-order.ps1`. Comparisons: `compare-ci.py`,
`compare-linux.py`. All are in `W\.scratch\session-e9d6-07\`.
