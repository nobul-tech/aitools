# S3-Reconcile-Code findings (2026-10-26)

Read-only code verifier for S3-Reconcile. No repo file edited, no branch switched,
nothing committed. Drafts were applied only to scratch copies and checked there.

## Summary (5 lines)

1. Fan-out: on main and on every open PR, `~/.claude/rules` gets the **dotprofile `claude/rules` only**. `~/.aitools/rules` merges shared/rules + .claude/rules + dotprofile rules, but nothing runs deploy-harness until #106. Cursor fans out all of `~/.aitools/rules` on main, and only shared + dotprofile on #110. This matches S3-FanPlan, with one FanPlan error noted in 1.3.
2. Step 7 FAILs on every push today. I reproduced it in an isolated HOME: the committed dotprofile `deploy/` (825aed4) differs from a fresh build in 42 of 42 files and lacks 8. The rebuild is reproducible, so one rebuild-and-commit fixes main. **But 16 of 19 open PRs change deploy/ inputs, and they FAIL step 7 by design even after that rebuild.** The commander has to decide this; a variant is drafted.
3. Abort: the JSON-field menu says `stop the run`, but it only ends the script. A non-harness exit 2 is ERROR `script failed (exit 2)` on main and on #106. On #115/#116 the lib relay makes it ERROR `aborted (exit 2)`, a third convention. **INCIDENT:** #106's PS1 hands `"harness files"` to the relay while the sh side does not, so PS1 writes duplicate rows. Drafts for the menu, the WARN rule, the relay and the parity fix all syntax-check, and the hookin test passes 39/39.
4. `--alias` auto-claim is unchanged at 8e490d7 and on #113/#115/#116 (the code only shifts). The confirm-or-ERROR fix is drafted for both shells, with 2 test changes and 2 new pty cases. test-user-init passes 216/216 under bash 5 + pwsh and 115/115 under /bin/bash 3.2.
5. aiToolingRepoPath: I recommend moving the migration into setup-user-config and keeping only a read fallback in the entry points. The reason: setup-user-config's validation needs `repoPath`, so simply deleting the migration would make the writer ERROR on a legacy machine. Drafted and tested in an isolated HOME (key migrated, backup made, other keys kept), and test-config passes 190/190.

Baseline: `origin/main` = 8e18ad4. That commit adds only mission reports: `git diff --stat 8e490d7 origin/main -- scripts tests` is empty, so every script line cited "on main" is identical at 8e490d7. All open PRs are based on 8a9dcb5. The stack #98/#103 -> #113 -> #115 -> #116 is cumulative (`git log 8a9dcb5..origin/fix/mf-installer-relay`).

## 1. Fan-out state (rules sources and targets)

### 1.1 Table (file:line on the named ref)

| Consumer | Ref | Source dir | Target dir | Which rules |
|---|---|---|---|---|
| setup-user-claude.sh | main | `$USER_REPO_PATH/claude/rules` (:290-292) | `$CLAUDE_DIR/rules` (:295) | dotprofile only. Adopt target is the dotprofile rule (:349-351) |
| setup-user-claude.ps1 | main | `Join-Path $userRepoPath "claude\rules"` (:308-312) | `Join-Path $claudeDir "rules"` (:316) | dotprofile only (:380-381) |
| setup-user-claude.sh/.ps1 | #103 fix/mf-dotprofile-adopt-push, #112 fix/mf-audit-claude-build, #113, #115, #116 | same lines (sh :290-295 on every branch; ps1 :308-316, #112 :318-326) | same | dotprofile only. The branches only remove the private commit+push block (END marker 428->408 sh, 460->437 ps1; #112 ps1 447) |
| setup-user-cursor.sh | main | `HARNESS_RULES_DIR="$HOME/.aitools/rules"` (:389) | `$CURSOR_DIR/rules` (:390) | everything in ~/.aitools/rules (all three sources), as .mdc |
| setup-user-cursor.ps1 | main | `.aitools\rules` (:383) | `$cursorDir\rules` (:384) | same |
| setup-user-cursor.sh/.ps1 | #110 feature/harness-cursor-user-rules | sh :403, ps1 :398 | sh :404, ps1 :399 | **user-level only**: manifest source `shared` or `dotprofile` (sh header :16-21, :559, :635; ps1 :544, :613). No manifest gives WARN `no rules manifest` + ACTION (sh :574-576) |
| setup-user-cursor.sh/.ps1 | #109 fix/mf-audit-consumers | sh :390, ps1 :386 | :391 / :387 | as main (row fixes only) |
| deploy-harness.sh | main | `shared/rules` :260, `.claude/rules` :261, dotprofile `claude/rules` :263 | `$HARNESS_DIR/rules` | all three, flat-md. Conflict: first source wins; each duplicate is `log_error` + counted (:238, header :24) |
| deploy-harness.ps1 | main | :244, :245, :247 | same | same (:219-221) |
| deploy-harness.sh/.ps1 | #100 feature/harness-rules-manifest | sh :272/:273/:275, ps1 :252/:253/:255 | same | same, plus section 5b: manifest `~/.aitools/rules/.aitools-rules-manifest` (`# aitools rules manifest v1`, `name<TAB>shared|aitools|dotprofile|retired`). Retired rules are backed up and removed from ~/.aitools/rules (sh :357-514) |
| deploy-harness.sh/.ps1 | #110, #111 | #110 = #100's code (same lines); #111 sh :295/:296/:298, ps1 :279/:280/:282 | same | same as #100 (stacked) |

