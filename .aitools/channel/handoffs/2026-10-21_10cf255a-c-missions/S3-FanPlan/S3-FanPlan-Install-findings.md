# S3-FanPlan-Install findings (2026-10-26)

Explorer S3-FanPlan-Install (level 2, under S3-FanPlan). Slice: installers,
`aitools` entry points, bootstrap, hh, relay prompt, the other setup-user-*
scripts; PRs #106, #116, #98, #114. Read only. Reading copy:
`/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/` (origin/main 480b901).
All `file:line` refer to that copy unless a PR is named. Rules: I used the main
checkout copies in my context; the worktree copies of `interactive-menus.md` and
`reference/managed-file-deployment.md` were grepped for "abort" and match.

## 1. Summary

1. **On main, no entry point runs deploy-harness.** Neither installer nor the
   `aitools` sync loop calls it (`grep -rln deploy-harness scripts/` hits only
   build-deploy.sh, deploy-harness.*, setup-user-cursor.*, aitools-lib.*, an allow
   list). So on main a rules fan-out in setup-user-claude would find no
   `~/.aitools/rules` on every run. That matches the live state (no
   `~/.aitools/rules`). **The fan-out depends on PR #106 landing first.**
2. **With #106, deploy-harness runs BEFORE setup-user-claude everywhere:**
   installer Step 8b (after Node, before Step 21's setup-user-claude), and first
   in `deploy_configs` / `Deploy-Configs` (setup-user-config leaves the list,
   because deploy-harness runs it).
3. **Exit 2 today:** on main, every loop or installer child's exit 2 is logged as
   `ERROR|<script>|script failed (exit 2)` and the run continues. The lib's
   `_managed_abort` / `Invoke-ManagedAbort` does `exit 2`. #106 adds a special case
   for deploy-harness only: its exit 2 ends the whole run (installer `exit 2`; loop
   `break`, then `return 2` / `exit 2`). **That conflicts with the commander's
   2026-10-26 decision** (abort ends only that script; the installer continues),
   and #106 must change.
4. **No other setup-user-* script in my slice writes `~/.claude/rules` or reads
   dotprofile `claude/rules`.** skills reads `shared/skills` + dotprofile
   `claude/skills`. hooks reads `shared/hooks` + dotprofile `claude/hooks`.
   settings / mcp / shell / config touch no rules (grep, section 3.6).
5. **No single-script command exists** (`aitools claude` and the like). But
   setup-user-claude can run without deploy-harness first: run directly (the
   documented step in tool-lifecycle.md:103 and tool-adopt SKILL.md:168), on main
   before #106, from the MDM `deploy/` path, or after deploy-harness fails or
   aborts. Suggested behaviour: copy setup-user-cursor's existing precedent
   (`setup-user-cursor.sh:476-478`): log, OK row `n/a (no harness rules)`, leave
   `~/.claude/rules` untouched.

## 2. Files read

Read in full:
- scripts/aitools-install.sh (884)
- scripts/aitools (2298; lines 1-2298 in three Reads)
- scripts/bootstrap.sh (104), bootstrap.ps1 (72)
- scripts/hh.sh (123), hh.ps1 (97)
- scripts/init-hh-hooks.sh (10)
- scripts/relay-outbound-prompt.sh (96), relay-outbound-prompt.ps1 (73)
- scripts/setup-user-skills.sh (250)
- PR #106 diff in full (scripts + tests + hand-back)
- PR #116 diff: the hunks for scripts/aitools, aitools.ps1, aitools-install.sh/.ps1 and setup-user-claude.sh/.ps1
- PR #98, #114: metadata, file lists and #114's body

Read in full in the follow-up pass (2026-10-26, see section 9; the first pass
read these in part or grep only):
- scripts/aitools.ps1 (2224): 1-520 and 1640-2224 in the first pass, 520-1640 in
  the second.
- scripts/aitools-install.ps1 (829): 140-185 and 755-829 first, 1-140 and 185-754
  second.
- scripts/setup-user-hooks.sh (481): 1-130 first, 131-481 second.
- setup-user-hooks.ps1 (444), setup-user-skills.ps1 (234),
  setup-user-settings.sh/.ps1 (160/148), setup-user-mcp.sh/.ps1 (263/237),
  setup-user-shell.sh/.ps1 (145/111), setup-user-config.sh/.ps1 (393/390): read
  in full in the second pass.

Every file in the slice is now read in full.

Context reads outside the slice, for cross-checks: aitools-lib.sh:948-961,
aitools-lib.ps1:845-856 (abort helpers), build-deploy.sh:835-910,
setup-user-cursor.sh:455-494, and greps of setup-user-claude.sh / setup-user-cursor.ps1.

## 3. Current behaviour (main 480b901)

### 3.1 Installer order, bash (aitools-install.sh)

Steps: 1 gh (357) -> 2 gh auth (369) -> 3 repos dir (396) -> 4 Drive (438) ->
5 config writer (487-508) -> 6 aitools/hh + `~/.aitools/bin` copy (514-565) ->
7 shell (570) -> 8 Node (609) -> 9 Claude Code (646) -> 10-20b tools (684-826) ->
21 deploy configs (831-842) -> 22 relay->AGENTS (847-870) -> footer (875-884).

Step 21 verbatim (aitools-install.sh:828-842):
```bash
# ============================================================
# 21. Deploy configurations
# ============================================================
log "Step 21: Deploy configurations"

DEPLOY_SCRIPTS="setup-user-claude.sh setup-user-cursor.sh setup-user-mcp.sh setup-user-skills.sh setup-cursor-ide-mcp.sh setup-user-settings.sh setup-user-hooks.sh"

for script in $DEPLOY_SCRIPTS; do
    script_path="$SCRIPT_DIR/$script"
    if [ -f "$script_path" ]; then
        validate_and_run "$script_path"
    else
        log_warn "$script not found — skipping"
    fi
done
```
`validate_and_run` (aitools-install.sh:221-240) treats any non-zero exit,
including 2, the same way:
```bash
    local script_rc=0
    bash "$script" || script_rc=$?
    if [ "$script_rc" -ne 0 ]; then
        log_error "$name failed (exit $script_rc)"
        write_summary ERROR "${name%.sh}" "script failed (exit $script_rc)"
    fi
}
```
No deploy-harness step anywhere in this file.

### 3.2 Installer order, PowerShell (aitools-install.ps1)

The same step numbering (grep: Step 1 at 262 ... Step 20b at 746, Step 21 at 758,
Step 22 at 782). Step 21 list (aitools-install.ps1:760-768):
```powershell
$deployScripts = @(
    "setup-user-claude.ps1",
    "setup-user-cursor.ps1",
    "setup-user-mcp.ps1",
    "setup-user-skills.ps1",
    "setup-cursor-ide-mcp.ps1",
    "setup-user-settings.ps1",
    "setup-user-hooks.ps1"
)
```
`Invoke-ValidatedScript` (aitools-install.ps1:150-177) runs `& $ScriptPath`
in-process. On `$LASTEXITCODE -ne 0` (2 included) it writes LogError + an
`ERROR ... script failed (exit N)` row and returns, so the install continues.

### 3.3 `aitools` sync loop (scripts/aitools deploy_configs, aitools.ps1 Deploy-Configs)

The lists (scripts/aitools:1108 for pwsh under Git Bash, :1151 for bash; aitools.ps1:157):
```bash
            local deploy_scripts="setup-user-config.sh setup-user-claude.sh setup-user-mcp.sh setup-user-skills.sh setup-cursor-ide-mcp.sh setup-user-cursor.sh setup-user-settings.sh setup-user-hooks.sh"
```
```powershell
    $deployScripts = @("setup-user-config.ps1", "setup-user-claude.ps1", "setup-user-mcp.ps1", "setup-user-skills.ps1", "setup-cursor-ide-mcp.ps1", "setup-user-cursor.ps1", "setup-user-settings.ps1", "setup-user-hooks.ps1")
```
Exit handling, bash branch (scripts/aitools:1171-1177):
```bash
                    local script_rc=0
                    bash "$script_path" || script_rc=$?
                    if [ "$script_rc" -ne 0 ]; then
                        log_error "$script failed (exit $script_rc) -- see $LOG_DISPLAY"
                        write_summary ERROR "${script%.sh}" "script failed (exit $script_rc)"
                        errors=$((errors + 1))
                    fi
```
The PowerShell branch is the same (aitools.ps1:191-196). Exit 2 is a counted
error and the loop continues.

**Order parity drift:** in the installer setup-user-cursor runs 2nd, in the sync
loop 6th (after cursor-ide-mcp). The two lists already differ. Not a fan-out
blocker, because claude comes before cursor in both.

**Smart reload** (scripts/aitools:2062-2093, aitools.ps1:2017-2046) compares the
last `local deploy_scripts=` / `$deployScripts = @(` line of the repo copy with
the running copy. If the refactor edits either list line, the first run after
the pull re-execs the entry point. That is expected and harmless.

`export AITOOLS_DEPLOY=1` (scripts/aitools:1099, aitools.ps1:159) is read by no
script (`grep -rln AITOOLS_DEPLOY scripts/` hits only the two entry points). It
is dead, and the installer does not set it.

### 3.4 Exit-2 meanings in this slice

- Managed-file abort: `_managed_abort() { log_error "Aborted by user"; exit 2; }`
  (aitools-lib.sh:956-959). `Invoke-ManagedAbort` is the same
  (aitools-lib.ps1:852-855).
- user init: a hooks exit 2 returns 2 (scripts/aitools:1052-1055, aitools.ps1:1673-1676):
  ```bash
      if [ "$hook_rc" -eq 2 ]; then
          log "user init: aborted by user"
          return 2
      fi
  ```
- Relay prompt `[q]`: `return 2` (relay-outbound-prompt.sh:79-81), propagated by
  `relay_outbound_prompt "$repo_path" || return $?` (scripts/aitools:2288).
  aitools.ps1:2217 has `if ($relayRc -eq 2) { exit 2 }`, and hh.ps1:86 and
  hh.sh:113 have the same. This exit 2 means "user quit", not a review abort.
- Rule text (interactive-menus.md "Abort" and line 122): "Abort ends this setup
  script; the installer continues with the next script". The menu block in the
  same file (line 119) says `[x]abort    : stop the run` (see INCIDENT 2).

### 3.5 Single-script / pre-harness paths to setup-user-claude

- Commands parsed (scripts/aitools:1350-1410; aitools.ps1:507): `install`,
  `gitpull`, `mcp`, `user`, `sessions`, `dashboard`, and none. **No command runs
  one setup script.**
- `aitools user init` runs setup-user-config and setup-user-hooks only
  (scripts/aitools:1018-1063). It does not run setup-user-claude.
- bootstrap.sh:76 runs the installer, then (when interactive) `aitools user init`
  and `aitools` (bootstrap.sh:92-97). bootstrap.ps1:48 and :59-64 do the same. So
  a fresh machine runs setup-user-claude three times: in the install (no
  dotprofile yet), not in user init, then in the sync.
- hh.sh:123 and hh.ps1:93 only `exec aitools`. hh -n runs the relay prompt only.
- Direct runs are documented: `.claude/rules/tool-lifecycle.md:103`
  ("`bash scripts/setup-user-claude.sh` — propagate CLAUDE.md") and
  `shared/skills/tool-adopt/SKILL.md:168`.
- The MDM path: `deploy/setup-user-*.sh` runs standalone. build-deploy's header
  for the generated setup-user-cursor already says
  `# Run deploy-harness.sh first: step 4 fans out ~/.aitools/rules, which it fills.`
  (build-deploy.sh:855, .ps1 twin at :895).
- Precedent for a missing harness dir (setup-user-cursor.sh:476-478):
  ```bash
  if [ ! -d "$HARNESS_RULES_DIR" ]; then
      log "No harness rules at $(display_path "$HARNESS_RULES_DIR") (deploy-harness has not run) -- skipping"
      write_summary OK "cursor rules" "n/a (no harness rules)"
  ```
  The PowerShell twin is at setup-user-cursor.ps1:476-477, and an empty directory
  is handled at :512 (`Harness rules directory $harnessRulesDir is empty -- skipping`).

### 3.6 Other setup-user-* scripts and rules

grep output (the command is in section 2): no match for `claude/rules`,
`.aitools/rules` or `setup-user-claude` in setup-user-{hooks,skills,settings,mcp,shell,config}.{sh,ps1}.
The only "rules" hits are permission rules (setup-user-settings.sh:58-60,135;
setup-user-mcp.sh:6,202-204) and a `rules` loop variable over hook events
(setup-user-hooks.sh:399-400). Sources:
- skills: `SKILLS_SRC="$REPO_DIR/shared/skills"` + dotprofile `claude/skills`
  (setup-user-skills.sh:43, 62-65), found by `resolve_user_repo_path`
  (setup-user-skills.sh:52-61). It does not read `~/.aitools/skills`.
- hooks: `$REPO_DIR/shared/hooks` + dotprofile `claude/hooks`
  (setup-user-hooks.sh:57, 70-74, 79-88). It finds userRepoPath with
  `read_config_key ... || true` (line 70), not the resolver that skills uses. It
  does not read `~/.aitools/hooks`.
- None of them depends on setup-user-claude's output. setup-user-cursor's rules
  step depends on `~/.aitools/rules` (setup-user-cursor.sh:389), not on
  setup-user-claude.

## 4. What must change or be checked in this slice

1. **Nothing in this slice has to change for the fan-out itself, provided #106
   lands first.** #106 is what puts deploy-harness before setup-user-claude.
   Planner: make "#106 merged" a precondition, or the FAN-PLAN PR must carry the
   hook-in.
2. **#106's abort handling must be reworked to the 2026-10-26 decision.** Today
   #106 ends the run on deploy-harness exit 2 (diff: aitools-install.sh
   `run_harness_step` returns 2, then `exit 2`; scripts/aitools `deploy_abort` +
   `break` + `return 2` in three call sites; the PowerShell twins). Under the
   decision, deploy-harness exit 2 should write a row and continue, so
   setup-user-claude still runs. It then sees whatever `~/.aitools/rules` holds:
   the earlier run's content, or a partial set.
   - This is owned by #106's mission, not FAN-PLAN. Flag it to S3-FanPlan.
   - The fan-out must tolerate a partially populated `~/.aitools/rules`. It is
     additive (it never deletes), so a partial set means stale rules, not lost
     ones.
