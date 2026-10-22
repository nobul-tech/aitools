# S3-Incidents review: incidents #87-#145 applied to registries/incidents.json

**Mission:** INCIDENTS (S3-Incidents, Session Commander 10cf255a-c) · **Date:** 2026-10-21 · **Baseline:** origin/main db4b3c5 · **Branch:** docs/incidents-87-plus-apply

## What was applied (commander approval 2026-10-21, items a-c)

- (a) The S3-Ledger batch #87-#128 (merged PR #57), with the PR #57 reviewer's fixes:
  1. `linked` set to null on 30 entries that pointed at unapproved draft batches or mission names; the old text moved into `suggestedResolution` as "(Draft plan reference at filing, not an approved tracker: ...)". Kept: #126 (`plans/governance-and-compliance-framework.md` 'Hook Specifications' exists, :317). No batch entry had a merged PR or open GitHub issue tracking it.
  2. Citations re-checked against db4b3c5. `git diff --stat c8573ed db4b3c5` touches only five live files outside the mission folders (reference/tool-ops-claude-code.md, scripts/setup-user-hooks.sh/.ps1, shared/hooks/standing-order-guard.sh, shared/skills/delegate/SKILL.md). No batch entry cites line numbers in those files, so the S3-Ledger line references on c8573ed still hold; every entry's discoveryContext says so. Rewrites: #113 (#80 now fixed and closed), #126 (the open question about a git checklist reminder answered: there is none), #128 (delegate skill re-checked after PR #54), #87 (cites the now-approved D-TS13), #95 (+ Related #76), #98 (live instances, see below). Everything PR #56 fixed (#80, #81, #82) is closed with PR #56 as correctiveAction, after verification.
  3. Id #113 kept for the first S2-Layout finding.
- (b) `affected` updates for #21, #55, #59, #76 (S3-Ledger-affected-updates.json, observation appends included) and the optional #51 recurrence note. #76 also got a line-reference refresh (fallback chain at build-deploy.sh:220-222) and a pointer to #95.
- (c) 17 new entries #129-#145 from the commander's list, each verified against db4b3c5 code first.

Registry after apply: 138 entries in `incidents`, 7 in `closed` (13, 14, 52, 53, 80, 81, 82), ids 1-145 unique and contiguous, valid JSON. The closed entries for #80-#82 carry a `correctiveAction` field in addition to id/title/closedIn/closedDate (the brief asked for the PR as correctiveAction; no script parses `closed`).

Severity of #87-#145: 10 high, 27 medium, 22 low.

## Dedupe decisions for the commander's new-finding list

