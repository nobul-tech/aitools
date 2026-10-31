# S3-FanPlan-Claude findings: setup-user-claude and its build-deploy generator

Explorer S3-FanPlan-Claude (level 2, delegated by S3-FanPlan), 2026-10-26.
Read only. Reading copy: `/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/`
at origin/main `480b901` (`git log -1` output: `480b901 Add handoff 10cf255a-c and its relay entry`).
All `scripts/...`, `reference/...`, `.claude/rules/...` paths below are in that worktree
unless they are given in full.

## 1. Summary (5 lines)

1. setup-user-claude.sh/.ps1 deploy rules today from `<dotprofile>/claude/rules/*.md` only (sh 288-429, ps1 306-461), additive, adopt target = the dotprofile rule, plus a private commit+push block that open PR #103/#112 removes.
2. build-deploy's setup-user-claude generator is already a pure extract (build-deploy.sh 625-628, 648-707, 741-803), so the dev-path fan-out code reaches deploy/ unchanged; the only MDM rules code to remove is the build-time rules embed (222-236, 504, 518-521, 566-569) and the two "Rules fallback" blocks (692-702, 786-797), plus header text.
3. MDM counterpart of `~/.aitools/rules` already exists on main: build-deploy generates `deploy/deploy-harness.sh/.ps1` (1676-2203), whose snapshot includes `shared/rules`, `.claude/rules` and dotprofile `claude/rules`; but the live dotprofile `deploy/` is stale (built 2026-10-22 by the old duplicated generator, no deploy-harness.* at all), and nothing enforces "deploy-harness first" on an endpoint.
4. Template to copy: setup-user-cursor.sh step 4 (378-653) is the existing `~/.aitools/rules` fan-out on main; PR #100 defines the manifest/retired contract, PR #110 adds the manifest reader (in setup-user-cursor, not the lib); `retired` for Claude = back up and remove its own copy in `~/.claude/rules`, which needs a recognition rule and a `removed` outcome the tracker lacks.
5. Main risks: on main `aitools`/`aitools install` never run deploy-harness, so after this refactor alone `~/.claude/rules` stops updating; #112's new test asserts dotprofile rules land in `~/.claude/rules` (will break); adopt for dotprofile rules (N-Q2 commit+push) is lost unless the adopt target is resolved from the manifest source.

## 2. Files read in full

| Path | Lines | How |
|---|---|---|
| scripts/setup-user-claude.sh | 442 | Read, full |
| scripts/setup-user-claude.ps1 | 474 (CRLF) | Read, full |
| scripts/build-deploy.sh | 2310 | Read 1-700, 700-1499, 1500-2310 |
| .claude/rules/deploy-paths.md (worktree) | 82 | Read, full (identical text to main checkout copy in my context) |
| .cursor/rules/deploy-paths.mdc | 41 | Read, full |
| reference/user-repo.md | 232 | Read, full |
| scripts/deploy-harness.sh | 413 | Read, full (context: rules sources, filters) |
| scripts/setup-user-cursor.sh | 370-669 | Read (step 4 fan-out precedent) |
| scripts/aitools-lib.sh | 2260-2334 | Read (deploy tracker) |
| tests/managed-files/test-managed-files.sh | 310-350 | Read (setup-user-claude test) |
| /Users/new-jose/repos/aitools-nobul-jose/deploy/setup-user-claude.sh | 2760-2820, 2930-3306 (grep for the rest) | regions holding CLAUDE.md + rules |
| /Users/new-jose/repos/aitools-nobul-jose/deploy/setup-user-claude.ps1 | grep only (rules region at 3173-3435) | |
| PR #103, #112, #111 diffs | saved to `.claude/worktrees/fanplan/.scratch/session-claude/pr{103,112,111}.diff`; read the hunks on my slice files | `gh pr diff` |
| PR #100, #110, #99 | `gh pr view` bodies; #99 diff hunks on deploy-paths.md/.mdc | context |
| Mission packet, explorer brief | full | |
| plans/tool-support-and-machine-profile.md | grep for fan-out / setup-user-claude; lines 60-89 | partial (not read in full: my slice did not need the 95 items beyond R20 and N-Q2) |

Rules used: the main-checkout `.claude/rules/*.md` in my context (deploy-paths.md compared: same text as the worktree copy).
Not read in full (disclosed): the reference subset the packet names (script-standards-detail.md etc.), the prior handoff 2026-10-21_360aa8f3-8.md (grepped only). Nothing in this findings file depends on them except where marked "unknown".

## 3. Current behaviour (verbatim, with line numbers)

### 3.1 setup-user-claude.sh header (managed/preserved scope) -- lines 1-14

```bash
1	#!/usr/bin/env bash
2	# setup-user-claude.sh -- Creates user-level ~/.claude/CLAUDE.md on macOS/Linux
3	# Safe to re-run -- replaces existing file with latest version.
4	#
5	# Sources (in priority order):
6	#   1. <userRepoPath>/claude/CLAUDE.md  (user's personal template from dotfile repo)
7	#   2. shared/claude-shared.md          (fallback template from aitools repo)
8	#
9	# {{PLACEHOLDER}} tokens are interpolated at deploy time using the current
10	# machine's profile from profile.json. See reference/user-repo.md.
11	#
12	# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
13	# Managed: ~/.claude/rules/*.md matching <userRepoPath>/claude/rules/ (additive deploy)
14	# Preserved: ~/.claude/rules/ files not in user repo source
```

The .ps1 header (lines 1-13) is the same text from line 1 `# setup-user-claude.ps1 -- Creates user-level ~/.claude/CLAUDE.md on Windows` to line 13 `# Preserved: ~/.claude/rules/ files not in user repo source`.

The dotprofile resolver result (sh 71-82, ps1 70-80) also stops the rules: `URP_RC -eq 3` -> `log_error "CLAUDE.md and rules not deployed: the dotprofile could not be resolved"` + `exit 1`. With the fan-out, rules no longer need the dotprofile; the planner must decide whether a dotprofile error should still skip the rules (see 7, Q4).

### 3.2 setup-user-claude.sh rules section -- lines 288-429 (every line would change)

Markers that build-deploy cuts on (see 3.5): `# --- BEGIN rules deployment` (288), `# --- BEGIN rules deploy logic` (297), `# --- END rules deploy logic` (428), `# --- END rules deployment` (429).

