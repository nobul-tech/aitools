# Incident Registry Audit Report

**Date**: 2026-03-16
**Auditor**: Incident Registry Auditor (S2)
**Scope**: All 42 open incidents in `reference/incidents.json`
**Method**: Direct codebase inspection via Read/Grep/Glob against each incident's affected files, observations, and described patterns

---

## Summary

| Classification | Count | IDs |
|---|---|---|
| STILL OPEN | 25 | 3, 4, 5, 6, 7, 9, 10, 11, 16, 19, 20, 21, 22, 23, 24, 26, 27, 29, 34, 35, 37, 38, 43, 44, 45 |
| SILENTLY RESOLVED | 8 | 8, 15, 17, 18, 32, 36, 40, 47 |
| NEEDS UPDATE | 6 | 1, 2, 25, 28, 30, 33 |
| STALE | 3 | 39, 41, 46 |

**Note**: NEEDS UPDATE incidents remain open but their descriptions are partially outdated or they have status/linked field issues. The deduplicated totals: 25 purely still open + 6 needing description updates = 31 remaining open, 8 silently resolved, 3 stale.

---

## Detailed Findings

### SILENTLY RESOLVED (8 incidents -- close these)

| ID | Title | Severity | Evidence |
|---|---|---|---|
| **15** | Skill deployment hardcoded for 2 skills | high | `setup-user-skills.sh/.ps1` created with dynamic discovery from `shared/skills/`. Wired into entry points (`scripts/aitools`, `scripts/aitools-install.sh`). Skill deployment code removed from `setup-user-mcp.sh` (grep confirms zero `deploy_skill` calls). Commit `22252da`. |
| **17** | Bridge pattern cross-reference points to missing section | low | `reference/script-standards-detail.md` line 827 now has heading `### Bridge pattern (check scripts exercising lib functions)`. Cross-reference valid. |
| **18** | Skills claimed discoverable but deployment infrastructure missing | medium | Resolves with #15. `~/.claude/skills/` contains 8 deployed skills: a11y-debugging, chrome-devtools, intent-audit, intent-writing, investigate, optimize-plan, planning, scratch. |
| **8** | Sessions feature silently fails without userRepoPath | medium | Both `scripts/aitools` (lines 1125-1130) and `scripts/aitools.ps1` (lines 1071-1074) now check `userRepoPath` and exit with `log_error`/`LogError` + clear remediation message. Both platforms fixed. |
| **32** | Silent hook failure: session-archive hook was no-op | high | `scripts/aitools` lines 1125-1130 now checks `userRepoPath` and exits with `log_error` if missing. The corrective action field already says "User ran aitools user init." Rule `.claude/rules/surface-silent-failures.md` does not exist (was never created), but the technical fix is in place. |
| **40** | Verification failure: regex test output not checked for completeness | high | Behavioral incident from 2026-03-01. The specific bug (v0.27.4 regex) was fixed in v0.27.5. Coaching bullet about counting expected matches is behavioral -- no code artifact to track. |
| **36** | Unnecessary @import of CC version-deps file in CLAUDE.md | medium | CLAUDE.md has zero `@reference/tool-ops-claude-code` or `@import` references. File is 170 lines (under 200 limit). The file is mentioned inline at line 138 as a plain reference (not an @import that pulls content). |
| **47** | PS1 -replace chain ordering bug | high | `check-post-push.ps1` step 26 (lines 787-788, 805) now uses Perl for basename extraction instead of PS1 -replace chains. Matches bash approach. |

### STILL OPEN (25 incidents -- verified still present)

