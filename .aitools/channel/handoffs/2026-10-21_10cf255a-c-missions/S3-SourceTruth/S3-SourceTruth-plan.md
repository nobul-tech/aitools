# S3-SourceTruth plan -- managed files: SOURCE is the source of truth

Mission SOURCE-TRUTH (Session Commander 10cf255a-c). Branch
`feature/managed-file-source-of-truth`, with origin/main 6eb2b0b merged in
(a merge, not a rebase: the branch was already pushed and force-push is not
allowed).
Target files are byte-identical between db4b3c5 and 6eb2b0b (`git diff --stat
db4b3c5 origin/main -- <targets>` empty, 2026-10-22), so the line ranges below
(taken at db4b3c5) are valid on the rebased branch.

Governing: `.claude/rules/plan-execution.md` + `reference/plan-execution-detail.md`
(shared-library change: verbatim code, error-handling audit, fresh sub-agent per
batch of at most 3 code files, verification between batches);
`interactive-menus.md` (return-value contract); `config-file-safety.md`;
`script-standards.md`; `cross-platform.md` (parity). Model: branch
docs/managed-file-choices, `.claude/rules/agentic-standards.md` "Managed-file
review choices and merge"; spec drafts in `../S3-SpecRewrite/` (PR #63).

## 1. Verbatim code (where it lives)

All new code is in `S3-SourceTruth-blocks/` (this folder). It is the plan's
verbatim "new" text; the "old" text is the origin/main content of the stated
range or `.old` file. Two tools apply it mechanically and refuse on any mismatch:

- `apply-lib.pl FILE SPEC` -- replaces line ranges with block files after
  checking each range's first line (`^# -{20}`) and last line (`^\}\s*$`);
  bottom-up; nothing written on any mismatch. A `.tmpl` block gets
  `review-json.js` injected at its `__REVIEW_JSON_NODE__` line, so the node
  script is byte-identical in both libraries.
- `apply-edits.pl FILE edits PREFIX` -- applies `edits/PREFIX-NN.old -> .new`
  pairs; each `.old` must occur exactly once; nothing written on any miss.
  Every `.old` was extracted mechanically from origin/main line ranges
  (`git show db4b3c5:<file> | perl -ne 'print if $. >= A && $. <= B'`).

Dry runs (2026-10-22, macOS): both libs and all nine caller files apply cleanly
on temp copies; `bash -n` and the pwsh parser pass on every result; the node
script extracted from both libs equals `review-json.js` (`cmp`); none of the
removed helpers remain; no caller line matches build-deploy's `inline_lib_*`
replacement patterns beyond the pre-existing `source`/dot-source lines.

## 2. Library changes

### scripts/aitools-lib.sh (`S3-SourceTruth-blocks/spec-sh.tsv`)

| Range (db4b3c5) | Old | New block |
|---|---|---|
| 368-395 | `backup_file` | `sh-G-backup.sh`: sets `BACKUP_FILE_OK` (false on a failed copy); still non-fatal |
| 426-549 | deploy state: `_DEPLOY_STATE_DIR`, `_DEPLOY_MANIFEST`, `get_content_hash`, `_deploy_state_key`, `initialize_deploy_state`, `get_deploy_state_hash`, `update_deploy_state`, `get_deploy_shadow`, `AUTO_MERGED_CONTENT`, `try_auto_merge` (all removed) | `sh-A-helpers.sh`: `_managed_abort` (log_error + exit 2, one helper for all prompts), `_managed_state_notice`, `_managed_protected_note`, `_managed_adopt_notice`, `_managed_write` |
| 797-900 | `_invoke_ai_merge` | `sh-F-merge.sh`: [n]o -> `menu`; no valid output -> `failed` + `MANAGED_MERGE_ERROR`; no fallback prompt |
| 902-1060 | `prompt_diff_review` (auto-merge menu, adopt label) | `sh-B-review.sh`: "Review choices" block + `prompt_diff_review DEST NEW ADOPT_OFFERED [CUR]`, one menu, loops on `menu` |
| 1062-1189 | `deploy_managed_file` (deploy state, auto-deploy, caller-side adopt) | `sh-C-deploy.sh.tmpl`: `deploy_managed_file SRC DEST TOOL ITEM [ADOPT_PATH] [ADOPT_FILTER]` + `review_json_fields SRC_FILE DEST ADOPT_PATH` |
| 1238-1290 | tracker | `sh-D-tracker.sh`: `failed` outcome; summary ERROR when failed > 0 |
| 1292-1358 | `prompt_json_field_review` | `sh-E-fieldprompt.sh`: optional `$6` local label (default `settings.json`, so `sync_managed_json` output is unchanged), `$7` overwrite-allowed; abort via `_managed_abort` |

