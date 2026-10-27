# Plan: Claude Code user rules from the `~/.aitools/rules` fan-out

**Intent** (DRAFT -- needs commander approval; protected: `plans/*.md` and every
intent statement): **Purpose**: Refactor `scripts/setup-user-claude.sh/.ps1` so
Claude Code gets its user-level rules from the `~/.aitools/rules` fan-out
(everything there minus the rules the manifest retires), with the build-deploy
MDM counterpart, the lib support it needs, CI wiring and a regression test in
`tests/rules-fanout/`. **Scope**: four implementation batches (lib, setup script
pair, build-deploy + MDM test + README, regression test + CI), their merge
order against open PRs #97-#116, the protected-file drafts the change needs,
risks and open questions. NOT the Cursor fan-out (PR #110), NOT deploy-harness
or its manifest (PRs #100/#111), NOT the installer hook-in or abort handling
(PR #106 and mission S3-AbortDocs), NOT the follow-ups listed at the end.
**Audience**: the implementing sub-agents (one per batch), the independent
reviewer, Session Commander 10cf255a-c, and the commander.

Author: S3-FanPlan-Planner (level 2, under S3-FanPlan), 2026-10-26. Status:
draft; nothing here is implemented. Every old_string below was applied with an
exact-one-occurrence check to the bases named per batch, and the edited tree
was syntax-checked and test-run in a scratch copy under isolated HOMEs
(`S3-FanPlan-Planner-notes.md` beside this plan's drafts folder, section 2).

## 1. Summary

- `setup-user-claude.sh/.ps1` stop reading `<dotprofile>/claude/rules` and fan
  out `~/.aitools/rules/*.md` (case-insensitive, `*.bak.*` and hidden files
  skipped, retired names excluded) into `~/.claude/rules` through
  `deploy_managed_file` / `Deploy-ManagedFile`, one summary tool `claude rules`.
- A retired rule's copy in `~/.claude/rules` is backed up and removed only when
  its bytes match the harness copy or a deploy-harness backup of it
  (`~/.aitools/rules/<name>.bak.*`); otherwise it is kept with a WARN + ACTION.
- Adopt target per rule from the manifest source (`shared` -> aitools
  `shared/rules`, `aitools` -> aitools `.claude/rules`, `dotprofile` ->
  `<dotprofile>/claude/rules`), only when that file exists; none without a
  manifest and on MDM for aitools-sourced rules.
- The lib gains a `removed` tracker outcome, a default branch for unknown
  outcomes, and four fan-out helpers; build-deploy stops embedding dotprofile
  rules into `deploy/setup-user-claude.*` (they reach endpoints through
  `deploy/deploy-harness.*`).
- Hard merge gate: PR #106 (deploy-harness runs before setup-user-claude) must
  be on main before Batch B ships, or `~/.claude/rules` stops getting new rules.

## 2. Decisions applied (binding) and their sources

| # | Decision | Source | Where applied |
|---|---|---|---|
| D1 | setup-user-claude fans out everything in `~/.aitools/rules` into `~/.claude/rules`, minus `retired`, case-insensitive, `*.md` only, skipping `*.bak.*` | Commander answers 2026-10-22 (HARNESS-2 hand-back), restated in S3-FanPlan-explorer-brief.md "Operational learning" and the planner launch prompt | Batch B (filter `rule_name_kind`, retired exclusion and pruning) |
| D2 | setup-user-claude stops deploying dotprofile rules directly | same | Batch B (no `USER_REPO_PATH/claude/rules` source), Batch C (no build-time rules embed) |
| D3 | A build-deploy MDM counterpart | same | Batch C |
| D4 | Regression test in `tests/rules-fanout/` | same | Batch D |
| D5 | "Put aitools rules in the user space of claude code"; Cursor gets user level only | same; PR #110 | Batch B fans out source `aitools` too (risk R1 first in section 8) |
| D6 | deploy-harness: first source wins; summary name `harness files` | SC-mission-packet.md section 6 | unchanged here |
| D7 | `[x]abort` = bare exit 2 (D-TS13 reversed: no marker file) | SC-mission-packet.md section 6 | Batch B: no trap, no row (section 4.6) |
| D8 | Abort semantics in the run: PR #106's current behaviour stands -- only deploy-harness's exit 2 ends the run; every other loop script, setup-user-claude included, keeps "ERROR row `script failed (exit 2)`, run continues". The 2026-10-26 "abort ends only that setup script" note is superseded | S3-FanPlan relay of Session Commander 10cf255a-c, 2026-10-26; verified in `gh pr diff 106` (scripts/aitools `deploy_configs`: `if [ "$script" = "deploy-harness.sh" ] ... deploy_abort "$script"; break`, other scripts `bash "$script_path" \|\| script_rc=$?` + `write_summary ERROR "${script%.sh}" "script failed (exit $script_rc)"`; aitools-install.sh `validate_and_run` 234-239 unchanged) | section 4.6; open question Q9 (#106 Q2) |
| D9 | Managed-file model: SOURCE is the source of truth; adopt/merge write the repo immediately; a dotprofile adopt target is committed and pushed (N-Q2) | packet section 6; `.claude/rules/managed-file-deployment.md` "Adopt target"; PR #103 (`dotprofile_commit_push`) | Batch B adopt mapping |
| D10 | Plans touching build-deploy or the lib use the sub-agent pattern, 2-3 files per batch, verbatim edits, error-handling audit | `.claude/rules/plan-execution.md`, `reference/plan-execution-detail.md` | every batch |

"Retired" is what PR #100 implements (verified in its diff, S3-FanPlan-Harness
findings 3b): manifest `~/.aitools/rules/.aitools-rules-manifest`, first line
`# aitools rules manifest v1`, then `<name><TAB><source>`, source `shared |
aitools | dotprofile | retired`; deploy-harness itself backs up and removes a
retired rule's file from `~/.aitools/rules`.

## 3. Contract (pinned: batches must not drift from it)

| Item | Value |
|---|---|
| Harness rules dir | bash `RULES_SRC="$HOME/.aitools/rules"`; ps1 `$rulesSrc = Join-Path (Join-Path $env:USERPROFILE ".aitools") "rules"` |
| Target dir | bash `RULES_DEST="$CLAUDE_DIR/rules"`; ps1 `$rulesDest = Join-Path $claudeDir "rules"` |
| Manifest | `$RULES_SRC/.aitools-rules-manifest`, read with `read_rules_manifest` / `Read-RulesManifest` (lib, Batch A; byte-identical to PR #110's copies) |
| Name filter | lib `rule_name_kind NAME` / `Get-RuleNameKind -Name` -> `hidden` (leading dot) / `backup` (`*.bak.*`) / `rule` (`*.md`) / `other`, all case-insensitive |
| Lib list helpers | `lower_name`, `in_list` (bash only; same bodies as setup-user-cursor's) |
| Tracker | new outcome `removed` (`deploy_tracker_record removed` / `Record-DeployOutcome -Outcome "removed"`), DETAIL row `removed: <name>`, summary part `N removed` (after `accepted`, before `verified`); unknown outcome -> `log_error` / `LogError` + counted `failed` + DETAIL `failed: <name>` |
| Summary tool name | `claude rules` (unchanged; `reference/script-standards-detail.md` tool-name table) |
| Rows (final, non-DETAIL) | `OK n/a (no harness rules)` (dir missing or nothing in it); `ERROR cannot read harness rules`; `ERROR cannot read rules manifest` (fan-out still runs, and the manifest is counted as a tracker `failed` item `.aitools-rules-manifest`, so the final row is `ERROR N failed`; review RC-2); `ERROR cannot create rules dir`; tracker row `N added, N updated, N accepted, N removed, N verified, N failed` (OK / WARN `N skipped (user review)` / ERROR `N failed`); dry run `OK dry run (no files written)` or `ERROR N failed (dry run)`; `ERROR validation failed` |
| ACTION rows | `Run aitools to rebuild ~/.aitools/rules and its manifest` (bad header); `Claude Code still loads retired rules in ~/.claude/rules: <names> -- delete them unless you wrote them` |
| Log lines tests rely on | `claude rules: <name> source=<source or unknown> adopt=<path or none>` (detail level); `Ignoring non-rule file in harness rules: <name> (only *.md is fanned out)`; `Not fanned out: <name> (retired in the rules manifest)`; `No rules manifest at ...`; `[DRY RUN] Would back up and remove <name> (retired rule; ...)` |
| Adopt targets | `shared` -> `<aitools>/shared/rules/<name>`, `aitools` -> `<aitools>/.claude/rules/<name>`, `dotprofile` -> `$USER_REPO_PATH/claude/rules/<name>` (resolver result), each only if that file exists; `<aitools>` = parent of the script dir when it holds `scripts/aitools-lib.sh` (`.ps1` for PowerShell), `shared/claude-shared.md` and `.git` (never true for the generated `deploy/` copy, nor for a BUILD-PKG package payload, which is a `git archive` without `.git`) |
| PS1 script dir variable | `$claudeScriptDir = $PSScriptRoot` (new, outside the extracted rules spans; bash uses the existing `SCRIPT_DIR`) |
| build-deploy markers | unchanged: `# --- BEGIN rules deployment`, `# --- BEGIN rules deploy logic`, `# --- END rules deploy logic`, `# --- END rules deployment` (prefix-matched by `extract_between`); the span between the first two stays non-empty |
| Test | `tests/rules-fanout/test-rules-fanout.sh` (mode 100755), options `--bash-only`, `--help`; env `AITOOLS_TEST_BASH` |
| Branches | Batch A `feature/lib-rules-fanout-helpers` (base `origin/main`); Batches B, C, D one branch `feature/claude-rules-fanout` (base `origin/main` after #103, #112 and Batch A merge) |
| Sub-agents | S3-FanImpl-A, S3-FanImpl-B, S3-FanImpl-C, S3-FanImpl-D (name prefixes `S3-FanImpl-A-` ... for any `*.md` they write) |

## 4. Behaviour, case by case (what the code in Batch B does)

1. **No `~/.aitools/rules`** (deploy-harness never ran; main before #106; an
   MDM endpoint that skipped deploy-harness): `log`, `OK|claude rules|n/a (no
   harness rules)`, `~/.claude/rules` untouched, exit unaffected. Same row when
   the directory holds no rule and the manifest retires nothing. Pre-push step
   7's smoke runs (no `~/.aitools/rules` in either HOME) stay green.
2. **Unreadable directory**: `log_error` + `ERROR|claude rules|cannot read
   harness rules`, nothing deployed.
3. **Manifest**: absent -> info log, every rule fanned out, nothing retired,
   adopt not offered (deploy-harness before #100 writes none). Bad header ->
   `log_warn` + ACTION, same behaviour. Unreadable -> `log_error` + ERROR row,
   fan-out continues without it, and the manifest is recorded as a tracker
   `failed` item so the tool's final row is `ERROR|claude rules|N failed` (no
   later OK row; with nothing to fan out, no `n/a` row either). Invalid lines
   -> `log_warn` each, ignored.
4. **Sources**: every entry of `~/.aitools/rules` (glob, flat) whose kind is
   `rule` and whose name is not retired; dangling symlink -> `failed`;
   directory named `*.md` -> ignored with a log line; names that differ only in
   case -> the first wins, the second `failed` (case-sensitive file systems).
   A file in `~/.aitools/rules` that the manifest does not list (a user file
   deploy-harness preserves) is fanned out too (D1 "everything"), adopt none.
5. **Deploy**: per rule `deploy_managed_file CONTENT ~/.claude/rules/<name>
   "claude rules" <name> <adopt>`; unexpected result -> `log_error` +
   `failed`. The bash loop reads its list on fd 3 so the review menu can
   prompt (verified: a here-string-fed loop makes `tty_interactive` false,
   `aitools-lib.sh:1357-1358` tests `[ -t 0 ]`).
6. **`[x]abort`** at a rule review: the lib's `_managed_abort` /
   `Invoke-ManagedAbort` exits 2 inside the loop. Files already processed keep
   their results; no `claude rules` tracker row and no exit footer are written.
   Under #106 the caller (installer `validate_and_run` / `Invoke-ValidatedScript`,
   `aitools` `deploy_configs` / `Deploy-Configs`) writes
   `ERROR|setup-user-claude|script failed (exit 2)` and continues with the next
   script (D8). Verified in the scratch prototype: exit 2, no `claude rules`
   row, the local file kept (`smoke-pty.sh`).
7. **Retired pruning**: for each retired name not deployed this run: the copy
   in `~/.claude/rules` (found case-insensitively, so `Gone.md` for the
   manifest's `gone.md` on a case-sensitive file system; reported under its
   on-disk name) is removed only when its bytes, ignoring trailing CR/LF, equal
   `~/.aitools/rules/<name>` or any `~/.aitools/rules/<name>.bak.*`. Removal
   steps: `backup_file` / `Backup-File`; then the flag
   (`BACKUP_FILE_OK` / `$script:BackupFileOk`) must be true **and** a
   `<file>.bak.*` with the same text must exist beside it (review RC-1), else
   `log_error` + tracker `failed` and the file stays; `rm` / `Remove-Item`,
   verified; tracker `removed`. Not matching -> `log_warn "Kept ..."` and one
   ACTION row listing the kept names. Dry run logs the removal only.
8. **Preserved**: every `rule`-kind file in `~/.claude/rules` not deployed this
   run is logged and counted `preserved` (the live `delegation.md.bak.*` is
   kind `backup`: ignored, as today).
9. **Dotprofile resolver error** (`URP_RC=3`): unchanged, the script still
   exits 1 before CLAUDE.md and rules (Q4 suggests keeping it).

## 5. Dependencies and merge order (open PRs #97-#116)

Verified with `proto-bases.sh` (scratch): each edit applied once, or not, to
each PR head.

| PR | Relation | Action |
|---|---|---|
| #103 `fix/mf-dotprofile-adopt-push` | **Must merge before B.** Deletes the private commit+push block inside the rules loop (B3/B6 old_strings include its replacement comment; they MISS on main). Makes accept & adopt into the dotprofile commit+push (lib) | merge first |
| #112 `fix/mf-audit-claude-build` (stacked on #103) | **Must merge before C/D.** Adds `tests/claude-mdm/` (its MDM check expects dotprofile `r1.md` in `~/.claude/rules`: C12 rewrites it) and the CI anchor D1/D2 use. B applies on #103 or #112 alike | merge second |
| #113, #115, #116 (stack on #98 -> #103) | Carry #103's same setup-user-claude hunk (B applies on #116's head: verified). Touch the lib in other regions (tracker untouched: verified by grep of their diffs). #116 changes `check.yml` (D1/D2 MISS on #116's head because it lacks #112's step) | any order; if #116 merges before #112, re-pin D1/D2 (instruction in Batch D) |
| #106 `feature/harness-hookin` | **Merge gate for B's PR** (not for writing it): without it nothing fills `~/.aitools/rules` on the dev path, so after B `~/.claude/rules` keeps its current files and gets no new ones | merge before B/C/D's PR; no textual overlap |
| #100 `feature/harness-rules-manifest` | Provides the manifest. Not a hard dependency (no manifest -> everything fanned out, no pruning, no adopt), but adopt mapping and pruning only work after it | merge before B's PR is useful; no textual overlap |
| #110 `feature/harness-cursor-user-rules` | Defines the same `lower_name` / `in_list` / `read_rules_manifest` / `Read-RulesManifest` inside setup-user-cursor; A's lib copies are byte-identical, so either order works (the script's own definition, after sourcing the lib, wins and is the same). After both merge: follow-up F1 removes Cursor's copies | independent |
| #111 `feature/harness-mdm-followups` | Rewords the comment C11 edits (C11 MISSES on #111's head; C11b is the re-pinned edit for that base). No other overlap | if #111 merges first, use C11b |
| #99 `docs/harness-approved-drafts`, #101 `docs/m3-approved-drafts` | Rewrite `deploy-paths.md/.mdc`, `managed-file-deployment.md/.mdc`, `reference/user-repo.md`: the protected drafts (section 7) are written on top of their text | drafts apply after them |
| #105, #108, #114, #98, #97, #102, #104, #109 | No overlap with this plan's files (S3-FanPlan-Misc, -Install, -Checks findings; `proto-d2.sh` found no PR touching README.md) | none |
| BUILD-PKG mission (not a PR; contract `S3-BuildPkg/S3-BuildPkg-decisions.md` on main 8953371) | BP-6: package mode runs the dev-path scripts from a read-only payload with "adopt disabled". This plan's adopt mapping requires `.git` beside `scripts/` (amended), so a payload is never an adopt target; BUILD-PKG's own "adopt disabled" switch (its batch B6) still has to cover the dotprofile target and CLAUDE.md. BP-10 / batch B5 add lib functions (target-user API) and batch B6 changes setup-user-* scripts "after FAN-PLAN" | **coordination item**: BUILD-PKG B5/B6 land after Batch A and the B+C+D PR, and rebase on them; this plan owns `aitools-lib.*` tracker/fan-out helpers and the setup-user-claude rules spans, BUILD-PKG the rest. State it in both PR bodies |

Order: #103 -> #112 -> (#113/#115/#116 any time) -> Batch A PR -> #100 -> #106
-> Batch B+C+D PR. Batch A can merge as soon as it is reviewed.

## 6. Batches

Every batch is executed by a fresh sub-agent (plan-execution.md: lib and
build-deploy changes). The orchestrator verifies between batches (spot-check
the diff against this plan, run the verification listed). Each prompt carries
the seven delegation-duty elements (`/delegate`), the mission packet path
`/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md`,
and this error-handling block verbatim (`reference/plan-execution-detail.md`
"Sub-agent prompt template"):

````text
## Error-handling rules (non-negotiable)

These rules apply to ALL code you write or modify:

1. Every `-ErrorAction SilentlyContinue` MUST have a null/empty check within 3 lines
2. Every `2>/dev/null` MUST have a comment explaining why AND a result check
3. Every `|| true` MUST have a comment explaining why AND a result check
4. Every try/catch MUST have a catch that logs or re-throws; empty catch {} is NEVER OK
5. Exception: command-existence checks (Get-Command, command -v) with explicit fallback
6. Every log_error/LogError for a file write MUST pair with write_summary ERROR
7. Prefer `-ErrorAction Stop` with try/catch over `-ErrorAction SilentlyContinue`
8. `rm -f` in bash is OK for cleanup (ignores nonexistent; targeted, not blanket)
````

Common to every batch:
- Work in your own worktree:
  `git -C /Users/new-jose/repos/aitools fetch origin`, then
  `git -C /Users/new-jose/repos/aitools worktree add -b <branch> /Users/new-jose/repos/aitools/.claude/worktrees/<short> <base>`
  (Batch C and D: `git -C ... worktree add /Users/new-jose/repos/aitools/.claude/worktrees/<short> feature/claude-rules-fanout` after `git fetch`, i.e. the existing branch).
- `.ps1` files check out with CRLF (`.gitattributes`: `*.ps1 text eol=crlf`):
  use the Edit tool, which matches CRLF lines; a perl/sed edit must keep CRLF.
- Scratch: `<worktree>/.scratch/session-<name, 10 chars max>/`. Commit with
  `git commit -F <scratch>/commit-msg.txt` ending in the attribution line; PR
  body via `--body-file`.
- Never run `aitools`, `aitools install`, `setup-user-*`, `deploy-harness` or
  `scripts/build-deploy.sh` against the real HOME; never run
  `scripts/check-post-push.sh/.ps1` (its step 7 runs build-deploy against the
  real HOME, Checks finding I-1) or `check-pre-commit --fix` (step 3, same).
  `check-pre-commit.sh` (no `--fix`) and `check-pre-push.sh` are safe from a
  worktree (pre-push step 7 isolates HOME, `check-pre-push.sh:131-148`).
- Known pre-existing failures (record, not blockers): pre-commit step 6
  (`harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` 100644),
  pre-push step 7 (dotprofile `deploy/` stale), pre-push step 3 `[\s]` false
  positives.

### Batch A -- lib: tracker `removed`, unknown outcomes, fan-out helpers

- **Sub-agent**: S3-FanImpl-A. **Branch**: `feature/lib-rules-fanout-helpers`,
  base `origin/main` (verified: A1-A4 apply to main, #103, #112, #116 and #110
  heads; the tracker block is identical on main and #112).
- **Files** (2): `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`.
- **Ships**: its own PR (D-DEL4), base `main`, title "Lib: tracker removed
  outcome, unknown outcomes fail, rules fan-out helpers".

#### A1 -- `scripts/aitools-lib.sh`, tracker init and record

old_string (A1):

````text
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
````

new_string (A1):

````text
# Reset all deploy tracker counters. Call before a deploy loop.
_DT_ADDED=0; _DT_UPDATED=0; _DT_VERIFIED=0
_DT_ACCEPTED=0; _DT_SKIPPED=0; _DT_PRESERVED=0; _DT_FAILED=0; _DT_REMOVED=0
DEPLOY_TRACKER_TEXT=""

deploy_tracker_init() {
    _DT_ADDED=0; _DT_UPDATED=0; _DT_VERIFIED=0
    _DT_ACCEPTED=0; _DT_SKIPPED=0; _DT_PRESERVED=0; _DT_FAILED=0; _DT_REMOVED=0
    DEPLOY_TRACKER_TEXT=""
}

# Record a single file outcome. Increments counter and writes DETAIL summary.
# "removed": the caller backed up and deleted a deployed file (a fan-out
# consumer pruning a retired rule). An outcome the tracker does not know is a
# caller bug: it is logged and counted as failed, never dropped.
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
        removed)   _DT_REMOVED=$((_DT_REMOVED + 1))
                   write_summary DETAIL "$tool_name" "removed: $item_name" ;;
        verified)  _DT_VERIFIED=$((_DT_VERIFIED + 1)) ;;
        preserved) _DT_PRESERVED=$((_DT_PRESERVED + 1)) ;;
        *)         log_error "deploy_tracker_record: unknown outcome \"$outcome\" for $item_name ($tool_name) -- counted as failed"
                   _DT_FAILED=$((_DT_FAILED + 1))
                   write_summary DETAIL "$tool_name" "failed: $item_name" ;;
    esac
}
````

#### A2 -- `scripts/aitools-lib.sh`, tracker summary + new helpers after it

old_string (A2):

````text
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
````

new_string (A2):

````text
    if [ "$_DT_ACCEPTED" -gt 0 ]; then parts="${parts:+$parts, }$_DT_ACCEPTED accepted"; fi
    if [ "$_DT_REMOVED" -gt 0 ];  then parts="${parts:+$parts, }$_DT_REMOVED removed"; fi
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

# ---------------------------------------------------------------------------
# Rules fan-out helpers, for the consumers of ~/.aitools/rules
# (setup-user-claude; setup-user-cursor still defines its own copies of
# lower_name, in_list and read_rules_manifest, which match these). deploy-harness
# writes the rules manifest (PR #100 contract): first line RULES_MANIFEST_HEADER,
# then "<name><TAB><source>" lines, source shared | aitools | dotprofile |
# retired. Parity: Get-RuleNameKind and Read-RulesManifest in aitools-lib.ps1.
# ---------------------------------------------------------------------------
RULES_MANIFEST_HEADER="# aitools rules manifest v1"

# Lower-case a name (APFS and NTFS are case-insensitive)
lower_name() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Exit 0 when the line $1 is in the newline-separated list $2 (bash 3.2: no
# associative arrays)
in_list() {
    case "
$2" in
        *"
$1
"*) return 0 ;;
    esac
    return 1
}

# Print the kind of a file name in ~/.aitools/rules, compared case-insensitively
# (commander decision 2026-10-22): "hidden" (a dot file, e.g. the rules
# manifest), "backup" (*.bak.*, the library's backup naming), "rule" (*.md) or
# "other". Parity: Get-RuleNameKind in aitools-lib.ps1.
rule_name_kind() {
    local lc
    lc=$(lower_name "$1")
    case "$lc" in
        .*)      printf 'hidden\n' ;;
        *.bak.*) printf 'backup\n' ;;
        *.md)    printf 'rule\n' ;;
        *)       printf 'other\n' ;;
    esac
}