3. **The non-harness children's exit 2 is a row and continue on main already**
   (`ERROR ... script failed (exit 2)`). That meets "the installer continues". But
   the row says "failed", not "aborted by user". If the commander wants a
   WARN/aborted row for every child, `validate_and_run`, `Invoke-ValidatedScript`
   and both loop branches change (4 sites). Unknown whether that is in scope.
4. **The missing `~/.aitools/rules` case in setup-user-claude** (owned by the
   Claude slice). Every path in 3.5 can reach it. Decide the behaviour; my
   suggestion is in section 7, Q1.
5. **Check:** the installer's Step 21 runs setup-user-claude after Step 8b (with
   #106). The `aitools` loop runs it 2nd, right after deploy-harness. With #106
   applied, both orders put deploy-harness first. No reorder is needed in my files.
6. **Check:** `aitools install` on main also runs no deploy-harness, so after the
   refactor (without #106) the fan-out is a no-op on install too. Same dependency.

## 5. Interactions with open PRs

- **#106** (`feature/harness-hookin`; scripts/aitools, aitools.ps1,
  aitools-install.sh/.ps1, tests/hookin). Hunks:
  - aitools-install.sh: new `run_harness_step` after `validate_and_run`; Step 8b
    after Step 8; the bin block (main :538-565) removed; `export AITOOLS_RUN_ID`.
  - aitools-install.ps1: `Invoke-HarnessStep`, Step 8b, bin block removed,
    `$env:AITOOLS_RUN_ID`.
  - scripts/aitools: `deploy_abort` before `deploy_configs`, both list lines
    (deploy-harness first, setup-user-config removed), the harness branch in both
    loop branches, the abort early-return, and exit-2 handling at three call
    sites (install, gitpull, no-args).
  - aitools.ps1: `Invoke-DeployAbort`, the list, the in-process
    `Invoke-ChildRelayed` branch, and the same call sites.

  Overlap with FAN-PLAN: none in setup-user-claude. But tests/hookin uses a
  **stub** `setup-user-claude.sh` (test-hookin.sh `DEPLOY_STUBS`), and its counts
  `OK|harness files|7 added` depend on deploy-harness's file set. A
  setup-user-claude change does not break hookin.