Who runs deploy-harness: nobody on main. `git grep -c deploy-harness` returns 0 for scripts/aitools, aitools.ps1 and aitools-install.* on main. Only #106 wires it (aitools 12, install.sh 12, install.ps1 10, aitools.ps1 7 matches). #116's single match is a comment (install.sh:129).

### 1.2 Consequence

No branch delivers `shared/rules/*` (hook-lifecycle.md, scratch.md) or `.claude/rules/*` to `~/.claude/rules`. The commander's 2026-10-23 order, "put aitools rules in the user space of claude code", is not implemented anywhere yet. That is FAN-PLAN's job.

### 1.3 Against S3-FanPlan

- **Matches.** The Claude findings (sections 1, 3.2, 3.3, 5) and the Harness findings (summary 1-5) agree with the table.
- **Discrepancy.** S3-FanPlan-Claude-findings.md section 6 item 5 says the case-sensitivity defect is the "same ... in setup-user-cursor.sh 493-495". That is wrong as a parity claim. setup-user-cursor is case-sensitive in both shells (.ps1 uses `-clike "*.md"`, main :496-497), so the shells agree. The real parity defects are:
  - deploy-harness.ps1 `$rel -notlike '*.md'` (main :198, case-insensitive) against the .sh's `*.md)` (case-sensitive). The Harness findings state this correctly.
  - setup-user-claude.ps1 `-Filter "*.md"` against the .sh glob.

## 2. Pre-push step 7 after 8e490d7

### 2.1 Code

- **sh:** check-pre-push.sh:107-226 (main). Guards: no userRepoPath gives SKIP (:122-123); no node gives WARN (:124-125). Then:
  - `git archive` of the dotprofile HEAD into a temp `dot/` and `committed/`, and `rm -rf dot/deploy`.
  - A temp HOME config.json via node, then `build-deploy.sh` with `HOME=<tmp>` and `AITOOLS_USER_REPO_PATH=<tmp>/dot` (:126-145).
  - FAIL on a build error (:150) or when nothing was built (:157).
  - `diff -rq committed/deploy dot/deploy`, where exit 1 gives `dotprofile deploy/ is stale (<files>) -- run build-deploy.sh and commit in <dotprofile>` (:160-169).
  - A smoke `--dry-run` of the fresh setup-user-claude/settings/cursor .sh, plus the endpoint snapshot path (:174-213).
  - PASS/FAIL (:218-222).
- **ps1:** check-pre-push.ps1:110-273 (main). Same flow: Git Bash lookup and WARN, no node needed. It compares top-level files with `Get-FileHash` (:246-254) where the .sh uses recursive `diff -rq`. That is equivalent today because the dotprofile `deploy/` has no subdirectories (`find ... -mindepth 1 -type d` printed nothing). It cleans up with `Remove-Item` (:272).
- **8e490d7 diff:** it removed only the trigger (`deploy_sources=` / `$deploySources`) and its SKIP, in both files. **.sh and .ps1 still agree** on outcomes.

### 2.2 Why it FAILs on every push now (reproduced)

`.scratch/session-rccode/step7-sim.sh` reproduces step 7's own method in an isolated HOME: git archive of the dotprofile HEAD, build from the main checkout. Output:

```
build rc=0
diff rc=1 lines=      50
only in fresh build: aitools-json.pl aitools-json.ps1 aitools-profile.ps1 aitools-profile.sh deploy-harness.ps1 deploy-harness.sh setup-user-config.ps1 setup-user-config.sh
differ count: 42      (fresh build 50 files, committed 42)
```

- The committed `deploy/` was last regenerated at 825aed4 (2026-10-22 18:59 -0700, `git -C aitools-nobul-jose log -- deploy`). It is pre-M3 generator output.
- A second isolated build (`step7-repro.sh`, a different HOME and a different dotprofile copy path) gave `repro diff rc=0`. The output is reproducible and embeds neither HOME nor the dotprofile path, so one rebuild-and-commit makes step 7 pass on main.

### 2.3 Rebuild the commander runs (macOS, main checkout on origin/main, clean source dirs)

```
AITOOLS_USER_REPO_PATH=/Users/new-jose/repos/aitools-nobul-jose bash /Users/new-jose/repos/aitools/scripts/build-deploy.sh
git -C /Users/new-jose/repos/aitools-nobul-jose add deploy
git -C /Users/new-jose/repos/aitools-nobul-jose commit -m "Regenerate deploy/ from aitools main 8e18ad4"
git -C /Users/new-jose/repos/aitools-nobul-jose push
```

