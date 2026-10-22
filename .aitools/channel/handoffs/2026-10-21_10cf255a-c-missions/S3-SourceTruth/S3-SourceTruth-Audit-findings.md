# S3-SourceTruth-Audit -- findings on S3-SourceTruth-plan.md

Reviewer: S3-SourceTruth-Audit (independent, review only). Date 2026-10-22 UTC, macOS.
Scratch: `.scratch/session-S3STAud/` (dryrun.sh, dryrun-lf.sh, steps.sh, func.sh, inter.sh, runpty.py, parse.ps1).
Re-reviewed after the mid-review plan update (D-TS13 reversed: no abort marker; edits/libsh-01 added). Marker findings dropped as instructed.

## Verdict

**Ready after fixes.** The library design matches the approved model and the code behaves as specified in every bash probe I ran. One blocker is mechanical: the apply tools fail on every PS1 file in the real worktree because those files are CRLF on disk. Fix that before B2/B4/B5. Two contract points conflict with existing protected text or are undecided (M1, M3).

## Findings (by severity)

### HIGH

**H1. The apply tools break on CRLF PS1 files in the real worktree.**
- Evidence: `git ls-files --eol` shows `i/lf w/crlf attr/text eol=crlf` for scripts/aitools-lib.ps1, setup-user-{claude,skills,hooks}.ps1 and check-post-push.ps1. The `.old`/`.new` files and blocks are LF.
- `dryrun.sh` on the worktree files: `claude-ps1-01.old: expected exactly 1 occurrence ... found 0`. The same failure hits skills-ps1-01, hooks-ps1-01 and cpp-ps1-01. Every bash edit applied.
- `apply-lib.pl` on aitools-lib.ps1 "succeeds", because the anchors `^\}\s*$` match `}\r`. It then splices LF blocks into a CRLF file, so the working tree ends up with mixed line endings.
- The plan's section 1 dry runs used `git show db4b3c5:<file>` copies (LF), which hides this. On LF copies (`dryrun-lf.sh`) every PS1 edit applies and parses.
- Fix: in both tools, detect CRLF in the target and convert the block, `.old` and `.new` text to CRLF before matching and writing. Alternatively, strip CR on read and write CRLF back for files with `eol=crlf`. Then assert that the output uses one line-ending style. The B2/B4/B5 verify steps should run on the worktree file, not a `git show` copy.

### MEDIUM

**M1. Contract #8 (a failed backup fails the step) conflicts with protected text.**
- `.claude/rules/config-file-safety.md` "Backup before overwrite" says: "Backup failures are non-fatal (warn and proceed) -- a failed backup should not block deployment."
- The SpecRewrite draft `reference/managed-file-deployment.md:579` says "Failure to back up: Non-fatal (warn and proceed)".
- The code (sh-A `_managed_write` lines ~106-116; ps1-A Write-ManagedFiles) makes it fatal. The SpecRewrite report Q13 suggests exactly this, but the decision is still open.
- Fix: get the commander's decision on Q13. Then ship protected-file drafts (config-file-safety.md and the reference Backup Policy) that scope the exception to `deploy_managed_file` / `review_json_fields`.

**M2. A corrupt LOCAL JSON is permanent: every run fails, including non-interactive runs.**
- Evidence: `func.sh` probe 5: `Failed: bad.json: field comparison failed (node exit 3): ... is not valid JSON`, result `failed`.
- review-json.js `readJson` throws, and `review_json_fields` returns `failed`. Nothing ever repairs the file.
- `config-file-safety.md` "Empty catch anti-pattern" says to distinguish missing from corrupt, then warn and start fresh.
- Latent today: no caller deploys a `.json` through `deploy_managed_file` (hooks-manifest.json lists only .sh/.py; skills and rules are .md).
- Fix: treat an unparsable LOCAL as one root-level difference, so the review offers overwrite and a non-interactive run overwrites it (backup kept). Or document the behaviour and add a test.

**M3. CLAUDE.md adopt target when the dotprofile has no template is undecided.**
- In claude-sh-02 / claude-ps1-02, `ADOPT_PATH=$USER_REPO_PATH/claude/CLAUDE.md` is passed whenever USER_REPO_PATH is set.
- `setup-user-claude.sh:76-90` falls back to `shared/claude-shared.md` when that file does not exist. In that case adopt creates a new dotprofile template, which is not "the repo file SOURCE comes from" (mfchoices agentic-standards.md, "Adopt and merge write the repo immediately").
- The behaviour may be what the commander wants, but it is not listed in section 6.
- Fix: either pass the adopt path only when `SOURCE_LABEL="user repo"`, or add this as contract item 13 for a decision.

**M4. The bash failed-merge ERROR always says "unknown error".**
- Evidence: pty probe, no AI CLI on PATH: `Failed: r.md: AI merge failed (iteration 1): unknown error -- nothing written`.
- Cause: in sh-F line 60, `merged=$(... | invoke_ai ...)` runs invoke_ai in a subshell, so the `AI_REJECT_REASON` it sets ("No AI CLI available", validation reason) never reaches `MANAGED_MERGE_ERROR`.
- PS1 keeps the reason (`$merged = $promptText | Invoke-AI`, no subshell), so the two languages diverge.
- This was pre-existing (main :856), but it is now the logged reason for an ERROR row.
- Fix: have invoke_ai also write the reason to a temp file named by the caller, or capture stdout to a file instead of using `$(...)`.

### LOW