- **#116** (`fix/mf-installer-relay`, stacked on #98 -> #103 -> #113 -> #115; commits
  b5292fd..0e0a3f7). Its diff **includes #103's setup-user-claude.sh/.ps1 change**:
  the private dotprofile commit+push after an adopt is removed (setup-user-claude.sh
  main :364-389 -> 3 comment lines; .ps1 main :394-422). The library's
  `dotprofile_commit_push` / `Invoke-DotprofileCommitPush` does it instead. **That
  hunk sits inside the rules loop the fan-out rewrites**: whichever merges second
  rebases. Its other hunks:
  - installers: the private relay helpers are removed; `jsonl_record`,
    `run_child_relayed --summary-tool "aitools config"`, `resolve_repos_dir`; Step 5
    skipped on a bad repos path.
  - user init: both children relayed; hooks still `return 2` on exit 2, now with
    an `ERROR|claude hooks|aborted (exit 2)` row.
  - #116 documents a merge-tree conflict with #106 in aitools-install.sh/.ps1
    (JSONL globals vs `AITOOLS_RUN_ID` export).
- **#98** (`feature/mf-config-no-machine`): setup-user-config.sh/.ps1 +
  tests/profile/test-config.sh only (`--no-machine` / `-NoMachine`). No overlap
  with rules or setup-user-claude.
