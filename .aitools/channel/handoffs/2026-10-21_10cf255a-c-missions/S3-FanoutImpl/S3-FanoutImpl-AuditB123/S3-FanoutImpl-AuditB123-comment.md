AUDIT (logging, B): FINDINGS

Scope: runtime logging/script-standards audit of `scripts/setup-user-cursor.sh` / `.ps1` steps 4 (rules fan-out) and 5 (skills fan-out), macOS (Darwin arm64), GNU bash 5.3.15 + PowerShell 7.6.3, commit 880749e; isolated HOME/USERPROFILE per run, deploy.log at `$HOME/.aitools/logs/deploy.log`. Independent of the static audit (A).

**How it ran.** sh: a driver that sources `aitools-lib.sh`, `logging_init "setup-user-cursor"`, then evals the script text from `log "Step 4: Cursor user rules"` to `# --- END cursor body` and the script's own exit footer (the bash twin of `tests/rules-fanout-cursor/step4-driver.ps1`). ps: `step4-driver.ps1` unchanged. Fidelity check: the whole `setup-user-cursor.sh` (steps 1-5, rg/agent stubbed) on the happy fixture gives step 4/5 rows identical to the driver run. Every case was run twice: once at 880749e and once on the clean merge of 880749e with PR #124's head 282c28b (`git merge-tree --write-tree 880749e 282c28b` = 8a4b216, no conflicts), because the PR's copy of `fanout_harness_skills` predates #124's audit fixes (finding 2). Parity is compared on summary rows (every category, in order), on deploy.log messages (level + text; home path, `.bak.<UTC>` stamps and the driver footers normalised) and on the resulting `~/.cursor` tree.

### Scenarios (both steps in every run)

| # | Scenario | sh rc | ps rc | Final rows (cursor rules / cursor skills) | Rows parity | Log parity |
|---|---|---|---|---|---|---|
| 1 | happy (shared/aitools/dotprofile, retired removed + retired kept, user files, local edit) | 0 | 0 | WARN 3 added, 1 removed / WARN 2 added, 1 updated, 1 removed + 2 ACTION | yes | yes |
| 2 | rerun (second run) | 0 | 0 | WARN 3 verified / WARN 3 verified | yes | yes |
| 3 | no manifests | 0 | 0 | OK 3 added / WARN 2 added, 1 updated (WARN: auto-promoted by the local-edit overwrite warning) | yes | yes |
| 4 | bad header (unparseable) | 0 | 0 | WARN 3 added / WARN 2 added, 1 updated + ACTION "Run aitools ..." x2 | yes | yes |
| 5 | invalid manifest lines + listed-but-missing | 0 | 0 | WARN / WARN | yes | yes |
| 6 | manifest chmod 000 | 1 | 1 | ERROR cannot read ... manifest + ERROR 1 failed (both tools) | yes | reason text only |
| 7 | manifest is a directory | 1 | 1 | as 6 | yes | reason text only |
| 8 | dangling symlink in source (rule + skill) | 1 | 1 | ERROR 1 failed / ERROR 1 failed | yes | yes |
| 9 | dangling symlink in target (s.mdc, skills/alpha) | 1 | 1 | ERROR 1 failed / WARN + ACTION | yes | **NO (finding 1)** |
| 10 | source file chmod 000 | 1 | 1 | ERROR 1 failed / ERROR 1 failed | yes | reason missing in sh (finding 3) |
| 11 | harness dirs chmod 000 | 1 | 1 | ERROR cannot read harness rules / skills | yes | reason text only |
| 12 | backup failure: `~/.cursor` 555 (skills backup root) | 1 | 1 | WARN / ERROR 1 failed ("Not removed: gone ... backup failed") | yes | reason text only |
| 13 | backup failure: rules + skills dirs 555 | 1 | 1 | ERROR 4 failed / ERROR 3 failed | yes | reason text only; tree differs (finding 7) |
| 14 | nocreate (files in the way) | 1 | 1 | ERROR cannot create rules dir / ERROR cannot create skills dir | yes | reason text only |
| 15 | dry run | 0 | 0 | WARN dry run (no files written) x2 + ACTION | yes | yes |
| 16 | dry run + nocreate | 1 | 1 | ERROR cannot create rules dir / OK dry run at 880749e, ERROR merged (finding 2) | yes | yes |
| 17 | no harness dirs | 0 | 0 | OK n/a (no harness rules) / no row (by design, FO-6) | yes | yes |
| 18 | empty harness dirs | 0 | 0 | OK n/a / OK n/a | yes | yes |
| 19 | only retired names | 0 | 0 | OK n/a (no harness rules) / OK verified (finding 6) | yes | yes |
| 20 | pty rules `[s]kip` | 0 | 0 | WARN 1 skipped (user review) / step 5 ran | yes | yes |
| 21 | pty rules `[x]abort` | 2 | 2 | no rows; step 5 not run (by design, D-TS13) | yes | yes |
| 22 | pty skills `[s]kip` | 0 | 0 | OK n/a / WARN 1 skipped (user review) | yes | yes |
| 23 | pty skills `[x]abort` | 2 | 2 | OK n/a / no row (by design) | yes | yes |

