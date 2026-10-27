# S3-FanoutImpl-Lib hand-back (FO-1)

Version 1.1, 2026-10-27, by S3-FanoutImpl-Lib (level 2, under S3-FanoutImpl).
v1.0 covered the first round, head 14f9fb1. v1.1 adds the fix round asked for by S3-FanoutImpl: the review and both audits, PR #119 finding 5, PR #121 runtime N1, PR #124 audit B N3, the Linux CI failure, and the missing CI run.

## Summary

1. PR https://github.com/nobul-tech/aitools/pull/118, branch feature/fanout-lib, head f69e2db9245794859014721cde97aad67122942e (base d7f6855).
2. Commits in this round:

| Commit | What |
|---|---|
| c459216 | merge FO-0 |
| 3abc53f | review and audit fixes, backup_dir |
| 7b7e1fb | dangling symlink destination |
| e83bfae | merge origin/main |
| 32a1354 | Linux prune fix |
| f69e2db | tracker fallback `n/a (nothing to deploy)` |

3. Mapping comment: https://github.com/nobul-tech/aitools/pull/118#issuecomment-6434051961
4. CI run 40450670671:
   - windows: pass.
   - The fan-out suite and "Every test suite is in CI" pass on linux and macos (bash 5 and /bin/bash 3.2).
   - linux and macos are red only at claude-mdm. That is the deploy-harness.ps1 Intune size gate, 221,665 B against a 200,000 limit; it already failed on the base at 202,519 B. CI is therefore not fully green, and FO-1 cannot make it green.
5. tests/fanout-lib: 364/0/0 with bash 5 + pwsh, and 130/0/1 with /bin/bash 3.2.

## Shipped signatures (final)

| bash | PowerShell | Result |
|---|---|---|
| `deploy_tracker_record removed TOOL ITEM` | `Record-DeployOutcome -Outcome "removed"` | DETAIL `removed: ITEM`; summary part `N removed` after `accepted`; outcomes matched case-sensitively in both |
| unknown outcome | `default` | log_error/LogError, counted failed, DETAIL `failed: ITEM` |
| tracker summary, every count 0 | same | text `n/a (nothing to deploy)` (was `verified`) |
| `RULES_MANIFEST_HEADER`, `SKILLS_MANIFEST_HEADER` | `$rulesManifestHeader`, `$skillsManifestHeader` | headers v1 |
| `lower_name`, `in_list` | n/a | FAN-PLAN A2 |
| `rule_name_kind NAME` / `skill_name_kind NAME` | `Get-RuleNameKind` / `Get-SkillNameKind` | hidden/backup/rule/other; hidden/backup/skill |
| `read_harness_manifest FILE KIND` | `Read-HarnessManifest -Path -Kind` | sh exit 0 read (may print `header-bad`), 1 missing / unreadable / directory, 2 unknown KIND; first word `rule` for both kinds. ps returns `@{Status; Rules; Invalid}`, throws |
| `read_rules_manifest FILE` | `Read-RulesManifest PATH` | wrappers |
| `fanout_text_equal A B` | `Test-FanoutTextEqual A B` | 0 / 1 / 2; detail line `<fn>: cannot read <file>: <reason>`; sh perl failure -> 2 + `perl failed (exit N)` |
| `fanout_dir_matches TARGET CAND` | `Test-FanoutDirMatches TARGET CAND` | 0 / 1 / 2 (below) |
| `backup_dir DIR` | `Backup-Dir -DirPath` | below |
| `deploy_managed_file` | `Deploy-ManagedFile` | dangling symlink DEST -> `failed`, `Failed: <item>: <dest> is a dangling symlink -- not written through it`, also in a dry run; a live symlink is written through, as before |

`fanout_dir_matches` / `Test-FanoutDirMatches`:
- 1 when TARGET or CAND is empty, and for any non-regular entry under TARGET: symlink or reparse point, FIFO, socket, block or character device.
- ps rejects those through `Get-FanoutEntryType`, which reads the type from UnixStat.Mode.
- 2 when an entry cannot be lstat'ed, listed or read; each reason is its own detail line.

