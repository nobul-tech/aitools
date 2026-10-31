# S3-FanPlan-Misc findings: the remaining scripts and the rules fan-out

Written by S3-FanPlan-Misc (explorer, level 2, delegated by S3-FanPlan), 2026-10-26.
Reading copy: `/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/` (origin/main 480b901).
Read only. No code changed, no setup script run. One probe: `pwsh -NoProfile -Command '$pid = 5'`
(no file or HOME touched), for INCIDENT M-1.

## 1. Summary

1. No file in this slice reads or writes `~/.claude/rules`, `~/.aitools/rules`, dotprofile `claude/rules`, `shared/rules` or the rules manifest. The only "rules" hits are comments (ait-harvest.py:893, 1021; aitools-json.ps1:124) and a knowledge-item type label (harness-db.py:300, 2740).
2. The one real coupling is `aitools-profile.sh/.ps1` (plus its engine `aitools-json.pl/.ps1`). It is the dotprofile resolver behind `resolve_user_repo_path` / `Resolve-UserRepoPath`, and that gives setup-user-claude the `USER_REPO_PATH` its rules loop reads and adopts into (setup-user-claude.sh:72-73, 350-351). The generated `deploy/setup-user-claude.*` embeds a copy of it (build-deploy.sh:436-457). The refactor needs no edit in the resolver. It does need to keep the resolver embedded, because CLAUDE.md and identity still depend on it.
3. Cross-slice risk: deploy-harness finds the dotprofile through `config.json userRepoPath` only (deploy-harness.sh:122). It does not use the resolver. The resolver deliberately does not save an `AITOOLS_USER_REPO_PATH` override to config.json (aitools-profile.sh:1157-1160). Once rules come only from the fan-out, a run with `AITOOLS_USER_REPO_PATH` set (tests, MDM, build-deploy under Git Bash) can deploy CLAUDE.md from one dotprofile and rules from another, or from none.
4. The conventions the refactor must keep consistent are: `write_summary` rows with canonical tool names; the library-style resolver contract (it returns warn/error lines, and the caller owns the rows); no pass-through of exit 2; and the hardened dotprofile commit+push in `commit_profile` (N-Q2), which is stricter than setup-user-claude's inline rule push. No file in the slice uses `deploy_tracker_*`. Open PRs #105, #108 and #114 touch the resolver and engine, but none of their hunks touch rules.
5. INCIDENT markers, none blocking: `aitools-dashboard.ps1 -Stop` assigns to the read-only `$PID` and then kills its own process (M-1, confirmed by probe); ait-harvest's `AITOOLS_DEPLOY_IN_PROGRESS` guard is dead (M-2); setup-cursor-ide-mcp diverges between .sh and .ps1 (M-3); minor items M-4..M-7.

## 2. Files read in full

Every file was read in full with Read (offset/limit for files over 1,000 lines). Line counts come from `git ls-files -z scripts | xargs -0 wc -l` in the worktree.