- Plain `aitools` also rebuilds it (scripts/aitools:2053-2058, Step 2), but it does not commit.
- The build deletes and rebuilds `<dotprofile>/deploy`. That is the intended effect here.
- It must be repeated after every merge to main that changes a deploy/ input. Otherwise every later push FAILs again.
- **Precondition, not met right now.** Since 15:56 the main checkout has another agent's uncommitted edits (`git diff --stat`): CLAUDE.md, README.md, ROADMAP.md, .claude/rules/aitools-workspace.md, .cursor/rules/cross-platform.mdc, reference/cross-platform-detail.md, reference/harness.md, reference/tool-evaluation-criteria.md, shared/cursor-rules/user-rules.md (they look like BUILD-PKG platform-list edits).
  - reference/, shared/ and .claude/rules are deploy-harness sources. A rebuild from this checkout would embed those uncommitted edits, if the snapshot reads working-tree content (unverified).
  - Rebuild only after they are committed or stashed by their owner, or build from a clean worktree at origin/main.
  - My two isolated builds finished at 15:55:26 and 15:55:43, before those edits (file mtimes), so they reflect origin/main.

### 2.4 The gap: PR branches FAIL by construction

Step 7 builds from **the branch being pushed** and compares the result with the dotprofile `deploy/`, which is built from main. A branch that changes any deploy/ input therefore always differs. It could pass only if `deploy/` were built from unmerged code and committed to dotprofile main, which would be wrong for main.

`.scratch/session-rccode/item2.sh` checks every open PR's diff against the input set: setup-*, build-deploy, lib, resolver, JSON engine, deploy-harness, bin CLIs, shared/, reference/, registries/, .claude/{hooks,skills,rules}.

- Affected (16 of 19): #98, #99, #100, #101, #103, #105, #106, #108, #109, #110, #111, #112, #113, #114, #115, #116.
- Not affected: #97, #102, #104.

The WARN-for-stale-deploy-harness-only idea (AnsA Q1c) is now **relevant in a different form**. Branch-caused differences hit `setup-*.sh` too, not only `deploy-harness.*`. The useful split is "this push changes deploy/ inputs" (expected; rebuild after merge) against "stale relative to main" (actionable now).

Also, every open PR branch still carries the **old** trigger in its own check-pre-push (`no deploy-relevant source changes` at sh:125 / ps1:139 on all 8 branches I grepped). A delegate running pre-push from an un-rebased worktree gets the old behaviour.

**Draft (only if the commander wants it; it keeps "step 7 always runs").** The build, compare and smoke run always run. A stale result becomes WARN when this push changes deploy/ inputs. FAIL stays for build failure, smoke failure, and staleness on a push that changes no input. Full text: `.scratch/session-rccode/edits-step7.txt` (E13a-c, E14a-c). The sh, verbatim:

```
# E13a, after "else" of the guards (OLD: else / d7_tmp=$(mktemp -d) / mkdir -p ...)
    d7_inputs=$(printf '%s\n' "$PUSH_FILES" | grep -E '^(scripts/(setup-[^/]*|build-deploy|aitools-lib|aitools-profile|deploy-harness)\.(sh|ps1)$|scripts/aitools-json\.(pl|ps1)$|scripts/(harness-db|read-session|read-session-full)\.py$|shared/|reference/|registries/|\.claude/(hooks|skills|rules)/)' | tr '\n' ' ') || d7_inputs=""
    d7_note=""
# E13b, replaces the d7_problems="dotprofile deploy/ is stale ..." line
            if [ -n "$d7_inputs" ]; then
                d7_note="this push changes deploy/ inputs (${d7_inputs% }) -- after it merges, rebuild deploy/ from main and commit in $USER_REPO_PATH (differs now: ${d7_files% })"
            else
                d7_problems="dotprofile deploy/ is stale (${d7_files% }) -- run build-deploy.sh and commit in $USER_REPO_PATH"
            fi
# E13c, the result
        if [ -n "$d7_problems" ]; then step_fail ...; elif [ -n "$d7_note" ]; then step_warn "7" "deploy/ matches source" "$d7_note"; else step_pass ...; fi
```

The ps1 twin uses `-cmatch` (case-sensitive, like grep -E) on `$pushFiles` (defined at check-pre-push.ps1:44-46) and has the same three branches.

- **Error-handling audit.** The `|| d7_inputs=""` is commented in the draft. A grep failure leaves the list empty, which keeps the stricter FAIL (fail-safe). No new suppressions.
- **Checks run.** `bash -n` OK; pwsh parser OK. A functional run was not done (it would run check-pre-push).
- **Risks.**
  - The input regex duplicates deploy-harness's source list (drift risk, the same class as the original trigger bug).
  - On an input-changing branch, staleness relative to main is masked (reported as WARN).
  - `reference/pre-push-checklist.md:40` would need a sentence.

## 3. Abort

### 3.1 Facts

