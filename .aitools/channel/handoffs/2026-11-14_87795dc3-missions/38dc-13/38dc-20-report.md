# 38dc-20 report: what the Windows "permission denied" test cases are, and whether to keep them (v1.0)

Mission 38dc-20-acl-deny-investigate, delegated by M6-Polish (session 87795dc3).
Question: RFI 38dc-4 (relaying RFI 38dc-13-2). Investigated on
`origin/fix/38dc-13-windows-ci-ps1-only` at bbb22c6 (read-only worktree
`.claude/worktrees/38dc-20`). No code changed, nothing committed.

## 1. The answer, in plain words

The OS guards and these test cases are two different kinds of "blocking". An OS
guard makes a script refuse to run on the wrong operating system: a `.sh` refuses
Windows, a `.ps1` refuses macOS and Linux. These test cases run the right script on
the right system (a `.ps1` on Windows) and check what it does when the disk refuses
it: a folder it cannot write into, or a file it cannot read. The product has code
for that (it must report an ERROR row, keep the user's file, and try again next
run); these cases make the refusal happen on purpose, in a throwaway temp folder,
so that code actually runs once. On macOS and Linux the tests cause the refusal
with `chmod` (file permissions); on Windows `chmod` does nothing, so the Windows
tests use the Windows equivalent, a "deny" entry in the file's access list (ACL).
That is the only reason "permissions" came up: the RFI asked whether that Windows
technique is safe on GitHub's Windows machine, which runs as administrator. It is:
the same technique already passes on that machine in a test merged on main, so I
recommend keeping all 22 cases.

## 2. Case by case

Suites on the 38dc-13 branch. "Product code" is the Windows code the case runs;
the `.sh` suites cover the separate `.sh` code on macOS/Linux, so before this port
none of this `.ps1` code was ever executed by a test (the old Git Bash harness ran
the `.ps1` scripts but SKIPped these cases because chmod does not block on NTFS:
38dc-13-report.md, rows 1e454ca and c4c588e).

