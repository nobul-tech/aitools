AUDIT (logging, B): FINDINGS

**S3-FanoutImpl-AuditB124: runtime logging and script-standards audit of PR #124 (FO-4), v1.0, 2026-10-27**

**Verdict: 0 blocking, 7 non-blocking.** The rows, exit codes, trees and log levels match between sh and ps in all 38 cases, plus 3 MDM runs. Every `log_error` has an ERROR row, every warning has a WARN or ACTION row, and every path writes a summary row. The non-blocking findings are about message detail and edge-case reporting.

## Scope and environment

- **Code:** head `fcf6edc`. In scope are `fanout_harness_skills` (`scripts/aitools-lib.sh`), `Invoke-HarnessSkillsFanout` (`scripts/aitools-lib.ps1`), the `skills fan-out` span in `setup-user-claude.sh/.ps1` and the `build-deploy.sh` extraction. The in-scope diff is `git diff f897b74 fcf6edc -- <those 5 files>`. Tests were checked for silent failures only.
- **Environment:** macOS 27.0.1 (26A434), GNU bash 5.3.15, /bin/bash 3.2 (sh side, second pass) and PowerShell 7.6.3.
- **Isolation:** every run used its own HOME and USERPROFILE under `<worktree>/.scratch/session-a124b/`. The .ps1 OS guard was patched only in a scratch copy.
- **MDM build:** `build-deploy.sh` ran under an isolated HOME into a `git clone` of the dotprofile inside scratch, with its remote removed.
- **Method:** this is an independent runner, analyzer and pty-abort script, adapted from the #121 audit scripts (copies are in this directory). For each case and language it captured the exit code, summary rows, `deploy.log` and stderr. It then compared the `claude skills` and ACTION rows, the exit code, the error and warn counts against the footer, and the normalized error/warn messages between sh and ps.
- **Not read:** the static audit's output (AuditA124).

## Case table

"rows" means the final `claude skills` row, plus ACTION rows (A). Parity covers the exit code, the `claude skills` and ACTION rows, and the error/warn counts. The message text differs only where a finding says so.

| Case | sh exit / rows | ps exit / rows | Parity |
|---|---|---|---|
| clean (nested, `*.bak.*`, hidden, top-level file, third-party dir, firecrawl symlink, x bit) | 0 / OK 5 added | 0 / same | same (rows, tree, modes) |
| verified (rerun of clean) | 0 / OK 5 verified | 0 / same | same |
| missing (~/.aitools/skills absent) | 0 / OK n/a (no harness skills) | 0 / same | same |
| empty | 0 / OK n/a (no harness skills) | 0 / same | same |
| unreaddir (chmod 000) | 1 / ERROR cannot read harness skills | 1 / same | same |
| unreadx (chmod 444) | 1 / ERROR cannot read harness skills | 1 / same | same (ps reason names the manifest path) |
| mfunread (manifest 000) | 1 / ERROR cannot read skills manifest + ERROR 1 failed | 1 / same | same |
| mfunreadonly (unreadable manifest, no skills) | 1 / ERROR cannot read skills manifest | 1 / same | same |
| mfdangling (manifest is a dangling symlink) | 1 / ERROR cannot read skills manifest + ERROR 1 failed | 1 / same | same |
| mfdir (manifest is a directory) | 1 / same as mfdangling | 1 / same | same |
| mfempty (empty manifest = header-bad) | 0 / WARN 1 added + A rebuild | 0 / same | same |
| badheader | 0 / WARN 1 added + A rebuild | 0 / same | same |
| invalid manifest lines (3) | 0 / WARN 2 added | 0 / same | same |
| srclink (dangling symlink in source) | 1 / ERROR 1 failed (`failed: broken`) | 1 / same | same |
| srcinner (dangling file link inside a skill) | 0 / OK 3 added ("Ignoring non-file") | 0 / same | same |
| destlink (dangling symlink at a skill name and at an unmanaged name in DEST) | 0 / WARN 2 added + A not updated: s1 | 0 / same | same |
| destkept (symlink to a dir + plain file at skill names) | 0 / WARN 1 added + A not updated: p1, s1 | 0 / same | same (tree) |
| nocreate (file at ~/.claude/skills) | 1 / ERROR cannot create skills dir | 1 / same | same |
| nocreatedry | 0 / OK dry run (no files written) | 0 / same | same (see N6) |
| noclaude (no ~/.claude at all) | 0 / OK 3 added | 0 / same | same |
| retired (removed from backup, removed from harness copy, user dir kept) | 0 / WARN 1 added, 2 removed + A still loads: mine2 | 0 / same | same (tree) |
| retireddry | 0 / WARN dry run + A still loads: mine2 | 0 / same | same |
| retonly (retired, user-modified, nothing else) | 0 / WARN verified + A still loads: gone | 0 / same | same (see N3) |
| retonlyrm (retired only, matches) | 0 / OK 1 removed | 0 / same | same |
| bakfail (~/.claude 555: DEST.bak.<UTC> cannot be created) | 1 / ERROR 1 failed (`failed: gone`) | 1 / same | same |
| rmfail (read-only subdir in the retired copy) | 1 / ERROR 1 failed | 1 / same | rows same; backup subdir mode 0555 sh / 0755 ps (N7) |
| srcunread (a harness file 000) | 1 / ERROR 1 failed | 1 / same | same |
| subunread (a harness subdir 000) | 1 / ERROR 1 failed (`failed: p1`) | 1 / same | same |
| destro (DEST skill dir 555, file differs) | 1 / ERROR 1 failed | 1 / same | same |
| destunlist (DEST 300: writable, not listable) | 0 / WARN 1 added | 0 / same | same (see N2) |
| dry (`--dry-run` / `-DryRun`) | 0 / OK dry run (no files written) | 0 / same | same |
| envdry (`AITOOLS_DRY_RUN=1`) | 0 / OK dry run (no files written) | 0 / same | same |
| edited (non-interactive overwrite) | 0 / WARN 1 updated, 2 verified | 0 / same | same |
| force | 0 / WARN 1 updated, 2 verified | 0 / same | same |
| xbit (DEST file 755, source 644) | 0 / OK 2 added, 1 verified | 0 / same | same: mode 0644 after run, a-x works |
| bracket (`[x]`, `a*b?.md`) | 0 / OK 2 added | 0 / same | same |
| dupcase (`a` + `A`, on a case-sensitive APFS image in scratch) | 1 / ERROR 1 failed (`failed: a`) | 1 / same | same |
| abort (`[x]` on a pty at a skill review) | 2 / no claude skills row, "Aborted by user", local file kept | 2 / same | same |
| MDM: generated `deploy/setup-user-claude.sh/.ps1`, clean / retired / rerun | 0 / OK 3 added; OK 3 added, 1 removed; OK 3 verified | 1 / same skills rows | skills rows same; ps exit 1 comes from machine-profile resolution on macOS pwsh (`machine.id unavailable, hostname unavailable`), not from skills |

