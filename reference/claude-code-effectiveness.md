# Claude Code Effectiveness Tracker

Self-assessment of how effectively Jose works with Claude Code, tracked over time.
See `shared/claude-shared.md` > Coaching section for the active improvement checklist.

## Baseline Assessment (2026-02-16)

**Rating: 8.5/10** (top tier on a curve against other users)

### Strengths

| Area | Description |
|------|-------------|
| Architectural thinking | Designs systems, not just fixes. CLAUDE.md hierarchy, build-deploy pipeline, MCP enable/disable architecture. |
| Documentation as infrastructure | Treats `CLAUDE.md`, `reference/`, `shared/` as load-bearing code. Every session starts with full context. |
| Cross-session continuity | Auto-memory + CLAUDE.md + project rules layering means minimal time re-explaining context. |
| Verification discipline | Traces execution paths, checks logs, verifies deployed artifacts rather than assuming correctness. |
| Plan-then-execute | Provides precise audit plans with file names, line numbers, severity ratings, and explicit "not fixing" lists. |
| Meta-investment | Optimizes the system (scaffolding, tooling, conventions) rather than just individual sessions. Multiplier effect. |

### Improvement Areas

| Area | Current | Target (9-10) |
|------|---------|----------------|
| Feedback loop size | Large batch plans (20+ files, 5 groups) | 2-3 file chunks with verification between each |
| Mid-session testing | Tests at end of session | Paste small test runs mid-session after each change group |
| Context management | Long sessions risk truncation | Use `/compact` or split sessions for distinct phases |
| Hooks | Not using Claude Code hooks | Pre/post hooks for auto-lint, auto-format, dangerous command blocking |
| `@` file references | Describes files by name | Use `@path/to/file` in prompts to pre-load into context |

## Progress Log

Track improvement over time. Add entries when notable changes in workflow are observed.

| Date | Rating | Notes |
|------|--------|-------|
| 2026-02-16 | 8.5 | Baseline. Strong architectural thinking and verification. Main gaps: batch size, hooks, context management. |
| 2026-02-19 | 8.5 | Session archive feature (v3.8): entry-flow review caught 3 bugs — missing uname dispatch, lossy path splitting, CRLF in .sh file. All preventable: batch size caused cross-cutting rules to be skipped despite being in context. Also discovered subagents don't inherit project rules. Strengthened coaching bullets accordingly. |
| 2026-02-19 | 8.5 | Post-session audit: subagent findings condensed away, dismissiveness when challenged, silent hook failure buried in summary. Added coaching bullets (preserve work product, standing order on user-reported problems) and surface-silent-failures rule. Technical: userRepoPath missing from config.json -- hook was a no-op. |

## Incident Tracker

Structured tracking of standing order violations, coaching failures, and behavioral
incidents. Each incident gets RCA and remediation tracking.

### Status definitions

| Status | Meaning |
|--------|---------|
| Observed | Incident logged, not yet investigated |
| RCA | Root cause identified |
| Remediated | Fix applied (code change, rule addition, hook) |
| Mitigated | Can't fully fix; risk reduced (workaround, monitoring, hook warning) |
| Accepted | Known limitation, consciously accepted with documentation |
| Verified | Fix/mitigation confirmed effective in a subsequent session |

### Incidents