"reason text only": the same message, with the OS error worded differently by bash and .NET. Results were the same at 880749e and on the merge, except where marked.

Checklist results: (1) every deploy.log line, in every run, matches `[UTC-Z] [setup-user-cursor] [info|ok|warn|error|detail]`. (2) every run with error lines has an ERROR row and exit 1; the only exceptions are the aborts (exit 2, no row, as documented). (3) ACTION rows appear for retired-kept rules/skills, kept symlinks and a bad header. (4) every path wrote a row for each tool, except the two documented cases (17, 21/23). (5) every OK/WARN/ERROR detail is 30 characters or fewer. (6) no error vanished from the console, the log and the summary together; at 880749e some reasons reached only the console (findings 2 and 3). (7) rows had parity in 23/23 cases; messages broke parity in case 9. (8) `removed` is recorded (`DETAIL|cursor rules|removed: gone.mdc`, "1 removed" in the final row).

### Findings

1. **blocking (message parity / error count): .ps1 step 4 validation reports a failed dangling-symlink target a second time.** `setup-user-cursor.ps1:850`: `Test-Path -LiteralPath $destPath -PathType Leaf` is true for a dangling link on pwsh 7, so the loop reads it and adds `LogError "Validation failed: cannot read ~/.cursor/rules/s.mdc -- ... Could not find file ..."` after `Failed: s.mdc: ... is a dangling symlink -- not written through it` was already logged. The .sh skips it (`setup-user-cursor.sh:837`, `[ -f "$dest_path" ] || continue`). Evidence (case 9): sh has 2 error lines and logs `FAILED with 1 error(s)`; ps has 3 error lines and logs `FAILED with 2 error(s)`. The rows match only because the item already failed (`ERROR|cursor rules|1 failed`). Fix: in the .ps1 loop, skip a missing target the same way as the .sh, e.g. `if (-not [System.IO.File]::Exists($destPath)) { continue }` (false for a dangling link). Alternatively, validate only the names whose deploy result was created/updated/verified.

2. **non-blocking (merge order): the PR carries an older `fanout_harness_skills` / `Invoke-HarnessSkillsFanout` than PR #124's head (282c28b).** `git diff 282c28b..880749e -- scripts/aitools-lib.sh` removes 253 lines of #124's audit fixes. At 880749e the runs show: step 5 errors whose reason goes only to the console as raw stderr (`mkdir: .../.cursor/skills: File exists`, `cat: .../SKILL.md: Permission denied`, `mkdir: .../skills.bak.<UTC>: Permission denied`, `rm: .../skills/gone: Permission denied`; aitools-lib.sh:2990, 3103, 3201, 3215), while deploy.log only says `Cannot create ~/.cursor/skills` / `Cannot read harness skill file ...`. The dry run does not preview "cannot create skills dir" (case 16: `OK|cursor skills|dry run (no files written)`, but the real run gives `ERROR|cursor skills|cannot create skills dir`). A retired skill that is kept is also logged as `Preserved unmanaged skill: mineold`. Invalid skills-manifest lines get no ACTION row. On the merge with 282c28b, all of these are fixed and every case was re-run: no raw step-5 stderr, case 16 gives the ERROR row, no double count, and ACTION for invalid lines. Fix: merge #124 before #123, or merge `origin/feature/fanout-claude-skills` into this branch again before it merges.