- **(a) Menu text.**
  - `prompt_json_field_review` prints `  [x]abort    : stop the run`: aitools-lib.sh:2376 (comment :2327 "abort (x) is global and exits the run (code 2)"). PS1: aitools-lib.ps1:2359 (comment :2312).
  - `x` calls `_managed_abort` (sh :2400), which does `log_error "Aborted by user"; exit 2` (sh :956-959). That ends **this script** (setup-user-settings).
  - The lines are byte-identical on #106 (sh :2376, ps1 :2352) and on #103/#112/#113/#115/#116 (only shifted). No open PR hunk touches them (`item3b.sh`), so a text fix merges cleanly in any order.
  - The text-review menu already says `stop this script (exit 2)` (sh :1735, ps1 :1692).
  - The #106 docs already flag the JSON-field text: `.claude/rules/interactive-menus.md` on #106 :130-135, "Despite the menu text, the run does not stop".
- **(b) Runner handling of a non-harness exit 2.**
  - **main.** `deploy_configs`: aitools:1137-1138 (Git Bash) and :1174-1175 (POSIX) give `log_error` + ERROR `script failed (exit 2)`, errors++, and the run continues. aitools.ps1:193-194 does the same. The installer's `validate_and_run` (aitools-install.sh:238) and `Invoke-ValidatedScript` (.ps1:175) give ERROR and continue. deploy-harness is not run.
  - **#106.** Only deploy-harness exit 2 stops: `deploy_abort` (aitools:1096-1100) and `Invoke-DeployAbort` (aitools.ps1:158-163) write WARN `harness files` `aborted by user`; the installer's `run_harness_step` (install.sh:273-276) and `Invoke-HarnessStep` (install.ps1:198-201) do the same. Any other script still gets ERROR `script failed (exit 2)` (aitools:1158-1159, :1214-1215; aitools.ps1:224-225; install.sh:240-243; install.ps1:178-180). This matches the S3-AbortDocs hand-back.
  - **#115/#116 (lib relay).** `run_child_relayed` turns rc 2 into `log_error "<label> aborted (exit 2)"` plus, with `--summary-tool`, ERROR `<tool>` `aborted (exit 2)` (#116 aitools-lib.sh:713-716; PS1 #115 aitools-lib.ps1:586-590). user init's hook exit 2 gives that ERROR row and then `return 2` (#116 aitools:1015-1054; tests assert `ERROR|claude hooks|aborted (exit 2)`, #116 test-user-init.sh:409, and `ERROR|child tool|aborted (exit 2)`, test-lib.sh:885). **That makes three conventions for exit 2.**