| ID | Title | Severity | Current State |
|---|---|---|---|
| **1** | Hook scripts deployed without backup or interactive review | high | `setup-user-hooks.sh` line 125 now uses `deploy_managed_file` for hook scripts. `setup-user-hooks.ps1` line 120 uses `Deploy-ManagedFile`. **NEEDS UPDATE**: The observation says "use direct cp/Copy-Item" but this has been upgraded. However, the settings.json merge (JSON config part) may still lack backup -- needs verification. Consider partial resolution or re-scoping. |
| **2** | Bash scripts missing backup_file before JSON config merge | medium | `setup-user-mcp.sh` line 184 DOES call `backup_file "$settings_file"`. `setup-user-hooks.sh` -- need to verify. **NEEDS UPDATE**: At least setup-user-mcp.sh is fixed. Check if setup-user-hooks.sh is also fixed. |
| **3** | JSON config merges have no interactive review | medium | No field-level review UI exists. Setup scripts use clobber detection (error on field loss) but no "here is what will change" prompt. Rule `.claude/rules/interactive-menus.md` specifies the pattern but no script implements it. Still valid. |
| **4** | Cursor MCP disable is project-scoped, not user-scoped | high | `setup-cursor-ide-mcp.sh` line 178 still calls `agent mcp disable` per-project. The architectural limitation persists -- Cursor stores MCP state per-project, not per-user. Still valid. |
| **5** | Directory backups cascade | low | `scripts/aitools-lib.sh` `backup_dir()` (line 289) uses `cp -R "$dir"` with no exclusion of `.bak.*` patterns. Each backup still contains previous backups. Still valid. |
| **6** | README 22 versions behind | high | `README.md` is 150 lines. Last committed change to README was at v0.33.0 (commit `7a9316b`). No commits to README since. Current version is much higher. Still valid. |
| **7** | AITOOLS_FORCE/DRY_RUN/RUN_ID env vars undocumented | medium | Grep of README.md shows zero matches for AITOOLS_FORCE, AITOOLS_DRY_RUN, or AITOOLS_RUN_ID. Still undocumented. CLAUDE.md mentions `--dry-run` and `--force` flags but not the env vars. Still valid. |
| ~~8~~ | ~~Sessions feature silently fails without userRepoPath~~ | ~~medium~~ | **Moved to SILENTLY RESOLVED** -- both bash and PS1 now check and fail with clear error. |
| **9** | Entry point logging override pattern has unclear design intent | medium | `scripts/aitools` lines 62-68 redefine `log`, `log_ok`, `log_error`, `log_warn` after sourcing aitools-lib (line 1331 calls `logging_init`). But `log_detail` (aitools-lib line 97) is NOT overridden. The design intent is still undocumented. Still valid. |
| **10** | No CI pipeline | high | `.github/workflows/` directory does not exist. No GitHub Actions. All verification remains manual check scripts. Still valid. |
| **11** | CLI entry point behavior only discoverable by reading source | medium | No `/aitools` skill exists. No user-facing documentation of entry point dispatch logic. Still valid. |
| **16** | No meta-skill for teaching ambiguity detection | low | No such skill exists. Still valid (though low priority). |
| **19** | Reference file placed without evaluating alternatives | medium | `reference/path-targeted-hooks-analysis.md` still exists. No evidence the placement was evaluated post-filing. Still valid. |
| **20** | No process discipline rule governs plan adherence | high | `reference/incident-020-process-discipline.md` exists (reference file). No `~/.claude/rules/process-discipline.md` user-level rule was created. No design principle added to CLAUDE.md. The reference file documents the discovery but the resolution (creating the rule) was never executed. Still valid. |
| **21** | Tool registry is markdown -- needs three-layer migration | medium | `reference/tool-registry.md` is still the primary tool registry (no `reference/tool-registry.json` exists). `reference/tool-versions.json` exists separately. Two sources that can drift. Still valid. |
| **22** | Incident registry has no read/context skill | medium | `.claude/skills/incident/SKILL.md` exists (filing skill). No `.claude/skills/incidents/SKILL.md` (read skill) exists. Still valid. |
| **23** | Credential storage undocumented; keychain prompts block install | high | `setup-gh-cli.sh` has no auth check at all (line 9: "Auth handled by aitools-install Step 2"). `setup-datadog.sh` lines 138-144 still use `pup auth status` which invokes keychain. No documentation of credential storage strategy. Still valid. |
| **24** | Rules lack trigger directives governing skill invocation | high | Only 3 rules have "When to invoke" sections: `glossary.md`, `frameworks.md`, `tool-ops.md`. The 6 affected rules (script-standards, tool-lifecycle, sources-of-truth, interactive-menus, agentic-standards, cross-platform) still lack trigger directives. Still valid (though partially resolved -- 3 of ~9 done). |
| **25** | Deploy hooks template embeds 2 of 6 hook scripts | high | `build-deploy.sh` now reads 4 hooks at top (lines 68-71: session-archive, standing-order-guard, sh-file-fixup, surfacing-duty-stop) but the deploy template (lines 1172-1197) still only embeds 2 (session-archive, standing-order-guard). **NEEDS UPDATE**: Description says "embeds only 2 of 6" and build reads 2. Now build reads 4 but still embeds only 2 in the template. 9 hook scripts exist in shared/hooks/ total. |
| **26** | Deny rule bypass -- permissions.deny doesn't block built-in subagent types | critical | `shared/hooks/block-claude-code-guide.sh` exists and is deployed. The corrective action is in place. However, this is an upstream CC limitation that hasn't been fixed. The hook is a workaround, not a fix. Still valid as long as the upstream issue persists. |
| **27** | Glossary skill guard hook registered but never deployed to disk | high | Linked to #25. `shared/hooks/glossary-skill-guard.sh` exists in source. Build-deploy only embeds 2 hooks. This hook is not deployed via MDM. Still valid. |
| **29** | Subagent context gap: rules/CLAUDE.md not inherited by Task subagents | medium | Upstream CC limitation. `shared/claude-shared.md` line 109 has the coaching bullet about hooks for context injection. No upstream fix confirmed. Still valid. |
| **34** | Plan drafted with unguarded error-suppression patterns | high | Behavioral/process incident. Rule scope was broadened to cover plans. The rule exists. Whether the behavior has changed is not verifiable from code. Still valid as a tracking item. |
| **35** | Plan revision uses grep-for-keywords instead of full re-read | medium | Behavioral incident. No code artifact to verify. Still valid as a tracking item. |
| **37** | PSO: Plan showed full bash code but summarized PS1 as bullet points | medium | Behavioral incident. No code artifact to verify. Still valid as a tracking item. |
| **38** | Error handling violations in plan-phase code -- plan v4 | high | Behavioral incident. Rule scope broadened. Whether the behavior pattern recurs is not verifiable from code. Still valid as a tracking item. |
| **43** | USO: Used && chaining and $() in Bash tool call | medium | Behavioral incident. No code artifact to verify. Still valid as a tracking item. |
| **44** | Error suppression in lib code during Batch 3 | high | Behavioral incident about the pattern of writing error-suppression violations. The specific violations were likely fixed in the same session. The incident tracks the recurring pattern (4th occurrence). Still valid as a pattern tracker. |
| **45** | USO: Semicolon chaining in git workflow | medium | Behavioral incident. No code artifact to verify. USO exists and is enforced. Still valid as a tracking item. |