3. **non-blocking: in .sh step 4, the reason for an unreadable source rule goes only to the console.** `setup-user-cursor.sh:484` (`< "$1"`) fails in the shell redirect, so bash prints `...: s.md: Permission denied` raw to stderr, and line 699 logs only `Failed: s.md: conversion to .mdc failed`. The .ps1 logs the reason (`.ps1:692`: `Failed: s.md: cannot read ... Access to the path ... is denied`). This is still present on the merge. Fix: before converting, check `[ -r "$rule_src" ]` and log `Failed: $rule_base: cannot read $(display_path "$rule_src")`, or capture the converter's stderr into the log line, as line 649-651 does for mkdir.

4. **non-blocking: in step 4, invalid rules-manifest lines and listed-but-missing rules are `log_warn` only, with no ACTION row** (`setup-user-cursor.sh:563, 627`; `.ps1:569, 620`). In the same run, header-bad gets ACTION "Run aitools to rebuild ~/.aitools/rules and its manifest", and after the #124 merge step 5 gives that ACTION for invalid skills-manifest lines (case 5 on the merge: ACTION for skills, none for rules). Fix: write the same ACTION once when any invalid or missing line is seen, to match step 5.

5. **non-blocking: `backup_dir` never backs up either fan-out target.** It copies only a directory that has a top-level `*.md` (aitools-lib.sh:1042-1058). `~/.cursor/rules` holds `*.mdc` and `~/.cursor/skills` holds directories, so every run logs only `[detail] backup_dir: ~/.cursor/rules: not backed up (no top-level *.md file)` (same for skills; call sites `setup-user-cursor.sh:647`, `.ps1:638`, aitools-lib.sh:2989). No data is lost: deploy_managed_file backs up each file it overwrites, and retired prunes check their backup first. Still, the directory-backup step in config-file-safety.md is effectively absent and reported only at detail level. Fix: drop the calls and say why in the comment, or let `backup_dir` take the managed pattern (`*.mdc`, skill dirs).

6. **non-blocking: the two steps word the same case differently.** With only retired names and nothing in the target (case 19), step 4 writes `OK|cursor rules|n/a (no harness rules)` (`setup-user-cursor.sh:869-872`), while step 5 writes `OK|cursor skills|verified` (tracker default). Fix: use one wording for both (step 5 could write `n/a (no harness skills)` when nothing was deployed or removed).

7. **non-blocking (outcome detail, for the functional review): a failed retired-skill removal leaves different trees.** With `~/.cursor/skills` mode 555 (case 13), sh `rm -rf` deletes `gone/SKILL.md` before it fails on the directory, while pwsh `Directory.Delete` leaves the files in place. Rows and messages match, the backup was verified before removal, and on the merge the message says "it may be partly removed; backup in ~/.cursor/skills.bak.<UTC>/gone". No change needed for logging.

8. **non-blocking, pre-existing (not in this PR's diff):** when `backup_file`'s `cp` fails, its stderr goes raw to the console (aitools-lib.sh:991), and the log line `Could not back up ... -- proceeding without backup` has no reason. The .ps1 includes it.

Tests (`tests/rules-fanout-cursor/`, `tests/skills-fanout/`, `tests/fanout-lib/`), scanned for silent failures: every `2>/dev/null` is either cleanup with a printed warning (`test-fanout-lib.sh:39`, `test-skills-fanout.sh:43`) or a check whose failure reads as "no match" and is used only positively (`test-skills-fanout.sh:196-197`; no negated `logged`). No `|| true` and no empty catch. Clean.

### Not run

- Windows (no Windows host); bash 3.2 (`/bin/bash`) was not used, only bash 5.3.
- The whole `.ps1` (its OS guard stops it on macOS; I used `step4-driver.ps1`, which runs the same step 4/5 text). The whole `.sh` was run once (happy path) to confirm the driver gives the same results.
- `AITOOLS_DRY_RUN=1` on the .ps1 path: `step4-driver.ps1` starts at step 4, so the script's env passthrough (`.ps1:49`) is outside the text it runs. Dry run was tested with the flags (`--dry-run` / `-DryRun`).
- The MDM `deploy/` copies (no `build-deploy.sh` run, by instruction).
- `--force` (steps 4/5 do not read FORCE).

Harness (reusable): `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanoutImpl/S3-FanoutImpl-AuditB123/a123b-runner.sh`, `a123b-step45.sh`, `a123b-analyze.pl`, `a123b-raw.pl`, `a123b-merged.sh`, `a123b-full.sh`.
