# S3-FanPlan-Lib findings: aitools-lib deploy primitives for the ~/.aitools/rules fan-out

Explorer S3-FanPlan-Lib (level 2, delegated by S3-FanPlan). 2026-10-26. Read only;
no repo file changed. Reading copy: `/Users/new-jose/repos/aitools/.claude/worktrees/fanplan`
at 480b901 (= origin/main). Line numbers below are main @ 480b901 unless a PR is named.

## 1. Summary (5 lines)

1. The lib has everything a per-file fan-out needs (`deploy_managed_file` / `Deploy-ManagedFile`, the deploy tracker, `backup_file` / `backup_dir`, `write_summary`, `_managed_abort` exit 2), and **no** rules-directory, manifest or remove helper: the Cursor fan-out (setup-user-cursor step 4) and deploy-harness's retire code are inline, and PR #110 / #100 add two more inline remove implementations.
2. The tracker has no `removed` outcome, and `deploy_tracker_record` / `Record-DeployOutcome` **silently ignore any unknown outcome** (no default branch) -- adding `removed` touches 3 lib functions per language plus check-post-push step 31's parity regexes; it is a tracker outcome, not a `Deploy-ManagedFile` return value, unless a lib `remove_managed_file` is added.
3. The case-sensitivity defect lives in **deploy-harness** (`add_source`: .sh `case *.md` / `*.bak.*` case-sensitive, .ps1 `-like` / `-notlike` case-insensitive) and in **setup-user-claude** (.sh glob `*.md` vs .ps1 `-Filter "*.md"`); setup-user-cursor is case-sensitive in both languages (`case` / `-clike`). Probed on macOS: bash glob/case/find miss `FOO.MD`; pwsh `-Filter` and `-like` match it, `-clike` does not.
4. Adopt into the dotprofile commits + pushes only after PR #103 (lib `dotprofile_commit_push` / `Invoke-DotprofileCommitPush`, decided by git top level); on main the lib never commits and only setup-user-claude's rules loop commits, and only after **merge** & adopt. For a rule copied from `~/.aitools/rules`, the adopt target must be the original repo source, which only PR #100's rules manifest records (`shared` -> `<aitools>/shared/rules/<n>`, `aitools` -> `<aitools>/.claude/rules/<n>`, `dotprofile` -> `<dotprofile>/claude/rules/<n>`).
5. Two traps for the planner: (a) a bash deploy loop written `while read ...; done <<< "$LIST"` makes stdin the here-string, so `tty_interactive` is false and every differing file is silently auto-overwritten with a warning (setup-user-cursor.sh:534-582 does this today; probe confirmed) -- use fd 3; (b) `[x]abort` is a bare `exit 2` from inside the lib that skips the caller's tracker summary row, so it must never run in a subshell.

## 2. Files read

Read in full:
- `scripts/aitools-lib.sh` (3047 lines)
- `scripts/aitools-lib.ps1` (3192 lines)
- `reference/managed-file-deployment.md` (699)
- `reference/framework-managed-file-deployment.md` (53)
- `tests/managed-files/test-managed-files.sh` (349), `test-managed-files.ps1` (258), `pty-run.py` (100)
- Mission packet, explorer brief; rules in context: every `.claude/rules/*.md` listed in the packet (main checkout = worktree HEAD 480b901, so identical), user CLAUDE.md, concurrent-agents.md, delegation.md.

Read in part (for questions c, d, e, f):
- `scripts/setup-user-cursor.sh` 370-669, `setup-user-cursor.ps1` 370-629 (step 4 fan-out)
- `scripts/deploy-harness.sh` 195-344 (add_source, deploy_one); `deploy-harness.ps1` grep of filters (193, 198, 333)
- `scripts/setup-user-claude.sh` / `.ps1`: grep of the rules section (sh 288-429, ps1 306-461) -- the slice of S3-FanPlan-Claude
- `scripts/check-post-push.sh` 744-818 (steps 29-31); `scripts/build-deploy.sh` grep of `inline_lib_*`
- PR #103 diff: lib (.ps1 353-515, .sh 516-656) and setup-user-claude hunks (657-733), read fully; body read
- PR #115 diff: bash lib hunks 1455-1746 (includes #113's runner change; #115 is stacked on #113 on #103); bodies of #113, #115 read. **Not read line by line: the .ps1 lib hunks of #113/#115** (1105-1455 of the #115 diff).
- PR #100 and #110: grep of their diffs for manifest / remove / filter code (other slices own them).

Not read (deviation, stated): `plans/tool-support-and-machine-profile.md`, prior handoff `2026-10-21_360aa8f3-8.md`, and the reference subset `script-standards-detail.md`, `cross-platform-detail.md`, `logging.md`, `plan-execution-detail.md`. Nothing in this slice depended on them; the planner should not treat this file as having checked against them.

Scratch (probes, diffs): `/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/.scratch/session-lib/` (`probe-filter.sh/.ps1`, `probe-herestring.sh` + `.out`, `pr100.diff`, `pr103.diff`, `pr110.diff`, `pr113.diff`, `pr115.diff`).

## 3. Current behaviour, with verbatim code

### 3.1 deploy_managed_file / Deploy-ManagedFile contract (question a)

bash, `scripts/aitools-lib.sh:1768-1798` (signature block, verbatim):