- **#114** (`fix/mf-audit-config`, merges #98 and #108 into itself):
  setup-user-config.*, aitools-profile.*, aitools-json.*, tests. No overlap with
  rules or setup-user-claude.

## 6. Error-handling / parity / standards issues (code the refactor touches or depends on)

1. Exit 2 is overloaded: managed abort, relay `[q]`, bash syntax error (exit 2),
   and `set -e` deaths that carry a child's exit 2. #106's hand-back says this too
   (its INCIDENT 3). On main `validate_and_run` already runs `bash -n` first, so a
   syntax error is filtered. A runtime builtin misuse is not.
2. Order parity: the installer's Step 21 list and the loop list differ (3.3).
3. `AITOOLS_DEPLOY` is exported and never read (3.3).
4. setup-user-hooks.sh:70 finds userRepoPath with `read_config_key || true`.
   setup-user-skills.sh:52-61 and setup-user-settings use the resolver, which
   handles a resolver error (exit 3) by blocking. So hooks behaves differently on
   a broken dotprofile. Out of scope; noted.
5. aitools-install.sh:554-559 (main): the bin step's
   `diff -u ... 2>/dev/null || true` has no result check. #106 deletes the block,
   which removes the issue.

## 7. Risks, unknowns, open questions (with suggested answers)