| File | Lines | Read fully | Rules dependency | Evidence |
|---|---|---|---|---|
| scripts/aitools-profile.sh | 1563 | y | indirect (dotprofile resolver) | Consumers named in the header, :14-19; dotprofile order, :419-473; env override not persisted, :1157-1160 |
| scripts/aitools-profile.ps1 | 1379 | y | indirect (same, Windows) | :13-16, :333-386, :1007-1010 |
| scripts/aitools-json.pl | 311 | y | n | JSON engine only. Consumed by aitools-profile.sh and setup-user-config.sh (:10-11) |
| scripts/aitools-json.ps1 | 175 | y | n | Same, PowerShell (:8-9); "rules" at :124 means rename rules |
| scripts/setup-bash.sh / .ps1 | 139 / 88 | y / y | n | No .claude/.aitools/rules reference (grep, section 3.1) |
| scripts/setup-perl.sh / .ps1 | 119 / 98 | y / y | n | same |
| scripts/setup-python.sh / .ps1 | 112 / 115 | y / y | n | same |
| scripts/setup-uv.sh / .ps1 | 100 / 90 | y / y | n | same |
| scripts/setup-go.sh / .ps1 | 138 / 153 | y / y | n | same |
| scripts/setup-rust.sh / .ps1 | 94 / 154 | y / y | n | same |
| scripts/setup-typst.sh / .ps1 | 116 / 119 | y / y | n | same |
| scripts/setup-pandoc.sh / .ps1 | 182 / 100 | y / y | n | same |
| scripts/setup-gh-cli.sh / .ps1 | 167 / 88 | y / y | n | same |
| scripts/setup-vercelcli.sh / .ps1 | 190 / 116 | y / y | n | same |
| scripts/setup-modal.sh / .ps1 | 170 / 216 | y / y | n | same |
| scripts/setup-datadog.sh / .ps1 | 202 / 170 | y / y | n | same |
| scripts/setup-google-chrome.sh / .ps1 | 416 / 33 | y / y | n | same (`$HOME/.pki/nssdb` only) |
| scripts/setup-cursor-ide-mcp.sh / .ps1 | 226 / 200 | y / y | n | Only `~/.cursor/mcp.json`; `~/.claude.json` appears in a comment (:12 / :11) |
| scripts/ait-harvest.py | 1260 | y | n | Reads `~/.claude/projects/*/*.jsonl` (:1059-1066) and `config.json userRepoPath` (:197-231); writes dotprofile `sessions/`, `harvesting/`, `.aitools/channel/handoffs/`; never touches rules |
| scripts/harness-db.py | 3078 | y | n | Records the path `~/.claude/CLAUDE.md` only (:565); `rule_change` is a knowledge-item type (:300, 2740) |
| scripts/read-session.py | 235 | y | n | Reads a transcript path given as an argument |
| scripts/read-session-full.py | 281 | y | n | same |
| scripts/generate-dashboard.py | 1547 | y | n | Renders a running-estimate JSON |
| scripts/sync-relay-to-cursor-agents.py | 188 | y | n | relay.md -> `~/.cursor/AGENTS.md` (:3, 122, 133) |
| scripts/profile-check.js | 170 | y | n | config.json + `<userRepoPath>/profile.json` only (:19, 55-63) |
| scripts/analyze-session.sh | 194 | y | n | Transcript analysis in node |
| scripts/aitools-dashboard.sh / .ps1 | 617 / 548 | y / y | n | `~/.aitools/dashboard-pids`, `.aitools/channel/running-estimate.json`, `.scratch/` |

`check-path-refs.py` is not in this slice (launch prompt) and was not read.

Rules read before the slice: the 26 files in `.claude/rules/` (main checkout; `diff -rq` against the worktree copy is empty, so the two are identical), `/Users/new-jose/repos/aitools/CLAUDE.md`, `.aitools/channel/CLAUDE.md`, the user rules, the mission packet, the explorer brief, `plans/tool-support-and-machine-profile.md`, the handoff `2026-10-21_360aa8f3-8.md`, and reference/{script-standards-detail, cross-platform-detail, logging, managed-file-deployment, plan-execution-detail}.md (worktree copies). Skills: `/scratch` and `/tool-ops` loaded.

## 3. Current behaviour relevant to the fan-out

### 3.1 Candidate grep (method)

`.scratch/session-misc/grep-slice.sh` ran `grep -n -i -E` over all 42 slice files twice. Pass 1 used `rules|\.claude|\.aitools|manifest|retired`. Pass 2 used `setup-user-claude|deploy-harness|userRepoPath|dotprofile|claude/|CLAUDE.md|cursor/rules|\.mdc|fan-?out`. Hit counts: every per-tool setup script had 0 hits in both passes, except setup-cursor-ide-mcp, with 1 comment hit each in .sh and .ps1. The resolver had 25/27 hits in pass 2, all dotprofile wording. ait-harvest.py had 35/38 hits, all session-archive, scratch or harvest manifest paths. Every file was then read in full anyway.

### 3.2 The resolver is setup-user-claude's source of `USER_REPO_PATH` (do not change; keep embedded)

setup-user-claude takes the dotprofile from the lib wrapper, which runs `aitools-profile.sh user-repo-path` (wrapper path aitools-lib.sh:172-173, wrapper at :286). It then uses that path as the rules adopt target:

