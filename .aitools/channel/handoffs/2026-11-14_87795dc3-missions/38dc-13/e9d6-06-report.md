# e9d6-06-port-fanout-lib: report (v1.0, 2026-11-14)

**Intent**: **Purpose**: Report the port of tests/fanout-lib to a native
PowerShell Windows harness and the macOS/Linux-only .sh harness, with the
evidence 38dc-13 needs to verify, commit and ship it. **Scope**: what the suite
tests on Windows, the CI comparison, mutations, syntax and guard results, files
changed, findings. NOT the CI workflow, docs or golden files (38dc-13 / never
edited). **Audience**: 38dc-13 (delegating agent).

## Summary

1. New `tests/fanout-lib/test-fanout-lib.ps1` (Windows, native pwsh): 90 passed, 0 failed, 20 skipped, the same 90 ok lines in the same order as the .sh harness's Windows CI run on main, and the same count line.
2. `tests/fanout-lib/test-fanout-lib.sh`: OS guard (uname + `BASH_VERSINFO[5]`, per 38dc-13's contract correction), every ps/Windows branch and the embedded `drive.ps1` removed; macOS/Linux behaviour unchanged apart from two skip-reason texts.
3. 4 mutations each turned a PASS into a FAIL and made the suite exit 1; every mutated file restored byte for byte; `git diff -- tests/fanout-lib/golden` empty.
4. The 20 SKIPs stay SKIPs on Windows (symlinks, FIFOs, `* ?` names, chmod 000): evidence below. The symlink group could run in CI (elevated runner) but I could not run it locally, so I did not enable untested cases.
5. No INCIDENT, no WRITE_BLOCKED; one CONFLICT line (the contract correction); no contract change requests.

## What Windows-reached code the suite tests

All in `scripts/aitools-lib.ps1`, dot-sourced by a driver run as a child pwsh
(`-NoProfile -NonInteractive -File`) through `Invoke-TestScript`, with HOME and
USERPROFILE set to a temp case home, AITOOLS_LOG_DIR / AITOOLS_SUMMARY_FILE in
the temp root, stdin at EOF:

- deploy tracker: `Initialize-DeployTracker`, `Record-DeployOutcome`, `Write-DeployTrackerSummary`
- `Get-RuleNameKind`, `Get-SkillNameKind`
- `Read-HarnessManifest`
- `Test-FanoutTextEqual` (with `Read-FanoutText`)
- `Test-FanoutDirMatches` (with `Get-FanoutEntryType`)
- `Backup-Dir` (with `Copy-DirectoryTree`)
- `Initialize-Logging` / `LogDetail` (the deploy.log format check)
- static check: `scripts/setup-user-cursor.sh` and `scripts/setup-user-cursor.ps1` hold no own copy of the manifest reader or list helpers (text match, not execution)

Class (c): .ps1 equivalent written. No case needs Git Bash: the suite runs no
cross-platform bash code on Windows (`Resolve-TestGitBash` is not used).

## How the .ps1 harness is built

- Fixtures: the base group's fixtures written byte for byte as the .sh writes
  them (helper `W` writes one byte per char through Latin1, so BOM and
  `\xFF\xFE\xC3\xA9` fixtures are exact). The groups that never run on Windows
  (symlinks, fifos, special, unread) get no fixtures.
- Cases: the same base-group case list in the same order (the `sh_` cases kept
  in the case file, skipped by the driver and the checks, as before).
- Driver: the `drive.ps1` text moved unchanged from the .sh heredoc into a
  single-quoted here-string (it keeps its `dmf` and `ps_bdirlink` handlers,
  which only the symlink group would reach; kept so the follow-up needs only
  fixtures and cases).
- Output: the .sh's line format (`  ok   NAME`, `  FAIL NAME`, `  skip ...`) and
  final line `<n> passed, <n> failed, <n> skipped` (the .sh's form; it has no
  parenthetical). Exit 1 on any failure.
- Log checks: deploy.log split on LF only, as perl/grep read it (a manifest
  line with a CR must not split a log line); the `logtext` rule (first CR
  removed, `\` to `/`) for the detail-line checks.
- One deliberate tightening: a missing deploy.log fails the "log line format"
  check (the .sh's perl passed on an unreadable file; the other log checks
  failed then).
- Two traps found while writing it (now avoided, and worth carrying forward):
  `$CASES` and `$cases` are the same variable (case-insensitive names), and a
  function named `Md` is shadowed by the built-in `md` alias (aliases win over
  functions): the first run failed with "An item with the specified name ...
  already exists". Renamed to `$caseList` and `New-Dir`; all helper names
  checked free with `Get-Command`.

## CI vs local

CI: `ci-windows-main.log`, step "Run bash tests/fanout-lib/test-fanout-lib.sh"
(section extracted with `ci-section.py`). Local: `pwsh -NoProfile -File
tests/fanout-lib/test-fanout-lib.ps1`, Windows 11, pwsh 7, run time about 1 s.

| | ok | FAIL | skip lines | count line |
|---|---|---|---|---|
| CI (.sh, Git Bash, pwsh driver) | 90 | 0 | 4 | `90 passed, 0 failed, 20 skipped` |
| local (.ps1, native) | 90 | 0 | 4 | `90 passed, 0 failed, 20 skipped` |

ok/FAIL/count lines identical and in the same order: True (compare.py). Lines
that differ, all skip reasons, reworded on purpose because the old reasons
named Git Bash mechanisms the native harness does not use:

| CI | local |
|---|---|
| `skip symlink cases (ln -s does not make real and dangling symlinks here)` | `skip symlink cases (Windows: making symlinks needs Developer Mode or an elevated process)` |
| `skip FIFO cases (no mkfifo, or Windows: no FIFOs native pwsh can see)` | `skip FIFO cases (Windows: NTFS has no FIFOs)` |
| `skip unreadable cases (chmod 000 leaves files readable: root or Windows)` | `skip unreadable cases (Windows: chmod 000 has no NTFS equivalent here)` |

The special-name skip line is identical.

## The 20 SKIPs

| Group | Count | Why skipped on Windows | Can the native harness run it now? |
|---|---|---|---|
| symlinks | 7 (dm-linktarget, dm-linkinside, dm-linkdir, ml-dangling, ml-dangling-dry, ml-live, bd-link-ps) | Git Bash `ln -s` copied instead of linking | Not here: `[IO.File]::CreateSymbolicLink` failed for a real, a dangling and a directory link with "A required privilege is not held by the client" (probe 2026-11-14; Developer Mode key absent, process not elevated). CI likely could (GitHub's Windows runners run as administrator; I did not verify this), but these PowerShell expectations have never run anywhere (the ps symlink cases existed only for a Git Bash run that always skipped them). I kept SKIP: enabling cases I cannot run locally risks a red CI. Follow-up already named in PR #139 ("Windows symlink / chmod / read-only coverage"). |
| fifos | 2 (dm-fifo, dm-candfifo) | no FIFO pwsh can see | No: NTFS has no FIFOs (named pipes live under `\\.\pipe\`, not in a directory tree). Stays SKIP. |
| special | 1 (bd-special) | `* ?` in names | No: `[IO.Directory]::CreateDirectory('...\r[1]*?')` failed with "The filename, directory name, or volume label syntax is incorrect" (probe 2026-11-14). Stays SKIP. |
| unread | 10 (m-r-unread, te-unread, dm-unreadfile, dm-unreadsub, dm-unreadcand, dm-unreaddiffer, dm-unread2, dm-noexec, bd-unread, bd-partial) | chmod 000 is a no-op on NTFS | Not as a port: an ACL deny would need new fixture design (search permission, `dm-noexec`, has no direct Windows meaning: traverse checking is bypassed by default). Stays SKIP; same follow-up. |

The skip counts are the .sh's (7, 2, 1, 10), so the count line matches CI.

## Mutations (scratch `mutate.ps1`; each file restored in a `finally`, restore verified byte for byte)

| # | Mutation | Failed checks | Exit |
|---|---|---|---|
| a | golden `parity-base.results`: `te-trailing rc=0` changed to `rc=1` | `parity base group: results match golden` | 1 (89 passed, 1 failed) |
| b | harness expectation: `Case 'te-differ' 'rc=1'` changed to `rc=0` | `ps te-differ` | 1 (89/1) |
| c | harness env: `AITOOLS_LOG_DIR = $null` (the driver then logs under the temp case HOME) | `ps unknown outcome logged`, `ps deploy.log: lines without the log line format`, the 4 `ps detail log:` checks | 1 (84/6) |
| d | fixture: `differ/T/sub/deep/y.sh` written as `y` instead of `y2` | `ps dm-differ`, `parity base group` | 1 (88/2) |

After mutation c, the real `~/.aitools/logs` holds no `[test-fanout-lib]`
line (Grep: 0), so the child logged under the temp HOME (aitools-lib.ps1
`Initialize-Logging` falls back to `$HOME/.aitools/logs`; pwsh's `$HOME`
follows USERPROFILE). Clean run after the mutations: 90/0/20, exit 0. No
`fanout-lib-*` temp root left behind. `git -C W status --short tests/fanout-lib`:
`M test-fanout-lib.sh`, `?? test-fanout-lib.ps1`; `git -C W diff --
tests/fanout-lib/golden`: empty.

## Syntax and guard

- `bash -n tests/fanout-lib/test-fanout-lib.sh`: OK.
- PowerShell parser (`ParseFile`) on `test-fanout-lib.ps1`: no errors.
- `-Help`: exit 0, prints the 25 header lines.
- Guard: the .sh run once with Git Bash (`C:\Program Files\Git\bin\bash.exe`,
  from `Resolve-TestGitBash`) from an empty temp directory: exit 1, output
  `This script is for macOS/Linux. On Windows, run
  tests/fanout-lib/test-fanout-lib.ps1 with pwsh.`, nothing written in the
  working directory, no new `tmp.*` directory in the temp dir.
- `tests/os-guards/classify-guards.pl` on the two files: `posix` for the .sh
  (strong guard, BASH_VERSINFO case present), `win` for the .ps1.
- The new .ps1 is ASCII only.

## Files changed

- `tests/fanout-lib/test-fanout-lib.ps1` (new, 515 lines, LF)
- `tests/fanout-lib/test-fanout-lib.sh` (edited, 740 -> 607 lines): header platform paragraph;
  OS guard (contract-correction form) before `--help`; `DRV=sh` (the
  `TEST_LANG` branch and the pwsh-on-PATH check removed); Windows-only
  conditions removed from the FIFO and special groups; Git Bash comments
  rewritten; the `bd-link-ps` case removed (a PowerShell-only case, never run
  by the .sh; its expectation lives on in git history and in the .ps1's
  driver handler: `ok=true l.md=file:outside sub=dir sub/x.txt=yes`); the
  `ps_*` branches in the driver and the result loop removed; the whole
  `drive.ps1` heredoc removed (moved to the .ps1); `run_shell` reduced to the
  bash run; `NF`/`ND` and the Windows `logtext` branch removed (on macOS/Linux
  `native_path` returned its argument, so `$F`/`$D` are the same values); the
  PowerShell `logged` expectations removed. `--help` range 2-29 unchanged (the
  header kept its length; line 29 is still the last header line). Two skip
  texts changed (printed on macOS/Linux only without mkfifo, or as root):
  `(no mkfifo, or Windows: no FIFOs native pwsh can see)` -> `(no mkfifo here)`;
  `(chmod 000 leaves files readable: root or Windows)` -> `(chmod 000 leaves
  files readable: root)`. Bash 3.2 compatible (no new constructs beyond
  `${BASH_VERSINFO[5]:-}`).

Not run: the .sh harness on macOS/Linux (CI does that; I cannot run it past its
guard here). Its macOS/Linux paths are unchanged in logic: every removed branch
was a `ps`/`windows` branch, dead under the guard.

## Findings

- CONFLICT: contract item 5 guard text (`${OSTYPE:-}` case) vs 38dc-13's
  contract correction message (`${BASH_VERSINFO[5]:-}` case, with evidence that
  an exported OSTYPE overrides bash's) -- resolved by tier 2 (the delegating
  agent's newer instruction, same tier as the prompt, newest wins; it does not
  loosen a rule): used the corrected block verbatim.
- Observation (not an incident, left as is to keep macOS/Linux output
  identical): the .sh adds 10 to SKIP for the unread group, but on macOS/Linux
  that group has 11 cases (`mrc-unread` is bash-only). The count only shows when
  the group is skipped (running as root). Suggested: 38dc-13 decides whether a
  follow-up corrects it to 11 in the .sh.
- INCIDENT: none. WRITE_BLOCKED: none.

## Contract change requests

None. The `tests/lib/platform-lib.ps1` helpers covered everything.

## Open questions

1. Enable the symlink group on Windows? Suggested answer: yes, as the PR #139
   follow-up, in a session that can create symlinks (elevated or Developer
   Mode) to run it first: add the fixtures with `[IO.File]::CreateSymbolicLink`
   / `[IO.Directory]::CreateSymbolicLink` behind a probe (as the .sh does with
   `ln -s`), the 8 symlink-group cases with `bd-link-ps` restored, and the
   "dangling symlink logged as an error" check; the driver already has the
   handlers.
2. Unreadable-entry coverage on Windows? Suggested answer: same follow-up, with
   ACL deny entries (`Set-Acl`) for the file cases and a separate decision for
   `dm-noexec`, which has no Windows equivalent.

## Operational learning

- A helper named like a built-in alias (`md`, also `cd`, `rd`, `ls`, `cat`,
  `diff`, `sort`...) is never called: aliases take precedence over functions.
  Check helper names with `Get-Command <name>` before use.
- `$CASES = ...` overwrites a `$cases` list in the same scope (case-insensitive
  names): the delegate prompt's warning applies to every pair, not only
  switches.
- Splitting a log on LF only (not `ReadAllLines`, which also splits on a lone
  CR) is what keeps a parity port of perl/grep line checks exact.
- A non-elevated Windows session without Developer Mode cannot create any
  symlink, dangling or not ("A required privilege is not held by the client").