- **Q1: what does setup-user-claude do when `~/.aitools/rules` is missing or
  empty?** Suggested: the setup-user-cursor precedent. Log
  `No harness rules at ~/.aitools/rules (deploy-harness has not run) -- skipping`,
  write `OK|claude rules|n/a (no harness rules)`, leave `~/.claude/rules`
  untouched, no fallback to dotprofile `claude/rules`. Why:
  - parity with Cursor;
  - the approved behaviour says "stops deploying dotprofile rules directly";
  - not touching the target is always safe.

  Alternative: WARN + ACTION "run aitools" because rules go stale. Rejected: on
  main before #106 that would be a WARN on every run.
- **Q2: does #106 get reworked to "continue after deploy-harness abort" before
  FAN-PLAN ships?** Suggested: yes, in #106's mission. FAN-PLAN's test should
  include "deploy-harness aborted, then setup-user-claude fans out the existing
  `~/.aitools/rules`".
- **Q3: merge order.** Suggested: #106 (reworked) -> #103/#116 stack -> FAN-PLAN,
  so FAN-PLAN rebases once onto the setup-user-claude without the private
  commit+push block.
- **Unknown:** whether deploy-harness, after exit 1 (e.g. a duplicate rule), has
  still written the non-conflicting rules. The Harness slice owns this. The #106
  test `install exit 1` shows the install continuing, not the directory's content.
- **Unknown:** whether the MDM `deploy/` path has an orchestrator that runs
  deploy-harness before setup-user-claude. The only evidence I found is the header
  comment at build-deploy.sh:855. The MDM slice owns this.
- **Risk:** on a fresh machine the installer runs before the dotprofile exists,
  so deploy-harness fills `~/.aitools/rules` from `shared/` + `.claude/` only.
  The dotprofile rules arrive at bootstrap's second `aitools`. That is fine if
  the fan-out is additive. If the fan-out ever removes rules that are absent from
  `~/.aitools/rules` (not approved), that first run would delete dotprofile-only
  rules.

## 8. INCIDENT markers (not filed)

- INCIDENT: **PR #106 implements "abort ends the whole run" for deploy-harness,
  contrary to the commander decision of 2026-10-26.** The decision is "abort ends
  only that setup script; the installer continues", as in interactive-menus.md
  "Abort". Affected: scripts/aitools-install.sh/.ps1 (Step 8b),
  scripts/aitools/aitools.ps1 (`deploy_abort`, `Invoke-DeployAbort`, three call
  sites each), tests/hookin.
- INCIDENT: interactive-menus.md has two descriptions of abort in one file. The
  profile-mirror menu block says `[x]abort    : stop the run` (line 119). The note
  under it (line 122) and the "Abort" section (lines 58-59) say it ends only the
  setup script. Spec ambiguity; protected file.