### NEEDS UPDATE (6 incidents -- still open but descriptions outdated)

| ID | Title | Issue |
|---|---|---|
| **1** | Hook scripts deployed without backup or interactive review | `setup-user-hooks.sh` now uses `deploy_managed_file` (line 125) for hook scripts -- this part is RESOLVED. But `setup-user-hooks.sh` still has NO `backup_file` call before the settings.json Node.js merge (line 192+). Re-scope to cover only the JSON settings merge backup gap. |
| **2** | Bash scripts missing backup_file before JSON config merge | `setup-user-mcp.sh` line 184 now calls `backup_file` -- this script is FIXED. `setup-user-hooks.sh` still has NO `backup_file` call before settings.json merge. Update affected list to remove setup-user-mcp.sh, keep setup-user-hooks.sh. |
| **25** | Deploy hooks template embeds 2 of 6 hook scripts | Build now reads 4 hooks at top (lines 68-71: session-archive, standing-order-guard, sh-file-fixup, surfacing-duty-stop) but template (lines 1172-1197) still embeds only 2 (session-archive, standing-order-guard). 9 hook scripts now exist in shared/hooks/ (was 6). Update counts and hook inventory. |
| **28** | Batch size caused cross-cutting rules skipped | Status is "planned" with null linked field (violates lifecycle rule). Has corrective action in place (coaching bullet in shared/claude-shared.md line 106). Consider closing since remediation was applied, or revert to "open" and link properly. |
| **30** | Dismissiveness when user challenged subagent results | Status is "planned" with null linked field (violates lifecycle rule). Has corrective action in place (USO in shared/claude-shared.md line 122, coaching bullet line 113). Consider closing since remediation was applied. |
| **33** | Deploy template logic not updated when scripts/ source fixed | Status is "planned" with null linked field (violates lifecycle rule). Has corrective action (sentinel-based extraction in build-deploy.sh, pre-commit step 13). Consider closing since structural fix and detection layer are both in place. |