setup-user-claude.sh:71-74 (verbatim):
```bash
URP_RC=0
resolve_user_repo_path || URP_RC=$?    # 1 = shared-only (expected); 3 = logged error + ERROR row
USER_REPO_PATH="$AITLIB_USER_REPO_PATH"
USER_REPO_VIA="$AITLIB_USER_REPO_VIA"
```
setup-user-claude.sh:349-352 (verbatim):
```bash
            _rule_adopt_path=""
            if [ -n "${USER_REPO_PATH:-}" ]; then
                _rule_adopt_path="$USER_REPO_PATH/claude/rules/$rule_name"
            fi
```

The resolver picks the dotprofile in this order, first match wins (aitools-profile.sh:419-424, verbatim):
```bash
# Which dotprofile (reference/user-repo.md "Which dotprofile"), first match wins:
#   1 AITOOLS_USER_REPO_PATH  2 --user-repo-path  3 config.json userRepoPath
#   4 <reposPath>/aitools-<githubUser>  5 the only aitools-* dir with profile.json
#   6 none (shared-only mode; not an error)
# Sets RUR_PATH, RUR_VIA, RUR_EXPECTED. Returns 0 found, 1 none, 2 error.
```
The PS1 twin is identical at aitools-profile.ps1:333-338.

`derive-config` (the source of config.json via setup-user-config) never saves the env override (aitools-profile.sh:1157-1160, verbatim):
```bash
    # A value from an environment override is used for this run but not persisted:
    # config.json records the machine's own answer, not a test's or a caller's.
    if [ "$RUR_VIA" != "env" ]; then d_urp="$RUR_PATH"
    else add_warn "dotprofile from AITOOLS_USER_REPO_PATH -- not saved to config.json"; fi
```
The PS1 twin is at aitools-profile.ps1:1007-1010.

deploy-harness takes the dotprofile for the rules fan-out from config.json only (deploy-harness.sh:117-129, verbatim; this file is outside the slice and is quoted as cross-slice evidence):
```bash
# =========================================================================
# 2. Dotprofile (source of user rules): userRepoPath in config.json
# =========================================================================
DOTPROFILE=""
# read_config_key returns 1 when the file or the key is absent: handled below.
URP=$(read_config_key "$HARNESS_DIR/config.json" "userRepoPath") || URP=""
if [ -z "$URP" ]; then
    log "No userRepoPath in $(display_path "$HARNESS_DIR/config.json") -- dotprofile rules skipped (run: aitools user init)"
elif [ ! -d "$URP" ]; then
    log "Dotprofile $(display_path "$URP") not found -- dotprofile rules skipped"
else
    DOTPROFILE="$URP"
fi
```
The PS1 twin is at deploy-harness.ps1:111-116. Convention and scan matches (steps 4 and 5) reach config.json, because derive-config persists them; only the env override (step 1) and `--user-repo-path` (step 2) do not. Consequence: see section 7 R-1.

### 3.3 MDM: the resolver is embedded in the generated setup-user-claude

build-deploy.sh:436-437 (verbatim):
```bash
RESOLVER_SH_FILES="aitools-profile.sh aitools-lib.sh aitools-json.pl"
RESOLVER_PS1_FILES="aitools-profile.ps1 aitools-lib.ps1 aitools-json.ps1"
```
build-deploy.sh:443-457 scans `aitools-profile.sh` for `$SCRIPT_DIR/<file>` loads (and the .ps1 for `Join-Path $PSScriptRoot "<file>"`). It fails the build when a loaded file is not embedded. The refactor must not add a sourced file to the resolver; none is planned. The embed dir also has a `rules/` subdir (build-deploy.sh:504, 697-698), which is the MDM rules fallback (MDM slice).

### 3.4 Contracts and conventions setup-user-claude shares with this slice