- INCIDENT: deploy order differs between the installer's Step 21
  (aitools-install.sh:833, .ps1:760-768) and the sync loop (scripts/aitools:1108,
  1151; aitools.ps1:157): setup-user-cursor is 2nd in one and 6th in the other.
  No spec names the order. Low.
- INCIDENT: `AITOOLS_DEPLOY=1` is exported by scripts/aitools:1099 and
  aitools.ps1:159, and no script reads it. Dead code. Low.
- INCIDENT: setup-user-hooks.sh:70 / .ps1:58 read userRepoPath from config.json
  directly. setup-user-skills and setup-user-settings use
  `resolve_user_repo_path` / `Resolve-UserRepoPath` (SD-7, "the one dotprofile
  resolver"). Spec deviation, low.

## 9. Full-read addendum (2026-10-26, second pass)

What each file adds beyond sections 1-8. None of them changes the answers in
sections 1-7: no file in the slice writes `~/.claude/rules`, reads dotprofile
`claude/rules`, or runs deploy-harness on main.

### scripts/aitools.ps1 520-1640

This range holds `-Version`, `mcp`, `dashboard`, `--addmcp` and the user-init
block (`# --- BEGIN user init ---` at line 737 through `Invoke-UserInit`). None
of it touches rules, setup-user-claude or deploy-harness.
- **Exit 2 inside user init:** UI helpers return 2 to mean "skipped at a prompt",
  and their callers map it to `0` + a WARN row:
  - `Read-UiChoose` (:1029-1048)
  - `Invoke-UiRegister` (:1104-1106)
  - `Invoke-UiRegisterFlow` (:1317-1327: `if ($rc -eq 2) { return 0 }`)

  So the only exit 2 that `Invoke-UserInit` returns is the hooks child's (:1673-1676).
- **Parity with scripts/aitools:**
  - The PowerShell user-init block is the function-for-function twin of the bash
    `ui_*` functions (the comments name each twin).
  - `Invoke-UiProfile` (:811-834) is the private resolver runner that #116 replaces
    with `Invoke-AitLibProfile` (#116 diff). The bash `ui_profile_run` is replaced
    the same way.
  - Machine shell: PowerShell fixes `$script:UiMachineShell = "pwsh"` (:774); bash
    `ui_machine_shell` also gives `pwsh` on Git Bash. Parity holds.
- **Nothing new for the fan-out.**

### scripts/aitools-install.ps1 1-140, 185-754

- **Step order is the same as the bash installer**, with platform-only extras:
  - Step 0 (long paths, :219-257) has no bash counterpart; the bash side has the
    brew PATH bootstrap (aitools-install.sh:340-352).
  - Step 6 installs both `aitools` (bash) and `aitools.ps1`, plus `hh.ps1`
    (:402-434).
  - The bin step is at :436-460 (removed by #106).
  - Step 7's profile block, by contrast, also defines the `aitools` / `hh` wrapper
    functions (:508-513).
- **Exit handling is the same:** every step child runs through
  `Invoke-ValidatedScript` (:150-177). `if ($scriptRc -and $scriptRc -ne 0)` makes
  exit 2 an ERROR row and the install continues, as in bash `validate_and_run`.
- **One PowerShell-only path:** a terminating error in the child (throw) gets
  `ERROR ... script failed (exception)` (:167-170). Bash has no equivalent, since
  its child is a separate process.
- **Step 21's list matches the bash installer's order** (claude, cursor, mcp,
  skills, cursor-ide-mcp, settings, hooks; :760-768 vs aitools-install.sh:833).
  The installer-vs-loop drift in section 3.3 is the same on both platforms.
- **Pre-#116 Step 3 issue:** `New-Item -ItemType Directory -Force | Out-Null`
  (:342-344) has no result check. #116 reports it can return `$null` with no error
  when a parent is a file, and replaces it with `Resolve-ReposDir`. The bash
  `mkdir -p "$REPOS_PATH"` (aitools-install.sh:421) aborts under `set -e` instead.
  The two platforms fail differently; #116 fixes both.
- **Nothing new for the fan-out.**

### scripts/setup-user-hooks.sh 131-481, setup-user-hooks.ps1 (444)

- **Precedent for removing deployed files (relevant to "minus retired" rules).**
  Both scripts delete a hard-coded list of stale hooks and their `.bak.*` files,
  with no backup and no review:
  - setup-user-hooks.sh:191-205: `STALE_HOOKS="surfacing-duty-stop.sh estimate-refresh-stop.sh intent-sentinel-stop.sh"`,
    then `rm -f "$stale_path"`. The `rm` is unchecked, and the log says
    `log_ok "Removed stale hook: ..."` regardless of the result.
  - setup-user-hooks.ps1:151-167: the same with `Remove-Item -Force` and no
    `-ErrorAction Stop`.

  This is the only removal pattern in the slice. If the fan-out ever removes
  retired rules from `~/.claude/rules`, it must not copy this pattern: the
  removal needs a result check, and per config-file-safety.md a backup.
- **settings.json is written without a backup in both scripts.**
  - setup-user-hooks.sh:383: `fs.writeFileSync(settingsFile, newJson)` inside node.
  - setup-user-hooks.ps1:376: `[System.IO.File]::WriteAllText`.
  - grep for "backup" in both files finds only the stale-backup cleanup lines
    (sh:202, ps1:164).

  config-file-safety.md "Backup before overwrite" says the JSON caller MUST call
  `backup_file` / `Backup-File`. Not fan-out scope; INCIDENT below.
- **Parity differences:**
  1. Node: the bash script needs node and exits 1 without it (sh:44-49: ERROR row
     `node not found`). PowerShell has no node check (it merges in PowerShell).
  2. chmod: bash sets `chmod +x` on created, updated and adopted hooks (sh:169-177).
     PowerShell does not (Windows).
  3. Dotprofile hooks dir: bash tests `[ -d ... ]` (sh:72). PowerShell uses
     `Test-Path` (ps1:62), which is also true for a file.
  4. Exit 2: neither script exits 2 itself. Only the lib's `_managed_abort` /
     `Invoke-ManagedAbort` inside `deploy_managed_file` does (sh:166, ps1:132).
- **Nothing reads `~/.aitools/hooks`.** Hooks come from `shared/hooks` and
  `scripts/` (`resolve_hook`, sh:79-88). The same "deploy-harness fills it but
  setup-user-* ignores it" gap as rules exists for hooks. Outside FAN-PLAN's
  scope; noted for the commander.

### scripts/setup-user-skills.ps1 (234), vs setup-user-skills.sh

- **Duplicate-name check: bash is case-sensitive, PowerShell is not.**
  - bash: `case " $SKILL_NAMES " in *" $skill_name "*)` (sh:89-92).
  - PowerShell: `$skillDir.Name -notin $skillNames` (ps1:77), and `-notin` ignores
    case.

  This is the same defect class as the known rules-filter case bug. The fan-out
  should use one explicit rule on both sides (lower-cased name, as
  setup-user-cursor.sh `lower_name` at :474 does).
- **Resolver-error rows differ:**
  - bash writes two rows, `ERROR|claude skills|not deployed: dotprofile error`
    and `ERROR|cursor skills|...` (sh:59-60).
  - PowerShell writes one row, `ERROR|skills|skipped (dotprofile error)` (ps1:51),
    with a different tool name and text.

  Parity gap, low.
- **Discovery order:** bash skips discovery when blocked (sh:73-74). PowerShell
  discovers, then clears the list (ps1:83-85). Same outcome.
- **Reverse-discovery adopt:** bash calls `adopt_managed_file SRC TARGET`
  (sh:218). PowerShell calls `Adopt-ManagedFile -SourceFile -Targets @()` and
  checks the count (ps1:206-209). Equivalent.
- **Nothing reads `~/.aitools/skills`** (ps1:36, sh:43): the same gap as hooks.

### scripts/setup-user-settings.sh/.ps1 (160/148)

- **Parity is clean:** the same branches (resolver error / no dotprofile / no
  profile.json / sync) and the same rows and texts (sh:72-145, ps1:58-133).
- **Legacy migration writes the dotprofile's profile.json without a commit or
  push** (sh:104-130, ps1:84-115). N-Q2 says dotprofile writes are committed and
  pushed. Pre-existing; not fan-out scope.
- Neither script exits 2 itself. `sync_managed_json` / `Sync-ManagedJson` can
  (per-leaf `[x]abort`, interactive-menus.md).
- **Nothing new for the fan-out.**

### scripts/setup-user-mcp.sh/.ps1 (263/237)

- **Missing summary rows in PowerShell:** a missing `claude` or `node` writes
  `write_summary ERROR "claude mcp" ...` in bash (sh:47-57) but only `LogError` +
  `exit 1` in PowerShell (ps1:33-41). Parity gap; the entry point's loop then adds
  its own `script failed (exit 1)` row, so the user still sees an ERROR.
- **Cloud MCP status is printed twice in the sync:** once by the script's exit
  footer (`show_cloud_mcp_status`, sh:255/259; ps1:229/233) and once by the entry
  point after setup-user-mcp (scripts/aitools:1182-1184, aitools.ps1:201-203).
  Cosmetic.
- **Nothing new for the fan-out.**

### scripts/setup-user-shell.sh/.ps1 (145/111)

- **No dry-run support in either script.** Neither reads `AITOOLS_DRY_RUN` or a
  `--dry-run` / `-DryRun` flag. Both write the login profile unconditionally
  (sh:68-102, ps1:57-83). Yet the installer runs them at Step 7 under
  `--dry-run` (aitools-install.sh:129 exports `AITOOLS_DRY_RUN=1` before Step 7).
  So a dry-run install writes `~/.bash_profile` / `$PROFILE`. INCIDENT below.
- **Parity differences (accepted platform differences):**
  - Profile path: `~/.bash_profile` vs `$PROFILE`.
  - Advisories: bash has the zsh-only advisory (sh:125-133); PowerShell has none.
- **Nothing new for the fan-out.**

### scripts/setup-user-config.sh/.ps1 (393/390)

- **Never exits 2** (header, sh:34 and ps1:35: "Never prompts, never exits 2").
  This matters for #106: deploy-harness runs this writer, so an exit 2 from
  deploy-harness can only come from its own review menus, not from the writer.
- **Header goes stale with #106.** Both headers say the writer is consumed by
  "the `aitools` sync deploy list (first entry)" (sh:10-11, ps1:9-10). #106
  removes it from the list and runs it from deploy-harness. Neither the #106 diff
  nor the #116 diff updates these lines. Stale documentation after #106, low.
- **Parity differences:**
  - The temp-file cleanup differs (A-11; fixed by #114):
    - bash: an unchecked EXIT trap, `cleanup() { rm -rf "$WORK_DIR"; rm -f "$CONFIG_TMP"; }` (sh:125-126).
    - PowerShell: `Remove-ConfigTmp` with LogWarn (ps1:138-143).
  - Unknown options: bash rejects them in its parse loop (sh:94). PowerShell takes
    them through `ValueFromRemainingArguments` (ps1:49, 81-85). Equivalent outcome.
- **Nothing for the fan-out:** the writer does not touch rules.

### Section 2 correction

Every file in the slice is now read in full (section 2 updated). The deploy order
and exit-2 handling in sections 3.1-3.4 are confirmed on both platforms. The one
parity difference in that handling is the PowerShell-only "exception" row for a
throwing in-process child.

### Further INCIDENT markers (not filed)

- INCIDENT: setup-user-hooks.sh:383 and setup-user-hooks.ps1:376 write
  `~/.claude/settings.json` without `backup_file` / `Backup-File`.
  config-file-safety.md "Backup before overwrite" says the JSON caller MUST back
  up. Medium.
- INCIDENT: the stale-hook removal is unchecked:
  - setup-user-hooks.sh:195 runs `rm -f` and then `log_ok`, whatever `rm` returned.
  - setup-user-hooks.ps1:155 runs `Remove-Item -Force` with no
    `-ErrorAction Stop` or result check.

  Spec: script-standards.md "Error handling requirements". Low.
- INCIDENT: setup-user-shell.sh/.ps1 ignore dry-run and write the login profile
  during `aitools install --dry-run`. The installer exports `AITOOLS_DRY_RUN=1` at
  aitools-install.sh:129 before Step 7. Spec: the `--dry-run` help text, "Preview
  mode -- show what would change without writing" (aitools-install.sh:66). Medium.
- INCIDENT: the skills duplicate-name check is case-sensitive in bash
  (setup-user-skills.sh:89-92) and case-insensitive in PowerShell
  (setup-user-skills.ps1:77). Same class as the rules-filter defect. Low.
- INCIDENT: the resolver-error rows differ between setup-user-skills.sh:59-60
  (two rows, "claude skills" / "cursor skills") and setup-user-skills.ps1:51 (one
  row, "skills"). Spec: interactive-menus.md / cross-platform parity. Low.
- INCIDENT: setup-user-mcp.ps1:33-41 writes no ERROR summary row when claude or
  node is missing; the bash twin does (sh:47-57). Low.
- INCIDENT: setup-user-config.sh:10-11 / .ps1:9-10 name the sync deploy list as a
  consumer. After #106 that is wrong: deploy-harness is the consumer. Low,
  documentation.