```bash
# ---------------------------------------------------------------------------
# Deploy one managed file. SOURCE is the source of truth ("Review choices"
# above prompt_diff_review). Parity: Deploy-ManagedFile in aitools-lib.ps1.
#
# Args:
#   $1 = SRC_CONTENT   content to deploy (SOURCE)
#   $2 = DEST          deployed path (LOCAL). A name ending in .json is
#                      reviewed field by field (review_json_fields).
#   $3 = TOOL_NAME     summary tool name (e.g. "claude rules")
#   $4 = ITEM_NAME     item name for log lines (e.g. "concurrent-agents.md")
#   $5 = ADOPT_PATH    absolute path of the repo file that is the source of
#                      truth; "" = adopt and merge are not offered
#   $6 = ADOPT_FILTER  optional, text files only: name of a function that
#                      reads LOCAL content on stdin and prints the content the
#                      adopt target gets (CLAUDE.md strips its machine footer
#                      and restores profile tokens). "" = plain copy.
#
# Sets MANAGED_FILE_RESULT to "created", "updated", "verified",
# "accept & adopt", "skipped" or "failed". On "failed" nothing is left
# half-written (snapshots restored) and the reason is logged with log_error;
# the caller records the outcome (deploy_tracker_record, or its own ERROR
# row). Exits 2 on [x]abort. Honors DRY_RUN (reports, writes nothing).
# ---------------------------------------------------------------------------
MANAGED_FILE_RESULT=""
deploy_managed_file() {
    local src_content="$1"
    local dest="$2"
    local tool_name="$3"
    local item_name="$4"
    local adopt_path="${5:-}"
    local adopt_filter="${6:-}"
```

PowerShell, `scripts/aitools-lib.ps1:1737-1763`:

```powershell
# Params:
#   -Content      content to deploy (SOURCE)
#   -DestPath     deployed path (LOCAL). A name ending in .json is reviewed
#                 field by field (Review-JsonFields).
#   -ToolName     summary tool name (e.g. "claude rules")
#   -ItemName     item name for log lines (e.g. "concurrent-agents.md")
#   -AdoptPath    absolute path of the repo file that is the source of truth;
#                 "" = adopt and merge are not offered
#   -AdoptFilter  optional, text files only: scriptblock that takes LOCAL
#                 content and returns the content the adopt target gets
#                 (e.g. CLAUDE.md strips its machine footer). $null = copy.
#
# Returns "created", "updated", "verified", "accept & adopt", "skipped" or
# "failed". On "failed" nothing is left half-written (snapshots restored) and
# the reason is logged with LogError; the caller records the outcome
# (Record-DeployOutcome, or its own ERROR row). Exits 2 on [x]abort.
# Honors $DryRun (reports, writes nothing).
# ---------------------------------------------------------------------------
function Deploy-ManagedFile {
    param(
        [string]$Content,
        [string]$DestPath,
        [string]$ToolName,
        [string]$ItemName,
        [string]$AdoptPath = "",
        [scriptblock]$AdoptFilter = $null
    )
```

Flow (both languages, sh 1792-1918, ps1 1755-1891):
- trailing newlines normalized (`perl -0777 -pe 's/[\r\n]+$/\n/'` / `-replace '[\r\n]+$', ''`); compare is exact and case-sensitive (`=` / `-ceq`).
- `DRY_RUN=true` / `$DryRun`: logs `[DRY RUN] Unchanged|Would update|Would create`, result `verified` (sh: the initial value; ps1 `return "verified"`).
- DEST `*.json` -> `review_json_fields` / `Review-JsonFields` (sh `case *.json` is case-sensitive; ps1 `-like '*.json'` is not -- irrelevant for `*.md` rules).
- LOCAL missing -> `_managed_write` / `Write-ManagedFiles` -> `created`; LOCAL == SOURCE -> `verified` (no backup, test-managed-files.sh:107).
- differs -> `prompt_diff_review` / `Prompt-DiffReview` (adopt offered only when ADOPT_PATH non-empty). Non-terminal, EOF, `AITOOLS_FORCE=1`, bash `FORCE=true`, ps1 `$Force` -> `overwrite` with a `log_warn "Diff in ... -- overwriting (non-interactive|--force)"` (sh 1647-1656, ps1 1602-1611). That log_warn increments WARNINGS, so any non-interactive update promotes the caller's later OK rows to WARN (write_summary sh 864, ps1 755).
- `adopt`: LOCAL not written; adopt target gets LOCAL (through ADOPT_FILTER if given). `merge`: both get the merge. Then `_managed_adopt_notice` / `Write-ManagedAdoptNotice` (protected-file WARN + "Uncommitted change in <repo>" log). Result `accept & adopt`.
- Every write goes through `_managed_write` (sh 1035-1128) / `Write-ManagedFiles` (ps1 946-1072): snapshot + `backup_file` each existing file (a failed backup fails the step, nothing written), write with one trailing newline, validate non-empty (+ JSON keys), restore on failure. Callers never back up a single managed file themselves.
- `failed` is logged with `log_error` by the lib (ERRORS++); the caller only records it.

Caller-scope variables the lib reads (must exist in the fan-out script): bash `DRY_RUN`, `FORCE`, `AITOOLS_FORCE`, `AITOOLS_SUMMARY_FILE`, `HOME`; ps1 `$DryRun`, `$Force` (dynamic scope), `$env:AITOOLS_FORCE`, `$env:AITOOLS_SUMMARY_FILE`.

Spec drift (see INCIDENT 1): `reference/managed-file-deployment.md:48-73` documents
`deploy_managed_file SRC_CONTENT DEST TOOL_NAME ITEM_NAME [ADOPT_PATH]` + "reads ADOPT_TRANSFORM when set" and `-AdoptTransform`; the code takes a positional 6th arg `ADOPT_FILTER` and `-AdoptFilter`. Use the code's names.

Adopt filter is the only "adopt transform" in use: setup-user-claude `claude_md_adopt_filter` (sh 187) / `$claudeMdAdoptFilter` (ps1 194). Rules need none (plain copy).

