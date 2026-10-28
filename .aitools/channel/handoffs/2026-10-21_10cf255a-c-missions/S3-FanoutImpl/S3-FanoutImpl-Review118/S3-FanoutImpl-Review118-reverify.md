RE-VERIFY: APPROVE

S3-FanoutImpl-Review118 re-checked #118 at head `f69e2db`, against the fix mapping in issuecomment-6434051961. I read the first-parent fix commits 3abc53f, 7b7e1fb, 32a1354 and f69e2db (plus the c459216 and e83bfae merges), then ran the suites and probes again in a detached worktree. Every run used an isolated HOME.

Every finding from my first verdict is fixed. Nothing blocks the merge. I have two new non-blocking notes, R1 and R2 at the end.

## My findings, re-checked

| Finding | Result at f69e2db |
|---|---|
| N1: a 644 subdirectory gave 1 in sh, 2 in ps | Fixed. `lstat` failure now returns 2 in bash 5, /bin/bash 3.2 and pwsh |
| N2: an empty Candidate threw in ps | Fixed. An empty Target or Candidate returns 1 in all three shells |
| N3: the comments differed | Fixed. Both comments list symlink, FIFO, socket, device and the read/list/lstat failures |
| N4: FO-0 was not merged first | Fixed. c459216 merges FO-0 with `--no-ff` |
| N5: tracker matched outcomes case-insensitively in ps only | Fixed. `switch -CaseSensitive` with separate `added` and `created` clauses |
| N6, N7, N8 | Kept as notes, as agreed |

## Probes the orchestrator asked for (bash 5 / bash 3.2 / pwsh, results identical in all three)

**backup_dir / Backup-Dir with special names and decoys.** The directory is `r[1]*? x`, with seven old stamped backups. Decoys:
- `r1Ax.bak.<stamp>` and `rAx.bak.<stamp>` (wildcard look-alikes)
- `r[1]*? x-other.bak.<stamp>` (another directory's backups)
- `r[1]*? x.bak.notastamp`
- `r[1]*? x.bak.<stamp>.extra`
- a symlink named `r[1]*? x.bak.2000-01-01T000000Z` that points at a live directory

Results:
- Exactly five stamped backups were kept: the newest four old ones plus the new copy.
- Every decoy is intact, and so is the symlink and its target.
- The ps copy contains `a.md`, so the old `Copy-Item` empty-copy bug is gone.

**Result flags (`BACKUP_DIR_OK` / `BACKUP_DIR_REASON` / `BACKUP_DIR_PATH`, and the `$script:` twins in ps):**

| Case | OK | Reason | Path |
|---|---|---|---|
| Success | true | (empty) | the new copy, which exists |
| Missing directory | false | `no directory` | |
| No top-level `*.md` | false | `no top-level *.md` | |
| Directory mode 000 | false | `cannot list` | |
| Unreadable file inside the directory | false | `copy failed` | |

**Symlink destinations for `deploy_managed_file` / `Deploy-ManagedFile` (non-interactive run):**

| Destination | Result |
|---|---|
| Dangling symlink | `failed`; the link target was not created; the error is logged once |
| Self-loop symlink | `failed` |
| Live symlink | `updated`, written through the link, link kept |

**Tracker case handling.** `Removed`, `CREATED` and `Added` are counted as failed with `log_error` in both shells; `created` is counted as added.

**Tracker zero fallback.** With nothing recorded, or with only `preserved` recorded, the text is `n/a (nothing to deploy)` in both shells. I grepped `scripts/` and `tests/` for a caller or test that expects the old fallback `verified`: none does. Every `|verified` row there is a script's own row, and setup-user-claude and setup-user-cursor only interpolate the text into their log lines.

**`fanout_dir_matches`:** lstat failure returns 2, empty TARGET returns 1, empty CAND returns 1.

**Log format.** No line in the probe deploy.log files breaks the `[ts] [script] [level]` format.

## Suites (macOS arm64)

| Suite | Result |
|---|---|
| tests/fanout-lib (bash 5 + pwsh) | 364/0/0 |
| tests/fanout-lib (/bin/bash 3.2 `--bash-only`) | 130/0/1 |
| managed-files, bash 5 | 57/0 |
| managed-files, bash 3.2 | 57/0 |
| managed-files, .ps1 | 39/0 |
| adopt-push, sh / .ps1 | 28/0, 23/0 |
| profile/test-lib.sh | 361/0 |
| profile/test-lib.sh, bash 3.2 | 160/0 |
| rules-fanout-cursor | 164/0/1 |
| deploy-harness | 76/0 |

- Step-31 tracker parity: both extractions give `added,created,failed,preserved,removed,skipped,updated,verified`.
- `bash -n` and the ps1 parser pass; the ps1 still has CRLF line endings; the test file is 100755.

## CI, run 40450670671 at f69e2db

Linux:
- Passes "Fan-out lib helper tests (bash + pwsh parity)". This suite includes `bd-special`, the case that failed on Linux in run 40445716292.
- Also passes "Every test suite is in CI", managed-files, adopt, profile, deploy-harness, hook-in and cursor.
- The only failure is "setup-user-claude dev + MDM tests". The failure log shows build-deploy's size gate six times on Linux: `deploy/deploy-harness.ps1 is 221665 bytes, over the Intune script limit (200000)`. The same failures occur on the base. This is FO-0b/SizeGate, not FO-1.

macOS: identical pattern, including the bash 3.2 fan-out step. Windows: green.

The PR now adds about 19 KB to the inlined lib (202,519 B on the base, 221,665 B now). The size-gate fix has to budget for that.

## New notes (non-blocking)

**R1: a failed directory backup leaves a half copy under a backup name.** `aitools-lib.sh` `backup_dir` (`cp -R` failing) and `aitools-lib.ps1` `Backup-Dir` (`Copy-DirectoryTree` throwing) both report `copy failed` with OK=false, which is correct. But the partial `DIR.bak.<stamp>` directory stays on disk. Its name matches the prune pattern, so the next run counts it as one of the five kept backups, and it can push a good backup out.
- Probe: a rules directory containing a mode-000 `b.md` leaves `rules.bak.<stamp>` in both shells.
- Suggested fix: on failure, remove `$dest` (it is our own new directory) and log the removal. This can be a follow-up.

**R2: Windows behaviour changes in `Backup-Dir`, not tested in CI.** Two differences from the old code:
- `Copy-DirectoryTree` now copies symlinks as symlinks. On Windows that requires Developer Mode or the symlink privilege. Without it, a rules directory that contains a link gives `copy failed`, where the old `Copy-Item` copied the file content.
- The `*.md` count is now case-sensitive. On Windows a directory with only `X.MD` is no longer backed up, where the old `-Filter` matched it.

Both are rare in `~/.claude/rules`. Neither is covered by the windows CI job, because the fan-out suite does not run there. A follow-up should state the intended behaviour.

Not run: Windows native, check-pre-commit and check-pre-push (the author reports only the known step 6 and step 7 FAILs), check-post-push.