Plus one edit pair after the ranges, `edits/libsh-01`: `_merge_validate`
returned the status of its last command (an assignment, always 0), so bash AI
merge validation never rejected any output (found by the merge-fail test; the
PS1 wrapper returns its result correctly). It now returns the validator's status.

`adopt_managed_file` stays (reverse discovery of user-created hooks/skills).
`sync_managed_json` is not touched.

### scripts/aitools-lib.ps1 (`spec-ps1.tsv`)

| Range | Old | New block |
|---|---|---|
| 327-352 | `Backup-File` | `ps1-G-backup.ps1` (`$script:BackupFileOk`) |
| 383-541 | `$script:DeployManifest`, `$script:DeployStateDir`, `Get-ContentHash`, `Initialize-DeployState`, `Get-DeployStateKey`, `Get-DeployState`, `Update-DeployState`, `Get-DeployShadow`, `Try-AutoMerge` (all removed) | `ps1-A-helpers.ps1`: `Invoke-ManagedAbort`, `Write-ManagedStateNotice`, `Write-ManagedProtectedNote`, `Write-ManagedAdoptNotice`, `Write-ManagedFiles` |
| 788-883 | `Invoke-AiMerge` | `ps1-F-merge.ps1` |
| 885-1074 | `Prompt-DiffReview` | `ps1-B-review.ps1`: `-FilePath -NewContent -AdoptOffered [-CurrentContent]` |
| 1076-1196 | `Deploy-ManagedFile` | `ps1-C-deploy.ps1.tmpl`: `-Content -DestPath -ToolName -ItemName [-AdoptPath] [-AdoptFilter]` + `Review-JsonFields -SourceFile -DestPath -AdoptPath` |
| 1245-1289 | tracker | `ps1-D-tracker.ps1` |
| 1291-1347 | `Prompt-JsonFieldReview` | `ps1-E-fieldprompt.ps1`: `-LocalLabel`, `-OverwriteAllowed` |

PS1 differences that are fixes, not drift: comparisons are case-sensitive
(`-ceq`, `Compare-Object -CaseSensitive`); before, `-eq` treated a case-only edit
as "verified". node gets its script and data through files, never through
native arguments (quoting differs across pwsh versions on Windows); "no adopt
target" is passed to node as `-`.

## 3. Caller changes (`edits/`)