- **Resolver exit codes and the D-TS13 guard** (aitools-profile.sh:31-38, verbatim tail): "Callers must not pass 2 through as their own exit code: exit 2 from a setup script means a user abort (D-TS13)." The wrapper maps resolver errors to rc 3 (setup-user-claude.sh:72, 84 comments). Any new resolver call in the refactored setup-user-claude must keep this mapping.
- **Library-style logging contract** (aitools-profile.sh:39-43, verbatim): "every warning and error is returned as a `warn` / `error` line (and logged at detail); the caller logs each at its level and owns the summary rows and counters." So setup-user-claude, not the resolver, writes the `dotprofile` ERROR row (setup-user-claude.sh:65-70 comment).
- **Dotprofile commit + push (N-Q2)**: `commit_profile` (aitools-profile.sh:943-1005; PS1 `Invoke-ProfileCommit` :784-847) commits only the one file (`commit -m "$msg" -- profile.json`, :984). It refuses when the file was dirty before the write (:950-958, :969-972), falls back to the profile's git identity on a fresh machine (:973-982), pushes with no prompts (`GIT_TERMINAL_PROMPT=0`, `ssh -o BatchMode=yes`, :990-993), and separates "push rejected" from "push failed" (:996-1001). setup-user-claude's own rule push (setup-user-claude.sh:370-389) does none of this: stderr is suppressed (`2>/dev/null`), `git commit` has no pathspec, and `git push` can prompt. PR #103 moves the adopt push into the lib. The plan should make the rules adopt push match `commit_profile` semantics, or reuse the PR #103 lib helper, not keep the inline block.
- **Summary rows**: every per-tool script writes `write_summary OK|WARN|ERROR|ACTION "<canonical tool name>" ...` on every path and ends with the standard exit footer (for example setup-uv.sh:90-100). The canonical names (script-standards-detail.md "Tool name table") are `claude.md` and `claude rules` for setup-user-claude, and `harness files` for deploy-harness. None of the per-tool scripts uses `deploy_tracker_*` or `deploy_managed_file`, so no tracker convention in this slice constrains the refactor.
- **Governed outcome words** seen in the slice: `verified` / `updated` (setup-cursor-ide-mcp.sh:171-174, .ps1:130, 162), `n/a (<environment>)` (setup-google-chrome.sh:164 / .ps1:21 through `write_environment_skip`). A tracker `removed` outcome (known defect in the brief) has no precedent in this slice. "pruned" is a harvest-manifest status (ait-harvest.py:970), not a deployment outcome.

### 3.5 Other `.claude` / `.aitools` touch points (none affect the fan-out)

- ait-harvest.py scans `~/.claude/projects/*/*.jsonl` (:1059-1066) and archives transcripts to `<dotprofile>/sessions/` with commit+push (:534-582, 602-701). It takes the dotprofile from `config.json userRepoPath` directly (:197-231), the same source as deploy-harness. It commits only the paths it staged (`git add <rel>` then `commit`, :547-552).
- harness-db.py writes `.aitools/sessions/*.db`, `.aitools/harness.db`, `.aitools/channel/running-estimate.json` (:454-466) and records `~/.claude/CLAUDE.md` as a path string (:565).
- sync-relay-to-cursor-agents.py writes `~/.cursor/AGENTS.md` (:122), not Cursor rules.

## 4. What must change, or be checked, in this slice for the refactor

Nothing in this slice must change. Checks for the planner:

1. **Keep the resolver embedded in the generated setup-user-claude** (build-deploy.sh:436-457). Even when the refactor removes the dotprofile `claude/rules` loop, the script still needs the dotprofile for the CLAUDE.md template, the `{{USER_REPO_PATH}}` token and identity (setup-user-claude.sh:72-91, 150-159). Removing the embed would break MDM CLAUDE.md.
2. **Decide the rules adopt target after the fan-out.** Today it is `$USER_REPO_PATH/claude/rules/<name>`, from the resolver (setup-user-claude.sh:349-352). After the fan-out, SOURCE is `~/.aitools/rules/<name>`, which may come from `shared/rules`, `.claude/rules` or dotprofile `claude/rules` (first source wins, packet section 6). The adopt target should be the original repo file, which needs provenance from the PR #100 manifest (Harness slice). If the dotprofile is the target, use `USER_REPO_PATH` from the resolver and `commit_profile`-grade commit+push (section 3.4).
3. **Reconcile the dotprofile source between deploy-harness and setup-user-claude** (R-1). Either deploy-harness calls `resolve_user_repo_path` / `Resolve-UserRepoPath` (aitools-lib, which honours `AITOOLS_USER_REPO_PATH`), or setup-user-claude warns when its resolved dotprofile differs from the one the manifest recorded. This is a Harness/Claude slice decision; the resolver already supports both options unchanged.
4. **Intent text in the resolver header**: PR #105 rewrites the "Consumed by" list (aitools-profile.sh:14-19 / .ps1:13-16). It still lists "the generated deploy/setup-user-claude.sh". That stays true after the refactor (item 1), so no follow-up edit is needed. If the refactor ever stops embedding it, the intent is protected (sources-of-truth.md "Intent statements") and needs commander review.

