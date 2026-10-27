# S3-Reconcile-Fix-Code items: code-area INCIDENT markers, verified on origin/main 60e7fd7

Delegate S3-Reconcile-Fix-Code (level 3) for S3-Reconcile-Fix. Read-only on the repo. Base: origin/main 60e7fd7 (fetched 2026-10-26 at the start). The fetch before finishing moved main to 5f8edb4: #104 and #97 merged, docs only, no file under scripts/, tests/, shared/, reference/ or .claude/ changed, and every main draft re-applied cleanly on 5f8edb4. The other PRs (#98, #100, #102, #103, #106, #108-#116) are still open (`gh pr list -R nobul-tech/aitools --state all --limit 25`). Drafts: `S3-Reconcile-Fix-drafts/code/edits-*.txt` (format of `S3-Reconcile-Code-drafts/apply.pl`, repo-relative paths).

## Summary (5 lines)

1. 37 markers checked. 25 OPEN, each an FX item with a draft or a precise spec (#189 and #212 are part covered, part FX). 7 COVERED (R8c, R9, R10, FAN-PLAN A/B, MERGE-ALL, PR #103). 2 FIXED (4.4-b by #68 on main; #216 on open PR #111). 1 NOT A DEFICIENCY (by design). 2 UNVERIFIABLE (PS1 spinner input; #205 Cursor canary).
2. 51 verbatim OLD/NEW edits in 9 draft files. Every one applies once on origin/main, and the main drafts also apply on main merged with each of the 13 open code PRs, one at a time. `bash -n` and the pwsh 7.6.3 parser pass on every output. The repo's 10 suites give the same counts patched as unpatched (see the end). A patched build under an isolated HOME passes too: rc 0, 0 bash -n failures, 25/25 generated .ps1 parse.
3. Probes confirmed four bugs. #182: the AI merge reject reason is lost in `$(...)`. #217: a statement-terminating error inside the MDM deploy-harness.ps1 outer `try/finally` ends the run with rc 0 and skips the footer. After the fix it returns rc 1. M-1: assigning `$pid` kills the dashboard's own shell. #216: BUILD_TMP leaks; 16 dirs leaked in 40 minutes.
4. #211: the generated scripts were measured. 7 .ps1 files and 7 .sh files are over the limits (Intune: .ps1 200,000 B, .sh 1 MB). After #111, 6 .ps1 files are still over. #215: the library is carried twice in setup-user-claude/-cursor/-settings (inlined, plus the embedded resolver copy).
5. Decisions needed: #205 (the Cursor AGENTS.md mirror), #211 (WARN or FAIL), #215 (dedupe), #199 (environment credentials), #195 (bootstrap abort semantics), #183 (prompt change needs sample tests). Each has a suggested answer.

## Verification run (all under mktemp -d, isolated HOME; nothing against the real HOME)

- Applier: `bash .scratch/session-rcfixc/apply-all.sh <ref> <edits...>` (git archive of touched files only, apply.pl, `bash -n`, `pwsh -NoProfile -File .scratch/session-rcfixc/parse.ps1`).
  - origin/main: edits-lib 7/7, edits-entry 8/8, edits-installer 8/8, edits-relay-prompt 3/3, edits-harness 2/2, edits-build 4/4, edits-misc 16/16. All PASS.
  - origin/feature/harness-hookin: edits-pr106 2/2, plus edits-installer and edits-entry. PASS.
  - origin/feature/harness-mdm-followups: edits-pr111 1/1, plus edits-build. PASS.
- Main merged with each open code PR (`.scratch/session-rcfixc/apply-merged.sh`; one PR at a time: #98, #100, #103, #106, #108, #109, #110, #111, #112, #113, #114, #115, #116). Every main draft file applies: 13/13 PASS. Applied to the raw PR heads, edits-lib fails only because those heads predate 9923a3c (Backup-Dir `-LiteralPath`). It applies once they are merged with main. Not tested: all PRs merged together.
- Functional checks:
  - `.scratch/session-rcfixc/test-lib-drafts.sh`, run under /bin/bash 3.2: 5/5. That covers an .mdc-only dir being backed up, an empty dir not, prune to 5, the reason kept with the new form, and the reason lost with the old form (bug reproduced).
  - `test-lib-drafts.ps1`: 2/2.
  - `test-skip-parse.sh`: L193a extraction on a real blog_warn line.
  - `claude auth status --json` output matches the L199 regex (`"loggedIn": true`).
- Build under an isolated HOME (`build-iso.sh`, `build-iso2.sh`) with a temp clone of the dotprofile.
  - Baseline: rc 0.
  - With edits-build: rc 0, 0 bash -n failures, 25 .ps1 parse ok. Generated setup-user-skills.ps1 is byte-identical. setup-user-skills.sh differs only in the mktemp check. deploy-harness.ps1 differs only in the new catch.
- Suites on a clone with all main drafts overlaid, against an unpatched baseline (`suite.sh`): see "Suite results" at the end.

---

## 1. Ledger L2 (library and deploy code)

### #181: backup_dir / Backup-Dir back up a directory only when it holds `*.md`
- Source marker(s): S3-H-Cursor-handback.md:66; S3-Harness-handback.md:54 ("backup_dir ... only when it holds *.md").
- Status on origin/main 60e7fd7: OPEN. No open PR touches it.
- Evidence:
  - scripts/aitools-lib.sh:925 `file_count=$(find "$dir" -maxdepth 1 -name '*.md' -type f ...)`.
  - scripts/aitools-lib.ps1:820 `Get-ChildItem -LiteralPath $DirPath -Filter "*.md" -File`.
  - Callers: setup-user-cursor.sh:517 / .ps1:516 back up `~/.cursor/rules`, which holds `*.mdc` only. setup-user-claude.sh:335 / .ps1:363.
  - Also found: the bash prune loop `printf | while ... rm -rf` (sh:937-941) is unchecked and runs in a subshell. The PS prune `Remove-Item` (ps1:832) has no `-ErrorAction` and no check.
- Severity: medium.
- Fix: count any regular file, and check each prune with a WARN (bash: here-string loop so WARNINGS counts). Drafts `edits-lib.txt` L181a, L181b, L181c.
- Files: scripts/aitools-lib.sh, scripts/aitools-lib.ps1 (code; not protected).
- Gate: none.
- Verification:
  - apply PASS; `bash -n`; pwsh parser.
  - test-lib-drafts.sh: an .mdc-only dir is backed up, an empty dir is not, prune keeps 5.
  - test-lib-drafts.ps1: the same.
  - Suites: tests/managed-files, tests/rules-fanout-cursor.
- Decision needed: none.
- Note (pre-existing, not fixed here): the bash twin prunes by the name's timestamp (`sort -r`), the PS twin by LastWriteTime. The probe pruned a just-made real backup when older-named dirs were newer on disk. A same-second second backup copies into the existing `.bak.<ts>` dir. Both are low (INCIDENT below).

### #182: the bash AI merge runs invoke_ai inside `$(...)`, so AI_REJECT_REASON never reaches the caller
- Source marker(s): S3-SourceTruth-report.md:52.
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - scripts/aitools-lib.sh `_invoke_ai_merge` :1439 `merged=$(printf '%s' "$prompt_text" | invoke_ai balanced none _merge_validate 1) || true`, then :1448 `${AI_REJECT_REASON:-unknown error}`. A pipe member and a command substitution are both subshells.
  - Probe: the old form leaves AI_REJECT_REASON empty. The new form keeps "No AI CLI available (claude or agent)".
  - PS twin is fine (aitools-lib.ps1:1382 reads `$script:AIRejectReason`).
- Severity: low.
- Fix: run invoke_ai in the current shell, with stdin from a here-string and stdout to a mktemp file. A mktemp failure is reported as a failed merge. Draft L182.
- Files: scripts/aitools-lib.sh (code).
- Gate: none.
- Verification: apply PASS; `bash -n`; test-lib-drafts.sh cases 4-5; tests/managed-files suite.
- Decision needed: none.

### #183: the AI merge prompt labels its diff "local vs source"; bash feeds a SOURCE->LOCAL diff and PS1 an unordered Compare-Object listing
- Source marker(s): S3-DiffUX-handback.md:41-44.
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - Prompt text: aitools-lib.sh:1179 / .ps1:1123 `## Differences (unified diff: local vs source)`.
  - bash input: aitools-lib.sh:1673 `diff -u <(source) <(local) --label "source (would deploy)" --label "local (on disk)"` (`-` = source only).
  - PS input: aitools-lib.ps1:1629-1641 `Compare-Object $srcLines $curLines` (unordered, no context, `-` source / `+` local).
  - Both platforms already compute the identical LOCAL->SOURCE review diff for display: `_review_diff` (sh:1568) / `Get-ReviewDiff` (ps1:1504), git diff --no-index, identical hunks.
- Severity: medium.
- Fix (spec; a prompt change, so agentic-standards.md "Prompt evaluation" applies before shipping):
  - (1) In `prompt_diff_review` / `Prompt-DiffReview`, drop the `diff -u` / Compare-Object block. Pass the review diff (`$REVIEW_DIFF` / `$script:ReviewDiffLines -join "`n"`) to `_invoke_ai_merge` / `Invoke-AiMerge`.
  - (2) In `_ai_prompt_merge` and its PS twin, replace the heading with `## Differences (unified diff from LOCAL to SOURCE: lines starting "-" are only in LOCAL, "+" only in SOURCE)`. Rule 2 becomes `Apply ONLY the changes shown in the diff ("+" lines come from SOURCE)`.
  - (3) When the review diff is unavailable (`_review_diff` returned 1), do not offer `[m]erge` for that file. Log the reason.
  - Test: `.scratch` samples (one changed line, one added block, one local customisation that must survive) run through both twins. Validation passes. The two platforms send byte-identical prompts (log the prompt with `log_detail` in a test build).
- Files: scripts/aitools-lib.sh, scripts/aitools-lib.ps1 (code); reference/agentic-framework.md if it quotes the prompt (protected, docs sibling).
- Gate: none (prompt test first).
- Verification: the sample run above; `grep -c "local vs source" scripts/aitools-lib.*` = 0; tests/managed-files (its merge cases).
- Decision needed: none. The direction is forced by parity. Suggested: ship it with the sample-test evidence in the PR body.

### #186: the deploy tracker has no `removed` outcome
- Source marker(s): S3-H2-Cursor-handback.md:74.
- Status on origin/main 60e7fd7: COVERED (FAN-PLAN Batch A: plans/rules-fanout-claude.md:36, :73, :204-:300; `deploy_tracker_record removed`, DETAIL `removed: <name>`, unknown outcome -> log_error + counted `failed`).
- Evidence: no `removed)` branch in `deploy_tracker_record` on main (`git grep -n "removed)" origin/main -- scripts/aitools-lib.sh`: none).
- Severity: low.
- Fix: FAN-PLAN Batch A.
- Files: scripts/aitools-lib.sh/.ps1.
- Gate: FAN-PLAN batch merged (A).
- Verification: FAN-PLAN Batch A verification (plans/rules-fanout-claude.md:584-598).
- Decision needed: none. The glossary word "removed" is FAN-PLAN Q7.

### #187: deploy-harness add_source filters `*.bak.*` / `*.md` case-sensitively in bash, case-insensitively in PS1
- Source marker(s): S3-H2-Manifest-handback.md:95; S3-FanPlan-Lib-findings.md:397.
- Status on origin/main 60e7fd7: OPEN. It is FAN-PLAN follow-up F2 (plans/rules-fanout-claude.md:2490), not covered.
- Evidence:
  - scripts/deploy-harness.sh:26 header "compared case-insensitively"; :196-198 `case "$base" in *.bak.*)`; :206-208 `*.md)`.
  - deploy-harness.ps1:193 `-like '*.bak.*'`, :198 `-notlike '*.md'` (case-insensitive).
  - Same on #100 and #106 (the drafts apply on main+#100 and main+#106).
- Severity: low.
- Fix: bracket patterns (`*.[bB][aA][kK].*`, `*.[mM][dD]`). This is bash 3.2 safe, with no fork per file. Draft `edits-harness.txt` L187a, L187b. After FAN-PLAN Batch A lands, F2 may switch to `rule_name_kind` instead.
- Files: scripts/deploy-harness.sh (code). build-deploy extracts it, so the MDM copy follows on the next build.
- Gate: none.
- Verification:
  - apply PASS; `bash -n`; tests/deploy-harness, tests/deploy-harness-mdm (suite).
  - New case for tests/deploy-harness: source `X.MD` deployed and `a.BAK.1` skipped, on both twins.
- Decision needed: none.

### #188: a user abort (exit 2) is logged as "<label> failed (exit 2)" with an ERROR row
- Source marker(s): S3-H2-Hookin-handback.md:46; S3-AbortDocs-handback.md:61.
- Status on origin/main 60e7fd7: COVERED (R8c, gate Q6 = WARN; drafts E3a-c, E4a-b, E5, E6 in S3-Reconcile-Code-drafts/edits-abort.txt; relay R1/R1b/R2/R2b in edits-relay.txt).
- Evidence: the same as the Ledger (aitools-lib.sh:613 / .ps1:523 relay message).
- Severity: low.
- Fix: R8c.
- Files: per R8c.
- Gate: R8c merged (needs Q6).
- Verification: per R8c.
- Decision needed: Q6 (already in the plan).

### #189: "[x]abort : stop the run" menu text, and deploy_abort comments citing T-Q3
- Source marker(s): S3-AbortDocs-handback.md:55, :67-69.
- Status on origin/main 60e7fd7:
  - Menu text and the lib comment: COVERED (R8a1, drafts E1, E1b, E2, E2b). Main: aitools-lib.sh:2327, :2376; .ps1:2359.
  - The `deploy_abort` / `Invoke-DeployAbort` comments: NOT in edits-abort.txt (E3a/E4a only add a helper after them). They exist only on PR #106: origin/feature/harness-hookin:scripts/aitools:1093 and scripts/aitools.ps1:155, "(D-TS13; abort ends the whole run, T-Q3)". T-Q3 (plans/tool-support-and-machine-profile.md:100) answered "the whole run". The commander's 2026-10-26 decision keeps #106: only a deploy-harness exit 2 stops the run. So the comment reads as a rule it no longer is: FX.
- Severity: low.
- Fix: reword both comments. Draft `edits-pr106.txt` L189a, L189b (base origin/feature/harness-hookin; after #106 merges, the same OLD is on main).
- Files: scripts/aitools, scripts/aitools.ps1 (code).
- Gate: PR #106 merged (or apply on the #106 branch before it merges).
- Verification: apply PASS on the #106 head; `bash -n`; pwsh parser; `git grep -n "abort ends the whole run" -- scripts` = 0.
- Decision needed: none.

## 2. Ledger L3 (entry points, installer, user init)

### #191: `aitools user init` claims an unowned profile named by `--alias` without asking
- Status on origin/main 60e7fd7: COVERED (R9, drafts E7a, E7b, E8, T1, T2). Still OPEN on main: scripts/aitools:495 `extra+=(--claim "$okey"); mode=claim`.
- Severity: high. Gate: R9 merged (Q7). Decision needed: Q7 (in the plan).

### #192: the entry points rewrite config.json (aiToolingRepoPath -> repoPath) without backup or validation
- Status on origin/main 60e7fd7: COVERED (R10, drafts E9-E12). Still OPEN on main: scripts/aitools:1445-1456 (node `delete cfg.aiToolingRepoPath`), aitools.ps1:444-457.
- Severity: medium. Gate: R10 merged (Q8). Decision needed: Q8 (in the plan).

### #193: a skipped build-deploy (no node, no dotprofile, resolver error) prints OK "Rebuilt"
- Source marker(s): S3-AnsB-report.md:229.
- Status on origin/main 60e7fd7: OPEN. The same on #106, #111 and #112 heads.
- Evidence:
  - The build-deploy skips exit 0: build-deploy.sh:87-88 (no node), :206-207 (resolver error), :211-212 (no dotprofile), :215-216 (not a directory). Each message ends "skipping deploy build".
  - scripts/aitools:2055-2056 sends the output to LOG_FILE, then `log_ok "Rebuilt"`.
  - aitools.ps1:2010-2011 `if ($buildRc -eq 0) { LogOk "Rebuilt" }`.
- Severity: low.
- Fix: capture the build output. If it holds "skipping deploy build", write `log_warn "Deploy build skipped: <reason>"` and a WARN `deploy build` / `skipped (see deploy log)` row (24 chars). Otherwise `log_ok "Rebuilt"`. Drafts `edits-entry.txt` L193a, L193b.
- Files: scripts/aitools, scripts/aitools.ps1 (code).
- Gate: none.
- Verification:
  - apply PASS on main and on main+#106; `bash -n`; pwsh parser.
  - `test-skip-parse.sh`: the real line gives "No dotprofile found. Run 'aitools user init' first -- skipping deploy build."; a normal build gives no match.
  - Suggested test in tests/logging: run the entry point with PATH lacking node, and expect the WARN row.
- Decision needed: none. The match on the shared phrase "skipping deploy build" is a contract between two files. Suggested: add a comment at each of the four build-deploy sites, or a constant, in the same PR.

### #194: tool_exception_record / Set-ToolException header says exit 3 means "matched by hostname only or not at all"
- Source marker(s): S3-H2-DraftsM3-handback.md:66.
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - aitools-lib.sh:413-414, aitools-lib.ps1:345-346.
  - The real refusals are in aitools-profile.sh `cmd_exception_set` :1042-1071: no dotprofile, an AITOOLS_PROFILE_FILE snapshot, no profile for this machine, matched by hostname, matched by the config.json cache, or not registered to this machine.
- Severity: low.
- Fix: reword the comment. Drafts `edits-lib.txt` L194a, L194b.
- Files: scripts/aitools-lib.sh/.ps1 (code comments).
- Gate: none.
- Verification: apply PASS; `bash -n`; parser.
- Decision needed: none.

### #195: bootstrap.ps1 runs the installer with Windows PowerShell (`powershell`) and ignores its exit code
- Source marker(s): S3-GateFix-B-review.md:84 (GB-03).
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - scripts/bootstrap.ps1:48 `& powershell -NoProfile -ExecutionPolicy Bypass -File ...aitools-install.ps1`, with no `$LASTEXITCODE` check.
  - The installer never installs PowerShell 7 (no pwsh step in aitools-install.ps1; `git grep -n -i powershell` finds only :160, :417). So a plain switch to `pwsh` would fail on a fresh machine.
  - /tool-registry pwsh: `winget install --id Microsoft.PowerShell --source winget`, preferred (registries/tool-registry.json:515, read for research).
- Severity: medium.
- Fix: a step 1b in bootstrap.ps1 installs pwsh 7 through winget, the same pattern as git. Run the installer with `pwsh`. Check `$LASTEXITCODE` and print "Installer completed." / "Installer reported issues (exit N)", in parity with bootstrap.sh:76-80. Drafts `edits-installer.txt` L195a, L195b.
- Files: scripts/bootstrap.ps1 (code).
- Gate: none.
- Verification: apply PASS; pwsh parser. Not run: Windows (a fresh-VM run of `irm | iex` is the real test).
- Decision needed: on an installer exit 2 (user abort), should bootstrap skip `user init` + `aitools`? Suggested: no change now; keep parity with bootstrap.sh, which continues. File the abort handling of both bootstraps with R8c's follow-ups.

### #196: aitools.ps1 hardcodes one Git Bash path; setup-bash.ps1 probes three; none marked `# Verified:`
- Source marker(s): S3-GateFix-B-review.md:86 (GB-13).
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - scripts/aitools.ps1:1989 `$bashExe = "$env:ProgramFiles\Git\bin\bash.exe"`.
  - scripts/setup-bash.ps1:27-38 (three literal paths, `C:\Program Files...` hardcoded).
  - check-pre-push.ps1:127-131 is a third list (checks sibling).
- Severity: low.
- Fix: one lib helper, `Find-GitBash` in aitools-lib.ps1. It uses env-based paths, each marked `# UNVERIFIED` per script-standards "KnownPaths". aitools.ps1 and setup-bash.ps1 call it. Drafts `edits-lib.txt` L196a, `edits-entry.txt` L196b, L196c. check-pre-push.ps1 can switch to it (checks sibling).
- Files: scripts/aitools-lib.ps1, scripts/aitools.ps1, scripts/setup-bash.ps1 (code).
- Gate: none. Verification of the paths needs a Windows machine (then replace `# UNVERIFIED` with `# Verified: <date> (<version>)`).
- Verification: apply PASS; pwsh parser on all three. Not run: Windows.
- Decision needed: none.

### #198: the installer's `claude update` "up to date" match never fits the updater's text
- Source marker(s): S3-RegCC-report.md:68; S3-RegCC-Check-report.md:122.
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - aitools-install.sh:660 `grep -qi 'already.*up.to.date\|no update'`; aitools-install.ps1:583.
  - The live `~/.aitools/logs/deploy.log` has `[aitools-install] [info] Claude Code is up to date (2.1.185)` up to `(2.1.308)`, followed by "claude update finished" (grep this session).
- Severity: low.
- Fix: match `up[ -]to[ -]date|no update`. In bash use a here-string, not `printf | grep -q` (the #184 SIGPIPE family). Drafts L198a, L198b.
- Files: scripts/aitools-install.sh/.ps1 (code).
- Gate: none.
- Verification: apply PASS; `bash -n`; parser; after merge, an up-to-date run logs "Already up to date" (deploy.log).
- Decision needed: none.

### #199: installer Step 9 runs no Claude Code authentication check
- Source marker(s): S3-RegCC-report.md:72.
- Status on origin/main 60e7fd7: OPEN. Only `gh auth status` exists (aitools-install.sh:375, .ps1:281).
- Evidence:
  - /tool-registry claude-code `authentication.checkCommand` = `claude auth status --json`, field loggedIn. The logged-out exit code is unverified (registries/tool-registry.json, read for research).
  - Live output this session: `"loggedIn": true, "authMethod": "claude.ai", ...`.
- Severity: low.
- Fix: after Step 9, every run:
  - loggedIn true: detail only.
  - Environment credentials (ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN / CLAUDE_CODE_OAUTH_TOKEN): detail only.
  - loggedIn false: log_warn + WARN `not logged in` + ACTION `Run: claude auth login`.
  - Anything else: log_warn + WARN `auth status unknown` (exit code in the message, output to detail).
  - Drafts L199a, L199b.
- Files: scripts/aitools-install.sh/.ps1 (code).
- Gate: none.
- Verification: apply PASS; `bash -n`; parser; regex checked against the live JSON. Not run: a logged-out machine.
- Decision needed: should environment credentials count as signed in? Suggested: yes (registry `envOverride`). Otherwise an API-key user gets a WARN on every run. Note: the "unknown" branch writes the full JSON (it holds the email and org id) to the local deploy.log only. Suggested: acceptable (local log).

### #200: relay-outbound-prompt.sh uses a bare `read -r choice < /dev/tty`; the .ps1 twin uses Read-Host
- Source marker(s): S3-HooksFix-report.md:70; S3-Incidents-report.md:35.
- Status on origin/main 60e7fd7: OPEN in both twins.
- Evidence:
  - relay-outbound-prompt.sh:77.
  - Both callers call it in a condition (`scripts/aitools:2288 ... || return $?`, hh.sh:113 `... || exit $?`), so set -e does not fire today. EOF already falls to the default; the risk is a future unconditional caller.
  - relay-outbound-prompt.ps1:42 tests only `[Environment]::UserInteractive`, true in any console even with stdin redirected. :65 `Read-Host` goes against interactive-menus.md "Console I/O" (`[Console]::ReadLine()`).
- Severity: low.
- Fix: sh: `if ! read ...; then choice=""; ...` (EOF = continue). ps1: also treat `[Console]::IsInputRedirected` as non-interactive, and read with `[Console]::ReadLine()` ($null at EOF is handled at :66). Drafts `edits-relay-prompt.txt` L200a, L200b, L200c.
- Files: scripts/relay-outbound-prompt.sh/.ps1 (code).
- Gate: none.
- Verification: apply PASS; `bash -n`; parser; `printf '' | bash scripts/relay-outbound-prompt.sh <repo with dirty relay>` -> default continue, rc 0 (not run: needs a dirty relay in a temp repo).
- Decision needed: none. The rest of the .ps1 still uses Write-Host (interactive-menus "Console I/O"). Suggested: fix in the same PR if the reviewer asks; it is cosmetic.

## 3. Ledger L4/L5 code

### #205: the `~/.cursor/AGENTS.md` relay mirror appears never to be loaded by Cursor
- Source marker(s): S3-H-Cursor-handback.md:65; S3-Harness-handback.md:53.
- Status on origin/main 60e7fd7: UNVERIFIABLE here (needs the live Cursor canary; `agent login`).
- Evidence:
  - reference/tool-ops-cursor.md:30-44 (on main): Cursor 3.13.10 and CLI 2026.05.21 `loadRulesFromDirAndAncestors` load `<ancestor>/AGENTS.md`, that is `~/AGENTS.md`, not `~/.cursor/AGENTS.md`. :82-85 lists the mirror as a known gap and the "live canary not yet run".
  - Writers: scripts/aitools:1189-1207, aitools.ps1:206-248, aitools-install.sh:845-864, aitools-install.ps1:780-808.
- Severity: medium.
- Fix: decision first.
  - (a) Retire the mirror: delete the four writer blocks, keep the script, add a note.
  - (b) Write `~/AGENTS.md` instead. Every workspace under `~` loads it, and other AGENTS.md readers would see it too.
  - (c) Write the relay as a user rule `~/.cursor/rules/aitools-relay.mdc` (`description:` only, so the agent loads it when relevant). This fits the existing fan-out.
  - Test for any option: the tool-ops-cursor.md "Verification (manual canary)".
- Files: scripts/aitools, scripts/aitools.ps1, scripts/aitools-install.sh/.ps1, scripts/sync-relay-to-cursor-agents.py (code); reference/tool-ops-cursor.md (protected, docs).
- Gate: the canary run + commander decision.
- Verification: the canary: a Cursor agent in a workspace under `~` quotes a sentinel line from the relay.
- Decision needed: which option? Suggested: run the canary (it needs `agent login`, about 5 minutes of the commander's time). If it confirms the gap, take (c): one mechanism, the one the rules already use. Otherwise keep the mirror and close the item.

### #210: build-deploy embeds skills through unchecked heredocs
- Source marker(s): S3-H-MDM-handback.md:111.
- Status on origin/main 60e7fd7: OPEN for the skills embed. The setup-user-claude rules embed is already checked: it goes through `embed_file_bash` (delimiter check, CRLF->LF, one final newline; build-deploy.sh:460-472) and `embed_file_ps1` (a "|" prefix so no line can end the here-string; :474-481). FAN-PLAN Batch C removes that embed anyway.
- Evidence:
  - build-deploy.sh:1307 emits `_skill_tmp=$(mktemp -d)` (unchecked in the generated script).
  - :1313-1316 `cat "$_sfile"` between `<<'__SKILL_X__'` and the marker, with no delimiter check and no final-newline guarantee.
  - PS1 :1404-1406 `cat "$_sfile"` inside `@' ... '@`, with no check for a line starting `'@`.
  - The hooks embed guarantees the newline (:1504-1508, :1592-1597) but has no delimiter check (low).
- Severity: low.
- Fix: a delimiter / here-string-terminator check that fails the build, and one final newline. This is one perl per file with no pipe, so grep -q cannot SIGPIPE it. A checked mktemp in the generated script (ERROR rows `claude skills` / `cursor skills` `temp dir failed`). Drafts `edits-build.txt` L210a, L210b, L210c.
- Files: scripts/build-deploy.sh (code).
- Gate: none.
- Verification: apply PASS on main and #111; the build passes; generated setup-user-skills.ps1 byte-identical; setup-user-skills.sh differs only by the mktemp block.
  - Suggested tests/claude-mdm case: a skill with a line `'@` fails the build; a SKILL.md without a final newline builds and parses.
- Decision needed: none.

### #211: no size gate for generated deploy scripts
- Source marker(s): S3-MdmPkg-report.md:190; S3-H2-MDM-handback.md:77.
- Status on origin/main 60e7fd7: OPEN. PR #111 gates deploy-harness only (origin/feature/harness-mdm-followups:scripts/build-deploy.sh:2470-2490: .ps1 200000, .sh 1000000, "learn.microsoft.com, read 2026-10-22").
- Evidence. Measured this session: a build of main 60e7fd7 under an isolated HOME into a temp dotprofile copy, then `wc -c` on the final files (after the build's CRLF conversion of .ps1):

  | File | Bytes |
  |---|---|
  | deploy-harness.ps1 | 2,404,608 (payload; #111 moves it) |
  | deploy-harness.sh | 2,372,735 |
  | setup-user-claude.ps1 | 464,358 |
  | setup-user-cursor.ps1 | 434,225 |
  | setup-user-settings.ps1 | 409,729 |
  | setup-user-skills.ps1 | 357,415 |
  | setup-user-hooks.ps1 | 302,599 |
  | aitools-profile.ps1 | 231,769 |
  | setup-user-config.ps1 | 175,181 |

  Every other .ps1 is about 160 KB. Every .sh except deploy-harness.sh is under 1 MB (largest setup-user-claude.sh 431,588). So over the Intune .ps1 limit after #111: 6 files.
- Severity: medium.
- Fix: extend #111's check to every generated script, as a WARN, not a FAIL: the build would fail today, and the delivery route is undecided. Draft `edits-pr111.txt` L211 (base origin/feature/harness-mdm-followups, inserted before "# Swap the staged build in"). Reducing the sizes is #215, plus moving skills and hooks content to payload files like #111 did.
- Files: scripts/build-deploy.sh (code); .claude/rules/deploy-paths.md (protected, docs sibling) for the limits.
- Gate: PR #111 merged.
- Verification: apply PASS on the #111 head; `bash -n`; the build prints 6 WARN lines today.
- Decision needed: WARN or FAIL, and is the Intune per-script limit even the target, given the package path ships an Intune Win32 app (deploy-paths.md "Package path")? Suggested: WARN now. Decide FAIL only if the MDM per-script route stays supported after BUILD-PKG.

### #212 (code half): the dev-path deploy order differs between installer and sync loop; deploy-harness not run
- Source marker(s): S3-MdmPkg-report.md:193; S3-FanPlan-Install-findings.md:366-369.
- Status on origin/main 60e7fd7:
  - "deploy-harness not run": FIXED ON OPEN PR #106. origin/feature/harness-hookin:scripts/aitools:1121/:1174 put `deploy-harness.*` first in the loop; aitools-install.sh:669 runs `run_harness_step` (Step 8b).
  - README MDM order: COVERED (FAN-PLAN Batch C, "README MDM run order").
  - Order mismatch: OPEN, on main and on #106. Installer Step 21 is claude, cursor, mcp, skills, cursor-ide-mcp, settings, hooks (aitools-install.sh:833 / .ps1:760-768; #106 :866 / :783-791). The sync loop is claude, mcp, skills, cursor-ide-mcp, cursor, settings, hooks (scripts/aitools:1151, aitools.ps1:157).
- Severity: low (no known order dependency between setup-user-cursor and mcp/skills/cursor-ide-mcp).
- Fix: put the installer in the sync loop's order, with a "keep in step" comment. Drafts `edits-installer.txt` L212a, L212b (apply on main and main+#106).
- Files: scripts/aitools-install.sh/.ps1 (code).
- Gate: none (independent of #106).
- Verification: apply PASS on main and #106; `bash -n`; parser.
  - Suggested check-post-push step: the two lists (minus `setup-user-config` / `deploy-harness`) are equal in both languages.
- Decision needed: which order wins? Suggested: the sync loop's (it runs every day). Its single source of truth could later be one lib variable, but the entry points' self-update check compares the `local deploy_scripts=` line (scripts/aitools:2067), so keep the literal lists.

### #215: the library is embedded twice in the generated setup-user-claude, -cursor and -settings
- Source marker(s): S3-MdmPkg-report.md:191.
- Status on origin/main 60e7fd7: OPEN (by design of the M3 B5 resolver embed).
- Evidence:
  - The generated bash scripts hold 2 copies: `grep -c '^backup_dir() {'` style counts give 4 hits (2 functions x 2 copies) in setup-user-claude/-cursor/-settings.sh, against 2 in setup-uv.sh.
  - The .ps1 holds the inlined lib plus a "|"-prefixed embedded copy (`grep -c '^|function Backup-Dir {'` = 1).
  - Cause: build-deploy.sh:436 `RESOLVER_SH_FILES="aitools-profile.sh aitools-lib.sh aitools-json.pl"` is embedded as text (`embed_file_bash`, :509) so aitools-profile.sh can load the lib from its temp dir, and `inline_lib_*` also inlines the lib as code.
- Severity: low (about 140-150 KB per script; feeds #211).
- Fix (spec):
  - In the three resolver-consuming scripts, inline the lib by writing the embedded copy first, then `source "$_AITOOLS_EMBED_DIR/aitools-lib.sh"` / `. (Join-Path $env:AITOOLS_EMBED_DIR 'aitools-lib.ps1')` instead of `inline_lib_*`. One copy, as text.
  - The embed block must then run before `logging_init`. Today it runs after the inlined lib (build-deploy.sh:427-431).
  - Keep build-deploy's "embedded resolver exactly once" invariant (:2208-2216) and add "the lib exactly once".
- Files: scripts/build-deploy.sh (code).
- Gate: #111 merged (it reshapes deploy-harness embedding; avoid conflicts).
- Verification: generated sizes drop by about the lib size; tests/claude-mdm; check-pre-push step 7 smoke under an isolated HOME.
- Decision needed: worth doing before BUILD-PKG settles the MDM route? Suggested: defer. Do it only if the #211 decision keeps the per-script MDM route.

### #216: build-deploy's `trap 'rm -rf "$MDM_TMP"' EXIT` replaces the BUILD_TMP trap
- Status on origin/main 60e7fd7: FIXED ON OPEN PR #111. origin/feature/harness-mdm-followups:scripts/build-deploy.sh:1725-1727: `MDM_TMP="$BUILD_TMP/mdm"`, so there is no second trap.
- Evidence:
  - main build-deploy.sh:320 `trap _cleanup_build_tmp EXIT`, :1706 `trap 'rm -rf "$MDM_TMP"' EXIT`. The traps at :500/:515 are inside a generated-code BLOCK heredoc, not build-deploy's own.
  - Leak observed this session: 16 `build-deploy.*` dirs in $TMPDIR from the last 40 minutes of isolated builds and tests (`find $TMPDIR -maxdepth 1 -name 'build-deploy.*' -mmin -40`).
- Severity: low. Gate: PR #111 merged. Fix: none beyond #111. Verification: after #111, a build leaves no `build-deploy.*` dir.
- Decision needed: none.

### #217: in the generated deploy-harness.ps1, an uncaught error inside the outer `try { } finally { }` returns rc 0
- Source marker(s): S3-H2-MDM-handback.md:83 (feature/harness-mdm-followups).
- Status on origin/main 60e7fd7: OPEN, re-probed and confirmed. The same structure is on #111 (:2369 `} finally {`, no catch).
- Evidence:
  - The outer `try {` is emitted at build-deploy.sh:2107 and `} finally {` at :2196, with no catch. The exit footer is inside the try.
  - Minimal probe (pwsh 7.6.3, `-File`): a statement-terminating error (parameter binding `Join-Path $null`, a .NET `ReadAllText` exception) inside try/finally runs finally, then continues after the try statement, so the footer is skipped and rc is 0. `throw` and `-ErrorAction Stop` give rc 1.
  - Generated script (`probe-harness-tf.sh`; OS guard removed, error injected after the outer try, isolated HOME): `bind` rc 0 and `nonterm` rc 0, even though a LogError ("config.json not generated") had already counted an error. `throw` rc 1, `cmd` rc 1.
- Severity: medium (an MDM run can report success after a failure; marker said low).
- Fix: add `} catch { LogError "MDM: unexpected error -- run stopped: $_"; Write-Summary "ERROR" $tool "unexpected error"; exit 1 }` before the finally. Draft `edits-build.txt` L217 (the OLD is the same on main and #111).
- Files: scripts/build-deploy.sh (code).
- Gate: none (applies on main and #111).
- Verification:
  - After the patch, all four probe variants give rc 1 with "MDM: unexpected error -- run stopped: ...".
  - The generated diff is only the catch block; the build passes; 25 .ps1 parse.
  - Suggested tests/deploy-harness-mdm pwsh case: inject a binding error and expect rc 1.
- Decision needed: none.

## 4. Ledger 4.4 "Needs verification"

### 4.4-a: a user-created hook adopted to the dotprofile is never deployed by any path
- Source marker(s): S3-Incidents-report.md:36.
- Status on origin/main 60e7fd7: NOT A DEFICIENCY (by design).
- Evidence:
  - shared/rules/hook-lifecycle.md:82-83: "setup-user-hooks deploys and registers manifest hooks only. It never deploys or registers a user-created hook". :84-85 says to make it managed by moving it to `shared/hooks/`.
  - Code matches: setup-user-hooks.sh:208-245 (reverse discovery, `adopt_managed_file` into `$USER_REPO_PATH/claude/hooks/`); deploy-harness has no dotprofile hooks source (deploy-harness.sh:256-257).
- Severity: low (expectation only).
- Fix: optional wording. The prompt `[a]dopt to dotprofile` could say "(kept in the dotprofile; not deployed to other machines)". sh:226 and the .ps1 twin.
- Files: scripts/setup-user-hooks.sh/.ps1 (code, if taken).
- Gate: none.
- Verification: n/a.
- Decision needed: should adopted user hooks reach other machines? Suggested: no, keep SD-2 (the commander's rule). Take the one-line wording change only.

### 4.4-b: setup-user-skills adopts a shared skill into a dotprofile fork
- Source marker(s): S3-SpecRewrite-report.md:50.
- Status on origin/main 60e7fd7: FIXED (PR #68, 1d67da9).
- Evidence: setup-user-skills.sh:122-124 "Adopt target: the file actually read (the dotprofile copy when that was the source, else shared/skills in the aitools repo)", `deploy_managed_file ... "$src"`; .ps1:118 `-AdoptPath $src`. `git log -S` gives 1d67da9.
- Severity: n/a. Fix: none. Verification: tests/managed-files. Decision needed: none.

### 4.4-c: PS1 console input corrupted after Start-AiSpinner's job
- Source marker(s): S3-SourceTruth-report.md:60.
- Status on origin/main 60e7fd7: UNVERIFIABLE (needs a pty; none in this run).
- Evidence:
  - aitools-lib.ps1:1271-1284. `Start-AiSpinner` runs `Start-Job`: an out-of-process pwsh whose stdio is the job's IPC channel. It calls `[Console]::Write` in a loop.
  - `Stop-AiSpinner` (:1286-1294) stops and removes it with SilentlyContinue.
  - Whether the job's console writes reach the parent's terminal, or disturb the next `[Console]::ReadLine()`, is unknown.
- Severity: low.
- Fix (spec, if confirmed): use `Start-ThreadJob` (in-process, shares the console) or drop the spinner in favour of a single "merging..." line.
- Files: scripts/aitools-lib.ps1.
- Gate: a pty probe (tests/managed-files/pty-run.py can drive pwsh: run an AI merge with a stub `claude`, then answer the next prompt).
- Verification: the pty probe.
- Decision needed: none.

## 5. Plan section 8 code items, Git/Docs findings

### N-Q2 / plan Q12: deploy-harness adopts into the dotprofile are not committed and pushed
- Status on origin/main 60e7fd7: COVERED by open PR #103 (fix/mf-dotprofile-adopt-push).
- Evidence:
  - The commit/push is in the library, not in setup-user-claude: origin/fix/mf-dotprofile-adopt-push:scripts/aitools-lib.sh:1105-1119 `_managed_adopt_notice` calls `dotprofile_commit_push "$target" ...` after every adopt or merge (ps1:1023-1029).
  - Whether a target is in the dotprofile is decided by git top level against the resolver's dotprofile (sh:1005-1060).
  - deploy-harness adopts through `deploy_managed_file` with `ADOPT_PATH` = the source file (deploy-harness.sh:300-320), so a dotprofile rules adopt is committed and pushed once #103 merges.
  - #103's tests cover setup-user-claude only (tests/managed-files/test-adopt-push.sh/.ps1).
- Severity: medium.
- Fix: none beyond #103. Add a test: a tests/deploy-harness case where a dotprofile rule (temp git repo with a bare remote) is adopted -> one commit on the remote.
- Files: tests/deploy-harness/test-deploy-harness.sh (checks sibling's area).
- Gate: PR #103 merged.
- Verification: the new test case.
- Decision needed: none. Commander 2026-10-26: "dotprofile pushes from a non-main branch are an ERROR". #103's behaviour there is the MERGE-ALL / #102-#165 item, not re-checked here.

### `--skip-config` (#111) not passed by #106 Step 8b
- Status on origin/main 60e7fd7: COVERED by MERGE-ALL (S3-MA-Brief-brief.md:83 "Small follow-ups -- #111's `--skip-config` in installer Step 8b", :182, :201).
- Gate: MERGE-ALL follow-up. Decision needed: none.

## 6. FAN-PLAN report markers, code side

### ADOPT_TRANSFORM (spec) vs ADOPT_FILTER (code)
- Source marker(s): S3-FanPlan-report.md:125.
- Status on origin/main 60e7fd7: OPEN (spec side).
- Evidence:
  - Code: aitools-lib.sh:1780-1783 `$6 = ADOPT_FILTER` (a function name; positional), aitools-lib.ps1:1745, :1762 `-AdoptFilter`. Callers: setup-user-claude.sh:181, .ps1:188-262.
  - Spec: reference/managed-file-deployment.md:49-50 "reads ADOPT_TRANSFORM when set", :59 `[-AdoptTransform]`, :69-72, :330-331; .claude/rules/managed-file-deployment.md:37-38.
- Severity: low.
- Fix: the spec changes. The code is shipped, has parity and is tested. Draft text (protected, for the docs sibling / R2c, which edits the same reference file):
  - reference/managed-file-deployment.md:49-50: OLD `deploy_managed_file SRC_CONTENT DEST TOOL_NAME ITEM_NAME [ADOPT_PATH]\n    reads ADOPT_TRANSFORM when set; sets MANAGED_FILE_RESULT` NEW `deploy_managed_file SRC_CONTENT DEST TOOL_NAME ITEM_NAME [ADOPT_PATH] [ADOPT_FILTER]\n    sets MANAGED_FILE_RESULT`.
  - :59: `[-AdoptTransform]` -> `[-AdoptFilter]`.
  - :69-72: OLD `` `ADOPT_TRANSFORM` (bash, a function name, optional) / `-AdoptTransform` (PS1, a scriptblock, optional) turns LOCAL content into adopt-target content before the write `` NEW `` `ADOPT_FILTER` (bash, the 6th argument: a function name that reads LOCAL on stdin and prints the adopt-target content; optional, text files only) / `-AdoptFilter` (PS1, a scriptblock; optional) turns LOCAL content into adopt-target content before the write ``.
  - :330-331: `ADOPT_TRANSFORM` -> `ADOPT_FILTER`, `-AdoptTransform` -> `-AdoptFilter`.
  - .claude/rules/managed-file-deployment.md:37-38: `(\`ADOPT_TRANSFORM\` /\n\`-AdoptTransform\`; today \`adopt_claude_md\`)` -> `(\`ADOPT_FILTER\` /\n\`-AdoptFilter\`; today \`claude_md_adopt_filter\` / \`$claudeMdAdoptFilter\`)`. `adopt_claude_md` no longer exists: `git grep -n adopt_claude_md origin/main -- scripts` finds nothing, and the function is setup-user-claude.sh:187 `claude_md_adopt_filter`, .ps1:194 `$claudeMdAdoptFilter`. So the reference file's "today's logic is `adopt_claude_md`" (:331) is stale too.
- Files: reference/managed-file-deployment.md (protected), .claude/rules/managed-file-deployment.md (protected), .cursor/rules/managed-file-deployment.mdc if it has the term (docs).
- Gate: R2c merged (same file), G-P.
- Verification: `git grep -n -e ADOPT_TRANSFORM -e AdoptTransform -- reference .claude .cursor` = 0.
- Decision needed: none (spec follows code). Hand to S3-Reconcile-Fix-Docs.

### setup-user-hooks writes settings.json without a backup
- Source marker(s): S3-FanPlan-Install-findings.md:445-452, :552-555.
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - setup-user-hooks.sh:383 `fs.writeFileSync(settingsFile, newJson)` inside node, with no `backup_file`.
  - setup-user-hooks.ps1:376 `[System.IO.File]::WriteAllText(...)`, with no `Backup-File`.
  - config-file-safety.md "Backup before overwrite": the JSON caller MUST back up.
- Severity: medium.
- Fix:
  - PS1: `Backup-File -FilePath $settingsFile` right before the write, only on a change. Draft `edits-misc.txt` M-hooks-a.
  - bash (spec; node owns the write today): follow the reference writer setup-user-config.sh ("merge to temp -> validate -> backup_file -> mv", :26, :341). node writes `newJson` to a temp path given as argv[5], validates the temp file, and prints `changed`. bash then runs `backup_file "$SETTINGS_FILE"` and `mv` temp -> settings.json (check rc: log_error + ERROR row), and handles `changed` like `ok` in the status case.
  - Quick alternative: `backup_file "$SETTINGS_FILE"` before the node call when not dry-run. Simpler, but it adds a backup on every run (pruned to 20).
- Files: scripts/setup-user-hooks.sh/.ps1 (code). The merge is extracted by build-deploy (deploy-paths.md "settings.json hooks merge itself is extracted"), so the MDM copy follows on the next build.
- Gate: none.
- Verification: PS draft apply PASS + parser; tests/managed-files or a new case: settings.json changes -> one `settings.json.bak.*`; unchanged -> none.
- Decision needed: bash option? Suggested: the temp-file option (parity with the PS twin: back up only on change).

### setup-user-shell ignores dry-run
- Source marker(s): S3-FanPlan-Install-findings.md:514-520, :562-565.
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - Neither setup-user-shell.sh nor .ps1 reads `AITOOLS_DRY_RUN` or a flag (sh:25-108; ps1 whole file).
  - The installer exports `AITOOLS_DRY_RUN=1` (aitools-install.sh:129) before Step 7.
  - The sh writes `~/.bash_profile` and the ps1 writes `$PROFILE` unconditionally, and the ps1 creates the profile directory.
- Severity: medium.
- Fix: the `--dry-run` / `-DryRun` + env convention of setup-user-hooks. In dry run, log "Would add/refresh the managed block in <profile>", write OK `shell` `dry run (no files written)`, exit 0, before any backup, mkdir or write. Drafts `edits-misc.txt` M-shell-a..d.
- Files: scripts/setup-user-shell.sh/.ps1 (code; copied as-is into deploy/ by build-deploy.sh:1179-1194).
- Gate: none.
- Verification: apply PASS; `bash -n`; parser; `AITOOLS_DRY_RUN=1 AITOOLS_PROFILE_DIR=<tmp> bash scripts/setup-user-shell.sh` -> no file in <tmp>, OK row (not run).
- Decision needed: none.

### aitools-dashboard.ps1 assigns to `$pid`
- Source marker(s): S3-FanPlan-Misc-findings.md:173 (M-1).
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - aitools-dashboard.ps1:379 `$pid = Get-PortServerPid -PortNum $Port`, :382 `Stop-Process -Id $pid`.
  - Probe this session: `$pid = 5` gives "Cannot overwrite variable PID because it is read-only or constant." `$pid` stays the script's own process id, so `-Stop` kills its own shell.
  - :533 reads `$PID` on purpose (fine).
- Severity: high (on Windows the stop command never stops the dashboard and kills the caller's process).
- Fix: rename to `$serverPid`. `Stop-Process -ErrorAction Stop` and `Remove-Item -LiteralPath -ErrorAction Stop` each get a try/catch with LogWarn (replacing the empty `catch {}`). LogOk only when stopped. Draft `edits-misc.txt` M1.
- Files: scripts/aitools-dashboard.ps1 (code).
- Gate: none.
- Verification: apply PASS; parser; `git grep -n '\$pid =' -- scripts/aitools-dashboard.ps1` = 0. Not run: Windows.
- Decision needed: none. The file's other empty catches and unchecked SilentlyContinue (M-4) are not in this item.

### `AITOOLS_DEPLOY_IN_PROGRESS` guard inactive
- Source marker(s): S3-FanPlan-Misc-findings.md:174 (M-2); S3-FanPlan-Install-findings.md:370-371 (AITOOLS_DEPLOY is dead).
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - scripts/ait-harvest.py:44, :1001-1003 read `AITOOLS_DEPLOY_IN_PROGRESS`; no script sets it (`git grep` over scripts, shared, tests).
  - The entry points export `AITOOLS_DEPLOY=1` (scripts/aitools:1099, :1215 unset; aitools.ps1:159, :209), which nothing reads.
  - FEATURE "catch-up skips its sweep during a deploy" IS CURRENTLY INACTIVE.
- Severity: medium.
- Fix: rename the entry points' variable to `AITOOLS_DEPLOY_IN_PROGRESS`, which activates the guard and drops the dead name. Drafts `edits-entry.txt` M2a..d.
  - The case the guard covers: a SessionStart hook in an AI merge's `claude -p` child. Whether hooks fire in `claude -p --no-session-persistence` is UNVERIFIED.
  - Optional: the installers' Step 21 export it too.
- Files: scripts/aitools, scripts/aitools.ps1 (code).
- Gate: none.
- Verification: apply PASS (main, main+#106); `bash -n`; parser; `git grep -n "AITOOLS_DEPLOY\b" -- scripts` = 0 (only `_IN_PROGRESS` left).
- Decision needed: should the installers set it too? Suggested: yes, in the same PR (2 lines each). Not drafted, because the installer drafts are already large.

### setup-cursor-ide-mcp sh/ps1 diverge
- Source marker(s): S3-FanPlan-Misc-findings.md:175 (M-3).
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - The .sh removes vercel/webflow with `agent mcp remove` and a WARN on failure (setup-cursor-ide-mcp.sh:189-204).
  - The .ps1 calls `agent mcp disable` (no longer a CLI verb, per the .sh comment :190-193) and writes an ERROR row on failure (.ps1:166-178).
  - Both headers say "disabled via `agent mcp disable`" (.sh:9, .ps1:8).
  - The .ps1 WriteAllText (:133) is unchecked. A validation LogError (:137-145) is followed by OK "updated" (:162).
  - Both exit 1 without a summary row when node is missing (.sh:51-53, .ps1:37-39).
- Severity: medium.
- Fix: port the .sh remove loop to the .ps1. Check the write. ERROR row `write or validation failed` when the error count rose, else OK `updated`. ERROR `node not found` before both exits. Fix both headers. Drafts `edits-misc.txt` M3a..M3g.
- Files: scripts/setup-cursor-ide-mcp.sh/.ps1 (code; build-deploy copies both whole).
- Gate: none.
- Verification: apply PASS; `bash -n`; parser. Not run: Windows, `agent` CLI.
- Decision needed: the .sh design itself may churn. The script writes vercel/webflow into `~/.cursor/mcp.json`, then `agent mcp remove` may delete them from the same file, so every run re-adds them (MCP_CHANGED + the "Restart Cursor" ACTION every run). UNVERIFIED: which file `agent mcp remove` edits. Suggested: before shipping, run `agent mcp remove vercel` once on a scratch HOME and diff `~/.cursor/mcp.json`. If it edits that file, stop writing vercel/webflow there and drop the remove step.

### setup-user-skills duplicate-name check is case-sensitive in bash, case-insensitive in PS1
- Source marker(s): S3-FanPlan-Install-findings.md:469-476, :566-568.
- Status on origin/main 60e7fd7: OPEN.
- Evidence:
  - setup-user-skills.sh:89-92 `case " $SKILL_NAMES " in *" $skill_name "*)`.
  - setup-user-skills.ps1:77 `$skillDir.Name -notin $skillNames` (case-insensitive).
  - On APFS a dotprofile `Foo` and a shared `foo` are one directory, but bash lists both and deploys twice.
- Severity: low.
- Fix: a parallel lower-cased list (`tr`; skill names are ASCII). Drafts `edits-misc.txt` M-skills-a..c. The resolver-error row parity gap (sh:59-60 two rows vs ps1:51 one row) is a separate low item: INCIDENT below.
- Files: scripts/setup-user-skills.sh (code).
- Gate: none.
- Verification: apply PASS; `bash -n`; suggested test: shared `foo` + dotprofile `Foo` -> one deploy, dotprofile wins (sh:110).
- Decision needed: none.

### setup-user-claude rules filter case parity
- Status on origin/main 60e7fd7: COVERED (FAN-PLAN Batch B: `rule_name_kind` case-insensitive, plans/rules-fanout-claude.md:47 D1, :71, :933).
- Gate: FAN-PLAN B merged. Decision needed: none.

### Cursor fan-out is case-sensitive in both languages (F1)
- Source marker(s): S3-FanPlan-report.md:114.
- Status on origin/main 60e7fd7: OPEN (FAN-PLAN follow-up F1, not covered). The same on #110.
- Evidence:
  - setup-user-cursor.sh:494-495 `*.bak.*) continue ;; *.md) ;;` (case-sensitive).
  - setup-user-cursor.ps1:496-497 `-clike "*.bak.*"`, `-clike "*.md"` (case-sensitive on purpose).
  - #110: setup-user-cursor.sh:630-631, .ps1:520, :608-609 unchanged in kind.
  - The approved filter is case-insensitive (D1, plans/rules-fanout-claude.md:47).
- Severity: low.
- Fix (spec, F1): after #110 and FAN-PLAN Batch A merge, replace the two filters in both twins with `rule_name_kind "$name"` / `Get-RuleNameKind -Name` (`hidden` / `backup` / `rule` / `other`). Delete setup-user-cursor's own `lower_name`, `in_list`, `read_rules_manifest`, `Read-RulesManifest` copies (Batch A's lib copies are byte-identical). Keep the case-insensitive duplicate handling it already has (sh:541, :596).
- Files: scripts/setup-user-cursor.sh/.ps1 (code).
- Gate: PR #110 + FAN-PLAN Batch A merged.
- Verification: tests/rules-fanout-cursor (+ cases `UP.MD` fanned out, `x.BAK.1` skipped); F6 puts that suite in CI.
- Decision needed: none.

---

## Not verified

- Windows: every `.ps1` change was parse-checked on macOS pwsh 7.6.3 only. Not tested on Windows: Find-GitBash paths, bootstrap.ps1 on a fresh VM, the dashboard `-Stop`, setup-cursor-ide-mcp with `agent`, setup-user-shell.ps1 dry run.
- Linux: not run.
- #205 Cursor canary (needs `agent login`); 4.4-c pty probe.
- Whether SessionStart hooks fire inside `claude -p --no-session-persistence` (the M-2 guard's case).
- Which file `agent mcp remove` edits (M-3 decision).
- All open PRs merged together (each was tested only alone on main).
- `claude auth status --json` on a logged-out machine; its exit code there.
- #183's prompt change (spec only; needs sample tests).

## INCIDENT markers (new; for the FX list upstream)

- INCIDENT: Backup-Dir prunes by LastWriteTime, backup_dir by the name's timestamp. A second backup in the same second copies into the existing `.bak.<ts>` dir (`cp -R` onto an existing dir; probe test-lib-drafts.sh/.ps1). Low.
- INCIDENT: any `try { ... } finally { ... }` without a catch whose try holds the exit footer, or later must-run code, can end silently with rc 0 on a statement-terminating error. It is confirmed for the MDM deploy-harness.ps1 (#217). An audit of the others is not done: aitools.ps1 build env try/finally (:2002-2008) and the lib's try/finally blocks. Low-medium.
- INCIDENT: setup-cursor-ide-mcp.sh may churn mcp.json every run. It writes vercel/webflow, then `agent mcp remove` (UNVERIFIED which file it edits). Medium if confirmed.
- INCIDENT: setup-user-skills resolver-error rows differ: sh:59-60 two rows `claude skills` / `cursor skills`, ps1:51 one row `skills` "skipped (dotprofile error)". Low (from S3-FanPlan-Install-findings.md:477-483, re-read on main).
- INCIDENT: `printf '%s\n' "$X" | grep -q ...` under pipefail remains in about 10 setup scripts (setup-gh-cli.sh:73, setup-go.sh:51, setup-pandoc.sh:64, setup-typst.sh:62, setup-uv.sh:30, setup-vercelcli.sh:75, setup-datadog.sh:57 and others). This is the Ledger #184 family; the audit has not been done. Low.
- INCIDENT (tooling): this delegate had no Grep/Glob tool (#51 recurrence). My own isolated builds and tests leaked about 16 `build-deploy.*` dirs into $TMPDIR (#216). They were left in place, not deleted.

## Open questions (each with a suggested answer)

1. #205: retire, move to `~/AGENTS.md`, or convert to a Cursor user rule? Suggested: run the canary, then convert to `~/.cursor/rules/aitools-relay.mdc`.
2. #211: WARN or FAIL for oversized generated scripts? Suggested: WARN until BUILD-PKG decides whether the per-script MDM route stays.
3. #215: dedupe the lib now? Suggested: defer, tied to question 2.
4. #199: environment credentials count as signed in? Suggested: yes.
5. #195: should bootstrap stop on an installer abort (exit 2)? Suggested: not now; parity with bootstrap.sh, review with R8c's follow-ups.
6. M-2: installers also export AITOOLS_DEPLOY_IN_PROGRESS? Suggested: yes, same PR.
7. setup-user-hooks bash backup: temp-file write, or backup on every run? Suggested: temp-file write (back up only on change).
8. #212: which deploy order? Suggested: the `aitools` sync loop's.
9. PR packaging. Suggested:
   - `fix/lib-backup-merge-reason`: edits-lib L181/L182/L194.
   - `fix/entry-build-skip-guard`: L193, M2.
   - `fix/git-bash-lookup`: L196, so the Windows verification is one PR.
   - `fix/installer-claude-step9`: L198, L199, L212.
   - `fix/bootstrap-pwsh`: L195.
   - `fix/relay-prompt-eof`: L200.
   - `fix/harness-case-filter`: L187.
   - `fix/build-embed-checks`: L210, L217.
   - `fix/misc-parity`: M1, M-shell, M3, M-skills, M-hooks; split M3 out if the churn question needs a probe first.
   - #189 and #211 on #106 / #111 or right after them.
   Each PR is 2-3 files (UCI smaller batches).

## Suite results

`.scratch/session-rcfixc/suite.sh` and `ps-suites.sh`: a local clone at origin/main 60e7fd7, the build under an isolated HOME into a temp dotprofile copy, then each suite with HOME set to a temp dir. "Patched" overlays every main draft except L212a/b, which were added afterwards; they only reorder one list and pass apply, `bash -n` and the parser. Results are identical:

| Suite | Baseline | Patched |
|---|---|---|
| build-deploy (isolated) | rc 0; gen bash -n 0 fail; 25 .ps1 parse | rc 0; gen bash -n 0 fail; 25 .ps1 parse |
| tests/managed-files/test-managed-files.sh | 57 passed, 0 failed | 57 passed, 0 failed |
| tests/managed-files/test-managed-files.ps1 | 39 passed, 0 failed | 39 passed, 0 failed |
| tests/profile/test-lib.sh | 209 / 0 | 209 / 0 |
| tests/profile/test-config.sh | 190 / 0 | 190 / 0 |
| tests/profile/test-user-init.sh | 200 / 0 | 200 / 0 |
| tests/logging/test-logging.sh | 24 / 0 | 24 / 0 |
| tests/logging/test-logging.ps1 | 15 / 0 (5 skipped) | 15 / 0 (5 skipped) |
| tests/deploy-harness/test-deploy-harness.sh | 45 / 0 | 45 / 0 |
| tests/deploy-harness-mdm/test-deploy-harness-mdm.sh | 30 / 0 | 30 / 0 |
| tests/rules-fanout-cursor/test-rules-fanout-cursor.sh | 78 / 0 (1 skipped) | 78 / 0 (1 skipped) |

No existing case exercises the changed behaviour directly. The functional evidence is the probes and the scratch tests above; each item names the test to add.

Final fetch (before finishing): origin/main moved 60e7fd7 -> 5f8edb4. The new commits are the #104 and #97 merges, docs only: `git diff --stat 60e7fd7 5f8edb4 -- scripts tests shared reference .claude` is empty. All 7 main draft files re-applied on 5f8edb4: PASS.

## Scratch and temp

Scratch scripts: /Users/new-jose/repos/aitools/.scratch/session-rcfixc/ (build-iso.sh, build-iso2.sh, apply-all.sh, apply-prs.sh, apply-merged.sh, parse.ps1, probe-tf.sh, probe-tf2.sh, probe-harness-tf.sh, test-lib-drafts.sh/.ps1, test-skip-parse.sh, suite.sh, ps-suites.sh). Temp dirs: /tmp/rcfixc-* (outside the repo; left in place).