### STALE (3 incidents -- consider closing)

| ID | Title | Severity | Rationale |
|---|---|---|---|
| **39** | Skipped checklist scripts during commit+push cycle | high | Behavioral incident from 2026-03-01. The git conventions section is now in CLAUDE.md (line 158-159). PreToolUse hook on Bash for git commands is planned in the governance framework but not built. The specific incident was a one-time failure. Close as behavioral remediation applied (commitment + CLAUDE.md rule). |
| **41** | USO: Inline complex scripts in Bash tool | medium | Behavioral incident from 2026-03-01. USO exists and is enforced. The specific violation was a one-time event. Pattern tracked by other incidents (43, 46). Close as duplicate pattern -- tracked by #43 and #46. |
| **46** | USO: Heredoc in Bash tool to write multi-line file | medium | Behavioral incident from 2026-03-11. USO exists and is enforced. Same pattern as #41 and #43. Close as duplicate pattern -- tracked by #43. |

---

## Cross-Cutting Observations

### Behavioral incidents cluster

Incidents 28, 30, 31, 34, 35, 37, 38, 39, 40, 41, 43, 44, 45, 46 are all behavioral/process incidents tracking agent failures (USO violations, planning failures, verification gaps). They have no affected files and no code-level fix. They serve as a learning log. Consider:
- Consolidating duplicates (41, 43, 46 are all "USO: don't inline complex scripts")
- Closing those with corrective actions already applied (28, 30, 31, 33)
- Keeping the pattern-tracking ones open as reminders (34, 38, 44)

### "Planned" status with null linked field

5 incidents have status "planned" but `linked: null`: #28, #30, #31, #32, #33. The lifecycle spec says "planned" means "linked to a roadmap item or plan." These violate the lifecycle rule. Either link them or revert to "open."

### Incident #8 confirmed resolved

Both `scripts/aitools` (lines 1125-1130) and `scripts/aitools.ps1` (lines 1071-1074) now check `userRepoPath` and exit with clear error message and remediation guidance.

### Incidents #1 and #2 partially resolved

The hook deployment scripts were upgraded to use `deploy_managed_file` and `backup_file`. The incidents' observations describe the old state. They need re-scoping or closing.

---

## Recommended Actions

1. **Close 8 silently resolved**: #8, #15, #17, #18, #32, #36, #40, #47
2. **Close 3 stale**: #39, #41, #46 (behavioral duplicates with remediation applied)
3. **Close 3 "planned" with corrective actions complete**: #28, #30, #33 (status "planned" with null linked field violates lifecycle; corrective actions already applied)
4. **Update 3 descriptions**: #1, #2, #25 (partially resolved, observations stale)
5. **Fix "planned" status on #31**: status is "planned" with null linked field -- either link or revert to "open"
6. **Consolidate behavioral cluster**: Consider grouping 34/35/37/38/43/44/45 under a single "behavioral patterns" tracking mechanism

**Net result if all recommendations applied**: 42 open -> 25 remaining open (after closing 14 + updating 3)