```bash
288	# --- BEGIN rules deployment (extracted by build-deploy) ---
289	# Deploy user rules: additive (add/update managed, preserve unmanaged, log diffs).
290	RULES_SRC=""
291	if [ -n "${USER_REPO_PATH:-}" ] && [ -d "$USER_REPO_PATH/claude/rules" ]; then
292	    RULES_SRC="$USER_REPO_PATH/claude/rules"
293	fi
294	
295	RULES_DEST="$CLAUDE_DIR/rules"
296	
297	# --- BEGIN rules deploy logic (extracted by build-deploy) ---
298	if [ -n "$RULES_SRC" ]; then
299	    RULE_COUNT=$(find "$RULES_SRC" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
300	    if [ "$RULE_COUNT" -eq 0 ]; then
301	        log "User repo claude/rules/ exists but has no .md files -- skipping"
302	    elif [ "$DRY_RUN" = "true" ]; then
303	        EXISTING_COUNT=0
304	        if [ -d "$RULES_DEST" ]; then
305	            EXISTING_COUNT=$(find "$RULES_DEST" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
306	        fi
307	        log "[DRY RUN] $(display_path "$RULES_DEST"): additive deploy"
308	        log "  Source: $(display_path "$RULES_SRC") ($RULE_COUNT rule files)"
309	        log "  Existing: $EXISTING_COUNT rule files"
310	        for rule_file in "$RULES_SRC"/*.md; do
311	            [ -f "$rule_file" ] || continue
312	            rule_name=$(basename "$rule_file")
313	            if [ -f "$RULES_DEST/$rule_name" ]; then
314	                # diff -q: exits 0 if identical, 1 if different (expected, not an error)
315	                if diff -q "$RULES_DEST/$rule_name" "$rule_file" >/dev/null 2>&1; then
316	                    log "  Would skip (unchanged): $rule_name"
317	                else
318	                    log "  Would update (changed): $rule_name"
319	                fi
320	            else
321	                log "  Would add (new): $rule_name"
322	            fi
323	        done
324	        # Show files that would be preserved
325	        if [ -d "$RULES_DEST" ]; then
326	            for existing in "$RULES_DEST"/*.md; do
327	                [ -f "$existing" ] || continue
328	                exist_name=$(basename "$existing")
329	                if [ ! -f "$RULES_SRC/$exist_name" ]; then
330	                    log "  Would preserve (unmanaged): $exist_name"
331	                fi
332	            done
333	        fi
334	    else
335	        backup_dir "$RULES_DEST"
336	        if ! mkdir -p "$RULES_DEST"; then
337	            log_error "Cannot create $(display_path "$RULES_DEST")"
338	            write_summary ERROR "claude rules" "cannot create rules dir"
339	            exit 1
340	        fi
341	
342	        deploy_tracker_init
343	        ERRORS_BEFORE_RULES=$ERRORS
344	        for rule_file in "$RULES_SRC"/*.md; do
345	            [ -f "$rule_file" ] || continue
346	            rule_name=$(basename "$rule_file")
347	            # Adopt target: the dotprofile rule (the file deployed from). Empty
348	            # in the MDM deploy script (no user repo): adopt and merge not offered.
349	            _rule_adopt_path=""
350	            if [ -n "${USER_REPO_PATH:-}" ]; then
351	                _rule_adopt_path="$USER_REPO_PATH/claude/rules/$rule_name"
352	            fi
353	            if ! _rule_content=$(cat "$rule_file"); then
354	                log_error "Cannot read source rule $rule_name"
355	                deploy_tracker_record "failed" "claude rules" "$rule_name"
356	                continue
357	            fi
358	            deploy_managed_file "$_rule_content" "$RULES_DEST/$rule_name" "claude rules" "$rule_name" "$_rule_adopt_path"
359	
360	            case "$MANAGED_FILE_RESULT" in
361	                created|updated|verified|"accept & adopt"|skipped|failed)
362	                    # The library wrote LOCAL and the adopt target itself; the
363	                    # tracker records every outcome (failed -> ERROR row).
364	                    ;;
365	            esac
366	            deploy_tracker_record "$MANAGED_FILE_RESULT" "claude rules" "$rule_name"
367	            # After a merge & adopt (the library already wrote the merge to the
368	            # dotprofile), auto commit+push to keep the dotprofile in sync.
369	            # Kept: commander confirmed 2026-10-21 (contract item #11).
370	            if [ "$MANAGED_FILE_RESULT" = "accept & adopt" ] && [ -n "${MERGED_CONTENT:-}" ] && [ -n "${USER_REPO_PATH:-}" ]; then
371	                # Suppress git stderr noise; failure handled by if/else branches
372	                if (cd "$USER_REPO_PATH" && \
373	                    git add "claude/rules/$rule_name" && \
374	                    git diff --cached --quiet "claude/rules/$rule_name") 2>/dev/null; then
375	                    # git diff --cached --quiet exits 0 = no staged changes
376	                    log "No diff to commit in user repo for $rule_name"
377	                else
378	                    # Suppress git stderr noise; failure handled by if/else branches
379	                    if (cd "$USER_REPO_PATH" && \
380	                        git add "claude/rules/$rule_name" && \
381	                        git commit -m "Sync merged $rule_name from deploy" && \
382	                        git push) 2>/dev/null; then
383	                        log_ok "Pushed merged $rule_name to user repo"
384	                    else
385	                        log_warn "Failed to push merged $rule_name to user repo"
386	                        write_summary WARN "claude rules" "$rule_name not pushed"
387	                    fi
388	                fi
389	            fi
390	        done
391	
392	        # Log preserved files (in target but not in source)
393	        if [ -d "$RULES_DEST" ]; then
394	            for existing in "$RULES_DEST"/*.md; do
395	                [ -f "$existing" ] || continue
396	                exist_name=$(basename "$existing")
397	                if [ ! -f "$RULES_SRC/$exist_name" ]; then
398	                    log "Preserved unmanaged rule: $exist_name"
399	                    deploy_tracker_record "preserved" "claude rules" "$exist_name"
400	                fi
401	            done
402	        fi
403	
404	        # Post-write validation: each deployed file is non-empty (a file whose
405	        # deploy failed is already reported; the library left it as it was)
406	        for rule_file in "$RULES_SRC"/*.md; do
407	            [ -f "$rule_file" ] || continue
408	            rule_name=$(basename "$rule_file")
409	            if [ -f "$RULES_DEST/$rule_name" ] && [ ! -s "$RULES_DEST/$rule_name" ]; then
410	                log_error "Validation failed: $rule_name is empty after deploy"
411	            fi
412	        done
413	
414	        if [ "$_DT_FAILED" -gt 0 ]; then
415	            # deploy_tracker_summary writes the ERROR row ("N failed")
416	            deploy_tracker_summary "claude rules"
417	            log "Rules: $DEPLOY_TRACKER_TEXT, $_DT_PRESERVED preserved in $(display_path "$RULES_DEST")"
418	        elif [ "$ERRORS" -eq "$ERRORS_BEFORE_RULES" ]; then
419	            deploy_tracker_summary "claude rules"
420	            log_ok "Rules: $DEPLOY_TRACKER_TEXT, $_DT_PRESERVED preserved in $(display_path "$RULES_DEST")"
421	        else
422	            write_summary ERROR "claude rules" "validation failed"
423	        fi
424	    fi
425	else
426	    log "No user rules to deploy (no claude/rules/ in user repo)"
427	fi
428	# --- END rules deploy logic (extracted by build-deploy) ---
429	# --- END rules deployment (extracted by build-deploy) ---
```

