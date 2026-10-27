# Fix backlog: every in-scope INCIDENT marker as an executable fix batch

**Author:** S3-Reconcile-Fix (level 2, delegated by S3-Reconcile for Session Commander 10cf255a-c; commander Jose) · **Date:** 2026-10-26 · **Verified against:** origin/main 9861ff7 (final fetch; #102 merged, not yet applied: `registries/incidents.json` still 145 ids, max 145). No file under `scripts/ shared/ tests/ .github/ .claude/ .cursor/ reference/ registries/` changed between the delegates' base 560de56 and 9861ff7 (`git diff --stat 560de56 origin/main -- ...` empty), and every main-based draft file re-applies on 9861ff7 (section 8).

This is the fix-batch section of `plans/fan-plan-reconciliation.md`. Link it from the plan as section 6 "F batches". It does not replace R1-R14. It covers what R1-R14 and FAN-PLAN do not cover.

## Summary (5 lines)

1. About 240 marker lines (the Ledger's 47 drafts and 9 updates, plan section 8, the RC findings, FAN-PLAN, AnsA/AnsB, MdmPkg, AbortDocs, H2/MF) reduce to **76 fix items, FX-1..FX-76**: 6 high, 26 medium, 44 low. About 45 more are covered by R1-R14, FAN-PLAN, MERGE-ALL or open PRs, or are already fixed or dropped (section 2).
2. The three high FAN-PLAN items are drafted verbatim and tested under isolated HOMEs.
   - **FX-1:** post-push step 7 no longer runs build-deploy.
   - **FX-2:** pre-commit step 3 `--fix` and the githook no longer rebuild or stage.
   - **FX-3:** the bash Cursor fan-out reads its list on fd 3. On a pty, main overwrote a local edit without asking (`overwriting (non-interactive)`); the fixed copy showed the menu and `[s]kip` kept the edit, on bash 5 and 3.2.
3. 42 draft files hold about 140 verbatim OLD/NEW blocks. Every main-based file applies on 9861ff7 and passes `bash -n`, the pwsh parser or py_compile. The delegates ran the repo suites patched and unpatched and got identical counts (managed-files 57/57, test-lib 209, test-user-init 200, deploy-harness 45, and others).
4. 34 fix batches F1-F34 of at most 3 files each, plus 12 docs batches DX1-DX12. Order: high first, then by gate. Most batches have no gate. The gated ones wait on #106, #110, #111, the lib PRs, R2b/R2c/R4/R7a/R8c, FAN-PLAN Batch A, MERGE-ALL D-DEL5 or G-P.
5. 21 decisions need the commander, each with a suggested answer (section 6). Ledger closing stays in R13 L0: close 19 (the Ledger's 17 plus #86 and #94, both verified fixed). **Do not close #33**: setup-user-hooks still duplicates template logic. Also: #102 is now merged but not applied, so R13-pre still applies before MERGE-ALL runs the apply script.

Detail files (tracked, beside this file; each item block has the full evidence and verification):
- `S3-Reconcile-Fix-Code-items.md` (S3-Reconcile-Fix-Code: lib, entry points, installer, build-deploy, setup scripts)
- `S3-Reconcile-Fix-Checks-items.md` (S3-Reconcile-Fix-Checks: check scripts, hooks, harvester, CI)
- `S3-Reconcile-Fix-Docs-items.md` (S3-Reconcile-Fix-Docs: docs, spec, process, glossary)
- Drafts: `S3-Reconcile-Fix-drafts/{high,code,checks,docs}/edits-*.txt`, with `@@@FILE <repo path>` blocks for `S3-Reconcile-Code-drafts/apply.pl`. The paths are repo-relative, with no `main/` prefix to rewrite. Tests are in `S3-Reconcile-Fix-drafts/high/tests/`.
- The sub-delegate brief: `S3-Reconcile-Fix-subbrief.md`.

## 1. Method and sources

- **Sources read:**
  - Ledger 4.2-4.4 (#171-#217, plus updates and "needs verification").
  - Plan section 8.
  - S3-Reconcile-Code/Docs/Git/Trans/Review/Barrier findings (INCIDENT lists).
  - S3-FanPlan-report "INCIDENT markers" and its findings files.
  - S3-MdmPkg-report section 8, S3-AnsA, S3-AnsB, AbortDocs, H2 and MF hand-backs (through the Ledger, which processed them; the sub-delegates re-read the cited lines).
  - The delegates' own new INCIDENT markers.
- **Verification:**
  - Three level-3 sub-delegates (Code, Checks, Docs) verified their areas against origin/main 60e7fd7 -> 560de56/5f8edb4. S3-Reconcile-Fix did the three high items itself and re-applied every draft on 9861ff7.
  - Spot-checks against origin/main, all matching:
    - #175: `shared/skills/handoff/SKILL.md:318`, "Scratch directories are deleted by the SessionEnd".
    - #171: `scripts/ait-harvest.py:94`, `SCRATCH_PREFIX_LEN = 10`.
    - #190: `git ls-tree origin/main shared/hooks/` lists both `.bak.2026-06-21T*` files.
    - M-1: `scripts/aitools-dashboard.ps1:379`, `$pid = Get-PortServerPid`.
- **Commander decisions applied (relayed 2026-10-26):**
  - D5 confirmed: all project rules and skills go to user scope, so the "skip aitools" variant is not planned.
  - FAN-PLAN's plan takes its suggested answers.
  - No filings: markers become FX.
  - `reference/rules.md` is someone else's. It has landed on main at 60e7fd7, and here it is only referenced.
  - Verify against current main.
- **Merged-PR status:** at 9861ff7 the merged PRs are #99, #101, #102, #104, #105 and #97. None of them fixed an FX item; they changed docs and the channel only. Open PRs that fix an item are named per item.

## 2. Dropped / covered (not FX)

| Marker (source) | Disposition |
|---|---|
| #186 tracker has no `removed` (Ledger L2) | COVERED: FAN-PLAN Batch A |
| #188 user abort is an ERROR row; three exit-2 conventions (Ledger L2, plan 8, RC/Code) | COVERED: R8c (Q6) |
| #189 menu "[x]abort : stop the run" (Ledger L2, plan 8, RC/Docs D-9) | COVERED: R8a1/R8a2. Residual (deploy_abort comments) = FX-26 |
| #191 `--alias` claim without asking (Ledger L3, plan 8) | COVERED: R9 (Q7) |
| #192 entry points write config.json (Ledger L3, plan 8, RC/Docs D-17) | COVERED: R10 (Q8) |
| #203 fan-out claims (Ledger L4, plan 8, RC/Docs, FanPlan harness.md) | COVERED: R2/R2c/R3, FAN-PLAN flips them (R14) |
| #204 Cursor twin drift / parity (Ledger L4, plan 8, RC/Git) | COVERED: R4 step 4, R7a/R7b (Q9) |
| #212 README MDM order omits deploy-harness | COVERED: FAN-PLAN Batch C (C13/C14). The run-order half is FIXED ON OPEN PR #106; the order-mismatch half = FX-34 |
| #216 build-deploy trap EXIT replaced | FIXED ON OPEN PR #111 (`MDM_TMP="$BUILD_TMP/mdm"`). Close in L0 after #111 merges |
| setup-user-claude rules filter case parity (FanPlan) | COVERED: FAN-PLAN Batch B (`rule_name_kind`) |
| deploy tracker drops unknown outcomes (FanPlan) | COVERED: FAN-PLAN Batch A (default branch -> `failed`) |
| deploy-harness adopts not committed/pushed, N-Q2 (plan 8, Q12, RC/Docs D-23) | COVERED by open PR #103 (`_managed_adopt_notice` -> `dotprofile_commit_push` for every adopt; deploy-harness adopts through `deploy_managed_file`). Test gap = part of FX-46's PR family (a tests/deploy-harness case; spec in Code items) |
| `--skip-config` not passed in #106 Step 8b (RC/Git) | COVERED: MERGE-ALL follow-up (S3-MA-Brief-brief.md "Small follow-ups") |
| pre-push step 7 FAILs input-changing branches (plan 8, RC/Code) | COVERED: R11 (Q5). Note: edits-step7.txt uses `main/` prefixes; plan 6.0 already says to rewrite them |
| PS1 passes "harness files" to the relay, duplicate rows (plan 8, RC/Code) | COVERED: R8b |
| Decision 2 recorded nowhere / PENDING comments (plan 8, RC/Review) | COVERED: R1, R9b2 |
| "hostname match, then first profile" (plan 8, RC/Git) | COVERED: R2c step 4 |
| #105 row 8 relay intent without an owner (plan 8, RC/Review) | COVERED: R8d |
| `.cursor/rules/sources-of-truth.mdc` lacks rows (plan 8, RC/Docs) | COVERED: R12d |
| parity record contradicts itself (plan 8, RC/Docs, RC/Git) | COVERED: R7a |
| deploy-state docs (aitools-workspace.md row, agentic-framework.md) (RC/Docs) | COVERED: R2b step 4, R12a. The rest of #174/#179 = FX-48/FX-53 |
| managed-file-deployment.md "Primary (wins)" row (FanPlan Review) | COVERED: R2a step 4 |
| #100 Manifest draft names only the `.md` (RC/Git) | COVERED: R2a step 2 (both files) |
| #111 deploy-paths draft "two edits" (RC/Git) | COVERED: R4 step 1 |
| user-repo.md "Scope guidance" vs D5 (FanPlan Planner) | COVERED: FAN-PLAN user-repo Edit 4. Errata for its Note: the decision is 2026-10-23T01:58:29Z (uuid e073aea3), not 2026-10-22, and skills fan out too (decision 1) |
| No spec for project rules at user scope (FanPlan Ref) | FIXED: reference/rules.md v1.0 (60e7fd7) |
| tool-support-decision-tree abort text (FanPlan) | FIXED ON OPEN PR #106 (3de51d6). Residual = FX-73 |
| Pre-push step 7 trigger misses deploy-harness inputs (FanPlan I-4, AnsA, Harness, MDM) | FIXED: 8e490d7 (step 7 always runs) |
| Backup-File without -LiteralPath (H2) | FIXED: 9923a3c |
| bash `_merge_validate` always 0 (SourceTruth) | FIXED: #68 |
| setup-user-skills adopts a shared skill into a dotprofile fork (Ledger 4.4) | FIXED: #68 1d67da9 (`deploy_managed_file ... "$src"`) |
| deploy-paths.md calls setup-user-claude "duplicated" (FanPlan, RC/Code) | FIXED on main: only setup-user-hooks is listed as duplicated |
| #206 paths -> globs, Cursor half | FIXED: reference/tool-ops-cursor.md "Glob anchoring" (#99, 3c4f8fe). Residual = FX-58 |
| /delegate "No follow-up messages" text | FIXED: b08ec95 (PR #62). The /aitool-ops card residual = FX-56 |
| Live dotprofile deploy/ stale, no deploy-harness.* (FanPlan, MdmPkg) | MERGE-ALL (A4 rebuild) |
| Open PR branches carry the old step-7 trigger (plan 8) | NOT A DEFICIENCY: no branch changes check-pre-push.*, and a merge keeps main's step 7. Operational: merge origin/main into a branch before running its pre-push |
| The packet understates the step-7 known failure (plan 8) | dropped: a mission artifact, not a harness file. The packet owner (SC) edits it |
| Q4 suggested reversal vs plan intent (RC/Review) | moot: decision 1 confirms D5 |
| "Cursor user-level only" was never confirmed (RC/Trans) | COVERED: plan Q3 |
| deploy-paths.md/.mdc describe the old step-7 trigger (RC/Trans) | dropped: verified none do (plan item 6) |
| #102 title says #146-#161; no re-check after fa90df0 (Ledger, RC/Git) | moot: #102 merged (9861ff7) |
| window.py / user-prompts.py tooling gaps (RC/Trans, AnsA) | dropped: mission scratch tools. The harness reader's gap is FX-20 |
| B1/B3/B8/B10 plan defects (Barrier) | fixed in plan v1.1 |
| 4.4-a adopted user hook never deployed (Ledger) | NOT A DEFICIENCY (hook-lifecycle.md: by design). Optional wording = FX-42 |
| #146-#170 (PR #102 batch) | out of scope: approved, filed by MERGE-ALL's apply step (pre-apply amendments = R13-pre) |
| Glossary "profile" | COVERED: R5b |
| Intune URLs moved; dotprofile stale; H2-MDM truncation guard; AnsB errata (Ledger 4.4 drops) | dropped as the Ledger states |
| `tests/build-package/test-cli.sh` not in CI (Checks) | handed to BUILD-PKG (its file) |
| `edits-step7.txt` `main/` prefix (Checks) | not a deficiency: plan 6.0 documents the prefix rewrite |

## 3. The three high FAN-PLAN items (verbatim drafts, tested)

### FX-1 (high): check-post-push step 7 rebuilds the real dotprofile deploy/ and checks nothing
- **Source marker(s):** S3-FanPlan-report "check-post-push.sh:204 and pre-commit 3 --fix run build-deploy against the real dotprofile deploy/ without checking the exit code; high (Checks I-1)".
- **Status on origin/main 9861ff7:** OPEN. No open PR touches `scripts/check-post-push.*` except for unrelated lines (`prfiles.sh`: none).
- **Evidence:**
  - `scripts/check-post-push.sh:204` runs `bash "$SCRIPT_DIR/build-deploy.sh" >/dev/null 2>&1`. Under `set -euo pipefail` a failed build aborts the checklist before `print_summary`.
  - `:205` runs `git diff deploy/`, on aitools/deploy/. build-deploy no longer writes it (`build-deploy.sh:218` `DEPLOY_DIR="$_urp/deploy"`, then `:2298` `rm -rf "$DEPLOY_DIR_FINAL"`), so the step always PASSes.
  - `:210` `git checkout -- deploy/` can discard another session's work.
  - The ps1 twin does the same (`check-post-push.ps1:233-241`, `2>$null | Out-Null`).
  - tool-lifecycle.md "Rebuild + propagate" step 3 tells agents to run check-post-push.
- **Fix:** step 7 becomes "Frozen deploy/ unchanged". It runs `git status --porcelain -- deploy/` with the rc checked: PASS when clean, FAIL with a count and the reset command, and no auto-reset. Pre-push step 7 remains the dotprofile check. Draft: `high/edits-post-push-step7.txt` (sh + ps1).
- **Files:** scripts/check-post-push.sh, scripts/check-post-push.ps1 (code; not protected).
- **Gate:** none.
- **Tests run:** `high/tests/test-checks.sh` (throwaway clone under /tmp, isolated HOME, fake dotprofile with `deploy/SENTINEL`). Results:
  - Clean tree: `7. Frozen deploy/ unchanged [PASS]`, sentinel intact.
  - After editing one deploy/ file: `[FAIL] aitools/deploy/ has 1 local change(s)`, the edit kept.
  - Post-push rc 1 came from steps 3 (MCP, isolated HOME), 12 and 23. The step 23 failure is FX-7, found here.
- **Decision needed:** none.

### FX-2 (high): pre-commit step 3 `--fix` / `-Fix` and the githook rebuild the real dotprofile deploy/ and stage the frozen one
- **Source marker(s):** FanPlan Checks I-1; RC/Docs D-12, D-15 and the INCIDENT "check-pre-commit.sh:106-120 ... and scripts/githooks/pre-commit:13-16 run build-deploy ... then git add deploy/"; plan section 8 and Q11.
- **Status on origin/main 9861ff7:** OPEN.
- **Evidence:**
  - `check-pre-commit.sh:113-115`: build-deploy `>/dev/null 2>&1` (under set -e), `git add deploy/ 2>/dev/null`, PASS "(rebuilt + staged)".
  - `check-pre-commit.ps1:110-114`: `Get-Command bash` (can be WSL), `2>$null | Out-Null`.
  - `scripts/githooks/pre-commit:15-16`: build-deploy, `git add deploy/`. It is enabled per clone by `scripts/init-hh-hooks.sh`; it is not enabled on this Mac checkout (`git config --get core.hooksPath` exit 1).
- **Fix (plan Q11, suggested answer):** step 3 never rebuilds. It WARNs and names pre-push step 7 and the rebuild after the merge; the header drops "build freshness" from `--fix`. The githook only reminds. Step 10 stays as it is and now checks only the frozen aitools/deploy/, which matches R12a's D-15 text. Drafts: `high/edits-pre-commit-step3.txt` (FX-2a), `high/edits-githook.txt` (FX-2b).
- **Files:** check-pre-commit.sh/.ps1; scripts/githooks/pre-commit, scripts/init-hh-hooks.sh (code; not protected).
- **Gate:** Q11.
- **Tests run:** `high/tests/test-checks.sh`:
  - **A, original `--fix` with a shared/ change staged:** `[PASS] (rebuilt + staged)` and **sentinel GONE**: the dotprofile deploy/ was deleted and rebuilt. This reproduces the marker.
  - **B, fixed:** `[WARN] scripts/ or shared/ changed -- pre-push step 7 checks the dotprofile deploy/; rebuild it (build-deploy.sh) after the merge`; sentinel intact; 0 deploy/ paths staged.
  - **D, fixed githook:** rc 0, prints the reminder; sentinel intact; nothing staged.
- **Knock-on (docs, for R12a/R12c):**
  - R12a's D-15 step 3 text must drop "; `--fix` still stages it (see INCIDENT)" and say "`--fix` does not rebuild".
  - R12c's githook sentence becomes "reminds you to rebuild the dotprofile `deploy/` after a merge (no rebuild; pre-push step 7 checks it)".
  - Also update `README.md` "Optional pre-commit (regenerates `deploy/` ...)" and `scripts/README.md` "-Fix switch" wording.
- **Decision needed:** Q11. Suggested: as drafted. Rebuilding the dotprofile from a feature branch is wrong even when the build succeeds, because the dotprofile deploy/ must follow main.

### FX-3 (high): the bash Cursor fan-out never prompts (here-string loop, `[ -t 0 ]`)
- **Source marker(s):** S3-FanPlan-report "The bash Cursor fan-out never prompts, because of the here-string loop; high (Lib)".
- **Status on origin/main 9861ff7:** OPEN, and the same on #109 (fix/mf-audit-consumers) and #110 (feature/harness-cursor-user-rules).
- **Evidence:**
  - `scripts/setup-user-cursor.sh:534` `while IFS= read -r rule_src; do` ... `:582` `done <<< "$RULE_SOURCES"`.
  - Inside it, `deploy_managed_file` -> `prompt_diff_review` -> `tty_interactive` (`aitools-lib.sh:1357-1358`, `[ -t 0 ] || return 1`) is false. The result is `log_warn "Diff in ... -- overwriting (non-interactive)"`, so a user's local edit to `~/.cursor/rules/<name>.mdc` is overwritten without a menu (a backup is kept).
  - `high/tests/loopscan.pl` over every `scripts/*.sh` and `shared/hooks/*.sh` finds only this loop. deploy-harness.sh already uses fd 3 (`:338` `<&3`, `:342` `done 3< "$PLAN"`).
  - The ps1 iterates an array, so process stdin is untouched and it needs no change.
- **Fix:** `read -r rule_src <&3` and `done 3<<< "$RULE_SOURCES"`, plus a comment. Draft: `high/edits-cursor-fd3.txt`. It applies once on main, #109 and #110 (`apply-refs.sh`).
- **Files:** scripts/setup-user-cursor.sh (code; not protected). The MDM copy follows on the next build: the body is extracted.
- **Gate:** none for correctness. To avoid rebasing twice, run it after #109/#110 merge (MERGE-ALL), then re-apply.
- **Tests run (isolated HOMEs, `expect` pty):** `high/tests/test-fd3.sh` with `~/.aitools/rules/x.md` and a locally edited `~/.cursor/rules/x.mdc`.
  - Main copy: `REVIEWED=0`, local edit gone, `WARN|cursor rules|1 updated`, log `overwriting (non-interactive)`.
  - Fixed copy: `REVIEWED=1`, `[s]kip` kept the edit, `WARN|cursor rules|1 skipped (user review)`.
  - The same on `/bin/bash` 3.2.
  - `test-fd3-noninter.sh` (stdin /dev/null): the fixed copy still overwrites (`1 updated`), so the non-interactive fallback is unchanged.
- **Follow-up test for the repo (spec):** a pty case in tests/rules-fanout-cursor that runs `expect` when it is installed and SKIPs with a reason when it is not: local edit + `s` -> skipped. It goes in CI with FX-14.
- **Decision needed:** none.

## 4. FX items (all others)

Severity uses the incident-governance table. "Draft" names the draft file and block ids. Full evidence, verification and limits are in the area file named in the last column (C = Code, K = Checks, D = Docs, F = this file).

| FX | Sev | Deficiency (current evidence on 9861ff7) | Fix (draft or spec) | Files (P = protected) | Gate | Decision | Detail |
|---|---|---|---|---|---|---|---|
| FX-4 | high | #171: the harvester finds scratch dirs by `session_id[:10]` (`ait-harvest.py:94`, :773, :1125). A longer `session-<name>` is never harvested, and the miss harvests the LIVE session named in `.current-session` (reproduced). No liveness guard for scratch | `checks/edits-harvest.txt` HV-3,4,6,7,8 (exact dir name, no pointer fallback, skip dirs changed < 30 min); docs SD-1, SD-5 in `checks/edits-scratch-docs.txt` | scripts/ait-harvest.py; shared/skills/scratch/SKILL.md | none (re-anchor SD-* if R3 lands first: same skill) | none | K |
| FX-5 | high | #172: one `.scratch/.current-session` per checkout, overwritten by each SessionStart (`scratch-init.sh:70`), deleted by each harvest (`ait-harvest.py:876-880`), read by 7 hooks + 2 py | (a) `HV-5`: delete the pointer only when it names the harvested dir (drafted). (b) spec: readers derive `session-<id[:10]>` from stdin `session_id` | (a) ait-harvest.py; (b) block-claude-code-guide.sh, block-explore-agent.sh, command-channel-stop.sh, delegation-duty-guard.sh, glossary-skill-guard.sh, sh-file-fixup.sh, standing-order-guard.sh, intelligence-stop.py, harness-db.py, scratch-init.sh | none | D1 (b) | K |
| FX-6 | high | M-1: `aitools-dashboard.ps1:379` `$pid = Get-PortServerPid` (PID is read-only), so `-Stop` kills its own shell (probe) | `code/edits-misc.txt` M1 (`$serverPid`, checked Stop-Process/Remove-Item, no empty catch) | scripts/aitools-dashboard.ps1 | none | none | C |
| FX-7 | medium | NEW (S3-Reconcile-Fix): `check-script-compliance.sh` filters comments with `grep -n ... \| grep -v '^\s*#'`, which never matches after the "NNN:" prefix (6 sites, steps 3, 6, 7, 11, 12). Step 12 FAILs on main: `2 invalid: setup-user-config.sh(1) setup-user-config.ps1(1)` (a comment naming write_summary), so post-push step 23 FAILs. The PS1 twin is correct | `high/edits-compliance-step12.txt` (6 blocks: `grep -vE '^[0-9]+:[[:space:]]*#'`; removing comments only removes matches) | scripts/check-script-compliance.sh | none | none | F (tested: patched script `13 PASS, 0 FAIL`, `high/tests/test-compliance.sh`) |
| FX-8 | medium | #181: `backup_dir` (`aitools-lib.sh:925`) / `Backup-Dir` (`.ps1:820`) count only `*.md`, so `~/.cursor/rules` (all `.mdc`) is never backed up. Prune loops are unchecked | `code/edits-lib.txt` L181a-c | scripts/aitools-lib.sh, .ps1 | none | none | C |
| FX-9 | medium | #183: the AI merge prompt says "local vs source", while bash feeds a SOURCE->LOCAL `diff -u` and PS1 an unordered Compare-Object. The two platforms give the model different, mislabelled input | spec: feed the shared review diff (`_review_diff` / `Get-ReviewDiff`) to both, relabel, no `[m]` when no diff. Sample tests first (agentic-standards "Prompt evaluation") | aitools-lib.sh, .ps1 | after FX-8's PR (same files) | none | C |
| FX-10 | medium | #195: `bootstrap.ps1:48` runs `& powershell` (5.1) and ignores the exit code; the installer never installs pwsh 7 | `code/edits-installer.txt` L195a,b (winget pwsh step, run with pwsh, check `$LASTEXITCODE`) | scripts/bootstrap.ps1 | none | D2 | C |
| FX-11 | medium | #217: in the generated MDM `deploy-harness.ps1`, the outer `try {} finally {}` (`build-deploy.sh:2107`, `:2196`) has no catch. A statement-terminating error skips the exit footer and returns rc 0 (probed) | `code/edits-build.txt` L217 (catch -> LogError + ERROR row + exit 1) | scripts/build-deploy.sh | none (applies on main and #111) | none | C |
| FX-12 | medium | #211: no size gate for generated scripts. Measured: 7 .ps1 over 200,000 B (6 after #111); #111 gates deploy-harness only | `code/edits-pr111.txt` L211 (WARN for every generated script) | scripts/build-deploy.sh | #111 merged | D3 | C |
| FX-13 | medium | #173: a worktree's `.scratch/` is never harvested; `git worktree remove` deletes it | spec: catch-up from the main worktree walks `git worktree list --porcelain`, harvests into the main checkout's harvesting/ with `wt-<name>_` tags; observe-mode warning on `git worktree remove` | ait-harvest.py; standing-order-guard.sh or a new hook + hooks-manifest.json | after FX-4/5 (same file) | D4 | K |
| FX-14 | medium | F6 / FanPlan I-2: tests/deploy-harness (45/45), tests/deploy-harness-mdm (30/30), tests/rules-fanout-cursor (78/78) pass locally but are not in check.yml | `checks/edits-ci.txt` CI-1, CI-2 (macos + linux jobs) | .github/workflows/check.yml | re-anchor after #112, #116 (same insertion point) | none | K |
| FX-15 | medium | setup-user-hooks writes settings.json without a backup (`setup-user-hooks.sh:383` node writeFileSync; `.ps1:376` WriteAllText), against config-file-safety.md "Backup before overwrite" | ps1: `code/edits-misc.txt` M-hooks-a; sh: spec (node writes a temp file, bash backs up + mv) | setup-user-hooks.sh, .ps1 | none | D5 | C |
| FX-16 | medium | setup-user-shell ignores dry-run (`AITOOLS_DRY_RUN=1` is exported by the installer; sh writes `~/.bash_profile`, ps1 `$PROFILE`) | `code/edits-misc.txt` M-shell-a..d | setup-user-shell.sh, .ps1 | none | none | C |
| FX-17 | medium | `AITOOLS_DEPLOY_IN_PROGRESS` is read by ait-harvest.py (:44, :1001) but set nowhere; the entry points set the dead `AITOOLS_DEPLOY`. The FEATURE "catch-up skips during a deploy" IS CURRENTLY INACTIVE | `code/edits-entry.txt` M2a-d (rename) | scripts/aitools, aitools.ps1 | none | D6 | C |
| FX-18 | medium | setup-cursor-ide-mcp sh/ps1 diverge (`agent mcp remove` vs `disable`, ERROR vs WARN, unchecked WriteAllText, no row when node missing); possible churn of mcp.json every run (UNVERIFIED) | `code/edits-misc.txt` M3a-g | setup-cursor-ide-mcp.sh, .ps1 | the churn probe (D7) | D7 | C |
| FX-19 | medium | #205: the `~/.cursor/AGENTS.md` relay mirror is probably never loaded (tool-ops-cursor.md: Cursor loads `<ancestor>/AGENTS.md`) | decision: retire / `~/AGENTS.md` / user rule `aitools-relay.mdc`, after the Cursor canary | scripts/aitools, aitools.ps1, aitools-install.sh, .ps1, sync-relay-to-cursor-agents.py; reference/tool-ops-cursor.md (P) | canary + D8 | D8 | C |
| FX-20 | medium | NEW (Docs): `scripts/read-session.py` skips every user message whose content is a list, so AskUserQuestion answers (the commander's words) are lost; no `isSidechain` filter | spec: emit list text blocks and AskUserQuestion tool_results as COMMANDER (answer); skip sidechain unless `--sidechain`; fixture test | scripts/read-session.py (+ ~/.aitools/bin copy via install) | none | none | D (M11) |
| FX-21 | medium | NEW (Checks): `printf/echo "$x" \| grep -q` under pipefail reports "no match" on large input when the match comes early (rc 141; 54 sites, e.g. check-pre-push.sh:188, :191 step-7 smoke detection; setup-gh-cli.sh:73 ...) | spec: here-strings (`grep -q pat <<< "$x"`); audit list in K; PRs of <= 3 files, check-pre-push first | 54 sites (list in K) | none | none | K, C |
| FX-22 | low | #184: `printf \| head -N` under pipefail SIGPIPE (rc 141 at 200,000 lines): aitools-lib.sh:1456 (merge preview), scripts/aitools:2022 | `checks/edits-sigpipe.txt` SP-1, SP-2 | aitools-lib.sh, scripts/aitools | ship SP-1 in FX-8's PR, SP-2 in F9 | none | K |
| FX-23 | low | #182: `merged=$(... invoke_ai ...)` loses AI_REJECT_REASON (subshell); log says "unknown error" (probed) | `code/edits-lib.txt` L182 | aitools-lib.sh | none | none | C |
| FX-24 | low | #185 + Docs' new marker: post-push steps 30/31 use `\w[\w-]*` / `[\w-]+`, so `accept & adopt` is never checked; `tr ',' ' '` splits values; step 30 computes but never compares tracker lists | `checks/edits-postpush.txt` PP-1..8 | check-post-push.sh, .ps1 | same PR as FX-1 (combined apply tested: 10/10) | none | K |
| FX-25 | low | #187: deploy-harness `add_source` filters case-sensitively in bash (`:196-208`), case-insensitively in PS1, against its header (FAN-PLAN F2) | `code/edits-harness.txt` L187a,b (bracket patterns) + a tests/deploy-harness case | scripts/deploy-harness.sh; tests/deploy-harness/test-deploy-harness.sh | none | none | C |
| FX-26 | low | #189 residual: `deploy_abort` / `Invoke-DeployAbort` comments "(D-TS13; abort ends the whole run, T-Q3)" (only on #106) contradict the kept #106 rule | `code/edits-pr106.txt` L189a,b | scripts/aitools, aitools.ps1 | #106 merged | none | C |
| FX-27 | low | #193: a skipped build-deploy (no node, no dotprofile, resolver error, exit 0) prints OK "Rebuilt" (`scripts/aitools:2055-2056`, `aitools.ps1:2010-2011`) | `code/edits-entry.txt` L193a,b (WARN `deploy build` `skipped (see deploy log)`) | scripts/aitools, aitools.ps1 | none | none | C |
| FX-28 | low | #194: tool_exception_record / Set-ToolException headers misstate exit 3 | `code/edits-lib.txt` L194a,b | aitools-lib.sh, .ps1 | none | none | C |
| FX-29 | low | #196: Git Bash path hardcoded in aitools.ps1:1989, three literals in setup-bash.ps1, a third list in check-pre-push.ps1; none `# Verified:` | `code/edits-lib.txt` L196a (`Find-GitBash`, `# UNVERIFIED`), `code/edits-entry.txt` L196b,c | aitools-lib.ps1; aitools.ps1, setup-bash.ps1 | Windows verification for the marks | none | C |
| FX-30 | low | #198: `claude update` "up to date" regex never matches ("Claude Code is up to date (2.1.308)" in deploy.log) | `code/edits-installer.txt` L198a,b | aitools-install.sh, .ps1 | none | none | C |
| FX-31 | low | #199: no Claude Code auth check in the installer (script-standards "Post-install authentication check") | `code/edits-installer.txt` L199a,b (`claude auth status --json`) | aitools-install.sh, .ps1 | none | D9 | C |
| FX-32 | low | #200: relay-outbound-prompt.sh bare `read -r choice < /dev/tty`; .ps1 `Read-Host` and no IsInputRedirected test | `code/edits-relay-prompt.txt` L200a-c | relay-outbound-prompt.sh, .ps1 | none | none | C |
| FX-33 | low | #210: build-deploy embeds skills through unchecked heredocs (no delimiter or `'@` check, no final newline, unchecked mktemp in generated script) | `code/edits-build.txt` L210a-c | scripts/build-deploy.sh | none | none | C |
| FX-34 | low | #212 residual: the installer's Step 21 order differs from the `aitools` sync loop | `code/edits-installer.txt` L212a,b (installer takes the loop's order) | aitools-install.sh, .ps1 | none | D10 | C |
| FX-35 | low | #215: the lib is carried twice in generated setup-user-claude/-cursor/-settings (about 140-150 KB each; feeds FX-12) | spec (embed once, source the embedded copy) | scripts/build-deploy.sh | #111 merged + D3 | D3 (defer) | C |
| FX-36 | low | #73 (update): the classifier harvests bookkeeping/staging files (dot files, `events.jsonl`, `msg-*`, `pr-body*`); live: `harvesting/2026-10-23_session-f486b184-c_.intelligence-last-check`, `_events.jsonl` | `checks/edits-harvest.txt` HV-1,2; SD-2,3 | ait-harvest.py, scratch SKILL.md | with FX-4 | D11 | K |
| FX-37 | low | #190: `shared/hooks/*.sh.bak.2026-06-21T*` tracked; .gitignore lacks `*.bak.*` | `checks/edits-bak.txt` BAK-1 + `git rm shared/hooks/harness-db-sessionstart.sh.bak.2026-06-21T203304Z` and `git rm shared/hooks/standing-order-guard.sh.bak.2026-06-21T203334Z` (two calls, no glob) | .gitignore + 2 deletions | none | none | K |
| FX-38 | low | #209: standing-order-guard checks only line 1 of a 2-3 line command (5 forms pass silently) | `checks/edits-sog.txt` SOG-1..3 (`MODE_LATER="observe"`, a widening change per hook-rollout.md); `checks/edits-sog-docs.txt` SOGD-1 | shared/hooks/standing-order-guard.sh; .claude/rules/hook-rollout.md (P) | G-P for SOGD-1 | none | K |
| FX-39 | low | Plan 8 / Barrier B8 + Ledger 4.4: pre-commit step 20 misses a bare path in parentheses; check-path-refs reads `scripts/aitools-json.pl/.ps1` as one path | `checks/edits-pathrefs.txt` CHK-P1a-d, CHK-P2a-c | scripts/check-path-refs.py, scripts/check-path-refs-allow.txt | none | D12 | K |
| FX-40 | low | setup-user-skills duplicate-name check is case-sensitive in bash (:89-92), case-insensitive in PS1; NEW: resolver-error rows differ (sh two rows, ps1 one) | `code/edits-misc.txt` M-skills-a..c; rows: spec (one row per tool in both) | setup-user-skills.sh (+ .ps1 for rows) | none | none | C |
| FX-41 | low | FAN-PLAN F1: the Cursor fan-out filter is case-sensitive in both languages; own copies of the manifest helpers | spec: `rule_name_kind` / `Get-RuleNameKind`, drop the copies | setup-user-cursor.sh, .ps1 | #110 + FAN-PLAN Batch A merged; after FX-3 | none | C |
| FX-42 | low | 4.4-a: the `[a]dopt to dotprofile` prompt for a user hook does not say it is not deployed elsewhere | optional one-line wording | setup-user-hooks.sh, .ps1 | fold into FX-15's PR | D13 | C |
| FX-43 | low | 4.4-c: PS1 console input after `Start-AiSpinner` (Start-Job) — UNVERIFIED | pty probe (tests/managed-files/pty-run.py), then `Start-ThreadJob` or no spinner | aitools-lib.ps1 | probe | none | C |
| FX-44 | low | NEW (Code): `try {} finally {}` without catch around must-run code can end rc 0 (confirmed only for FX-11); aitools.ps1 build env try/finally and lib blocks not audited | spec: audit + add catches | aitools.ps1, aitools-lib.ps1 | after FX-11 | none | C |
| FX-45 | low | NEW (Code): Backup-Dir prunes by LastWriteTime, backup_dir by the name's timestamp; a same-second second backup copies into the existing dir | spec: both prune by name timestamp; a unique suffix on collision | aitools-lib.sh, .ps1 | after FX-8 | none | C |
| FX-46 | low | NEW (Checks): tests/deploy-harness-mdm needs a committed checkout (build embeds `git ls-files`); 2 cases fail with no hint otherwise. Also the #103 coverage gap (a deploy-harness dotprofile adopt -> one commit on a bare remote) | spec: precondition SKIP with reason; new test case | tests/deploy-harness-mdm/*, tests/deploy-harness/test-deploy-harness.sh | #103 merged for the adopt case | none | K, C |
| FX-47 | low | Barrier B13: a full-tree export under `.scratch/` is loaded as project context | `checks/edits-scratch-docs.txt` SD-6 (docs only; the harvester takes top-level files only) | shared/skills/scratch/SKILL.md | with FX-4 | none | K |
| FX-48 | medium | #174: aitools-workspace.md "Workspace structure" names `.aitools/scratch/` and `.aitools/harvesting/` (not used) and "#34 superseded" as done | `docs/edits-workspace.txt` D174a-c | .claude/rules/aitools-workspace.md (P) | G-P; in R2b's PR (same file) | none | D |
| FX-49 | medium | #175: /handoff SKILL.md says the SessionEnd hook deletes scratch (4 sites) | `docs/edits-handoff.txt` D175a-d | shared/skills/handoff/SKILL.md | none | none | D |
| FX-50 | low | #176: /handoff Step 5 reads only a separate assessment file | `docs/edits-handoff.txt` D176 | shared/skills/handoff/SKILL.md | none | none | D |
| FX-51 | medium | #177: no rule that stacked PRs target main (two merged into stale bases) | `docs/edits-delegate.txt` D177-D178 (bullet 2) | shared/skills/delegate/SKILL.md | MERGE-ALL D-DEL5 (same skill; pull, re-anchor) | D14 | D |
| FX-52 | low | #178: file ownership only in launch prompts; no pre-PR overlap check | `docs/edits-delegate.txt` D177-D178 (bullet 1) | shared/skills/delegate/SKILL.md | as FX-51 | none | D |
| FX-53 | medium | #179 rest: post-push-checklist.md step 29 "auto-merge menu", step 30 lists scripts not audited | `docs/edits-postpush.txt` D179a,b. Add after FX-1: the step 7 line becomes "Frozen deploy/ unchanged (the dotprofile deploy/ is checked by pre-push step 7)" (spec) | reference/post-push-checklist.md | after FX-1 for the step-7 line | none | D |
| FX-54 | low | #180: config-file-safety.md "when both sides differ"; backup section skips library JSON; NEW: says backup failure is non-fatal but `_managed_write` stops on one (`aitools-lib.sh:1057-1061`) | `docs/edits-configsafety.txt` D180a-c | .claude/rules/config-file-safety.md (P) | G-P | none | D |
| FX-55 | low | #197: cross-platform-detail.md recommends Refresh-Path against shadowing; Refresh-Path only appends | `docs/edits-xplat.txt` D197 | reference/cross-platform-detail.md | none | none | D |
| FX-56 | medium | #201: tool-ops-claude-code.md "2.1.81" (2.1.309 now), item #1 two dates, item #25 + section obsolete; NEW: /aitool-ops card still says "No follow-up messages possible" | `docs/edits-toolops.txt` D201a-f | reference/tool-ops-claude-code.md (P), shared/skills/aitool-ops/SKILL.md | G-P | none | D |
| FX-57 | medium | #202: claude-shared.md says Claude Code on Windows always uses Git Bash; upstream (chrome-devtools, code.claude.com/docs/en/setup, 2026-10-26): PowerShell without Git for Windows, a PowerShell tool alongside Bash with it, `CLAUDE_CODE_GIT_BASH_PATH` | `docs/edits-claudeshared.txt` D202; same line in the dotprofile `claude/CLAUDE.md` (dotprofile main, N-Q2) | shared/claude-shared.md (P); dotprofile template | G-P | none | D |
| FX-58 | low | #206 residual: rules.md does not cite tool-ops-cursor "Glob anchoring" or the Claude vs Cursor scoping difference | one sentence in reference/rules.md section 5 (spec) | reference/rules.md (owner: SC's rules.md delegate) | owner | none | D |
| FX-59 | low | #207: cursor-practices.md says User Rules are SQLite-only, CLI reads no user rule files | `docs/edits-cursorpractices.txt` D207a-c; replaces R7a's D-25 row step | reference/cursor-practices.md | in R7a's PR (Q9) | none | D |
| FX-60 | low | #208: harness.md intent scope "architecture only" but holds the conflict-handling contract | `docs/edits-harness.txt` D208 (widen) | reference/harness.md (P, intent) | G-P, in R2b's PR | D15 | D |
| FX-61 | medium | #211/#213/#214 doc halves: deploy-paths.md states no MDM size, clean-endpoint or run-context limits | `docs/edits-deploypaths.txt` (new "MDM path limits" subsection) | .claude/rules/deploy-paths.md (P) | G-P; after R4; pull (BUILD-PKG edits it) | none | D |
| FX-62 | low | #105 (update): /tool-registry SKILL.md calls `overrides` per-tool (it is top-level) and lacks many fields | `docs/edits-toolregistry.txt` D105 | .claude/skills/tool-registry/SKILL.md | none | none | D |
| FX-63 | medium | #51 (recurrence): the USO "Dedicated tools" names Grep/Glob, absent in 2.1.307-2.1.309 sub-agents | `docs/edits-claudeshared.txt` D51, `docs/edits-toolops.txt` D201b, `docs/edits-delegate.txt` D51 | claude-shared.md (P), tool-ops-claude-code.md (P), delegate SKILL.md | G-P (protected two) | none | D |
| FX-64 | medium | G1: glossary terms describe the removed model ("auto-merge menu", "merge-conflict menu", "accept & adopt", "updated"); missing "review menu", "failed", "merge & adopt", "fan-out", "harness files", "trigger directive"; later "retired", "removed" | one `/glossary` run (spec in D, steps 1-10) | registries/glossary.json (P, via skill), .claude/rules/glossary.md (P) | G-P; step 9 after #100 / FAN-PLAN A | none | D |
| FX-65 | low | M1: `shared/rules/*.md` not in the protected table | `docs/edits-sot.txt` DSOT | .claude/rules/sources-of-truth.md (P) | after MERGE-ALL's review-after edit | none | D |
| FX-66 | medium | M2 (Q14): the channel exception is only in CLAUDE.md; /handoff and the user rule delegation.md do not know it | `docs/edits-handoff.txt` DQ14; user-rule line spec (dotprofile delegation.md) | shared/skills/handoff/SKILL.md; dotprofile claude/rules/delegation.md | Q14 / MERGE-ALL D-DEL5 | D16 | D |
| FX-67 | low | M4: the #108/#114 Fix6 draft adds a second "library-style tool" definition | spec: Edit 1 only, fold Edit 2 into logging.md section 7 | reference/logging.md, reference/script-standards-detail.md | #108/#114 merged + D17 | D17 | D |
| FX-68 | medium | M5 / RC/Git: 3de51d6 (5 protected abort docs on #106) has no independent review | process: an independent reviewer checks the five files against #106's code and posts `gh pr comment` before MERGE-ALL merges #106 | none (PR #106) | before #106 merges | none | D |
| FX-69 | medium | M6 / FanPlan Lib: the spec names `ADOPT_TRANSFORM` / `-AdoptTransform` and `adopt_claude_md`; the code uses positional `ADOPT_FILTER` / `-AdoptFilter`, `claude_md_adopt_filter` | `docs/edits-adoptfilter.txt` DAF1-6 (spec follows the shipped code; Code agrees) | reference/managed-file-deployment.md (P), .claude/rules/managed-file-deployment.md (P), .cursor/rules/managed-file-deployment.mdc | G-P; after R2c (same files) | none | D, C |
| FX-70 | low | M7 / FanPlan Ref: tool-ops-claude-code lacks how user rules load; FAN-PLAN's #28 draft is UNVERIFIED | `docs/edits-toolops.txt` D28 (text verified with chrome-devtools, code.claude.com/docs/en/memory, 2026-10-26); rules.md section 5 drops its UNVERIFIED mark (owner) | reference/tool-ops-claude-code.md (P) | G-P; whichever of FAN-PLAN's doc batch or DX4 lands first; the other drops #28 | none | D |
| FX-71 | low | NEW (Docs): documentation-standards.md "Skill placement" says project skills are not deployed; contradicts rules.md R-4 and decision 1 | spec: reword with FAN-PLAN's skills half | .claude/rules/documentation-standards.md (P) | FAN-PLAN skills half | none | D |
| FX-72 | low | NEW (Docs): harness.md cites an `/artifact-roles` skill that does not exist | spec: remove or retarget the citation | reference/harness.md (P) | in R2b's PR with FX-60 | none | D |
| FX-73 | low | M10 residual: decision-tree tool-menu line `[x]abort : change nothing and stop the run` (main :433) is false under #106 | fold into R8c-d2: `change nothing and stop this script (exit 2)` | reference/tool-support-decision-tree.md | #106 merged, R8c-d2 | none | D |
| FX-74 | low | #212 README residual: C13 keeps "MDM-ready", which #213 shows is false on a clean endpoint | note to FAN-PLAN's C13: point to deploy-paths.md "MDM path limits" (FX-61) | README.md | FAN-PLAN Batch C + FX-61 | none | D |
| FX-75 | low | NEW (Checks): the guard blocks a read-only `sed -n '1,20p;135,160p' f` (`;` check); the #82 exemption covers one range | spec: a narrowing exemption for multi-range read-only `sed -n` (keeps the mode, hook-rollout.md) | shared/hooks/standing-order-guard.sh; hook-rollout.md (P) row | after FX-38 (same file) | D18 | K |
| FX-76 | low | NEW (S3-Reconcile-Fix): post-push step 24 `grep -r ... \| grep -v '^\s*#'` has the same prefix bug as FX-7 (path prefix); harmless today (real uses exist) | spec: `grep -vE '^[^:]*:[[:space:]]*#'` | check-post-push.sh | with FX-1 / FX-24 | none | F |

## 5. Fix batches

Rules for every batch: plan section 6.0 (shipping, delegation, anchors, Windows). In addition:
- Run `perl S3-Reconcile-Code-drafts/apply.pl <edits> <worktree> <out>` with the files below (no prefix rewrite needed), diff, copy in.
- `edits-misc.txt`, `edits-installer.txt` and `edits-entry.txt` hold blocks for several batches: split them by `@@@FILE` before applying.
- Every code batch passes the "Error-handling rules (non-negotiable)" block of `reference/plan-execution-detail.md`. The audit line per batch says what was checked.
- After a gate opens, `git fetch` and re-run `high/tests/apply-refs.sh <edits> <tmp> origin/main`. If an OLD is no longer unique, re-pin it and record that in the PR body.

**Order:**
- **First, no gate:** F1, F2+F3 (after Q11), F4, F5, F6, F7. Run F4 after #109/#110 merge.
- **Then:** F8 -> F9 -> F10 and the rest by gate.
- **Code batches that share files with R8-R10** (`scripts/aitools`, `aitools.ps1`, `aitools-install.*`, `aitools-lib.*`) run strictly after the R-batch holding the file, or strictly before it. Never in parallel.
- **Suggested order:** F8 after the open lib PRs (#103, #112, #113, #115, #116) merge, before R8a1. F9 and F11 after R10.

| Batch | Branch | Items | Files (<= 3) | Gate | Verification | Error-handling audit |
|---|---|---|---|---|---|---|
| F1 | `fix/post-push-frozen-deploy` | FX-1, FX-24, FX-76 | scripts/check-post-push.sh, .ps1 | none | `high/edits-post-push-step7.txt` + `checks/edits-postpush.txt` together (10/10 tested); `bash -n`; pwsh parser; `high/tests/test-checks.sh` case C; `.scratch/session-rcfixk/test-postpush-regex.sh` + `.ps1` (copy to the worktree scratch); `git grep -n "build-deploy.sh" -- scripts/check-post-push.sh` = 0 | step 7: no suppression; `2>&1` captured, rc checked; no auto-reset. PP: per K (an unreadable caller becomes a finding) |
| F2 (+F3 as 2nd commit, one PR) | `fix/pre-commit-no-rebuild` | FX-2a, FX-2b | F2: check-pre-commit.sh, .ps1. F3: scripts/githooks/pre-commit, scripts/init-hh-hooks.sh | Q11 | `bash -n` all; pwsh parser; `high/tests/test-checks.sh` cases A/B/D; `git grep -n "build-deploy" -- scripts/check-pre-commit.sh scripts/check-pre-commit.ps1 scripts/githooks/pre-commit` = 0 | removes two unchecked `2>/dev/null` / `2>$null`; adds no new ones |
| F4 | `fix/cursor-fanout-fd3` | FX-3 | scripts/setup-user-cursor.sh | after #109, #110 (re-apply; drafts apply on both heads) | `bash -n` (bash 5 + /bin/bash); `high/tests/test-fd3.sh <tmp>` and `<tmp> /bin/bash` (REVIEWED=1, skipped); `test-fd3-noninter.sh` (1 updated); `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | redirection change only |
| F5 | `fix/harvest-scratch-dirs` | FX-4, FX-5a, FX-36, FX-47 | scripts/ait-harvest.py, shared/skills/scratch/SKILL.md | none (re-anchor SD-* after R3) | py_compile; `.scratch/session-rcfixk/test-harvest.py` fixture (exact names, own dir untouched, `session-live` skipped, pointer kept, "2 harvested, 6 ephemeral skipped") | HV-5 replaces a bare `except: pass` with a logged path; `_scratch_dir_recent` logs and treats as live |
| F6 | `fix/dashboard-pid` | FX-6 | scripts/aitools-dashboard.ps1 | none | pwsh parser; `git grep -n '\$pid =' -- scripts/aitools-dashboard.ps1` = 0; Not run: Windows | empty `catch {}` replaced by LogWarn; `-ErrorAction Stop` in try |
| F7 | `fix/compliance-comment-filter` | FX-7 | scripts/check-script-compliance.sh | none | `bash -n`; `high/tests/test-compliance.sh` (step 12 PASS, 13 PASS 0 FAIL) | pattern change only |
| F8 | `fix/lib-backup-merge-reason` | FX-8, FX-23, FX-28, FX-29 (L196a), FX-22 (SP-1) | scripts/aitools-lib.sh, .ps1 | after open lib PRs merge (drafts tested on main + each); before R8a1 or after it with re-pin | `bash -n`; pwsh parser; `.scratch/session-rcfixc/test-lib-drafts.sh` (/bin/bash) + `.ps1`; `bash tests/managed-files/test-managed-files.sh` (57/57); `pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1` (39/39); `bash tests/profile/test-lib.sh` | prune loops checked (WARN); mktemp failure = failed merge; no new suppressions (C) |
| F9 | `fix/entry-build-skip-guard` | FX-27, FX-29 (L196b,c), FX-17, FX-22 (SP-2) | scripts/aitools, aitools.ps1, setup-bash.ps1 | F8 merged (Find-GitBash); sequential with R8b-R10 | `bash -n`; pwsh parser; `.scratch/session-rcfixc/test-skip-parse.sh`; `bash tests/profile/test-user-init.sh`; `git grep -n 'AITOOLS_DEPLOY\b' -- scripts` = 0 | build output captured, phrase match documented at the four build-deploy sites |
| F10 | `docs/abort-comment-tq3` | FX-26 | scripts/aitools, aitools.ps1 | #106 merged (fold into F9 if #106 merged first) | `bash -n`; parser; `git grep -n "abort ends the whole run" -- scripts` = 0 | comments only |
| F11 | `fix/installer-claude-step9` | FX-30, FX-31, FX-34 | scripts/aitools-install.sh, .ps1 | after #106/#116 and R8b/R8c (same files) | `bash -n`; parser; regex vs live `claude auth status --json`; Not run: logged-out machine, Windows | here-string, not `printf \| grep -q`; WARN + ACTION paired; unknown -> WARN with rc |
| F12 | `fix/bootstrap-pwsh` | FX-10 | scripts/bootstrap.ps1 | D2 | parser; Not run: fresh Windows VM | `$LASTEXITCODE` checked after winget and the installer |
| F13 | `fix/relay-prompt-eof` | FX-32 | scripts/relay-outbound-prompt.sh, .ps1 | none | `bash -n`; parser; `printf '' \| bash scripts/relay-outbound-prompt.sh` in a temp repo with a dirty relay -> rc 0 | EOF handled explicitly |
| F14 | `fix/harness-case-filter` | FX-25 | scripts/deploy-harness.sh, tests/deploy-harness/test-deploy-harness.sh | none (drafts apply on main + #100/#106) | `bash -n`; `bash tests/deploy-harness/test-deploy-harness.sh` (+ new `X.MD` / `a.BAK.1` case); tests/deploy-harness-mdm | pattern change only |
| F15 | `fix/build-embed-checks` | FX-11, FX-33, FX-12 (if #111 merged) | scripts/build-deploy.sh | FX-12 part: #111 merged; else ship FX-11/FX-33 alone | isolated-HOME build (`.scratch/session-rcfixc/build-iso.sh`): rc 0, generated bash -n 0 fail, 25 .ps1 parse; `probe-harness-tf.sh` 4 variants rc 1; size WARN lines (6 today) | delimiter checks fail the build; mktemp checked; catch logs + ERROR row |
| F16 | `fix/setup-user-shell-dryrun` | FX-16 | setup-user-shell.sh, .ps1 | none | `bash -n`; parser; `AITOOLS_DRY_RUN=1 AITOOLS_PROFILE_DIR=<tmp> bash scripts/setup-user-shell.sh` -> no file, OK row | no writes in dry run |
| F17 | `fix/hooks-skills-parity` | FX-15, FX-40, FX-42 | setup-user-hooks.sh, .ps1, setup-user-skills.sh (rows: + .ps1 in a 2nd commit) | D5 | `bash -n`; parser; new case: settings.json changes -> one `.bak.*`, unchanged -> none; shared `foo` + dotprofile `Foo` -> one deploy | backup on change; mv rc checked -> log_error + ERROR row |
| F18 | `fix/cursor-ide-mcp-parity` | FX-18 | setup-cursor-ide-mcp.sh, .ps1 | D7 probe | `bash -n`; parser; probe `agent mcp remove vercel` on a scratch HOME | WriteAllText checked; ERROR row when errors rose |
| F19 | `chore/untrack-hook-backups` | FX-37 | .gitignore, 2 `git rm` | none | `git ls-files -ci --exclude-standard` lists exactly the two files before the rm, none after | n/a |
| F20 | `fix/sog-later-lines` | FX-38 | shared/hooks/standing-order-guard.sh, .claude/rules/hook-rollout.md | G-P for the doc row | `.scratch/session-rcfixk/test-sog.sh` 16/16 on bash 5 and /bin/bash 3.2; hook-rollout.md "Pre-deploy verification" steps 1-4 | observe mode logs, exits 0 |
| F21 | `ci/uncid-suites` | FX-14 (+ FX-3's pty case when it exists) | .github/workflows/check.yml | re-anchor after #112, #116 | YAML parse (`.scratch/session-rcfixk/yaml-steps.rb`); first CI run green | n/a |
| F22 | `fix/path-refs-bare` | FX-39 | scripts/check-path-refs.py, scripts/check-path-refs-allow.txt | D12 | `.scratch/session-rcfixk/test-pathrefs.sh`; full tree 0 dead; `bash scripts/check-pre-commit.sh` step 20 | n/a (py; errors exit 2 unchanged) |
| F23a-c | `fix/scratch-pointer-readers-{1,2,3}` | FX-5b | (a) block-claude-code-guide.sh, block-explore-agent.sh, command-channel-stop.sh; (b) delegation-duty-guard.sh, glossary-skill-guard.sh, sh-file-fixup.sh; (c) standing-order-guard.sh, intelligence-stop.py, harness-db.py (+ scratch-init.sh in F23c's 2nd commit) | D1; after F5, F20 | the two-session test (K); each hook's smoke test (hook-rollout.md) | per hook |
| F24 | `fix/harvest-worktrees` | FX-13 | scripts/ait-harvest.py, shared/hooks/standing-order-guard.sh (or a new hook + hooks-manifest.json) | D4; after F5, F23 | worktree fixture test (K) | observe-mode warning only |
| F25 | `fix/ai-merge-diff-parity` | FX-9 | aitools-lib.sh, .ps1 | after F8 | sample prompts through both twins (agentic-standards "Prompt evaluation"); `grep -c "local vs source" scripts/aitools-lib.*` = 0; managed-files suites | validation unchanged; no `[m]` without a diff |
| F26 | `fix/read-session-answers` | FX-20 | scripts/read-session.py (+ a fixture under tests/) | none | fixture: an AskUserQuestion answer prints as COMMANDER (answer); sidechain skipped | n/a |
| F27a-n | `fix/grep-q-herestring-<n>` | FX-21 | 54 sites, <= 3 files per PR, check-pre-push.sh/.ps1 first | none | per file `bash -n`; probe-grepq.sh pattern on each changed line | here-strings; no new suppressions |
| F28 | `fix/cursor-rule-kind` | FX-41 | setup-user-cursor.sh, .ps1 | #110 + FAN-PLAN A + F4 merged | tests/rules-fanout-cursor + `UP.MD` / `x.BAK.1` cases | n/a |
| F29 | `fix/ps-try-finally-audit` | FX-44 | aitools.ps1, aitools-lib.ps1 | after F15 | parser; probe per site | catch logs + ERROR row |
| F30 | `fix/backup-dir-prune-order` | FX-45 | aitools-lib.sh, .ps1 | after F8 | test-lib-drafts.sh / .ps1 extended | per C |
| F31 | `test/mdm-precondition-adopt-push` | FX-46 | tests/deploy-harness-mdm/test-deploy-harness-mdm.sh, tests/deploy-harness/test-deploy-harness.sh | #103 merged (adopt case) | both suites | n/a |
| F32 | (probe) | FX-43 | aitools-lib.ps1 if confirmed | pty probe | tests/managed-files/pty-run.py driving pwsh | per result |
| F33 | `fix/cursor-relay-mirror` | FX-19 | per D8 option | D8 + canary | tool-ops-cursor.md "Verification (manual canary)" | per option |
| F34 | `fix/build-lib-once` | FX-35 | scripts/build-deploy.sh | D3 (defer) | sizes drop; tests/claude-mdm; pre-push step 7 smoke under isolated HOME | per C |

Docs batches. Protected files ship under G-P: a version plus "Review after" in the PR body (MERGE-ALL A2) once `.claude/rules/sources-of-truth.md` carries review-after. Until then they are drafts.

| Batch | Branch / PR | Items | Files | Gate | Verification |
|---|---|---|---|---|---|
| DX1 | in R2b's PR (`docs/reconcile-fanout-today`) | FX-48, FX-60, FX-72 | .claude/rules/aitools-workspace.md, reference/harness.md | R2b's gate + G-P; D15 | D items' greps; apply on the R2b-edited files |
| DX2 | `docs/fix-handoff-skill` | FX-49, FX-50, FX-66 (DQ14) | shared/skills/handoff/SKILL.md | DQ14 part: D16 | `git grep -n -i "deleted by the" -- shared/skills/handoff/SKILL.md` = 0 |
| DX3 | `docs/fix-delegate-skill` | FX-51, FX-52, FX-63 (D51 part) | shared/skills/delegate/SKILL.md | MERGE-ALL D-DEL5 landed (pull, re-anchor) | D greps |
| DX4 | `docs/fix-tool-ops-cc` | FX-56, FX-63 (D201b), FX-70 | reference/tool-ops-claude-code.md, shared/skills/aitool-ops/SKILL.md | G-P; coordinate with FAN-PLAN's #28 | `git grep -n "No follow-up" -- shared/skills reference` = 0 |
| DX5 | `docs/fix-claude-shared` | FX-57, FX-63 (D51) | shared/claude-shared.md (+ dotprofile `claude/CLAUDE.md`, committed to the dotprofile's main, N-Q2) | G-P | `git grep -c "always uses Git Bash" -- shared/claude-shared.md` = 0; diff against the dotprofile line |
| DX6 | `docs/fix-config-xplat-postpush` | FX-54, FX-55, FX-53 | .claude/rules/config-file-safety.md, reference/cross-platform-detail.md, reference/post-push-checklist.md | G-P; FX-53's step-7 line after F1 | D greps |
| DX7 | in R7a's PR | FX-59 | reference/cursor-practices.md | R7a gate (Q9) | `git grep -c "SQLite" -- reference/cursor-practices.md` = 0 |
| DX8 | `docs/fix-deploy-paths-limits` | FX-61, FX-74 note | .claude/rules/deploy-paths.md | G-P; after R4; pull (BUILD-PKG) | `grep -c "### MDM path limits"` = 1; pre-commit step 20 |
| DX9 | `docs/fix-tool-registry-skill` | FX-62 | .claude/skills/tool-registry/SKILL.md | none | `grep -c "not a per-tool section"` = 1 |
| DX10 | `docs/fix-adopt-filter` | FX-69 | reference/managed-file-deployment.md, .claude/rules/managed-file-deployment.md, .cursor/rules/managed-file-deployment.mdc | R2c merged + G-P | `git grep -n "ADOPT_TRANSFORM\|AdoptTransform\|adopt_claude_md" -- reference .claude/rules .cursor/rules` = 0 |
| DX11 | `docs/fix-sot-shared-rules` | FX-65 | .claude/rules/sources-of-truth.md | after MERGE-ALL's review-after edit | `grep -c "shared/rules/\*.md"` = 1 |
| DX12 | `/glossary` run (one PR) | FX-64 | registries/glossary.json (skill), .claude/rules/glossary.md | G-P; step 9 after #100 / FAN-PLAN A | skill validation; JSON parse; `grep -c "auto-merge menu"` = 0 |

Handed to others (no batch here):
- FX-58 goes to the reference/rules.md owner.
- FX-67 waits on #108/#114 and D17.
- FX-68 is MERGE-ALL's, before #106 merges.
- FX-71 waits on FAN-PLAN's skills half.
- FX-73 goes into R8c-d2.
- FX-74 is a note for FAN-PLAN C13.
- FX-75 follows F20.

## 6. Decisions needed (each with a suggested answer)

- **Q11 (plan; FX-2):** pre-commit `--fix` and the githook stop rebuilding and staging. *Suggested:* yes, as drafted.
- **D1 (FX-5b):** hooks derive their scratch dir from stdin `session_id`, using the pointer only as a fallback. *Suggested:* yes.
- **D2 (FX-10):** should bootstrap stop on an installer exit 2? *Suggested:* not now (parity with bootstrap.sh); revisit with R8c.
- **D3 (FX-12, FX-35):** oversized generated scripts: WARN or FAIL? Dedupe the lib now? *Suggested:* WARN, and defer the dedupe until BUILD-PKG says whether the per-script MDM route stays.
- **D4 (FX-13):** harvest worktree scratch into the main checkout, plus an observe warning on `git worktree remove`? *Suggested:* yes to both.
- **D5 (FX-15):** bash settings.json backup: temp-file write, or a backup on every run? *Suggested:* temp-file (backup only on change, PS parity).
- **D6 (FX-17):** should the installers also export `AITOOLS_DEPLOY_IN_PROGRESS`? *Suggested:* yes, same PR.
- **D7 (FX-18):** first probe whether `agent mcp remove` edits `~/.cursor/mcp.json`. *Suggested:* probe on a scratch HOME; if it does, stop writing vercel/webflow there and drop the remove step.
- **D8 (FX-19):** what to do with the Cursor relay mirror. *Suggested:* run the canary (about 5 minutes, `agent login`); if the gap is confirmed, convert it to `~/.cursor/rules/aitools-relay.mdc`.
- **D9 (FX-31):** do environment credentials count as signed in? *Suggested:* yes.
- **D10 (FX-34):** which deploy order wins? *Suggested:* the `aitools` sync loop's.
- **D11 (FX-36):** treat `msg-*` and `pr-body*` names as ephemeral, reversing the skill's "msg-fix.txt is harvested"? *Suggested:* yes.
- **D12 (FX-39):** accept the wider step-20 scan for bare paths? *Suggested:* yes, with the allowlist for planned files.
- **D13 (FX-42):** should adopted user hooks reach other machines? *Suggested:* no (SD-2); take the one-line wording only.
- **D14 (FX-51):** turn on GitHub `delete_branch_on_merge`? *Suggested:* not while MERGE-ALL runs.
- **D15 (FX-60):** widen harness.md's intent, or move the section? *Suggested:* widen.
- **D16 (FX-66, plan Q14):** *Suggested:* the user-rule line goes in MERGE-ALL's D-DEL5 commit; DQ14 covers /handoff.
- **D17 (FX-67):** should script-standards recognise "library-style tool"? *Suggested:* yes, named scripts only, folded into logging.md section 7.
- **D18 (FX-75):** narrow the guard for multi-range read-only `sed -n`? *Suggested:* yes (a narrowing change, mode stays enforce).
- **D19 (FX-70):** who lands item #28? *Suggested:* whichever lands first uses D28's verified text.
- **D20 (F-batches merging, extends plan Q15):** who merges the F PRs? *Suggested:* the executing SC's mission, with merge commits, after green CI and an independent reviewer's verdict.
- **D21 (#33, ledger):** keep #33 open? *Suggested:* yes (see section 7).

## 7. Ledger-closing work that stays in R13 L0

- **Close (19):**
  - The Ledger's 17 (its section 3 table, unchanged since its base: no `scripts/` code those rows cite changed between 8953371 and 9861ff7, except `scripts/aitools-profile.*`, which only #74 cites, and #74 is an update): #129, #130, #84, #93, #114, #115, #122, #75, #97, #78, #95, #98, #109, #110, #99, #111, #145.
  - **#86:** fixed in build-deploy.sh (staging dir, then swap), PR #95.
  - **#94:** fixed by 378423c (PR #70). `git log -S "Deployment pattern updates"` on managed-file-deployment.md/.mdc; no citation is left in `.claude/rules`, and only the `.mdc` heading exists.
- **Not closable: #33.** Its "structural fix" claimed every template was extracted, but `.claude/rules/deploy-paths.md` "Scripts with deploy templates" still lists `setup-user-hooks.sh/.ps1` as duplicated (hook embedding + REGS_JSON). Keep it open, or update it to name setup-user-hooks as the residual.
- **Close later:**
  - #112 after R6 step 1.
  - #216 after #111 merges.
  - #76's last doc line after R2c.
  - #191/#192 after R9/R10.
  - Every Ledger draft #171-#217 is not filed (commander decision 3); each is resolved by its FX instead.
- **Updates that stay as ledger work:** the 4.3 rows for #74, #76, #77, #102, #116, #144, #87, #105 and #51. #73 and #105 also get fixes here: FX-36 and FX-62.
- **R13-pre is still live:** #102 merged at 9861ff7, but `registries/incidents.json` is unchanged (145 ids, max 145; python parse of origin/main). The #165 ERROR decision and the #166 two-keys case must reach MERGE-ALL before its apply step. If the batch is applied first, they become L0 updates.

## 8. Verification summary (S3-Reconcile-Fix's own runs)

- **Re-apply on origin/main 9861ff7:** `high/tests/apply-refs.sh` via `.scratch/session-rcfix/reapply-all.sh`. All 37 main-based draft files apply.
  - high: 5 files, 17 blocks.
  - code: 7 files, 48 blocks.
  - checks: 9 files, 38 blocks.
  - docs: 14 files, 39 blocks.
  - Syntax: `bash -n` and the pwsh parser pass on every .sh/.ps1 output, and py_compile passes on ait-harvest.py and check-path-refs.py.
  - `edits-pr106.txt` and `edits-pr111.txt` were applied by S3-Reconcile-Fix-Code on their PR heads, not re-run here.
- **Overlapping batches applied together** (`.scratch/session-rcfix/combo.sh`):
  - post-push (step 7 + PP-1..8): 10/10.
  - lib + entry + sigpipe: 17/17. `bash -n` and the parser pass on all 5 outputs.
- **High-item tests:** listed in section 3. Throwaway clone and HOMEs under `/tmp/rcfix.d9tMHy`. Nothing ran against the real HOME.
- **Sub-delegate suite runs:** in the C and K files. The repo suites give the same counts patched and unpatched, and the harvester, hook, regex and path-refs probes are listed there.

## 9. Not verified

- **Windows:**
  - No `.ps1` change ran natively; every one is parser-checked on macOS pwsh 7.6.3 only.
  - Not run on Windows: bootstrap on a fresh VM, Find-GitBash paths, dashboard `-Stop`, setup-cursor-ide-mcp with `agent`.
  - Linux: not run.
- **Not run end to end:**
  - check-post-push and check-pre-commit against the real HOME. The isolated-clone runs stand in for them.
  - check-pre-push.
  - CI for FX-14.
- **Not tested together:** all open PRs merged at once with the drafts. Code tested each PR merged alone with main.
- **Unverified facts:**
  - Which file `agent mcp remove` edits (D7).
  - Whether SessionStart hooks fire inside `claude -p --no-session-persistence` (FX-17's case).
  - `claude auth status` exit code when logged out.
  - The Jamf script size limit.
  - Whether user-level rule subdirectories load.
  - Item #1 on Windows.
  - FX-43 (needs a pty).
  - FX-19 (needs the canary).
- **Specs only, no drafts:** FX-5b, FX-9, FX-13, FX-20, FX-21, FX-35, FX-41, FX-44, FX-45, FX-46, FX-58, FX-67, FX-71, FX-72, FX-75, FX-76.

## 10. INCIDENT markers found by this mission (not filed; each is already an FX above)

- INCIDENT: check-script-compliance.sh comment filter never matches after `grep -n` (6 sites); post-push step 23 FAILs on main today (FX-7).
- INCIDENT: post-push step 24 has the same prefix bug (FX-76).
- INCIDENT: read-session.py drops AskUserQuestion answers (FX-20).
- INCIDENT: `printf | grep -q` under pipefail, 54 sites (FX-21).
- INCIDENT: try/finally without catch (FX-44); Backup-Dir prune order (FX-45); mdm test precondition (FX-46); setup-user-skills resolver rows (FX-40); /aitool-ops card stale (FX-56); documentation-standards vs rules.md R-4 (FX-71); `/artifact-roles` missing (FX-72); config-file-safety backup non-fatal vs code (FX-54); guard blocks multi-range `sed -n` (FX-75).
- INCIDENT (tooling): the sub-delegates had no Grep/Glob (#51 recurrence, FX-63). Isolated builds leak `build-deploy.*` temp dirs until #111 merges (#216).

## 11. Delegates and provenance

- S3-Reconcile-Fix-Code (level 3, code area): `S3-Reconcile-Fix-Code-items.md`, `S3-Reconcile-Fix-drafts/code/`; scratch `.scratch/session-rcfixc/`.
- S3-Reconcile-Fix-Checks (level 3): `S3-Reconcile-Fix-Checks-items.md`, `S3-Reconcile-Fix-drafts/checks/`; scratch `.scratch/session-rcfixk/`.
- S3-Reconcile-Fix-Docs (level 3): `S3-Reconcile-Fix-Docs-items.md`, `S3-Reconcile-Fix-drafts/docs/`; scratch `.scratch/session-rcfixd/`.
- S3-Reconcile-Fix: the high items, FX-7, FX-76, this file; scratch `.scratch/session-rcfix/`; tests copied to `S3-Reconcile-Fix-drafts/high/tests/`.
- Spot-checks of delegate claims: section 1. Every delegate reported no WRITE_BLOCKED.
- No repo file outside the S3-Reconcile folder was changed. The temp dirs under /tmp are left in place.