- **Bash 3.2 pass:** 35 sh-side cases rerun under /bin/bash 3.2 (every runner case except dupcase and destunlist, which were added after this pass; abort not rerun). Rows and exit codes match the ps runs. The analyzer raised no counter or format flag.
- **Format and counters, all cases, both languages:**
  - Every `setup-user-claude` log line matches `[YYYY-MM-DDTHH:MM:SSZ] [setup-user-claude] [level] message`.
  - Every skills `[detail]` line is single-line and prefixed `claude skills:`, except the library's own `backup_dir:` / `Backup-Dir:` line.
  - The footer count equals the number of logged errors, and exit 1 occurs exactly when errors were logged.
  - Every skills `log_error` has an `ERROR|claude skills|...` row, and every warning has a WARN or ACTION row.
  - No row detail is over 30 characters, and no unstructured console output appears.
- **Tracker `removed`:** rendered the same in both languages (`DETAIL|claude skills|removed: gone`, `N removed`).
- **Suite:**
  - `tests/skills-fanout/test-skills-fanout.sh`: 137 passed, 0 failed, 1 skipped (case-only duplicate on APFS).
  - The same suite with `AITOOLS_TEST_BASH=/bin/bash --bash-only`: 54 passed, 0 failed, 25 skipped. Both match the PR body.
- **MDM build:** `build-deploy.sh` exit 0. Both generated scripts contain the call (1 each) and the lib function. `bash -n` passes on the generated .sh.

## Findings

All are **non-blocking**. Line numbers are at `fcf6edc`.

**N1. sh drops the OS reason from the log; ps logs it (parity of message detail).** On five failure paths the sh `log_error` / `log_warn` has no reason. The command's own message goes to the terminal's stderr instead of `deploy.log`. ps logs the .NET exception text.
- **Evidence:**

  | Case | sh stderr | Lines |
  |---|---|---|
  | nocreate | `mkdir: .../.claude/skills: File exists` | `aitools-lib.sh:2989-2991` |
  | bakfail | `mkdir: ...skills.bak.<UTC>: Permission denied` | `:3200-3201` |
  | srcunread | `cat: .../p1/SKILL.md: Permission denied` | `:3102-3103` |
  | rmfail | three `rm:` lines | `:3214-3215` |

  `cp -R` at `:3205` has the same pattern (not triggered).
- **Example:** sh logs `[error] Cannot create ~/.claude/skills`; ps logs `[error] Cannot create ... (Exception calling "CreateDirectory" ... "The file '...' already exists.")`.
- **Suggested fix:** capture `2>&1` into a variable and append it to the message, as the same function already does for `_fanout_list_dir` at `:2907`, `:3147` and `:3237`.
- The `destro` stderr (`cp: ...SKILL.md.bak...: Permission denied`) comes from the library's `backup_file`, which predates this PR.