**INCIDENT (parity + duplicate rows, #106).**

- The PS1 harness calls pass a summary tool to the relay: `Invoke-ChildRelayed "Step 8b: deploy-harness.ps1" $Harness @{} "harness files"` (install.ps1:196) and `Invoke-ChildRelayed $script $scriptPath @{} "harness files"` (aitools.ps1:196). The sh calls pass none (install.sh:270; aitools:1197 `run_child_relayed "$script" ...`).
- On main's lib, a throw gives ERROR `harness files` `script failed (exception)` (aitools-lib.ps1:519). The #106 caller then adds a second ERROR `script failed (exit 1)` (install.ps1:205-208; aitools.ps1:200-205).
- After #115 merges, a PS1 abort also gives ERROR `aborted (exit 2)` from the relay **plus** #106's WARN `aborted by user`, and a PS1 failure gives two ERROR rows. sh writes one row in every case.
- After #106 + #115, the sh deploy-harness abort also logs an `[error]` line from the relay (`... aborted (exit 2)`) under a WARN row.

**Open decision.** The #106 docs (interactive-menus.md :61-69) record "commander, 2026-10-26: keep this behaviour", and the bullet they wrote includes "handled like any failure ... ERROR `script failed (exit 2)`". The brief's decision reads "keep #106's behaviour (only deploy-harness exit 2 stops a run)", which is about stopping, not about the row. **(ii) changes the row from ERROR to WARN, so it needs Jose's explicit yes.** Suggested answer: yes. An abort is a user choice, and the summary should not report it as a failure; the stop rule is unchanged.

### 3.2 Drafts (full text: `.scratch/session-rccode/edits-abort.txt`, `edits-relay.txt`)

**(i) Menu text (lib, on main or any branch; no hunk conflict).**

```
OLD sh  (aitools-lib.sh:2376)  printf '  [x]abort    : stop the run\n' > /dev/tty
NEW sh                         printf '  [x]abort    : stop this script (exit 2)\n' > /dev/tty
OLD sh  (:2327)  # abort (x) is global and exits the run (code 2).
NEW sh           # abort (x) is global: it ends this script (exit 2, D-TS13); the runner decides
                 # whether the run goes on (only deploy-harness's abort stops it).
OLD ps1 (aitools-lib.ps1:2359)     [Console]::WriteLine("  [x]abort    : stop the run")
NEW ps1                            [Console]::WriteLine("  [x]abort    : stop this script (exit 2)")
OLD ps1 (:2312)  # setting/rule. overwrite/adopt/skip are per-leaf; abort (x) exits (code 2).
NEW ps1          # setting/rule. overwrite/adopt/skip are per-leaf; abort (x) ends this script
                 # (exit 2, D-TS13); the runner decides whether the run goes on.
```

Docs that quote the menu need the same change: interactive-menus.md (protected) on #106 :130 and its "Despite the menu text" note :133-135, plus the .mdc twin. They change only after the code text does. No test asserts the JSON-field abort text (`git grep "stop the run" -- tests/` finds only the text-menu asserts).

**(ii) Non-harness exit 2 = WARN `aborted by user`, run continues (on #106).**

- scripts/aitools: a new helper after `deploy_abort` (#106 :1096-1100):

  ```
  deploy_script_abort() {
      log "$1: aborted by user at a review menu -- the run continues with the next script"
      write_summary WARN "$2" "aborted by user"
  }
  ```

  The Git Bash branch (#106 :1153-1161) and the POSIX branch (:1213-1217) change from `if [ "$script_rc" -ne 0 ]; then log_error ... ERROR ...` to `if [ "$script_rc" -eq 2 ]; then deploy_script_abort "$script" "$row_tool"` (POSIX: `"${script%.sh}"`) `elif [ "$script_rc" -ne 0 ]; then <unchanged>`.
- aitools.ps1: `Invoke-DeployScriptAbort([string]$AbortedScript, [string]$Tool)` after `Invoke-DeployAbort`, with the same Log + `Write-Summary "WARN" $Tool "aborted by user"`. Deploy-Configs (#106 :222-226) becomes `if ($scriptRc -eq 2) { Invoke-DeployScriptAbort $script ($script -replace '\.ps1$', '') } elseif ($scriptRc -and $scriptRc -ne 0) { <unchanged> }`. It uses if/elseif, not `continue`, so the setup-user-mcp cloud status still shows.
- aitools-install.sh `validate_and_run` (#106 :238-244): `if [ "$script_rc" -eq 2 ]; then log "$name: aborted by user at a review menu -- the install continues"; write_summary WARN "${name%.sh}" "aborted by user"; elif [ "$script_rc" -ne 0 ]; then <unchanged>`. The comment notes that `bash -n` above rules out a syntax-error exit 2.
- aitools-install.ps1 `Invoke-ValidatedScript` (#106 :176-180): the same, with the ParseFile note.
- **Parity fix (the INCIDENT above).** Drop the 4th argument at install.ps1:196 and aitools.ps1:196, so each caller writes the one `harness files` row, as sh does.
- **Relay (on #115; required if (ii) is adopted, otherwise there are three conventions).** With rc 2, log (not `log_error`) `"<label>: aborted by user at a review menu (exit 2)"`, write WARN `<tool>` `aborted by user` when a tool is given, and return 1 (the caller reads AITLIB_CHILD_RC). Other non-zero exits are unchanged. Section comments are updated (sh :520-524, ps1 :438-445). The same rule applies in #116's Windows direct hook block (aitools:1039-1046).
  - Tests to update: #116 test-lib.sh:885 (`ERROR|child tool|aborted (exit 2)` -> `WARN|child tool|aborted by user`), test-user-init.sh:409 (`ERROR|claude hooks|aborted (exit 2)` -> `WARN|claude hooks|aborted by user`), and the comments at #116 aitools:1015-1018, aitools.ps1:1648-1651.

**Rules respected.**

- interactive-menus.md "Abort": exit 2 = user abort, and only deploy-harness stops the run.
- script-standards "every code path calls write_summary": each abort path writes one WARN row.
- The summary detail `aborted by user` is 15 characters (limit 30).
- WARN, not ERROR: the user's choice is not a functional failure. The `errors` counter is not incremented.
- Identical text and outcomes in bash and PowerShell.

**Error-handling audit.** No new suppressions. The bare `exit 2` is still the only signal (D-TS13, no marker).

**Residual risk:** a bash runtime exit 2 that is not an abort, for example a `[` syntax error under `set -e` (`bash -n` does not catch it), would show as WARN `aborted by user`. The child's deploy.log then lacks the `Aborted by user` line. Accepted by D-TS13.

**Verification run.**

- `bash -n` OK on all edited .sh copies. The pwsh parser is OK on all edited .ps1 copies (`syntax.sh`, `parse.ps1`).
- `tests/hookin/test-hookin.sh` on a #106 copy with the runner drafts: **39 passed, 0 failed, 0 skipped** (it covers the PS1 harness step and loop, so the dropped relay argument is exercised).
- Not run: the relay drafts against #115/#116's tests, which are expected to need the 2 assert changes above. No test covers a non-harness exit 2. Suggested new hookin case: a stub setup-user-claude that exits 2 gives `WARN|setup-user-claude|aborted by user`, the later stubs still run, and the loop rc is 0.

## 4. `--alias` auto-claim (AnsB edit C)

### 4.1 Facts at 8e490d7 and on #113/#115/#116

- **sh.** `ui_register` (scripts/aitools:475-551) turns resolver exit 4 with `owner unregistered` into `--claim <ownerKey>` at :492-496, before the `ui_can_ask` check at :497. The header comment :468-471 calls that intended ("the explicit alias names it").
- **PS1.** `Invoke-UiRegister` (aitools.ps1:1067-1107) does the same at :1086-1090, before `Test-UiCanAsk` at :1091.
- **PR branches.** The text is identical on #113 and #115 (sh :462, ps1 :1071) and on #116 (sh :462, ps1 :1079). Shifts only; no hunk touches the logic.
- **Resolver comments.**
  - aitools-profile.sh:111-112 and ps1:120-121 ("after an interactive choice only") become TRUE with the fix.
  - aitools-profile.sh:1299 and ps1:1134 ("passed by user init only after the user picked KEY at a terminal") become true in substance. Optional wording: "picked or confirmed KEY at a terminal".
- **Tension to surface.** The `--alias` parse comment says "register this machine without a prompt (P-Q12)" (scripts/aitools:1357 on main). With the fix, `--alias` naming an unowned profile prompts on a terminal. Only a new alias is prompt-free.

### 4.2 Draft (full text: `.scratch/session-rccode/edits-claim.txt` E7a, E7b, E8)

```
# scripts/aitools :492-496 OLD
        if [ "$owner" = "unregistered" ] && [ -n "$okey" ]; then
            log "machine profile: alias \"$value\" names profile $okey, which belongs to no machine -- claiming it for this machine"
            extra+=(--claim "$okey"); mode=claim
            continue
        fi
# NEW
        if [ "$owner" = "unregistered" ] && [ -n "$okey" ]; then
            # The alias names a profile no machine owns: --claim only after the user
            # confirms at a terminal (a claim follows a choice at a terminal)
            if ! ui_can_ask; then
                log_error "machine profile: alias \"$value\" names profile $okey, which belongs to no machine -- not claimed without a confirm on a terminal; run aitools user init on a terminal, or --alias <another name>"
                write_summary ERROR "machine profile" "not claimed (no terminal)"
                ui_action "Run: aitools user init on a terminal to claim $okey (or --alias <another name>)"
                return 1
            fi
            printf 'Alias "%s" names profile %s, which belongs to no machine. Claim it for this machine? [y/N]: ' "$value" "$okey" > /dev/tty
            read_tty_choice ans "no"
            case "$ans" in
                [yY]*)
                    log "machine profile: alias \"$value\" names profile $okey, which belongs to no machine -- claiming it for this machine (confirmed at the prompt)"
                    extra+=(--claim "$okey"); mode=claim
                    continue ;;
                *)
                    log_warn "machine profile: alias \"$value\" names profile $okey, which belongs to no machine -- not claimed, registration skipped"
                    write_summary WARN "machine profile" "skipped"
                    return 2 ;;
            esac
        fi
```

- **PS1** (aitools.ps1:1086-1090): the same, using `Test-UiCanAsk`, `Write-UiAction`, `[Console]::Write(...)`, `Read-ConsoleChoice "no"`, `$ans -match '^[yY]'`, and `return 1` / `return 2`. Verbatim in E8.
- **Header comment** :468-471 NEW: "... a profile that belongs to no machine is claimed instead (--claim), only after a confirm on a terminal; another machine's needs a confirm on a terminal, then --allow-duplicate-alias (that profile is never rewritten). Without a terminal both are refused (ERROR + ACTION); a declined confirm skips (WARN)."
- **Outcomes.** These mirror the existing other-machine branch: return 1 = ERROR + ACTION, return 2 = WARN `skipped` (the caller then logs the not-registered error, exit 1). `--force` counts as no terminal (`ui_can_ask` is false). Every alias source is covered (`--alias`, `AITOOLS_MACHINE_ALIAS`, `[n]ew`, default hostname). The menu's numbered pick (mode=claim) is not affected.
- **Error-handling audit.** No suppressions. Each `log_error` is paired with an ERROR row.

**Tests** (`.scratch/session-rccode/edits-test.txt`):

- tests/profile/test-user-init.sh:285-288, `alias-claim` -> exit 1, `ERROR|machine profile|not claimed (no terminal)`, `ACTION||Run: aitools user init on a terminal to claim nobul-mac (or --alias <another name>)`, `pj_lacks THIS_KEY`.
- New pty cases `pty-claim-confirm` (input `\n\ny\n`, exit 0, claimed) and `pty-claim-decline` (`\n\nn\n`, exit 1, WARN `skipped`), before the `--force` case.
- The anchors exist on #116 too (test-user-init.sh:319, :576).

**Verification.** The test was run on a throwaway copy (origin/main + drafts; it builds its own isolated HOMEs):

- **216 passed, 0 failed** (bash 5 + pwsh, menus and rows identical in both shells).
- `AITOOLS_TEST_BASH=/bin/bash --bash-only`: **115 passed, 0 failed** (bash 3.2).

## 5. aiToolingRepoPath rename (AnsB edit H)

### 5.1 Facts (8e490d7; no open PR touches it: AnsB grep, and #116's hunks skip the region)

- **sh.** scripts/aitools:1440 reads `repoPath` or else `aiToolingRepoPath`, raw. :1445-1469: when the old key exists and node is present, node rewrites config.json in place. It adds repoPath (ai-tooling->aitools) when absent and deletes the old key. There is no backup and no validation. A failure only adds a pre-lib warning. Without node the file is silently not migrated.
- **PS1.** aitools.ps1:439-464: the same with ConvertTo-Json + WriteAllText (it re-formats the file). `-replace` is case-insensitive there, against case-sensitive JS.
- **History.** The migration came in with 174b0d6 (2026-02-28). This Mac's config.json has no `aiToolingRepoPath` (`grep -c` = 0). Windows: unknown.
- **Key fact for the choice.** setup-user-config validates that `version`, `reposPath`, `repoPath` exist after every merge (setup-user-config.sh:298-300, ps1:303-304), and keeps repoPath only from flags or the file (header :18).
  - So deleting the entry-point migration alone breaks a legacy machine. Its bare run (deploy-harness on #106, user init) would ERROR `validation failed`.
  - The installer passes `--repo-path` (aitools-install.sh:505), so `aitools install` would heal it, but a sync would not.

### 5.2 Recommendation: move the migration into setup-user-config, and keep a read-only fallback in the entry points

Reasons:

- The writer is the "only config.json writer" (setup-user-config.sh:2, the config intent, config-file-safety.md). It already backs up and validates.
- The entry points still need a repo path before the lib loads, so they keep reading the old key, in memory only.
- After one writer run the key is gone, and the warning stops.

Drafts (`.scratch/session-rccode/edits-claim.txt` E9-E12):

```
# scripts/aitools :1440-1469 NEW (replaces the read and the whole node block)
# A config.json from before the ai-tooling -> aitools rename may have only the
# legacy key aiToolingRepoPath: read it (ai-tooling -> aitools) for this run. The
# file is not rewritten here: setup-user-config, the only config.json writer,
# migrates the key (backup + validation) on its next run.
if raw=$(read_config_key "$config" "repoPath"); then
    repo_path=$(to_native_path "$raw")
elif raw=$(read_config_key "$config" "aiToolingRepoPath"); then
    repo_path=$(to_native_path "${raw//ai-tooling/aitools}")
    _pre_lib_warnings+=("config.json has the legacy key aiToolingRepoPath and no repoPath -- using $repo_path until setup-user-config migrates it")
fi
repo_path="${repo_path:-$HOME/repos/aitools}"
```

- **aitools.ps1 :439-464:** the same, using `-creplace` for parity.
- **setup-user-config.sh**, after `if [ -n "$REPO_PATH_ARG" ]; then op_set string "$REPO_PATH_ARG" repoPath; fi` (:264):

  ```
  if [ "$IN" != "-" ]; then
      LEGACY_RP=""; EXISTING_RP=""
      cfg_get LEGACY_RP aiToolingRepoPath
      if [ -n "$LEGACY_RP" ]; then
          cfg_get EXISTING_RP repoPath
          if [ -z "$REPO_PATH_ARG" ] && [ -z "$EXISTING_RP" ]; then
              op_set string "${LEGACY_RP//ai-tooling/aitools}" repoPath
          fi
          OPS="${OPS}del"$'\t'"aiToolingRepoPath"$'\n'
          log "config: legacy key aiToolingRepoPath migrated to repoPath and removed"
      fi
  fi
  ```

  It sits behind a 4-line comment; verbatim in E11.
- **setup-user-config.ps1**, after `if ($RepoPath) { Set-JValue $cfg $RepoPath @("repoPath") }` (:267): `Get-JText $old @("aiToolingRepoPath")`, `-creplace`, `$cfg.PSObject.Properties.Remove(...)`, and the same log line (E12).
- **Header follow-up.** Add "aiToolingRepoPath (legacy; migrated to repoPath and removed)" to the "Managed fields" header of both writers. Not drafted.

**Error-handling audit.** `cfg_get` already checks its rc and treats it as "absent". `del` is used only when the key exists. No new suppressions.

**Verification.**

- `bash -n` and the pwsh parser pass.
- `.scratch/session-rccode/test-legacy.sh` (isolated HOME; drafted setup-user-config.sh, bare run):
  - Only the legacy key: `repoPath: (unset) -> "/Users/x/repos/aitools"`, old key gone, unrelated key `keep` kept, 1 backup.
  - Both keys: repoPath kept, old key removed.
- tests/profile/test-config.sh on the copy: **190 passed, 0 failed**.
- Not run: setup-user-config.ps1 (OS guard, Windows only). The entry-point read fallback has no test. Suggested: a tests/logging/test-logging.sh pre-lib case (config.json with only aiToolingRepoPath gives the warning and an unchanged file hash).
- **Nit:** in `--dry-run` the log line reads "migrated ... and removed" although nothing is written.

## 6. Other disagreements found in the deployment area

1. **AnsA Q1 "Final text to apply" is false after 8e490d7.** The note says "Pre-push step 7 triggers only on the `shared/` ones ... does not trigger it". It is not applied on any branch (no grep hits on main and 8 open branches), and must not be applied as written. reference/pre-push-checklist.md:40 on main is correct.
2. **#106 PS1 relay summary-tool parity / duplicate rows.** See 3.1. INCIDENT. A fix is drafted and tested (hookin 39/39).
3. **Three exit-2 conventions across #106 and #115/#116.** See 3.1. INCIDENT (ambiguity) until the commander picks one.
4. **`deploy_abort` / `Invoke-DeployAbort` comments** say "abort ends the whole run, T-Q3". True for deploy-harness only (S3-AbortDocs already noted it; low).
5. **Packet section 4** lists "pre-push step 7 (dotprofile deploy/ stale)" as a known pre-existing failure. It is now a FAIL on **every** push (2.2), plus the structural branch FAIL (2.4). Delegates should record it, not chase it.
6. **Concurrent uncommitted edits in the main checkout** (see 2.3), including protected files (CLAUDE.md, .claude/rules/aitools-workspace.md, .cursor/rules/cross-platform.mdc). Not mine; S3-Reconcile should find out who owns them before committing from the main checkout (concurrent-agents.md).
7. **Stale deploy-paths.md (main :49-69)** still calls setup-user-claude "duplicated" and lists "`<userRepoPath>/claude/rules/*.md` -> read via `cat` at build time". S3-FanPlan-Claude already flags this (INCIDENT 1). Confirmed in the copy of the rule in my context.

## INCIDENT markers (not filed)

- INCIDENT: pre-push step 7 compares a build from the pushed branch with the dotprofile deploy/ built from main. Every branch that changes a deploy/ input (16 of 19 open PRs) FAILs by construction. check-pre-push.sh:160-169, .ps1:246-257. Medium.
- INCIDENT: PS1 passes `"harness files"` to `Invoke-ChildRelayed` (#106 aitools-install.ps1:196, aitools.ps1:196) while sh passes no tool. A throw gives two ERROR rows today, and after #115 an abort gives ERROR + WARN. Parity / spec deviation (interactive-menus "identical outcomes"). Medium.
- INCIDENT: exit 2 is reported three ways: ERROR `script failed (exit 2)` (#106 runners), ERROR `aborted (exit 2)` (#115 relay), WARN `aborted by user` (#106 deploy-harness). Ambiguity. Medium.
- INCIDENT: the JSON-field menu `[x]abort : stop the run` (aitools-lib.sh:2376, .ps1:2359) misstates the effect. Low (already flagged by S3-AbortDocs).
- INCIDENT: the user init auto-claim deviates from approved text (AnsB). Still open at 8e490d7 and on #113/#115/#116.
- INCIDENT: the entry points write config.json without backup or validation (aitools:1445-1469, aitools.ps1:444-464). Still open (AnsB).

## Open questions (with suggested answers)

1. Step 7 on PR branches (2.4): accept the structural FAIL, or apply the drafted WARN variant? **Suggested:** apply the variant. It keeps "always runs" and keeps FAIL for real problems. Also rebuild and commit the dotprofile deploy/ now (2.3).
2. Non-harness exit 2: WARN `aborted by user` instead of ERROR? **Suggested:** yes, applied in one rule across #106 runners, the #115 relay and #116 user init. Without it, keep ERROR everywhere and drop the relay's special `aborted (exit 2)` text.
3. Where does (i) the menu-text fix ship? **Suggested:** on #106, with its interactive-menus.md/.mdc text (it owns those docs). The lib lines conflict with no PR.
4. Item 4: does `--alias` naming an unowned profile prompt even though P-Q12 says "without a prompt"? **Suggested:** yes. The prompt appears only when the alias collides with an existing unowned profile; a new alias stays prompt-free. Update the :1357 comment accordingly.
5. Item 5: move into the writer, or delete? **Suggested:** move (5.2). Deleting alone makes bare setup-user-config runs ERROR on a legacy machine.

## Scratch and artifacts

**Verbatim drafts (tracked copy):** `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Code-drafts/`

- Each file holds `@@@FILE <base>/<file> <id>` / `@@@OLD` / `@@@NEW` / `@@@END` blocks with exact old/new text: edits-abort.txt E1-E6b, edits-claim.txt E7-E12, edits-step7.txt E13-E14, edits-relay.txt R1-R3, edits-test.txt T1-T2.
- `apply.pl EDITS BASEDIR OUTDIR` applies them. It fails unless each OLD occurs exactly once, and it converts to CRLF for a CRLF target.
- Base: `pr106/` = origin/feature/harness-hookin, `main/` = origin/main, `pr115/` = origin/fix/mf-lib-relay, `pr115/aitools-116` = #116's scripts/aitools.

Scratch, `/Users/new-jose/repos/aitools/.scratch/session-rccode/`:

- Scripts: refs.sh, item1-3c.sh, item6.sh, step7-sim.sh, step7-repro.sh, export.sh, apply.pl, syntax.sh, parse.ps1, mkcopy.sh, mkcopy106.sh, test-legacy.sh.
- Drafts: edits-abort.txt, edits-claim.txt, edits-step7.txt, edits-relay.txt, edits-test.txt.
- Outputs: out*/, repo-claim/, repo-106/, test-*.txt, s7/, s7b/.

The real dotprofile and the real HOME were never written; the builds and tests ran under scratch or mktemp HOMEs.

No WRITE_BLOCKED. No sub-delegates used.