| Finding | Disposition | Why |
|---|---|---|
| Accepted-but-not-adopted merges reverted | new #129 | No registry entry or issue covers it |
| Deploy state needs node; .corrupt rename | new #130, linked issue #30 | #30 covers the per-file node calls, not initialize_deploy_state |
| aitools-install.ps1 Step 6 no diff | new #131 | Distinct from #125 (refresh timing) |
| build-deploy.sh "Nobul" default + first-profile fallback | merged into #95 and #76 | #95 is the hardcoded defaults (:198-201); #76 is the first-profile fallback; #76 observation refreshed |
| inline_lib_bash matches the delegation-duty-guard.sh comment | merged into #98 | Same defect; #98 rewritten with two verified live instances (also shared/skills/aitool-ops/SKILL.md:280) |
| MDM never deletes retired hooks | new #132 | Related #119 (skills) |
| harvesting .sh tracked 100644 | new #133 | |
| Secret pattern `[\s]` | new #134 | Probe also found false negatives ('token = x') |
| Step 10 git -C walk-up | new #135 | |
| Pre-commit step 3 --fix real HOME | new #136 | Ties #86 |
| Step 7 PS1 top-level only | new #137 | |
| Guard ';' exemption bare word | new #138 | |
| Workflow agents lack Agent/Workflow | new #139 | Partial fix PR #54/#59 recorded |
| Worktree isolation refuses HOME | new #140 | Partial fix PR #54/#59 recorded |
| READY from issue state (#32) | new #141 | |
| validate_and_run dual ERROR rows | new #142 | Related issue #26 item e |
| ensure_tool_on_path empty array | new #143 | Latent (both callers pass paths) |
| PRs #56/#58 merged with changes-needed reviews | new #144 | Reviewer verdict text is not in the repo; consequence (sed -i observed, not blocked) verified |
| /scratch skill vs harness | new #145 | One umbrella entry pointing at SCRATCH-RULE |

## Per-id table

| Id | Title (short) | Sev | Status | Source | Dedupe / edit note |
|---|---|---|---|---|---|
| 87 | Setup-script exit 2 ('[x]abort', documented as stop the run) is treated as an ordinary failure: both installer... | high | open | S3-Ledger batch (S4-Review) | suggestedResolution now cites approved D-TS13; linked -> null |
| 88 | setup-datadog.sh deletes (rm -f) any non-Homebrew pup binary after a Homebrew install, including binaries of u... | high | open | S3-Ledger batch (S4-Review) | linked -> null |
| 89 | Tool setup scripts ignore AITOOLS_DRY_RUN, so 'aitools install --dry-run' installs, upgrades and removes tools... | high | open | S3-Ledger batch (S4-Review) | linked -> null |
| 90 | Tool registry install-method data cannot drive automation: nonPreferredMethods[].detection holds prose or inst... | medium | open | S3-Ledger batch (S4-Review) | linked -> null |
| 91 | Installer Step 8 reports OK for any node on PATH; on nobul-mac the registry-preferred node@22 is installed keg... | medium | open | S3-Ledger batch (S4-Review) | linked -> null |
| 92 | setup-perl.sh reports ERROR 'Homebrew not found' on a Mac without Homebrew and installs Homebrew perl, althoug... | medium | open | S3-Ledger batch (S4-Review) | linked -> null |
| 93 | Framework registry 'Tool operations' entry lists reference/tool-ops.json as an artifact, a file removed in v0.... | low | open | S3-Ledger batch (S4-Review) |  |
| 94 | managed-file-deployment.md and its Cursor mirror cite a tool-lifecycle.md section 'Deployment pattern updates'... | medium | open | S3-Ledger batch (S4-Review) | linked -> null |
| 95 | build-deploy.sh hardcodes one user's identity (PROFILE_COMPANY="Nobul", IDENTITY_GIT_EMAIL="jose@nobul.tech") ... | high | open | S3-Ledger batch (S4-Review) | + Related #76 (first-profile fallback); linked -> null |
| 96 | The MDM path embeds shared/claude-shared.md while the dev path prefers <dotprofile>/claude/CLAUDE.md, so the t... | medium | open | S3-Ledger batch (S4-Review) | linked -> null |
| 97 | aitools user init writes config.json and profile.json without backup_file, and its profile write swallows erro... | medium | open | S3-Ledger batch (S4-Review) | linked -> null |
| 98 | build-deploy.sh inline_lib_bash replaces every line containing 'source' before aitools-lib.sh, comments includ... | medium | open | S3-Ledger batch (S4-Review) | absorbs the delegation-duty-guard.sh splice finding; live instances verified by isolated build; linked -> null |
| 99 | setup-user-claude.sh adopt_claude_md builds its perl program from shell values, so '@' in the email is interpo... | medium | open | S3-Ledger batch (S4-Review) | linked -> null |
| 100 | Empty catch blocks in the entry points and hh.ps1 swallow profile, gh and config errors | medium | open | S3-Ledger batch (S4-Review) |  |
| 101 | UNVERIFIED: bash 'aitools user init' on Git Bash may write userRepoPath to config.json in MSYS form (/c/Users/... | medium | open | S3-Ledger batch (S4-Review) | linked -> null |
| 102 | sources-of-truth.md omits the project skills (.claude/skills/*) and reference/tool-registry.md, while check-po... | low | open | S3-Ledger batch (S4-Review) | linked -> null |
| 103 | Summary detail text 'Max 30 characters (compliance-checked)' has no enforcing check, and runtime details excee... | low | open | S3-Ledger batch (S4-Review) |  |
| 104 | Intent statements required by D-TS9 are missing from several rules, references, every setup script and both libs | low | open | S3-Ledger batch (S4-Review) | linked -> null |
| 105 | /tool-registry skill lists delivery, health, maintenance and evaluation as required fields, but 16 of 18 regis... | low | open | S3-Ledger batch (S4-Review) | linked -> null |
| 106 | tool-evaluation.md requires every install-method decision documented in reference/evaluations/, but one evalua... | low | open | S3-Ledger batch (S4-Review) |  |
| 107 | setup-user-cursor installs ripgrep via Homebrew although ripgrep has no tool registry entry | low | open | S3-Ledger batch (S4-Review) |  |
| 108 | cross-platform.md 'One script per tool (D-ENV0)' names helpers install_via_brew / install_via_apt that do not ... | low | open | S3-Ledger batch (S4-Review) | linked -> null |
| 109 | build-deploy.sh evaluates node output with eval "$PROFILE_VALS", so $(...) inside a profile value executes at ... | low | open | S3-Ledger batch (S4-Review) | linked -> null |
| 110 | Token interpolation corrupts values containing & (bash 5.2 patsub_replacement) or $ (PS1 -replace group refere... | low | open | S3-Ledger batch (S4-Review) | linked -> null |
| 111 | ait-harvest.py reads config.json with encoding utf-8, so a BOM-prefixed file (PS 5.1) disables session archiving | low | open | S3-Ledger batch (S4-Review) | linked -> null |
| 112 | cross-platform.md says Windows repos live under C:\repos\, while CLAUDE.md, the installer and the profile desi... | low | open | S3-Ledger batch (S4-Review) |  |
| 113 | No check detects a skill name that exists at more than one level (shared/skills, .claude/skills, dotprofile cl... | medium | open | S3-Ledger batch (S2-Layout §7) | #80 noted as fixed/closed; linked -> null |
| 114 | check-post-push.ps1 still reads reference/tool-versions.json, removed in v0.69.0, so on Windows step 10 always... | high | open | S3-Ledger batch (S2-Layout §7) | linked -> null |
| 115 | No check verifies that repo paths cited in skills, rules, references, hooks and Cursor rules exist, so the v0.... | high | open | S3-Ledger batch (S2-Layout §7) | linked -> null |
| 116 | check-pre-commit step 16 (capability bypass audit) misses registries/ on PowerShell, ignores tool-ops.json and... | medium | open | S3-Ledger batch (S2-Layout §7) | linked -> null |
| 117 | dashboard-serve.sh finds generate-dashboard.py only at $HOME/repos/aitools or the current repo and exits silen... | medium | open | S3-Ledger batch (S2-Layout §7) | linked -> null |
| 118 | The MDM deploy path embeds only shared/skills, so the personal dotprofile skills that the dev path deploys nev... | medium | open | S3-Ledger batch (S2-Layout §7) |  |
| 119 | setup-user-skills never removes deployed skills that were renamed or retired, so they stay in ~/.claude/skills... | medium | open | S3-Ledger batch (S2-Layout §7) | linked -> null |
| 120 | setup-user-skills deploys only SKILL.md, dropping a skill's supporting files, and writes through ~/.claude/ski... | medium | open | S3-Ledger batch (S2-Layout §7) |  |
| 121 | The installer writes the shell rc 'source .../shared/shell/aliases.sh' line once and never rewrites it, so mov... | medium | open | S3-Ledger batch (S2-Layout §7) |  |
| 122 | /incident assigns the next id from a read of incidents.json that Read truncates at 2,000 lines and that looks ... | medium | open | S3-Ledger batch (S2-Layout §7) | linked -> null |
| 123 | The trigger rules for the cross-repo reference cards (aitool-ops.md, aitool-eval.md) are project rules, so the... | medium | open | S3-Ledger batch (S2-Layout §7) | linked -> null |
| 124 | No framework or rule governs artifact placement (user level, project level or source), so placement follows an... | medium | open | S3-Ledger batch (S2-Layout §7) | linked -> null |
| 125 | ~/.aitools/bin is written only by aitools install, so plain aitools updates leave stale helpers, and ~/.aitool... | low | open | S3-Ledger batch (S2-Layout §7) | linked -> null |
| 126 | incident-governance.md 'Hook specifications' describes hooks that do not exist in hooks-manifest.json (Subagen... | low | open | S3-Ledger batch (S2-Layout §7) | linked kept (plans file exists); git-checklist question answered |
| 127 | shared/cursor-rules/user-rules.md says setup-user-cursor copies it to the clipboard, but that workflow was rem... | low | open | S3-Ledger batch (S2-Layout §7) |  |
| 128 | /handoff tells sessions to preserve work products in tracked locations but does not warn that drafts mirroring... | medium | open | S3-Ledger batch (G17-1) | delegate skill re-checked after PR #54 |
| 129 | A merge the user accepts without adopting (Merge-Conflict [m]erge, or Auto-Merge [a]ccept with no adopt label)... | high | open | SC brief (merge-revert-test.sh) | new; no registry/issue match |
| 130 | Bash deploy state needs node: with node missing, initialize_deploy_state reads node's failure as 'manifest unr... | medium | open | SC brief | new; linked issue #30 (related node handling) |
| 131 | aitools-install.ps1 Step 6 overwrites ~/.aitools/bin helpers without logging a diff, while the bash installer ... | low | open | SC brief | new; distinct from #125 |
| 132 | The MDM path never deletes retired hook files: build-deploy.sh replaces the whole hook-deployment block, inclu... | medium | open | S3-Hooks (PR #56) | new; related #119 (skills prune) |
| 133 | harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh is tracked as 100644, so check-pre-commit step... | low | open | SC brief / packet §4 | new |
| 134 | check-pre-push.sh step 3 secret pattern uses `[\s]` inside an ERE bracket expression, so it flags words like '... | high | open | S3-Gate (PR #58) | new; false negatives found in addition |
| 135 | check-pre-push step 10 tests only that userRepoPath is a directory, so `git -C` walks up into an enclosing rep... | low | open | S3-Path32 (PR #55) | new |
| 136 | check-pre-commit step 3 --fix runs build-deploy.sh under the real HOME with its output and exit code discarded... | high | open | S3-Path32 (PR #55) | new; ties #86 |
| 137 | check-pre-push step 7 compares deploy/ recursively in bash (diff -rq) but only top-level files in PS1 (Get-Chi... | low | open | S3-Path32 (PR #55) | new |
| 138 | standing-order-guard exempts ';' only when the command starts with the bare word pwsh/powershell/perl, so `/op... | low | open | S3-Hooks / S3-Path32 | new |
| 139 | Agents launched from a Workflow have neither the Agent nor the Workflow tool, so mission commanders launched t... | medium | open | SC probe (PR #59) | new; partial fix PR #54/#59 |
| 140 | Worktree-isolated agents refuse any command that sets HOME, so they cannot follow the isolated-HOME rule for b... | medium | open | S3-Ledger, S3-Path32 (PRs #57, #55) | new; partial fix PR #54/#59 |
| 141 | Handoff open threads are classified READY from GitHub issue state alone, so a mission was launched on issue #3... | medium | open | S3-Path32 (PR #55) | new |
| 142 | When a tool script fails, the installers add an ERROR row keyed by the script's base name (setup-go) while the... | low | open | S3-Gate A-05 (PR #58) | new; related issue #26e |
| 143 | ensure_tool_on_path expands "${known_paths[@]}" unguarded, which aborts under set -u on bash 3.2 when called w... | low | open | S3-Gate-B (PR #58) | new; latent |
| 144 | PRs #56 and #58 were merged while their independent reviews reported changes needed; #56 shipped a standing-or... | high | open | SC brief | new; verdict text not in repo |
| 145 | The /scratch skill disagrees with the harness on scratch location, deletion and commit attribution | medium | open | SC brief (SCRATCH-RULE) | new; one umbrella entry |

## Independent check (S3-Incidents-Check)

Full report: `S3-Incidents-Check-report.md` in this folder. 33 file:line citations across 22 entries (11 in the new entries #129-#145, 22 in #87-#128) were read with `git show db4b3c5:<file>`, and all 33 hold. A 34th (the #143 callers) was not checked. The checker re-ran the #134 and #138 probes and got the same results. For the closures, #80 and #81 are FIXED on bash and PS1, and #82 is FIXED as stated. Because the checker found that every non-exempt sed form is unblocked in observe mode and that hook-rollout.md:79 is stale, the #82 closure text and #144 now say both. The checker found no wrong entry. It reported one gap outside the approval, which is in the report as an `INCIDENT:` marker: setup-user-skills.sh:195-200 still uses a bare `read -r choice < /dev/tty`.

## Not done

- Nothing was fixed. The /incident skill path (#84) is left to LAYOUT PR-a.
- These repros were not re-run: S5-Profile H1 and H6 (behind #98 and #99), and the Windows-only claims (#101, #114, #131 PS1 behaviour).
- #144: the reviewers' verdict text is not in the repo. The claim rests on the session commander's brief, and its consequence was verified.