- **L1. Adopt-target backups land untracked in repo working trees.**
  - Paths affected: `shared/skills/<n>/SKILL.md.bak.<ts>`, `shared/hooks/*.bak.*`, `scripts/ait-harvest.py.bak.*`, dotprofile `claude/rules/*.md.bak.*` and `claude/CLAUDE.md.bak.*`.
  - `git check-ignore` returns exit 1 for all three aitools paths tested.
  - The hooks and CLAUDE.md adopt paths already did this on main; rules and skills are new.
  - Fix: gitignore `*.bak.*` in both repos, or skip the rotated backup for an adopt target inside a git work tree (the snapshot and restore still cover failures).
- **L2. Unknown keys mean overwrite.** In the text menu, `a`/`m` when adopt is not offered, or any typo, overwrites (sh-B `*)`, ps1-B `default`). Same as main; noted only.
- **L3. The CLAUDE.md filters differ between bash and PS1.**
  - PS1 `IndexOf("`n## Machine-Specific")` misses a heading on line 1, where bash `^## Machine-Specific` matches.
  - PS1 `TrimEnd()` also strips trailing spaces and tabs, while bash `s/\n+\z//` strips only newlines.
  - Fix: use a `(?m)^## Machine-Specific` regex and `TrimEnd("`r","`n")`.
- **L4. The JSON rewrite reformats LOCAL.** review-json.js:133 writes 2-space `JSON.stringify` output, and JS moves integer-like keys first, so "key order preserved" has that exception. Document it.
- **L5. Spec drafts are out of date after the D-TS13 reversal.** SpecRewrite drafts (reference env-var table, interactive-menus Abort section; report line 16 "+ AITOOLS_ABORT_FILE") still describe the abort marker. Outside this plan, but the PR should not ship both.
- **L6. Write failures inside the helpers can be silent.** Every `_managed_write` call is in an `if`, so errexit is off inside it. If `: > "$snapdir/e$i"` (sh-A ~line 118) fails silently, a partially created new file would not be removed on restore. Very unlikely (fresh mktemp dir). Fix: `if ! : > ...; then MANAGED_WRITE_ERROR=...; return 1; fi`.
- **L7. Large merge previews can abort the script.** sh-F:77 `printf | head -30 | while` under pipefail can SIGPIPE when the merge exceeds the pipe buffer, which aborts under set -e. Pre-existing (main :870).
- **L8. EOF warning text changed.** sh-E `read_tty_choice` default text changed from "overwrite from X" to "overwriting from X". This only changes the sync_managed_json EOF warning wording.

## Verified (with evidence)

**Library ranges**
- spec-sh.tsv and spec-ps1.tsv replace only the intended functions. Checked against the `^function`/`name()` listings of HEAD; adopt_managed_file, Backup-Dir, Sync-ManagedJson and the merge prompt builders are untouched.
- Outside the two libs and check-post-push step 28, no reference to the removed helpers remains (`grep-removed.sh`; only incidents.json text mentions them).

**Syntax**
- `bash -n` and `/bin/bash -n` (3.2) pass on all six bash files after the edits.
- The pwsh ParseFile check passes on all five PS1 files (LF copies, and the CRLF/mixed lib).

**check-post-push on the post-plan libs** (`steps.sh`)
- Step 29: PASS (`a,m,n,o,s,x` on both sides).
- Step 30: all of `created,failed,skipped,updated,verified` present in setup-user-claude.sh.
- Step 31: PASS (results `created,failed,skipped,updated,verified`; trackers `added,created,failed,preserved,skipped,updated,verified`).
- Note: these regexes cannot see `"accept & adopt"` (space). The full sets do match: `accept & adopt,created,failed,skipped,updated,verified` in both libs.

**build-deploy**
- No edit adds a line matching `source.*aitools-lib\.sh` or `aitools-lib\.ps1` (grep over edits/: none). The lib text itself is not rescanned by inline_lib_*.
- claude-sh-02 keeps the `BEGIN/END post-write validation` sentinels.
- The extracted rules logic uses `${USER_REPO_PATH:-}`, so the MDM path has no adopt target.

**Bash functional probes** (`func.sh`, isolated HOME, stdin /dev/null)
- created, verified, and non-interactive overwrite (backup kept).
- New file in a read-only directory: `failed`, nothing left behind.
- `_managed_write` with an unwritable adopt target: rc=1, LOCAL restored to `orig`.
- JSON: differ fields overwritten, local-only `l` kept, source-only `s` appended, key order kept.
- Root-level array overwritten.
- libsh-01 `_merge_validate` now rejects output.

**Interactive probes** (`runpty.py`/`inter.sh`, under a pty)
- CLAUDE.md `[a]` with the adopt filter: the template gets the tokens back and the next run is `verified`.
- `[m]` with no AI CLI: `failed`, LOCAL and repo unchanged.

**Code reading**
- PS1 return values are not polluted: Log uses Write-Host, LogDetail writes to the file, `List.Add` returns void, and node output is captured into variables.
- review-json.js argv indices match both callers.
- Plan lines never have an empty field (`disp` returns `(absent)`), so the bash `IFS=$'\t'` whitespace collapse cannot shift columns.

## Not checked

- Windows runtime (Git Bash, Windows pwsh).
- PS1 library functions run under macOS pwsh (parse only).
- The interactive JSON field prompts.
- `[m]` with a stub `claude` accepting a merge.
- A full build-deploy run under a fake dotprofile.
- tests/managed-files/ (untracked, batch B6).
- check-pre-commit / check-pre-push.

## INCIDENT markers (pre-existing, outside the plan)

- INCIDENT: bash merge failure reason lost to a subshell (M4), present on main at scripts/aitools-lib.sh:847/856.
