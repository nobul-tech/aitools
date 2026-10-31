# S3-FanPlan-Harness findings (explorer, level 2), 2026-10-26

Slice: deploy-harness.sh/.ps1, setup-user-cursor.sh/.ps1, reference/harness.md,
reference/cursor-practices.md, shared/rules/*, tests/deploy-harness/,
tests/deploy-harness-mdm/, tests/rules-fanout-cursor/, PRs #100, #110, #111
(and #106 for run order). Reading copy: worktree `fanplan` at origin/main
480b901. Read only; nothing run except `gh pr view/diff`, `grep`, `ls`, `wc`.

## 1. Summary (5 lines)

1. On main and in #100, `~/.aitools/rules` merges **three** sources in this order: `shared/rules`, then aitools **`.claude/rules`**, then dotprofile `claude/rules`. First source wins, and names are compared case-insensitively. HARNESS Q1's suggested "NO" (project rules stay project-scoped) was **not** implemented, and the commander's 2026-10-22 decision keeps `.claude/rules` in.
2. #100 (open) adds `~/.aitools/rules/.aitools-rules-manifest`. It is v1 with lines `<name>\t<source>`, where source is `shared|aitools|dotprofile|retired`. deploy-harness itself backs up and **removes** a retired rule's file from `~/.aitools/rules`. So a consumer that copies `*.md` already never sees a retired name, but it must use the manifest to prune its own copy.
3. setup-user-cursor step 4 (main, #87) copies every `*.md` in `~/.aitools/rules` to `~/.cursor/rules/*.mdc`, using the deploy tracker and the `cursor rules` rows. Its filter is case-**sensitive** in both .sh and .ps1 (`-clike`). The known case-sensitivity defect is in deploy-harness `add_source`/`Add-Source`, not in the Cursor fan-out. #110 adds the manifest reader, user-level-only selection, a body marker, and pruning of fan-out-created `.mdc` files. #110 is the template for the Claude fan-out.
4. The MDM generator cuts deploy-harness at section headings on main (`^# 2\. Dotprofile`, `^# 3\. The six directories`, `^# Managed \(`, `^# Usage:`) and at two `replace_once` literals. #111 replaces these with body markers. Section 5b (the manifest) sits inside the extracted span in both versions.
5. On main **nothing runs deploy-harness**: it has no caller in the installers or `scripts/aitools*`. #106 makes it run before setup-user-claude in `aitools install` (Step 8b, before the Step 21 loop) and in every sync (first in `deploy_scripts`). MDM has no enforced order, and README's list omits deploy-harness. A `[x]abort` in deploy-harness exits 2 **before** section 5b, so the manifest is not refreshed.

## 2. Files read in full (path, lines)

| File | Lines |
|---|---|
| fanplan/scripts/deploy-harness.sh | 413 |
| fanplan/scripts/deploy-harness.ps1 | 373 |
| fanplan/scripts/setup-user-cursor.sh | 668 |
| fanplan/scripts/setup-user-cursor.ps1 | 654 |
| fanplan/reference/harness.md | 179 |
| fanplan/reference/cursor-practices.md | 207 |
| fanplan/shared/rules/hook-lifecycle.md | 134 |
| fanplan/shared/rules/scratch.md | 74 |
| fanplan/tests/deploy-harness/test-deploy-harness.sh | 281 |
| fanplan/tests/deploy-harness-mdm/test-deploy-harness-mdm.sh | 297 |
| fanplan/tests/rules-fanout-cursor/test-rules-fanout-cursor.sh | 304 |
| fanplan/tests/rules-fanout-cursor/convert-rule.ps1 | 19 |
| PR #100 diff (scripts + drafts + hand-back; test hunk skimmed) | scratch `session-harn/pr100.diff` |
| PR #110 diff (setup-user-cursor.*, tests, step4-driver.ps1) | scratch `session-harn/pr110.diff` |
| PR #111 diff (deploy-harness.sh hunk in full, build-deploy.sh hunks 500-910, drafts) | scratch `session-harn/pr111.diff` |
| PR #106 body + diff hunk headers (deploy list, Step 8b) | scratch `session-harn/pr106.diff` |
| Partial reads: fanplan/scripts/build-deploy.sh 840-919, 1670-2209; aitools-lib.sh 2262-2321; aitools-install.sh 812-851; README.md 66-97 | |
| Hand-backs: S3-Harness-handback.md (71, full); S3-H-Core/-Cursor/-MDM hand-backs (grep only) | |

Rules: the project rules and user rules were in my context (main-checkout copies, as injected). I did not diff them against the worktree copies. I did not read the packet's full reference subset (script-standards-detail, cross-platform-detail, logging, managed-file-deployment, plan-execution-detail); this slice did not need them.

## 3. Current behaviour, with verbatim code

### 3a. Sources and order that deploy-harness merges into ~/.aitools/rules (focus a)

The header states the contract at `deploy-harness.sh:20-26`:

```
#   ~/.aitools/rules/<file>.md     <- <aitools>/shared/rules, <aitools>/.claude/rules,
#                                     <dotprofile>/claude/rules (one flat directory)
...
# Name conflicts: the first source wins; each skipped duplicate is log_error +
#   an ERROR row. Unit: file name (rules, hooks), skill directory name (skills);
#   compared case-insensitively. Files named *.bak.* are never deployed.
```

The calls are at `deploy-harness.sh:260-264`. build-deploy parses this exact line format (see 3e):

```
add_source rules      "shared/rules"     "$REPO_DIR/shared/rules"    "$HARNESS_DIR/rules"      flat-md
add_source rules      ".claude/rules"    "$REPO_DIR/.claude/rules"   "$HARNESS_DIR/rules"      flat-md
if [ -n "$DOTPROFILE" ]; then
    add_source rules  "dotprofile"       "$DOTPROFILE/claude/rules"  "$HARNESS_DIR/rules"      flat-md
fi
```

The PowerShell twin is at `deploy-harness.ps1:244-248`:

```
Add-Source -Kind "rules"      -Label "shared/rules"   -SrcDir (Join-Path (Join-Path $repoDir "shared") "rules")   -DestDir (Join-Path $harnessDir "rules")      -Layout "flat-md"
Add-Source -Kind "rules"      -Label ".claude/rules"  -SrcDir (Join-Path (Join-Path $repoDir ".claude") "rules")  -DestDir (Join-Path $harnessDir "rules")      -Layout "flat-md"
if ($dotprofile) {
    Add-Source -Kind "rules"  -Label "dotprofile"     -SrcDir (Join-Path (Join-Path $dotprofile "claude") "rules") -DestDir (Join-Path $harnessDir "rules")     -Layout "flat-md"
}
```

The dotprofile comes from `userRepoPath` in `~/.aitools/config.json` (`deploy-harness.sh:120-129`). When it is absent or not found, the run logs info and skips dotprofile rules. Only git-tracked files are deployed (`git ls-files -z`, `:188`).

The rules filter in `add_source` is at `deploy-harness.sh:196-211`. It is **case-sensitive**:

```
        case "$base" in
            *.bak.*) log_detail "skip backup copy: $label/$rel"; continue ;;
        esac
...
                if [ "$layout" = "flat-md" ]; then
                    case "$rel" in
                        *.md) ;;
                        *) log_detail "skip non-.md file in a rules source: $label/$rel"; continue ;;
                    esac
                fi
```

The .ps1 filter is at `deploy-harness.ps1:193,198`. It is **case-insensitive** (`-like`, `-notlike`):

```
        if ($base -like '*.bak.*') { LogDetail "skip backup copy: $Label/$rel"; continue }
...
                if ($Layout -eq "flat-md" -and $rel -notlike '*.md') {
```

The duplicate check is case-insensitive on both sides: the .sh uses `tr '[:upper:]' '[:lower:]'` at `:220`, and the .ps1 uses `ToLowerInvariant()` at `:211`.

**Answer to Q1.** main and #100 both include project `.claude/rules`, under manifest source `aitools`. Nothing on main or in any PR in my slice implements HARNESS Q1's suggested "NO". The 2026-10-22 decision ("Claude gets everything in ~/.aitools/rules, Cursor user-level only") matches the code as it is. The #110 body cites it, and #110 says the integration produced 26 aitools, 2 shared and 1 dotprofile rules.

**Expected live inventory.** The worktree has 26 `.claude/rules` files and 2 `shared/rules` files (`hook-lifecycle.md`, `scratch.md`). The dotprofile has 2 (`concurrent-agents.md`, `delegation.md`). That makes 30 rules and no name collisions (`ls` output). Live `/Users/new-jose/.aitools/` has no `rules/` directory, and `/Users/new-jose/.cursor/rules` does not exist (`ls`: "No such file or directory").

### 3b. The #100 manifest format and how it marks "retired" (focus b)

Contract, from the #100 PR body ("Contract") and the header of `write_rules_manifest`:

- **File:** `~/.aitools/rules/.aitools-rules-manifest`. It is a dot file with no `.md` extension.
- **Format:** UTF-8, LF. The first line is `# aitools rules manifest v1`. Each following line is `<file name>\t<source>`, sorted in byte order (ordinal in the .ps1).
- **Source values:** `shared` (shared/rules), `aitools` (.claude/rules), `dotprofile`, `retired`. The label-to-source map is at pr100.diff:567 in the .sh and :342 in the .ps1:

```
        my %source_of = ("shared/rules" => "shared", ".claude/rules" => "aitools", "dotprofile" => "dotprofile");
```

- **When a name is retired:** a name in the previous manifest that no source claims this run becomes `retired`, but only when its previous source was **listed** this run. Otherwise it keeps its line (`keep`). The decision logic, at pr100.diff:605-615:

```
                    next if $claimed{lc $name};          # a source has it this run
                    if ($src eq "retired") {
                        $lines{$name} = "retired";
                        print $a "stale\t$name\n";
                    } elsif ($listed{$label_of{$src}}) {
                        $lines{$name} = "retired";
                        print $a "retire\t$name\t$src\n";
                    } else {
                        $lines{$name} = $src;
                        print $a "keep\t$name\t$src\n";
                    }
```

- **What deploy-harness does with a retired name:** it backs up and **removes** the file from `~/.aitools/rules` on every run while the file exists. This is `retire_rule_file` (pr100.diff:629-649), which uses `backup_file`, then `rm -f`, then the row `DETAIL|harness files|retired: rules/<name>`. As a result, a retired name normally has **no** file in `~/.aitools/rules`, only `<name>.bak.<ts>` backups (pruned to 20 by `backup_file`).
- **Write order:** section 5b runs after the deploy loop and before the preserved report. The manifest is written to a temp file and then moved. On failure: `log_error` plus `ERROR|harness files|rules manifest not written`, and the run continues. Dry run: logged only.
- **Consumer contract** (#100 body): "take every non-retired name they are entitled to; back up and remove their own deployed copy of every `retired` name (Cursor also removes names whose source is `aitools`)."

**Implication for "minus retired" in setup-user-claude.** Claude is entitled to `shared`, `aitools` and `dotprofile`. Retired files are already gone from `~/.aitools/rules`, so the manifest's job for Claude is (i) **pruning** `~/.claude/rules/<name>` for `retired` names, and (ii) deciding what to do with a `*.md` that is in `~/.aitools/rules` but not in the manifest. Example: a preserved user-added file. #110's Cursor logs it as "Not fanned out ... (not in the rules manifest)".

### 3c. The setup-user-cursor fan-out on main (#87) and what #110 changes (focus c)

**On main, step 4** is at `setup-user-cursor.sh:378-653` and `setup-user-cursor.ps1:372-639`. Function names:

- `cursor_rule_from_md` (.sh:404) / `ConvertTo-CursorRule` (.ps1:398): `.md` to `.mdc` conversion. Not needed for Claude.
- `cursor_rule_check` (.sh:462) / `Test-CursorRuleParse` (.ps1:469).
- `lower_name` (.sh:474).

**Source enumeration and filter** (`.sh:486-510`). The glob skips dot files. The filter is case-**sensitive**:

```
    for rule_src in "$HARNESS_RULES_DIR"/*; do
        if [ ! -e "$rule_src" ] && [ ! -L "$rule_src" ]; then
            continue   # the unexpanded glob of an empty directory
        fi
        rule_base=$(basename "$rule_src")
        # Contract (S3-Harness correction): only *.md rules; *.bak.* are the
        # backups deploy_managed_file leaves next to updated harness files
        case "$rule_base" in
            *.bak.*) continue ;;
            *.md) ;;
            *) log "Ignoring non-rule file in harness rules: $rule_base (only *.md is fanned out)"
               continue ;;
        esac
```

The .ps1 (`.ps1:492-499`) is also case-**sensitive** (`-clike`) and skips names that start with `.`:

```
        foreach ($entry in $entries) {
            if ($entry.Name.StartsWith(".")) { continue }
            # Contract (S3-Harness correction): only *.md rules; *.bak.* are the
            # backups Deploy-ManagedFile leaves next to updated harness files
            if ($entry.Name -clike "*.bak.*") { continue }
            if (-not ($entry.Name -clike "*.md")) {
```

The brief's "known defect" (case-sensitive .sh vs case-insensitive .ps1) is in **deploy-harness** `add_source`/`Add-Source` (3a). The #100 hand-back's INCIDENT marker says the same. In the Cursor fan-out both scripts are case-sensitive. The approved behaviour for the Claude fan-out is "case-insensitive", so the planner must choose the matching style deliberately (see section 7).

**Edge states and rows** (`.sh:476-482, 512-514`):

- `~/.aitools/rules` missing: `OK|cursor rules|n/a (no harness rules)`.
- Unreadable: `ERROR|cursor rules|cannot read harness rules`.
- Empty: `OK ... n/a (no harness rules)`.
- A dangling symlink is recorded `failed`.

**Backup and duplicates** (`.sh:516-554`):

- `backup_dir "$CURSOR_RULES_DIR"` before writing.
- `deploy_tracker_init` starts the tracker.
- A second source that maps to the same lower-cased target is `log_error` plus `deploy_tracker_record "failed"`.

**The deploy call and outcome switch** (`.sh:568-581`). Adopt target is `""`:

```
            deploy_managed_file "$rule_content" "$CURSOR_RULES_DIR/$dest_name" "cursor rules" "$dest_name" ""
            case "$MANAGED_FILE_RESULT" in
                created|updated|verified|skipped|failed)
                    # The library wrote (or left) LOCAL; the tracker records every
                    # outcome (failed -> ERROR row, skipped -> WARN row).
                    ;;
                "accept & adopt")
                    # Not reachable: adopt is not offered without an adopt target
                    log_error "Unexpected accept & adopt for $dest_name (no adopt target)" ;;
                *)
                    log_error "Unexpected deploy result for ${dest_name}: $MANAGED_FILE_RESULT"
                    MANAGED_FILE_RESULT="failed" ;;
            esac
            deploy_tracker_record "$MANAGED_FILE_RESULT" "cursor rules" "$dest_name"
```

**Preserved files** (`.sh:591-605`): a target file that is not `*.bak.*` and not in the deployed list is logged and recorded with `deploy_tracker_record "preserved"`. On main nothing is pruned.

**Summary rows** (`.sh:641-650`):

- `deploy_tracker_summary "cursor rules"`, which writes ERROR `N failed`, WARN `N skipped (user review)`, or OK `<parts>`.
- `ERROR|cursor rules|validation failed` when the errors counter rose without a tracked failure.
- Dry run: `OK ... dry run (no files written)` or `ERROR ... N failed (dry run)`.

**Tracker outcomes** (`aitools-lib.sh:2281-2297`): `added|created`, `updated`, `accept & adopt`, `skipped`, `failed`, `verified`, `preserved`. There is **no `removed`**, and **no default branch**: an unknown outcome is silently ignored.

```
        verified)  _DT_VERIFIED=$((_DT_VERIFIED + 1)) ;;
        preserved) _DT_PRESERVED=$((_DT_PRESERVED + 1)) ;;
    esac
```

**What #110 changes** (pr110.diff:1591-1968 for .sh, :1000-1590 for .ps1; stacked on #100):

- **New functions:**
  - `read_rules_manifest` / `Read-RulesManifest`. Output lines are `rule\t<name>\t<source>` or `invalid\t<line>`, or `header-bad`. A valid line is `^[^/\\]+\.md$`, has no `.bak.`, has a known source, and is not a case-insensitive duplicate.
  - `cursor_rule_is_fanout` / `Test-CursorFanoutRule`: checks the marker after the first closing `---`.
  - `in_list`: newline-list membership, for bash 3.2.
  - `CURSOR_FANOUT_MARKER` / `$cursorFanoutMarker`.
  - `RULES_MANIFEST_HEADER`.
- **No manifest or a bad header** (pr110.diff:1751-1767): nothing is fanned out and nothing is removed. Rows: `WARN|cursor rules|no rules manifest` or `WARN|cursor rules|rules manifest not v1`, plus `ACTION||Run aitools to rebuild ~/.aitools/rules and its manifest`. An unreadable manifest gives `ERROR ... cannot read rules manifest`.
- **Selection:** entitled names come from source `shared|dotprofile`, matched **case-insensitively** (`lower_name` plus `in_list`). Names from `aitools|retired` go to `REMOVE_RULES`. A `*.md` not in the manifest gets `log "Not fanned out: X (not in the rules manifest)"`. An entitled name with no file gets `log_warn`.
- **The `*.bak.*` and `*.md` glob filter stays case-sensitive in #110.** The manifest match is case-insensitive.
- **Prune loop** (pr110.diff:1867-1940), per `aitools|retired` name:
  1. Skip it if the target name was deployed this run (a case-only difference).
  2. Recognise it as fan-out-created: either the marker is present, or the content equals the conversion of `~/.aitools/rules/<name>` or of any `<name>.bak.*`.
  3. If recognised: `backup_file`, check `BACKUP_FILE_OK`, `rm -f`, verify the file is gone, then write `DETAIL|cursor rules|removed: <file>`. `N_REMOVED` counts the removal; it does **not** go through the tracker, because there is no `removed` outcome.
  4. If not recognised: `log_warn "Kept ..."` and add it to one `ACTION||Cursor still loads project/retired rules ...: <list>` row.
- **Row when nothing was fanned out:** `OK ... N removed` or `OK ... n/a (no user-level rules)`.
- **The .ps1 backs up names containing `[ ] * ?` with `Copy-Item -LiteralPath`** (pr110.diff:1441-1465), because `Backup-File` is wildcard-based. On main, 9923a3c "Use -LiteralPath in Backup-File and Backup-Dir" may make this workaround unnecessary; verify on the rebased branch.

### 3d. The tests/rules-fanout-cursor structure, to mirror in tests/rules-fanout/ (focus d)

`test-rules-fanout-cursor.sh` (main, 304 lines):

- **Header:** a `--help` that prints the header lines (`:18-21`). It uses `set -uo pipefail`, not `-e`.
- **Paths and cleanup:** `ROOT`, `SCRIPT`, `SCRIPT_PS1`, `HELPER_PS1`, and `TMP_ROOT=$(mktemp -d)` with `trap rm -rf EXIT` (`:23-28`).
- **Helpers:**
  - `check NAME CONDITION`: eval'd. On failure it prints the tail of `$C/out` (`:34-43`).
  - `setup_case NAME`: sets `C=$TMP_ROOT/NAME` and `H=$C/home`, puts stub `rg`/`agent` in `$C/bin`, and empties `$C/summary` (`:46-54`).
  - `seed_rules`: one fixture per source shape: plain, scoped, native.mdc, notes.txt, `*.bak.*`, `odd.bak.2026.md`, `.hidden.md`, `subdir/` (`:57-68`).
  - `run_script ARGS`: `env HOME=$C/home AITOOLS_LOG_DIR=$C/logs AITOOLS_SUMMARY_FILE=$C/summary PATH=$C/bin:$PATH bash "$SCRIPT" "$@" < /dev/null > $C/out 2>&1`, then writes `$C/rc` (`:71-75`).
  - `rc` and `row` read the last non-DETAIL `|cursor rules|` row (`:77-78`).
- **Converter and resolution checks:** golden cases and a PS1 parity check through `convert-rule.ps1`, which loads the function from the script AST (`:81-168`). This part is Cursor-specific; Claude needs no converter.
- **Cases** (`:170-301`): missing, empty, fanout (first, rerun, edited non-interactive, `--force`), mdcnext, dupcase (skipped on a case-insensitive file system), broken symlink, unreadable (`chmod 000`), descdash, dry, drydup.
- **Final line:** `N passed, N failed, N skipped`, then `[ "$FAIL" -eq 0 ]`.

#110 adds the following (pr110.diff:2244-2646):

- `manifest LINE...`: writes the v1 manifest, with `|` standing for TAB.
- Every existing case gets a manifest fixture.
- New cases: users, rerun, nomanifest, badheader, invalid, onlyremove, bracket, edited (#87 files matched through `.bak.*`), bodymark, lonecr, dryprune, missingsrc.
- **PS1 parity harness:** `step4-driver.ps1` dot-sources `aitools-lib.ps1`, sets `$cursorDir`, and runs the script text from `Log "Step 4: Cursor user rules"` to `# --- END cursor body`, under an isolated USERPROFILE. `parity CASE SEED [args]` reseeds `$C/home-ps`, runs the .ps1, and compares the exit code, a `tree_sig` (path plus md5, with `.bak.TS` normalised) and the summary rows (`rows()`).

**Mirror for tests/rules-fanout/.** Keep the same scaffold: `setup_case`, `run_script` with HOME, log dir and summary file isolated, `manifest`, `tree_sig`, `rows`, and `parity`. Then:

- setup-user-claude needs its own driver, or an isolated run of the whole script. Its other steps (CLAUDE.md template, etc.) need a fake dotprofile and config.json; ask the S3-FanPlan-Claude explorer what they read.
- The step4-driver approach needs a stable start anchor (a `Log "Step N: ..."` line) and an end marker in setup-user-claude.ps1. Coordinate with the -Claude slice.
- Cases to carry over: missing dir, manifest only, user-level plus aitools all fanned out, retired pruned only when recognised, a user's own file with a retired name kept, `*.bak.*` and the manifest silent, no manifest, bad header, invalid lines, case-insensitive match, dry run, a `[ ]` name, rerun verified, `--force`, broken symlink, unreadable dir.

### 3e. deploy-harness cut points for the MDM generator (focus e)

**On main**, build-deploy.sh cuts at these places:

- Header scope span: `extract_span "$HARNESS_SH" '^# Managed \(' '^# Usage:'` (`build-deploy.sh:1933`) and the same for the PS1 (`:2083`).
- Body to section 2: `extract_span "$HARNESS_SH" '^set -euo pipefail$' '^# 2\. Dotprofile'` (`:1942`) and `extract_span "$HARNESS_PS1" '^param\($' '^# 2\. Dotprofile'` (`:2092`).
- Sections 3 to EOF: `extract_span "$HARNESS_SH" '^# 3\. The six directories' EOF` (`:2040`) and the PS1 at `:2192`.
- `replace_once` literals, which must occur exactly once:
  - `'deploy_managed_file "$content" "$dest" "$TOOL" "$item" "$src"'` (`:2041`)
  - `'-ItemName $p.Item -AdoptPath $p.Src'` (`:2193`)
- Parsers:
  - `add_source` lines must match `/^\s*add_source\s+\S+\s+"[^"]*"\s+"\$(REPO_DIR|DOTPROFILE)\/([^"]+)"/` (`:1711-1716`).
  - `Add-Source -Kind ... -SrcDir (... "a") "b") -DestDir` (`:1718-1727`).
  - Exactly one `^for cli in ...; do` (`:1737`) and one `^foreach \(\$cli in \@\(...\)\)` (`:1741`).
  - .sh/.ps1 parity of both lists is enforced (`:1732, :1745`).

**#111** (pr111.diff) adds these markers to deploy-harness.sh/.ps1:

```
# --- BEGIN scope (extracted by build-deploy) ---           ... # --- END scope (extracted by build-deploy) ---
# --- BEGIN body (extracted by build-deploy) ---            (before set -euo pipefail / param()  ... file end) # --- END body (extracted by build-deploy) ---
# --- BEGIN config bootstrap check (replaced by build-deploy) --- / # --- END config bootstrap check (replaced by build-deploy) ---
# --- BEGIN dotprofile lookup (replaced by build-deploy) --- / # --- END dotprofile lookup (replaced by build-deploy) ---
```

- `extract_markers FILE FROM TO` / `extract_marked FILE NAME` (pr111.diff:508-521) fail the build unless each marker is on exactly one line, in order.
- Assembly order (pr111.diff:682-899):
  1. scope
  2. `BEGIN body` to `BEGIN config bootstrap check`
  3. the MDM bootstrap block
  4. `END config bootstrap check` to `BEGIN dotprofile lookup`
  5. MDM section 2
  6. `END dotprofile lookup` to `END body`, with the same `replace_once`
- #111 keeps the `add_source` / `for cli` parsers.
- `--help` hides marker lines (pr111.diff:1519).

**Relevance to the fan-out.** The setup-user-claude refactor does **not** need to touch deploy-harness. If someone edits it anyway, they must keep:

- the `add_source rules ...` line format;
- the two `replace_once` literals;
- on main, the four headings (`# Managed (`, `# Usage:`, `# 2. Dotprofile`, `# 3. The six directories`);
- after #111, the eight marker lines.

Section 5b (the manifest) is inside the extracted span in both versions (#100 body "MDM"; #111 body). So the MDM deploy-harness writes the same manifest from the build-time snapshot. Its dotprofile rules are the build-time dotprofile's (`build-deploy.sh:1689-1690`).

The Cursor MDM counterpart is generated by `extract_between ... '^# --- BEGIN cursor body' '^# --- END cursor body'`, plus a header span `'^# Does [a-z]+ things:'` to the body marker (`build-deploy.sh:860-865, 900-906`). The #110 hand-back says no build-deploy.sh change was needed because step 4 sits inside the cursor body markers. **A setup-user-claude fan-out that sits inside the extracted body of setup-user-claude would get its MDM counterpart for free, in the same way.** Whether setup-user-claude has such markers is the -Claude slice's question; I did not read it.

### 3f. Does deploy-harness run before setup-user-claude in every path? (focus f)

- **main:** no. `grep -rn deploy-harness` over `scripts/aitools`, `aitools.ps1`, `aitools-install.sh/.ps1` and `hh` finds nothing; only aitools-lib comments mention it.
  - The installer's Step 21 loop is `DEPLOY_SCRIPTS="setup-user-claude.sh setup-user-cursor.sh ..."` (`aitools-install.sh:833`).
  - The sync list is `setup-user-config.sh setup-user-claude.sh ...` (`scripts/aitools:1151`, `:1108` for ps1; `aitools.ps1:157`).
  - So on main, `~/.aitools/rules` exists only if someone runs deploy-harness by hand. Cursor step 4 reports `n/a (no harness rules)`, and a Claude fan-out would see the same.
- **#106 (open):**
  - Installer: Step 8b `run_harness_step` / `Invoke-HarnessStep` runs right after Step 8 (Node), well before Step 21, where setup-user-claude runs. The test asserts Step 8 < 8b < 9.
  - Sync: `local deploy_scripts="deploy-harness.sh setup-user-claude.sh ..."`, with `setup-user-config` removed (pr106.diff:144, :110; aitools.ps1 pr106.diff:493). So deploy-harness runs before setup-user-claude on both dev paths.
  - On abort, #106 stops the whole run (exit 2, `deploy_aborted`). The commander's 2026-10-26 decision reverses that: the installer continues. See risk R2.
- **MDM:** no enforced order. The generated header says "Run it FIRST in an MDM sequence: setup-user-cursor (and the other rules fan-out consumers) read ~/.aitools/rules" (`build-deploy.sh:1913-1914`). The README MDM list (`README.md:69-93`) starts with setup-user-claude and omits deploy-harness. That is S3-H-MDM's INCIDENT, still unfixed on main. The live dotprofile `deploy/` (`ls /Users/new-jose/repos/aitools-nobul-jose/deploy/`) has **no** `deploy-harness.*` at all: it was built before #93, and nobody has rebuilt it.

## 4. What must change, or be checked, for the refactor

1. **setup-user-claude (the -Claude slice): model it on #110 step 4, not on main's #87.**
   - **What to take:**
     - the manifest reader;
     - case-insensitive name matching;
     - skipping `*.bak.*`, non-`.md` files and dot files;
     - `deploy_managed_file` per file into `~/.claude/rules/<name>` (no conversion);
     - the outcome switch, including `accept & adopt` if an adopt target is passed;
     - the deploy tracker under one tool name (suggested: `claude rules`; check script-standards-detail's tool-name table);
     - the preserved report;
     - pruning of `retired` names only;
     - the no-manifest and bad-header WARN plus ACTION.
   - **Entitled sources:** `shared`, `aitools`, `dotprofile`.
   - **Pruning without a marker:** Claude copies are verbatim, so recognise a fan-out-created file by content. Compare with `~/.aitools/rules/<name>` (normally absent for a retired name) and with each `~/.aitools/rules/<name>.bak.*`. deploy-harness's `retire_rule_file` leaves that backup, so the comparison works until `backup_file` prunes it (it keeps 20).
   - **Not recognised:** keep the file, `log_warn`, and add an ACTION row, as #110 does.
2. **Shared helpers.** `read_rules_manifest` / `Read-RulesManifest` and `in_list` live in setup-user-cursor.* in #110. A second consumer means either a copy or a move to aitools-lib.sh/.ps1 (the -Lib slice). build-deploy inlines the lib into the MDM scripts, so a lib move keeps the MDM counterpart working.
3. **Deploy tracker.** It has no `removed` outcome, and an unknown outcome is silently dropped (`aitools-lib.sh:2283-2296`). #110 uses DETAIL rows plus a counter instead. If the Claude fan-out records `removed` through the tracker, the lib must gain it first. That is a contract change: interactive-menus.md requires updating the function, the tracker, every caller and the spec.
4. **The dotprofile direct rules deploy in setup-user-claude must stop**, per the approved behaviour. Its MDM embed of `<userRepoPath>/claude/rules/*.md` in build-deploy.sh (deploy-paths.md "What IS auto-embedded") must go too. That is the -Claude/-Misc slice; listed here because it interacts with the deploy-harness snapshot, which already embeds the dotprofile rules for MDM.
5. **The run order must guarantee deploy-harness first** on every path:
   - Dev: depends on #106 merging.
   - MDM: README run order (INCIDENT), plus the #99/#111 deploy-paths "MDM run order" drafts.
   - Without #106, the Claude fan-out on main would always hit the "no harness rules" path and deploy nothing. Planner: decide the dependency order (#100, then #106, then fan-out).
6. **reference/harness.md (protected).** It still says "No deletion" (`:156-158`) and says conflicts with `~/.claude/rules` are "handled by the fan-out in setup-user-claude / setup-user-cursor" (`:153-155`). #100's draft edits both. The Claude fan-out needs an extra sentence there, or in the manifest subsection's "Consumers" bullet, saying Claude takes all non-retired names.
7. **reference/cursor-practices.md.** It is stale: nothing about `~/.cursor/rules`, and it says user rules are "Not file-accessible" (`:127, :137`). S3-H-Cursor filed an INCIDENT for this. It is not required for the Claude fan-out; listed so the planner does not cite it as current.
8. **tests/rules-fanout/ (new).** Mirror the structure in 3d. Consider a static check that the Claude and Cursor manifest readers agree on the same fixtures, if the readers are not merged into the lib.

## 5. Interactions with open PRs in this slice

| PR | Overlap with the Claude fan-out plan |
|---|---|
| #100 (deploy-harness manifest) | Prerequisite: the manifest contract. Touches deploy-harness.* sections 4/5b/6/7 and tests/deploy-harness. No setup-user-claude change. |
| #110 (Cursor user-level, stacked on #100) | Template, and it owns the manifest-reader code. Its diff contains #100's commits. If the Claude plan moves `read_rules_manifest` into the lib, it must land after #110 or rebase #110. Both edit test conventions, and step4-driver.ps1 is the parity pattern to reuse. |
| #111 (MDM payload and markers, stacked on #100) | Changes the deploy-harness cut points (3e) and build-deploy.sh lines 397-2210. #103/#112 also edit build-deploy.sh (setup-user-claude MDM; not read here). Any build-deploy change for the Claude MDM counterpart conflicts textually with #111's region only if it touches the deploy-harness generator; the setup-user-claude generator is elsewhere (unknown where; -Claude slice). |
| #106 (installer/sync hook-in) | Gives the run order the fan-out needs (3f). Its abort-ends-run semantics are under change (commander 2026-10-26). Its test counts ("7 added") change after #100. |
| #116 (installers, lib relay) | Touches setup-user-claude.*, aitools-install.*, aitools-lib.*, per its file list (`gh pr view 116`). Not read beyond the file list; -Install/-Lib slices. |

## 6. Error handling, parity and script-standards issues spotted

1. **The deploy-harness rules filter is case-sensitive in the .sh and case-insensitive in the .ps1** (`deploy-harness.sh:197,207` vs `.ps1:193,198`). `X.MD` deploys on Windows only. Pre-existing; #100 hand-back INCIDENT.
2. **Cursor fan-out filter:** both scripts are case-sensitive (`.sh:493-498`, `.ps1:496-497` `-clike`). They are at parity with each other, but not with the approved "case-insensitive" Claude behaviour. If Claude goes case-insensitive (`*.[mM][dD]`, `*.[bB][aA][kK].*`, or perl `lc`), the two consumers will differ on `X.MD`. Suggest: fix all three places together (deploy-harness, Cursor, Claude), or record the difference.
3. **The deploy-harness preserved report** uses `/\.bak\./i` (case-insensitive, `.sh:367`), while `add_source` uses a case-sensitive `*.bak.*` (`.sh:197`). This is an internal inconsistency; low.
4. **`deploy_tracker_record` silently ignores unknown outcomes** (no `*)` branch, `aitools-lib.sh:2283-2296`). That is a silent-failure hazard under USO "No silent failures" if a caller passes `removed`.
5. **The #110 .ps1 workaround for `Backup-File`'s wildcard bug** may be obsolete after 9923a3c on main. Verify, then consider removing the duplicate code path in a consumer modelled on it.
6. **#100 parity notes still open** (hand-back): .ps1 retire backups are not pruned (the .sh keeps 20); the warning count on a failed backup differs; a dangling symlink with a retired name is removed by the .sh and left by the .ps1. The Claude consumer's content-match against `<name>.bak.*` therefore sees a different number of backups on Windows than on macOS.
7. **`backup_dir` backs up only directories that contain `*.md`** (S3-H-Cursor INCIDENT 2). `~/.claude/rules` holds `.md`, so the Claude fan-out does get a directory backup. Fine, but note the asymmetry with Cursor.
8. **cursor .ps1 step 4 has no separate "permission denied" branch.** Its `Get-ChildItem` catch gives the same ERROR row as the .sh `[ ! -r ]` branch, so parity is fine.

## 7. Risks, unknowns, open questions (with suggested answers)

**Risks**

- **R1. The Claude fan-out depends on #100, and in practice on #106.** Without #106 nothing populates `~/.aitools/rules` on any dev path. Suggested: plan the fan-out to merge after #100 and #106, and make "no harness rules" a non-error `OK ... n/a` row, as Cursor does.
- **R2. A `[x]abort` inside deploy-harness exits 2 from the deploy loop, before section 5b** (`deploy-harness.sh:292`: "Not run in a subshell: [x]abort exits 2 from here"; 5b comes after the loop in #100). The manifest is then the previous run's, while some rule files were already updated. Under the 2026-10-26 decision (abort ends only that script; the installer continues), setup-user-claude then runs against that state:
  - a rule added this run may have a file but no manifest line, so it gets "not in the rules manifest" and is not fanned out;
  - a rule retired this run is not marked retired yet, so it is not pruned.

  Suggested: accept this. It is self-healing on the next full run. Document it, and have the consumer log the not-in-manifest case at info, as #110 does.
- **R3. Double loading and project-rule spread.** The aitools `.claude/rules` loads twice in aitools sessions (project plus user level). 26 "(this repo)" rules load in every repo on the machine (S3-Harness Q1 consequences). The commander chose this; I am restating it so the plan states it as accepted.
- **R4. Some fanned-out rules carry `paths:` frontmatter** written for the aitools repo, for example `shared/rules/hook-lifecycle.md:2-9`, and several `.claude/rules` files. How Claude Code resolves `paths:` in a **user-level** `~/.claude/rules` file (relative to which root) is **unknown** to me. It is in the /tool-ops slice (-Ref/-Misc). If paths resolve per project, aitools-scoped rules such as `scripts/**` would load in other repos with a `scripts/` dir.
- **R5. MDM.** The live dotprofile `deploy/` predates deploy-harness generation, and README's order omits deploy-harness. An MDM endpoint running the refactored setup-user-claude without deploy-harness first gets no rules at all, where today it gets the embedded dotprofile rules. That is a regression in MDM coverage until deploy-paths/README document the order and the commander rebuilds `deploy/`.

**Unknowns**

- Where setup-user-claude's MDM body markers are and how build-deploy generates it (-Claude slice; #103/#112).
- Whether 9923a3c fully fixes `Backup-File` for `[ ]` names on the .ps1 (I did not read the commit).

**Open questions, with suggested answers**

- **Q-A. No manifest:** should Claude fan out every `*.md` (safe, because retired files are already gone), or mirror #110 (nothing fanned out, WARN plus ACTION)? Suggested: mirror #110, for one consumer contract and because a preserved, user-added file in `~/.aitools/rules` would otherwise spread. After #100, deploy-harness writes the manifest on every run, so this path only means "deploy-harness never ran, or an old one ran".
- **Q-B. Adopt target for `~/.claude/rules` copies.** Cursor passes `""` because its file is converted. Claude's copy is verbatim, so on the dev path the manifest source could map to the repo file: `shared` to `<aitools>/shared/rules/<n>`, `aitools` to `<aitools>/.claude/rules/<n>`, `dotprofile` to `<dotprofile>/claude/rules/<n>`. Suggested: pass that path on dev (adopt then reaches the source of truth), and `""` on MDM. The alternative, `""` everywhere, is simpler but loses adopt that setup-user-claude offers today for dotprofile rules. Commander decision needed.
- **Q-C. Case-insensitive filter scope** (issue 6.2). Suggested: fix deploy-harness, Cursor and Claude together, in one lib helper (`is_rule_file NAME`), so all three agree.
- **Q-D. Tool name for the Claude rows.** Suggested: `claude rules`, mirroring `cursor rules`. Check the existing setup-user-claude row names first (-Claude slice); keep the current one if rules already have a row.

## 8. INCIDENT markers (not filed)

- **INCIDENT:** `deploy_tracker_record` (`scripts/aitools-lib.sh:2281-2297`) has no default branch: an unknown outcome (for example `removed`) is silently ignored, so no count and no DETAIL row. This deviates from script-standards "No silent failures" and from the interactive-menus.md return-value contract.
- **INCIDENT (pre-existing, re-confirmed):** the deploy-harness rules filter is case-sensitive in the .sh (`scripts/deploy-harness.sh:197,207`) and case-insensitive in the .ps1 (`scripts/deploy-harness.ps1:193,198`).
- **INCIDENT:** the brief's "known defect" statement points at the wrong scripts. The setup-user-cursor filter is case-sensitive in **both** scripts (`setup-user-cursor.ps1:496-497` uses `-clike`); the divergence is in deploy-harness. Fix the carry-forward text so the planner does not "fix" the Cursor .ps1.
- **INCIDENT (pre-existing, re-confirmed):** README.md:69-93 MDM run order omits deploy-harness and lists setup-user-claude first. With the fan-out, MDM endpoints would get no Claude rules.
- **INCIDENT:** reference/harness.md:153-155 says conflicts with `~/.claude/rules` are handled by "the fan-out in setup-user-claude". On main, setup-user-claude has no fan-out. The doc describes unbuilt behaviour; #100's draft does not fix this sentence.
- **INCIDENT (doc drift, re-confirmed):** reference/cursor-practices.md:121-145 does not mention `~/.cursor/rules` and calls user rules "Not file-accessible".