# Print the rules manifest $1 as lines "rule<TAB><name><TAB><source>" and
# "invalid<TAB><line, tabs as <TAB>>", or the one line "header-bad" when its
# first line is not RULES_MANIFEST_HEADER. A valid line: a *.md name with no /
# or \ and no .bak., a source of shared, aitools, dotprofile or retired, and a
# name not already listed (compared case-insensitively). Exit non-zero (message
# on stderr) when $1 cannot be read. Parity: Read-RulesManifest in aitools-lib.ps1.
read_rules_manifest() {
    perl -e '
        my ($f, $header) = @ARGV;
        open my $fh, "<:raw", $f or die "cannot read $f: $!\n";
        my $head = <$fh>; $head = "" unless defined $head;
        $head =~ s/\A\xEF\xBB\xBF//; $head =~ s/\r?\n\z//;
        if ($head ne $header) { print "header-bad\n"; exit 0 }
        my %seen;
        while (my $l = <$fh>) {
            $l =~ s/\r?\n\z//;
            next if $l eq "";
            my ($name, $src) = split /\t/, $l, 2;
            $src = "" unless defined $src;
            if ($name !~ /\A[^\/\\]+\.md\z/ || $name =~ /\.bak\./
                    || $src !~ /\A(?:shared|aitools|dotprofile|retired)\z/ || $seen{lc $name}++) {
                (my $show = $l) =~ s/\t/<TAB>/g;
                print "invalid\t$show\n";
                next;
            }
            print "rule\t$name\t$src\n";
        }
        close $fh;
    ' "$1" "$RULES_MANIFEST_HEADER"
}
````

#### A3 -- `scripts/aitools-lib.ps1`, tracker init and record (CRLF file)

old_string (A3):

````text
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
````

new_string (A3):

````text
$script:dtAdded = 0; $script:dtUpdated = 0; $script:dtVerified = 0
$script:dtAccepted = 0; $script:dtSkipped = 0; $script:dtPreserved = 0; $script:dtFailed = 0; $script:dtRemoved = 0
$script:deployTrackerText = ""

function Initialize-DeployTracker {
    $script:dtAdded = 0; $script:dtUpdated = 0; $script:dtVerified = 0
    $script:dtAccepted = 0; $script:dtSkipped = 0; $script:dtPreserved = 0; $script:dtFailed = 0; $script:dtRemoved = 0
    $script:deployTrackerText = ""
}

