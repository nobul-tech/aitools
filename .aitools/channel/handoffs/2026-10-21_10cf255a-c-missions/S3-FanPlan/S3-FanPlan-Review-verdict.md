# S3-FanPlan-Review verdict: plans/rules-fanout-claude.md (draft)

**Verdict: APPROVE WITH CHANGES.** The plan's edits apply as written, and the plan's own test suite passes when I apply every edit to an exported #112 tree. No change I found needs the plan re-planned. Required: two small code changes (RC-1, RC-2) and one commander decision before Batch B ships (RC-3). The rest is non-blocking.

Reviewer: S3-FanPlan-Review (level 2, under S3-FanPlan), 2026-10-26. This is an independent review. I did not read the planner's notes or any S3-FanPlan-*-findings file. Method: the /optimize-plan skill, followed by hand. I also loaded /tool-ops; its Claude Code reference has no item yet on how Claude Code loads user rules, so the plan's draft item #28 is new and still UNVERIFIED.

Base drift: origin/main is now `568fb5b`, not the `480b901` the brief named. The seven commits since then are BUILD-PKG and channel files, plus `scripts/check-pre-push.sh/.ps1` (step 7 now runs on every push). None of them touches a file this plan edits. Every count below against "main" was taken at `568fb5b`.

## Required changes

### RC-1 (code, Batch A or B6): PowerShell removes a retired rule without a backup when its name holds wildcard characters
- **Where in the plan**: B6, the retired-rules loop: `Backup-File -FilePath $rmPath; if (-not $script:BackupFileOk) {...}; Remove-Item -LiteralPath $rmPath`. The audit table claims "no removal without a backup", and section 4 item 7 says the same.
- **Evidence**: the lib's `Backup-File` (#112 head, `scripts/aitools-lib.ps1:781-805`) runs `if (-not (Test-Path $FilePath)) { return }` and `Copy-Item -Path`. Both are wildcard-aware. For a name like `[r].md`, `Test-Path` finds no match, so the function returns early with `$script:BackupFileOk` still `$true`. B6 then removes the file. I ran a probe on the edited export (`.scratch/session-review/probe-bracket-retired.sh`) with manifest line `[r].md<TAB>retired`, harness backup `[r].md.bak.2026-10-25T000000Z` and deployed `[r].md` (same text):
  - sh: removed, backup `[r].md.bak.2026-10-26T225859Z` kept.
  - ps: removed, **no backup**.
  - Both runs wrote `DETAIL|claude rules|removed: [r].md`, so the parity test cannot see the difference: it compares rows, and no bracket-named retired case exists.
- **Required change** (either option):
  - (a) Batch A also changes `Backup-File` to `Test-Path -LiteralPath` / `Copy-Item -LiteralPath`. The prune glob `"${FilePath}.bak.*"` needs its own escaping (`[WildcardPattern]::Escape`). Preferred, because it fixes every caller.
  - (b) B6 checks after the backup that a `"$rmName.bak.*"` file now exists, using `[IO.Directory]::GetFiles` plus an ordinal `StartsWith`, as the loop already does. If none exists, the rule is `failed`.
- In either case, add a test case `retired-bracket` with a tree comparison: the backup must exist in both languages.
- Data-loss risk is low (removal requires the bytes to match a harness copy), but the plan states the guarantee, and the implementers copy the code verbatim.

### RC-2 (code, B3 and B6): an unreadable manifest gives two `claude rules` rows
- **Where**: B3 lines "`if ! manifest_out=$(read_rules_manifest ...)` -> `write_summary ERROR "claude rules" "cannot read rules manifest"`" and the B6 twin.
- **Evidence**: `ERRORS_BEFORE_RULES=$ERRORS` / `$errorsBefore = $errors` is set after the manifest step. Once the fan-out has run, `deploy_tracker_summary` therefore writes `OK|claude rules|N added`, alongside the earlier `ERROR|claude rules|cannot read rules manifest`. The contract table in section 3 lists both rows without saying they co-exist. No test covers this case: the matrix has no "unreadable manifest" row.
- **Required change** (either option):
  - (a) Take the error snapshot before the manifest read, so the final row becomes `ERROR validation failed`.
  - (b) Keep one row: record the manifest failure as a tracker `failed` named `.aitools-rules-manifest`.