**N2. DEST that cannot be listed silently skips the retired prune.** In case destunlist (`~/.claude/skills` mode 300), the retired copy `gone` matches its harness backup but is not removed. There is no ACTION row, and the only row is `WARN|claude skills|1 added`.
- The log has `warn Cannot list ~/.claude/skills for the retired skills -- ...` and `... for the preserved report -- ...`. It reports `0 preserved` although `mine` and `gone` are there.
- **Code:** `aitools-lib.sh:3146-3150` and `:3237-3240`; `aitools-lib.ps1:3177-3184` and `:3283-3288`.
- Contract 3.4 does not cover this case. A row such as ACTION `Claude Code skills in ~/.claude/skills not checked for retired skills (cannot list) -- ...` or an ERROR row would tell the user that a retired skill may still load.

**N3. Row text "verified" when nothing was verified.** In case retonly, the run deploys nothing and keeps one retired user directory. The row is `WARN|claude skills|verified` and the log says `Skills (claude skills): verified, 1 preserved in ~/.claude/skills`.
- **Cause:** the text comes from the empty-counts fallback in `deploy_tracker_summary` (`aitools-lib.sh:2593`, FO-1, not in this diff). This function reaches it through `:3265`.
- **Suggested fix:** when every count is 0, write `n/a (nothing to deploy)` or `0 deployed` from the fan-out, or fix the fallback in the lib for every caller.

**N4. A retired directory that is kept, or whose removal failed, is counted twice.** It is a `failed` (or WARN-kept) item and then also `preserved` by the preserved scan. For example, bakfail and rmfail log `Skills (claude skills): 1 verified, 1 failed, 1 preserved` for the one directory `gone`, plus `Preserved unmanaged skill: gone`.
- **Code:** `aitools-lib.sh:3241-3249`; `aitools-lib.ps1:3289-3298`. The scan excludes only names deployed this run.
- This is cosmetic: the counts in the log line and in the DETAIL rows overstate the directories.

**N5. A failed retired removal leaves a partial copy and does not name the backup.** In case rmfail, `rm -rf` (sh) and `Directory.Delete` (ps) removed `gone/SKILL.md` before failing on `gone/sub`. The verified backup exists in `skills.bak.<UTC>/gone/`, but the error names only the copy: `Cannot remove ~/.claude/skills/gone (retired skill)`. The ps message adds the exception text.
- **Code:** `aitools-lib.sh:3214-3216`; `aitools-lib.ps1:3253-3263`.
- **Suggested fix:** add `(partly removed; backup in <bak root>)` so the user can restore it.

**N6. A dry run does not predict "cannot create skills dir".** With a file at `~/.claude/skills`, the dry run shows `OK|claude skills|dry run (no files written)` and `[DRY RUN] Would create: d1/SKILL.md -> ~/.claude/skills/d1/SKILL.md`. The real run is `ERROR|claude skills|cannot create skills dir`, exit 1.
- **Code:** `aitools-lib.sh:2987-2994` and `aitools-lib.ps1:2999-3016` skip the check under dry run.
- **Suggested fix:** test "exists and is not a directory" in dry run too, and report `ERROR ... 1 failed (dry run)` or the same text.

**N7. Mode parity of the retired-skill backup.** sh `cp -R` keeps a 0555 subdirectory at 0555 in `skills.bak.<UTC>/gone/sub`. ps `Copy-DirectoryTree` writes 0755 (rmfail tree diff). This is not a logging issue; it is recorded for parity.
- **Code:** `aitools-lib.sh:3205`; `aitools-lib.ps1:3241`.

### Outside this PR's diff (recorded, not findings)

- **Multi-line `[detail]` line on the ps runs:** `footer OS: Get-CimInstance Win32_OperatingSystem failed (...` followed by a second line `Check the spelling ...`. It comes from the CLAUDE.md footer code. That code is unchanged by FO-4, and the line appears only because the Windows .ps1 runs on macOS.
- **`write_summary` OK-to-WARN promotion is global:** it promotes OK to WARN when any warning was logged earlier in the script (`aitools-lib.sh:956-959`). So the `claude skills` row can be WARN because of a CLAUDE.md or rules warning. This is library behaviour that predates FO-4.

## Tests: silent failures

None found in `tests/skills-fanout/test-skills-fanout.sh`:
- `cleanup`'s `2>/dev/null` is followed by a printed warning on failure.
- `logged` / `logged_re` (`cat ... 2>/dev/null | grep -q`) are used only in positive checks, so missing logs make the check FAIL.
- Every `command -v` has an explicit fallback.
- Negative greps read files that the run always creates.

## Not run

- **Windows:** no native pwsh or Git Bash run. The ps path ran on macOS pwsh with the guard patched off in a copy.
- **No fault injection:** these paths could not be triggered without injecting faults into the library:
  - unexpected `deploy_managed_file` result (`aitools-lib.sh:3110-3114`)
  - post-write empty-file validation (`:3253-3258`, `:3268`)
  - chmod / `SetUnixFileMode` failure (`:3120-3128`; ps `:3158-3161`)
  - the caller-bug guard (`:2885-2889`)

  They were read statically: each one logs an error and writes an ERROR row or a `failed` item.
- **Adopt on a pty:** covered by the suite (pass), not by my runner.
- **MDM .ps1 (profile):** run against a clone of the real dotprofile. Its machine-profile resolution fails on macOS pwsh (exit 1, unrelated to skills), so the MDM ps exit code is not a parity signal. Only its skills rows are.