## 5. Interactions with open PRs in this slice

`.scratch/session-misc/pr-files.sh` listed the files of all 20 open PRs (gh, 2026-10-26). Three PRs touch slice files. `.scratch/session-misc/pr-diffs.sh` grepped their added/removed lines for `rules|setup-user-claude|retired|manifest|\.claude`.

| PR | Branch | Slice files | Overlap with the fan-out |
|---|---|---|---|
| #105 | docs/m3-approved-intents | aitools-profile.sh/.ps1 header intent (hunk `@@ -8,20 +8,18 @@` / `@@ -7,19 +7,18 @@`); shared/claude-shared.md +2 lines | None in code. The new claude-shared line names "rules" as dotprofile content ("My dotprofile repo (profile.json, personal CLAUDE.md template, rules, session archives)"). That stays true, because dotprofile `claude/rules` remains a fan-out source. claude-shared.md is a Claude-slice file |
| #108 | fix/mf-audit-profile-json | aitools-json.pl (`nav`, `renp`), aitools-json.ps1 (`Get-JItems`...), aitools-profile.sh (`jread`, `jlist`, new block after :153), aitools-profile.ps1 (`Remove-TempFile`, `Invoke-ExceptionSet`, `Invoke-DeriveConfig`) | None (no rules terms in its +/- lines; one hit is a doc table row naming "generated `setup-user-claude`" as a consumer) |
| #114 | fix/mf-audit-config | the same aitools-json/aitools-profile hunks as #108, plus `Complete-Match` (.ps1 `@@ -510,9`) and setup-user-config | None. #114 appears to contain #108's resolver hunks (identical hunk headers); whichever merges second rebases |

#100, #103, #106, #110-#113, #115 and #116 touch no slice file (setup-user-claude, lib, build-deploy, deploy-harness and the installers belong to other slices).

## 6. Error-handling, parity and script-standards issues the refactor would touch

None. The refactor touches no file in this slice. The resolver code the refactor depends on (`resolve_user_repo`, `commit_profile`) follows script-standards: every suppression is commented and checked (for example aitools-profile.sh:953-954, 976-977), and the PS1 `Get-Command git -ErrorAction SilentlyContinue` (:773, 790) is an exempt existence check. Issues found elsewhere in the slice are under section 8.

## 7. Risks, unknowns, open questions

- **R-1 (cross-slice, medium): two dotprofile sources.** setup-user-claude resolves the dotprofile in the order env > `--user-repo-path` > config > convention > scan (section 3.2). deploy-harness reads config.json only. With `AITOOLS_USER_REPO_PATH` set and config.json naming another dotprofile, or none, the fan-out deploys the config.json dotprofile's rules, or none, while CLAUDE.md comes from the env one. Today rules come from the env one. Who sets it: tests under an isolated HOME, and build-deploy under Git Bash (aitools-profile.sh:16-18 old header; PR #105 text: "build-deploy.sh (through resolve_user_repo_path, unless its caller sets AITOOLS_USER_REPO_PATH)"). Q: should deploy-harness use `resolve_user_repo_path`? Suggested answer: yes. It is one lib call, it honours the same override as every other consumer (SD-7 "one resolver"), and tests in `tests/rules-fanout/` can then pin the dotprofile with the env var.
- **R-2 (low): `~` in userRepoPath.** The resolver expands a leading `~` (`expand_home`, aitools-profile.sh:232-239); deploy-harness's `read_config_key` path (deploy-harness.sh:122) does not, as far as this read shows. derive-config writes an expanded path, so the risk is only a hand-edited config.json. The behaviour of `read_config_key` itself is unknown here (Lib slice).
- **R-3 (low): concurrent dotprofile commits.** ait-harvest's catch-up commits and pushes the dotprofile from SessionStart (:1014, 1027-1040) under a lock only it honours (`~/.aitools/locks/harvest.lock`, :340). Its "skip during an aitools deploy" guard reads `AITOOLS_DEPLOY_IN_PROGRESS` (:1001), which nothing sets: `grep -rn AITOOLS_DEPLOY_IN_PROGRESS scripts shared/hooks` finds only ait-harvest.py:44 and :1001. A refactored setup-user-claude that commits adopted rules to the dotprofile can race it. Each side commits only its own paths, so a race at most makes a push fail (both log it). Q: set the env var in the installers? Suggested answer: yes, in a later PR (installer slice). It is not needed for the fan-out.
- **Unknown:** whether any Windows run has exercised `aitools-profile.ps1` against a real dotprofile. Its header marks MachineGuid as UNVERIFIED (:104-105, 270-272); this read cannot settle it.