- Either way, add a `manifest-unreadable` case (`chmod 000` on the manifest, guarded like `unreadable`) to `tests/rules-fanout`, with parity.

### RC-3 (decision gate, before Batch B's PR merges): Q1 / R1 needs the commander's explicit answer
- The plan implements D5 and fans out all 26 aitools `.claude/rules` files into `~/.claude/rules`. I re-counted: 17 of the 26 have no `paths:` frontmatter, 75,475 bytes. With `shared/rules/scratch.md` that matches the plan's roughly 79 KB, about 20k tokens loaded in every session in every repo.
- Many of those rules are written "(this repo)". `sources-of-truth.md` would then mark any repo's `plans/*.md`, `CLAUDE.md` and `ROADMAP.md` as protected, and `script-standards.md` would govern scripts everywhere. Inside aitools, every rule would load twice.
- The decision was the commander's (D5). The plan does surface it (Q1, plus a costed variant). The PR body must still carry the commander's recorded answer, because the change is visible in every repo the day #106 and this PR land.

## Non-blocking findings

1. **Hidden `.md` files are excluded beyond D1.** `rule_name_kind` returns `hidden` for a leading dot and the fan-out skips it (test "fanout: ... hidden ... skipped"). D1 says "*.md only, skipping *.bak.*". It does not exclude hidden files. This is harmless today: the manifest is not `*.md`, and the bash glob skips dot files anyway. Record the commander's confirmation, or fan out `.x.md`.
2. **The Windows-native `.ps1` run has no CI.** check.yml has a `windows-2022` job that already runs pwsh suites (`check.yml:361`, `:429-445` on #112). The plan defers a native step (F4). All `.ps1` fan-out logic is exercised only on macOS pwsh with the OS guard patched off. Native Windows paths, `ResolveLinkTarget`, hidden attributes and `$env:USERPROFILE` are never run. Given "Windows is first-class", I recommend a small pwsh-only test in Batch D rather than F4.
3. **A retired name's case on a case-sensitive file system.** B3 checks `$RULES_DEST/$rm_name` in the manifest's case. On Linux, a deployed `Gone.md` with manifest name `gone.md` is not pruned and not warned about; it is counted `preserved`. This is the same in .ps1. Edge case. No test covers it.
4. **A dotprofile row in the rules draft contradicts first-source-wins.** `.claude/rules/managed-file-deployment.md` "Content sources" still says the dotprofile is "Primary (wins if present)" for "user rules". Under deploy-harness, `shared/` and `.claude/` win a name conflict over the dotprofile. The draft changes only the "Rules" bullet. Add this row to the same draft, and to its `.mdc` twin.
5. **Vocabulary.** deploy-harness's DETAIL rows say `retired: rules/<name>` (#100 `deploy-harness.sh:467`); the fan-out says `removed: <name>`. Q7's `/glossary` filing should cover both words.
6. **Overlap with the BUILD-PKG mission.**
   - BP-6 (now on main, `S3-BuildPkg-decisions.md`) runs dev-path scripts from a read-only payload with "adopt disabled". The payload contains `scripts/aitools-lib.sh` and `shared/claude-shared.md`, so B2/B7 would treat the payload as the aitools checkout and offer adopt into it, unless package mode disables adopt in the lib.
   - BP-10 adds lib functions and changes setup-user-* scripts.
   - Both missions should state who owns `aitools-lib.*` and `setup-user-claude.*` and in which order they land.
7. **Merge order: the plan is right, with one environmental conflict.** `git merge-tree` of #112 with #116 conflicts in `.github/workflows/check.yml` on its own, independent of this plan. The plan's D1/D2 re-pin instruction covers it. Every other combination merges cleanly, and every old_string applies exactly once on #112 merged with each of #111, #113, #115, #100, #106 and #110 (C11b instead of C11 on #111; table below).
8. **Test gaps** besides RC-1 and RC-2: no case for "cannot create rules dir", for a case-differing retired name, or for the dotprofile resolver error (`URP_RC=3`, behaviour unchanged).
9. **One draft OLD block cannot be checked.** `reference/harness.md` OLD 2 is "#100 draft text", which is on no branch. I could not verify it.
10. **Interaction note, not a defect.** Inside aitools, adopting a source-`aitools` rule writes a protected `.claude/rules/*.md` in the working tree (the lib WARNs). This matches agentic-standards.md "Adopting into a protected file is allowed".

## What I verified

**Old_strings** (`.scratch/session-review/oldstr-check.pl`): I extracted every `old_string (X)` block from the plan and counted exact occurrences, with CRLF normalized, in `git show <ref>:<file>`. Results:

| ids | main 568fb5b | #103 | #112 | #116 | #111 | #110 | #113 | #115 | #106 | #100 |
|---|---|---|---|---|---|---|---|---|---|---|
| A1-A4 (lib.sh x2, lib.ps1 x2) | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| B1, B2, B4, B5, B7 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| B3 (.sh), B6 (.ps1) | 0 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 0 |
| C1-C10 (build-deploy.sh) | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| C11 | 1 | 1 | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 |
| C11b | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| C12 | NA | NA | 1 | NA | NA | NA | NA | NA | NA | NA |
| C13, C14 (README) | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| D1, D2 (check.yml) | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

On the merged trees #112+#111, +#113, +#115, +#100, +#106 and +#110, every id is 1, except C11 = 0 and C11b = 1 on #112+#111. This matches every claim the plan makes about bases, and covers all 29 old_strings (4 in .ps1 for A/B, 12 in build-deploy.sh).

**Full application and tests.** I exported #112 (`git archive`) to `.scratch/session-review/t112`, applied all pairs except C11b with `apply-plan.pl` (exact-one check; CRLF used for the CRLF .ps1 files; all 27 applied), and copied the draft test in. Each run used `HOME` and `AITOOLS_LOG_DIR` under `.scratch/session-review/home`:
- `bash tests/rules-fanout/test-rules-fanout.sh` (bash 5 + pwsh): **89 passed, 0 failed, 1 skipped** (dupcase, APFS). The pty adopt and abort cases ran: 16 PASS lines.
- `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/rules-fanout/test-rules-fanout.sh --bash-only`: **37/0/16**.
- `bash tests/claude-mdm/test-claude-mdm.sh` (includes C12 and a build-deploy run on a fixture dotprofile): **35/0/0**.
- `bash tests/managed-files/test-managed-files.sh`: **57/0/0**.
- `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`: **78/0/1**.
- `bash tests/deploy-harness/test-deploy-harness.sh`: **45/0/0**.
- After C, the only rules mentions left in `build-deploy.sh` are comments, the markers and the deploy-harness sections. There is no `USER_RULE`, `EMBED_DIR/rules` or `aitoolsEmbedRules`.
- Probe `probe-bracket-retired.sh` gave RC-1.

**Code read**, with the lib contracts checked on #112:
- `deploy_managed_file` honours `DRY_RUN` (`aitools-lib.sh:1916-1930`), so the dry-run fan-out writes nothing.
- `backup_file` sets `BACKUP_FILE_OK` (`:889-916`).
- `tty_interactive` checks `[ -t 0 ]` (`:1462-1467`), so the fd-3 loop design is correct.
- `write_summary` promotes OK to WARN after any warning (`:860-869`), which explains the WARN rows in the matrix.
- `_managed_abort` exits 2 (`:956-959`).
- `SCRIPT_DIR` (setup-user-claude.sh:46) and `$claudeScriptDir` (B5, after `$claudeMd`) both lie in the span build-deploy extracts (END preamble to BEGIN rules deployment), so the MDM copy has them.
- The lib helper bodies (`lower_name`, `in_list`, `read_rules_manifest`, `Read-RulesManifest`) are byte-identical to #110's `setup-user-cursor.sh:498-554` and `.ps1:502-528`.
- The lib's new names collide with nothing in scripts/, shared/ or tests/ (grep).
- The check-post-push step 31 regexes (`check-post-push.sh:802-803`) do not pick up `*)` or `default`.
- D8 matches #106: `scripts/aitools:1195-1215` (only deploy-harness exit 2 aborts; other scripts get an ERROR row) and `aitools-install.sh:238-242`.
- Retired backups that deploy-harness makes are `<name>.bak.<ts>` in `~/.aitools/rules` (#100 `deploy-harness.sh:447-467`). That is the shape B3/B6 match.
- No check script depends on the embedded rules (grep of check-pre-commit, check-pre-push, check-post-push and check-lib).

**Error-handling audit of the new code**: no `2>/dev/null`, `|| true`, `-ErrorAction SilentlyContinue` or empty catch. Every `log_error` for a write pairs with an ERROR row or a tracker `failed`. Every return value of `deploy_managed_file` is handled at the call site, and `*)` / `default` map to `failed`. The only gaps are RC-1 and RC-2.

**Protected-file drafts** (`draft-old-check.pl`): every OLD block matches exactly once on its stated base:
- the deploy-paths .md/.mdc on #99 only;
- user-repo OLD 2 and 4 on #101 only;
- the rest on main, #99, #101 and #100 alike;
- harness.md OLD 2 (#100 draft) on none: not verifiable.

**Coverage against the order**: setup-user-claude.sh/.ps1 (B), the build-deploy MDM counterpart (C), `tests/rules-fanout` (D), CI for macOS and Linux (D1/D2), and docs (drafts plus README) are all covered. Nothing the decisions require is deferred, except a native Windows CI step (non-blocking 2).

## What I did not verify
- Windows native; Linux (so the dupcase case never ran); real CI.
- `check-pre-commit.sh` / `check-pre-push.sh` on the edited tree (the export is not the fanplan worktree).
- `tests/managed-files/test-managed-files.ps1`, `test-adopt-push.sh/.ps1`, `tests/deploy-harness-mdm`, `tests/profile/test-lib.sh` on the edited tree.
- The Claude Code memory-docs claims (R1, draft item #28).
- The #100 draft text behind harness.md OLD 2.
- Any combination of three or more PRs merged together.

## INCIDENT markers (not filed)
- INCIDENT: `Backup-File` in `scripts/aitools-lib.ps1` uses wildcard `Test-Path` / `Copy-Item -Path`, while every caller passes a literal path. For a name with `[` `]` it skips the backup, and `$script:BackupFileOk` stays `$true`. Callers that gate a write or removal on that flag proceed without a backup. Bash `backup_file` handles the same name. Spec: config-file-safety.md "A merge or copy without backup is a bug". (RC-1 evidence.)
- INCIDENT: `.claude/rules/managed-file-deployment.md` "Content sources" calls the dotprofile "Primary (wins if present)" for user rules, which contradicts deploy-harness's first-source-wins order (`shared/`, `.claude/`, dotprofile) stated in the row below it. (Non-blocking 4.)

## Scratch artifacts
`/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/.scratch/session-review/`: `oldstr-check.pl`, `apply-plan.pl`, `export-tree.sh`, `merge-sim.sh`, `draft-old-check.pl`, `draft-old-all.sh`, `probe-bracket-retired.sh`, `t112/` (the edited export), and `run-*.log`.