# Record a single file outcome. Increments counter and writes DETAIL summary.
# "removed": the caller backed up and deleted a deployed file (a fan-out
# consumer pruning a retired rule). An outcome the tracker does not know is a
# caller bug: it is logged and counted as failed, never dropped.
function Record-DeployOutcome {
    param([string]$Outcome, [string]$ToolName, [string]$ItemName)
    switch ($Outcome) {
        { $_ -eq "added" -or $_ -eq "created" } { $script:dtAdded++;     Write-Summary "DETAIL" $ToolName "added: $ItemName" }
        "updated"   { $script:dtUpdated++;   Write-Summary "DETAIL" $ToolName "updated: $ItemName" }
        "accept & adopt" { $script:dtAccepted++;  Write-Summary "DETAIL" $ToolName "accept & adopt: $ItemName" }
        "skipped"   { $script:dtSkipped++;   Write-Summary "DETAIL" $ToolName "skipped: $ItemName" }
        "failed"    { $script:dtFailed++;    Write-Summary "DETAIL" $ToolName "failed: $ItemName" }
        "removed"   { $script:dtRemoved++;   Write-Summary "DETAIL" $ToolName "removed: $ItemName" }
        "verified"  { $script:dtVerified++ }
        "preserved" { $script:dtPreserved++ }
        default {
            LogError "Record-DeployOutcome: unknown outcome `"$Outcome`" for $ItemName ($ToolName) -- counted as failed"
            $script:dtFailed++
            Write-Summary "DETAIL" $ToolName "failed: $ItemName"
        }
    }
}
````

#### A4 -- `scripts/aitools-lib.ps1`, tracker summary + new helpers after it (CRLF file)

old_string (A4):

````text
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
````

new_string (A4):

````text
    if ($script:dtAccepted -gt 0)  { $parts += "$($script:dtAccepted) accepted" }
    if ($script:dtRemoved -gt 0)   { $parts += "$($script:dtRemoved) removed" }
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

# ---------------------------------------------------------------------------
# Rules fan-out helpers, for the consumers of .aitools\rules (setup-user-claude;
# setup-user-cursor still defines its own Read-RulesManifest, which matches
# this one). deploy-harness writes the rules manifest (PR #100 contract): first
# line $rulesManifestHeader, then "<name><TAB><source>" lines, source shared |
# aitools | dotprofile | retired. Parity: rule_name_kind and
# read_rules_manifest in aitools-lib.sh.
# ---------------------------------------------------------------------------
$rulesManifestHeader = "# aitools rules manifest v1"

# The kind of a file name in .aitools\rules, compared case-insensitively
# (commander decision 2026-10-22): "hidden" (a dot file, e.g. the rules
# manifest), "backup" (*.bak.*, the library's backup naming), "rule" (*.md) or
# "other". Parity: rule_name_kind in aitools-lib.sh.
function Get-RuleNameKind([string]$Name) {
    if ($Name.StartsWith(".")) { return "hidden" }
    if ($Name -like "*.bak.*") { return "backup" }
    if ($Name -like "*.md") { return "rule" }
    return "other"
}

# Read the rules manifest. Returns @{ Status = "ok" | "header-bad"; Rules = list
# of @{ Name; Source }; Invalid = list of ignored lines (tabs shown as <TAB>) }.
# A valid line: a *.md name with no / or \ and no .bak., a source of shared,
# aitools, dotprofile or retired, and a name not already listed (compared
# case-insensitively). Throws when the file cannot be read.
# Parity: read_rules_manifest in aitools-lib.sh.
function Read-RulesManifest([string]$Path) {
    $result = @{ Status = "ok"; Rules = New-Object System.Collections.Generic.List[object]; Invalid = New-Object System.Collections.Generic.List[string] }
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    $lines = $text -split "`n"
    # A CR is a line ending only before an LF (as the .sh reads it): the last
    # piece, which no LF follows, keeps a trailing CR (and fails validation)
    $last = $lines.Count - 1
    $head = if ($last -gt 0) { $lines[0] -replace "`r$", "" } else { $lines[0] }
    if ($head -cne $rulesManifestHeader) { $result.Status = "header-bad"; return $result }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    for ($i = 1; $i -lt $lines.Count; $i++) {
        $l = if ($i -lt $last) { $lines[$i] -replace "`r$", "" } else { $lines[$i] }
        if ($l -eq "") { continue }
        $tab = $l.IndexOf("`t")
        $name = if ($tab -ge 0) { $l.Substring(0, $tab) } else { $l }
        $src = if ($tab -ge 0) { $l.Substring($tab + 1) } else { "" }
        if ($name -cnotmatch '\A[^/\\]+\.md\z' -or $name -clike "*.bak.*" -or
            $src -cnotmatch '\A(?:shared|aitools|dotprofile|retired)\z' -or -not $seen.Add($name)) {
            $result.Invalid.Add(($l -replace "`t", "<TAB>"))
            continue
        }
        $result.Rules.Add(@{ Name = $name; Source = $src })
    }
    return $result
}
````

#### Error-handling audit (Batch A)

| Code | Pattern | Verdict |
|---|---|---|
| `deploy_tracker_record` `*)` / `Record-DeployOutcome` `default` | `log_error` (not a file write) | Counted `failed`, so the caller's tracker summary writes `ERROR|<tool>|N failed`: the error is never silent (rule 6 satisfied through the tracker row) |
| `lower_name` | `tr` in a pipeline | no suppression; result used directly |
| `read_rules_manifest` | perl `die` on open failure | non-zero exit + stderr message; the caller captures `2>&1` and checks the exit (`if ! manifest_out=$(...)`) |
| `Read-RulesManifest` | `ReadAllText` throws | documented "Throws"; the caller wraps it in try/catch that logs (Batch B) |
| `Get-RuleNameKind` / `rule_name_kind` | none | pure |
| No `2>/dev/null`, `\|\| true`, `-ErrorAction SilentlyContinue` or empty catch added | | PASS |

Step 31 (check-post-push) parity: after A both tracker regex extractions give
`added,created,failed,preserved,removed,skipped,updated,verified` (verified by
running the two perl one-liners of `check-post-push.sh:802-803` on the edited
copies). Step 29 (menu letters) and step 30 (`MANAGED_FILE_RESULT=` values)
are unchanged: no menu or result value is added.

#### Verification (Batch A)

1. `bash -n scripts/aitools-lib.sh`; `pwsh -NoProfile -File scripts/_validate-ps1.ps1 scripts/aitools-lib.ps1` -> `OK`.
2. Step 31 extraction (scratch script with the two perl lines from
   `check-post-push.sh:802-803`): both lists equal and include `removed`.
3. Suites (each isolates HOME): `bash tests/managed-files/test-managed-files.sh`,
   `pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1`,
   `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`,
   `bash tests/deploy-harness/test-deploy-harness.sh`,
   `bash tests/profile/test-lib.sh`. Prototype results on the edited #112
   tree: 57/0, 39/0, 78/0/1 skipped, 45/0, 209/0.
4. A one-off tracker probe in scratch (source the lib under an isolated
   HOME; record `removed` and `bogus`; summary): rows `DETAIL|t|removed: x.md`,
   `DETAIL|t|failed: y.md`, `ERROR|t|1 failed`, text `1 removed, 1 failed`
   (Batch D's lib cases do the same permanently).
5. `bash scripts/check-pre-commit.sh`; `bash scripts/check-pre-push.sh` (from the worktree).
- **Not run in Batch A**: check-post-push (real HOME), Windows native.

### Batch B -- setup-user-claude.sh/.ps1: the fan-out

- **Sub-agent**: S3-FanImpl-B. **Branch**: `feature/claude-rules-fanout`, base
  `origin/main` after #103, #112 and Batch A have merged (if Batch A is not
  merged yet: base on `feature/lib-rules-fanout-helpers` and say so in the PR).
  B's old_strings need #103 (B3, B6 MISS on main: they contain #103's
  replacement comment); verified to apply on #103, #112 and #116 heads.
- **The base must contain 9923a3c** ("Use -LiteralPath in Backup-File and
  Backup-Dir", on main since 2026-10-26). #112's branch does not (`git
  merge-base --is-ancestor` exit 1, S3-FanPlan); a base cut from main after
  #112 merges does. Check before the first edit:
  `git -C <worktree> merge-base --is-ancestor 9923a3c HEAD` must exit 0.
  Without it, PowerShell `Backup-File` skips names with `[ ]` while reporting
  success; B6's backup check then refuses the removal (the retired-bracket test
  fails), so no file is lost, but the base is wrong.
- **Files** (2): `scripts/setup-user-claude.sh`, `scripts/setup-user-claude.ps1`.
- **Ships**: pushes the branch and opens a **draft** PR (title "setup-user-claude:
  fan out ~/.aitools/rules into ~/.claude/rules"); Batches C and D push to the
  same branch; S3-FanImpl-D marks it ready (`gh pr ready`). The PR body states
  the #106 merge gate.
- Pre-commit step 13 WARNs on B's commit (setup-user-claude without
  build-deploy.sh): expected, cleared by C's commit on the same branch.
- Between B's and C's commits the generated MDM script still contains
  build-deploy's "Rules fallback" block; it tests `[ -z "$RULES_SRC" ]`, and B
  keeps `RULES_SRC` defined (now `~/.aitools/rules`, never empty), so the
  block is a no-op and `set -u` is safe.

#### B1 -- `scripts/setup-user-claude.sh`, header (managed scope)

old_string (B1):

````text
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md matching <userRepoPath>/claude/rules/ (additive deploy)
# Preserved: ~/.claude/rules/ files not in user repo source
````

new_string (B1):

````text
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md fanned out from ~/.aitools/rules (additive; the
#   copy of a rule the rules manifest retires is backed up and removed)
# Preserved: ~/.claude/rules/ files not in ~/.aitools/rules
# Rules come from ~/.aitools/rules only (deploy-harness fills it: run it first);
# the dotprofile's claude/rules reaches Claude Code through it.
````

#### B2 -- `scripts/setup-user-claude.sh`, rules source span (between `# --- BEGIN rules deployment` and `# --- BEGIN rules deploy logic`)

old_string (B2):

````text
# Deploy user rules: additive (add/update managed, preserve unmanaged, log diffs).
RULES_SRC=""
if [ -n "${USER_REPO_PATH:-}" ] && [ -d "$USER_REPO_PATH/claude/rules" ]; then
    RULES_SRC="$USER_REPO_PATH/claude/rules"
fi

RULES_DEST="$CLAUDE_DIR/rules"

# --- BEGIN rules deploy logic (extracted by build-deploy) ---
````

new_string (B2):

````text
# Rules fan-out: ~/.aitools/rules -> ~/.claude/rules. deploy-harness fills
# ~/.aitools/rules from aitools shared/rules, aitools .claude/rules and the
# dotprofile's claude/rules (first source wins) and writes its rules manifest
# (PR #100 contract). Claude Code gets every rule there except the ones the
# manifest retires (commander decisions 2026-10-22): *.md only, *.bak.* and
# hidden files skipped, names compared case-insensitively. The dotprofile's
# claude/rules is not read here. Additive: managed files updated, unmanaged
# files preserved; the copy of a retired rule is backed up and removed when it
# matches a harness copy. Adopt target: the repo file the manifest names as the
# rule's source, when it is on this machine. Parity: setup-user-claude.ps1.
RULES_SRC="$HOME/.aitools/rules"
RULES_DEST="$CLAUDE_DIR/rules"
RULES_MANIFEST="$RULES_SRC/.aitools-rules-manifest"
# The aitools checkout this script runs from: adopt targets of shared and
# aitools rules. Only a git checkout counts: the generated deploy/ copy runs
# from the dotprofile's deploy/ directory, and a package payload (git archive,
# read-only) has no .git; adopt is then offered for dotprofile rules only.
RULES_AITOOLS_REPO=""
if [ -f "$SCRIPT_DIR/../scripts/aitools-lib.sh" ] && [ -f "$SCRIPT_DIR/../shared/claude-shared.md" ] && [ -e "$SCRIPT_DIR/../.git" ]; then
    if ! RULES_AITOOLS_REPO=$(cd "$SCRIPT_DIR/.." && pwd); then
        log_warn "Cannot resolve the aitools checkout from $(display_path "$SCRIPT_DIR") -- adopt not offered for shared and aitools rules"
        RULES_AITOOLS_REPO=""
    fi
fi

# --- BEGIN rules deploy logic (extracted by build-deploy) ---
````

#### B3 -- `scripts/setup-user-claude.sh`, rules logic span (everything between `# --- BEGIN rules deploy logic` and `# --- END rules deploy logic`)

old_string: the whole span below (lines 298-407 at #112 head 52821bd; sha256
of those lines with LF endings and a final newline:
`55f352ff15a6c0ff69c2965ec977edd9a9d5d6ba1965f2ca8387c0917966b9d9`).
new_string: the fan-out.

old_string (B3):

````text
if [ -n "$RULES_SRC" ]; then
    RULE_COUNT=$(find "$RULES_SRC" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
    if [ "$RULE_COUNT" -eq 0 ]; then
        log "User repo claude/rules/ exists but has no .md files -- skipping"
    elif [ "$DRY_RUN" = "true" ]; then
        EXISTING_COUNT=0
        if [ -d "$RULES_DEST" ]; then
            EXISTING_COUNT=$(find "$RULES_DEST" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
        fi
        log "[DRY RUN] $(display_path "$RULES_DEST"): additive deploy"
        log "  Source: $(display_path "$RULES_SRC") ($RULE_COUNT rule files)"
        log "  Existing: $EXISTING_COUNT rule files"
        for rule_file in "$RULES_SRC"/*.md; do
            [ -f "$rule_file" ] || continue
            rule_name=$(basename "$rule_file")
            if [ -f "$RULES_DEST/$rule_name" ]; then
                # diff -q: exits 0 if identical, 1 if different (expected, not an error)
                if diff -q "$RULES_DEST/$rule_name" "$rule_file" >/dev/null 2>&1; then
                    log "  Would skip (unchanged): $rule_name"
                else
                    log "  Would update (changed): $rule_name"
                fi
            else
                log "  Would add (new): $rule_name"
            fi
        done
        # Show files that would be preserved
        if [ -d "$RULES_DEST" ]; then
            for existing in "$RULES_DEST"/*.md; do
                [ -f "$existing" ] || continue
                exist_name=$(basename "$existing")
                if [ ! -f "$RULES_SRC/$exist_name" ]; then
                    log "  Would preserve (unmanaged): $exist_name"
                fi
            done
        fi
    else
        backup_dir "$RULES_DEST"
        if ! mkdir -p "$RULES_DEST"; then
            log_error "Cannot create $(display_path "$RULES_DEST")"
            write_summary ERROR "claude rules" "cannot create rules dir"
            exit 1
        fi

        deploy_tracker_init
        ERRORS_BEFORE_RULES=$ERRORS
        for rule_file in "$RULES_SRC"/*.md; do
            [ -f "$rule_file" ] || continue
            rule_name=$(basename "$rule_file")
            # Adopt target: the dotprofile rule (the file deployed from). Empty
            # in the MDM deploy script (no user repo): adopt and merge not offered.
            _rule_adopt_path=""
            if [ -n "${USER_REPO_PATH:-}" ]; then
                _rule_adopt_path="$USER_REPO_PATH/claude/rules/$rule_name"
            fi
            if ! _rule_content=$(cat "$rule_file"); then
                log_error "Cannot read source rule $rule_name"
                deploy_tracker_record "failed" "claude rules" "$rule_name"
                continue
            fi
            deploy_managed_file "$_rule_content" "$RULES_DEST/$rule_name" "claude rules" "$rule_name" "$_rule_adopt_path"

            case "$MANAGED_FILE_RESULT" in
                created|updated|verified|"accept & adopt"|skipped|failed)
                    # The library wrote LOCAL and the adopt target itself; the
                    # tracker records every outcome (failed -> ERROR row).
                    ;;
            esac
            deploy_tracker_record "$MANAGED_FILE_RESULT" "claude rules" "$rule_name"
            # After accept & adopt or merge & adopt the library commits that one
            # dotprofile rule and pushes it (dotprofile_commit_push, N-Q2;
            # commander confirmed 2026-10-21, contract item #11). No commit here.
        done

        # Log preserved files (in target but not in source)
        if [ -d "$RULES_DEST" ]; then
            for existing in "$RULES_DEST"/*.md; do
                [ -f "$existing" ] || continue
                exist_name=$(basename "$existing")
                if [ ! -f "$RULES_SRC/$exist_name" ]; then
                    log "Preserved unmanaged rule: $exist_name"
                    deploy_tracker_record "preserved" "claude rules" "$exist_name"
                fi
            done
        fi

        # Post-write validation: each deployed file is non-empty (a file whose
        # deploy failed is already reported; the library left it as it was)
        for rule_file in "$RULES_SRC"/*.md; do
            [ -f "$rule_file" ] || continue
            rule_name=$(basename "$rule_file")
            if [ -f "$RULES_DEST/$rule_name" ] && [ ! -s "$RULES_DEST/$rule_name" ]; then
                log_error "Validation failed: $rule_name is empty after deploy"
            fi
        done

        if [ "$_DT_FAILED" -gt 0 ]; then
            # deploy_tracker_summary writes the ERROR row ("N failed")
            deploy_tracker_summary "claude rules"
            log "Rules: $DEPLOY_TRACKER_TEXT, $_DT_PRESERVED preserved in $(display_path "$RULES_DEST")"
        elif [ "$ERRORS" -eq "$ERRORS_BEFORE_RULES" ]; then
            deploy_tracker_summary "claude rules"
            log_ok "Rules: $DEPLOY_TRACKER_TEXT, $_DT_PRESERVED preserved in $(display_path "$RULES_DEST")"
        else
            write_summary ERROR "claude rules" "validation failed"
        fi
    fi
else
    log "No user rules to deploy (no claude/rules/ in user repo)"
fi
````

new_string (B3):

````text
# rule_adopt_target NAME SOURCE: print the repo file that a rule from SOURCE (a
# rules manifest source) came from, or nothing when that file is not on this
# machine (adopt and merge are then not offered). A dotprofile adopt target is
# committed and pushed by the library (N-Q2); an aitools one is a working-tree
# change. Parity: Get-RuleAdoptTarget in setup-user-claude.ps1.
rule_adopt_target() {
    local name="$1" src="$2" target=""
    case "$src" in
        shared)     if [ -n "$RULES_AITOOLS_REPO" ]; then target="$RULES_AITOOLS_REPO/shared/rules/$name"; fi ;;
        aitools)    if [ -n "$RULES_AITOOLS_REPO" ]; then target="$RULES_AITOOLS_REPO/.claude/rules/$name"; fi ;;
        dotprofile) if [ -n "${USER_REPO_PATH:-}" ]; then target="$USER_REPO_PATH/claude/rules/$name"; fi ;;
    esac
    if [ -n "$target" ] && [ -f "$target" ]; then printf '%s\n' "$target"; fi
}

# rule_text_equal A B: exit 0 when files A and B hold the same bytes apart from
# trailing CR/LF (deploy_managed_file normalizes trailing newlines), 1 when they
# differ, 2 when one cannot be read. Parity: Test-RuleTextEqual in setup-user-claude.ps1.
rule_text_equal() {
    perl -e '
        my @t;
        for my $f (@ARGV) {
            open my $fh, "<:raw", $f or exit 2;
            local $/; my $c = <$fh>; close $fh;
            $c = "" unless defined $c; $c =~ s/[\r\n]+\z//; push @t, $c;
        }
        exit($t[0] eq $t[1] ? 0 : 1);
    ' "$1" "$2"
}

# rule_manifest_source NAME: the manifest source of NAME (names compared
# case-insensitively), or nothing
rule_manifest_source() {
    local lc line
    lc=$(lower_name "$1")
    while IFS= read -r line; do
        case "$line" in
            "$lc$TAB"*) printf '%s\n' "${line#*"$TAB"}"; return 0 ;;
        esac
    done <<< "$RULE_SOURCE_OF"
    return 0
}

TAB=$(printf '\t')
RULES_GO=false
if [ ! -d "$RULES_SRC" ]; then
    log "No harness rules at $(display_path "$RULES_SRC") (deploy-harness has not run) -- skipping"
    write_summary OK "claude rules" "n/a (no harness rules)"
elif [ ! -r "$RULES_SRC" ] || [ ! -x "$RULES_SRC" ]; then
    log_error "Cannot list $(display_path "$RULES_SRC") (permission denied)"
    write_summary ERROR "claude rules" "cannot read harness rules"
else
    RULES_GO=true
fi

# Rules manifest: each rule's source (adopt target) and the retired names.
# Without one (deploy-harness before PR #100) every rule is fanned out, none
# is retired and adopt is not offered.
MANIFEST_OK=false
MANIFEST_FAILED=false   # unreadable: counted as a failed item, so the final row is ERROR
RULE_SOURCE_OF=""   # "<lower-case name><TAB><source>" lines
RETIRED_NAMES=""    # names the manifest retires, one per line
RETIRED_LC=""       # the same, lower-cased
if [ "$RULES_GO" = "true" ]; then
    if [ ! -f "$RULES_MANIFEST" ]; then
        log "No rules manifest at $(display_path "$RULES_MANIFEST") -- every rule fanned out, none retired, adopt not offered"
    else
        manifest_out=""
        if ! manifest_out=$(read_rules_manifest "$RULES_MANIFEST" 2>&1); then
            log_error "Cannot read the rules manifest $(display_path "$RULES_MANIFEST"): $manifest_out -- every rule fanned out, none retired"
            write_summary ERROR "claude rules" "cannot read rules manifest"
            MANIFEST_FAILED=true
        elif [ "$manifest_out" = "header-bad" ]; then
            log_warn "Rules manifest $(display_path "$RULES_MANIFEST"): the first line is not \"$RULES_MANIFEST_HEADER\" -- every rule fanned out, none retired, adopt not offered"
            write_summary ACTION "" "Run aitools to rebuild ~/.aitools/rules and its manifest"
        else
            MANIFEST_OK=true
            while IFS= read -r m_line; do
                [ -n "$m_line" ] || continue
                case "$m_line" in
                    "invalid$TAB"*)
                        log_warn "Rules manifest $(display_path "$RULES_MANIFEST"): line ignored: ${m_line#invalid"$TAB"}" ;;
                    "rule$TAB"*)
                        m_rest="${m_line#rule"$TAB"}"
                        m_name="${m_rest%%"$TAB"*}"
                        m_src="${m_rest#*"$TAB"}"
                        if [ "$m_src" = "retired" ]; then
                            RETIRED_NAMES="${RETIRED_NAMES}${m_name}
"
                            RETIRED_LC="${RETIRED_LC}$(lower_name "$m_name")
"
                        else
                            RULE_SOURCE_OF="${RULE_SOURCE_OF}$(lower_name "$m_name")${TAB}${m_src}
"
                        fi ;;
                esac
            done <<< "$manifest_out"
        fi
    fi
fi

# Source files: every *.md in ~/.aitools/rules (flat, the deploy-harness
# contract) that the manifest does not retire. The glob skips hidden files.
RULE_SOURCES=""   # paths, one per line
RULE_BROKEN=""    # dangling symlinks: failed in the deploy loop
if [ "$RULES_GO" = "true" ]; then
    for rule_src in "$RULES_SRC"/*; do
        if [ ! -e "$rule_src" ] && [ ! -L "$rule_src" ]; then
            continue   # the unexpanded glob of an empty directory
        fi
        rule_base=$(basename "$rule_src")
        case "$(rule_name_kind "$rule_base")" in
            rule) ;;
            backup|hidden) continue ;;
            *) log "Ignoring non-rule file in harness rules: $rule_base (only *.md is fanned out)"
               continue ;;
        esac
        if in_list "$(lower_name "$rule_base")" "$RETIRED_LC"; then
            log "Not fanned out: $rule_base (retired in the rules manifest)"
            continue
        fi
        if [ -L "$rule_src" ] && [ ! -e "$rule_src" ]; then
            RULE_BROKEN="${RULE_BROKEN}${rule_base}
"
            continue
        fi
        if [ ! -f "$rule_src" ]; then
            log "Ignoring non-file in harness rules: $rule_base"
            continue
        fi
        RULE_SOURCES="${RULE_SOURCES}${rule_src}
"
    done

    if [ -z "$RULE_SOURCES" ] && [ -z "$RULE_BROKEN" ] && [ -z "$RETIRED_NAMES" ]; then
        log "No rules in $(display_path "$RULES_SRC") -- skipping"
        # An unreadable manifest already wrote this tool's ERROR row
        if [ "$MANIFEST_FAILED" != "true" ]; then
            write_summary OK "claude rules" "n/a (no harness rules)"
        fi
        RULES_GO=false
    elif [ "$DRY_RUN" != "true" ]; then
        backup_dir "$RULES_DEST"
        if ! mkdir -p "$RULES_DEST"; then
            log_error "Cannot create $(display_path "$RULES_DEST")"
            write_summary ERROR "claude rules" "cannot create rules dir"
            RULES_GO=false
        fi
    fi
fi

if [ "$RULES_GO" = "true" ]; then
    deploy_tracker_init
    ERRORS_BEFORE_RULES=$ERRORS
    if [ "$MANIFEST_FAILED" = "true" ]; then
        deploy_tracker_record "failed" "claude rules" ".aitools-rules-manifest"
    fi
    while IFS= read -r broken_name; do
        [ -n "$broken_name" ] || continue
        log_error "Failed: $broken_name: dangling symlink in $(display_path "$RULES_SRC")"
        deploy_tracker_record "failed" "claude rules" "$broken_name"
    done <<< "$RULE_BROKEN"

    # Deploy loop. The list is read on fd 3: stdin stays the terminal, so the
    # review menu can prompt (a loop fed on stdin never prompts). [x]abort exits
    # 2 from the library here: no "claude rules" row is written, and the
    # calling installer or aitools loop records "script failed (exit 2)".
    RULE_DESTS=""      # deployed names, one per line
    RULE_DESTS_LC=""   # the same, lower-cased
    while IFS= read -r rule_src <&3; do
        [ -n "$rule_src" ] || continue
        rule_name=$(basename "$rule_src")
        rule_lc=$(lower_name "$rule_name")
        # Two harness rules whose names differ only in case (possible on a
        # case-sensitive file system) map to one file here: the first wins
        if in_list "$rule_lc" "$RULE_DESTS_LC"; then
            log_error "Skipped duplicate: $rule_name (a harness rule whose name differs only in case was already deployed)"
            deploy_tracker_record "failed" "claude rules" "$rule_name"
            continue
        fi
        RULE_DESTS="${RULE_DESTS}${rule_name}
"
        RULE_DESTS_LC="${RULE_DESTS_LC}${rule_lc}
"
        rule_source=""
        _rule_adopt_path=""
        if [ "$MANIFEST_OK" = "true" ]; then
            rule_source=$(rule_manifest_source "$rule_name")
            if [ -n "$rule_source" ]; then
                _rule_adopt_path=$(rule_adopt_target "$rule_name" "$rule_source")
            fi
        fi
        log_detail "claude rules: $rule_name source=${rule_source:-unknown} adopt=${_rule_adopt_path:-none}"
        _rule_content=""
        if ! _rule_content=$(cat "$rule_src"); then
            log_error "Cannot read harness rule $(display_path "$rule_src")"
            deploy_tracker_record "failed" "claude rules" "$rule_name"
            continue
        fi
        deploy_managed_file "$_rule_content" "$RULES_DEST/$rule_name" "claude rules" "$rule_name" "$_rule_adopt_path"
        case "$MANAGED_FILE_RESULT" in
            created|updated|verified|"accept & adopt"|skipped|failed)
                # The library wrote LOCAL and the adopt target itself (it commits
                # and pushes a dotprofile adopt target, N-Q2); the tracker records
                # every outcome (failed -> ERROR row, skipped -> WARN row).
                ;;
            *)
                log_error "Unexpected deploy result for ${rule_name}: $MANAGED_FILE_RESULT"
                MANAGED_FILE_RESULT="failed" ;;
        esac
        deploy_tracker_record "$MANAGED_FILE_RESULT" "claude rules" "$rule_name"
    done 3<<< "$RULE_SOURCES"

    # Retired rules: the copy in ~/.claude/rules is backed up and removed when
    # it is this fan-out's copy -- the same text as the harness copy or as a
    # backup deploy-harness made when it retired the rule. Any other file of
    # that name may be the user's own: kept, with a warning.
    RM_KEPT=""
    while IFS= read -r rm_name; do
        [ -n "$rm_name" ] || continue
        rm_lc=$(lower_name "$rm_name")
        # Deployed this run under a name that differs only in case
        if in_list "$rm_lc" "$RULE_DESTS_LC"; then continue; fi
        # The copy in ~/.claude/rules, found case-insensitively (a case-sensitive
        # file system may hold it as Gone.md for the manifest's gone.md)
        rm_path=""
        for rm_existing in "$RULES_DEST"/*; do
            [ -f "$rm_existing" ] || continue
            if [ "$(lower_name "$(basename "$rm_existing")")" = "$rm_lc" ]; then
                rm_path="$rm_existing"
                break
            fi
        done
        [ -n "$rm_path" ] || continue
        rm_file=$(basename "$rm_path")
        if [ ! -r "$rm_path" ]; then
            log_error "Cannot read $(display_path "$rm_path") -- retired rule not removed"
            deploy_tracker_record "failed" "claude rules" "$rm_file"
            continue
        fi
        rm_why=""
        for rm_cand in "$RULES_SRC/$rm_name" "$RULES_SRC/$rm_name".bak.*; do
            [ -f "$rm_cand" ] || continue
            rm_rc=0
            rule_text_equal "$rm_path" "$rm_cand" || rm_rc=$?
            if [ "$rm_rc" -eq 0 ]; then
                rm_why="same text as $(basename "$rm_cand")"
                break
            fi
            if [ "$rm_rc" -ne 1 ]; then
                log_warn "Cannot compare $(display_path "$rm_path") with $(display_path "$rm_cand")"
            fi
        done
        if [ -z "$rm_why" ]; then
            log_warn "Kept $rm_file: the rules manifest retires $rm_name, but this file matches no harness copy (it may be your own) -- Claude Code still loads it; delete it if it is an old fan-out copy"
            RM_KEPT="${RM_KEPT:+$RM_KEPT, }$rm_file"
            continue
        fi
        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY RUN] Would back up and remove $rm_file (retired rule; $rm_why)"
            continue
        fi
        backup_file "$rm_path"
        # Belt and braces: remove only when a backup with the same text exists
        # beside it (a backup step that reports success without a copy must not
        # lose the file)
        rm_backed=false
        if [ "$BACKUP_FILE_OK" = "true" ]; then
            for rm_bak in "$rm_path".bak.*; do
                [ -f "$rm_bak" ] || continue
                if rule_text_equal "$rm_path" "$rm_bak"; then rm_backed=true; break; fi
            done
        fi
        if [ "$rm_backed" != "true" ]; then
            log_error "Not removed: $rm_file (retired rule): backup failed"
            deploy_tracker_record "failed" "claude rules" "$rm_file"
            continue
        fi
        if ! rm -f "$rm_path" || [ -e "$rm_path" ]; then
            log_error "Cannot remove $(display_path "$rm_path") (retired rule)"
            deploy_tracker_record "failed" "claude rules" "$rm_file"
            continue
        fi
        log "Removed $rm_file (retired rule; $rm_why; backup kept)"
        deploy_tracker_record "removed" "claude rules" "$rm_file"
    done <<< "$RETIRED_NAMES"
    if [ -n "$RM_KEPT" ]; then
        write_summary ACTION "" "Claude Code still loads retired rules in ~/.claude/rules: $RM_KEPT -- delete them unless you wrote them"
    fi

    if [ "$DRY_RUN" = "true" ]; then
        if [ "$_DT_FAILED" -gt 0 ]; then
            write_summary ERROR "claude rules" "$_DT_FAILED failed (dry run)"
        else
            write_summary OK "claude rules" "dry run (no files written)"
        fi
    else
        # Preserved: rules in ~/.claude/rules not fanned out this run
        for existing in "$RULES_DEST"/*; do
            [ -f "$existing" ] || continue
            exist_name=$(basename "$existing")
            case "$(rule_name_kind "$exist_name")" in
                rule) ;;
                *) continue ;;
            esac
            if ! in_list "$(lower_name "$exist_name")" "$RULE_DESTS_LC"; then
                log "Preserved unmanaged rule: $exist_name"
                deploy_tracker_record "preserved" "claude rules" "$exist_name"
            fi
        done

        # Post-write validation: each deployed file is non-empty (a file whose
        # deploy failed is already reported; the library left it as it was)
        while IFS= read -r rule_name; do
            [ -n "$rule_name" ] || continue
            if [ -f "$RULES_DEST/$rule_name" ] && [ ! -s "$RULES_DEST/$rule_name" ]; then
                log_error "Validation failed: $rule_name is empty after deploy"
            fi
        done <<< "$RULE_DESTS"

        if [ "$_DT_FAILED" -gt 0 ]; then
            # deploy_tracker_summary writes the ERROR row ("N failed")
            deploy_tracker_summary "claude rules"
            log "Rules: $DEPLOY_TRACKER_TEXT, $_DT_PRESERVED preserved in $(display_path "$RULES_DEST")"
        elif [ "$ERRORS" -eq "$ERRORS_BEFORE_RULES" ]; then
            deploy_tracker_summary "claude rules"
            log_ok "Rules: $DEPLOY_TRACKER_TEXT, $_DT_PRESERVED preserved in $(display_path "$RULES_DEST")"
        else
            write_summary ERROR "claude rules" "validation failed"
        fi
    fi
fi
````

#### B4 -- `scripts/setup-user-claude.ps1`, header (CRLF file)

old_string (B4):

````text
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md matching <userRepoPath>/claude/rules/ (additive deploy)
# Preserved: ~/.claude/rules/ files not in user repo source

param(
````

new_string (B4):

````text
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md fanned out from ~/.aitools/rules (additive; the
#   copy of a rule the rules manifest retires is backed up and removed)
# Preserved: ~/.claude/rules/ files not in ~/.aitools/rules
# Rules come from ~/.aitools/rules only (deploy-harness fills it: run it first);
# the dotprofile's claude/rules reaches Claude Code through it.

param(
````

#### B5 -- `scripts/setup-user-claude.ps1`, script directory (outside the extracted rules spans)

old_string (B5):

````text
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"
````

new_string (B5):

````text
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"
# The directory this script runs from (aitools scripts/ on the dev path, the
# dotprofile's deploy/ for the generated copy): the rules fan-out derives the
# aitools checkout from it (SCRIPT_DIR in setup-user-claude.sh)
$claudeScriptDir = $PSScriptRoot
````

#### B7 -- `scripts/setup-user-claude.ps1`, rules source span (CRLF file)

old_string (B7):

````text
# Deploy user rules: additive (add/update managed, preserve unmanaged, log diffs).
$rulesSrc = ""
if ($userRepoPath) {
    $candidateRules = Join-Path $userRepoPath "claude\rules"
    if (Test-Path $candidateRules) {
        $rulesSrc = $candidateRules
    }
}

$rulesDest = Join-Path $claudeDir "rules"

# --- BEGIN rules deploy logic (extracted by build-deploy) ---
````

new_string (B7):

````text
# Rules fan-out: .aitools\rules -> .claude\rules. deploy-harness fills
# .aitools\rules from aitools shared/rules, aitools .claude/rules and the
# dotprofile's claude/rules (first source wins) and writes its rules manifest
# (PR #100 contract). Claude Code gets every rule there except the ones the
# manifest retires (commander decisions 2026-10-22): *.md only, *.bak.* and
# hidden files skipped, names compared case-insensitively. The dotprofile's
# claude/rules is not read here. Additive: managed files updated, unmanaged
# files preserved; the copy of a retired rule is backed up and removed when it
# matches a harness copy. Adopt target: the repo file the manifest names as the
# rule's source, when it is on this machine. Parity: setup-user-claude.sh.
$rulesSrc = Join-Path (Join-Path $env:USERPROFILE ".aitools") "rules"
$rulesDest = Join-Path $claudeDir "rules"
$rulesManifest = Join-Path $rulesSrc ".aitools-rules-manifest"
# The aitools checkout this script runs from: adopt targets of shared and
# aitools rules. Only a git checkout counts: the generated deploy/ copy runs
# from the dotprofile's deploy/ directory, and a package payload (git archive,
# read-only) has no .git; adopt is then offered for dotprofile rules only.
$rulesAitoolsRepo = ""
if ($claudeScriptDir) {
    $rulesRepoCand = Split-Path -Parent $claudeScriptDir
    if ((Test-Path -LiteralPath (Join-Path (Join-Path $rulesRepoCand "scripts") "aitools-lib.ps1") -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path (Join-Path $rulesRepoCand "shared") "claude-shared.md") -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $rulesRepoCand ".git"))) {
        $rulesAitoolsRepo = $rulesRepoCand
    }
}

# --- BEGIN rules deploy logic (extracted by build-deploy) ---
````

#### B6 -- `scripts/setup-user-claude.ps1`, rules logic span (CRLF file; lines 329-446 at #112 head, sha256 with LF endings `64e8e8f4a028e3340e96f5ad1ade6ced512fedeb67510f03567be99edf1b5b7c`)

B6 and B7 do not overlap; apply them in either order.

old_string (B6):

````text
if ($rulesSrc) {
    $sourceRules = Get-ChildItem -Path $rulesSrc -Filter "*.md" -File -ErrorAction Stop
    if (-not $sourceRules -or $sourceRules.Count -eq 0) {
        Log "User repo claude/rules/ exists but has no .md files -- skipping"
    } elseif ($DryRun) {
        $existingCount = 0
        if (Test-Path $rulesDest) {
            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
            if ($existingFiles) { $existingCount = $existingFiles.Count }
        }
        Log "[DRY RUN] $rulesDest`: additive deploy"
        Log "  Source: $rulesSrc ($($sourceRules.Count) rule files)"
        Log "  Existing: $existingCount rule files"
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            if (Test-Path $destFile) {
                try {
                    $oldContent = Get-Content $destFile -Raw -ErrorAction Stop
                    $newContent = Get-Content $rf.FullName -Raw -ErrorAction Stop
                } catch {
                    LogWarn "Cannot compare $($rf.Name): $_"
                    Log "  Would update (cannot compare): $($rf.Name)"
                    continue
                }
                if ($oldContent -eq $newContent) {
                    Log "  Would skip (unchanged): $($rf.Name)"
                } else {
                    Log "  Would update (changed): $($rf.Name)"
                }
            } else {
                Log "  Would add (new): $($rf.Name)"
            }
        }
        # Show preserved files
        if (Test-Path $rulesDest) {
            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
            foreach ($ef in $existingFiles) {
                $srcMatch = Join-Path $rulesSrc $ef.Name
                if (-not (Test-Path $srcMatch)) {
                    Log "  Would preserve (unmanaged): $($ef.Name)"
                }
            }
        }
    } else {
        Backup-Dir -DirPath $rulesDest
        if (-not (Test-Path $rulesDest)) {
            try {
                New-Item -ItemType Directory -Path $rulesDest -Force -ErrorAction Stop | Out-Null
            } catch {
                LogError "Cannot create $rulesDest ($_)"
                Write-Summary "ERROR" "claude rules" "cannot create rules dir"
                exit 1
            }
        }

        Initialize-DeployTracker
        $errorsBefore = $errors
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            # Adopt target: the dotprofile rule (the file deployed from). Empty
            # in the MDM deploy script (no user repo): adopt and merge not offered.
            $ruleAdoptPath = ""
            if ($userRepoPath) { $ruleAdoptPath = Join-Path (Join-Path $userRepoPath "claude\rules") $rf.Name }

            try {
                $ruleContent = Get-Content $rf.FullName -Raw -ErrorAction Stop
            } catch {
                LogError "Cannot read source rule $($rf.Name): $_"
                Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rf.Name
                continue
            }
            $ruleResult = Deploy-ManagedFile -Content $ruleContent -DestPath $destFile -ToolName "claude rules" -ItemName $rf.Name -AdoptPath $ruleAdoptPath

            if ($ruleResult -in @("created", "updated", "verified", "accept & adopt", "skipped", "failed")) {
                # The library wrote LOCAL and the adopt target itself; the
                # tracker records every outcome (failed -> ERROR row).
            }
            Record-DeployOutcome -Outcome $ruleResult -ToolName "claude rules" -ItemName $rf.Name
            # After accept & adopt or merge & adopt the library commits that one
            # dotprofile rule and pushes it (Invoke-DotprofileCommitPush, N-Q2;
            # commander confirmed 2026-10-21, contract item #11). No commit here.
        }

        # Log preserved files (in target but not in source)
        if (Test-Path $rulesDest) {
            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
            foreach ($ef in $existingFiles) {
                $srcMatch = Join-Path $rulesSrc $ef.Name
                if (-not (Test-Path $srcMatch)) {
                    Log "Preserved unmanaged rule: $($ef.Name)"
                    Record-DeployOutcome -Outcome "preserved" -ToolName "claude rules" -ItemName $ef.Name
                }
            }
        }

        # Post-write validation: each deployed file is non-empty (a file whose
        # deploy failed is already reported; the library left it as it was)
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            if ((Test-Path $destFile) -and (Get-Item $destFile).Length -eq 0) {
                LogError "Validation failed: $($rf.Name) is empty after deploy"
            }
        }

        if ($script:dtFailed -gt 0) {
            # Write-DeployTrackerSummary writes the ERROR row ("N failed")
            Write-DeployTrackerSummary -ToolName "claude rules"
            Log "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
        } elseif ($errors -eq $errorsBefore) {
            Write-DeployTrackerSummary -ToolName "claude rules"
            LogOk "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
        } else {
            Write-Summary "ERROR" "claude rules" "validation failed"
        }
    }
} else {
    Log "No user rules to deploy (no claude/rules/ in user repo)"
}
````

new_string (B6):

````text
# The repo file that a rule from Source (a rules manifest source) came from, or
# "" when that file is not on this machine (adopt and merge are then not
# offered). A dotprofile adopt target is committed and pushed by the library
# (N-Q2); an aitools one is a working-tree change. Parity: rule_adopt_target in
# setup-user-claude.sh.
function Get-RuleAdoptTarget([string]$Name, [string]$Source) {
    $target = ""
    if ($Source -ceq "shared" -and $rulesAitoolsRepo) {
        $target = Join-Path (Join-Path (Join-Path $rulesAitoolsRepo "shared") "rules") $Name
    } elseif ($Source -ceq "aitools" -and $rulesAitoolsRepo) {
        $target = Join-Path (Join-Path (Join-Path $rulesAitoolsRepo ".claude") "rules") $Name
    } elseif ($Source -ceq "dotprofile" -and $userRepoPath) {
        $target = Join-Path (Join-Path (Join-Path $userRepoPath "claude") "rules") $Name
    }
    if ($target -and (Test-Path -LiteralPath $target -PathType Leaf)) { return $target }
    return ""
}

# 0 when files A and B hold the same bytes apart from trailing CR/LF
# (Deploy-ManagedFile normalizes trailing newlines), 1 when they differ, 2 when
# one cannot be read. Parity: rule_text_equal in setup-user-claude.sh.
function Test-RuleTextEqual([string]$A, [string]$B) {
    try {
        # Latin1 maps each byte to one char: a byte comparison, as the .sh does
        $ta = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($A))
        $tb = [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($B))
    } catch {
        LogDetail "claude rules: cannot read $A or ${B}: $_"
        return 2
    }
    if (($ta -replace '[\r\n]+\z', '') -ceq ($tb -replace '[\r\n]+\z', '')) { return 0 }
    return 1
}

$rulesGo = $false
$rulesEntries = @()
if (-not (Test-Path -LiteralPath $rulesSrc -PathType Container)) {
    Log "No harness rules at $rulesSrc (deploy-harness has not run) -- skipping"
    Write-Summary "OK" "claude rules" "n/a (no harness rules)"
} else {
    try {
        $rulesEntries = @(Get-ChildItem -LiteralPath $rulesSrc -ErrorAction Stop | Sort-Object Name)
        $rulesGo = $true
    } catch {
        LogError "Cannot list $rulesSrc -- $_"
        Write-Summary "ERROR" "claude rules" "cannot read harness rules"
    }
}

# Rules manifest: each rule's source (adopt target) and the retired names.
# Without one (deploy-harness before PR #100) every rule is fanned out, none
# is retired and adopt is not offered.
$manifestOk = $false
$manifestFailed = $false   # unreadable: counted as a failed item, so the final row is ERROR
$ruleSourceOf = @{}   # name -> source; PowerShell hashtable keys are case-insensitive
$retiredNames = New-Object System.Collections.Generic.List[string]
$retiredSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
if ($rulesGo) {
    if (-not (Test-Path -LiteralPath $rulesManifest -PathType Leaf)) {
        Log "No rules manifest at $rulesManifest -- every rule fanned out, none retired, adopt not offered"
    } else {
        $manifest = $null
        try {
            $manifest = Read-RulesManifest $rulesManifest
        } catch {
            LogError "Cannot read the rules manifest ${rulesManifest}: $_ -- every rule fanned out, none retired"
            Write-Summary "ERROR" "claude rules" "cannot read rules manifest"
            $manifestFailed = $true
        }
        if ($manifest -and $manifest.Status -eq "header-bad") {
            LogWarn "Rules manifest ${rulesManifest}: the first line is not `"$rulesManifestHeader`" -- every rule fanned out, none retired, adopt not offered"
            Write-Summary "ACTION" "" "Run aitools to rebuild ~/.aitools/rules and its manifest"
        } elseif ($manifest) {
            $manifestOk = $true
            foreach ($bad in $manifest.Invalid) { LogWarn "Rules manifest ${rulesManifest}: line ignored: $bad" }
            foreach ($r in $manifest.Rules) {
                if ($r.Source -ceq "retired") {
                    $retiredNames.Add($r.Name); [void]$retiredSet.Add($r.Name)
                } else {
                    $ruleSourceOf[$r.Name] = $r.Source
                }
            }
        }
    }
}

# Source files: every *.md in .aitools\rules (flat, the deploy-harness
# contract) that the manifest does not retire. Hidden files are skipped.
$ruleSources = @()
$ruleBroken = @()   # dangling symlinks: failed in the deploy loop
if ($rulesGo) {
    foreach ($entry in $rulesEntries) {
        $kind = Get-RuleNameKind $entry.Name
        if ($kind -eq "backup" -or $kind -eq "hidden") { continue }
        if ($kind -ne "rule") {
            Log "Ignoring non-rule file in harness rules: $($entry.Name) (only *.md is fanned out)"
            continue
        }
        if ($retiredSet.Contains($entry.Name)) {
            Log "Not fanned out: $($entry.Name) (retired in the rules manifest)"
            continue
        }
        if ($entry.LinkType) {
            # Test-Path is true for a dangling link on pwsh 7; check the final target
            $linkOk = $false
            try {
                $linkOk = [bool]$entry.ResolveLinkTarget($true).Exists
            } catch {
                LogDetail "claude rules: cannot resolve the link $($entry.FullName): $_"
                $linkOk = $false
            }
            if (-not $linkOk) { $ruleBroken += $entry.Name; continue }
        }
        if ($entry.PSIsContainer) { Log "Ignoring non-file in harness rules: $($entry.Name)"; continue }
        $ruleSources += $entry
    }

    if ($ruleSources.Count -eq 0 -and $ruleBroken.Count -eq 0 -and $retiredNames.Count -eq 0) {
        Log "No rules in $rulesSrc -- skipping"
        # An unreadable manifest already wrote this tool's ERROR row
        if (-not $manifestFailed) { Write-Summary "OK" "claude rules" "n/a (no harness rules)" }
        $rulesGo = $false
    } elseif (-not $DryRun) {
        Backup-Dir -DirPath $rulesDest
        if (-not (Test-Path -LiteralPath $rulesDest -PathType Container)) {
            $mkdirError = ""
            try {
                New-Item -ItemType Directory -Path $rulesDest -Force -ErrorAction Stop | Out-Null
            } catch {
                $mkdirError = "$_"
            }
            # New-Item -Force can return without an error when a file is in
            # the way: check the result (parity with mkdir -p in the .sh)
            if (-not (Test-Path -LiteralPath $rulesDest -PathType Container)) {
                if (-not $mkdirError) { $mkdirError = "not a directory" }
                LogError "Cannot create $rulesDest ($mkdirError)"
                Write-Summary "ERROR" "claude rules" "cannot create rules dir"
                $rulesGo = $false
            }
        }
    }
}

if ($rulesGo) {
    Initialize-DeployTracker
    $errorsBefore = $errors
    if ($manifestFailed) {
        Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName ".aitools-rules-manifest"
    }
    foreach ($brokenName in $ruleBroken) {
        LogError "Failed: ${brokenName}: dangling symlink in $rulesSrc"
        Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $brokenName
    }

    # Deploy loop. [x]abort exits 2 from the library here: no "claude rules" row
    # is written, and the calling installer or aitools loop records
    # "script failed (exit 2)".
    $ruleDests = New-Object System.Collections.Generic.List[string]   # deployed names
    $ruleDestsLc = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($src in $ruleSources) {
        $ruleName = $src.Name
        # Two harness rules whose names differ only in case (possible on a
        # case-sensitive file system) map to one file here: the first wins
        if ($ruleDestsLc.Contains($ruleName)) {
            LogError "Skipped duplicate: $ruleName (a harness rule whose name differs only in case was already deployed)"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $ruleName
            continue
        }
        $ruleDests.Add($ruleName); [void]$ruleDestsLc.Add($ruleName)
        $ruleSource = ""
        $ruleAdoptPath = ""
        if ($manifestOk -and $ruleSourceOf.ContainsKey($ruleName)) {
            $ruleSource = $ruleSourceOf[$ruleName]
            $ruleAdoptPath = Get-RuleAdoptTarget $ruleName $ruleSource
        }
        $ruleSourceShown = if ($ruleSource) { $ruleSource } else { "unknown" }
        $ruleAdoptShown = if ($ruleAdoptPath) { $ruleAdoptPath } else { "none" }
        LogDetail "claude rules: $ruleName source=$ruleSourceShown adopt=$ruleAdoptShown"
        try {
            $ruleContent = [System.IO.File]::ReadAllText($src.FullName, [System.Text.UTF8Encoding]::new($false))
        } catch {
            LogError "Cannot read harness rule $($src.FullName): $_"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $ruleName
            continue
        }
        $ruleResult = Deploy-ManagedFile -Content $ruleContent -DestPath (Join-Path $rulesDest $ruleName) -ToolName "claude rules" -ItemName $ruleName -AdoptPath $ruleAdoptPath
        switch ($ruleResult) {
            { $_ -in @("created", "updated", "verified", "accept & adopt", "skipped", "failed") } {
                # The library wrote LOCAL and the adopt target itself (it commits
                # and pushes a dotprofile adopt target, N-Q2); the tracker records
                # every outcome (failed -> ERROR row, skipped -> WARN row).
            }
            default {
                LogError "Unexpected deploy result for ${ruleName}: $ruleResult"
                $ruleResult = "failed"
            }
        }
        Record-DeployOutcome -Outcome $ruleResult -ToolName "claude rules" -ItemName $ruleName
    }

    # Retired rules: the copy in .claude\rules is backed up and removed when it
    # is this fan-out's copy -- the same text as the harness copy or as a backup
    # deploy-harness made when it retired the rule. Any other file of that name
    # may be the user's own: kept, with a warning.
    $rmKept = New-Object System.Collections.Generic.List[string]
    foreach ($rmName in $retiredNames) {
        # Deployed this run under a name that differs only in case
        if ($ruleDestsLc.Contains($rmName)) { continue }
        # The copy in .claude\rules, found case-insensitively (a case-sensitive
        # file system may hold it as Gone.md for the manifest's gone.md)
        $rmPath = ""
        if (Test-Path -LiteralPath $rulesDest -PathType Container) {
            try {
                foreach ($f in @([System.IO.Directory]::GetFiles($rulesDest) | Sort-Object -CaseSensitive)) {
                    if ([string]::Equals([System.IO.Path]::GetFileName($f), $rmName, [System.StringComparison]::OrdinalIgnoreCase)) { $rmPath = $f; break }
                }
            } catch {
                LogWarn "Cannot list $rulesDest for retired rule $rmName -- $_"
            }
        }
        if (-not $rmPath) { continue }
        $rmFile = [System.IO.Path]::GetFileName($rmPath)
        try {
            $null = [System.IO.File]::ReadAllBytes($rmPath)
        } catch {
            LogError "Cannot read $rmPath -- retired rule not removed: $_"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        $rmCands = New-Object System.Collections.Generic.List[string]
        $rmCands.Add((Join-Path $rulesSrc $rmName))
        try {
            $rmBaks = @([System.IO.Directory]::GetFiles($rulesSrc) |
                Where-Object { [System.IO.Path]::GetFileName($_).StartsWith("$rmName.bak.", [System.StringComparison]::Ordinal) } |
                Sort-Object -Property { [System.IO.Path]::GetFileName($_) } -CaseSensitive)
            foreach ($b in $rmBaks) { $rmCands.Add($b) }
        } catch {
            LogWarn "Cannot list the backups of $rmName in ${rulesSrc}: $_"
        }
        $rmWhy = ""
        foreach ($rmCand in $rmCands) {
            if (-not (Test-Path -LiteralPath $rmCand -PathType Leaf)) { continue }
            $rmRc = Test-RuleTextEqual $rmPath $rmCand
            if ($rmRc -eq 0) {
                $rmWhy = "same text as $([System.IO.Path]::GetFileName($rmCand))"
                break
            }
            if ($rmRc -ne 1) { LogWarn "Cannot compare $rmPath with $rmCand" }
        }
        if (-not $rmWhy) {
            LogWarn "Kept ${rmFile}: the rules manifest retires $rmName, but this file matches no harness copy (it may be your own) -- Claude Code still loads it; delete it if it is an old fan-out copy"
            $rmKept.Add($rmFile)
            continue
        }
        if ($DryRun) {
            Log "[DRY RUN] Would back up and remove $rmFile (retired rule; $rmWhy)"
            continue
        }
        Backup-File -FilePath $rmPath
        # Belt and braces: remove only when a backup with the same text exists
        # beside it (a backup step that reports success without a copy must not
        # lose the file)
        $rmBacked = $false
        if ($script:BackupFileOk) {
            try {
                foreach ($b in @([System.IO.Directory]::GetFiles($rulesDest) |
                        Where-Object { [System.IO.Path]::GetFileName($_).StartsWith("$rmFile.bak.", [System.StringComparison]::Ordinal) })) {
                    if ((Test-RuleTextEqual $rmPath $b) -eq 0) { $rmBacked = $true; break }
                }
            } catch {
                LogWarn "Cannot list the backups of $rmFile in ${rulesDest}: $_"
            }
        }
        if (-not $rmBacked) {
            LogError "Not removed: $rmFile (retired rule): backup failed"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        try {
            Remove-Item -LiteralPath $rmPath -Force -ErrorAction Stop
        } catch {
            LogError "Cannot remove $rmPath (retired rule) -- $_"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        if (Test-Path -LiteralPath $rmPath) {
            LogError "Cannot remove $rmPath (retired rule): still present"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        Log "Removed $rmFile (retired rule; $rmWhy; backup kept)"
        Record-DeployOutcome -Outcome "removed" -ToolName "claude rules" -ItemName $rmFile
    }
    if ($rmKept.Count -gt 0) {
        Write-Summary "ACTION" "" "Claude Code still loads retired rules in ~/.claude/rules: $($rmKept -join ', ') -- delete them unless you wrote them"
    }

    if ($DryRun) {
        if ($script:dtFailed -gt 0) {
            Write-Summary "ERROR" "claude rules" "$($script:dtFailed) failed (dry run)"
        } else {
            Write-Summary "OK" "claude rules" "dry run (no files written)"
        }
    } else {
        # Preserved: rules in .claude\rules not fanned out this run
        $destEntries = @()
        try {
            $destEntries = @(Get-ChildItem -LiteralPath $rulesDest -File -ErrorAction Stop | Sort-Object Name)
        } catch {
            LogWarn "Cannot list $rulesDest for the preserved report -- $_"
        }
        foreach ($existing in $destEntries) {
            if ((Get-RuleNameKind $existing.Name) -ne "rule") { continue }
            if (-not $ruleDestsLc.Contains($existing.Name)) {
                Log "Preserved unmanaged rule: $($existing.Name)"
                Record-DeployOutcome -Outcome "preserved" -ToolName "claude rules" -ItemName $existing.Name
            }
        }

        # Post-write validation: each deployed file is non-empty (a file whose
        # deploy failed is already reported; the library left it as it was)
        foreach ($ruleName in $ruleDests) {
            $destFile = Join-Path $rulesDest $ruleName
            if ((Test-Path -LiteralPath $destFile -PathType Leaf) -and (Get-Item -LiteralPath $destFile).Length -eq 0) {
                LogError "Validation failed: $ruleName is empty after deploy"
            }
        }

        if ($script:dtFailed -gt 0) {
            # Write-DeployTrackerSummary writes the ERROR row ("N failed")
            Write-DeployTrackerSummary -ToolName "claude rules"
            Log "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
        } elseif ($errors -eq $errorsBefore) {
            Write-DeployTrackerSummary -ToolName "claude rules"
            LogOk "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
        } else {
            Write-Summary "ERROR" "claude rules" "validation failed"
        }
    }
}
````

#### Error-handling audit (Batch B)

| Code | Pattern | Verdict |
|---|---|---|
| `RULES_AITOOLS_REPO=$(cd ... && pwd)` | command substitution can fail | `if !` + `log_warn` + fallback `""` |
| `manifest_out=$(read_rules_manifest ... 2>&1)` | stderr captured, not suppressed | `if !` -> `log_error` + `write_summary ERROR "claude rules" "cannot read rules manifest"` |
| `_rule_content=$(cat "$rule_src")` | read failure | `if !` -> `log_error` + tracker `failed` (ERROR row via `deploy_tracker_summary`) |
| `rule_text_equal ... \|\| rm_rc=$?` | exit captured, not suppressed | 0/1 used, other codes `log_warn` |
| `rm -f "$rm_path"` | removal | `if ! rm -f ... \|\| [ -e ... ]` -> `log_error` + tracker `failed`; preceded by `backup_file` with `BACKUP_FILE_OK` checked **and** a same-text `<file>.bak.*` found beside it (no removal without a backup; review RC-1); same in .ps1 (`$script:BackupFileOk` + `[IO.Directory]::GetFiles` ordinal prefix match + `Test-RuleTextEqual`) |
| ps1 `New-Item -Force` on a path a file occupies | can return without an error | result re-checked with `Test-Path -PathType Container`; `LogError` + `ERROR cannot create rules dir` (found by the nocreate test) |
| manifest unreadable | `log_error` | explicit ERROR row plus tracker `failed` `.aitools-rules-manifest`: the final row is ERROR (review RC-2) |
| `mkdir -p "$RULES_DEST"` | dir create | `log_error` + `write_summary ERROR "claude rules" "cannot create rules dir"`; the step stops, the script reaches its exit footer (no bare `exit 1` mid-script any more) |
| `backup_dir "$RULES_DEST"` | non-fatal by policy (config-file-safety.md "Backup failures are non-fatal"); per-file backups happen in the lib | unchanged from today |
| ps1 `Get-ChildItem -ErrorAction Stop` (sources, preserved scan) | | in try; catch `LogError` + ERROR row / `LogWarn` |
| ps1 `ResolveLinkTarget` | | try; catch `LogDetail` + treated as dangling (`failed`) |
| ps1 `[IO.Directory]::GetFiles`, `ReadAllBytes`, `ReadAllText`, `Remove-Item -ErrorAction Stop`, `New-Item -ErrorAction Stop` | | each in try; every catch logs (`LogWarn` / `LogError` + tracker `failed` or ERROR row) |
| ps1 `Test-RuleTextEqual` catch | | `LogDetail` + return 2; caller `LogWarn`s on 2 (parity with the .sh) |
| `log_error` for file writes (remove, mkdir) | rule 6 | paired: mkdir with its own `write_summary ERROR`; removal failures with tracker `failed` -> `ERROR|claude rules|N failed` |
| No `2>/dev/null`, `\|\| true`, `-ErrorAction SilentlyContinue` or empty catch | | PASS |
| Return-value contract (interactive-menus.md) | `created, updated, verified, accept & adopt, skipped, failed` handled; `*)` / `default` -> `failed` | PASS; check-post-push step 30 values all present in both files (verified) |

Parity (.sh/.ps1): same rows, same order of checks, same log texts; one
intended difference: a failed `Get-ChildItem` of `~/.claude/rules` in the
preserved scan is a `LogWarn` in PowerShell, which bash's glob cannot hit.

#### Verification (Batch B)

1. `bash -n`, `_validate-ps1.ps1` on both files.
2. Scratch smoke runs (isolated HOME, a temp aitools checkout copied from the
   worktree's `scripts/`, a temp git dotprofile with `profile.json`,
   `config.json` pointing at it, the `.ps1` copy with its OS guard off as
   `tests/claude-mdm` does): dry run, run, rerun, no `~/.aitools/rules`, and on
   a pty (`tests/managed-files/pty-run.py`) accept & adopt of a dotprofile and
   an aitools rule, and `[x]abort`. Expected rows: see the prototype output in
   S3-FanPlan-Planner-notes.md section 2.
3. `bash tests/managed-files/test-managed-files.sh` (its pty case runs the real
   script with input `a\n` in a HOME without `~/.aitools/rules`: the fan-out
   must not prompt), `pwsh ... test-managed-files.ps1`,
   `bash tests/managed-files/test-adopt-push.sh`.
4. `bash tests/claude-mdm/test-claude-mdm.sh` is expected to FAIL one check
   ("MDM sh run: ... rules deployed") until C's commit: record it, do not fix
   it in B.
5. `bash scripts/check-pre-commit.sh` (step 13 WARN expected).
- **Not run in Batch B**: the regression suite (Batch D), Windows native.

### Batch C -- build-deploy MDM counterpart, MDM test, README run order

- **Sub-agent**: S3-FanImpl-C. **Branch**: `feature/claude-rules-fanout`
  (B's branch), pushed to the same PR.
- **Files** (3): `scripts/build-deploy.sh`, `tests/claude-mdm/test-claude-mdm.sh`, `README.md`.
- C1-C11 verified on main, #112 and #111 heads, except C11 on #111 (use C11b
  there). C12 needs #112 (the file is new in #112).

#### C1 -- `scripts/build-deploy.sh`, file header (lines 11-14)

old_string (C1):

````text
# snapshot of every harness source file (~/.aitools); MDM runs it first, before
# setup-user-cursor, whose rules fan-out reads ~/.aitools/rules. Its config.json
````

new_string (C1):

````text
# snapshot of every harness source file (~/.aitools); MDM runs it first, before
# setup-user-claude and setup-user-cursor, whose rules fan-outs read
# ~/.aitools/rules (the only way dotprofile rules reach an endpoint). Its config.json
````

#### C2 -- `scripts/build-deploy.sh`, remove the user-rules embed inputs

old_string (C2):

````text
# --- User rules (embedded as a fallback; see "Embedded dotprofile content") ---
USER_RULE_COUNT=0
declare -a USER_RULE_FILES=()
if [ -d "$_urp/claude/rules" ]; then
    for rf in "$_urp/claude/rules"/*.md; do
        [ -f "$rf" ] || continue
        USER_RULE_FILES+=("$rf")
        USER_RULE_COUNT=$((USER_RULE_COUNT + 1))
    done
fi
if [ "$USER_RULE_COUNT" -gt 0 ]; then
    blog "User rules: $USER_RULE_COUNT files from $_urp/claude/rules"
else
    blog "No user rules in the dotprofile -- the deploy scripts embed none (a machine with the dotprofile still uses its own claude/rules/)"
fi

# --- Embedded dotprofile content: fallbacks, resolved per machine at RUNTIME ---
# deploy/ is committed once and used by every machine of this user, so no machine's
# values are interpolated here (M3 B5: the cross-machine defect, decision 4). The
# generated setup-user-claude.* resolve this machine's profile when they run: from
# the live dotprofile on that machine when it has one (what scripts/ reads), else
# from the build-time template, profile snapshot and rules embedded below.
````

new_string (C2):

````text
# Dotprofile rules are not embedded in setup-user-claude: they reach an endpoint
# through deploy/deploy-harness.* (its snapshot includes <dotprofile>/claude/rules),
# and setup-user-claude fans out ~/.aitools/rules (rules fan-out, 2026-10-22).

# --- Embedded dotprofile content: fallbacks, resolved per machine at RUNTIME ---
# deploy/ is committed once and used by every machine of this user, so no machine's
# values are interpolated here (M3 B5: the cross-machine defect, decision 4). The
# generated setup-user-claude.* resolve this machine's profile when they run: from
# the live dotprofile on that machine when it has one (what scripts/ reads), else
# from the build-time template and profile snapshot embedded below.
````

#### C3 -- `scripts/build-deploy.sh`, `write_resolver_block_bash` comment

old_string (C3):

````text
# write_resolver_block_bash OUT [claude] -- the bash embed block; "claude" adds the
# dotprofile fallbacks (template, profile snapshot, rules).
````

new_string (C3):

````text
# write_resolver_block_bash OUT [claude] -- the bash embed block; "claude" adds the
# dotprofile fallbacks (template, profile snapshot).
````

#### C4 -- `scripts/build-deploy.sh`, embed dir (emitted text, used by every resolver consumer)

old_string (C4):

````text
elif ! mkdir -p "$_AITOOLS_EMBED_DIR/claude" "$_AITOOLS_EMBED_DIR/shared" "$_AITOOLS_EMBED_DIR/rules"; then
````

new_string (C4):

````text
elif ! mkdir -p "$_AITOOLS_EMBED_DIR/claude" "$_AITOOLS_EMBED_DIR/shared"; then
````

#### C5 -- `scripts/build-deploy.sh`, bash embed loop for rules

old_string (C5):

````text
                embed_file_bash "profile.json" "$BUILD_TMP/profile-snapshot.json"
            fi
            for i in $(seq 0 $((USER_RULE_COUNT - 1))); do
                [ "$USER_RULE_COUNT" -gt 0 ] || break
                embed_file_bash "rules/$(basename "${USER_RULE_FILES[$i]}")" "${USER_RULE_FILES[$i]}"
            done
        fi
````

new_string (C5):

````text
                embed_file_bash "profile.json" "$BUILD_TMP/profile-snapshot.json"
            fi
        fi
````

#### C6 -- `scripts/build-deploy.sh`, PowerShell embed loop for rules

old_string (C6):

````text
                embed_file_ps1 "profile.json" "$BUILD_TMP/profile-snapshot.json"
            fi
            for i in $(seq 0 $((USER_RULE_COUNT - 1))); do
                [ "$USER_RULE_COUNT" -gt 0 ] || break
                embed_file_ps1 "rules/$(basename "${USER_RULE_FILES[$i]}")" "${USER_RULE_FILES[$i]}"
            done
        fi
````

new_string (C6):

````text
                embed_file_ps1 "profile.json" "$BUILD_TMP/profile-snapshot.json"
            fi
        fi
````

#### C7 -- `scripts/build-deploy.sh`, generated setup-user-claude.sh: comment and header

old_string (C7):

````text
# Pure extract from scripts/setup-user-claude.sh (template interpolation, footer,
# managed-file deploy, rules logic: no duplicated logic, I6), plus two generated
# parts: the profile/template source on this machine (before the body) and the
# rules fallback (between the rules source selection and the rules logic).
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-claude.sh -- Creates user-level ~/.claude/CLAUDE.md and deploys user rules
# Self-contained (MDM-ready): the profile resolver and build-time copies of the
# dotprofile's CLAUDE.md template, profile snapshot and rules are embedded below.
# This machine's profile is resolved when the script runs, never at build time. On a
# machine with the dotprofile, its live template, profile.json and rules are used
# (as by scripts/setup-user-claude.sh); the embedded copies are the fallback.
# Safe to re-run.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md (additive deploy from the rules source)
# Preserved: ~/.claude/rules/ files not in the rules source
````

new_string (C7):

````text
# Pure extract from scripts/setup-user-claude.sh (template interpolation, footer,
# managed-file deploy, rules fan-out: no duplicated logic, I6), plus one generated
# part: the profile/template source on this machine (before the body). The rules
# come from ~/.aitools/rules, which deploy/deploy-harness.sh fills (run it first).
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-claude.sh -- Creates user-level ~/.claude/CLAUDE.md and fans out the harness rules
# Self-contained (MDM-ready): the profile resolver and build-time copies of the
# dotprofile's CLAUDE.md template and profile snapshot are embedded below.
# This machine's profile is resolved when the script runs, never at build time. On a
# machine with the dotprofile, its live template and profile.json are used
# (as by scripts/setup-user-claude.sh); the embedded copies are the fallback.
# Run deploy-harness.sh first: the rules fan-out reads ~/.aitools/rules, which it fills.
# Safe to re-run.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md fanned out from ~/.aitools/rules (additive; the
#   copy of a rule the rules manifest retires is backed up and removed)
# Preserved: ~/.claude/rules/ files not in ~/.aitools/rules
````

#### C8 -- `scripts/build-deploy.sh`, generated setup-user-claude.sh: drop the rules fallback

old_string (C8):

````text
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN rules deployment' '^# --- BEGIN rules deploy logic'
    if [ "$USER_RULE_COUNT" -gt 0 ]; then
        cat <<'BLOCK'
# --- Rules fallback (generated by build-deploy.sh): the build-time copy when this
# machine has no dotprofile (a dotprofile without claude/rules/ deploys none, as
# scripts/ does; review m3) ---
if [ "$_DP_RC" -ne 0 ] && [ -z "$RULES_SRC" ] && [ -n "$_AITOOLS_EMBED_DIR" ] && [ -d "$_AITOOLS_EMBED_DIR/rules" ]; then
    RULES_SRC="$_AITOOLS_EMBED_DIR/rules"
    log "Rules source: embedded build-time copy (no dotprofile on this machine)"
fi
BLOCK
    fi
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN rules deploy logic' '^# --- END rules deploy logic'
````

new_string (C8):

````text
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN rules deployment' '^# --- BEGIN rules deploy logic'
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN rules deploy logic' '^# --- END rules deploy logic'
````

#### C9 -- `scripts/build-deploy.sh`, generated setup-user-claude.ps1: comment and header

old_string (C9):

````text
# Pure extract from scripts/setup-user-claude.ps1, plus the same two generated parts
# as the .sh (parity).
{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# setup-user-claude.ps1 -- Creates user-level ~/.claude/CLAUDE.md and deploys user rules
# Self-contained (MDM-ready): the profile resolver and build-time copies of the
# dotprofile's CLAUDE.md template, profile snapshot and rules are embedded below.
# This machine's profile is resolved when the script runs, never at build time. On a
# machine with the dotprofile, its live template, profile.json and rules are used
# (as by scripts/setup-user-claude.ps1); the embedded copies are the fallback.
# Safe to re-run.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md (additive deploy from the rules source)
# Preserved: ~/.claude/rules/ files not in the rules source
````

new_string (C9):

````text
# Pure extract from scripts/setup-user-claude.ps1, plus the same generated part as
# the .sh (parity).
{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# setup-user-claude.ps1 -- Creates user-level ~/.claude/CLAUDE.md and fans out the harness rules
# Self-contained (MDM-ready): the profile resolver and build-time copies of the
# dotprofile's CLAUDE.md template and profile snapshot are embedded below.
# This machine's profile is resolved when the script runs, never at build time. On a
# machine with the dotprofile, its live template and profile.json are used
# (as by scripts/setup-user-claude.ps1); the embedded copies are the fallback.
# Run deploy-harness.ps1 first: the rules fan-out reads .aitools\rules, which it fills.
# Safe to re-run.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md fanned out from ~/.aitools/rules (additive; the
#   copy of a rule the rules manifest retires is backed up and removed)
# Preserved: ~/.claude/rules/ files not in ~/.aitools/rules
````

#### C10 -- `scripts/build-deploy.sh`, generated setup-user-claude.ps1: drop the rules fallback

old_string (C10):

````text
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN rules deployment' '^# --- BEGIN rules deploy logic' --crlf
    if [ "$USER_RULE_COUNT" -gt 0 ]; then
        cat <<'BLOCK'
# --- Rules fallback (generated by build-deploy.sh): the build-time copy when this
# machine has no dotprofile (a dotprofile without claude/rules/ deploys none, as
# scripts/ does; review m3) ---
$aitoolsEmbedRules = Join-Path $aitoolsEmbedDir "rules"
if ($aitoolsDpRc -ne 0 -and -not $rulesSrc -and (Test-Path -LiteralPath $aitoolsEmbedRules)) {
    $rulesSrc = $aitoolsEmbedRules
    Log "Rules source: embedded build-time copy (no dotprofile on this machine)"
}
BLOCK
    fi
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN rules deploy logic' '^# --- END rules deploy logic' --crlf
````

new_string (C10):

````text
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN rules deployment' '^# --- BEGIN rules deploy logic' --crlf
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN rules deploy logic' '^# --- END rules deploy logic' --crlf
````

#### C11 -- `scripts/build-deploy.sh`, deploy-harness generator comment (base main or #112)

old_string (C11):

````text
#   - section 2 (dotprofile lookup) is replaced: dotprofile rules are the
#     build-time dotprofile's, as with setup-user-claude's embedded rules;
````

new_string (C11):

````text
#   - section 2 (dotprofile lookup) is replaced: dotprofile rules are the
#     build-time dotprofile's (an endpoint gets them only this way: the
#     setup-user-claude and setup-user-cursor fan-outs read ~/.aitools/rules);
````

C11b -- the same comment when #111 has merged first ("re-pin after #111 merges"):

old_string (C11b):

````text
#   - the "dotprofile lookup" span (section 2) is replaced: dotprofile rules are
#     the build-time dotprofile's, as with setup-user-claude's embedded rules;
````

new_string (C11b):

````text
#   - the "dotprofile lookup" span (section 2) is replaced: dotprofile rules are
#     the build-time dotprofile's (an endpoint gets them only this way: the
#     setup-user-claude and setup-user-cursor fan-outs read ~/.aitools/rules);
````

After C1-C11: `grep -n 'USER_RULE\|EMBED_DIR/rules\|aitoolsEmbedRules' scripts/build-deploy.sh`
finds nothing (verified on the prototype). The four rules markers and both
`extract_between` calls per language stay; the span between `BEGIN rules
deployment` and `BEGIN rules deploy logic` is B2/B6's code, so it is never
empty. The A-19 post-build check (#112: `$EMBED_FINALLY_PS1` must stay the
.ps1's last line) is untouched: nothing is emitted after the exit footer.

#### C12 -- `tests/claude-mdm/test-claude-mdm.sh` (from #112), the MDM .sh run

old_string (C12):

````text
run_mdm_sh mdm-sh
check "MDM sh run: exit 0, created, footer hostname = resolver's ($LIVE_HOST), rules deployed" \
    "[ \"\$(rc_of mdm-sh)\" = 0 ] && row mdm-sh 'OK|claude.md|created' && grep -qF '($LIVE_HOST; profile m1)' \"\$(md_of mdm-sh)\" && grep -qx 'rule one' '$TMP_ROOT/mdm-sh/.claude/rules/r1.md'"
````

new_string (C12):

````text
check "MDM sh dry run without ~/.aitools/rules: claude rules n/a, rules not embedded" \
    "row mdm-sh 'OK|claude rules|n/a (no harness rules)' && ! grep -q 'Rules fallback' '$G/setup-user-claude.sh' && ! grep -q 'Rules fallback' '$G/setup-user-claude.ps1'"
# The rules reach ~/.claude/rules through ~/.aitools/rules, which deploy-harness
# fills first on an endpoint: seed it as deploy-harness would (manifest included)
mkdir -p "$TMP_ROOT/mdm-sh/.aitools/rules"
printf 'rule one\n' > "$TMP_ROOT/mdm-sh/.aitools/rules/r1.md"
printf '# aitools rules manifest v1\nr1.md\tdotprofile\n' > "$TMP_ROOT/mdm-sh/.aitools/rules/.aitools-rules-manifest"
run_mdm_sh mdm-sh
check "MDM sh run: exit 0, created, footer hostname = resolver's ($LIVE_HOST), rules fanned out from ~/.aitools/rules" \
    "[ \"\$(rc_of mdm-sh)\" = 0 ] && row mdm-sh 'OK|claude.md|created' && grep -qF '($LIVE_HOST; profile m1)' \"\$(md_of mdm-sh)\" && grep -qx 'rule one' '$TMP_ROOT/mdm-sh/.claude/rules/r1.md' && row mdm-sh 'OK|claude rules|1 added'"
````

#### C13, C14 -- `README.md`, MDM run order (not protected)

old_string (C13):

````text
Run these from the `deploy/` directory -- self-contained, MDM-ready:

macOS/Linux:
```bash
bash deploy/setup-user-claude.sh        # Claude Code user preferences
````

new_string (C13):

````text
Run these from the `deploy/` directory -- self-contained, MDM-ready.
`deploy-harness` runs first: it fills `~/.aitools`, and the rules fan-outs in
`setup-user-claude` and `setup-user-cursor` read `~/.aitools/rules` (run
before it, they report `n/a (no harness rules)` and deploy no rules):

macOS/Linux:
```bash
bash deploy/deploy-harness.sh           # ~/.aitools: rules, reference, registries, hooks, skills (run first)
bash deploy/setup-user-claude.sh        # Claude Code user preferences + rules
````

old_string (C14):

````text
Windows (PowerShell):
```powershell
.\deploy\setup-user-claude.ps1          # Claude Code user preferences
````

new_string (C14):

````text
Windows (PowerShell):
```powershell
.\deploy\deploy-harness.ps1             # .aitools: rules, reference, registries, hooks, skills (run first)
.\deploy\setup-user-claude.ps1          # Claude Code user preferences + rules
````

#### Error-handling audit (Batch C)

| Code | Verdict |
|---|---|
| C2-C10 delete code and comments only; C4 changes an emitted `mkdir -p` that keeps its `elif !` check | PASS |
| C12 is test code (`set -uo pipefail`, eval'd checks): `mkdir -p` / `printf >` in a temp dir, failures surface as a FAIL of the next check | PASS (test scaffold) |
| No new suppression | PASS |

#### Verification (Batch C)

1. `bash -n scripts/build-deploy.sh tests/claude-mdm/test-claude-mdm.sh`.
2. `bash tests/claude-mdm/test-claude-mdm.sh` and
   `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/claude-mdm/test-claude-mdm.sh`
   (it runs build-deploy under an isolated HOME with a fixture dotprofile).
   Prototype on #112 + A + B + C: 35/0/0 with both bashes.
3. `bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (prototype in a
   real scratch worktree of #112 + main + A-D: 30/0; on a plain `git archive`
   export the 2 "conflict" checks fail with or without the edits, because an
   export is not a git work tree).
4. `bash scripts/check-pre-commit.sh` (step 13 now PASS), `bash scripts/check-pre-push.sh`
   (step 7 builds into a temp dotprofile copy and dry-runs the generated
   `setup-user-claude.sh`: expect exit 0, `Profile source:` lines present, row
   `claude rules n/a (no harness rules)`).
- **Not run in Batch C**: a real endpoint; the commander's rebuild of the live
  dotprofile `deploy/` (it is stale since 825aed4, Checks/Claude findings).

### Batch D -- regression test `tests/rules-fanout/` and CI

- **Sub-agent**: S3-FanImpl-D. **Branch**: `feature/claude-rules-fanout`; marks
  the PR ready when green.
- **Files** (2): `tests/rules-fanout/test-rules-fanout.sh` (new, 100755),
  `.github/workflows/check.yml`.
- **D0 -- new file**: copy verbatim from
  `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanPlan/S3-FanPlan-drafts/tests/rules-fanout/test-rules-fanout.sh`,
  then `chmod +x` (and on Windows `git update-index --chmod=+x`). Prototype
  after the review amendments, on a scratch detached worktree of #112 merged
  with origin/main 568fb5b (contains 9923a3c) + A + B + C + D: 110 passed, 0
  failed, 1 skipped (case-only duplicates on APFS) with bash 5 + pwsh 7.6.3;
  42/0/21 with `/bin/bash` 3.2 `--bash-only`. On a #112 export without
  9923a3c: 107/3/1, the 3 failures being the retired-bracket parity checks
  (PowerShell refuses the removal because Backup-File made no copy: the base
  check above). Before the amendments, against the unedited #112 tree: 48
  passed, 41 failed (the suite detects the missing fan-out).
- **D1, D2 -- `.github/workflows/check.yml`** (base #112; if #116 merged first
  and #112 not yet, insert the same steps after the last test step before
  "Build deploy scripts" in the macos and linux jobs: re-pin):

old_string (D1):

````text
      - name: setup-user-claude dev + MDM tests (macOS /bin/bash 3.2)
        run: AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/claude-mdm/test-claude-mdm.sh
````

new_string (D1):

````text
      - name: setup-user-claude dev + MDM tests (macOS /bin/bash 3.2)
        run: AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/claude-mdm/test-claude-mdm.sh

      - name: Claude rules fan-out tests (bash 5 + pwsh parity)
        run: bash tests/rules-fanout/test-rules-fanout.sh

      - name: Claude rules fan-out tests (macOS /bin/bash 3.2)
        run: AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/rules-fanout/test-rules-fanout.sh --bash-only
````

old_string (D2):

````text
      - name: setup-user-claude dev + MDM tests (bash + pwsh)
        run: bash tests/claude-mdm/test-claude-mdm.sh
````

new_string (D2):

````text
      - name: setup-user-claude dev + MDM tests (bash + pwsh)
        run: bash tests/claude-mdm/test-claude-mdm.sh

      - name: Claude rules fan-out tests (bash + pwsh parity)
        run: bash tests/rules-fanout/test-rules-fanout.sh
````

No Windows step (reviewer non-blocking 2 considered, kept as F4): the suite
is a bash driver whose every case runs `setup-user-claude.sh` first, and that
script refuses Git Bash (OS guard); a native-Windows run needs a `.ps1`-only
mode with its own assertions (the suite asserts on the .sh run and compares
the .ps1 run to it), which is not a few lines in the existing `windows-2022`
job.

#### Test matrix (`tests/rules-fanout/test-rules-fanout.sh`)

| Case | Seed | Expected (sh; ps parity: same exit code, tree, rows) |
|---|---|---|
| lib | source the lib | `removed` DETAIL + count; unknown outcome logged + `failed` + ERROR; `rule_name_kind` case-insensitive; sh/ps rows and kinds equal |
| missing | no `~/.aitools/rules`, `mine.md` deployed | `OK n/a (no harness rules)`, target untouched, no `rules.bak.*`, dotprofile rules not deployed |
| empty | empty `~/.aitools/rules` | `OK n/a (no harness rules)` |
| fanout | manifest shared/aitools/dotprofile; `UP.MD`; `*.bak.*` (any case), `odd.bak.2026.md`, `.hidden.md`, `notes.txt`, `subdir/` | `OK 4 added`; filter; preserved `mine.md`; `only-dp.md` (dotprofile only) not deployed |
| fanout rerun / edited / --force | same HOMEs | `OK 4 verified`; `WARN 1 updated, 3 verified` + backup; `--force` / `-Force` the same |
| retired | retired names: one matching a deploy-harness backup, one still in `~/.aitools/rules`, one user file | `WARN 1 added, 2 removed`; DETAIL `removed:`; backups kept; retired file not fanned out; user file kept + ACTION |
| retired-dry | same, `--dry-run` / `-DryRun` | `WARN dry run (no files written)`, nothing changed, removal previewed |
| retired-bracket (RC-1) | retired `[r].md` matching a deploy-harness backup | `OK 1 added, 1 removed`; `[r].md.bak.*` exists in both trees (tree parity) |
| retired-case | manifest `gone.md` retired, deployed `Gone.md` | removed under its own name (`DETAIL removed: Gone.md`), backup kept |
| manifest-unreadable (RC-2) | `chmod 000` on the manifest (not root, not Git Bash) | exit 1; rules fanned out; `ERROR cannot read rules manifest`, DETAIL `failed: .aitools-rules-manifest`, final row `ERROR 1 failed` |
| nocreate | a file at `~/.claude/rules` | exit 1, `ERROR cannot create rules dir`, file untouched, exit footer reached |
| payload | run from a checkout without `.git` | `source=shared adopt=none`, `source=aitools adopt=none`, dotprofile adopt still mapped (sh and ps) |
| nomanifest | two rules, no manifest | `OK 2 added`, `adopt=none` |
| badheader | `v2` header + a retired line | `WARN 1 added`, nothing removed, ACTION rebuild |
| invalid | bad lines | warned, `WARN 2 added`, unknown source -> `adopt=none` |
| adoptmap | sources with and without repo files | log lines `source=... adopt=<aitools>/shared/rules/s.md`, `.claude/rules/p.md`, `<dotprofile>/claude/rules/d.md`, `z.md ... adopt=none` (sh and ps) |
| adopt (pty) | local edits of `d.md`, `p.md`, input `a\na\n` | dotprofile file written and committed (#103), aitools working-tree file written, DETAIL rows (sh and ps) |
| abort (pty) | local edit of `s.md`, input `x\n` | exit 2, no `claude rules` row, local file kept (sh and ps) |
| bracket | `[x].md` | `OK 1 added`, rerun `OK 1 verified` (LiteralPath) |
| dupcase | `a.md` + `A.md` (case-sensitive FS only) | exit 1, `ERROR 1 failed` |
| broken | dangling symlink | exit 1, `ERROR 1 failed`, other rules deployed |
| unreadable | `chmod 000 ~/.aitools/rules` (not root, not Git Bash) | exit 1, `ERROR cannot read harness rules` |
| MDM (in `tests/claude-mdm`, C12) | generated script, no `~/.aitools/rules`, then seeded | `OK n/a (no harness rules)`; no "Rules fallback" in the generated files; `OK 1 added` |

#### Error-handling audit (Batch D)

Test scaffold, not reusable production code: `cleanup()` uses
`chmod -R ... 2>/dev/null || printf 'warn: ...'` (commented, result reported);
`logged()` uses `2>/dev/null` on a glob that may match nothing, documented in
its comment and turned into "no match". The CI steps have no suppression.

#### Verification (Batch D)

1. `bash -n tests/rules-fanout/test-rules-fanout.sh`; `git ls-files -s tests/rules-fanout` shows 100755.
2. `bash tests/rules-fanout/test-rules-fanout.sh`;
   `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/rules-fanout/test-rules-fanout.sh --bash-only`.
3. `ruby -e 'require "yaml"; YAML.load_file(ARGV[0])' .github/workflows/check.yml`
   (prototype: parses).
4. `bash scripts/check-pre-commit.sh`, `bash scripts/check-pre-push.sh`.
5. Push; wait for CI on the PR; mark ready.
- **Not run in Batch D**: Windows native CI for the fan-out (none exists).

## 7. Docs and protected-file drafts

Protected files are not edited by any batch. Drafts (old -> new) are in
`/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanPlan/S3-FanPlan-drafts/`:

| Draft | File | Base text | Why |
|---|---|---|---|
| `dot-claude/rules/deploy-paths.md` | `.claude/rules/deploy-paths.md` | after #99 | "once it fans out" -> present; drop "and the rules fallback" and the `claude/rules/*.md` embed bullet |
| `dot-cursor/rules/deploy-paths.mdc` | `.cursor/rules/deploy-paths.mdc` | after #99 | twin |
| `dot-claude/rules/managed-file-deployment.md` | `.claude/rules/managed-file-deployment.md` | after #100's draft and #101 | "Rules" bullet: Claude takes every non-retired rule |
| `dot-cursor/rules/managed-file-deployment.mdc` | `.cursor/rules/managed-file-deployment.mdc` | after #101 | twin of the bullet, plus the missing deploy-harness content-source row |
| `dot-claude/rules/config-file-safety.md` | `.claude/rules/config-file-safety.md` | main | the "Directory deployment" header example |
| `dot-claude/rules/hook-rollout.md` | `.claude/rules/hook-rollout.md` | main | the deployment of `hook-lifecycle.md` becomes true |
| `reference/user-repo.md` | `reference/user-repo.md` | after #101 | "User Rules Deployment" and the two other rules mentions |
| `reference/harness.md` | `reference/harness.md` | after #100's draft | "Not detected" bullet; the Claude consumer in the manifest section |
| `reference/managed-file-deployment.md` | `reference/managed-file-deployment.md` | main + #100's draft | tracker `removed`, unknown outcomes, rules content source, "as setup-user-claude does today" |
| `reference/tool-ops-claude-code.md` | `reference/tool-ops-claude-code.md` | main | new item #28 (user-rule loading facts); UNVERIFIED until read with chrome-devtools (web-sources.md) |
| `plans/rules-fanout-claude.md` | this plan | new | protected (`plans/*.md`) |

Not protected, edited by a batch: `README.md` (C13, C14). Not edited, flagged:
`reference/script-standards-detail.md` governed outcome words have no
`removed` (S3-FanPlan-Ref R7): a new governed term goes through `/glossary`
first (Q7); `reference/framework-managed-file-deployment.md:27-28`
("created, updated, or unchanged") is protected and would need the same word.

## 8. Risks

**R1 (first, by the commander's instruction) -- aitools project rules in
every repo's context.** D5 fans out source `aitools` (the 26
`.claude/rules/*.md`). Evidence:
- Claude Code loads every `~/.claude/rules/*.md` in every project, before
  project rules, with no precedence on conflict; a user rule's `paths:` globs
  resolve against the session's primary working directory
  (code.claude.com/docs/en/memory, fetched by S3-FanPlan-Ref with WebFetch
  2026-10-26; not yet re-read with chrome-devtools).
- 17 of the 26 `.claude/rules` files and `shared/rules/scratch.md` have no
  `paths:` (`grep -l '^paths:'` lists 9 + `hook-lifecycle.md`): about 79 KB
  (`wc -c` of those 18 files: 79,048 bytes, roughly 20k tokens) would load in
  every session in every repo; many are titled "(this repo)".
- Inside aitools every project rule loads twice (project + user copy); in a
  worktree or branch that edits a rule, the user copy is stale until the next
  `aitools` run and "Claude may follow either one".
- The 9 scoped rules (`scripts/**`, `deploy/**` ...) would also fire in any
  other repo that has those paths.
- `reference/user-repo.md` "Scope guidance" says user-level rules should be
  universal and project rules belong in the project: D5 contradicts it (the
  draft rewrites the sentence; flagged for the commander).

Variant costed (not planned): **skip source `aitools`** in the Claude fan-out,
as Cursor does. Code: in B3/B6 treat source `aitools` like `retired` for
selection (not fanned out) and add it to the pruning list (the same
byte-match recognition removes the copies a first run made): about +15 lines
per language, no lib change. Tests: +3 cases (aitools not fanned out; earlier
copy pruned; user file of that name kept). Docs: the drafts' "everything"
wording changes to "user-level and shared rules". Effect: ~20k tokens less
per session outside aitools, no double load inside it; costs D5 ("Put aitools
rules in the user space of claude code"). Without a manifest the variant
cannot tell sources apart and would have to fan out nothing (Cursor's
behaviour). Decision needed: Q1.

**R2 -- ordering gap.** Until #106 merges, no entry point fills
`~/.aitools/rules`; merging B alone freezes `~/.claude/rules` (preserved, not
deleted). Mitigation: the merge gate in section 5. On MDM the order is
documentation only (README C13/C14, deploy-paths draft); the live dotprofile
`deploy/` has no `deploy-harness.*` until the commander rebuilds it, so an
endpoint using today's `deploy/` keeps the old embedded rules until then.

**R3 -- first run on this Mac.** With #106 and this plan, the first `aitools`
adds about 28 files to `~/.claude/rules` (26 aitools + 2 shared; the 2
dotprofile rules verify), Claude-explorer 3.4. New files are created without
review (no prompt).

**R4 -- two review menus for one source change.** An edit in a repo rule
reaches the user through deploy-harness (`~/.aitools/rules`) and then
setup-user-claude (`~/.claude/rules`); a local edit in `~/.claude/rules` is
reviewed by setup-user-claude only.

**R5 -- stale harness copy after an adopt.** After accept & adopt in the
fan-out, `~/.aitools/rules/<name>` still holds the old text; the next
deploy-harness run shows a review for it (repo = adopted text, harness copy =
old), where `[a]ccept & adopt` would write the old text back. Not handled in
this plan (Q8).

**R6 -- dotprofile mismatch (Misc R-1).** deploy-harness takes the dotprofile
from `config.json userRepoPath` only (`deploy-harness.sh:117-129`);
setup-user-claude's adopt target uses the resolver (`AITOOLS_USER_REPO_PATH`
first). With the override set, a rule may come from one dotprofile and adopt
into another (only when that one has a file of the same name). Q6.

**R7 -- persistent WARN.** A user's own file with a retired name is kept with
a `log_warn` on every run, so every later OK row of the run turns WARN until
the user deletes or renames it (same as Cursor's #110 behaviour).

**R8 -- the unknown-outcome default branch** turns a caller bug that is
silently dropped today into an ERROR row. Every current caller passes known
values (grep of `deploy_tracker_record` / `Record-DeployOutcome` callers); a
PowerShell function that leaks pipeline output into its return value would
now show up as `failed`. Intended, but it can surface latent bugs.

**R9 -- case of the manifest.** `read_rules_manifest` (#110's, kept verbatim)
accepts only names ending in lower-case `.md`; deploy-harness.ps1's
case-insensitive filter can put `X.MD` into `~/.aitools/rules` and its
manifest, which the reader then reports as an invalid line (the rule is still
fanned out, adopt none). The deploy-harness filter itself is case-sensitive in
.sh and case-insensitive in .ps1 (Harness findings 3a): F2.

**R10 -- Claude Code and `X.MD`.** Whether Claude Code loads a rule whose
extension is upper case is unknown (Ref 7.5); the fan-out deploys it as
named (D1 case-insensitive filter).

## 9. Open questions (with suggested answers)

- **Q1 (R1).** Keep D5 (fan out source `aitools`) or take the costed variant?
  Suggested: confirm with the commander after he sees the 20k-token and
  double-load evidence; the plan implements D5 as decided.
- **Q2.** Adopt target from the manifest source (this plan) or `""` (Cursor
  parity)? Suggested: manifest-mapped, because setup-user-claude offers adopt
  for dotprofile rules today (contract item #11) and `""` would remove it.
- **Q3.** No manifest: fan out everything (this plan) or nothing (Cursor)?
  Suggested: everything, because Claude takes all sources (no source needed to
  select) and retired files are already removed from `~/.aitools/rules` by
  deploy-harness; only adopt and pruning are lost.
- **Q4.** Should a dotprofile resolver error (`URP_RC=3`) still stop the
  rules? Suggested: yes (unchanged): a broken dotprofile config is worth one
  stop, and the dotprofile adopt mapping needs the resolver.
- **Q5.** Lib helpers (this plan) or inline copies? Suggested: lib
  (deploy-harness, Cursor and Claude share one filter and one manifest
  reader; build-deploy inlines the whole lib into MDM scripts, so no
  extraction change). F1 removes Cursor's copies.
- **Q6 (R6).** Should deploy-harness use `resolve_user_repo_path` /
  `Resolve-UserRepoPath`? Suggested: yes, in a deploy-harness PR (F3), so one
  dotprofile is used everywhere and tests can pin it with the env override.
- **Q7.** `removed` as a governed outcome word? Suggested: file it through
  `/glossary` (definition: "a deployed file backed up and deleted because its
  source retired it") and add it to `reference/script-standards-detail.md`'s
  governed outcomes after approval.
- **Q8 (R5).** Refresh `~/.aitools/rules/<name>` after an adopt? Suggested: a
  follow-up with a public lib write helper over `_managed_write` (backup,
  validate, no review), called by setup-user-claude after `accept & adopt`;
  out of this plan's scope.
- **Q9 (#106 Q2).** Should every loop script's exit 2 end the run? It decides
  what a `[x]abort` at a rule review means: today (and in this plan) the run
  continues with `ERROR|setup-user-claude|script failed (exit 2)`, which reads
  as a failure, not a user choice. Suggested: the follow-up PR #106 proposes,
  plus a WARN `aborted by user` row (PR #115's `--summary-tool` already maps
  exit 2 to `aborted (exit 2)` when a caller passes it).
- **Q10 (R7).** Should a kept retired-name file warn every run? Suggested:
  yes for now (it still loads and the user should decide); revisit with Cursor
  if it proves noisy.
- **Q11 (R10).** Warn on a non-lower-case `.md` extension? Suggested: no
  warning until Claude Code's behaviour is verified (a WARN would turn every
  later row WARN).
- **Q12 (review non-blocking 1).** Hidden files (`.x.md`) are skipped, which
  goes beyond D1 ("*.md only, skipping *.bak.*"). Suggested: keep the skip
  (the bash glob skips dot files anyway, deploy-harness's own dot file is the
  manifest, and Cursor's fan-out skips them too); record the commander's
  confirmation.
- **Q13 (review RC-3, merge gate).** The B+C+D PR body must carry the
  commander's recorded answer to Q1 before it merges: the change is visible in
  every repo the day #106 and this PR land. Suggested: ask him with R1's
  numbers (17 of 26 rules unscoped, 75,475 bytes plus `scratch.md`, about 20k
  tokens per session; `sources-of-truth.md` and `script-standards.md` would
  govern every repo; double load inside aitools).

## 10. Follow-ups (not in this plan)

- F1: setup-user-cursor.sh/.ps1 drop their copies of `lower_name`, `in_list`,
  `read_rules_manifest`, `Read-RulesManifest` and use `rule_name_kind` (after
  #110 and Batch A merge); fixes its case-sensitive filter to the approved
  case-insensitive one.
- F2: deploy-harness `add_source` filter case-insensitive in .sh (parity with
  .ps1) and `rule_name_kind` there.
- F3: deploy-harness dotprofile through the resolver (Q6).
- F4: a native-Windows CI step for the fan-out (`.ps1` without the OS-guard
  copy).
- F5: Q8 refresh helper; Q9 abort semantics.
- F6: the un-CI'd suites `tests/rules-fanout-cursor/`, `tests/deploy-harness/`,
  `tests/deploy-harness-mdm/` (Checks I-2).

## 11. Not run (by the planner)

- No repo working tree was edited; no branch, commit, push or PR. The
  prototypes ran on a `git archive` export of #112 and on a scratch detached
  worktree (`.scratch/session-plan/wt112main`: #112 head merged with
  origin/main locally, no branch, never pushed).
- No `aitools`, `setup-user-*`, `deploy-harness` or `build-deploy.sh` run
  against the real HOME. build-deploy ran only inside `tests/claude-mdm`
  (isolated HOME, temp dotprofile).
- Not run: check-pre-commit, check-pre-push, check-post-push, CI, Windows,
  Linux (so `dupcase` never ran), a real MDM endpoint, the chrome-devtools
  read of the Claude Code memory docs.

## 12. Review amendments (S3-FanPlan-Review verdict: APPROVE WITH CHANGES)

Verdict: `S3-FanPlan/S3-FanPlan-Review-verdict.md`. Changes made in place:

1. **RC-1 (Backup-File and `[ ]` names).** Batch B states that its base must
   contain 9923a3c (main has it; #112's branch does not), with the
   `merge-base --is-ancestor` check. B3/B6 retired pruning now removes a file
   only when the backup flag is true **and** a same-text `<file>.bak.*`
   exists beside it; otherwise `log_error` + tracker `failed`, the file
   stays. New test `retired-bracket` (tree parity proves the backup exists in
   both languages). Verified both ways: passes on #112 + main; on #112 alone
   the PowerShell run refuses the removal and the test fails loudly.
2. **RC-2 (unreadable manifest).** B3/B6 set `MANIFEST_FAILED` /
   `$manifestFailed` and record the manifest as a tracker `failed` item, so
   the final row is `ERROR|claude rules|N failed`; the `n/a` row is not
   written after a manifest error. New test `manifest-unreadable`.
3. **RC-3 (decision gate).** Added Q13: the PR body must carry the
   commander's answer to Q1.
4. **Non-blocking, taken.** Case-insensitive lookup of a retired name's copy
   (`Gone.md` for `gone.md`) and test `retired-case`; test `nocreate` (it found
   a real parity bug: PowerShell `New-Item -Force` returned without an error
   when a file blocks the directory, so B6 now re-checks the result); the
   adopt mapping requires `.git` (a BUILD-PKG payload is never an adopt
   target) and test `payload`; the test's temp checkout is now `git init`ed;
   BUILD-PKG coordination row in section 5; Q12 (hidden files); the
   managed-file-deployment drafts (.md and .mdc) now also fix the "Primary
   (wins if present)" dotprofile row for user rules.
5. **Non-blocking, not taken.** Native Windows CI step: kept as F4 (reason in
   Batch D). Vocabulary (`retired:` vs `removed:`): folded into Q7. Dotprofile
   resolver error test (`URP_RC=3`): behaviour unchanged and covered by
   `tests/claude-mdm` (#112); not duplicated. harness.md draft OLD 2 stays
   unverifiable until #100's draft is applied.
6. **Counts after the amendments** (scratch detached worktree: #112 head
   merged with origin/main 568fb5b, then A-D applied; isolated HOMEs):
   tests/rules-fanout 110/0/1 (bash 5 + pwsh), 42/0/21 (`/bin/bash` 3.2);
   claude-mdm 35/0/0 (both bashes); managed-files 57/0 (sh), 39/0 (ps1);
   adopt-push 28/0; rules-fanout-cursor 78/0/1; deploy-harness 45/0;
   deploy-harness-mdm 30/0; profile test-lib 209/0. `bash -n` and the
   PowerShell parser pass on every edited file.