### 3.2 Deploy tracker: outcome set (question b)

bash `scripts/aitools-lib.sh:2263-2321` (verbatim):

```bash
# ---------------------------------------------------------------------------
# Deploy tracker: centralizes outcome counting and summary writing for
# loops that deploy multiple managed files (rules, skills, hooks).
# ---------------------------------------------------------------------------

# Reset all deploy tracker counters. Call before a deploy loop.
_DT_ADDED=0; _DT_UPDATED=0; _DT_VERIFIED=0
_DT_ACCEPTED=0; _DT_SKIPPED=0; _DT_PRESERVED=0; _DT_FAILED=0
DEPLOY_TRACKER_TEXT=""

deploy_tracker_init() {
    _DT_ADDED=0; _DT_UPDATED=0; _DT_VERIFIED=0
    _DT_ACCEPTED=0; _DT_SKIPPED=0; _DT_PRESERVED=0; _DT_FAILED=0
    DEPLOY_TRACKER_TEXT=""
}

# Record a single file outcome. Increments counter and writes DETAIL summary.
# Args: $1=outcome $2=tool_name $3=item_name
deploy_tracker_record() {
    local outcome="$1" tool_name="$2" item_name="$3"
    case "$outcome" in
        added|created) _DT_ADDED=$((_DT_ADDED + 1))
                   write_summary DETAIL "$tool_name" "added: $item_name" ;;
        updated)   _DT_UPDATED=$((_DT_UPDATED + 1))
                   write_summary DETAIL "$tool_name" "updated: $item_name" ;;
        "accept & adopt") _DT_ACCEPTED=$((_DT_ACCEPTED + 1))
                       write_summary DETAIL "$tool_name" "accept & adopt: $item_name" ;;
        skipped)   _DT_SKIPPED=$((_DT_SKIPPED + 1))
                   write_summary DETAIL "$tool_name" "skipped: $item_name" ;;
        failed)    _DT_FAILED=$((_DT_FAILED + 1))
                   write_summary DETAIL "$tool_name" "failed: $item_name" ;;
        verified)  _DT_VERIFIED=$((_DT_VERIFIED + 1)) ;;
        preserved) _DT_PRESERVED=$((_DT_PRESERVED + 1)) ;;
    esac
}

# Write aggregate summary for a deploy loop. Uses non-zero counts.
# ERROR when any file failed, WARN when any was skipped, else OK.
# Sets DEPLOY_TRACKER_TEXT for use in log lines.
# Args: $1=tool_name
deploy_tracker_summary() {
    local tool_name="$1"
    local parts=""
    if [ "$_DT_ADDED" -gt 0 ];    then parts="$_DT_ADDED added"; fi
    if [ "$_DT_UPDATED" -gt 0 ];  then parts="${parts:+$parts, }$_DT_UPDATED updated"; fi
    if [ "$_DT_ACCEPTED" -gt 0 ]; then parts="${parts:+$parts, }$_DT_ACCEPTED accepted"; fi
    if [ "$_DT_VERIFIED" -gt 0 ]; then parts="${parts:+$parts, }$_DT_VERIFIED verified"; fi
    if [ "$_DT_FAILED" -gt 0 ];   then parts="${parts:+$parts, }$_DT_FAILED failed"; fi
    if [ -z "$parts" ]; then parts="verified"; fi
    DEPLOY_TRACKER_TEXT="$parts"

    if [ "$_DT_FAILED" -gt 0 ]; then
        write_summary ERROR "$tool_name" "$_DT_FAILED failed"
    elif [ "$_DT_SKIPPED" -gt 0 ]; then
        write_summary WARN "$tool_name" "$_DT_SKIPPED skipped (user review)"
    else
        write_summary OK "$tool_name" "$parts"
    fi
}
```

PowerShell `scripts/aitools-lib.ps1:2257-2306` (verbatim):

```powershell
$script:dtAdded = 0; $script:dtUpdated = 0; $script:dtVerified = 0
$script:dtAccepted = 0; $script:dtSkipped = 0; $script:dtPreserved = 0; $script:dtFailed = 0
$script:deployTrackerText = ""

function Initialize-DeployTracker {
    $script:dtAdded = 0; $script:dtUpdated = 0; $script:dtVerified = 0
    $script:dtAccepted = 0; $script:dtSkipped = 0; $script:dtPreserved = 0; $script:dtFailed = 0
    $script:deployTrackerText = ""
}

# Record a single file outcome. Increments counter and writes DETAIL summary.
function Record-DeployOutcome {
    param([string]$Outcome, [string]$ToolName, [string]$ItemName)
    switch ($Outcome) {
        { $_ -eq "added" -or $_ -eq "created" } { $script:dtAdded++;     Write-Summary "DETAIL" $ToolName "added: $ItemName" }
        "updated"   { $script:dtUpdated++;   Write-Summary "DETAIL" $ToolName "updated: $ItemName" }
        "accept & adopt" { $script:dtAccepted++;  Write-Summary "DETAIL" $ToolName "accept & adopt: $ItemName" }
        "skipped"   { $script:dtSkipped++;   Write-Summary "DETAIL" $ToolName "skipped: $ItemName" }
        "failed"    { $script:dtFailed++;    Write-Summary "DETAIL" $ToolName "failed: $ItemName" }
        "verified"  { $script:dtVerified++ }
        "preserved" { $script:dtPreserved++ }
    }
}

# Write aggregate summary for a deploy loop. Uses non-zero counts.
# ERROR when any file failed, WARN when any was skipped, else OK.
function Write-DeployTrackerSummary {
    param([string]$ToolName)
    $parts = @()
    if ($script:dtAdded -gt 0)     { $parts += "$($script:dtAdded) added" }
    if ($script:dtUpdated -gt 0)   { $parts += "$($script:dtUpdated) updated" }
    if ($script:dtAccepted -gt 0)  { $parts += "$($script:dtAccepted) accepted" }
    if ($script:dtVerified -gt 0)  { $parts += "$($script:dtVerified) verified" }
    if ($script:dtFailed -gt 0)    { $parts += "$($script:dtFailed) failed" }
    $text = if ($parts.Count -gt 0) { $parts -join ", " } else { "verified" }
    $script:deployTrackerText = $text

    if ($script:dtFailed -gt 0) {
        Write-Summary "ERROR" $ToolName "$($script:dtFailed) failed"
    } elseif ($script:dtSkipped -gt 0) {
        Write-Summary "WARN" $ToolName "$($script:dtSkipped) skipped (user review)"
    } else {
        Write-Summary "OK" $ToolName $text
    }
}
```