## 8. INCIDENT markers (not filed)

- **INCIDENT M-1 (high, Windows):** `aitools-dashboard.ps1` assigns to the automatic read-only `$PID` on `-Stop` without `-All`: `$pid = Get-PortServerPid -PortNum $Port` (:379). PowerShell variable names ignore case, so this targets `$PID`. Probe on this Mac: `pwsh -NoProfile -Command '$pid = 5'` gives "Cannot overwrite variable PID because it is read-only or constant." The error is non-terminating, so `$pid` keeps the script's own process id, and `Stop-Process -Id $pid -Force` (:382) then kills the running pwsh: the dashboard is never stopped. The foreground start path also writes `$PID` deliberately (:533). Fix: rename the variable (for example `$serverPid`). Not run on Windows.
- **INCIDENT M-2 (medium):** ait-harvest.py's `AITOOLS_DEPLOY_IN_PROGRESS` guard (:44, 1001-1003) is inactive, because no writer sets the variable (grep above). The docstring presents it as a protection (plan §20.2 M2). Per script-standards "When analyzing code": FEATURE "skip catch-up during deploy" IS CURRENTLY INACTIVE.
- **INCIDENT M-3 (medium, parity):** setup-cursor-ide-mcp. The .sh removes vercel/webflow with `agent mcp remove` and a WARN on failure (:189-204), noting that `disable`/`enable` were dropped from the Cursor CLI (:190-193). The .ps1 still calls `agent mcp disable` and writes an ERROR row on failure (:166-178). Both headers still say "disabled via `agent mcp disable`" (.sh:9, .ps1:8). The .ps1 post-write validation logs LogError with no `Write-Summary ERROR`, then writes an OK "updated" row (:137-145, 162), which breaks the logging-summary pairing rule. Both scripts exit 1 on a missing node with no summary row (.sh:51-53, .ps1:37-39), which breaks the summary coverage rule.
- **INCIDENT M-4 (low):** aitools-dashboard.ps1 has empty `catch {}` blocks and unchecked `-ErrorAction SilentlyContinue` (:53, 62, 168, 172, 193, 196, 217, 266, 371, 383), against the error-handling requirements in script-standards.md.
- **INCIDENT M-5 (low):** generate-dashboard.py `load_estimate` calls `sys.exit(1)` (:83-94). The live watcher thread calls it inside `except Exception` (:216-230). `SystemExit` is not an `Exception`, so one malformed write of the estimate ends the watcher thread silently, and the served page stops updating.
- **INCIDENT M-6 (low):** harness-db.py `export_session_to_dict` writes `decisions` / `assumptions` at top level (:897-927), while generate-dashboard.py and aitools-dashboard health checks expect `situation.decisions` / `situation.assumptions` / `situation.facts` (generate-dashboard.py:70-76, 527-531; aitools-dashboard.sh:336-342). A DB-exported running estimate always renders zero decisions and assumptions, and the health check calls it UNHEALTHY.
- **INCIDENT M-7 (low):** setup-perl.sh `check_perl_version` captures `perl -e 'print $];' 2>&1` with no exit-code check (:29). If the probe fails, the error text becomes the "version" shown in the warning. Cosmetic.

## Scratch artifacts

`/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/.scratch/session-misc/`: `grep-slice.sh`, `grep-hits.txt`, `grep-hits2.txt`, `pr-files.sh`, `pr-files.txt`, `pr-diffs.sh`, `pr105.diff.tmp`, `pr108.diff.tmp`, `pr114.diff.tmp`.