| # | Suite | PASS line (case) | Product behaviour tested (`.ps1` code) | How it can happen on Windows in real use | Technique | Verdict |
|---|---|---|---|---|---|---|
| 1 | deploy-harness | `ps1: failed backup keeps the file (ERROR row, exit 1)` | Retiring a rule: the backup copy fails, so the rule is NOT deleted; ERROR `retire failed: <name>`, `backup failed` logged, exit 1 (`scripts/deploy-harness.ps1` Remove-RetiredRule) | `~/.aitools/rules` not writable (an ACL set by IT/MDM), disk full, path too long | Deny CreateFiles+CreateDirectories on `~/.aitools/rules` (= `chmod 555`) | Keep |
| 2 | deploy-harness | `ps1: next run retries and removes it` | After the cause is gone, the next run backs up and removes the rule | same | same, removed | Keep |
| 3 | deploy-harness | `manifest write failure: ERROR row, exit 1, run completes` | Manifest temp file cannot be written: ERROR `rules manifest not written`, run still completes (Write-HarnessManifest) | Folder not writable; also, Windows-only: replacing a file another process holds open without delete-sharing fails (probe 8 below), which POSIX rename never does | Deny write on `~/.aitools/rules` | Keep |
| 4 | deploy-harness | `ps1 skills: partial backup removed again; directory kept (ERROR row, exit 1)` | Retiring a skill: copy fails half-way, the half-made backup is removed, the skill is kept (Remove-RetiredSkill, Remove-SkillBackupCopy) | A file in the skill folder held open with no sharing (probe 7) or not readable (ACL) | Deny ReadData on one file (= `chmod 000`) | Keep |
| 5 | deploy-harness | `ps1 skills: readable again -- backed up and removed` | Retry succeeds | same | removed | Keep |
| 6 | deploy-harness | `ps1 skills: partial backup with a read-only subdirectory removed (no leftover, nothing renamed)` | Windows-only code: the half-made backup holds a ReadOnly file, so the cleanup must clear the attribute before deleting (deploy-harness.ps1 lines 554-562) | ReadOnly file attribute (set by a user, a sync tool, or a copy from a read-only source) | Deny ReadData + ReadOnly attribute | Keep |
| 7 | deploy-harness | `ps1 skills: read-only case retried -- backed up and removed` | Retry succeeds | same | removed | Keep |
| 8 | deploy-harness | `ps1 skills: failed backup keeps the directory (ERROR row, exit 1)` | Backup folder cannot be created: skill kept, ERROR, no backup | `~/.aitools/skills` not writable | Deny write on `~/.aitools/skills` | Keep |
| 9 | deploy-harness | `ps1 skills: next run retries -- backed up and removed` | Retry succeeds | same | removed | Keep |
| 10 | deploy-harness | `skills read-only parity: trace equals the golden file` | Windows outcome (exit codes, rows, manifest, tree) equals the Linux/macOS outcome | n/a | golden file | Keep |
| 11 | rules-fanout | `unreadable harness dir: ERROR row, exit 1` | `setup-user-claude.ps1` cannot list `~/.aitools/rules`: ERROR `cannot read harness rules`, exit 1 (lines 387-396) | ACL on the folder | Deny ListDirectory (= `chmod 000` on a dir) | Keep |
| 12 | rules-fanout | parity `unreadable` | Same rows and tree as Linux | n/a | golden | Keep |
| 13 | rules-fanout | `unreadable manifest: rules fanned out, ERROR rows, final row ERROR, exit 1` | Manifest unreadable: rules still fanned out, ERROR `cannot read rules manifest`, final row ERROR (lines 415-421) | Manifest held open with no sharing; ACL | Deny ReadData | Keep |
| 14 | rules-fanout | parity `manifest-unreadable` | Same as Linux | n/a | golden | Keep |
| 15 | skills-legacy | `ps1 unreadable manifest: exit 1, ERROR skills row, reverse discovery not run` | `setup-user-skills.ps1`: no harness skill is wrongly offered for adoption; ERROR `no adopt: manifest unreadable` (lines 250-259) | as 13 | Deny ReadData | Keep |
| 16 | skills-legacy | golden rows `ps1-mfu` | Same rows as Linux | n/a | golden | Keep |
| 17 | skills-legacy | `ps1 unreadable ~/.aitools/skills: exit 1, ERROR skills row, reverse discovery not run` | ERROR `no adopt: harness unreadable` (lines 232-237) | as 11 | Deny ListDirectory | Keep |
| 18 | skills-legacy | golden rows `ps1-hdu` | Same as Linux | n/a | golden | Keep |
| 19 | skills-legacy | `ps1 unreadable ~/.claude/skills: exit 1, ERROR skills 'no adopt: target unreadable', logged` | An unreadable target is an error, not "nothing found" (lines 294-299) | as 11 | Deny ListDirectory | Keep |
| 20 | skills-legacy | golden rows `ps1-dstu` | Same as Linux | n/a | golden | Keep |
| 21 | skills-legacy | `ps1 pty adopt failure (fanned out): exit 1, ERROR skills 'adopt failed: mine', no claude skills row` | Adopting into the dotprofile fails: ERROR `adopt failed: mine`, nothing half-written (line 347) | Dotprofile folder not writable (ACL, a managed or synced folder) | Deny CreateFiles, CreateDirectories, DeleteSubdirectoriesAndFiles (= `chmod 555`) | Keep |
| 22 | skills-legacy | golden rows `ps1-adoptfail` | Same as Linux | n/a | golden | Keep |

Count check: deploy-harness 10 + rules-fanout 4 + skills-legacy 8 = 22, matching
the PASS deltas in 38dc-13-report.md (109/0/0 vs CI 99/0/2; 65/0/2 vs 61/0/3;
40/0/0 vs 32/0/2).

## 3. Is the technique sound and safe?