How rules are deployed today (dev path, .sh), point by point:
- **Function**: `deploy_managed_file CONTENT DEST "claude rules" NAME ADOPT` (358), outcomes to `deploy_tracker_record` (366), row from `deploy_tracker_summary "claude rules"` (416/419).
- **Source**: `<USER_REPO_PATH>/claude/rules` only (291-292). No `~/.aitools` involvement.
- **Filter**: shell glob `"$RULES_SRC"/*.md` (310, 344, 406) and `find -name '*.md'` (299, 305). Case-sensitive (`X.MD` is not deployed by the .sh). Dot files: the glob skips them. `*.bak.*`: not explicitly skipped; a `name.md.bak.<ts>` does not end in `.md`, so the glob skips it, but a name like `a.bak.b.md` would be deployed.
- **Backup**: `backup_dir "$RULES_DEST"` (335) before the loop (whole dir, `rules.bak.<ts>/`, result not checked: non-fatal by policy, config-file-safety.md "Backup failures are non-fatal"); per file inside `deploy_managed_file`.
- **Adopt**: target `<USER_REPO_PATH>/claude/rules/<name>` (349-352); empty in MDM when no dotprofile.
- **Tracker outcomes**: created/updated/verified/accept & adopt/skipped/failed (+ `preserved` at 399). No `removed`. An unknown result is silently dropped by `deploy_tracker_record` (aitools-lib.sh 2283-2296: the `case` has no `*)` branch).
- **Summary rows**: `claude rules` OK/WARN/ERROR via the tracker; ERROR `cannot create rules dir` (338, then `exit 1`); ERROR `validation failed` (422); WARN `<rule> not pushed` (386; removed by #103).
- **Dry run**: logs only; **no `claude rules` summary row** (PR #112 follow-up lists this).
- **No source**: `log "No user rules to deploy ..."` (426), no row.

### 3.3 setup-user-claude.ps1 rules section -- lines 306-461 (every line would change; file is CRLF)

```powershell
306	# --- BEGIN rules deployment (extracted by build-deploy) ---
307	# Deploy user rules: additive (add/update managed, preserve unmanaged, log diffs).
308	$rulesSrc = ""
309	if ($userRepoPath) {
310	    $candidateRules = Join-Path $userRepoPath "claude\rules"
311	    if (Test-Path $candidateRules) {
312	        $rulesSrc = $candidateRules
313	    }
314	}
315	
316	$rulesDest = Join-Path $claudeDir "rules"
317	
318	# --- BEGIN rules deploy logic (extracted by build-deploy) ---
319	if ($rulesSrc) {
320	    $sourceRules = Get-ChildItem -Path $rulesSrc -Filter "*.md" -File -ErrorAction Stop
321	    if (-not $sourceRules -or $sourceRules.Count -eq 0) {
322	        Log "User repo claude/rules/ exists but has no .md files -- skipping"
323	    } elseif ($DryRun) {
324	        $existingCount = 0
325	        if (Test-Path $rulesDest) {
326	            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
327	            if ($existingFiles) { $existingCount = $existingFiles.Count }
328	        }
329	        Log "[DRY RUN] $rulesDest`: additive deploy"
330	        Log "  Source: $rulesSrc ($($sourceRules.Count) rule files)"
331	        Log "  Existing: $existingCount rule files"
332	        foreach ($rf in $sourceRules) {
333	            $destFile = Join-Path $rulesDest $rf.Name
334	            if (Test-Path $destFile) {
335	                try {
336	                    $oldContent = Get-Content $destFile -Raw -ErrorAction Stop
337	                    $newContent = Get-Content $rf.FullName -Raw -ErrorAction Stop
338	                } catch {
339	                    LogWarn "Cannot compare $($rf.Name): $_"
340	                    Log "  Would update (cannot compare): $($rf.Name)"
341	                    continue
342	                }
343	                if ($oldContent -eq $newContent) {
344	                    Log "  Would skip (unchanged): $($rf.Name)"
345	                } else {
346	                    Log "  Would update (changed): $($rf.Name)"
347	                }
348	            } else {
349	                Log "  Would add (new): $($rf.Name)"
350	            }
351	        }
352	        # Show preserved files
353	        if (Test-Path $rulesDest) {
354	            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
355	            foreach ($ef in $existingFiles) {
356	                $srcMatch = Join-Path $rulesSrc $ef.Name
357	                if (-not (Test-Path $srcMatch)) {
358	                    Log "  Would preserve (unmanaged): $($ef.Name)"
359	                }
360	            }
361	        }
362	    } else {
363	        Backup-Dir -DirPath $rulesDest
364	        if (-not (Test-Path $rulesDest)) {
365	            try {
366	                New-Item -ItemType Directory -Path $rulesDest -Force -ErrorAction Stop | Out-Null
367	            } catch {
368	                LogError "Cannot create $rulesDest ($_)"
369	                Write-Summary "ERROR" "claude rules" "cannot create rules dir"
370	                exit 1
371	            }
372	        }
373	
374	        Initialize-DeployTracker
375	        $errorsBefore = $errors
376	        foreach ($rf in $sourceRules) {
377	            $destFile = Join-Path $rulesDest $rf.Name
378	            # Adopt target: the dotprofile rule (the file deployed from). Empty
379	            # in the MDM deploy script (no user repo): adopt and merge not offered.
380	            $ruleAdoptPath = ""
381	            if ($userRepoPath) { $ruleAdoptPath = Join-Path (Join-Path $userRepoPath "claude\rules") $rf.Name }
382	
383	            try {
384	                $ruleContent = Get-Content $rf.FullName -Raw -ErrorAction Stop
385	            } catch {
386	                LogError "Cannot read source rule $($rf.Name): $_"
387	                Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rf.Name
388	                continue
389	            }
390	            $ruleResult = Deploy-ManagedFile -Content $ruleContent -DestPath $destFile -ToolName "claude rules" -ItemName $rf.Name -AdoptPath $ruleAdoptPath
391	
392	            if ($ruleResult -in @("created", "updated", "verified", "accept & adopt", "skipped", "failed")) {
393	                # The library wrote LOCAL and the adopt target itself; the
394	                # tracker records every outcome (failed -> ERROR row).
395	            }
396	            Record-DeployOutcome -Outcome $ruleResult -ToolName "claude rules" -ItemName $rf.Name
397	            # After a merge & adopt (the library already wrote the merge to the
398	            # dotprofile), auto commit+push to keep the dotprofile in sync.
399	            # Kept: commander confirmed 2026-10-21 (contract item #11).
400	            if ($ruleResult -eq "accept & adopt" -and $script:MergedContent -and $userRepoPath) {
401	                try {
402	                    Push-Location $userRepoPath
403	                    & git add "claude/rules/$($rf.Name)"
404	                    # Suppress git stderr noise; LASTEXITCODE checked on next line
405	                    & git diff --cached --quiet "claude/rules/$($rf.Name)" 2>$null
406	                    if ($LASTEXITCODE -ne 0) {
407	                        # Has staged changes -- commit and push
408	                        & git commit -m "Sync merged $($rf.Name) from deploy"
409	                        if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
410	                        & git push
411	                        if ($LASTEXITCODE -ne 0) { throw "git push failed" }
412	                        LogOk "Pushed merged $($rf.Name) to user repo"
413	                    } else {
414	                        Log "No diff to commit in user repo for $($rf.Name)"
415	                    }
416	                } catch {
417	                    LogWarn "Failed to push merged $($rf.Name) to user repo: $_"
418	                    Write-Summary "WARN" "claude rules" "$($rf.Name) not pushed"
419	                } finally {
420	                    Pop-Location
421	                }
422	            }
423	        }
424	
425	        # Log preserved files (in target but not in source)
426	        if (Test-Path $rulesDest) {
427	            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
428	            foreach ($ef in $existingFiles) {
429	                $srcMatch = Join-Path $rulesSrc $ef.Name
430	                if (-not (Test-Path $srcMatch)) {
431	                    Log "Preserved unmanaged rule: $($ef.Name)"
432	                    Record-DeployOutcome -Outcome "preserved" -ToolName "claude rules" -ItemName $ef.Name
433	                }
434	            }
435	        }
436	
437	        # Post-write validation: each deployed file is non-empty (a file whose
438	        # deploy failed is already reported; the library left it as it was)
439	        foreach ($rf in $sourceRules) {
440	            $destFile = Join-Path $rulesDest $rf.Name
441	            if ((Test-Path $destFile) -and (Get-Item $destFile).Length -eq 0) {
442	                LogError "Validation failed: $($rf.Name) is empty after deploy"
443	            }
444	        }
445	
446	        if ($script:dtFailed -gt 0) {
447	            # Write-DeployTrackerSummary writes the ERROR row ("N failed")
448	            Write-DeployTrackerSummary -ToolName "claude rules"
449	            Log "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
450	        } elseif ($errors -eq $errorsBefore) {
451	            Write-DeployTrackerSummary -ToolName "claude rules"
452	            LogOk "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
453	        } else {
454	            Write-Summary "ERROR" "claude rules" "validation failed"
455	        }
456	    }
457	} else {
458	    Log "No user rules to deploy (no claude/rules/ in user repo)"
459	}
460	# --- END rules deploy logic (extracted by build-deploy) ---
461	# --- END rules deployment (extracted by build-deploy) ---
```

.ps1 differences from the .sh (parity defects):
- `-Filter "*.md"` (320, 326, 354, 427) is case-insensitive on Windows (the known "case-sensitive .sh vs case-insensitive .ps1" defect). On pwsh for macOS/Linux: unknown (not probed).
- `-Path` (not `-LiteralPath`) in Get-ChildItem/Test-Path/Get-Content: a name with `[ ]` is treated as a wildcard (same class as the Backup-File bug fixed in 9923a3c).
- Dry-run comparison `$oldContent -eq $newContent` (343) is case-insensitive and keeps trailing newlines; the .sh uses `diff -q` (byte compare). PR #112 fixed exactly this for CLAUDE.md (A-26) but not for rules.
- `Get-ChildItem ... -ErrorAction Stop` at 320/326/354/427 is not in a try: a listing failure is a terminating error with no `claude rules` row.

### 3.4 Live state (for the migration)

- `ls -la /Users/new-jose/.claude/rules`: `concurrent-agents.md` (483 B, Jun 14), `delegation.md` (6828 B, Oct 21), `delegation.md.bak.2026-10-22T045154Z`.
- Dotprofile `/Users/new-jose/repos/aitools-nobul-jose/claude/rules`: `concurrent-agents.md` (483 B), `delegation.md` (6828 B). Same names and sizes as the live copies.
- `/Users/new-jose/.aitools/rules`: does not exist (brief, S3-FanPlan 2026-10-26).
- aitools sources that deploy-harness would put in `~/.aitools/rules`: `shared/rules/` = `hook-lifecycle.md`, `scratch.md`; `.claude/rules/` = 26 files (agentic-standards.md ... web-sources.md). No name collides with the two dotprofile rules (ls output).
- After the refactor, the first run on this Mac would add 28 files to `~/.claude/rules` and verify the two dotprofile rules (identical content). `delegation.md.bak.*` is not `*.md`: ignored, as today.

### 3.5 build-deploy.sh: the setup-user-claude generator

Already a pure extract (comment at 625-628: "Pure extract from scripts/setup-user-claude.sh (template interpolation, footer, managed-file deploy, rules logic: no duplicated logic, I6), plus two generated parts"). deploy-paths.md still says it is duplicated (see 8, INCIDENT 1).

**User-rule embed inputs -- lines 222-236 (would be removed):**

```bash
222	# --- User rules (embedded as a fallback; see "Embedded dotprofile content") ---
223	USER_RULE_COUNT=0
224	declare -a USER_RULE_FILES=()
225	if [ -d "$_urp/claude/rules" ]; then
226	    for rf in "$_urp/claude/rules"/*.md; do
227	        [ -f "$rf" ] || continue
228	        USER_RULE_FILES+=("$rf")
229	        USER_RULE_COUNT=$((USER_RULE_COUNT + 1))
230	    done
231	fi
232	if [ "$USER_RULE_COUNT" -gt 0 ]; then
233	    blog "User rules: $USER_RULE_COUNT files from $_urp/claude/rules"
234	else
235	    blog "No user rules in the dotprofile -- the deploy scripts embed none (a machine with the dotprofile still uses its own claude/rules/)"
236	fi
```

`USER_RULE_COUNT` / `USER_RULE_FILES` are used only at 518-521, 566-569, 692, 786 (grep of the file as read). The comment block at 238-243 also names "rules embedded below":

```bash
238	# --- Embedded dotprofile content: fallbacks, resolved per machine at RUNTIME ---
239	# deploy/ is committed once and used by every machine of this user, so no machine's
240	# values are interpolated here (M3 B5: the cross-machine defect, decision 4). The
241	# generated setup-user-claude.* resolve this machine's profile when they run: from
242	# the live dotprofile on that machine when it has one (what scripts/ reads), else
243	# from the build-time template, profile snapshot and rules embedded below.
```

**Resolver block, bash (claude variant) -- lines 483-484, 504, 511-522:**

```bash
483	# write_resolver_block_bash OUT [claude] -- the bash embed block; "claude" adds the
484	# dotprofile fallbacks (template, profile snapshot, rules).
...
504	elif ! mkdir -p "$_AITOOLS_EMBED_DIR/claude" "$_AITOOLS_EMBED_DIR/shared" "$_AITOOLS_EMBED_DIR/rules"; then
...
511	        if [ "$with_claude" = "claude" ]; then
512	            printf '# Dotprofile content at build time: fallbacks for a machine without the dotprofile\n'
513	            embed_file_bash "claude/CLAUDE.md" "$TEMPLATE_FILE"
514	            embed_file_bash "shared/claude-shared.md" "$CLAUDE_SHARED"
515	            if [ -n "$PROFILE_SNAPSHOT" ]; then
516	                embed_file_bash "profile.json" "$BUILD_TMP/profile-snapshot.json"
517	            fi
518	            for i in $(seq 0 $((USER_RULE_COUNT - 1))); do
519	                [ "$USER_RULE_COUNT" -gt 0 ] || break
520	                embed_file_bash "rules/$(basename "${USER_RULE_FILES[$i]}")" "${USER_RULE_FILES[$i]}"
521	            done
522	        fi
```

Note: line 504 is inside the quoted heredoc `BLOCK` (489-507), so it is emitted text, used by every resolver consumer (claude, cursor, settings). Removing `"$_AITOOLS_EMBED_DIR/rules"` there is harmless for the other two (they never write `rules/`).

**Resolver block, PowerShell -- lines 534, 559-570:**

```bash
534	# write_resolver_block_ps1 OUT [claude] -- the PowerShell embed block (same content)
...
559	        if [ "$with_claude" = "claude" ]; then
560	            printf '# Dotprofile content at build time: fallbacks for a machine without the dotprofile\n'
561	            embed_file_ps1 "claude/CLAUDE.md" "$TEMPLATE_FILE"
562	            embed_file_ps1 "shared/claude-shared.md" "$CLAUDE_SHARED"
563	            if [ -n "$PROFILE_SNAPSHOT" ]; then
564	                embed_file_ps1 "profile.json" "$BUILD_TMP/profile-snapshot.json"
565	            fi
566	            for i in $(seq 0 $((USER_RULE_COUNT - 1))); do
567	                [ "$USER_RULE_COUNT" -gt 0 ] || break
568	                embed_file_ps1 "rules/$(basename "${USER_RULE_FILES[$i]}")" "${USER_RULE_FILES[$i]}"
569	            done
570	        fi
```

**Generated .sh header + extracts -- lines 620-711:**

```bash
620	# ============================================================
621	# 1. deploy/setup-user-claude.sh
622	# ============================================================
623	blog "Generating deploy/setup-user-claude.sh"
624	
625	# Pure extract from scripts/setup-user-claude.sh (template interpolation, footer,
626	# managed-file deploy, rules logic: no duplicated logic, I6), plus two generated
627	# parts: the profile/template source on this machine (before the body) and the
628	# rules fallback (between the rules source selection and the rules logic).
629	{
630	    echo '#!/usr/bin/env bash'
631	    echo "$HEADER_COMMENT_BASH"
632	    cat <<'BLOCK'
633	# setup-user-claude.sh -- Creates user-level ~/.claude/CLAUDE.md and deploys user rules
634	# Self-contained (MDM-ready): the profile resolver and build-time copies of the
635	# dotprofile's CLAUDE.md template, profile snapshot and rules are embedded below.
636	# This machine's profile is resolved when the script runs, never at build time. On a
637	# machine with the dotprofile, its live template, profile.json and rules are used
638	# (as by scripts/setup-user-claude.sh); the embedded copies are the fallback.
639	# Safe to re-run.
640	#
641	# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
642	# Managed: ~/.claude/rules/*.md (additive deploy from the rules source)
643	# Preserved: ~/.claude/rules/ files not in the rules source
644	
645	set -euo pipefail
646	
647	BLOCK
648	    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
649	        '^# --- BEGIN preamble' '^# --- END preamble'
...
688	    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
689	        '^# --- END preamble' '^# --- BEGIN rules deployment'
690	    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
691	        '^# --- BEGIN rules deployment' '^# --- BEGIN rules deploy logic'
692	    if [ "$USER_RULE_COUNT" -gt 0 ]; then
693	        cat <<'BLOCK'
694	# --- Rules fallback (generated by build-deploy.sh): the build-time copy when this
695	# machine has no dotprofile (a dotprofile without claude/rules/ deploys none, as
696	# scripts/ does; review m3) ---
697	if [ "$_DP_RC" -ne 0 ] && [ -z "$RULES_SRC" ] && [ -n "$_AITOOLS_EMBED_DIR" ] && [ -d "$_AITOOLS_EMBED_DIR/rules" ]; then
698	    RULES_SRC="$_AITOOLS_EMBED_DIR/rules"
699	    log "Rules source: embedded build-time copy (no dotprofile on this machine)"
700	fi
701	BLOCK
702	    fi
703	    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
704	        '^# --- BEGIN rules deploy logic' '^# --- END rules deploy logic'
705	    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
706	        '^# --- BEGIN exit' '^# --- END exit'
707	} | inline_lib_bash "$BUILD_TMP/resolver-claude.sh.blk" > "$DEPLOY_DIR/setup-user-claude.sh"
```

Extraction semantics that constrain the refactor: `extract_between` (335-357) prints the lines strictly between the first START match and the next END match (perl flip-flop), and fails the build if the result is empty. So:
- The span `END preamble .. BEGIN rules deployment` (688-689) is the CLAUDE.md body; the span `BEGIN rules deployment .. BEGIN rules deploy logic` (690-691) is the rules source selection; the span `BEGIN rules deploy logic .. END rules deploy logic` (703-704) is the rules logic. If the refactor keeps the three markers (`BEGIN rules deployment`, `BEGIN rules deploy logic`, `END rules deploy logic`) and puts all fan-out code inside them, the generator needs no structural change: delete 692-702 (and its .ps1 twin) and both extracts still work.
- If the source-selection span (between `BEGIN rules deployment` and `BEGIN rules deploy logic`) becomes empty, `extract_between` fails the build ("sentinels not found" message; 352-355). Either keep at least one line there (e.g. `HARNESS_RULES_DIR=...`), or delete the 690-691 / 784-785 extract and merge the markers. Recommendation: keep both markers, put `HARNESS_RULES_DIR` / `RULES_DEST` assignments in the first span.
- The marker regexes are `^# --- BEGIN rules deployment` etc. (prefix match): rewording the marker comment after the prefix is safe; changing the prefix breaks the build.

**Generated .ps1 -- lines 712-805 (same structure):**

```bash
717	# Pure extract from scripts/setup-user-claude.ps1, plus the same two generated parts
718	# as the .sh (parity).
...
722	# setup-user-claude.ps1 -- Creates user-level ~/.claude/CLAUDE.md and deploys user rules
723	# Self-contained (MDM-ready): the profile resolver and build-time copies of the
724	# dotprofile's CLAUDE.md template, profile snapshot and rules are embedded below.
725	# This machine's profile is resolved when the script runs, never at build time. On a
726	# machine with the dotprofile, its live template, profile.json and rules are used
727	# (as by scripts/setup-user-claude.ps1); the embedded copies are the fallback.
728	# Safe to re-run.
729	#
730	# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
731	# Managed: ~/.claude/rules/*.md (additive deploy from the rules source)
732	# Preserved: ~/.claude/rules/ files not in the rules source
...
782	    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
783	        '^# --- END preamble' '^# --- BEGIN rules deployment' --crlf
784	    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
785	        '^# --- BEGIN rules deployment' '^# --- BEGIN rules deploy logic' --crlf
786	    if [ "$USER_RULE_COUNT" -gt 0 ]; then
787	        cat <<'BLOCK'
788	# --- Rules fallback (generated by build-deploy.sh): the build-time copy when this
789	# machine has no dotprofile (a dotprofile without claude/rules/ deploys none, as
790	# scripts/ does; review m3) ---
791	$aitoolsEmbedRules = Join-Path $aitoolsEmbedDir "rules"
792	if ($aitoolsDpRc -ne 0 -and -not $rulesSrc -and (Test-Path -LiteralPath $aitoolsEmbedRules)) {
793	    $rulesSrc = $aitoolsEmbedRules
794	    Log "Rules source: embedded build-time copy (no dotprofile on this machine)"
795	}
796	BLOCK
797	    fi
798	    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
799	        '^# --- BEGIN rules deploy logic' '^# --- END rules deploy logic' --crlf
800	    printf '%s\n' "$EMBED_CLEANUP_PS1"
801	    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
802	        '^# --- BEGIN exit' '^# --- END exit' --crlf
803	} | inline_lib_ps1 "$BUILD_TMP/resolver-claude.ps1.blk" > "$DEPLOY_DIR/setup-user-claude.ps1"
```

The generator also needs `_DP_RC` / `$aitoolsDpRc` only for the profile/template block (657-686, 750-780) after 692-702/786-797 go; those stay.

**Other build-deploy text that names the rules embed or the run order:**

```bash
11	# deploy/deploy-harness.sh/.ps1 (the MDM path of scripts/deploy-harness.*) embed a
12	# snapshot of every harness source file (~/.aitools); MDM runs it first, before
13	# setup-user-cursor, whose rules fan-out reads ~/.aitools/rules. Its config.json
14	# writer (setup-user-config + aitools-profile + aitools-json) is copied alongside.
...
855	# Run deploy-harness.sh first: step 4 fans out ~/.aitools/rules, which it fills.
...
895	# Run deploy-harness.ps1 first: step 4 fans out .aitools\rules, which it fills.
...
1689	#   - section 2 (dotprofile lookup) is replaced: dotprofile rules are the
1690	#     build-time dotprofile's, as with setup-user-claude's embedded rules;
...
1913	# Run it FIRST in an MDM sequence: setup-user-cursor (and the other rules
1914	# fan-out consumers) read ~/.aitools/rules, which this script fills.
...
1927	#   - dotprofile rules are those of the dotprofile deploy/ was built from;
...
2063	# Run it FIRST in an MDM sequence: setup-user-cursor (and the other rules
2064	# fan-out consumers) read .aitools\rules, which this script fills.
```

Lines 855/895 are the cursor generator's header (setup-user-cursor's "Run deploy-harness first"); the claude header BLOCKs (633-643, 722-732) have no such line and should get one.

### 3.6 The MDM counterpart of `~/.aitools/rules` (does deploy/ ship it? order?)

- **Yes on main's generator.** build-deploy.sh 1676-2203 generate `deploy/deploy-harness.sh/.ps1`. The source directories are parsed from deploy-harness.sh `add_source` lines (1711-1735), which include `shared/rules`, `.claude/rules` (aitools) and `claude/rules` (dotprofile) (deploy-harness.sh 260-264). Each is snapshotted via `git ls-files -s -z` (1763-1775) and embedded (base64; PR #111 moves it to `deploy/deploy-harness.payload`). Section 2 (dotprofile lookup) is replaced with `DOTPROFILE="$MDM_STAGE/dotprofile"` (2032), so section 4's `add_source rules "dotprofile" ...` runs against the build-time dotprofile snapshot. Sections 3-7 are extracted unchanged (`extract_span ... '^# 3\. The six directories' EOF`, 2040), so #100's section 5b (manifest + retire) reaches MDM with no build-deploy change (#100 body: "MDM: all new code is in section 5b ... no build-deploy change needed").
- **Not in the live dotprofile.** `ls -la /Users/new-jose/repos/aitools-nobul-jose/deploy` lists 42 `setup-*.{sh,ps1}` files and no `deploy-harness.*`, `setup-user-config.*`, `aitools-profile.*`, `aitools-json.*`. `git log` on `deploy/setup-user-claude.sh` there: last commit `825aed4 2026-10-22 18:59:05 -0700`. Its content is the pre-M3 duplicated generator: header line 4 `# Self-contained: shared preferences and user rules are embedded below. No repo needed.`, CLAUDE.md embedded as heredoc (2793-2934), rules embedded as heredocs at 3014-3170 (`RULES_SRC=$(mktemp -d)`, `cat > "$RULES_SRC/concurrent-agents.md" <<'__RULE_concurrent_agents_md___'`), rules loop 3171-3291. This is the known pre-push step 7 "dotprofile deploy/ stale".
- **Order on an endpoint**: nothing enforces it. There is no MDM runner in deploy/; the order lives only in comments (build-deploy.sh 11-13, 855, 895, 1913-1914, 2063-2064) and in PR #99's draft "MDM run order" section for deploy-paths.md (pr99.diff 415-421: "`deploy/deploy-harness.sh/.ps1` runs first ... the rules fan-out in `setup-user-cursor` (and `setup-user-claude` once it fans out) reads `~/.aitools/rules`. Run in the other order, the fan-out step reports `n/a (no harness rules)` and deploys nothing."). The fan-out in setup-user-claude must therefore report a clear row when `~/.aitools/rules` is absent (cursor precedent: `write_summary OK "cursor rules" "n/a (no harness rules)"`, setup-user-cursor.sh 476-478, 512-514).
- **Dev path order**: on main, deploy-harness is not run by any entry point: `grep -rn "deploy-harness\|setup-user-claude"` over scripts/aitools, aitools.ps1, aitools-install.sh/.ps1 finds only the setup-user-claude entries (aitools-install.sh:833, aitools.ps1:157, aitools:1108/1151, aitools-install.ps1:761) and no deploy-harness call. Wiring is in open PRs #106/#116 (Install explorer's slice; their order relative to setup-user-claude: unknown to me).

### 3.7 The precedent to copy: setup-user-cursor.sh step 4 (on main)

setup-user-cursor.sh 378-653 already fans out `~/.aitools/rules`. Key behaviour a planner can mirror (all verbatim in the file):
- Source dir `HARNESS_RULES_DIR="$HOME/.aitools/rules"` (389).
- Absent dir: `log "No harness rules at ... (deploy-harness has not run) -- skipping"` + `write_summary OK "cursor rules" "n/a (no harness rules)"` (476-478). Unreadable: ERROR `cannot read harness rules` (479-481).
- Filter (491-498): `*.bak.*) continue ;;` then `*.md) ;;` else `log "Ignoring non-rule file ..."`; dangling symlink -> failed (499-503, 525-529). Glob `"$HARNESS_RULES_DIR"/*` skips dot files (so `.aitools-rules-manifest` is never seen). Case-sensitive `*.md` (same .sh/.ps1 defect).
- Case-insensitive duplicate destination check, first wins, failed + log_error (539-550).
- `deploy_managed_file ... "cursor rules" "$dest_name" ""` (568): adopt target empty; `"accept & adopt"` unreachable -> log_error; `*)` -> log_error + failed (569-580).
- Dry run goes through the library and writes a row (`dry run (no files written)` / `N failed (dry run)`) (584-589).
- Preserved: everything in the dest not produced this run, skipping `*.bak.*`, compared lower-cased (591-605).
- Validation + summary block (607-650) mirrors setup-user-claude's (414-423).
PR #110 replaces this step with manifest-driven fan-out and pruning (see 5).

## 4. What must change (or be checked), and why

| # | Where | Change | Why |
|---|---|---|---|
| C1 | setup-user-claude.sh 12-14, .ps1 11-13 | Managed/Preserved header: rules come from `~/.aitools/rules/*.md` (deploy-harness), not `<userRepoPath>/claude/rules`; say *.bak.* and non-.md skipped, retired copies removed; "Run deploy-harness first". | config-file-safety.md "Directory deployment" step 1 (declare managed scope in header); header must match body. |
| C2 | sh 290-293, ps1 308-314 (source selection span) | `RULES_SRC="$HOME/.aitools/rules"` / `Join-Path $env:USERPROFILE ".aitools\rules"`; no `USER_REPO_PATH` dependency. Keep at least one line in this span (3.5). | "it stops deploying dotprofile rules directly" (brief). |
| C3 | sh 298-427, ps1 319-459 (logic span) | Replace with the fan-out: list every regular `*.md` in `~/.aitools/rules`, case-insensitive (`*.[mM][dD]` in bash 3.2, or `-like '*.md'` in .ps1), skip `*.bak.*` (case-insensitive) and dot files, dangling symlink = failed; absent/empty dir = `OK "claude rules" "n/a (no harness rules)"`; deploy each via `deploy_managed_file`; preserved = dest `*.md` not in this run's set (case-insensitive); retired handling (C4); validation; summary. Add `*)` branch for unexpected results. Dry run: emit a row (cursor wording or the lib's). | Commander contract (brief: everything minus retired, case-insensitive, *.md only, skip *.bak.*). Cursor parity (3.7). |
| C4 | new code in the logic span | Read `~/.aitools/rules/.aitools-rules-manifest` (format in 5, PR #100); for each `retired` name, back up and remove `~/.claude/rules/<name>` only when it is the fan-out's copy (recognition rule: open question Q2). Report each removal (DETAIL `removed: <name>`; there is no `removed` tracker outcome). No manifest / bad header: open question Q3. | #100 contract: "Consumers: ... back up and remove their own deployed copy of every `retired` name". |
| C5 | sh 347-352, ps1 378-381 (adopt target) | Decide the adopt target (Q1). Options: `""` (cursor precedent; loses today's adopt-into-dotprofile + N-Q2 push); or map from the manifest source: `dotprofile` -> `$USER_REPO_PATH/claude/rules/<name>`, `aitools` -> `$SCRIPT_DIR/../.claude/rules/<name>` (protected file: lib WARNs, working tree only), `shared` -> `$SCRIPT_DIR/../shared/rules/<name>`; MDM `""` (no repo). | Today's behaviour adopts into the dotprofile (3.2). Losing it silently would be a behaviour change the commander has not approved. |
| C6 | sh 367-389, ps1 397-422 | Remove the private commit+push block. | Already done by #103/#112; the refactor must be based on them (5). |
| C7 | sh 71-82, ps1 70-80 | Decide whether `URP_RC -eq 3` still stops the rules fan-out (rules no longer need the dotprofile) (Q4). | Today: one exit for CLAUDE.md and rules. |
| C8 | build-deploy.sh 222-236, 243, 484, 504, 518-521, 566-569 | Remove the user-rules embed and its comments. | The MDM rules now arrive through deploy-harness (3.6). |
| C9 | build-deploy.sh 625-628, 692-702, 717-718, 786-797 | Remove both "Rules fallback" blocks and the comment naming them. | Same. |
| C10 | build-deploy.sh 633-643, 722-732 | Header BLOCKs: drop "and rules" from the embedded list, "the rules source" -> `~/.aitools/rules`, add "Run deploy-harness.sh/.ps1 first". | Header accuracy; endpoint order (3.6). |
| C11 | build-deploy.sh 11-14, 1689-1690 | Comments: add setup-user-claude to the fan-out consumers; drop "as with setup-user-claude's embedded rules". | Stale after C8. |
| C12 | tests/rules-fanout/ (new) | Regression test (brief). Model: PR #110's `tests/rules-fanout-cursor/` (sh + `step4-driver.ps1` parity, manifest fixtures). | Brief. |
| C13 | tests/claude-mdm/test-claude-mdm.sh (from #112) | Its check "MDM sh run: ... rules deployed" (`grep -qx 'rule one' '$TMP_ROOT/mdm-sh/.claude/rules/r1.md'`, pr112.diff 1496-1497) relies on dotprofile rules reaching `~/.claude/rules`. Must be changed to seed `~/.aitools/rules` (or expect `n/a`). | It will fail after the refactor. |
| C14 | protected: `.claude/rules/deploy-paths.md`, `.cursor/rules/deploy-paths.mdc` | Drafts only. Based on #99's text: bullet "`<userRepoPath>/claude/rules/*.md` -> read at build time (the fallback rules)" and "and the rules fallback" in the setup-user-claude pure-extract bullet become wrong; "(and `setup-user-claude` once it fans out)" becomes "and `setup-user-claude`". On main's text (no #99): lines 56 and 69 (3.5, INCIDENT 1). | Protected (sources-of-truth.md). |
| C15 | protected: `reference/user-repo.md` 18, 181-195 | Drafts: "User Rules Deployment" describes source `<userRepoPath>/claude/rules/*.md` -> `~/.claude/rules`, and "Build-time embedding: build-deploy.sh reads user rules at build time and embeds them in deploy scripts via heredocs" (195). Both wrong after the refactor (dotprofile rules -> `~/.aitools/rules` via deploy-harness -> `~/.claude/rules` via setup-user-claude). Tree comment at 18 "(deployed to ~/.claude/rules/)". | Protected. |
| C16 | protected: `.claude/rules/managed-file-deployment.md` "Rules" bullet; `.claude/rules/config-file-safety.md` "Directory deployment" example (`# Managed: ~/.claude/rules/*.md matching <userRepoPath>/claude/rules/`) | Drafts (outside my slice; #100 has a draft for the first). | Stale examples. |
| C17 | check-pre-commit.sh:267 | No change; note: touching setup-user-claude.* without build-deploy.sh triggers step 13 WARN. The refactor touches both. | |

## 5. Interactions with open PRs

**#103 (fix/mf-dotprofile-adopt-push) and #112 (fix/mf-audit-claude-build, stacked on #103; merge after #103).**
- Both remove sh 367-389 and ps1 397-422 (the private commit block) and put this comment in its place (pr112.diff 1182-1184 / 1082-1084):
  ```
  # After accept & adopt or merge & adopt the library commits that one
  # dotprofile rule and pushes it (dotprofile_commit_push, N-Q2;
  # commander confirmed 2026-10-21, contract item #11). No commit here.
  ```
  The library helper `dotprofile_commit_push` only commits when the adopt target is inside the dotprofile (#103 body, "not-dotprofile: detail line only"). So option C5 "map dotprofile-source rules to `$USER_REPO_PATH/claude/rules/<name>`" keeps N-Q2 working with no code in setup-user-claude.
- #112 also changes sh 93-109 (hostname) -> `MACHINE_HOST="${AITLIB_MACHINE_HOSTNAME:-}"`, sh 216-238 / ps1 230-254 (dry-run rows for claude.md), and build-deploy.sh 42-46, 192-202, 544-596 (PS1 embed block becomes `try {`), 800-803 (adds `printf '%s\n' "$EMBED_FINALLY_PS1"` after the claude .ps1 exit footer), 2216+ (post-build try/finally check). None of these overlap the rules spans, but line numbers shift: after #112, the sh rules section starts about 11 lines earlier (hunk `@@ -364,29 +364,9 @@` on the post-#103 file). **The planner must write old_string text against the post-#112 file, or against main and rebase.** Recommendation: base the fan-out branch on #112's head (or wait for #103 and #112 to merge), because both PRs delete the exact block the refactor would otherwise rewrite.
- #112's new test `tests/claude-mdm/test-claude-mdm.sh`: fixture dotprofile has `claude/rules/r1.md` (pr112.diff 1278-1280) and the MDM run checks it lands in `~/.claude/rules` (1496-1497). That check breaks after the fan-out (C13). The A-19 post-build check (EMBED_FINALLY_PS1 must be the last line of setup-user-claude.ps1) means the refactor must not emit anything after the exit footer in the .ps1 generator.
- #112's follow-up: "claude rules dry run writes no `claude rules` row" -- the fan-out should close it (C3).

**#111 (feature/harness-mdm-followups, stacked on #100).**
- build-deploy.sh hunks: 397+ (new `extract_markers`/`extract_marked`), 1680-2203 (deploy-harness generator: payload file, markers, bootstrap check), 2294+ (size checks). **No hunk in the setup-user-claude generator (620-805) or the resolver embed (483-607).** No textual overlap with C8-C11 except comment line 11-14? -- #111's first build-deploy hunk is `@@ -397,6 +397,21 @@`, so 11-14 are untouched; 1689-1690 (C11) is inside #111's `@@ -1680,14 +1695,22 @@` hunk: rebase conflict likely on that comment.
- It fixes the trap override (`trap 'rm -rf "$MDM_TMP"' EXIT` at 1706 replacing the BUILD_TMP trap at 320) (INCIDENT 3).
- After #111, the MDM deploy-harness needs `deploy/deploy-harness.payload` beside it, and a fresh endpoint with no bootstrap keys reports `OK|config.json|n/a (no bootstrap)` and exits 0, so deploy-harness-then-setup-user-claude works on a fresh endpoint.
- #111 also includes #100's deploy-harness section 5b (manifest + retire), which is the contract C4 reads.

**#100 (manifest; not in my slice, read for "retired").** Manifest `~/.aitools/rules/.aitools-rules-manifest`: UTF-8, LF, first line `# aitools rules manifest v1`, then `<file name><TAB><source>`, source in `shared | aitools | dotprofile | retired`, sorted by name; only `*.md` names, never `*.bak.*`. deploy-harness itself backs up and removes `~/.aitools/rules/<retired>`. So for setup-user-claude, a retired rule is already absent from the copy loop; "minus retired" matters only for **removing the stale copy from `~/.claude/rules`**. Since the manifest has no `.md` extension and starts with a dot, a `*.md` filter never copies it.

**#110 (Cursor fan-out; not my slice).** Adds `read_rules_manifest` / `Read-RulesManifest` inside setup-user-cursor.sh/.ps1, a fan-out marker comment to recognise its own `.mdc` files, per-file backup + removal with `DETAIL|cursor rules|removed: <file>`, no-manifest = WARN `no rules manifest` + ACTION "Run aitools to rebuild ~/.aitools/rules and its manifest", and notes "No `removed` outcome in the deploy tracker". A Claude fan-out needs the same manifest reader: duplicating it in setup-user-claude makes two copies (Q5).

**#99 (protected drafts).** Rewrites deploy-paths.md/.mdc (pr99.diff 407-604): setup-user-claude moves to "pure extract ... adds only the profile/template source block ... and the rules fallback"; embed bullet "`<userRepoPath>/claude/rules/*.md` -> read at build time (the fallback rules)"; new "MDM run order" section already anticipates "`setup-user-claude` once it fans out". C14 drafts must be written on top of #99's text.

## 6. Error-handling / parity / script-standards issues in code the refactor touches

1. sh 299/305: `RULE_COUNT=$(find ... | wc -l | tr -d ' ')` under `set -euo pipefail`: a `find` failure aborts the script with no `claude rules` row (script-standards "Every code path must call write_summary"). The fan-out should list with a glob and check readability first (cursor 479-481).
2. sh 360-365 / ps1 392-395: the result `case`/`if` is a no-op with no `*)` branch; an unexpected `MANAGED_FILE_RESULT` is dropped by `deploy_tracker_record` (aitools-lib.sh 2283-2296, no default). interactive-menus.md "Return value contract" requires every value handled; cursor 577-579 shows the fix.
3. ps1 320/326/354/427: `Get-ChildItem -ErrorAction Stop` outside try: terminating error, no row.
4. ps1 uses `-Path` throughout (310-311, 320, 333-337, 356-357, 429-430, 441): wildcard interpretation of `[ ]` names. Use `-LiteralPath`.
5. Case-sensitivity: .sh `*.md` glob vs .ps1 `-Filter "*.md"` (3.2/3.3). Same defect in deploy-harness.sh 205-209 (`*.md)`) and setup-user-cursor.sh 493-495 (#100 follow-up notes it).
6. Dry-run parity: .ps1 343 `-eq` vs .sh `diff -q` (3.3).
7. Dry run writes no `claude rules` row (sh 302-333, ps1 323-361).
8. sh 336-339 / ps1 364-371: `exit 1` on mkdir failure skips the exit footer (the CLAUDE.md row is already written; acceptable but the fan-out could `log_error` + ERROR row and continue to the footer instead).
9. sh 335 / ps1 363: `backup_dir` of the whole `~/.claude/rules` on every non-dry run (max 5 kept, config-file-safety.md). With 28 files that is fine; note that `deploy_managed_file` also backs up each changed file.
10. build-deploy.sh 518/566: `for i in $(seq 0 $((USER_RULE_COUNT - 1)))` with a count of 0 prints `0` and `-1` on BSD seq; the `|| break` guard saves it. Goes away with C8.
11. CRLF: setup-user-claude.ps1 is "ASCII text, with CRLF line terminators" (`file` output). Old/new strings for it must match CRLF lines (the Edit tool handles it; perl/sed scripts must not).

## 7. Risks, unknowns, open questions (with suggested answers)

Risks:
- R1. **Ordering gap on main.** After this refactor alone, `aitools` and `aitools install` never fill `~/.aitools/rules` (3.6), so setup-user-claude reports `n/a (no harness rules)` and `~/.claude/rules` keeps whatever is there (preserved, not deleted). New dotprofile rules would stop reaching Claude Code until #106/#116 wire deploy-harness before setup-user-claude. Suggest: land after #106/#116, or make the plan state the dependency in the PR.
- R2. **Project rules in user scope.** Fanning out `.claude/rules` (26 files; the ones I read are titled "(this repo)", and deploy-paths.md 1-15 has `paths:` frontmatter; I did not check all 26) loads aitools-specific rules in every repo. That is the commander's decision ("Put aitools rules in the user space of claude code", brief). Unknown: how Claude Code resolves a user-level rule's `paths:` (relative to which root), and whether it de-duplicates a user rule identical to a project rule (inside the aitools repo every rule would be loaded twice). Suggest: say so in the PR as a known effect; do not change scope.
- R3. **Adopt regression** if the adopt target becomes `""` (C5): accept & adopt / merge & adopt disappear for dotprofile rules, and the N-Q2 auto-push path from #103 is never reached for rules.
- R4. **First run after the refactor on this Mac**: 28 adds to `~/.claude/rules` (3.4). In an interactive run that is no prompt (new files are created without review), but a later edit in `~/.aitools/rules` vs `~/.claude/rules` gives two review menus (deploy-harness, then setup-user-claude) for one source change. Acceptable; mention.
- R5. **#112 test break** (C13) and **marker/span constraint** (3.5) can fail CI/build if missed.
- R6. MDM `setup-user-claude.ps1` size: #111 reports it at 450,142 B, over the Intune 200 KB limit; removing the rules embed shrinks it only by the size of the two rules (~7 KB). Not solved by this refactor.

Open questions:
- Q1. Adopt target for fanned-out rules? Suggested: map from the manifest source on the dev path (`dotprofile` -> `<dotprofile>/claude/rules/<name>`, `aitools` -> `<aitools>/.claude/rules/<name>`, `shared` -> `<aitools>/shared/rules/<name>`), `""` when the manifest is missing or on MDM. It keeps today's dotprofile adopt + N-Q2 push, and the lib already WARNs on protected targets. Ask the commander if `""` (cursor parity) is preferred instead.
- Q2. How does setup-user-claude recognise its own copy of a retired rule before removing it? Suggested: remove `~/.claude/rules/<name>` only when its content equals the last harness copy (`~/.aitools/rules/<name>.bak.*`, newest first), else keep it with a WARN (a user-edited or user-owned file is never deleted). Alternative: a marker comment like #110's; rejected here because it changes every deployed rule's bytes and the first run would prompt for all 28.
- Q3. No manifest, or a bad header? Suggested: fan out everything anyway (Claude takes all sources, so the manifest is not needed to choose), remove nothing, `log` only for "no manifest" (deploy-harness before #100 writes none) and WARN for a bad header. Differs from #110 (Cursor WARN + ACTION), because Cursor needs the source to filter and Claude does not.
- Q4. Should a dotprofile resolver error (`URP_RC -eq 3`) still skip the rules? Suggested: yes, keep one exit (minimal change; the rules fan-out does not need the dotprofile, but Q1's adopt mapping does, and a broken dotprofile config is worth stopping on).
- Q5. Where does the manifest reader live? Suggested: in aitools-lib (`read_rules_manifest` / `Read-RulesManifest`), shared by setup-user-claude and setup-user-cursor; coordinate with the Lib explorer and #110's owner. If the lib is out of scope, copy #110's function and file an incident for the duplication.
- Q6. Tool name for the summary: keep `claude rules` (today's) -- suggested yes, the summary consumers and #112 tests use it.
- Q7. Does the MDM still need `_DP_RC` rules logic? No: after C9 the generated script uses `~/.aitools/rules` on every machine, with or without a dotprofile.
- Unknown: PowerShell `-Filter "*.md"` case behaviour on pwsh for macOS/Linux; Claude Code `paths:` semantics for user-level rules; #106/#116 run order.

## 8. INCIDENT markers (not filed)

1. `INCIDENT:` `.claude/rules/deploy-paths.md` lines 49-69 (and `.cursor/rules/deploy-paths.mdc` 32-41) still list `setup-user-claude.sh/.ps1` as having duplicated "Template interpolation, footer generation" in build-deploy, and list `<userRepoPath>/claude/rules/*.md -> read via cat at build time`. build-deploy.sh 625-628 says it is a pure extract (I6), and the code (648-707) confirms it. The .mdc also lists setup-user-mcp as duplicated (38) while the .md says it is pure extract (60-63): the two copies disagree. Also raised by the #112 reviewer (pr112.diff 393, 484). #99 fixes the text but is unmerged; the fan-out makes the "rules fallback" wording stale again. Spec drift, medium.
2. `INCIDENT:` `reference/user-repo.md` 195: "build-deploy.sh reads user rules at build time and embeds them in deploy scripts via heredocs" describes the pre-M3 generator (heredocs); main embeds them through `embed_file_bash` into the resolver block (build-deploy.sh 518-521). Becomes wholly wrong after the fan-out. Medium.
3. `INCIDENT:` build-deploy.sh 1706 `trap 'rm -rf "$MDM_TMP"' EXIT` replaces the trap set at 320 (`trap _cleanup_build_tmp EXIT`), so `$BUILD_TMP` (the staging dir and resolver blocks) leaks on every build and on every failure after 1706. Fixed in open PR #111 ("BUILD_TMP leaked on every build"). Low (already in flight).
4. `INCIDENT:` setup-user-claude.sh 360-365 / .ps1 392-395 and `deploy_tracker_record` (aitools-lib.sh 2283-2296): no handling of an unexpected deploy result (no `*)` branch); the tracker silently ignores unknown outcomes. interactive-menus.md "Return value contract". Medium (spec deviation).
5. `INCIDENT:` setup-user-claude.ps1 320/326/354/427: `Get-ChildItem -ErrorAction Stop` with no try: a listing error ends the script with no `claude rules` summary row (script-standards "Every code path ... must call write_summary"). Low.
6. `INCIDENT:` the dotprofile `deploy/` (aitools-nobul-jose, last regenerated 825aed4, 2026-10-22) is the pre-M3 generator output and lacks `deploy-harness.*` and its config writer; an endpoint using it has no `~/.aitools` and gets the old embedded-rules behaviour. Known as pre-push step 7; listed because it means no MDM endpoint can test the fan-out until the commander rebuilds deploy/ (#111 follow-up ACTION).
7. `INCIDENT:` plans/tool-support-and-machine-profile.md:83 R20 (".claude/rules/deploy-paths.md (setup-user-claude row ...)", "approve the text") has no commander answer recorded; the row has stayed stale since. Ambiguity, low.

## Scratch and outputs

- Scratch: `/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/.scratch/session-claude/` (pr99.diff, pr103.diff, pr111.diff, pr112.diff from `gh pr diff`).
- No repo file edited, no script run, no branch switched. No WRITE_BLOCKED.
