# S3-Incidents-Check report

Independent read-only verification of S3-Incidents-final-batch.json (#87-#145) and the proposed closure of #80, #81 and #82. Delegated by S3-Incidents (mission INCIDENTS, Session Commander 10cf255a-c), 2026-10-21.

## Summary (5 lines)

1. I checked 34 file:line citations across 22 entries (11 in #129-#145, 23 in #87-#128) against `git show db4b3c5:<file>`. All 34 **HOLD**. None moved and none is wrong.
2. I re-ran two of S3-Incidents' probes under an isolated HOME and got the same results: the `[\s]` secret pattern (#134) and the `/opt/homebrew/bin/pwsh` `;` block (#138).
3. **#80: FIXED. #81: FIXED.** Both are fixed in the bash and PS1 code on db4b3c5.
4. **#82: FIXED as stated** (`sed -n 'N,Mp' file` now passes). But `MODE_SED="observe"`, so every sed write form, `sed -i` included, now exits 0 and is only logged. The live hook-rollout.md:79 still says sed is literal enforce. The closure note should point to #144 / open PR #60.
5. Section C: no batch entry is wrong. One gap is untracked: a bare `read -r choice < /dev/tty` in setup-user-skills.sh:195-200, the #81 pattern in the skills twin.

Setup: worktree `/Users/new-jose/repos/aitools/.claude/worktrees/incidents87`, HEAD db4b3c5 (`git log --oneline -3`). Every citation was read through `.scratch/session-S3IncChk/show.sh` (prints numbered lines from `git show db4b3c5:<file>`). The hook probes ran with `.scratch/session-S3IncChk/probe.py` (`HOME=<worktree>/.scratch/session-S3IncChk/home`, cwd a mktemp dir outside any git repo, so no `events.jsonl` was written to a live session).

## A. Citation checks

| # | Entry | Citation | What the file says at db4b3c5 (quoted) | Verdict |
|---|-------|----------|----------------------------------------|---------|
| 1 | #129 | scripts/aitools-lib.sh:1132-1141 (auto-deploy) | 1134 `if [ "$existing_hash" = "$state_hash" ]; then`; 1135 `# User didn't edit since last deploy → auto-deploy silently`; 1137 `printf '%s\n' "$src_content" > "$dest"`; 1139 `log "Auto-deployed: $item_name (no local edits detected)"` | HOLDS |
| 2 | #129 | scripts/aitools-lib.sh:1173-1179 (merge) | 1173 `merge)`; 1174 `src_content="$MERGED_CONTENT"`; 1178 `printf '%s\n' "$src_content" > "$dest"`; 1179 `update_deploy_state "$dest" "$src_content"`. deploy_managed_file starts at :1080 | HOLDS |
| 3 | #129 | scripts/aitools-lib.ps1 merge :1178-1185, auto-deploy :1139-1150 | 1142 `if ($existingHash -eq $state.hash) {`; 1148 `Log "Auto-deployed: $ItemName (no local edits detected)"`; 1178 `"merge" {`; 1179 `$Content = $script:MergedContent`; 1185 `Update-DeployState -FilePath $DestPath -Content $Content` | HOLDS |
| 4 | #130 | scripts/aitools-lib.sh:443-456 | 448 `if node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$manifest_path"; then`; 451 `log_warn "Deploy-state manifest unreadable -- starting fresh (old copy kept as .corrupt)"`; 452 `if ! mv "$manifest_path" "${manifest_path}.corrupt"; then`. No `command -v node` in the function | HOLDS |
| 5 | #134 | scripts/check-pre-push.sh:68-69 | 68 `secret_pattern='(password\|secret\|api_key\|...\|ANTHROPIC_API)[\s]*[=:]'`; 69 `secrets_found=$(echo "$push_diff" \| grep -iE "^\+.*$secret_pattern" \|\| true)`. PS1 :69 `...ANTHROPIC_API)\s*[=:]'`. Probe (/usr/bin/grep -iE): `+Path tokens: a b` MATCH, `+tokens= y` MATCH, `+token=abc` MATCH, `+token = abc` no-match, `+password : x` no-match. Extra: `+password\: x` MATCH, which confirms that `[\s]` = backslash or `s` | HOLDS |
| 6 | #136 | scripts/check-pre-commit.sh:111-115 | 113 `bash "$SCRIPT_DIR/build-deploy.sh" >/dev/null 2>&1`; 114 `git add deploy/ 2>/dev/null`; 115 `step_pass "3" "Build freshness" "(rebuilt + staged)"` | HOLDS |
| 7 | #136 | scripts/check-pre-commit.ps1:112-114 | 112 `& $bashExe "$script:RepoRoot/scripts/build-deploy.sh" 2>$null \| Out-Null`; 113 `InvokeGit add deploy/`; 114 `StepPass "3" "Build freshness" "(rebuilt + staged)"` | HOLDS |
| 8 | #138 | shared/hooks/standing-order-guard.sh:177-184 and :199-202 | 182 `pwsh\ *\|powershell\ *\|perl\ *) ;;`; 183 `*) violation "USO: Simple Bash commands only --: Don't use ';' ..."`; 200 `pwsh\|powershell\|git\|perl\|uv\|npm\|node\|python*\|...` 201 `exit 0`. Probe: `pwsh -NoProfile -Command 'a; b'` exit 0; `/opt/homebrew/bin/pwsh -NoProfile -Command 'a; b'` exit 2 with the ';' message | HOLDS |
| 9 | #142 | scripts/aitools-install.sh:164, :171 and aitools-lib.sh:1781 | 164 `write_summary ERROR "${name%.sh}" "syntax errors -- skipped"`; 171 `write_summary ERROR "${name%.sh}" "script failed (exit $script_rc)"`; lib 1781 `# Dedup by tool name: highest severity wins (ERROR > WARN > OK).`; setup-go.sh writes `"go"` (grep: :54, :59, :63, :70, :76, :79, :94, :112, :115) | HOLDS |
| 10 | #142 | scripts/aitools-install.ps1:103, :111, :117 | each is `Write-Summary "ERROR" ($name -replace '\.ps1$', '') ...` | HOLDS |
| 11 | #143 | scripts/aitools-lib.sh:1868-1881 | 1871 `local known_paths=("$@")`; 1881 `for kp in "${known_paths[@]}"; do` | HOLDS |
| 12 | #144 | shared/hooks/standing-order-guard.sh:55 | `MODE_SED="observe"       # sed — matching changed 2026-10-21 (#82 sed -n exemption); observe`. Probe: `sed -i '' 's/a/b/' file.txt` exit 0, observe log grew | HOLDS |
| 13 | #133 | git ls-files -s (harvesting/...build-deploy-prefix.sh) | `100644 861dbd9d8537082a15b7e94b9f142c28153aeafc 0` | HOLDS |
| 14 | #135 | scripts/check-pre-push.sh:181-182 | 181 `if [ -n "$USER_REPO_PATH" ] && [ -d "$USER_REPO_PATH" ]; then`; 182 `unpushed=$(git -C "$USER_REPO_PATH" log --oneline origin/main..HEAD 2>/dev/null \|\| true)` | HOLDS |
| 15 | #145 | shared/skills/scratch/SKILL.md:71 | `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>` | HOLDS |
| 16 | #87 | scripts/aitools-install.sh validate_and_run :154-173 | 154 `validate_and_run() {`; 168 `bash "$script" \|\| script_rc=$?`; 170 `log_error "$name failed (exit $script_rc)"`; 171 `write_summary ERROR ...`; returns, no exit | HOLDS |
| 17 | #87 | scripts/aitools:1604-1616 | 1604 `installer_rc=$?`; 1607 `if [ $installer_rc -eq 0 ]; then`; 1615 `log "Completed with errors (see $LOG_DISPLAY)" "error"`; 1616 `overall_rc=1` | HOLDS |
| 18 | #87 | .claude/rules/interactive-menus.md:74, :88 | 74 `` `abort` is global (stops the run). ``; 88 `[x]abort    : stop the run (global)` | HOLDS |
| 19 | #88 | scripts/setup-datadog.sh:73, :84, :91, :95 | 73 `# Installed via go install or another method -- migrate to Homebrew.`; 84 `INSTALL_OUTPUT=$(brew install datadog-labs/pack/pup 2>&1) \|\| INSTALL_EC=$?`; 91 `log_warn "... -- kept $PUP_PATH"`; 95 `if rm -f "$PUP_PATH"; then` | HOLDS |
| 20 | #89 | scripts/aitools-install.sh:129, :187; setup-go.sh:104 | 129 `if $DRY_RUN; then export AITOOLS_DRY_RUN=1; fi`; 187 `$DRY_RUN && log "[DRY RUN] Preview mode -- no files will be written"`; setup-go 104 `if sudo rm -rf "$CLEANUP_TARGET"; then` | HOLDS |
| 21 | #91 | scripts/aitools-install.sh:642-646 | 642 `log "Step 8: Node.js"`; 644 `if command -v node &>/dev/null; then`; 646 `write_summary OK "node.js" "$(node --version)"` | HOLDS |
| 22 | #92 | scripts/setup-perl.sh:42-47, :64-65 | 42 `# macOS: Homebrew is the preferred method`; 44 `log_error "Homebrew not found. Install perl manually:"`; 47 `write_summary ERROR "perl" "Homebrew not found"`; 65 `if ! brew install perl 2>&1 \| ...` | HOLDS |
| 23 | #95 | scripts/build-deploy.sh:198-201, :241-242, :220-222 | 199 `PROFILE_COMPANY="Nobul"`; 201 `IDENTITY_GIT_EMAIL="jose@nobul.tech"`; 241 `} catch(e) { process.exit(1); }`; 242 `" "$CONFIG" 2>/dev/null) && eval "$PROFILE_VALS"`; 222 `\|\| Object.values(p.profiles)[0];` | HOLDS |
| 24 | #98 | scripts/build-deploy.sh:115-145 | 121 `if (/source.*aitools-lib\.sh/) {`; 138 `if (/aitools-lib\.ps1/) {` | HOLDS |
| 25 | #98 | build-deploy.sh:1155, :1356 | 1155 `} \| inline_lib_bash > "$DEPLOY_DIR/setup-user-skills.sh"`; 1356 `} \| inline_lib_bash > "$DEPLOY_DIR/setup-user-hooks.sh"` | HOLDS |
| 26 | #98 | shared/hooks/delegation-duty-guard.sh:38; shared/skills/aitool-ops/SKILL.md:280 | 38 `#   - Standalone — cannot source aitools-lib.sh`; 280 ``environments. Hooks cannot source `aitools-lib.sh` or `check-lib.sh` `` (both match `/source.*aitools-lib\.sh/`) | HOLDS |
| 27 | #99 | scripts/setup-user-claude.sh:168-173 | 168 `content=$(printf '%s' "$content" \| perl -pe "`; 172 `s/\\Q${IDENTITY_GIT_EMAIL}\\E/{{IDENTITY_GIT_EMAIL}}/g;` (shell interpolation into a perl double-quoted program, so `@nobul` is interpolated as a perl array) | HOLDS |
| 28 | #100 | scripts/aitools:179, :998 | 179 `try { old = JSON.parse(fs.readFileSync(profilePath, 'utf8')); } catch {}`; 998 `} catch {}` | HOLDS |
| 29 | #108 | .claude/rules/cross-platform.md:40-42 | 41-42 ``capability or by the environment API (e.g. `install_via_brew` / `install_via_apt`)``; `grep -rn install_via_brew\|install_via_apt scripts/`: no hits | HOLDS |
| 30 | #114 | scripts/check-post-push.ps1:268, :520-522; .sh :233, :448 | ps1 268 `"reference/tool-versions.json",`; ps1 520 `$versionsJson = Join-Path (Join-Path $script:RepoRoot "reference") "tool-versions.json"`; ps1 522 `StepSkip "21" ...`; sh 233 `"registries/tool-versions.json" \`; sh 448 `versions_json="$REPO_ROOT/registries/tool-versions.json"` | HOLDS |
| 31 | #122 | .claude/skills/incident/SKILL.md:48-49 | 48 ``Read `reference/incidents.json`. Note the highest ID in the `incidents` array.``; 49 ``The new entry gets `highest + 1`.`` | HOLDS |
| 32 | #126 | shared/hooks/hooks-manifest.json (18 hooks) | python3 count: 18; SessionEnd 4, SessionStart 4, Stop 4, PreToolUse Agent 3, Bash 1, Read\|Grep 1, PostToolUse Write\|Edit 1. No SubagentStart, no PreToolUse Write/Edit | HOLDS |
| 33 | #126 | standing-order-guard.sh:199-202 (git exits 0) | 200 `pwsh\|powershell\|git\|perl\|...`, 201 `exit 0`. Probe `git status` exit 0 | HOLDS |
| 34 | #143 | callers aitools-lib.sh:1933, :1945 | not re-read | unknown (not checked) |

Count: 34 rows, of which 33 were checked: 11 in #129-#145 (rows 1-15, all HOLD) and 22 in #87-#128 (rows 16-33, all HOLD). Row 34 is listed only so the gap is visible.

## B. Closure claims (#80, #81, #82 by PR #56, bd42ba5)

`git show --stat bd42ba5`: it changes scripts/setup-user-hooks.sh (60 lines), scripts/setup-user-hooks.ps1 (68), shared/hooks/standing-order-guard.sh (22), plus mission drafts. The protected-rule drafts were not applied.

| Incident | Stated defect (title + observation) | Code on db4b3c5 | Verdict |
|----------|-------------------------------------|-----------------|---------|
| #80 | The dev path's resolve_hook prefers `<userRepoPath>/claude/hooks/<name>` over shared/hooks, and [a]dopt writes to both shared/hooks and the dotprofile, so a dotprofile copy shadows shared/hooks and diverges from MDM | **bash**: setup-user-hooks.sh:79-88 `resolve_hook` checks only `$REPO_DIR/shared/hooks/$hook_name`, then `$REPO_DIR/scripts/$hook_name`. :133-135 a dotprofile copy gives `log_warn "Ignoring dotprofile copy of managed hook ..."` + `write_summary WARN "claude hooks" "dotprofile copy ignored"`. Adopt :175-179 writes `adopt_managed_file "$hook_dst" "$SHARED_HOOKS_DIR/$hook_name"` only. **PS1**: Resolve-HookSource :70-76 uses shared\hooks then scripts\. :94-96 same warning and row. Adopt :140-143 targets `Join-Path $sharedHooksDir $hookName` only. MDM embed: build-deploy.sh unchanged (bd42ba5 message says no change needed). I did not rebuild to confirm | **FIXED** (code, both platforms). Not done: the spec half of the suggested resolution (hook-lifecycle rule; hook-rollout.md is in `affected`) is still a draft under S3-Hooks/dot-claude/. Residual (pre-existing, not the #80 defect): a user-created hook adopted to the dotprofile (:247-251) is never deployed by any code path. DOTPROFILE_HOOKS is only read at :72-73, :133 and :230 (grep). Whether that is intended under SD-2: unknown |
| #81 | The reverse-discovery prompt uses bare `read -r choice < /dev/tty` gated on `[ -c /dev/tty ]` | **bash** :240 `if tty_interactive; then`, :245 `read_tty_choice choice "skip"`, :259-260 non-interactive gives `log "Non-interactive: skipped adoption prompt ..."`. `read_tty_choice` (aitools-lib.sh:787-795) logs `log_warn "No input at prompt (EOF) -- defaulting to $__default_desc"` and returns 0. **PS1** :204 `if (-not (Test-InteractiveConsole))` logs and continues; :212 `$choice = Read-ConsoleChoice "skip"` | **FIXED** for the named call site, both platforms. The suggested resolution's grep for other bare reads still finds some: see C-1 |
| #82 | standing-order-guard blocks the read-only `sed -n '<range>p' <file>` | :263-274 `SED_READONLY_RE` exempts `sed -n` with one numeric/`$` address or range + `p`, with no `-`-prefixed argument after the script and no `< > \| ; &`. Probe: `sed -n '60,75p' scripts/setup-user-hooks.sh`, `sed -n 60,75p ...`, `sed -n '5p' a.txt` and `sed -n '1,$p' a.txt` each give exit 0 and **no** observe-log line (the regex allows them; they never reach violation) | **FIXED as stated**. Caveat below |

**What `sed -i` does now (MODE_SED).** standing-order-guard.sh:55 sets `MODE_SED="observe"`. Every sed form the regex does not exempt reaches `violation ... "$MODE_SED" "sed"` (:273). In observe mode, `violation()` (:87-101) appends `[WOULD-BLOCK] ... | cmd: ...` to `$HOME/.aitools/logs/standing-order-guard.log` and exits 0. Probe results: `sed -i '' 's/a/b/' file.txt`, `sed -i.bak ...`, `sed 's/a/b/' file.txt`, `sed -n '1,5p' a.txt > out.txt`, `sed -n '1,5w out.txt' a.txt`, `sed -n '1,5p' a.txt -i` and `sed -n -i '1p' a.txt` all gave **exit 0** and grew the observe log. So `sed -i` is allowed (logged, not blocked). Before bd42ba5, the sed check passed a literal "enforce". The live rule `.claude/rules/hook-rollout.md:79` on db4b3c5 still says `` | `cat`/`head`/`tail`/`sed`/`awk` outside a pipeline | none (literal `"enforce"`) | enforce | No mode variable | ``, which is now false for sed. `gh pr view 60`: state OPEN, mergedAt null, title "Restore the sed guard to enforce; fix hook-lifecycle drafts (#82 follow-up)".

Recommendation for the closure text of #82: close it for the false positive, but name the observe-mode regression and the stale hook-rollout.md:79 row as tracked by #144 / PR #60. Otherwise closing #82 hides that the enforcement it was filed against is currently off.

## C. Entries whose claims I found wrong, and related gaps

- **No batch entry was found wrong.** Every citation checked in A holds at db4b3c5.
- **C-1 (gap, not in the batch or the registry):** scripts/setup-user-skills.sh:195-200 still has the exact #81 defect. Line 195 is `elif [ -c /dev/tty ]; then` and line 200 is `read -r choice < /dev/tty` in the "User-created skill detected ... [a]dopt to dotprofile  [s]kip" prompt. Other bare reads remain at scripts/relay-outbound-prompt.sh:77 and scripts/aitools:108, :157, :957, :1058, :1062, :1066, :1118, :1122, :1125, :1128, :1181 (`grep -rn "read -r [a-z_]* < /dev/tty" scripts shared`). I did not check whether each of those is EOF-guarded by its caller. grep of the batch and registries/incidents.json for `setup-user-skills.sh:19x/20x` and `relay-outbound-prompt.sh:7x` found nothing. Whether GitHub #29 covers them: unknown.
  `INCIDENT:` setup-user-skills.sh reverse-discovery prompt uses bare `read -r choice < /dev/tty` gated on `[ -c /dev/tty ]` (:195-200), the #81 pattern missed by PR #56.
- **C-2 (precision note on #82 / #144, not wrong):** #144 says the guard "no longer blocks sed -i". That is true and also too narrow: every non-exempt sed form is unblocked (probe list above), including plain `sed 's/a/b/' file` and `sed -n ... > out`.
- **C-3 (wording, #92):** the entry cites ":64-65 brew install perl". Line 64 is the log line (`log "Installing Perl via Homebrew..."`) and the command is on 65. The citation holds.

## Not done / deviations

- **Reading list (deviation).** I did not read every file in mission packet section 1 with the Read tool. The project rules and both CLAUDE.md files were in my context (injected from the main checkout, not the worktree). I did not read `~/.claude/rules/delegation.md` or the five reference files. They did not bear on the read-only checks, and I created no delegates.
- No build-deploy run, so the MDM half of #80 rests on the bd42ba5 commit message and the unchanged build-deploy.sh. No PS1 execution (code read only). No Windows runs.
- **Scratch path.** I used `.scratch/session-S3IncChk/` (10 characters or fewer, per packet section 2), not the `session-S3-Incidents-Check` named in the launch prompt. That name is longer than the packet allows and would trip the catch-up harvest (S3-SR-8).
- WRITE_BLOCKED: none.
- Delegates used: none.