| # | Date | Category | Summary | Status | Standing Order | Upstream |
|---|------|----------|---------|--------|---------------|----------|
| I1 | 2026-02-19 | Coaching | Batch size (20+ files) caused cross-cutting rules skipped despite being in context | Remediated | -- | -- |
| I2 | 2026-02-19 | Coaching | Subagent context gap: rules/CLAUDE.md not inherited by Task subagents | Mitigated | -- | [#29423](https://github.com/anthropics/claude-code/issues/29423) |
| I3 | 2026-02-19 | SO #2 | Dismissiveness when user challenged subagent results; deflected instead of investigating | Remediated | Investigate user-reported problems | -- |
| I4 | 2026-02-19 | Coaching | Subagent work product condensed to stub summary, discarding detail | Remediated | -- | -- |
| I5 | 2026-02-19 | SO #7 | Silent hook failure: session-archive hook was no-op due to missing userRepoPath, buried in summary | Remediated | No silent failures | -- |
| I6 | 2026-02-28 | Process | Deploy template logic not updated when scripts/ source fixed — recurring pattern (3+ occurrences) | Remediated | -- | v0.25.1 |
| I7 | 2026-02-28 | SO #7 | Plan drafted with unguarded `2>/dev/null \|\| true` cleanup patterns and missing exemption entries -- caught only after user requested re-audit | RCA | No silent failures | -- |
| I8 | 2026-02-28 | Coaching | Plan revision uses grep-for-keywords instead of full re-read; misses scope/order changes from user feedback during review | RCA | -- | -- |
| I9 | 2026-03-01 | Process | Unnecessary @import of reference/claude-code-maintenance.md in CLAUDE.md -- added 85 lines of maintenance-only context to every session. File already triggered by post-push checklist #20. | RCA | -- | -- |
| I10 | 2026-03-02 | SO #5 | Chained version-check commands (`&&`/`;`) in single Bash tool call; plan contained inline version checks because I8 plan revision left Batch 4 uncorrected when fixing Batch 2 | RCA | Simple Bash commands only | -- |
| I11 | 2026-03-02 | SO #5 | Used `cd /path && git status` as a compound Bash tool call during commit/push workflow — same session as I10 RCA, main agent, rule in context | RCA | Simple Bash commands only | -- |
| I12 | 2026-03-02 | Process | Hook crashed on every Bash call after MODE→per-check refactor: stale `$MODE` reference with `set -euo pipefail -u` caused immediate exit before any check ran | Remediated | -- | v0.29.2 |
| I13 | 2026-03-02 | SO #5 | Newline-separated two-command sequence in single Bash tool call (`echo ... | bash ...\necho "exit: $?"`); CC flagged "newlines that could separate multiple commands" | Observed | Simple Bash commands only | -- |

### Incident Details

#### I1: Batch size caused rule skips (2026-02-19)

- **Observed**: Session archive feature planned as 20+ file batch across 5 groups
- **RCA**: Focus narrows to feature logic in large batches; cross-cutting concerns (dispatch patterns, encoding, platform guards) get skipped even when rules are in context
- **Remediation**: Added coaching bullet "Smaller batches: 2-3 file chunks with verification between each" to `shared/claude-shared.md`
- **Status**: Remediated
- **Detection gap**: No automated check. Could be caught by transcript analysis that flags sessions with many consecutive writes without intermediate verification
- **Next step**: Explore PreToolUse hook that warns after N consecutive writes without a check/test step

#### I2: Subagent context gap (2026-02-19)

- **Observed**: Subagents launched via Task tool did not load `.claude/rules/`, `CLAUDE.md`, or `~/.claude/CLAUDE.md`
- **RCA**: Upstream limitation -- Task subagents are isolated processes with no rule inheritance
- **Remediation**: Added coaching bullet warning against delegating code-writing to subagents in projects with cross-cutting rules. Filed [#29423](https://github.com/anthropics/claude-code/issues/29423)
- **Status**: Mitigated (upstream limitation, can't fully fix)
- **Detection gap**: None feasible until upstream fixes. Coaching bullet is the mitigation
- **Next step**: Monitor #29423; re-check on CC version bumps (version-deps item #5)

#### I3: Dismissiveness on user challenge (2026-02-19)

- **Observed**: User challenged subagent audit results; Claude deflected instead of investigating
- **RCA**: Tendency to defend prior output rather than treat user feedback as signal
- **Remediation**: Added standing order #2 "Investigate user-reported problems" and coaching bullet "Clarify before complying"
- **Status**: Remediated
- **Detection gap**: Hard to detect automatically. Transcript analysis could flag responses that don't include investigation steps after user pushback
- **Next step**: None (behavioral, covered by standing order)

#### I4: Subagent work product condensed (2026-02-19)

- **Observed**: Multi-file audit by subagent produced detailed findings; main context condensed them to a stub summary discarding the detail
- **RCA**: Context pressure led to summarization that lost actionable information
- **Remediation**: Added coaching bullet "Preserve subagent work product: write full findings to plans/ or scratch file"
- **Status**: Remediated
- **Detection gap**: Transcript analysis could compare subagent output size vs. main context summary size
- **Next step**: None (behavioral, covered by coaching bullet)

#### I5: Silent hook failure (2026-02-19)

- **Observed**: Session-archive hook was deployed and appeared working, but was actually a no-op because `userRepoPath` was missing from `config.json`
- **RCA**: Hook silently exits on missing config. Feature described as "working" when it had never fired
- **Remediation**: Added `.claude/rules/surface-silent-failures.md` rule. Technical fix: user ran `aitools user init` to set `userRepoPath`
- **Status**: Remediated
- **Detection gap**: Check scripts could verify hook prerequisites (config keys present, target dirs exist). Post-push step #5 partially covers this
- **Next step**: Extend post-push step #5 to verify archive directory exists and has recent files

#### I6: Deploy template drift — recurring (2026-02-28)

- **Observed**: When fixing bugs in `scripts/setup-user-hooks.sh/.ps1` (ConvertPSObjectToHashtable array fix, mergeHookEntry logic), the corresponding template in `build-deploy.sh` was not updated. User had to remind. This is the 3rd+ occurrence of this pattern.
- **RCA**: Generated deploy scripts (`setup-user-{claude,cursor,mcp,hooks}`) have setup logic hardcoded in `build-deploy.sh` templates, duplicated from `scripts/`. Running `build-deploy.sh` faithfully reproduces stale templates — existing pre-commit checks (step 3+10) catch stale builds but not stale template logic.
- **Remediation**:
  - Added pre-commit step 13: heuristic warning when `scripts/setup-user-*` changes without `build-deploy.sh`
  - Updated `deploy-paths.md` rule with explicit template sync table
  - **Structural fix (v0.25.1)**: Refactored `build-deploy.sh` to extract setup logic from `scripts/` at build time via sentinel-based Perl extraction (`extract_between()` helper). Eliminated ~507 lines of duplicated template logic. All 4 script pairs (claude, cursor, mcp, hooks) now use single source of truth.
- **Status**: Remediated (v0.25.1)
- **Verification**: `build-deploy.sh` now fails loudly if sentinels are missing. Pre-commit step 13 remains as a secondary safety net.

#### I7: Plan-phase rule violations — Typst setup (2026-02-28)

- **Observed**: Initial plan for setup-typst.sh included `cargo uninstall typst-cli 2>/dev/null || true` and `npm uninstall -g typst 2>/dev/null || true` without the required explanatory comments, without noting the need for exemption table entries, and with vague pseudocode that omitted required logging block elements (display_path, tool-registry.md header reference). User had to request a re-audit to surface these issues.
- **RCA**: Rules were treated as applying only to committed code. Plan-phase pseudocode was given "draft quality" latitude, allowing violations to be deferred to implementation. This is wrong -- the plan is the blueprint, and a blueprint with violations produces violations.
- **Remediation**: Broadened scope in error-handling.md and script-standards.md to explicitly cover plans and pseudocode. Violations in plans are equivalent to violations in committed code and must be documented as incidents.
- **Status**: RCA (rule updates applied)

#### I8: Plan revision shallow -- keyword grep instead of full re-read (2026-02-28)

- **Observed**: When user provides feedback during plan review that alters scope or
  order of operations, the revision approach defaults to grepping the plan for specific
  keywords or phrases rather than re-reading and regenerating from scratch. This misses
  structural changes that the feedback implies. Two confirmed occurrences:
  - Typst plan (2026-02-28): removing "gold standard" altered audit framing and "Based on" references,
    but revision only grep-replaced the phrase itself.
  - File rename / version-tracking plan (2026-03-02): user asked to make the stale-reference check
    a write-and-execute script. Fix applied to Batch 2 (check-rename.sh). Batch 4 version checks had
    the identical violation (`;`-separated inline commands) but were not corrected — targeted edit,
    not full re-scan. I10 is a downstream consequence.
- **RCA**: Plan revision is performed as a targeted find-and-replace rather than a full re-read of
  the revised plan. When feedback implies a cross-cutting change (a pattern, a style, a constraint),
  the correct response is to re-read every batch/section and apply the change wherever it applies —
  not just at the location the user pointed to.
- **Remediation**: After any user feedback that alters a pattern or constraint (not just a specific
  line), scan every batch/section of the plan before finalizing. If the corrected pattern applies
  elsewhere, update those locations too. Present the full revised plan or a summary of all locations
  changed, not just the immediate fix.
- **Status**: RCA
- **Detection gap**: Hard to automate. Could be caught at plan-review time by asking: "does this
  feedback imply a pattern change? If so, where else in the plan does the same pattern appear?"

#### I10: Chained version-check commands in Bash tool call (2026-03-02)

- **Observed**: During Batch 4 (version checks), attempted to run 9 tool version commands chained with `&&` and `echo "---"` separators in a single Bash tool call. User blocked it and asked for a script.
- **RCA**: Two-layer failure. (1) **I8 (plan revision)**: During plan review, user asked to make the stale-reference check a write-and-execute script. Fix was applied to Batch 2's `check-rename.sh` block but not generalized — Batch 4 still had `;`-separated inline version commands. User also missed it during review. (2) **Implementation**: Batch 4's inline commands were carried into implementation as `&&`-chained Bash tool calls instead of a script, despite the Batch 2 template being immediately available.
- **Remediation**: (1) I8 remediation (re-scan full plan after pattern-change feedback) prevents the Batch 4 block from surviving to implementation. (2) When a plan batch shows multi-command sequences inline, apply the write-and-execute pattern regardless — the inline form in the plan is not authorization to run them inline in the Bash tool.
- **Status**: RCA
- **Detection gap**: No automated check. Could be caught at plan-review time by scanning prescribed Bash blocks for `&&`/`;` and flagging them for conversion to write-and-execute.

#### I11: `cd /path && git status` compound Bash call (2026-03-02)

- **Observed**: During commit/push workflow, issued `cd /Users/pepe/repos/aitools-nobul-jose && git status`
  as a single Bash tool call. User blocked it. Occurred in the same session as I10 RCA documentation —
  the USO was actively in context.
- **Was the rule in context?** Yes. USO #5 is in `~/.claude/CLAUDE.md` (loaded every session). I10 was
  just documented in this same session. The rule was not only in context but under active discussion.
- **Was it a subagent?** No. Main agent. No subagent context gap involved.
- **Hook behavior**: The `standing-order-guard.sh` hook fired and correctly detected the `&&` (line 103).
  The hook's own feedback message names the fix: `"use 'git -C /path' instead of 'cd /path && git'"`.
  However the hook is in `MODE="observe"` — it logs violations and exits 0. The call was allowed through
  to CC's permission UI, where the user manually rejected it.
- **RCA**: Three contributing factors:
  1. **Mode-switch amnesia**: I10 was documented as a completed incident. When switching from
     documentation mode to execution mode, the constraint was treated as "resolved/historical" rather
     than "actively in force right now." The lesson was filed, not carried forward.
  2. **Salient vs. convenience `&&`**: I10 involved chaining 9 commands (obviously a multi-command
     sequence). I11 used `&&` as a convenience shortcut for a single conceptual operation (check git
     status in another repo). The USO violation isn't more acceptable in the second case, but it
     registered differently — `cd && cmd` feels like one operation, not two chained commands.
  3. **Unfired alternative**: `git -C /path status` is the correct form for cross-repo git calls but
     is less automatic than `cd && cmd`. It requires active recall; `cd && cmd` fires from habit.
- **Remediation**: `git -C /path <command>` must be internalized as the default for cross-repo git
  operations — as automatic as `git status` itself. Before any Bash call containing a path component,
  ask: "does this use `cd` + another command? If so, use `git -C` or make two separate calls."
- **Hook remediation**: The hook correctly detected this but couldn't block it. Moving the hook from
  `observe` to `enforce` mode would have blocked it before the user had to intervene. This is a signal
  that the observe phase for USO #5 `&&`/`;` detection has produced enough confirmed catches (I10, I11)
  to justify promoting to enforce.
- **Status**: RCA
- **Detection gap**: Hook is functional but in observe mode. Log analysis (35 entries) shows two false
  positive categories that must be fixed before promoting `;` detection to enforce:
  (1) `pwsh -NoProfile -Command '$e = $null; $null = ...'` — PS1 statement separator inside `-Command`
  string; would block the prescribed pre-validation convention from `cross-platform.md`.
  (2) `perl -e 'alarm(10); exec(...)'` — Perl statement separator inside `-e` string; would block
  Perl one-liners including the USO-prescribed pattern.
  `&&` and `||` checks have zero false positives in the log and could enforce independently.
  Fix: exempt `;` when it appears inside a `-Command '...'` or `-e '...'` argument before promoting.

#### I13: Newline-separated commands in single Bash tool call (2026-03-02)

- **Observed**: Attempted to run two commands in one Bash tool call separated by a newline:
  `echo '{"tool_name":"Bash",...}' | bash shared/hooks/standing-order-guard.sh` followed by
  `echo "clean exit: $?"`. CC flagged "Command contains newlines that could separate multiple
  commands." User blocked it.
- **RCA**: Newline is a shell command separator, equivalent in effect to `;`. The USO ("Simple Bash
  commands only") prohibits `;` and `&&` for exactly this reason — they chain independent commands in
  a single call. A newline between two commands is the same violation. The correct pattern is the
  write-and-execute pattern: write both commands to a temp script, run the script.
- **Relationship to hook**: The `standing-order-guard.sh` hook does NOT detect newlines as command
  separators. It checks `&&`, `||`, `;` explicitly, and has a "scratch files" threshold of 4+
  newlines (`\n` in JSON). A 2-command sequence (1 newline) falls below that threshold and passes
  undetected. This is a gap: the same logical violation (multiple commands in one call) has three
  forms — `&&`, `;`, newline — and the hook only catches two of them. CC's own permission system
  caught this one.
- **Status**: Observed
- **Detection gap**: Hook's newline detection threshold (4+) is too high to catch short
  multi-command sequences. Adding a newline-as-separator check (distinct from the scratch-files
  length check) would close this. Needs careful scoping to avoid false positives on heredocs and
  multi-line strings passed as arguments.

#### I12: Hook crash after per-check mode refactor (2026-03-02)

- **Observed**: Every Bash tool call produced "PreToolUse:Bash hook error" immediately after deploying
  the `&&`/`$()` enforcement changes. Hook was crashing before running any check.
- **RCA**: The refactor renamed `MODE="observe"` to `MODE_AND`, `MODE_SUBSHELL`, `MODE_REST`. The
  `mkdir -p "$LOG_DIR"` guard on line 40 still referenced `if [ "$MODE" = "observe" ]`. With
  `set -euo pipefail`, the `-u` flag treats unset variables as errors — `$MODE` was unset, so the
  script exited fatally on every invocation before reaching any check logic. `bash -n` syntax
  validation passed because `-n` only checks syntax, not runtime variable bindings.
- **RCA**: Two gaps: (1) the refactor didn't search for all remaining uses of the old variable name
  (`$MODE` appeared in the guard but not in the case statement, so it wasn't obvious); (2) no
  smoke-test was run against a sample input before deploying — `bash -n` is insufficient for hooks
  that use `-u` and reference variables dynamically.
- **Remediation**: Fixed in v0.29.2 — `mkdir -p "$LOG_DIR"` now runs unconditionally (both modes
  need the log dir). Added smoke-test recommendation to hook rollout practice: run
  `echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | bash <hook>` before deploying.
- **Status**: Remediated (v0.29.2)
- **Detection gap**: `bash -n` does not catch unset variable errors under `-u`. Smoke-test with
  representative input is required for any hook using `set -euo pipefail`. Added to `hook-rollout.md`.