`backup_dir` / `Backup-Dir`:
- Sets `BACKUP_DIR_OK`, `BACKUP_DIR_PATH` and `BACKUP_DIR_REASON` (ps: `$script:BackupDirOk`, `BackupDirPath`, `BackupDirReason`). The reason is one of `no directory`, `no top-level *.md`, `cannot list`, `copy failed`.
- Old backups are pruned by literal name: base + `.bak.` + UTC stamp, optional `-n`.
- The skip rule (no top-level `*.md` means no backup) is kept, logs at detail level, and is documented.
- ps copies with `Copy-DirectoryTree` (.NET) and prunes with `Directory.Delete`.

## Contract changes (listed in the PR body)

1. `read_harness_manifest` uses fixed exit codes 1 and 2. setup-user-cursor's copy exits with errno, and printed `header-bad` for a directory.
2. `Record-DeployOutcome` uses `switch -CaseSensitive`, which deviates from FAN-PLAN A3.
3. `backup_dir` gains its result variables and literal pruning, and warns when the directory cannot be listed.
4. The skills manifest keeps the first word `rule`.
5. The dangling symlink destination fails in both shells.
6. The tracker's all-zero fallback is `n/a (nothing to deploy)`.

## Verification (macOS, isolated HOMEs, head f69e2db)

- fanout-lib: 364/0/0; 130/0/1 with 3.2.
- managed-files: 57/0 (bash 5 and 3.2); ps1 39/0.
- adopt-push: 28/0 (both); ps1 23/0.
- profile: test-lib 361/0 (160/0 with 3.2), test-config 319/0, test-profile 763/0, test-user-init 229/0.
- rules-fanout-cursor 164/0/1 (both); deploy-harness 76/0 (both); hookin 39/0; b8-consumers 60/0; logging 24/0 (both), ps1 15/0/5.
- step 31 parity: PASS.
- claude-mdm 21/13 and deploy-harness-mdm 10/54: the same as on the base copy (size gate).
- check-pre-commit: only step 6 FAIL. check-pre-push: only step 7 FAIL.

## Findings / INCIDENT

- INCIDENT: two Copy-Item / Remove-Item bugs in PowerShell with `[ ] * ?` names.
  - `Copy-Item -LiteralPath -Recurse` creates an empty copy when a sibling matches the name as a wildcard. Seen on macOS pwsh 7.6.3.
  - `Join-Path` + `Remove-Item -LiteralPath -Recurse` removed the wrong sibling on Linux pwsh (CI run 40445716292).
  - Both are fixed in Backup-Dir with .NET calls. Any other harness code that copies or removes directory trees with those cmdlets can hit the same bugs; I did not audit the rest of the repo.
- INCIDENT (pre-existing): the deploy-harness.ps1 size gate keeps linux and macos red. FO-1 adds ~19 KB to the inlined lib.
- The Linux fix was not reproduced locally (no container runtime); it is verified by `bd-special` passing in CI runs 40448761743 and 40450670671.
- For FO-4: a skills DEST has no top-level `*.md`, so `backup_dir` skips it with reason `no top-level *.md`. Suggested: an optional pattern argument, default `*.md`.
- Ambiguity I resolved myself: the dangling-symlink request said "a dangling or any symlink destination gives failed", and also "check what ps does for a live symlink and match that". I measured that ps writes through a live link and kept that behaviour in both shells, so a dotfile-managed link stays usable. Suggested: confirm this, or decide that a live link should also fail.

## v1.2 addendum (2026-10-27): FO-0 merge, R1/R2, CI green

- Head d29dc5f5d140847bd15ef0a2aba05dbea722f5b3. Commits:

| Commit | What |
|---|---|
| f6d0b54 | merge FO-0 dbe8f46 (#120, size gate WARN) |
| ec6c4ac | R1: a half-made backup is removed, or renamed `.bak.incomplete.<UTC>`; R2a: the `*.md` count ignores case; R2b: symlinks: sh `cp -R` keeps links, ps copies content |
| d29dc5f | merge origin/main 4ca476f, no file change; no CI run had been created for ec6c4ac |

- CI run 40460911036: linux, macos and windows all success.
- Mapping comment: https://github.com/nobul-tech/aitools/pull/118#issuecomment-6435584802
- Suites (macOS):
  - fanout-lib 374/0/0, 134/0/1 with 3.2.
  - claude-mdm 34/0 and deploy-harness-mdm 65/0, both bashes.
  - Every other suite in v1.1 is unchanged and green.
- Accepted by S3-FanoutImpl: a live symlink destination is written through; only a dangling one fails. The FO-4 skills backup is handled in FO-4.
- Not tested: the `.bak.incomplete.` rename fallback.

## WRITE_BLOCKED

None.