Facts:
- Outcome set: `added`/`created`, `updated`, `accept & adopt`, `skipped`, `failed`, `verified`, `preserved`. **No `removed`** (confirmed; brief's known defect).
- Unknown outcomes fall through silently in both (no `*)` / `default`): `deploy_tracker_record removed ...` would count nothing and write nothing (INCIDENT 2).
- `preserved` and `skipped` are not in the `parts` text; callers print `$_DT_PRESERVED` / `$script:dtPreserved` themselves (setup-user-claude.sh:417, setup-user-cursor.sh:644).
- One global tracker per process: a script with two loops must call `deploy_tracker_init` between them.
- What adding `removed` requires (proposal, not implemented): (1) `_DT_REMOVED` / `$script:dtRemoved` in the top-level init line and in `deploy_tracker_init` / `Initialize-DeployTracker`; (2) a `removed)` branch with `write_summary DETAIL "$tool_name" "removed: $item_name"` in bash and a `"removed" { ... }` branch in PS1 (both formats are what check-post-push step 31's regexes expect: sh `/^\s+([\w|.-]+)\)\s/`, ps1 `"([\w-]+)"\s*\{`, `scripts/check-post-push.sh:802-803`; keep them identical or step 31 fails); (3) `N removed` in the `parts` text of both summaries; (4) `reference/managed-file-deployment.md` "Functions" / "Return Values" (protected). `interactive-menus.md`'s 4-item list ("function itself, Record-DeployOutcome/deploy_tracker_record, every caller's switch, reference spec") applies in full only if `removed` becomes a `Deploy-ManagedFile` return value, i.e. if a lib remover is added (section 4.2). Then also check-post-push step 30 (`check-post-push.sh:766`, captures `MANAGED_FILE_RESULT="word"`) requires setup-user-claude.sh to contain the literal string `removed`.

### 3.3 backup_file / backup_dir

bash `aitools-lib.sh:889-945`, ps1 `aitools-lib.ps1:780-841`. `backup_file FILE` -> `<file>.bak.<YYYY-MM-DDTHHMMSSZ>`, keeps 20, sets `BACKUP_FILE_OK` / `$script:BackupFileOk`; failure is a warning (non-fatal) except inside `_managed_write`. Main has the -LiteralPath fix (ps1 784-808, commit 9923a3c).

`backup_dir DIR` (bash 921-945):

```bash
backup_dir() {
    local dir="$1" max_backups=5
    [ -d "$dir" ] || return 0
    local file_count
    file_count=$(find "$dir" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
    if [ "$file_count" -eq 0 ]; then
        return 0
    fi
    local ts
    ts=$(date -u +%Y-%m-%dT%H%M%SZ)
    if ! cp -R "$dir" "${dir}.bak.${ts}"; then
        log_warn "Could not back up $(display_path "$dir") -- proceeding without backup"
        return 0
    fi
    local old_backups
    old_backups=$(find "$(dirname "$dir")" -maxdepth 1 -name "$(basename "$dir").bak.*" -type d \
        | sort -r | tail -n +$((max_backups + 1)))
    if [ -n "$old_backups" ]; then
        printf '%s\n' "$old_backups" | while IFS= read -r old_dir; do
            rm -rf "$old_dir"
            log "Pruned old backup: $(display_path "$old_dir")"
        done
    fi
    log "Backed up $(display_path "$dir") ($file_count managed files)"
}
```

Notes: counts only `*.md` (case-sensitive in bash; ps1 `-Filter "*.md"` is case-insensitive on macOS too, probe); a rules dir with only `.mdc` files is never backed up (Cursor dir); `rm -rf` unchecked; ps1 prune uses `Get-ChildItem -Path $parentDir -Filter` and `Remove-Item $_.FullName` without `-LiteralPath` (ps1 832-836). Both are used by setup-user-claude.sh:335 / ps1:363 and setup-user-cursor before their loops. A directory backup of `~/.claude/rules` is in addition to the per-file backups the lib makes; it is the only backup a fan-out **removal** gets unless the remover calls `backup_file`.

### 3.4 write_summary, ACTION, relay

`write_summary CAT TOOL DETAIL` (sh 860-869, ps1 752-761) appends `CAT|TOOL|DETAIL` to `AITOOLS_SUMMARY_FILE`; OK is promoted to WARN when WARNINGS > 0 at that moment. `_aitlib_action_once TEXT` / `Write-AitLibActionOnce` (sh 272-279, ps1 197-211) dedupes ACTION rows per run. `show_summary` / `Show-Summary` dedupe rows by tool (highest severity wins) and print DETAIL rows under their tool (sh 2827-2909, ps1 2917-3021); a `DETAIL|claude rules|removed: x.md` row renders with no code change.

Relay (child scripts): `run_child_relayed LABEL CMD...` (sh 589-621) / `Invoke-ChildRelayed` (ps1 510-531). PR #115 adds `--summary-tool TOOL`: a failed child that wrote no ERROR row of its own gets `ERROR|TOOL|script failed (exit N)`, or `aborted (exit 2)` for exit 2 (#115 diff 1681-1746). No caller passes it yet (FIX-2).

### 3.5 Adopt notice and dotprofile commit/push (question e)

Main, bash `aitools-lib.sh:1004-1015` (verbatim; ps1 twin 905-918):

```bash
# After adopt or merge: the library never commits or pushes. Say that the
# adopt target's repo has an uncommitted change to review, and WARN when the
# target is protected (_managed_protected_note).
_managed_adopt_notice() {
    local target="$1" top
    _managed_protected_note "$target"
    # 2>/dev/null: outside a git repo there is nothing to commit (empty result checked).
    top=$(git -C "$(dirname "$target")" rev-parse --show-toplevel 2>/dev/null) || top=""
    if [ -n "$top" ]; then
        log "Uncommitted change in $(display_path "$top"): $(basename "$target") -- review and commit it (cd $(display_path "$top") && git diff)"
    fi
}
```

On main the only commit/push of an adopted rule is setup-user-claude's private block (sh 367-389, ps1 397-420), gated on `MERGED_CONTENT` / `$script:MergedContent`, so a plain **accept & adopt into the dotprofile is not committed on main** (contradicts `.claude/rules/managed-file-deployment.md` "Adopt target" and N-Q2; PR #103 fixes it). The PS1 block runs `git commit` with no pathspec (commits everything staged), per #103's body.

PR #103 (`fix/mf-dotprofile-adopt-push`, open): adds `dotprofile_commit_push FILE MESSAGE` (bash, #103 diff 554-626) / `Invoke-DotprofileCommitPush -File -Message` (ps1, 393-485), called from `_managed_adopt_notice` / `Write-ManagedAdoptNotice` with message `Adopt <name> from the deployed copy`:

```bash
_managed_adopt_notice() {
    local target="$1" top
    _managed_protected_note "$target"
    dotprofile_commit_push "$target" "Adopt $(basename "$target") from the deployed copy"
    if [ "$AITLIB_DOTPROFILE_PUSH" != "not-dotprofile" ]; then return 0; fi
```

Contract (from the diff): "in the dotprofile" = FILE's git top level equals the dotprofile's git top level; dotprofile = `AITLIB_USER_REPO_PATH` if set (even ""), else a quiet resolver call; pathspec commit `git add -- FILE` + `git commit -m MSG -- FILE`; push with `GIT_TERMINAL_PROMPT=0` and ssh BatchMode; result `AITLIB_DOTPROFILE_PUSH` = committed-pushed | unchanged | commit-failed | push-failed | not-dotprofile; failures are log_warn + ACTION, result stays `accept & adopt`; always returns 0. #103 also deletes setup-user-claude's private commit block (both languages). Applies to every lib adopt (text and JSON field adopt), for any caller.

Adopt target for a fan-out rule: `~/.aitools/rules` is not a git repo and is overwritten by deploy-harness, so it cannot be the adopt target (setup-user-cursor.sh:383-385 states the same and passes `""`). deploy-harness passes the repo source file as its own adopt target (`deploy-harness.sh:309`: `deploy_managed_file "$content" "$dest" "$TOOL" "$item" "$src"`), but the winning source is held only in a temp plan (`$WORK/plan.tsv`) on main. PR #100 (`feature/harness-rules-manifest`) writes `~/.aitools/rules/.aitools-rules-manifest`: header `# aitools rules manifest v1`, then `<name><TAB><source>`, source `shared` (aitools `shared/rules/`), `aitools` (aitools `.claude/rules/`), `dotprofile` (`<dotprofile>/claude/rules/`) or `retired` (#100 diff 69-75, 541-546). That is the only machine-readable record of each rule's original source.

### 3.6 [x]abort / exit 2 (question f)

bash `aitools-lib.sh:953-959`, ps1 `aitools-lib.ps1:849-855` (verbatim):

```bash
# [x]abort: log, then exit 2 (a bare exit 2 means user abort; commander
# decision 2026-10-21, D-TS13 reversed: no marker file). One helper for every
# review prompt. Parity: Invoke-ManagedAbort in aitools-lib.ps1.
_managed_abort() {
    log_error "Aborted by user"
    exit 2
}
```

```powershell
function Invoke-ManagedAbort {
    LogError "Aborted by user"
    exit 2
}
```

Called from `prompt_diff_review` (sh 1759) / `Prompt-DiffReview` (ps1 1722-1724) and `prompt_json_field_review` (sh 2400) / `Prompt-JsonFieldReview` (ps1 2383). Effects for a fan-out loop: the script exits mid-loop; files already processed keep their (atomic) results; no `deploy_tracker_summary` row and no exit footer are written; ERRORS was incremented. The exit only ends the script when `deploy_managed_file` runs in the script's own shell: never call it in `$( )`, a pipeline, or `( )` (deploy-harness.sh:292 comments this). PS1: `exit 2` inside the lib function ends the calling script; under `Invoke-ChildRelayed` (in-process `&`) it returns to the parent with `$LASTEXITCODE` 2 (ps1 514-525). Text menu says `[x]abort : stop this script (exit 2)` (sh 1735, ps1 1692), the JSON field menu says `[x]abort : stop the run` (sh 2376, ps1 2359) -- the latter contradicts the 2026-10-26 decision (abort ends only that script) and `reference/managed-file-deployment.md:164`.

### 3.7 Existing fan-out code (question c)

There is no lib helper for fanning out a directory. setup-user-cursor step 4 is inline (sh 378-653, ps1 372-~640): enumerate `~/.aitools/rules/*` (non-hidden, regular files; dangling symlinks -> `failed`), filter, dedupe by lower-cased destination name, convert, `deploy_managed_file ... ""`, record every outcome, preserved scan, post-write validation, tracker summary. Its filter (sh 491-498, verbatim):

```bash
        case "$rule_base" in
            *.bak.*) continue ;;
            *.md) ;;
            *) log "Ignoring non-rule file in harness rules: $rule_base (only *.md is fanned out)"
               continue ;;
        esac
```

ps1 496-500:

```powershell
            if ($entry.Name -clike "*.bak.*") { continue }
            if (-not ($entry.Name -clike "*.md")) {
                Log "Ignoring non-rule file in harness rules: $($entry.Name) (only *.md is fanned out)"
                continue
            }
```

Its deploy loop feeds the list on stdin (sh 534 + 582):

```bash
        while IFS= read -r rule_src; do
...
            deploy_managed_file "$rule_content" "$CURSOR_RULES_DIR/$dest_name" "cursor rules" "$dest_name" ""
...
        done <<< "$RULE_SOURCES"
```

Probe (`.scratch/session-lib/probe-herestring.sh` on a pty via `tests/managed-files/pty-run.py`): `herestring-loop: notty`, `fd3-loop: tty`. So in the bash Cursor fan-out the review menu never appears; each differing `.mdc` is overwritten with a `[warn] Diff in ... -- overwriting (non-interactive)`. PR #110 keeps this loop (`done <<< "$RULE_SOURCES"`, #110 diff line 1865). deploy-harness (`done 3< "$PLAN"`, read `<&3`) and review_json_fields (`3< "$work/plan.tsv"`) do it correctly. setup-user-claude's current loop is `for rule_file in "$RULES_SRC"/*.md` (no stdin redirect), which is safe.

Reusable pieces that would make sense as lib helpers, since two consumers (Claude, Cursor) and deploy-harness need them: (1) list harness rules + read the #100 manifest (name, source, retired), with the approved filter; (2) remove one managed file with backup and a tracker `removed` outcome; (3) case-insensitive name set (bash 3.2: newline lists + `tr`). PR #110 implements (1)-(2) inline for Cursor (bash #110 diff 1868-1937; ps1 1349-1485, with `N_REMOVED` counters outside the tracker and DETAIL `removed: <f>` rows) and PR #100 implements removal inline for `~/.aitools/rules` (`retire_rule_file`, #100 diff 628-648). build-deploy inlines the **whole** lib into each generated deploy script (`inline_lib_bash` / `inline_lib_ps1`, build-deploy.sh:116-172, used for setup-user-claude at 707 / 803 and setup-user-cursor at 866 / 907), so a new lib helper reaches the MDM path with no build-deploy extraction change.

### 3.8 Case-sensitivity of the rules filter (question d)

| Where | bash | PowerShell |
|---|---|---|
| deploy-harness `add_source` (fills `~/.aitools/rules`) | `deploy-harness.sh:197` `*.bak.*)`, `:207` `*.md)` -- case-sensitive | `deploy-harness.ps1:193` `-like '*.bak.*'`, `:198` `-notlike '*.md'` -- case-insensitive |
| deploy-harness preserved scan | (not read) | `deploy-harness.ps1:333` `-like '*.bak.*'` |
| setup-user-claude rules source | `setup-user-claude.sh:299` `find -name '*.md'`, `:310/:344` glob `"$RULES_SRC"/*.md` -- case-sensitive | `setup-user-claude.ps1:320` `Get-ChildItem -Filter "*.md"` -- case-insensitive (Windows and, by probe, macOS) |
| setup-user-cursor step 4 | sh 493-498 `case` -- case-sensitive | ps1 496-497 `-clike` -- case-sensitive; preserved scan ps1 589 `-like "*.bak.*"` -- insensitive vs sh 595 `case` sensitive |
| lib `backup_dir` count | sh 925 `find -name '*.md'` -- sensitive | ps1 820 `-Filter "*.md"` -- insensitive |

Probe on macOS (pwsh 7.6.3, `.scratch/session-lib/probe-filter.*`), files `FOO.MD`, `bar.md`, `baz.Md.BAK.1`: bash glob / `case` / `find -name` -> `bar.md` only; `case *.bak.*` -> none; pwsh `-Filter "*.md"` and `-like` -> `bar.md,FOO.MD`; `-clike` -> `bar.md`; `-like "*.bak.*"` -> `baz.Md.BAK.1`. The S3-H2-Manifest hand-back already marks the deploy-harness instance as an INCIDENT (#100 diff 266-269, 550). The approved fan-out behaviour is case-insensitive: bash needs a lower-cased copy of the name for the `case` (`tr '[:upper:]' '[:lower:]'`, as setup-user-cursor.sh:474 `lower_name` does), ps1 needs `-like` / `-notlike`.

## 4. What the refactor must change or check in this slice

4.1 Call pattern for the Claude fan-out (no lib change needed for the happy path): per rule,
`deploy_managed_file "$content" "$HOME/.claude/rules/$name" "claude rules" "$name" "$adopt"` / `Deploy-ManagedFile -Content $c -DestPath $d -ToolName "claude rules" -ItemName $n -AdoptPath $adopt`, then `deploy_tracker_record "$MANAGED_FILE_RESULT" ...` / `Record-DeployOutcome`, then `deploy_tracker_summary "claude rules"`. Keep the literal strings `created`, `updated`, `verified`, `skipped`, `failed` in setup-user-claude.sh (check-post-push step 30 greps that file for them, `check-post-push.sh:777-783`). Read content with `$(cat ...)` / `[IO.File]::ReadAllText` (UTF-8); the lib normalizes trailing newlines.

4.2 Removal of retired / no-longer-entitled copies from `~/.claude/rules` (#100 manifest): either inline (as #110 does for Cursor) or a new lib helper, e.g. `remove_managed_file DEST TOOL ITEM` / `Remove-ManagedFile -DestPath -ToolName -ItemName`: refuse non-files, `backup_file` (fail the removal when `BACKUP_FILE_OK != true`), `rm -f` + existence check, `log "Removed ... (backup kept)"`, set `MANAGED_FILE_RESULT=removed|failed`; honour `DRY_RUN`. Plus the tracker changes in 3.2. Suggested: lib helper, because three consumers (deploy-harness #100, Cursor #110, Claude) otherwise carry three copies in two languages each; it needs commander approval since it changes the lib contract and protected spec text.

4.3 Adopt target per rule (from the #100 manifest line): `shared` -> `$REPO_DIR/shared/rules/$name`, `aitools` -> `$REPO_DIR/.claude/rules/$name`, `dotprofile` -> `$USER_REPO_PATH/claude/rules/$name`; `""` when that repo is absent (MDM endpoint: no aitools repo, maybe no dotprofile) or the manifest is missing / not v1. Consequences: a `dotprofile` adopt is committed + pushed (after #103); an `aitools` adopt is a working-tree change with the protected-file WARN (`.claude/rules/*.md` is in sources-of-truth.md:15); a `shared` adopt is a working-tree change with no WARN (shared/rules is not in the table).

4.4 Stale harness copy after adopt: after an accept & adopt in setup-user-claude, `~/.aitools/rules/<name>` still holds the old text. On the next run deploy-harness compares it (LOCAL) with the repo file (SOURCE, now the adopted text) and, on a terminal, shows the review menu, where `[a]ccept & adopt` would write the old text back over the user's adoption. Options: (a) leave it (non-interactive runs resolve it by overwrite); (b) after an adopt, also refresh `~/.aitools/rules/<name>` with a backup and no review -- needs a public lib write helper (today `_managed_write` / `Write-ManagedFiles` are private) ; (c) setup-user-claude deploys from the repo source directly when one exists. Suggested: (b), with a small public wrapper over `_managed_write`, because it keeps the three copies identical in the same run, which the managed-file model promises (reference/managed-file-deployment.md:18-20).

4.5 Filter: implement the approved `*.md`, minus `*.bak.*`, case-insensitive, in both languages; fix deploy-harness `add_source` in the same direction or the harness copy and the fan-out disagree on which files exist (deploy-harness is another slice; flag to S3-FanPlan-Harness).

4.6 Loop shape: bash deploy loops must keep stdin the terminal: `while IFS= read -r x <&3; do ... done 3<<< "$LIST"` (or `3< file`), or a `for` over a glob. Never `done <<< "$LIST"` or `cmd | while`.

## 5. Interactions with open PRs (lib hunks)

- **#103** (open): rewrites `_managed_adopt_notice` / `Write-ManagedAdoptNotice` and the two "Review choices" comment blocks; inserts ~105 lines after sh 1002 and ~127 after ps1 895, so every main line number after those points (tracker, prompts) shifts by that much once it lands; deletes setup-user-claude's commit block (sh 367-389, ps1 397-420) -- the refactor's rules section overlaps this hunk directly. Plan on top of #103: do not re-add any commit/push in the fan-out.
- **#113** (open, contains #103 and #98): lib profile runner only (`_aitlib_profile_run` / `Invoke-AitLibProfile` accept `result` lines; resolver-missing sets RC 2 + error line; `_aitlib_rm_tmp`). No overlap with deploy/tracker functions. `dotprofile_commit_push`'s fallback resolver call goes through this runner (`user-repo-path`, prints `via`), so behaviour is unchanged for it.
- **#115** (open, stacked on #113): relay section (`run_child_relayed --summary-tool`, `_aitlib_summary_errors`, `_aitlib_child_row`), A-2 ACTION in `resolve_machine_profile`. Relevant to abort: once the installers pass `--summary-tool`, an `[x]abort` in setup-user-claude (exit 2, no ERROR row written by `_managed_abort`) shows as `ERROR|<tool>|aborted (exit 2)`. No overlap with tracker/deploy code. Merge order stated in #115: #113, #115, then FIX-2.
- **#100**, **#110** (other slices, no lib hunks): contain the manifest the adopt mapping needs and the inline removal code that a lib remover would replace.
- A lib change made by the fan-out mission (tracker `removed`, remover, write helper) would conflict textually with #103 only near the "Review choices" comments if it edits them; the tracker block is untouched by #103/#113/#115.

## 6. Error-handling / parity / script-standards issues seen

- `deploy_tracker_record` / `Record-DeployOutcome`: unknown outcomes ignored silently (no default branch). Violates "no silent failures".
- JSON review menu abort text `[x]abort : stop the run` (sh 2376, ps1 2359) and the bash comment "abort (x) is global and exits the run (code 2)" (sh 2327; ps1 2312 says only "abort (x) exits (code 2)") vs the decision and spec ("stop this script (exit 2)"). JSON menu labels also differ from the spec (`[a]dopt : keep local value -> write to source` in code vs `[a]ccept & adopt : keep the local value -> write it to the repo now` in reference:162).
- `backup_dir`: unchecked `rm -rf` in the prune loop (sh 940); ps1 prune lacks `-LiteralPath` and `-ErrorAction Stop` (ps1 832-836); `*.md` count case parity (sh 925 vs ps1 820).
- `Adopt-ManagedFile` (ps1 2232, 2242, 2246) still uses `Test-Path $SourceFile`, `Test-Path $targetDir` and `Copy-Item -Path` (wildcard paths); bash `adopt_managed_file` `mkdir -p` unchecked (sh 2251). Used only by reverse discovery (hooks/skills), not the fan-out.
- `deploy_managed_file` `*.json` dispatch: case-sensitive in bash (`case`), insensitive in ps1 (`-like`). Not reachable for `*.md` rules.
- PS1 `Sync-ManagedJson` uses `-ErrorAction SilentlyContinue` on cleanup and `Test-Path $LiveFile` (wildcard) -- outside this slice's path, noted only.
- Tests: the PS1 managed-files suite lacks the bash cases `verified: no backup made`, `deploy state`, `backup-fail`, `claude-md` round trip (test-managed-files.sh:107, 117-122, 133-137, 318-346 vs .ps1). Neither suite covers a loop of several files, the tracker `preserved` / `skipped` rows, or a here-string-fed loop.

## 7. Risks, unknowns, open questions (with suggested answers)

- Q1. Lib remover + tracker `removed`, or inline removal in setup-user-claude like #110? Suggest the lib helper (4.2): one tested implementation for deploy-harness, Cursor and Claude, inlined into MDM scripts automatically by build-deploy.
- Q2. Adopt target for fan-out rules: manifest-mapped repo source (4.3) or none? Suggest manifest-mapped: `""` would drop the accept & adopt that setup-user-claude gives dotprofile rules today (contract item #11, kept 2026-10-21, cited in setup-user-claude.sh comments).
- Q3. Refresh `~/.aitools/rules/<name>` after an adopt (4.4)? Suggest yes, through a new public lib write helper.
- Q4. Should the fan-out depend on PR #100's manifest being merged? Suggest yes: without it there is no source to adopt into and no `retired` list; with no manifest, deploy without adopt and remove nothing, with a WARN + ACTION (#110's behaviour for Cursor).
- Q5. Plan on top of #103? Suggest yes: #103 removes the block the refactor would otherwise rewrite, and makes accept & adopt (not only merge) push.
- Risk: deploying `.claude/rules/*` (source `aitools`) into `~/.claude/rules` means a session inside the aitools repo loads each of those rules twice (project and user scope). Unknown whether Claude Code dedupes identical rule files; S3-FanPlan-Claude / -Ref may know. Not verified here.
- Risk: the manifest is case-insensitive by name, but bash `case` matching in the fan-out is not; a rule `Foo.md` in the manifest and `foo.md` in `~/.claude/rules` on APFS are one file, on ext4 two. Use lower-cased comparison for every name lookup (Cursor's `lower_name` pattern).
- Unknown: PS1 lib hunks of #113/#115 were not read line by line; the bodies state parity, unverified here.
- Unknown: whether `$Force` exists in setup-user-claude.ps1's scope (Prompt-DiffReview reads it by dynamic scope). Not checked (Claude slice).

## 8. INCIDENT markers (not filed)

1. INCIDENT (medium, spec deviation): `reference/managed-file-deployment.md` "Signatures" (lines 48-73) documents `ADOPT_TRANSFORM` (env-style, bash) / `-AdoptTransform` and a 5-arg bash signature; the code takes a 6th positional `ADOPT_FILTER` (`aitools-lib.sh:1781-1798`) and `-AdoptFilter` (`aitools-lib.ps1:1745-1763`). A planner writing from the spec produces calls that silently drop the filter (bash) or fail parameter binding (ps1).
2. INCIDENT (medium): `deploy_tracker_record` (`aitools-lib.sh:2281-2297`) and `Record-DeployOutcome` (`aitools-lib.ps1:2273-2284`) drop unknown outcomes with no log line; there is no `removed` outcome, so pruning consumers (#100, #110) keep private counters outside the tracker.
3. INCIDENT (high, silent wrong behaviour): `setup-user-cursor.sh:534-582` runs `deploy_managed_file` inside `while ...; done <<< "$RULE_SOURCES"`, so stdin is not the terminal and the review menu never appears; every differing `.mdc` is overwritten with a warning (probe: `.scratch/session-lib/probe-herestring.out`). PR #110 keeps the loop. The .ps1 twin prompts normally (parity break).
4. INCIDENT (medium, parity): rules filters disagree on case across languages and scripts (table 3.8); approved behaviour is case-insensitive.
5. INCIDENT (low, spec deviation): JSON field menu `[x]abort : stop the run` (`aitools-lib.sh:2376`, `aitools-lib.ps1:2359`) and the bash comment "exits the run" (`aitools-lib.sh:2327`) contradict the abort decision (ends only this script) and `reference/managed-file-deployment.md:155-169` menu text.
6. INCIDENT (medium, on main until #103 merges): accept & adopt into a dotprofile rule is not committed or pushed (setup-user-claude.sh:370 / ps1:400 gate on merged content), contrary to `.claude/rules/managed-file-deployment.md` "Adopt target" (N-Q2); the ps1 block commits without a pathspec.
7. INCIDENT (low): `reference/managed-file-deployment.md:266-270` says the library holds a protected-path list synced by a pre-commit step (Q14); the code reads the target repo's `.claude/rules/sources-of-truth.md` table at run time (`aitools-lib.sh:977-1002`, `aitools-lib.ps1:875-903`).
8. INCIDENT (low): `backup_dir` prune `rm -rf` unchecked (`aitools-lib.sh:940`); `Backup-Dir` prune without `-LiteralPath` (`aitools-lib.ps1:832-836`); `Adopt-ManagedFile` wildcard paths (`aitools-lib.ps1:2232-2246`).