| Prefix | File | Change |
|---|---|---|
| claude-sh-01..04 | setup-user-claude.sh | `adopt_claude_md` -> `claude_md_adopt_filter` (stdin->stdout; empty profile values never substituted); CLAUDE.md passes `ADOPT_PATH=$USER_REPO_PATH/claude/CLAUDE.md` + the filter, handles `failed`; rules pass `ADOPT_PATH` (dotprofile rule; empty in MDM), manual `cp` adopt and merged write-back removed, the dotprofile auto-commit/push after a merge & adopt kept (pending confirmation); validation skips files whose deploy failed; ERROR row via tracker when a rule failed |
| claude-ps1-01..04 | setup-user-claude.ps1 | same; `$claudeMdAdoptFilter` scriptblock |
| skills-sh-01..02 | setup-user-skills.sh | `ADOPT_PATH=$src` (the file read); adopted content still copied to the other deploy target, now with backup + checked copy; reverse discovery uses `tty_interactive` + `read_tty_choice` + `adopt_managed_file` (GitHub #29: the bare `read -r choice < /dev/tty` aborted under set -e at EOF) |
| skills-ps1-01..02 | setup-user-skills.ps1 | same; reverse discovery `Test-InteractiveConsole` + `Read-ConsoleChoice` + `Adopt-ManagedFile` |
| hooks-sh-01..02 | setup-user-hooks.sh | `ADOPT_PATH=$hook_src` (shared/hooks, or scripts/ for deploy-only helpers: before, adopting ait-harvest.py created a shadowing copy in shared/hooks); manual adopt removed; chmod checked; reverse discovery of user-created hooks unchanged (default #10) |
| hooks-ps1-01..02 | setup-user-hooks.ps1 | same |
| bd-01..02 | build-deploy.sh | embedded-skill deploy (MDM) passes no adopt target (the file read is the build-time embed, default #9); manual adopt + sync removed |
| cpp-sh-01, cpp-ps1-01 | check-post-push.sh/.ps1 | step 28 (deploy state integrity) retired: `step_skip` |

## 4. Interface contract (as implemented)

As briefed, plus the "Contract change" items in section 6.
- `deploy_managed_file SRC_CONTENT DEST TOOL ITEM [ADOPT_PATH] [ADOPT_FILTER]`
  -> `MANAGED_FILE_RESULT` in `created|updated|verified|accept & adopt|skipped|failed`.
- `prompt_diff_review DEST NEW ADOPT_OFFERED [CUR]` -> `DIFF_REVIEW_RESULT` in
  `overwrite|adopt|merge|skip|failed` (`menu` is internal to the loop).
- `review_json_fields SRC_FILE DEST ADOPT_PATH` -> same result set.
- `deploy_tracker_record failed` (count + `DETAIL failed: <item>`);
  `deploy_tracker_summary` ERROR when failed > 0.
- Abort: `_managed_abort` / `Invoke-ManagedAbort`: log_error + `exit 2`, as on
  main. No abort marker: the commander reversed D-TS13 on 2026-10-21 (a bare
  exit 2 means user abort).
- PS1 twins as briefed, plus `-AdoptFilter [scriptblock]`.

## 5. Error-handling audit (every suppression in the new code)

| Block:line | Pattern | Check |
|---|---|---|
| sh-B:120 | `diff ... 2>&1) \|\| true` | unchanged from main; comment present; diff exits 1 on differences (expected) |
| sh-C keys/plan/apply | `node ... 2> "$work/err" \|\| rc=$?` | rc checked on the next line; stderr logged with log_error |
| sh-A:41,44,70 | `git ... 2>/dev/null) \|\| x=""` | comment + empty-result check |
| sh-F:60 | `invoke_ai ...) \|\| true` | comment + `-z "$merged"` check right after |
| sh-G:24 | `ls ... 2>/dev/null` | unchanged; comment + `-n` check |
| ps1-A git 2>$null (3) | comment + `$LASTEXITCODE`/empty check |
| ps1-A/C `Remove-Item ... SilentlyContinue` (temp/snapshot/work cleanup) | `# ErrorAction exempt:` comment (existing convention); nothing depends on it |
| ps1-C:186, ps1-F:25,27 `Get-Command ... SilentlyContinue` | command-existence check with explicit branch |
| every `catch` in ps1-A/C/F/G | logs (LogError/LogWarn/LogDetail) or reports through `$script:ManagedWriteError` and returns failure |
| `log_error`/`LogError` on a write failure | paired with an ERROR row: tracker (`failed`) or the caller's own row (CLAUDE.md "deploy failed") |
| `cp`/`Copy-Item` | snapshot copy failure -> nothing written; restore failure -> log_error; skills sync copy -> checked, log_error |

Bash 3.2: no `${x,,}`, no empty array expansion; `read ... <&3` + `done 3<`;
`$'\t'`; `printf -v` (3.1+).

## 6. Contract change (pending commander decision)

Relayed by the Session Commander from SPEC-REWRITE (PR #63); each is one
function or variable to change.
1. CLAUDE.md adopt transform: optional `ADOPT_FILTER` (`$6`) / `-AdoptFilter`; setup-user-claude passes its transform.
2. `prompt_diff_review` reports a failed AI merge: `DIFF_REVIEW_RESULT=failed` -> `MANAGED_FILE_RESULT=failed`, nothing written (`_invoke_ai_merge`).
3. Merge preview [n]o returns to the review menu (`menu` loop in `prompt_diff_review`).
4. JSON mixed per-field choices: one result by precedence failed > accept & adopt > skipped > updated > verified (end of `review_json_fields`).
5. Restore when the target did not exist: the partial file is removed (`_managed_write`).
6. JSON field only in LOCAL: [a]dopt / [s]kip / [x]abort, no overwrite; without an adopt target, a terminal, or with --force: kept, no prompt (`review_json_fields`, `prompt_json_field_review $7`).
7. JSON required keys = SOURCE's top-level keys, minus keys the review chose to leave absent (skip or adopt of a SOURCE-only key) -- otherwise a deliberate skip would fail validation (`keptKeys` in review-json.js).
8. A failed backup of an existing file fails the step, nothing written (`BACKUP_FILE_OK` checked in `_managed_write`).
9. Skills adopt target = the file read (dotprofile or shared/skills); the MDM embedded deploy has no adopt target.
10. Reverse discovery of user-created hooks keeps `adopt_managed_file` into the dotprofile.
11. Dotprofile auto-commit/push kept (commander confirmed 2026-10-21; ported unchanged: runs after a merge & adopt of a rule, as before: condition `accept & adopt` + `MERGED_CONTENT` set).
12. cli-config.json (setup-user-cursor's own merge) untouched.
13. CLAUDE.md adopt target when the dotprofile has no `claude/CLAUDE.md` (SOURCE came from shared/claude-shared.md): adopt creates the dotprofile template, as on main (adopt was offered whenever a user repo is configured); the next run reads it and verifies. Alternative: offer adopt only when SOURCE is the dotprofile file (one `if` in setup-user-claude).
Own additions: `prompt_json_field_review $6/$7` and `Prompt-JsonFieldReview -LocalLabel/-OverwriteAllowed` (optional, defaults keep sync_managed_json output); the library logs "Uncommitted change in <repo>" after every adopt (it never commits).

## 7. Batches (fresh delegate each; verification between)

| Batch | Files | Apply | Verify |
|---|---|---|---|
| B1 | scripts/aitools-lib.sh | `apply-lib.pl` spec-sh.tsv, then `apply-edits.pl` libsh | bash -n; node cmp; grep removed helpers; tests/logging |
| B2 | scripts/aitools-lib.ps1 | `apply-lib.pl` spec-ps1.tsv | pwsh parser; node cmp; tests/logging .ps1 |
| B3 | setup-user-claude.sh, setup-user-skills.sh, setup-user-hooks.sh | `apply-edits.pl` claude-sh, skills-sh, hooks-sh | bash -n; isolated-HOME smoke runs |
| B4 | the three .ps1 | claude-ps1, skills-ps1, hooks-ps1 | pwsh parser |
| B5 | build-deploy.sh, check-post-push.sh, check-post-push.ps1 | bd, cpp-sh, cpp-ps1 | bash -n / parser; build-deploy under isolated HOME + fake dotprofile; check-post-push 29-31 |
| B6 | tests/managed-files/ (new), .github/workflows/check.yml | new files | the test matrix below |

## 8. Tests (isolated HOME; both languages where runnable)

created; verified; non-interactive overwrite; EOF at the prompt; --force;
adopt writes LOCAL-kept + repo file and the next run is verified; merge & adopt
with a stub `claude` on PATH writes both and the next run is verified; merge
[n]o returns to the menu; failed AI merge -> failed, nothing written; skip;
abort exits 2 with "Aborted by user" logged and LOCAL unchanged; forced write failure (read-only adopt target during merge & adopt)
restores LOCAL, returns failed, run continues; new file in a read-only dir ->
failed, nothing left; JSON per-field overwrite/adopt/skip, LOCAL-only kept,
key order preserved, invalid JSON result restored; tracker ERROR row;
CLAUDE.md filter round trip. Interactive cases run under a pty (python3 `pty`).
check-post-push steps 29/30/31 (menu parity, return-value coverage, state
machine sync).

Not runnable here: Windows (Git Bash, Windows pwsh); the .ps1 setup scripts
(Windows-guarded) are parse-checked only; their library functions are tested
by dot-sourcing the lib under macOS pwsh.