- **Elevated CI runner (the RFI's worry): resolved.** GitHub docs, read in the
  browser this session: "Windows virtual machines are configured to run as
  administrators with User Account Control (UAC) disabled."
  (docs.github.com/en/actions/reference/runners/github-hosted-runners). On that
  machine (user `runneradmin`), a deny ACE already blocks: the merged main test
  `tests/pywinpty/test-setup-pywinpty.ps1` denies ListDirectory with
  `icacls /deny (RD)` and passed: `PASS f fake externally managed, target not
  listable: ...` (run 43632595172, fix/m6-logging at 4d881f7, windows job, log
  line 1369; that branch merged to main as PR #157, 875e957). A deny entry for the
  user's own SID applies to an administrator too; administrators bypass it only
  with backup privileges, which these file APIs do not use (Windows access-check
  model, from knowledge, not re-read this session; the CI PASS above is the
  evidence that matters).
- **Cleanup**: every ACE is on a path under the suite's temp root
  (`New-TestTempRoot`: `RUNNER_TEMP` or the system temp dir), never the real HOME.
  deploy-harness and rules-fanout undo each ACE after the step and again in the
  suite's outer `finally`; skills-legacy undoes each in a per-case `finally` and
  again in the outer `finally`. Each ACE is non-inheriting (InheritanceFlags None).
- **Leftovers**: only if the process is killed outright (CI cancel, hard kill). Then
  a temp folder with a deny entry can remain; on CI the VM is discarded; locally
  the owner can still reset it (`icacls <dir> /reset /T`). Low risk.
- **False passes**: unlikely. Each check matches the exact ERROR row and the
  specific log text of that failure (e.g. `backup failed`, `Cannot read the skills
  manifest ...`), and 7 of the 22 lines (rows 10, 12, 14, 16, 18, 20, 22) compare
  the result with the Linux golden files.
- **False failures / the "falls back to SKIP" claim**: true for deploy-harness (its
  probe tests a write deny and a read deny). In rules-fanout and skills-legacy the
  probe tests only a ReadData deny on a file; the ListDirectory and CreateFiles
  denies are not probed, so if one ever did not block, those cases would FAIL
  (loudly), not SKIP. Not a safety problem; see RFI 38dc-20-1.

## 4. Recommendation for 38dc-13: keep all 22 cases

1. **It follows the commander's rule.** "sh scripts and tests should only run on
   linux/mac and ps1 on windows": these are `.ps1` harnesses, run by native pwsh on
   Windows, testing the `.ps1` product scripts with a Windows mechanism. The
   alternative that existed before (chmod from Git Bash) is a bash tool on Windows
   and does not work.
2. **Zero defects needs it.** Without these cases, the Windows error handling for
   retiring rules and skills, writing manifests, unreadable harness folders and a
   failed adopt is never executed by any test, on any platform. Windows has more
   ways to hit these paths than Linux (probes 7 and 8: a file held open by another
   process blocks reading, copying and replacing it).
3. **No alternative covers them.** Local probe (section 5): a ReadOnly attribute on a
   folder does not stop creating files in it (so it cannot replace `chmod 555`); a
   ReadOnly file can still be read (cannot replace `chmod 000`); a locked file
   (FileShare.None) blocks reading, copying and replacing a file but cannot make a
   folder unlistable or uncreatable. Only the deny ACE reproduces all 22.
4. **Optional tightening (not blocking)**: probe ListDirectory and CreateFiles in
   rules-fanout and skills-legacy too, and update the stale SKIP texts ("chmod does
   not block reads here") to name the deny ACE (RFI 38dc-20-1). A locked-file case
   (realistic Windows cause) is a follow-up, not 38dc-13 scope (RFI 38dc-20-2).

## 5. Evidence and probes

- Read: `tests/deploy-harness/test-deploy-harness.ps1` (header, helpers 74-107,
  probe 289-306, cases 573-587 and 724-774, cleanup 854-874);
  `tests/rules-fanout/test-rules-fanout.ps1` (1-139, 553-591);
  `tests/skills-legacy/test-skills-legacy.ps1` (1-35, 385-457); the `.sh` twins'
  chmod lines (`git grep`); product code `scripts/deploy-harness.ps1` 456-759,
  `scripts/setup-user-claude.ps1` 380-424, `scripts/setup-user-skills.ps1` 225-304;
  `38dc-13-report.md` (RFI 38dc-13-2); `.claude/rules/cross-platform.md` (OS guard
  patterns); `tests/os-guards` uses no ACL or chmod (`git grep`, no hit).
- CI: `gh run view 43632595172 --job 132562282819 --log` (target-not-listable PASS,
  user `runneradmin`, Windows Server 2022); main run 43632383993 predates the
  icacls case (bb1edce is not an ancestor of 00beb8e).
- Browser (chrome-devtools): GitHub-hosted runners reference, "Administrative
  privileges" section, quoted above.
- Local probe `pwsh -NoProfile -File .scratch/session-38dc-20/probe-acl.ps1`
  (user NEWCOPC\pepe, not elevated; scratch folder; ACEs removed in `finally`;
  cleanup removed=True):

```
--- 2. deny ACE ReadData on a file
read : BLOCKED (MethodInvocationException)
File.Copy : BLOCKED (MethodInvocationException)
read after undeny : allowed
--- 3. deny ACE ListDirectory on a directory
Get-ChildItem -LiteralPath -ErrorAction Stop : BLOCKED (UnauthorizedAccessException)
Directory.GetFiles : BLOCKED (MethodInvocationException)
--- 4. deny ACE CreateFiles+CreateDirectories on a directory
new file : BLOCKED (MethodInvocationException)
new subdir : BLOCKED (MethodInvocationException)
overwrite existing file : allowed
--- 5. ReadOnly attribute on a directory (alternative 1)
new file in RO dir : allowed
--- 6. ReadOnly attribute on a file (alternative 2)
read RO file : allowed
write RO file : BLOCKED (MethodInvocationException)
File.Move over RO file : BLOCKED (MethodInvocationException)
--- 7. FileShare.None handle held (alternative 3: a locked file)
read locked : BLOCKED (MethodInvocationException)
File.Copy locked : BLOCKED (MethodInvocationException)
File.Move over locked : BLOCKED (MethodInvocationException)
--- 8. FileShare.Read handle held (an ordinary reader, e.g. an editor or scanner)
read while shared-read open : allowed
File.Move over a file open without FILE_SHARE_DELETE : BLOCKED (MethodInvocationException)
```

- Not run: the three ported suites themselves (38dc-13 ran them locally; not yet
  on CI, the branch's check.yml still runs the `.sh`); an elevated local run (CI
  evidence stands in for it).

## 6. Lines

- WRITE_BLOCKED: none.
- CONFLICT: /investigate's RCA, remediation and corrective-action phases vs this
  prompt (analysis only, no code changes) -- resolved by tier 2 (prompt): used
  detection, triage and evidence gathering; no RCA (nothing went wrong), no fixes.
- CONFLICT: CLAUDE.md "Leave something behind" (relay entry) vs this prompt (no
  commits) -- resolved by tier 2 for this delegate: no relay commit; the OL below
  is for the orchestrator's relay entry.
- OL: on Windows, "permission" failures in tests are simulated with a deny ACE for
  the current SID (blocks even an elevated admin, verified on GitHub's runner);
  a ReadOnly attribute on a folder blocks nothing; replacing a file that another
  process holds open without delete-sharing fails on Windows (never on POSIX).

## 7. Open questions

RFI 38dc-20-1: Probe every deny right the rules-fanout and skills-legacy ports use?
Their probe checks only a ReadData deny on a file, so the RFI's "a probe falls back
to SKIP" holds for deploy-harness only; a ListDirectory or CreateFiles deny that did
not block would FAIL those cases. The SKIP texts still say "chmod does not block".
Suggest: 38dc-13 extends `Test-DenyBlocksRead` to the three rights and rewords the
SKIP texts (why: makes the claim true everywhere; a few lines, no behaviour change
on the runner, where all three block).

RFI 38dc-20-2: Add a locked-file case (FileShare.None) as a follow-up?
It is the most common real Windows cause of these failures (probes 7 and 8) and
the deny ACE does not model it; e.g. the rules manifest replace under a concurrent
reader.
Suggest: a follow-up mission after 38dc-13 merges, not in 38dc-13 (why: new
coverage, not a port; keeps 38dc-13's scope to parity).
